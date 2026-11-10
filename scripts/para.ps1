#requires -Version 7.5
[CmdletBinding(DefaultParameterSetName='Check')]
param(
    [string]$ConfigPath,[string]$SessionId,
    [string]$BackupRoot,
    [Parameter(ParameterSetName='Check')][switch]$Check,
    [Parameter(Mandatory,ParameterSetName='Index')][switch]$BuildIndex,
    [Parameter(Mandatory,ParameterSetName='Suggest')][switch]$SuggestArchive,
    [Parameter(Mandatory,ParameterSetName='New')][switch]$NewProject,
    [Parameter(Mandatory,ParameterSetName='Resource')][switch]$NewResource,
    [Parameter(Mandatory,ParameterSetName='Status')][switch]$SetStatus,
    [Parameter(Mandatory,ParameterSetName='New')][Parameter(Mandatory,ParameterSetName='Resource')][ValidatePattern('^[a-z][a-z0-9-]{0,95}$')][string]$Id,
    [Parameter(Mandatory,ParameterSetName='New')][Parameter(Mandatory,ParameterSetName='Resource')][string]$Title,
    [Parameter(ParameterSetName='New')][string[]]$Areas=@(),
    [Parameter(Mandatory,ParameterSetName='New')][Parameter(Mandatory,ParameterSetName='Resource')][string]$Objective,
    [Parameter(Mandatory,ParameterSetName='New')][string[]]$Acceptance,
    [Parameter(Mandatory,ParameterSetName='Status')][ValidateSet('active','completed','cancelled','retired')][string]$Status,
    [Parameter(Mandatory,ParameterSetName='Migrate')][switch]$MigrateToProjects,
    [Parameter(ParameterSetName='Migrate')][switch]$Apply,
    [Parameter(ParameterSetName='Migrate')][string[]]$Only,
    [Parameter(Mandatory,ParameterSetName='Archive')][switch]$Archive,
    [Parameter(Mandatory,ParameterSetName='Restore')][switch]$Restore,
    [Parameter(Mandatory,ParameterSetName='Archive')][Parameter(Mandatory,ParameterSetName='Restore')][Parameter(Mandatory,ParameterSetName='Status')][string]$EntityId
)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1') -Force
# Writer busy beyond the wait limit: exit 3 (the message identifies the owner).
trap { if (Test-SBWriteDeniedError $_) { Write-SBWriteDeniedDiagnostic $_ $PSCommandPath $PSBoundParameters; exit 4 }; if (Test-SBBusyError $_) { [Console]::Error.WriteLine($_.Exception.Message); exit 3 }; break }
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Para.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.TrackerImport.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Add-SBMessages @{
    'paracli.policy.invalid' = @{ it = 'Policy condivisa non valida: config/shared.json'; en = 'Invalid shared policy: config/shared.json' }
    'paracli.project.fields' = @{ it = 'Titolo, obiettivo e criteri di completamento richiesti'; en = 'Title, objective and completion criteria required' }
    'paracli.area.unknown' = @{ it = 'Dossier repository o area attiva inesistente'; en = 'Active repository dossier or area does not exist' }
    'paracli.project.folder' = @{ it = 'Cartella progetto gia presente'; en = 'Project folder already present' }
    'paracli.resource.fields' = @{ it = 'Titolo e obiettivo richiesti'; en = 'Title and objective required' }
    'paracli.id.present' = @{ it = 'Identificatore gia presente'; en = 'Identifier already present' }
    'paracli.resource.folder' = @{ it = 'Cartella risorsa gia presente'; en = 'Resource folder already present' }
    'paracli.entity.archived' = @{ it = 'Entita archiviata: ripristinarla prima di cambiarne lo stato'; en = 'Entity archived: restore it before changing its status' }
    'paracli.status.invalid' = @{ it = 'Stato non valido per {0}: ammessi {1}'; en = 'Invalid status for {0}: allowed {1}' }
    'paracli.status.same' = @{ it = 'Stato gia impostato'; en = 'Status already set' }
    'paracli.entity.unknown' = @{ it = 'Entita PARA inesistente'; en = 'PARA entity does not exist' }
    'paracli.entity.archivedalready' = @{ it = 'Entita gia archiviata'; en = 'Entity already archived' }
    'paracli.entity.activealready' = @{ it = 'Entita gia attiva'; en = 'Entity already active' }
    'paracli.archive.blocked' = @{ it = 'Stato o Progetti attivi impediscono archiviazione'; en = 'Status or active Projects prevent archiving' }
    'paracli.destination.exists' = @{ it = 'Destinazione gia esistente'; en = 'Destination already exists' }
    'paracli.migrate.plan' = @{ it = 'Anteprima migrazione ({0} dossier): rilanciare con -Apply per spostarli in 01-projects'; en = 'Migration preview ({0} dossiers): rerun with -Apply to move them to 01-projects' }
    'paracli.migrate.done' = @{ it = 'Migrati {0} dossier in 01-projects'; en = 'Migrated {0} dossiers to 01-projects' }
    'paracli.migrate.dirty' = @{ it = 'Dossier non migrabile ({0}): {1}'; en = 'Dossier cannot be migrated ({0}): {1}' }
    'paracli.tracker.changed' = @{ it = 'Tracker modificato durante la preparazione dello spostamento'; en = 'Tracker modified while preparing the move' }
}
$config=Read-SBConfiguration $ConfigPath
if(!$BackupRoot){$BackupRoot=$config.backupRoot}
if($config.ContainsKey('mode') -and $config.mode -eq 'portable'){$BackupRoot=Assert-SBCentralDataPath $config.brainRoot $BackupRoot}
if((Read-SBJson (Join-Path $config.brainRoot 'config/shared.json') @{}).schemaVersion -ne 1){throw (New-SBError 'paracli.policy.invalid')}
$writing=$BuildIndex -or $NewProject -or $NewResource -or $SetStatus -or $Archive -or $Restore -or ($MigrateToProjects -and $Apply)
$lock=Enter-SBOperation $config $SessionId -ReadOnly:(!$writing)
try {
    $index=Get-SBParaIndex $config.brainRoot $config.allowedOwners
    if($NewProject){
        if(!$Title.Trim() -or $Title -match '[\r\n]' -or !$Objective.Trim() -or !$Acceptance.Count -or @($Acceptance|Where-Object {![string]$_ -or !([string]$_).Trim()}).Count){throw (New-SBError 'paracli.project.fields')}
        if(@($index.entities|Where-Object id -eq $Id).Count){throw (New-SBError 'paracli.id.present')}
        foreach($area in $Areas){if(!@($index.entities|Where-Object {$_.id -eq $area -and (Test-SBRepoDossier $_) -and !$_.archived -and $_.status -eq 'active'}).Count){throw (New-SBError 'paracli.area.unknown')}}
        $dir=Resolve-SBParaPath $config.brainRoot ('01-projects/'+$Id)
        if(Test-Path -LiteralPath $dir){throw (New-SBError 'paracli.project.folder')}
        $meta=New-SBParaMetadata $Id 'project' $Title;$meta.areas=@($Areas|Sort-Object -Unique);$meta.trackers=@()
        $brief="# $Title`n`n## Obiettivo`n`n$Objective`n`n## Criteri di completamento`n`n"+(($Acceptance|ForEach-Object {'- '+$_}) -join "`n")+"`n"
        $ops=@(@{path=(Join-Path $dir 'para.json');expected='absent';bytes=[Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $meta))},@{path=(Join-Path $dir 'brief.md');expected='absent';bytes=[Text.Encoding]::UTF8.GetBytes($brief)})
        Invoke-SBParaTransaction $ops $BackupRoot $config.brainRoot
    }elseif($NewResource){
        if(!$Title.Trim() -or $Title -match '[\r\n]' -or !$Objective.Trim()){throw (New-SBError 'paracli.resource.fields')}
        if(@($index.entities|Where-Object id -eq $Id).Count){throw (New-SBError 'paracli.id.present')}
        $dir=Resolve-SBParaPath $config.brainRoot ('03-resources/'+$Id)
        if(Test-Path -LiteralPath $dir){throw (New-SBError 'paracli.resource.folder')}
        $meta=New-SBParaMetadata $Id 'resource' $Title
        $brief="# $Title`n`n## Obiettivo`n`n$Objective`n"
        $ops=@(@{path=(Join-Path $dir 'para.json');expected='absent';bytes=[Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $meta))},@{path=(Join-Path $dir 'brief.md');expected='absent';bytes=[Text.Encoding]::UTF8.GetBytes($brief)})
        Invoke-SBParaTransaction $ops $BackupRoot $config.brainRoot
    }elseif($SetStatus){
        $matches=@($index.entities|Where-Object id -eq $EntityId)
        if($matches.Count -ne 1){throw (New-SBError 'paracli.entity.unknown')};$item=$matches[0]
        if($item.archived){throw (New-SBError 'paracli.entity.archived')}
        $allowed=@{project=@('active','completed','cancelled');area=@('active','retired');resource=@('active','retired')}[$item.kind]
        if($Status -notin $allowed){throw (New-SBError 'paracli.status.invalid' @($item.kind, ($allowed -join ', ')))}
        if($item.status -eq $Status){throw (New-SBError 'paracli.status.same')}
        $metaPath=Join-Path (Resolve-SBParaPath $config.brainRoot $item.path) 'para.json'
        $m=Read-SBJson $metaPath $null;$m.status=$Status
        Invoke-SBParaTransaction @(,@{path=$metaPath;expected=(Get-SBFileHash $metaPath);bytes=[Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $m))}) $BackupRoot $config.brainRoot
    }elseif($MigrateToProjects){
        # Repository dossiers move from 02-areas/products (kind area) to 01-projects (kind project): same id, same files, one transaction per dossier.
        $candidates=@($index.entities|Where-Object {$_.kind -eq 'area' -and !$_.archived -and $_.repository -and (!$Only.Count -or $_.id -in $Only -or $_.repository -in $Only)})
        $plan=@(foreach($item in $candidates){
            $leaf=($item.path -split '/')[-1]
            $destination='01-projects/'+$leaf
            if(Test-Path -LiteralPath (Resolve-SBParaPath $config.brainRoot $destination)){throw (New-SBError 'paracli.migrate.dirty' @($item.id,(Get-SBMessage 'paracli.destination.exists')))}
            [ordered]@{id=$item.id;repository=$item.repository;from=$item.path;to=$destination}
        })
        if(!$Apply){
            ConvertTo-SBJson @{apply=$false;dossiers=$plan}
            (Get-SBMessage 'paracli.migrate.plan' @($plan.Count))
        }else{
            $moved=0
            foreach($step in $plan){
                $current=Get-SBParaIndex $config.brainRoot $config.allowedOwners
                $item=@($current.entities|Where-Object id -eq $step.id)[0]
                $source=Resolve-SBParaPath $config.brainRoot $item.path;$target=Resolve-SBParaPath $config.brainRoot $step.to
                $mapping=@{$item.path=$step.to}
                $trackerChanges=@{}
                foreach($change in @(Get-SBTrackerRelocationData $config $item $mapping)){$trackerChanges[$change.path]=$change}
                foreach($child in Get-ChildItem -LiteralPath $source -Directory -Recurse -Force){Assert-SBPlainPath $child.FullName}
                $ops=@()
                foreach($file in Get-ChildItem -LiteralPath $source -Recurse -File -Force){
                    Assert-SBPlainPath $file.FullName
                    $relative=[IO.Path]::GetRelativePath($source,$file.FullName)
                    $bytes=[IO.File]::ReadAllBytes($file.FullName)
                    $sourceHash=Get-SBHash $bytes
                    if($trackerChanges.ContainsKey($file.FullName)){
                        $change=$trackerChanges[$file.FullName]
                        if($sourceHash -ne $change.previousHash){throw (New-SBError 'paracli.tracker.changed')}
                        $bytes=$change.bytes
                    }
                    if($relative -eq 'para.json'){
                        $m=([Text.UTF8Encoding]::new($false,$true)).GetString($bytes).TrimStart([char]0xFEFF)|ConvertFrom-Json -AsHashtable -DateKind String
                        $m.kind='project';if($m.status -eq 'retired'){$m.status='completed'}
                        $bytes=[Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $m))
                    }
                    $ops+=@{path=(Join-Path $target $relative);expected='absent';bytes=$bytes}
                    $ops+=@{path=$file.FullName;expected=$sourceHash;bytes=$null}
                }
                foreach($folder in @('specs','material','data')){
                    if(!(Test-Path -LiteralPath (Join-Path $source $folder))){$ops+=@{path=(Join-Path $target "$folder/README.md");expected='absent';bytes=[Text.Encoding]::UTF8.GetBytes("# $folder`n")}}
                }
                $ops+=@(Get-SBParaReferenceOperations $config $mapping)
                $ops+=@(Get-SBTrackerRelocationOperations $config $mapping $trackerChanges)
                Invoke-SBParaTransaction $ops $BackupRoot $config.brainRoot @(Get-SBParaRuntimePaths $config)
                Remove-SBParaEmptyTree $source $config.brainRoot
                $moved++
            }
            (Get-SBMessage 'paracli.migrate.done' @($moved))
        }
    }elseif($Archive -or $Restore){
        $matches=@($index.entities|Where-Object id -eq $EntityId)
        if($matches.Count -ne 1){throw (New-SBError 'paracli.entity.unknown')};$item=$matches[0]
        if($Archive -and $item.archived){throw (New-SBError 'paracli.entity.archivedalready')}
        if($Restore -and !$item.archived){throw (New-SBError 'paracli.entity.activealready')}
        if($Archive -and !@($index.candidates|Where-Object id -eq $EntityId).Count){throw (New-SBError 'paracli.archive.blocked')}
        $category=@{project='projects';area='areas';resource='resources'}[$item.kind]
        $activeRoot=@{project='01-projects';area='02-areas/products';resource='03-resources'}[$item.kind]
        $destination=$(if($Archive){'04-archives/'+$category+'/'+$item.id}else{$activeRoot+'/'+$item.id})
        $source=Resolve-SBParaPath $config.brainRoot $item.path;$target=Resolve-SBParaPath $config.brainRoot $destination
        if(Test-Path -LiteralPath $target){throw (New-SBError 'paracli.destination.exists')}
        $mapping=@{$item.path=$destination}
        $trackerChanges=@{}
        foreach($change in @(Get-SBTrackerRelocationData $config $item $mapping)){$trackerChanges[$change.path]=$change}
        foreach($child in Get-ChildItem -LiteralPath $source -Directory -Recurse -Force){Assert-SBPlainPath $child.FullName}
        $ops=@()
        foreach($file in Get-ChildItem -LiteralPath $source -Recurse -File -Force){
            Assert-SBPlainPath $file.FullName
            $relative=[IO.Path]::GetRelativePath($source,$file.FullName)
            $bytes=[IO.File]::ReadAllBytes($file.FullName)
            $sourceHash=Get-SBHash $bytes
            if($trackerChanges.ContainsKey($file.FullName)){
                $change=$trackerChanges[$file.FullName]
                if($sourceHash -ne $change.previousHash){throw (New-SBError 'paracli.tracker.changed')}
                $bytes=$change.bytes
            }
            if($Restore -and $relative -eq 'para.json'){
                $m=([Text.UTF8Encoding]::new($false,$true)).GetString($bytes).TrimStart([char]0xFEFF)|ConvertFrom-Json -AsHashtable -DateKind String
                $m.status='active';$bytes=[Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $m))
            }
            $ops+=@{path=(Join-Path $target $relative);expected='absent';bytes=$bytes}
            $ops+=@{path=$file.FullName;expected=$sourceHash;bytes=$null}
        }
        $ops+=@(Get-SBParaReferenceOperations $config $mapping)
        $ops+=@(Get-SBTrackerRelocationOperations $config $mapping $trackerChanges)
        Invoke-SBParaTransaction $ops $BackupRoot $config.brainRoot @(Get-SBParaRuntimePaths $config)
        Remove-SBParaEmptyTree $source $config.brainRoot
    }
    if($writing){$index=Update-SBParaIndex $config}
    elseif(!$SuggestArchive){$index=Update-SBParaIndex $config -Check}
    if($SuggestArchive){$index.candidates|ConvertTo-Json -Depth 5}else{"PARA: $($index.entities.Count) entita; $($index.candidates.Count) proposte di archiviazione"}
} finally {Exit-SBOperation $lock}
