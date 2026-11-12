#requires -Version 7.5
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Add-SBMessages @{
    'para.path.unconfined' = @{ it = 'Percorso PARA non relativo o non confinato'; en = 'PARA path is not relative or not confined' }
    'para.path.outside' = @{ it = 'Percorso fuori radice PARA'; en = 'Path outside the PARA root' }
    'para.reparse.knowledge' = @{ it = 'Reparse point nella conoscenza PARA'; en = 'Reparse point in PARA knowledge' }
    'para.metadata.missing' = @{ it = 'Metadato PARA mancante: {0}'; en = 'Missing PARA metadata: {0}' }
    'para.metadata.invalid' = @{ it = 'Metadati PARA non validi'; en = 'Invalid PARA metadata' }
    'para.status.invalid' = @{ it = 'Stato PARA non valido'; en = 'Invalid PARA status' }
    'para.id.duplicate' = @{ it = 'Identificatore PARA duplicato: {0}'; en = 'Duplicate PARA identifier: {0}' }
    'para.category.diverged' = @{ it = 'Categoria e percorso PARA divergenti'; en = 'PARA category and path diverge' }
    'para.brief.missing' = @{ it = 'Brief mancante: {0}'; en = 'Missing brief: {0}' }
    'para.project.field' = @{ it = 'Campo progetto non valido: {0}'; en = 'Invalid project field: {0}' }
    'para.tracker.reference' = @{ it = 'Riferimento tracker non valido'; en = 'Invalid tracker reference' }
    'para.tracker.repopath' = @{ it = 'Percorso tracker repository mancante'; en = 'Repository tracker path missing' }
    'para.area.identity' = @{ it = 'Identita del dossier repository non ammessa'; en = 'Repository dossier identity not allowed' }
    'para.area.repoduplicate' = @{ it = 'Repository associato a piu dossier'; en = 'Repository bound to more than one dossier' }
    'para.area.incomplete' = @{ it = 'Dossier repository incompleto: {0}/{1}'; en = 'Incomplete repository dossier: {0}/{1}' }
    'para.area.linkmissing' = @{ it = 'Dossier repository o area collegati inesistenti: {0}'; en = 'Linked repository dossier or area does not exist: {0}' }
    'para.tracker.unlinked' = @{ it = 'Tracker non collegato ai dossier del progetto'; en = 'Tracker not linked to the project dossiers' }
    'para.tracker.localmissing' = @{ it = 'Tracker locale inesistente'; en = 'Local tracker does not exist' }
    'para.index.stale' = @{ it = 'Indice PARA da aggiornare'; en = 'PARA index needs updating' }
    'para.transaction.outside' = @{ it = 'Operazione transazionale fuori perimetro'; en = 'Transactional operation outside scope' }
    'para.transaction.duplicate' = @{ it = 'Destinazione duplicata nella transazione'; en = 'Duplicate destination in the transaction' }
    'para.transaction.changed' = @{ it = 'Contenuto cambiato: {0}'; en = 'Content changed: {0}' }
    'para.transaction.backup' = @{ it = 'Backup transazionale non verificato'; en = 'Transactional backup not verified' }
    'para.transaction.incomplete' = @{ it = 'Transazione PARA incompleta: ripristinare prima il manifest pendente'; en = 'Incomplete PARA transaction: restore the pending manifest first' }
    'para.transaction.marker' = @{ it = 'Indicatore transazione modificato'; en = 'Transaction marker modified' }
    'para.transaction.interrupted' = @{ it = 'Transazione interrotta; ripristino con manifest {0}. {1}'; en = 'Transaction interrupted; restore with manifest {0}. {1}' }
    'para.manifest.outside' = @{ it = 'Manifest fuori radice backup autorizzata'; en = 'Manifest outside the authorized backup root' }
    'para.manifest.foreign' = @{ it = 'Manifest di altra installazione o non valido'; en = 'Manifest of another installation or invalid' }
    'para.recovery.outside' = @{ it = 'Record di recupero fuori perimetro'; en = 'Recovery record outside scope' }
    'para.restore.refused' = @{ it = 'Ripristino rifiutato: file modificato {0}'; en = 'Restore refused: file modified {0}' }
    'para.backup.altered' = @{ it = 'Backup alterato'; en = 'Backup altered' }
    'para.payload.outside' = @{ it = 'Payload fuori registro di recupero'; en = 'Payload outside the recovery registry' }
    'para.recovery.pending' = @{ it = 'Altro recupero pendente'; en = 'Another recovery is pending' }
}

