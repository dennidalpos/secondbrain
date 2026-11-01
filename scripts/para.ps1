#requires -Version 7.5
[CmdletBinding(DefaultParameterSetName='Check')]
param(
    [string]$ConfigPath,[string]$SessionId,
    [string]$BackupRoot,
    [Parameter(ParameterSetName='Check')][switch]$Check,
    [Parameter(Mandatory,ParameterSetName='Index')][switch]$BuildIndex,
    [Parameter(Mandatory,ParameterSetName='Suggest')][switch]$SuggestArchive,
    [Parameter(Mandatory,ParameterSetName='New')][switch]$NewProject,
    [Parameter(Mandatory,ParameterSetName='New')][ValidatePattern('^[a-z][a-z0-9-]{0,95}$')][string]$Id,
    [Parameter(Mandatory,ParameterSetName='New')][string]$Title,
    [Parameter(Mandatory,ParameterSetName='New')][string[]]$Areas,
    [Parameter(Mandatory,ParameterSetName='New')][string]$Objective,
    [Parameter(Mandatory,ParameterSetName='New')][string[]]$Acceptance,
    [Parameter(Mandatory,ParameterSetName='Archive')][switch]$Archive,
    [Parameter(Mandatory,ParameterSetName='Restore')][switch]$Restore,
    [Parameter(Mandatory,ParameterSetName='Archive')][Parameter(Mandatory,ParameterSetName='Restore')][string]$EntityId
)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1') -Force
# Scrittura occupata oltre l'attesa: exit 3 (il titolare e nel messaggio).
trap { if (Test-SBBusyError $_) { [Console]::Error.WriteLine($_.Exception.Message); exit 3 }; break }
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Para.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.TrackerImport.psm1')
$config=Read-SBConfiguration $ConfigPath
if(!$BackupRoot){$BackupRoot=$config.backupRoot}
if($config.ContainsKey('mode') -and $config.mode -eq 'portable'){$BackupRoot=Assert-SBCentralDataPath $config.brainRoot $BackupRoot}
if((Read-SBJson (Join-Path $config.brainRoot 'config/shared.json') @{}).schemaVersion -ne 1){throw 'Policy condivisa non valida: config/shared.json'}
$writing=$BuildIndex -or $NewProject -or $Archive -or $Restore
$lock=Enter-SBOperation $config $SessionId -ReadOnly:(!$writing)
try {
    $index=Get-SBParaIndex $config.brainRoot $config.allowedOwners
    if($NewProject){
        if(!$Title.Trim() -or $Title -match '[\r\n]' -or !$Objective.Trim() -or !$Acceptance.Count -or @($Acceptance|Where-Object {![string]$_ -or !([string]$_).Trim()}).Count){throw 'Titolo, obiettivo e criteri di completamento richiesti'}
        if(@($index.entities|Where-Object id -eq $Id).Count){throw 'Identificatore gia presente'}
        foreach($area in $Areas){if(!@($index.entities|Where-Object {$_.id -eq $area -and $_.kind -eq 'area' -and !$_.archived -and $_.status -eq 'active'}).Count){throw 'Area attiva inesistente'}}
        $dir=Resolve-SBParaPath $config.brainRoot ('01-projects/'+$Id)
        if(Test-Path -LiteralPath $dir){throw 'Cartella progetto gia presente'}
        $meta=New-SBParaMetadata $Id 'project' $Title;$meta.areas=@($Areas|Sort-Object -Unique);$meta.trackers=@()
        $brief="# $Title`n`n## Obiettivo`n`n$Objective`n`n## Criteri di completamento`n`n"+(($Acceptance|ForEach-Object {'- '+$_}) -join "`n")+"`n"
        $ops=@(@{path=(Join-Path $dir 'para.json');expected='absent';bytes=[Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $meta))},@{path=(Join-Path $dir 'brief.md');expected='absent';bytes=[Text.Encoding]::UTF8.GetBytes($brief)})
        Invoke-SBParaTransaction $ops $BackupRoot $config.brainRoot
    }elseif($Archive -or $Restore){
        $matches=@($index.entities|Where-Object id -eq $EntityId)
        if($matches.Count -ne 1){throw 'Entita PARA inesistente'};$item=$matches[0]
        if($Archive -and $item.archived){throw 'Entita gia archiviata'}
        if($Restore -and !$item.archived){throw 'Entita gia attiva'}
        if($Archive -and !@($index.candidates|Where-Object id -eq $EntityId).Count){throw 'Stato o Progetti attivi impediscono archiviazione'}
        $category=@{project='projects';area='areas';resource='resources'}[$item.kind]
        $activeRoot=@{project='01-projects';area='02-areas/products';resource='03-resources'}[$item.kind]
        $destination=$(if($Archive){'04-archives/'+$category+'/'+$item.id}else{$activeRoot+'/'+$item.id})
        $source=Resolve-SBParaPath $config.brainRoot $item.path;$target=Resolve-SBParaPath $config.brainRoot $destination
        if(Test-Path -LiteralPath $target){throw 'Destinazione gia esistente'}
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
                if($sourceHash -ne $change.previousHash){throw 'Tracker modificato durante la preparazione dello spostamento'}
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