function Resolve-SBParaPath([string]$Root,[string]$Relative) {
    if (!$Relative -or [IO.Path]::IsPathRooted($Relative) -or $Relative -match '(^|[\\/])\.\.([\\/]|$)|:') { throw (New-SBError 'para.path.unconfined') }
    $boundary=[IO.Path]::GetFullPath($Root).TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
    $full=[IO.Path]::GetFullPath((Join-Path $Root $Relative))
    if (!$full.StartsWith($boundary,[StringComparison]::OrdinalIgnoreCase)) { throw (New-SBError 'para.path.outside') }
    Assert-SBPlainPath $full
    $full
}

$script:SBParaCache=@{}
function Get-SBParaEntities([string]$BrainRoot,[string[]]$AllowedOwners,[switch]$Refresh) {
    # On a share, scanning every dossier on each call is costly: short-lived memoization, invalidated by each write
    # in this process (generation) and by expiry. Disabled locally unless forced with SECONDBRAIN_PARA_CACHE=1.
    if(!($BrainRoot.StartsWith('\\') -or $env:SECONDBRAIN_PARA_CACHE -eq '1')){return @(Read-SBParaEntitiesFromDisk $BrainRoot $AllowedOwners)}
    $key=[IO.Path]::GetFullPath($BrainRoot).ToLowerInvariant()+'|'+((@($AllowedOwners)|Sort-Object) -join ',')
    $generation=Get-SBWriteGeneration
    $entry=if($script:SBParaCache.ContainsKey($key)){$script:SBParaCache[$key]}else{$null}
    if(!$Refresh -and $entry -and $entry.generation -eq $generation -and ([DateTimeOffset]::UtcNow-$entry.at).TotalSeconds -lt 10){return @($entry.items)}
    $items=@(Read-SBParaEntitiesFromDisk $BrainRoot $AllowedOwners)
    $script:SBParaCache[$key]=@{generation=$generation;at=[DateTimeOffset]::UtcNow;items=$items}
    $items
}
function Read-SBParaEntitiesFromDisk([string]$BrainRoot,[string[]]$AllowedOwners) {
    $items=[Collections.Generic.List[object]]::new();$ids=@{};$repositories=@{}
    foreach($root in @('01-projects','02-areas','03-resources','04-archives')) {
        $path=Resolve-SBParaPath $BrainRoot $root
        if(!(Test-Path -LiteralPath $path)){continue}
        $queue=[Collections.Generic.Queue[string]]::new();$queue.Enqueue($path)
        while($queue.Count){
            $dir=$queue.Dequeue();Assert-SBPlainPath $dir
            foreach($child in Get-ChildItem -LiteralPath $dir -Directory -Force){
                if($child.Attributes -band [IO.FileAttributes]::ReparsePoint){throw (New-SBError 'para.reparse.knowledge')}
                if($child.Name -ne 'snapshots'){$queue.Enqueue($child.FullName)}
            }
            $metadata=Join-Path $dir 'para.json'
            if(!(Test-Path -LiteralPath $metadata)){continue}
            Assert-SBPlainPath $metadata
            $m=Read-SBJson $metadata $null
            foreach($field in @('schemaVersion','id','kind','title','status')){if(!$m.ContainsKey($field)){throw (New-SBError 'para.metadata.missing' @($field))}}
            if($m.schemaVersion -ne 1 -or $m.id -notmatch '^[a-z][a-z0-9-]{0,95}$' -or $m.kind -notin @('project','area','resource') -or !$m.title.Trim() -or $m.title -match '[\r\n]'){throw (New-SBError 'para.metadata.invalid')}
            $statuses=@{project=@('active','completed','cancelled');area=@('active','retired');resource=@('active','retired')}
            if($m.status -notin $statuses[$m.kind]){throw (New-SBError 'para.status.invalid')}
            if($ids.ContainsKey($m.id)){throw (New-SBError 'para.id.duplicate' @($m.id))};$ids[$m.id]=$true
            $relative=[IO.Path]::GetRelativePath($BrainRoot,$dir).Replace('\','/')
            $expected=@{project='01-projects/';area='02-areas/';resource='03-resources/'}[$m.kind]
            $archive=@{project='projects';area='areas';resource='resources'}[$m.kind]
            $archived=$relative.StartsWith('04-archives/',[StringComparison]::Ordinal)
            if(!$relative.StartsWith($expected,[StringComparison]::Ordinal) -and !$relative.StartsWith("04-archives/$archive/",[StringComparison]::Ordinal)){throw (New-SBError 'para.category.diverged')}
            if(!(Test-Path -LiteralPath (Join-Path $dir 'brief.md') -PathType Leaf)){throw (New-SBError 'para.brief.missing' @($relative))}
            Assert-SBPlainPath (Join-Path $dir 'brief.md')
            $repo=Read-SBJson (Join-Path $dir 'repository.json') $null
            # A project with repository.json is a repository dossier (strict per-repository perimeter): no areas or trackers links.
            $isRepoProject=($m.kind -eq 'project' -and $repo -and $repo.ContainsKey('identity'))
            if($m.kind -eq 'project' -and !$isRepoProject){
                foreach($field in @('areas','trackers')){if(!$m.ContainsKey($field) -or $m[$field] -isnot [array]){throw (New-SBError 'para.project.field' @($field))}}
                foreach($tracker in $m.trackers){
                    if(!$tracker.ContainsKey('area') -or !$tracker.ContainsKey('path')){throw (New-SBError 'para.tracker.reference')}
                    if($tracker.ContainsKey('repository') -and $tracker.repository){
                        if(!$tracker.path){throw (New-SBError 'para.tracker.repopath')}
                    }else{[void](Resolve-SBParaPath $dir $tracker.path)}
                }
            }
            # An area with repository.json is a legacy repository dossier; an area without it is a plain ongoing responsibility (02-areas/<id>).
            if(($m.kind -eq 'area' -and $repo) -or $isRepoProject){
                if(!$repo -or !(Test-SBRepositoryIdentity $repo.identity $AllowedOwners)){throw (New-SBError 'para.area.identity')}
                if($repositories.ContainsKey($repo.identity)){throw (New-SBError 'para.area.repoduplicate')};$repositories[$repo.identity]=$true
                foreach($file in @('context.md','memory.md')){if(!(Test-Path -LiteralPath (Join-Path $dir $file) -PathType Leaf)){throw (New-SBError 'para.area.incomplete' @($relative, $file))}}
            }
            $items.Add(@{id=$m.id;kind=$m.kind;title=$m.title;status=$m.status;path=$relative;archived=$archived;metadata=$m;repository=$(if($repo){$repo.identity}else{''})})
        }
    }
    foreach($item in $items|Where-Object {$_.kind -eq 'project' -and !$_.repository}){
        foreach($area in $item.metadata.areas){
            if(!@($items|Where-Object { $_.id -eq $area -and (Test-SBRepoDossier $_) }).Count){throw (New-SBError 'para.area.linkmissing' @($area))}
        }
        foreach($tracker in $item.metadata.trackers){
            $area=@($items|Where-Object {$_.id -eq $tracker.area -and (Test-SBRepoDossier $_)})
            if($area.Count -ne 1 -or $tracker.area -notin $item.metadata.areas){throw (New-SBError 'para.tracker.unlinked')}
            if(!$tracker.ContainsKey('repository') -or !$tracker.repository){
                if(!(Test-Path -LiteralPath (Resolve-SBParaPath (Join-Path $BrainRoot $area[0].path) $tracker.path) -PathType Leaf)){throw (New-SBError 'para.tracker.localmissing')}
            }
        }
    }
    @($items|Sort-Object id)
}

function Get-SBParaIndex([string]$BrainRoot,[string[]]$AllowedOwners) {
    $entities=@(Get-SBParaEntities $BrainRoot $AllowedOwners)
    $candidates=@()
    foreach($item in $entities){
        if($item.archived){continue}
        $eligible=($item.kind -eq 'project' -and $item.status -in @('completed','cancelled')) -or ($item.kind -in @('area','resource') -and $item.status -eq 'retired')
        if((Test-SBRepoDossier $item) -and @($entities|Where-Object {$_.kind -eq 'project' -and !$_.repository -and !$_.archived -and $_.status -eq 'active' -and $item.id -in $_.metadata.areas}).Count){$eligible=$false}
        if($eligible){$candidates+=@{id=$item.id;reason=$item.status}}
    }
    $data=@{schemaVersion=1;entities=@($entities|ForEach-Object {@{id=$_.id;kind=$_.kind;title=$_.title;status=$_.status;path=$_.path;archived=$_.archived}});archiveCandidates=@($candidates)}
    $lines=@('# Indice PARA','')
    foreach($item in $entities){$label=$item.title.Replace('[','\[').Replace(']','\]');$lines+='- ['+$label+']('+[Uri]::EscapeUriString($item.path+'/brief.md')+'): '+$item.kind+' / '+$item.status+$(if($item.archived){' / archived'}else{''})}
    $lines+=@('','## Proposte di archiviazione','')
    foreach($item in $candidates){$lines+='- '+$item.id+': '+$item.reason}
    @{json=(ConvertTo-SBJson $data);markdown=($lines -join "`n")+"`n";entities=$entities;candidates=$candidates}
}

function Update-SBParaIndex($Config,[switch]$Check) {
    $index=Get-SBParaIndex $Config.brainRoot $Config.allowedOwners
    foreach($pair in @(@('para-index.json','json'),@('PARA.md','markdown'))){
        $path=Join-Path $Config.brainRoot $pair[0];$text=$index[$pair[1]]
        $hash=Get-SBFileHash $path
        if($hash -ne (Get-SBTextHash $text)){
            if($Check){throw (New-SBError 'para.index.stale')}
            Write-SBFile $path ([Text.Encoding]::UTF8.GetBytes($text)) $hash $Config.backupRoot -Recoverable|Out-Null
        }
    }
    $index
}

# File-level journal: every old payload is verified before the first write. Recovery
# verifies the deployed hashes and never overwrites a subsequent user edit.
function Invoke-SBParaTransaction([object[]]$Operations,[string]$BackupRoot,[string]$BrainRoot,[string[]]$AllowedPaths=@(),[string]$RecoveryManifest='') {
    try {
    $backupFull=[IO.Path]::GetFullPath($BackupRoot)
    $brainFull=[IO.Path]::GetFullPath($BrainRoot).TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
    if($backupFull.StartsWith($brainFull,[StringComparison]::OrdinalIgnoreCase)){
        [void](Assert-SBCentralDataPath $BrainRoot $backupFull)
    }
    Assert-SBPlainPath $BackupRoot
    $journalRoot=Join-Path $BackupRoot ('para-'+[guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($journalRoot)|Out-Null
    $records=@();$seen=@{}
    foreach($op in $Operations){
        $path=[IO.Path]::GetFullPath($op.path);Assert-SBPlainPath $path
        if(!$path.StartsWith($brainFull,[StringComparison]::OrdinalIgnoreCase) -and $path -notin $AllowedPaths){throw (New-SBError 'para.transaction.outside')}
        if($seen.ContainsKey($path)){throw (New-SBError 'para.transaction.duplicate')};$seen[$path]=$true
        if((Get-SBFileHash $path) -ne $op.expected){throw (New-SBError 'para.transaction.changed' @($path))}
        $payload=Join-Path $journalRoot ($records.Count.ToString()+'.bin')
        if($op.expected -ne 'absent'){
            [IO.File]::Copy($path,$payload)
            if((Get-SBFileHash $payload) -ne $op.expected){throw (New-SBError 'para.transaction.backup')}
        }
        $records+=@{path=$path;previousHash=$op.expected;backup=$payload;deployedHash=$(if($null -eq $op.bytes){'absent'}else{Get-SBHash $op.bytes});applied=$false}
    }
    $manifest=Join-Path $journalRoot 'manifest.json'
    $journal=@{schemaVersion=1;brainRoot=[IO.Path]::GetFullPath($BrainRoot);status='applying';records=$records}
    function Save-Journal {
        $temp=$manifest+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
        try {
            $bytes=[Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $journal))
            $stream=[IO.FileStream]::new($temp,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
            try{$stream.Write($bytes);$stream.Flush($true)}finally{$stream.Dispose()}
            [IO.File]::Move($temp,$manifest,$true)
        }finally{if([IO.File]::Exists($temp)){[IO.File]::Delete($temp)}}
    }
    Save-Journal
    $marker=Get-SBTransactionMarkerPath $BrainRoot
    $markerHash=Get-SBFileHash $marker
    if($markerHash -ne 'absent'){
        $pending=Read-SBJson $marker @{}
        # The marker may have been written by another host using a different alias of the same brain.
        $pendingManifest=if($pending.ContainsKey('brainRoot')){Convert-SBBrainAlias ([string]$pending.manifest) ([string]$pending.brainRoot) $BrainRoot}else{[string]$pending.manifest}
        if(!$RecoveryManifest -or $pendingManifest -ne [IO.Path]::GetFullPath($RecoveryManifest)){throw (New-SBError 'para.transaction.incomplete')}
    }
    $markerText=ConvertTo-SBJson @{manifest=$manifest;brainRoot=[IO.Path]::GetFullPath($BrainRoot);computer=[Environment]::MachineName;user=[Security.Principal.WindowsIdentity]::GetCurrent().Name;processId=$PID;startedAt=[DateTimeOffset]::UtcNow.ToString('o')}
    Write-SBFile $marker ([Text.Encoding]::UTF8.GetBytes($markerText)) $markerHash $journalRoot|Out-Null
    try {
        for($i=0;$i -lt $Operations.Count;$i++){
            Assert-SBWriteGuard
            $op=$Operations[$i];$record=$records[$i]
            if($null -eq $op.bytes){Remove-SBFile $op.path (Split-Path $op.path) $op.expected $journalRoot|Out-Null}
            else{
                if($op.expected -ne 'absent' -and (Get-SBFileHash $record.backup) -ne $op.expected){throw (New-SBError 'para.transaction.backup')}
                Write-SBFile $op.path $op.bytes $op.expected $journalRoot -Recoverable|Out-Null
            }
            $record.applied=$true;Save-Journal
        }
        $journal.status='complete';Save-Journal
        if((Get-SBFileHash $marker) -ne (Get-SBTextHash $markerText)){throw (New-SBError 'para.transaction.marker')}
        Assert-SBWriteGuard;[IO.File]::Delete($marker)
        $manifest
    }catch{
        $primary=$_.Exception;$journal.status='interrupted'
        try{Save-Journal}catch{Write-Warning (Get-SBMessage 'core.write.finalization' @($manifest,$_.Exception.Message))}
        throw (New-SBError 'para.transaction.interrupted' @($manifest,$primary.Message) ([IO.IOException]) 0 $primary)
    }
    }catch{throw (ConvertTo-SBWriteError $_.Exception $BackupRoot)}
}

function Restore-SBParaTransaction([string]$ManifestPath,[string]$BrainRoot,[string]$BackupRoot,[string[]]$AllowedPaths=@()) {
    Assert-SBPlainPath $ManifestPath
    $manifestFull=[IO.Path]::GetFullPath($ManifestPath)
    $backupBoundary=[IO.Path]::GetFullPath($BackupRoot).TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
    if(!$manifestFull.StartsWith($backupBoundary,[StringComparison]::OrdinalIgnoreCase)){throw (New-SBError 'para.manifest.outside')}
    $journal=Read-SBJson $ManifestPath $null
    if(!$journal -or $journal.schemaVersion -ne 1 -or !(Test-SBSamePath $journal.brainRoot $BrainRoot)){throw (New-SBError 'para.manifest.foreign')}
    $ops=@()
    foreach($r in $journal.records){
        # The journal may have been written by another host accessing the same brain through a different alias.
        $r.path=Convert-SBBrainAlias $r.path $journal.brainRoot $BrainRoot
        if($r.backup){$r.backup=Convert-SBBrainAlias $r.backup $journal.brainRoot $BrainRoot}
        $path=[IO.Path]::GetFullPath($r.path)
        $boundary=[IO.Path]::GetFullPath($BrainRoot).TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
        if(!$path.StartsWith($boundary,[StringComparison]::OrdinalIgnoreCase) -and $path -notin $AllowedPaths){throw (New-SBError 'para.recovery.outside')}
        # Also covers a process killed after a file change but before journal flush.
        $current=Get-SBFileHash $r.path
        if($current -eq $r.previousHash){continue}
        if($current -ne $r.deployedHash){throw (New-SBError 'para.restore.refused' @($r.path))}
        if($r.previousHash -ne 'absent' -and (Get-SBFileHash $r.backup) -ne $r.previousHash){throw (New-SBError 'para.backup.altered')}
        if($r.previousHash -ne 'absent' -and ![IO.Path]::GetFullPath($r.backup).StartsWith((Split-Path $manifestFull)+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw (New-SBError 'para.payload.outside')}
        $ops=@(@{path=$r.path;expected=$current;bytes=$(if($r.previousHash -eq 'absent'){$null}else{[IO.File]::ReadAllBytes($r.backup)})})+$ops
    }
    if($ops.Count){Invoke-SBParaTransaction $ops $BackupRoot $BrainRoot $AllowedPaths $ManifestPath}else{
        $marker=Get-SBTransactionMarkerPath $BrainRoot
        if(Test-Path -LiteralPath $marker){
            $pendingMarker=Read-SBJson $marker @{}
            $pendingManifest=if($pendingMarker.ContainsKey('brainRoot')){Convert-SBBrainAlias ([string]$pendingMarker.manifest) ([string]$pendingMarker.brainRoot) $BrainRoot}else{[string]$pendingMarker.manifest}
            if($pendingManifest -ne $manifestFull){throw (New-SBError 'para.recovery.pending')}
            Assert-SBWriteGuard;[IO.File]::Delete($marker)
        }
        'Nessun ripristino necessario'
    }
}

function New-SBParaMetadata([string]$Id,[string]$Kind,[string]$Title) {
    @{schemaVersion=1;id=$Id;kind=$Kind;title=$Title;status='active'}
}

function Convert-SBParaReferences($Value,[hashtable]$Mapping,[string]$BrainRoot) {
    if($Value -is [Collections.IDictionary]){
        $result=@{}
        foreach($key in $Value.Keys){$newKey=Convert-SBParaReferences ([string]$key) $Mapping $BrainRoot;$result[$newKey]=Convert-SBParaReferences $Value[$key] $Mapping $BrainRoot}
        return $result
    }
    if($Value -is [array]){return ,@($Value|ForEach-Object {Convert-SBParaReferences $_ $Mapping $BrainRoot})}
    if($Value -is [string]){
        foreach($old in $Mapping.Keys|Sort-Object Length -Descending){
            foreach($pair in @(@($old,$Mapping[$old]),@((Join-Path $BrainRoot $old),(Join-Path $BrainRoot $Mapping[$old])))){
                if($Value -eq $pair[0] -or $Value.StartsWith($pair[0]+'/',[StringComparison]::Ordinal) -or $Value.StartsWith($pair[0]+'\',[StringComparison]::Ordinal)){return $pair[1]+$Value.Substring($pair[0].Length)}
            }
        }
    }
    $Value
}

function Get-SBParaReferenceOperations($Config,[hashtable]$Mapping) {
    $paths=@((Join-Path $Config.brainRoot 'inventory.json'))
    $registry=Read-SBJson (Join-Path $Config.coordinationRoot 'workstations.json') @{}
    $runtimeRoots=@($Config.runtimeRoot)+@($registry.Values|ForEach-Object runtimeRoot)|Sort-Object -Unique
    foreach($runtime in $runtimeRoots){
        Assert-SBPlainPath $runtime
        foreach($name in @('state.json','inventory.json','workstation.json')){$paths+=Join-Path $runtime $name}
    }
    foreach($path in $paths|Sort-Object -Unique){
        if(!(Test-Path -LiteralPath $path -PathType Leaf)){continue}
        $original=Read-SBJson $path $null
        $value=Convert-SBParaReferences $original $Mapping $Config.brainRoot
        if((Split-Path $path -Leaf) -eq 'state.json'){
            # Baseline keys use an absolute file path followed by |snapshot.
            $managed=@{}
            foreach($key in $original.managed.Keys){
                $parts=$key -split '\|',2
                $new=Convert-SBParaReferences $parts[0] $Mapping $Config.brainRoot
                $managed[$new+'|'+$parts[1]]=$original.managed[$key]
            }
            $value.managed=$managed
        }

        $text=ConvertTo-SBJson $value
        if((Get-SBTextHash $text) -ne (Get-SBFileHash $path)){@{path=$path;expected=(Get-SBFileHash $path);bytes=[Text.Encoding]::UTF8.GetBytes($text)}}
    }
}

function Remove-SBParaEmptyTree([string]$Path,[string]$BrainRoot) {
    $relative=[IO.Path]::GetRelativePath($BrainRoot,$Path)
    [void](Resolve-SBParaPath $BrainRoot $relative)
    $dirs=@(Get-ChildItem -LiteralPath $Path -Recurse -Directory -Force|Sort-Object {$_.FullName.Length} -Descending)+@(Get-Item -LiteralPath $Path)
    foreach($dir in $dirs){
        Assert-SBPlainPath $dir.FullName
        if(!@(Get-ChildItem -LiteralPath $dir.FullName -Force).Count){Assert-SBWriteGuard;[IO.Directory]::Delete($dir.FullName);Wait-SBDirectoryGone $dir.FullName}
    }
}
# On Windows a deleted directory stays visible while another process (indexer, antivirus, a parallel suite) holds a handle on it
# (delete pending). An immediate Restore then saw the old path as an existing destination (#525). Wait briefly until it is gone.
function Wait-SBDirectoryGone([string]$Path,[int]$TimeoutMs=3000) {
    $watch=[Diagnostics.Stopwatch]::StartNew()
    while([IO.Directory]::Exists($Path) -and $watch.ElapsedMilliseconds -lt $TimeoutMs){Start-Sleep -Milliseconds 20}
}

Export-ModuleMember -Function @(
    'Resolve-SBParaPath',
    'Get-SBParaEntities',
    'Get-SBParaIndex',
    'Update-SBParaIndex',
    'Invoke-SBParaTransaction',
    'Restore-SBParaTransaction',
    'New-SBParaMetadata',
    'Convert-SBParaReferences',
    'Get-SBParaReferenceOperations',
    'Remove-SBParaEmptyTree'
)
