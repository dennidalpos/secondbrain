#requires -Version 7.5
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
try {
    if ([Console]::OutputEncoding.CodePage -ne 65001) {
        [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
    }
} catch { }
$OutputEncoding = [Text.UTF8Encoding]::new($false)
$script:SBWriteGuard = $null

function Set-SBWriteGuard([scriptblock]$Guard) { $script:SBWriteGuard=$Guard }
function Assert-SBWriteGuard { if($script:SBWriteGuard){ & $script:SBWriteGuard } }

function Get-SBHash([byte[]]$Bytes) {
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes))
}
function Get-SBTextHash([string]$Text) { Get-SBHash ([Text.Encoding]::UTF8.GetBytes($Text)) }
# Versione del prodotto: unica fonte è il file VERSION nella radice del clone.
function Get-SBVersion {
    $path=Join-Path $PSScriptRoot '../VERSION'
    if(!(Test-Path -LiteralPath $path -PathType Leaf)){throw 'File VERSION mancante'}
    (Get-Content -LiteralPath $path -Raw).Trim()
}

function Read-SBText([string]$Path) { [IO.File]::ReadAllText($Path, [Text.UTF8Encoding]::new($false, $true)) }
function Get-SBFileHash([string]$Path) {
    if ([IO.File]::Exists($Path)) { Get-SBHash ([IO.File]::ReadAllBytes($Path)) } else { 'absent' }
}
function Read-SBJson([string]$Path, $Default) {
    if (!(Test-Path -LiteralPath $Path)) { return $Default }
    # Su una share la sostituzione atomica di un file da parte di un altro host puo dare una violazione di condivisione transitoria.
    for ($attempt = 1; $attempt -le 5; $attempt++) {
        try { return (Read-SBText $Path | ConvertFrom-Json -AsHashtable -DateKind String) }
        catch [IO.IOException] {
            if (($_.Exception.HResult -band 0xffff) -notin @(32, 33) -or $attempt -eq 5) { throw }
            Start-Sleep -Milliseconds (50 * $attempt)
        }
    }
}
function ConvertTo-SBComparablePath([string]$Path) {
    # Forma di confronto per alias dello stesso percorso: maiuscole, drive mappato o condivisione amministrativa locale e UNC con nome host breve o FQDN.
    $full = [IO.Path]::GetFullPath($Path).TrimEnd('\','/')
    if ($full -match '^(?<drive>[A-Za-z]):(?<rest>.*)$') {
        $mapped = Get-PSDrive -Name $Matches.drive -PSProvider FileSystem -ErrorAction SilentlyContinue
        if ($mapped -and $mapped.DisplayRoot) { $full = $mapped.DisplayRoot.TrimEnd('\') + $Matches.rest }
    }
    if ($full -match '^\\\\(?<srv>[^\\]+)(?<rest>.*)$') {
        $server = $Matches.srv; $rest = $Matches.rest
        $isLocal = $server -in @('localhost', '127.0.0.1', '::1') -or ($server -split '\.')[0] -ieq [Environment]::MachineName
        if ($isLocal -and $rest -match '^\\(?<d>[A-Za-z])\$(?<tail>.*)$') { $full = $Matches.d + ':' + $Matches.tail }
        else {
            if ($server -notmatch '^\d{1,3}(\.\d{1,3}){3}$' -and $server -notmatch ':') { $server = ($server -split '\.')[0] }
            $full = '\\' + $server + $rest
        }
    }
    $full.ToLowerInvariant()
}
function Test-SBSamePath([string]$First, [string]$Second) {
    (ConvertTo-SBComparablePath $First) -ceq (ConvertTo-SBComparablePath $Second)
}
function Convert-SBBrainAlias([string]$Path, [string]$FromRoot, [string]$ToRoot) {
    # Riscrive un percorso registrato da un altro host (alias UNC, drive mappato) sulla radice del cervello corrente.
    if (!$Path -or !$FromRoot) { return $Path }
    $from = [IO.Path]::GetFullPath($FromRoot).TrimEnd('\','/'); $to = [IO.Path]::GetFullPath($ToRoot).TrimEnd('\','/')
    $full = [IO.Path]::GetFullPath($Path)
    if ($full.TrimEnd('\','/').Equals($from, [StringComparison]::OrdinalIgnoreCase)) { return $to }
    if ($full.StartsWith($from + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { return $to + $full.Substring($from.Length) }
    $Path
}
function ConvertTo-SBStableValue($Value) {
    if ($Value -is [Collections.IDictionary]) {
        $sorted = [ordered]@{}
        foreach ($key in $Value.Keys | Sort-Object) { $sorted[$key] = ConvertTo-SBStableValue $Value[$key] }
        return $sorted
    }
    if ($Value -is [array] -or $Value -is [Collections.IList]) {
        $items = @(); foreach ($item in $Value) { $items += ,(ConvertTo-SBStableValue $item) }
        return ,$items
    }
    return $Value
}
function ConvertTo-SBJson($Value) { (ConvertTo-SBStableValue $Value | ConvertTo-Json -Depth 40).Replace("`r`n","`n") + "`n" }
$script:SBBrainRootFull = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')).TrimEnd('\','/')
function Assert-SBPlainPath([string]$Path, [hashtable]$VerifiedAncestors) {
    # VerifiedAncestors (opzionale, a cura del chiamante per un ciclo su molti file): directory antenate gia risultate
    # senza reparse point in questa esecuzione; il percorso indicato e controllato sempre, solo gli antenati si saltano.
    $current = [IO.Path]::GetFullPath($Path)
    # Sotto il cervello la verifica si ferma alla sua radice: la posizione scelta per l'installazione
    # (OneDrive, junction, DFS) non e un reindirizzamento introdotto dentro i dati.
    $brainRoot = $script:SBBrainRootFull
    $boundary = $brainRoot + [IO.Path]::DirectorySeparatorChar
    $underBrain = $current.StartsWith($boundary, [StringComparison]::OrdinalIgnoreCase) -or $current.TrimEnd('\','/') -ieq $brainRoot
    $ancestors = $null
    if ($null -ne $VerifiedAncestors) { $ancestors = [Collections.Generic.List[string]]::new() }
    $first = $true
    while ($current) {
        if ($underBrain -and $current.TrimEnd('\','/') -ieq $brainRoot) { break }
        if (!$first -and $null -ne $VerifiedAncestors -and $VerifiedAncestors.ContainsKey($current)) { break }
        if (Test-Path -LiteralPath $current) {
            if ((Get-Item -LiteralPath $current -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Reparse point non scrivibile: $current"
            }
        }
        if (!$first -and $null -ne $ancestors) { $ancestors.Add($current) }
        $first = $false
        $current = [IO.Path]::GetDirectoryName($current)
    }
    if ($null -ne $ancestors) { foreach ($ancestor in $ancestors) { $VerifiedAncestors[$ancestor] = $true } }
}
$script:SBWriteGeneration = 0
function Get-SBWriteGeneration { $script:SBWriteGeneration }
function Get-SBGitFileState([string]$Path) {
    # Sola lettura: $null se il file non esiste, Git non e disponibile o il file non e tracciato (dossier ignorati, IDE globali, config MCP).
    $gitExe = (Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1).Source
    if (!$gitExe) { return $null }
    $full = [IO.Path]::GetFullPath($Path)
    $dir = [IO.Path]::GetDirectoryName($full)
    if (!(Test-Path -LiteralPath $full -PathType Leaf)) { return $null }
    $name = [IO.Path]::GetFileName($full)
    $null = & $gitExe -C $dir ls-files --error-unmatch -- $name 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    $status = (& $gitExe -C $dir status --porcelain -- $name 2>$null) -join ''
    $commit = (& $gitExe -C $dir rev-parse HEAD 2>$null | Select-Object -First 1)
    $blob = (& $gitExe -C $dir rev-parse "HEAD:./$name" 2>$null | Select-Object -First 1)
    @{ dirty = ($status.Length -gt 0); commit = [string]$commit; blob = [string]$blob }
}
function Test-SBBackupInGit([string]$MetadataPath) {
    # Sola lettura: true solo se il .bin di un .bin.json e un duplicato di Git (copia presente con SHA-256 pari a previousHash, file origine tracciato e pulito, contenuto presente come blob).
    $info = $null; try { $info = Read-SBJson $MetadataPath $null } catch { return $false }
    if ($null -eq $info -or !$info.path -or !$info.backup) { return $false }
    $backup = [string]$info.backup
    if (!(Test-Path -LiteralPath $backup -PathType Leaf)) { return $false }
    if ($info.previousHash -and (Get-SBFileHash $backup) -ne [string]$info.previousHash) { return $false }
    $git = Get-SBGitFileState ([string]$info.path)
    if ($null -eq $git -or $git.dirty) { return $false }
    $gitExe = (Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1).Source
    $full = [IO.Path]::GetFullPath([string]$info.path)
    $dir = [IO.Path]::GetDirectoryName($full)
    $pathArgument = '--path=' + [IO.Path]::GetFileName($full)
    $blob = (& $gitExe -C $dir hash-object $pathArgument -- $backup 2>$null | Select-Object -First 1)
    if (!$blob) { return $false }
    $null = & $gitExe -C $dir cat-file -e $blob 2>$null
    $LASTEXITCODE -eq 0
}
function Write-SBFile {
    param([string]$Path, [byte[]]$Bytes, [string]$ExpectedHash, [string]$BackupRoot, [switch]$BackupDirty)
    Assert-SBWriteGuard
    Assert-SBPlainPath $Path
    if ((Get-SBFileHash $Path) -ne $ExpectedHash) { throw "Modifica concorrente: $Path" }
    if ((Get-SBHash $Bytes) -eq $ExpectedHash) { return $false }
    # Git salva i file tracciati: pulito = niente .bin (commit e blob registrati); sporco = rifiuto, salvo -BackupDirty (file rigenerati: resta il .bin).
    $git = Get-SBGitFileState $Path
    if ($null -ne $git -and $git.dirty -and !$BackupDirty) {
        throw "File tracciato con modifiche non committate: $Path. Committa o metti da parte (git stash) le modifiche al file, poi ripeti l'operazione."
    }
    $gitOnly = ($null -ne $git -and !$git.dirty)
    $script:SBWriteGeneration++
    $parent = Split-Path -Parent $Path
    [IO.Directory]::CreateDirectory($parent) | Out-Null
    $temp = Join-Path $parent ('.secondbrain-' + [guid]::NewGuid().ToString('N') + '.tmp')
    $backup = $null
    $completed=$false
    [IO.Directory]::CreateDirectory($BackupRoot)|Out-Null
    $stageRecordPath=Join-Path $BackupRoot ([guid]::NewGuid().ToString('N')+'.stage')
    $stageRecord=@{schemaVersion=1;path=[IO.Path]::GetFullPath($Path);staging=$temp;expectedHash=$ExpectedHash;status='writing'}
    [IO.File]::WriteAllText($stageRecordPath,(ConvertTo-SBJson $stageRecord),[Text.UTF8Encoding]::new($false))
    try {
        $stream = [IO.FileStream]::new($temp, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        try { $stream.Write($Bytes); $stream.Flush($true) } finally { $stream.Dispose() }
        if ((Get-SBFileHash $temp) -ne (Get-SBHash $Bytes)) { throw 'Readback staging fallito' }
        if ((Get-SBFileHash $Path) -ne $ExpectedHash) { throw "Modifica concorrente: $Path" }
        Assert-SBWriteGuard
        if ($ExpectedHash -ne 'absent') {
            [IO.Directory]::CreateDirectory($BackupRoot) | Out-Null
            $backup = Join-Path $BackupRoot ([guid]::NewGuid().ToString('N') + '.bin')
            # Replace conserva esattamente il file sostituito per rilevare anche gare nell'ultima finestra.
            $localBackup = Join-Path $parent ('.secondbrain-' + [guid]::NewGuid().ToString('N') + '.recovery')
            $stageRecord.recovery=$localBackup
            [IO.File]::Replace($temp, $Path, $localBackup)
            if ($gitOnly) {
                $actual = Get-SBFileHash $localBackup
                $backup = $null
                $record = @{ schemaVersion = 1; path = $Path; previousHash = $actual; deployedHash = Get-SBHash $Bytes; gitCommit = $git.commit; gitBlob = $git.blob }
                [IO.File]::WriteAllText((Join-Path $BackupRoot ([guid]::NewGuid().ToString('N') + '.git.json')), (ConvertTo-SBJson $record), [Text.UTF8Encoding]::new($false))
                if ($actual -ne $ExpectedHash) { throw "Gara di scrittura rilevata; copia concorrente conservata: $localBackup" }
                [IO.File]::Delete($localBackup)
            } else {
                [IO.File]::Copy($localBackup, $backup)
                $actual = Get-SBFileHash $backup
                if ($actual -ne (Get-SBFileHash $localBackup)) { throw "Backup non verificato; recupero locale: $localBackup" }
                $metadata = @{ path = $Path; previousHash = $actual; deployedHash = Get-SBHash $Bytes; backup = $backup }
                [IO.File]::WriteAllText($backup + '.json', (ConvertTo-SBJson $metadata), [Text.UTF8Encoding]::new($false))
                [IO.File]::Delete($localBackup)
            }
            if ($actual -ne $ExpectedHash) {
                # Non tentare un rollback con Copy(overwrite): un editor esterno
                # potrebbe avere cambiato ancora il file dopo il controllo hash.
                throw "Gara di scrittura rilevata; copia concorrente conservata: $backup"
            }
        } else { [IO.File]::Move($temp, $Path) }
        if ((Get-SBFileHash $Path) -ne (Get-SBHash $Bytes)) { throw "Readback destinazione fallito: $Path" }
        $completed=$true
        return $true
    } finally {
        $stageRecord.status=if($completed){'completed'}else{'interrupted'}
        if([IO.File]::Exists($temp)){
            if($completed){[IO.File]::Delete($temp)}else{Write-Warning ('Staging transazionale conservato: '+$temp)}
        }
        [IO.File]::WriteAllText($stageRecordPath,(ConvertTo-SBJson $stageRecord),[Text.UTF8Encoding]::new($false))
    }
}
function Get-SBStageRetention([string[]]$BackupRoot,[int]$OlderThanDays=90) {
    # Sola lettura: elenca i record .stage completati piu vecchi della soglia in uno o piu backupRoot (anche nelle sottocartelle). Backup .bin/.bin.json, staging interrotti e record illeggibili non sono mai candidati.
    if($OlderThanDays -lt 1){throw 'OlderThanDays deve essere almeno 1'}
    $cutoff=[DateTimeOffset]::UtcNow.AddDays(-$OlderThanDays)
    $candidates=@();$retained=@{recent=0;notCompleted=0;unreadable=0};$seenRecords=@{}
    foreach($root in @($BackupRoot|Where-Object {$_}|Sort-Object -Unique)){
        if(!(Test-Path -LiteralPath $root -PathType Container)){continue}
        foreach($file in @(Get-ChildItem -LiteralPath $root -Filter '*.stage' -File -Recurse)){
            if($seenRecords.ContainsKey($file.FullName)){continue};$seenRecords[$file.FullName]=$true
            $record=$null
            try{$record=Read-SBJson $file.FullName $null}catch{}
            if($record -isnot [Collections.IDictionary] -or $record.schemaVersion -ne 1 -or !$record.ContainsKey('status')){$retained.unreadable++;continue}
            if($record.status -ne 'completed'){$retained.notCompleted++;continue}
            if([DateTimeOffset]$file.LastWriteTimeUtc -gt $cutoff){$retained.recent++;continue}
            $candidates+=@{path=$file.FullName;sha256=(Get-SBFileHash $file.FullName);lastWriteUtc=$file.LastWriteTimeUtc.ToString('o');target=[string]$record.path}
        }
    }
    @{olderThanDays=$OlderThanDays;candidates=@($candidates|Sort-Object path);retained=$retained}
}
function Get-SBRuntimeRetention([string]$BrainRoot,[string[]]$ProtectedPaths=@(),[int]$OlderThanDays=90) {
    # Sola lettura: inventario delle voci di primo livello sotto .runtime con eta (ultima scrittura), dimensione, riferimenti testuali e protezione.
    # Non elenca file da rimuovere e non segue reparse point: la rimozione resta possibile solo con un manifest revisionato (cleanup.ps1 -ManifestPath).
    if($OlderThanDays -lt 1){throw 'OlderThanDays deve essere almeno 1'}
    $runtime=[IO.Path]::GetFullPath((Join-Path $BrainRoot '.runtime')).TrimEnd('\','/')
    if(!(Test-Path -LiteralPath $runtime -PathType Container)){return @{olderThanDays=$OlderThanDays;entries=@();reviewable=@();totalBytes=0L}}
    $cutoff=[DateTime]::UtcNow.AddDays(-$OlderThanDays)
    $fixed=@{'access'='sessioni e lock di accesso';'hosts'='configurazione e backup delle postazioni';'cleanup'='registro delle pulizie (prova di recuperabilita)';'state.json'='stato operativo';'para-transaction.json'='marker di transazione pendente'}
    $byConfig=@{}
    foreach($path in @($ProtectedPaths|Where-Object {$_})){
        $full=[IO.Path]::GetFullPath($path)
        if($full.StartsWith($runtime+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){$byConfig[($full.Substring($runtime.Length+1) -split '[\\/]')[0].ToLowerInvariant()]=$true}
    }
    $options=[IO.EnumerationOptions]::new();$options.RecurseSubdirectories=$true;$options.IgnoreInaccessible=$true;$options.AttributesToSkip=[IO.FileAttributes]::ReparsePoint
    $entries=@()
    foreach($item in @(Get-ChildItem -LiteralPath $runtime -Force|Sort-Object Name)){
        $count=0;$size=0L;$newest=[DateTime]::MinValue;$kind='file';$followed=$true
        if($item.Attributes -band [IO.FileAttributes]::ReparsePoint){$kind='reparse-point';$followed=$false}
        elseif($item.PSIsContainer){
            $kind='directory'
            foreach($file in ([IO.DirectoryInfo]::new($item.FullName)).EnumerateFiles('*',$options)){$count++;$size+=$file.Length;if($file.LastWriteTimeUtc -gt $newest){$newest=$file.LastWriteTimeUtc}}
        }else{$count=1;$size=$item.Length;$newest=$item.LastWriteTimeUtc}
        if($newest -eq [DateTime]::MinValue){$newest=$item.LastWriteTimeUtc}
        $reason=$null
        if(!$followed){$reason='reparse point: non seguito'}
        elseif($fixed.ContainsKey($item.Name.ToLowerInvariant())){$reason=$fixed[$item.Name.ToLowerInvariant()]}
        elseif($byConfig.ContainsKey($item.Name.ToLowerInvariant())){$reason='percorso della configurazione o del registro postazioni'}
        $classification=Get-SBRuntimeCategory $item.Name ([bool]$reason)
        $entries+=@{name=$item.Name;kind=$kind;files=$count;bytes=$size;newestWriteUtc=$newest.ToString('o');ageDays=[int][Math]::Floor(([DateTime]::UtcNow-$newest).TotalDays);olderThanThreshold=($newest -lt $cutoff);protected=[bool]$reason;protectedReason=$reason;category=$classification.category;recovery=$classification.recovery;references=@{mentions=0;samples=@()}}
    }
    # Riferimenti testuali a .runtime/<voce> nelle superfici versionate e nei dossier (file di testo fino a 2 MB).
    $names=@($entries|ForEach-Object {[regex]::Escape($_.name)})
    if($names.Count){
        $pattern=[regex]::new('\.runtime[\\/]+(?<n>'+($names -join '|')+')(?![A-Za-z0-9_-])',[Text.RegularExpressions.RegexOptions]::IgnoreCase)
        $byName=@{};foreach($entry in $entries){$byName[$entry.name.ToLowerInvariant()]=$entry}
        $surfaces=@('README.md','AGENTS.md','docs','scripts','direttive','config','02-areas','01-projects','03-resources')
        $scan=[IO.EnumerationOptions]::new();$scan.RecurseSubdirectories=$true;$scan.IgnoreInaccessible=$true;$scan.AttributesToSkip=[IO.FileAttributes]::ReparsePoint
        $textExtensions=@('.md','.json','.ps1','.psm1','.txt')
        $files=@()
        foreach($surface in $surfaces){
            $target=Join-Path $BrainRoot $surface
            if(Test-Path -LiteralPath $target -PathType Leaf){$files+=[IO.FileInfo]::new($target)}
            elseif(Test-Path -LiteralPath $target -PathType Container){$files+=@(([IO.DirectoryInfo]::new($target)).EnumerateFiles('*',$scan))}
        }
        foreach($file in $files){
            if($file.Extension.ToLowerInvariant() -notin $textExtensions -or $file.Length -gt 2MB){continue}
            $text=$null;try{$text=[IO.File]::ReadAllText($file.FullName)}catch{continue}
            $seen=@{}
            foreach($match in $pattern.Matches($text)){
                $entry=$byName[$match.Groups['n'].Value.ToLowerInvariant()]
                if(!$entry){continue}
                $entry.references.mentions++
                if(!$seen.ContainsKey($entry.name)){$seen[$entry.name]=$true;if($entry.references.samples.Count -lt 5){$entry.references.samples+=$file.FullName.Substring($BrainRoot.TrimEnd('\','/').Length+1).Replace('\','/')}}
            }
        }
    }
    $byCategory=[ordered]@{}
    foreach($group in @($entries|Group-Object {$_.category})){$byCategory[$group.Name]=@{entries=$group.Count;files=[long](($group.Group|Measure-Object files -Sum).Sum);bytes=[long](($group.Group|Measure-Object bytes -Sum).Sum)}}
    $entryBytes=0L;foreach($e in $entries){$entryBytes+=[long]$e.bytes}
    @{olderThanDays=$OlderThanDays;entries=$entries;reviewable=@($entries|Where-Object {!$_.protected -and $_.olderThanThreshold}|ForEach-Object {$_.name});totalBytes=[long]$entryBytes;byCategory=$byCategory}
}
# Classificazione delle voci di primo livello di .runtime: protected (configurazione/accessi), evidence (prove da tenere), backup (recuperi), regenerable (si ricrea), working (lavoro temporaneo di agent da verificare).
function Get-SBRuntimeCategory([string]$Name,[bool]$IsProtected) {
    $key=$Name.ToLowerInvariant()
    if($IsProtected){return @{category='protected';recovery='non rimuovere: configurazione, accessi o stato attivo'}}
    if($key -eq 'tests'){return @{category='regenerable';recovery='si ricrea rieseguendo le suite test-secondbrain*.ps1'}}
    if($key -eq 'mcp-handshake'){return @{category='regenerable';recovery='si ricrea rieseguendo test-secondbrain-mcp-handshake.ps1'}}
    if($key -in @('cleanup','captures','publication','directives-activation')){return @{category='evidence';recovery='prova o provenienza: non si rigenera identica'}}
    if($key -in @('backups','backup','workstations')){return @{category='backup';recovery='recupero di file gestiti: rimuovere solo con manifest revisionato (cleanup.ps1)'}}
    @{category='working';recovery='lavoro temporaneo: verificare riferimenti e proprietà prima di valutarlo'}
}
# Proposta di pulizia di .runtime (sola lettura): NON è un manifest eseguibile. Elenca cartelle candidate con dimensioni, età, riferimenti e come si ricreano.
function Get-SBRuntimeCleanupProposal([string]$BrainRoot,[string[]]$ProtectedPaths=@(),[int]$OlderThanDays=90,[int]$KeepFixtures=5) {
    $report=Get-SBRuntimeRetention $BrainRoot $ProtectedPaths $OlderThanDays
    $runtime=[IO.Path]::GetFullPath((Join-Path $BrainRoot '.runtime')).TrimEnd('\','/')
    $cutoff=[DateTime]::UtcNow.AddDays(-$OlderThanDays)
    $options=[IO.EnumerationOptions]::new();$options.RecurseSubdirectories=$true;$options.IgnoreInaccessible=$true;$options.AttributesToSkip=[IO.FileAttributes]::ReparsePoint
    $measure={param([string]$Path) $n=0;$b=0L;$t=[DateTime]::MinValue;foreach($f in ([IO.DirectoryInfo]::new($Path)).EnumerateFiles('*',$options)){$n++;$b+=$f.Length;if($f.LastWriteTimeUtc -gt $t){$t=$f.LastWriteTimeUtc}};@{files=$n;bytes=$b;newest=$t}}
    $relative={param([string]$Path) $Path.Substring($runtime.Length+1).Replace('\','/')}
    $candidates=@()
    $entryByName=@{};foreach($entry in $report.entries){$entryByName[$entry.name.ToLowerInvariant()]=$entry}
    $mentions={param([string]$Name) if($entryByName.ContainsKey($Name)){$entryByName[$Name].references.mentions}else{0}}
    # 1. Fixture di test: si tengono le più recenti, il resto si ricrea rieseguendo le suite.
    $testsDir=Join-Path $runtime 'tests'
    if(Test-Path -LiteralPath $testsDir -PathType Container){
        $folders=@(Get-ChildItem -LiteralPath $testsDir -Directory -Force|Where-Object {!($_.Attributes -band [IO.FileAttributes]::ReparsePoint)}|Sort-Object LastWriteTimeUtc -Descending)
        $old=@($folders|Select-Object -Skip $KeepFixtures)
        if($old.Count){
            $files=0;$bytes=0L;foreach($folder in $old){$m=& $measure $folder.FullName;$files+=$m.files;$bytes+=$m.bytes}
            $candidates+=@{path='tests/';category='regenerable';action=('rimuovere '+$old.Count+' cartelle fixture più vecchie su '+$folders.Count+', tenendo le ultime '+$KeepFixtures);folders=$old.Count;files=$files;bytes=$bytes;oldestUtc=($old|Sort-Object LastWriteTimeUtc|Select-Object -First 1).LastWriteTimeUtc.ToString('o');recovery='si ricrea rieseguendo le suite test-secondbrain*.ps1';references=(& $mentions 'tests')}
        }
    }
    # 2. Rapporti dell'handshake MCP oltre soglia.
    $handshake=Join-Path $runtime 'mcp-handshake'
    if(Test-Path -LiteralPath $handshake -PathType Container){
        $oldFiles=@(Get-ChildItem -LiteralPath $handshake -File -Force|Where-Object {$_.LastWriteTimeUtc -lt $cutoff})
        if($oldFiles.Count){$candidates+=@{path='mcp-handshake/';category='regenerable';action=('rimuovere '+$oldFiles.Count+' rapporti oltre '+$OlderThanDays+' giorni');folders=0;files=$oldFiles.Count;bytes=[long](($oldFiles|Measure-Object Length -Sum).Sum);oldestUtc=($oldFiles|Sort-Object LastWriteTimeUtc|Select-Object -First 1).LastWriteTimeUtc.ToString('o');recovery='si ricrea rieseguendo test-secondbrain-mcp-handshake.ps1';references=(& $mentions 'mcp-handshake')}}
    }
    # 3. Per ogni host: ambiente Python delle fonti (rigenerabile) e zip di backup oltre i due più recenti.
    $hostsDir=Join-Path $runtime 'hosts'
    if(Test-Path -LiteralPath $hostsDir -PathType Container){
        foreach($hostDir in Get-ChildItem -LiteralPath $hostsDir -Directory -Force|Where-Object {!($_.Attributes -band [IO.FileAttributes]::ReparsePoint)}){
            $python=Join-Path $hostDir.FullName 'sources/python'
            if(Test-Path -LiteralPath $python -PathType Container){
                $m=& $measure $python
                $candidates+=@{path=(& $relative $python)+'/';category='regenerable';action='rimuovere l''ambiente Python dedicato alle fonti';folders=1;files=$m.files;bytes=$m.bytes;oldestUtc=$m.newest.ToString('o');recovery='si ricrea con sources.ps1 dal lock delle dipendenze';references=0}
            }
            $backupsDir=Join-Path $hostDir.FullName 'backups'
            $zips=@()
            if(Test-Path -LiteralPath $backupsDir -PathType Container){$zips=@(Get-ChildItem -LiteralPath $backupsDir -File -Filter '*.zip' -Force|Sort-Object LastWriteTimeUtc -Descending)}
            $oldZips=@($zips|Select-Object -Skip 2)
            # Backup .bin il cui contenuto esiste come blob in Git (SHA-256 pari a previousHash, file origine tracciato e pulito): duplicati da valutare. Senza blob il .bin e l'unica copia e non e candidato.
            if(Test-Path -LiteralPath $backupsDir -PathType Container){
                $gitBins=@();$gitBytes=0L;$oldestBin=$null
                foreach($meta in Get-ChildItem -LiteralPath $backupsDir -File -Filter '*.bin.json' -Force){
                    $info=$null;try{$info=Read-SBJson $meta.FullName $null}catch{continue}
                    if(!(Test-SBBackupInGit $meta.FullName)){continue}
                    $gitBins+=$meta
                    $gitBytes+=$meta.Length;if(Test-Path -LiteralPath $info.backup -PathType Leaf){$gitBytes+=([IO.FileInfo]::new($info.backup)).Length}
                    if($null -eq $oldestBin -or $meta.LastWriteTimeUtc -lt $oldestBin){$oldestBin=$meta.LastWriteTimeUtc}
                }
                if($gitBins.Count){$candidates+=@{path=(& $relative $backupsDir)+'/*.bin';category='backup';action=('valutare '+$gitBins.Count+' backup .bin di file ora tracciati da Git e puliti (Git ne conserva il contenuto)');folders=0;files=$gitBins.Count;bytes=$gitBytes;oldestUtc=$oldestBin.ToString('o');recovery='il contenuto precedente è recuperabile da Git (git log, git show); rimuovere solo con manifest revisionato (cleanup.ps1 -ManifestPath)';references=0}}
            }
            if($oldZips.Count){$candidates+=@{path=(& $relative $backupsDir)+'/*.zip';category='backup';action=('valutare '+$oldZips.Count+' zip di backup oltre i 2 più recenti (non esiste un restore automatico: verificare il più recente con backup.ps1 -Verify prima)');folders=0;files=$oldZips.Count;bytes=[long](($oldZips|Measure-Object Length -Sum).Sum);oldestUtc=($oldZips|Sort-Object LastWriteTimeUtc|Select-Object -First 1).LastWriteTimeUtc.ToString('o');recovery='copia compressa dei dati locali: tenere almeno uno zip verificato';references=0}}
        }
    }
    # 4. Cartelle di lavoro di agent oltre soglia, non protette e senza riferimenti: solo da valutare.
    foreach($entry in @($report.entries|Where-Object {$_.category -eq 'working' -and !$_.protected -and $_.olderThanThreshold -and $_.references.mentions -eq 0})){
        $candidates+=@{path=$entry.name+'/';category='working';action='valutare la rimozione (lavoro temporaneo senza riferimenti nel repository)';folders=1;files=$entry.files;bytes=$entry.bytes;oldestUtc=$entry.newestWriteUtc;recovery=$entry.recovery;references=0}
    }
    $regenerable=0L;foreach($c in $candidates){if($c.category -eq 'regenerable'){$regenerable+=[long]$c.bytes}}
    @{scope='runtime-cleanup-proposal';applied=$false;generatedAt=[DateTimeOffset]::UtcNow.ToString('o');olderThanDays=$OlderThanDays;keepFixtures=$KeepFixtures;totalBytes=$report.totalBytes;byCategory=$report.byCategory;regenerableCandidateBytes=$regenerable;candidates=$candidates;
        note='Proposta di sola lettura, non un manifest eseguibile. Nessuna cartella è stata rimossa. L''applicazione richiede una richiesta esplicita e un perimetro concreto; i file con backup passano da cleanup.ps1 -ManifestPath.'}
}
# Pulizia delle sole cartelle rigenerabili di .runtime (fixture di test oltre le ultime N, ambiente Python delle fonti): perimetro fisso, mai selezione per nome libero.
function Get-SBRegenerableRuntimeTargets([string]$BrainRoot,[string[]]$ProtectedPaths=@(),[int]$KeepFixtures=5,[int]$MinAgeMinutes=10) {
    $runtime=[IO.Path]::GetFullPath((Join-Path $BrainRoot '.runtime')).TrimEnd('\','/')
    $sep=[IO.Path]::DirectorySeparatorChar
    $protected=@($ProtectedPaths|Where-Object {$_}|ForEach-Object {[IO.Path]::GetFullPath($_).TrimEnd('\','/')})
    $options=[IO.EnumerationOptions]::new();$options.RecurseSubdirectories=$true;$options.IgnoreInaccessible=$true;$options.AttributesToSkip=[IO.FileAttributes]::ReparsePoint
    $candidates=@()
    $testsDir=Join-Path $runtime 'tests'
    if(Test-Path -LiteralPath $testsDir -PathType Container){
        $folders=@(Get-ChildItem -LiteralPath $testsDir -Directory -Force|Where-Object {!($_.Attributes -band [IO.FileAttributes]::ReparsePoint)}|Sort-Object LastWriteTimeUtc -Descending)
        foreach($folder in @($folders|Select-Object -Skip $KeepFixtures)){$candidates+=@{path=$folder.FullName;kind='fixture-test';recovery='si ricrea rieseguendo le suite test-secondbrain*.ps1'}}
    }
    $hostsDir=Join-Path $runtime 'hosts'
    if(Test-Path -LiteralPath $hostsDir -PathType Container){
        foreach($hostDir in @(Get-ChildItem -LiteralPath $hostsDir -Directory -Force|Where-Object {!($_.Attributes -band [IO.FileAttributes]::ReparsePoint)})){
            $python=Join-Path $hostDir.FullName 'sources/python'
            if(Test-Path -LiteralPath $python -PathType Container){$candidates+=@{path=[IO.Path]::GetFullPath($python);kind='python-sources';recovery='si ricrea con sources.ps1 dal lock delle dipendenze'}}
        }
    }
    $targets=@();$skipped=@()
    foreach($candidate in $candidates){
        $path=$candidate.path;$item=Get-Item -LiteralPath $path -Force
        $relative=$path.Substring($runtime.Length+1).Replace('\','/')
        $reason=$null
        if($item.Attributes -band [IO.FileAttributes]::ReparsePoint){$reason='reparse point: non seguito'}
        elseif(@($protected|Where-Object {$_ -ieq $path -or $_.StartsWith($path+$sep,[StringComparison]::OrdinalIgnoreCase)}).Count){$reason='contiene percorsi della configurazione o degli accessi'}
        $files=0;$bytes=0L;$newest=$item.LastWriteTimeUtc
        if(!$reason){
            foreach($file in ([IO.DirectoryInfo]::new($path)).EnumerateFiles('*',$options)){$files++;$bytes+=$file.Length;if($file.LastWriteTimeUtc -gt $newest){$newest=$file.LastWriteTimeUtc}}
            if($MinAgeMinutes -gt 0 -and $newest -gt [DateTime]::UtcNow.AddMinutes(-$MinAgeMinutes)){$reason="scritta negli ultimi $MinAgeMinutes minuti: potrebbe essere in uso"}
        }
        $entry=@{path=$path;relative=$relative;kind=$candidate.kind;files=$files;bytes=$bytes;newestWriteUtc=$newest.ToString('o');recovery=$candidate.recovery}
        if($reason){$entry.reason=$reason;$skipped+=$entry}else{$targets+=$entry}
    }
    $totalBytes=0L;$totalFiles=0L;foreach($target in $targets){$totalBytes+=$target.bytes;$totalFiles+=$target.files}
    @{targets=@($targets);skipped=@($skipped);keepFixtures=$KeepFixtures;minAgeMinutes=$MinAgeMinutes;bytes=$totalBytes;files=$totalFiles}
}
function Remove-SBRuntimeTree([string]$Path,[string]$BrainRoot) {
    # Rimuove una cartella sotto .runtime senza seguire junction/symlink (si scollegano soltanto) e togliendo l'attributo di sola lettura (oggetti Git).
    $runtime=[IO.Path]::GetFullPath((Join-Path $BrainRoot '.runtime')).TrimEnd('\','/')
    $full=[IO.Path]::GetFullPath($Path).TrimEnd('\','/')
    if(!$full.StartsWith($runtime+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Percorso fuori da .runtime'}
    $root=Get-Item -LiteralPath $full -Force
    if($root.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Reparse point non rimovibile con questo passo'}
    $stack=[Collections.Generic.Stack[string]]::new();$stack.Push($full)
    while($stack.Count){
        $directory=[IO.DirectoryInfo]::new($stack.Pop())
        foreach($entry in $directory.EnumerateFileSystemInfos()){
            if($entry.Attributes -band [IO.FileAttributes]::ReparsePoint){
                if($entry.Attributes -band [IO.FileAttributes]::Directory){[IO.Directory]::Delete($entry.FullName)}else{[IO.File]::Delete($entry.FullName)}
            }elseif($entry.Attributes -band [IO.FileAttributes]::Directory){$stack.Push($entry.FullName)}
            elseif($entry.Attributes -band [IO.FileAttributes]::ReadOnly){$entry.Attributes=$entry.Attributes -band (-bnot [IO.FileAttributes]::ReadOnly)}
        }
    }
    [IO.Directory]::Delete($full,$true)
}
function New-SBGitStartInfo([string]$Root, [string[]]$GitArguments) {
    $start = [Diagnostics.ProcessStartInfo]::new('git')
    $start.UseShellExecute = $false; $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true; $start.RedirectStandardError = $true
    # Git emette UTF-8: senza codifica esplicita i percorsi accentati arrivano alterati.
    $start.StandardOutputEncoding = [Text.UTF8Encoding]::new($false); $start.StandardErrorEncoding = [Text.UTF8Encoding]::new($false)
    $prefix = @('--no-optional-locks','-c','core.fsmonitor=false','-c','core.quotepath=false')
    # Un cervello su share ha spesso un proprietario diverso dall'utente corrente: git rifiuta il percorso ("dubious ownership").
    # Il consenso e limitato al solo cervello, mai ai checkout dei prodotti.
    $brainRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    if ($Root.StartsWith('\\') -and (Test-SBSamePath $Root $brainRoot)) { $prefix += @('-c', ('safe.directory=' + ($Root -replace '\\', '/'))) }
    foreach ($arg in $prefix + @('-C',$Root) + $GitArguments) { $start.ArgumentList.Add($arg) }
    $start
}
function Invoke-SBGit([string]$Root, [string[]]$GitArguments, [int]$TimeoutMs = 10000, [switch]$PreserveOutput) {
    $process = [Diagnostics.Process]::Start((New-SBGitStartInfo $Root $GitArguments))
    try {
        $stdout = $process.StandardOutput.ReadToEndAsync(); $stderr = $process.StandardError.ReadToEndAsync()
        if (!$process.WaitForExit($TimeoutMs)) { $process.Kill($true); throw "Git timeout: $Root" }
        $output=$stdout.GetAwaiter().GetResult()
        @{ code = $process.ExitCode; output = $(if($PreserveOutput){$output}else{$output.Trim()}); error = $stderr.GetAwaiter().GetResult().Trim() }
    } finally { $process.Dispose() }
}
# Tipo e dimensione di molti oggetti con un solo processo (cat-file --batch-check): oid -> @{type;size}; oggetti assenti omessi.
function Get-SBGitObjectInfo([string]$Root, [string[]]$ObjectIds, [int]$TimeoutMs = 120000) {
    $info = @{}
    if (!$ObjectIds.Count) { return $info }
    $start = New-SBGitStartInfo $Root @('cat-file','--batch-check')
    $start.RedirectStandardInput = $true; $start.StandardInputEncoding = [Text.UTF8Encoding]::new($false)
    $process = [Diagnostics.Process]::Start($start)
    try {
        $stdout = $process.StandardOutput.ReadToEndAsync(); $stderr = $process.StandardError.ReadToEndAsync()
        $process.StandardInput.Write((($ObjectIds -join "`n") + "`n")); $process.StandardInput.Close()
        if (!$process.WaitForExit($TimeoutMs)) { $process.Kill($true); throw "Git timeout: $Root" }
        foreach ($line in $stdout.GetAwaiter().GetResult() -split "`n") {
            if ($line -match '^([a-f0-9]{40,64}) (blob|tree|commit|tag) (\d+)\s*$') { $info[$Matches[1]] = @{ type = $Matches[2]; size = [long]$Matches[3] } }
        }
        if ($process.ExitCode -ne 0) { throw ('Git cat-file --batch-check non riuscito: ' + $stderr.GetAwaiter().GetResult().Trim()) }
    } finally { $process.Dispose() }
    $info
}
# Contenuto di molti blob con un solo processo (cat-file --batch), emesso nell ordine di Entries in streaming (usare in pipeline).
# Ogni voce: @{Oid;Skip}. Le voci con Skip non vengono lette (Bytes nullo). Emette @{Entry;Bytes;Missing}.
function Read-SBGitBlobs([string]$Root, [object[]]$Entries, [int]$ReadTimeoutMs = 60000) {
    if (!('SBGitBatchReader' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Text;
public sealed class SBGitBatchReader {
    readonly Stream stream; readonly int timeoutMs; readonly byte[] buffer = new byte[65536]; int position, length;
    public SBGitBatchReader(Stream stream, int timeoutMs) { this.stream = stream; this.timeoutMs = timeoutMs; }
    bool Fill() {
        var task = stream.ReadAsync(buffer, 0, buffer.Length);
        if (!task.Wait(timeoutMs)) throw new TimeoutException("git cat-file --batch");
        length = task.Result; position = 0; return length > 0;
    }
    public string ReadLine() {
        var text = new StringBuilder();
        while (true) {
            if (position >= length && !Fill()) return text.Length == 0 ? null : text.ToString();
            byte value = buffer[position++];
            if (value == 10) return text.ToString();
            text.Append((char)value);
        }
    }
    public byte[] ReadBytes(long count) {
        var result = new byte[count]; long offset = 0;
        while (offset < count) {
            if (position >= length && !Fill()) throw new EndOfStreamException("git cat-file --batch");
            int chunk = (int)Math.Min(count - offset, length - position);
            Buffer.BlockCopy(buffer, position, result, (int)offset, chunk); position += chunk; offset += chunk;
        }
        return result;
    }
}
'@
    }
    $wanted = @($Entries | Where-Object { !$_.Skip } | ForEach-Object { $_.Oid })
    $process = $null
    try {
        if ($wanted.Count) {
            $start = New-SBGitStartInfo $Root @('cat-file','--batch')
            $start.RedirectStandardInput = $true; $start.StandardInputEncoding = [Text.UTF8Encoding]::new($false)
            $process = [Diagnostics.Process]::Start($start)
            $stderr = $process.StandardError.ReadToEndAsync()
            $writer = $process.StandardInput.WriteAsync((($wanted -join "`n") + "`n"))
            $reader = [SBGitBatchReader]::new($process.StandardOutput.BaseStream, $ReadTimeoutMs)
        }
        foreach ($entry in $Entries) {
            if ($entry.Skip) { [pscustomobject]@{ Entry = $entry; Bytes = $null; Missing = $false }; continue }
            $header = $reader.ReadLine()
            if ($null -eq $header) { throw 'Git cat-file --batch: flusso interrotto' }
            if ($header -match '^[a-f0-9]{40,64} missing$') { [pscustomobject]@{ Entry = $entry; Bytes = $null; Missing = $true }; continue }
            if ($header -notmatch '^([a-f0-9]{40,64}) \S+ (\d+)$' -or $Matches[1] -ne $entry.Oid) { throw "Git cat-file --batch: intestazione inattesa: $header" }
            $bytes = $reader.ReadBytes([long]$Matches[2]); $null = $reader.ReadBytes(1)
            [pscustomobject]@{ Entry = $entry; Bytes = $bytes; Missing = $false }
        }
        if ($process) { $writer.Wait(); $process.StandardInput.Close(); if (!$process.WaitForExit($ReadTimeoutMs)) { throw "Git timeout: $Root" } }
    } finally {
        if ($process) { if (!$process.HasExited) { try { $process.Kill($true) } catch {} }; $process.Dispose() }
    }
}
function ConvertTo-SBRepositoryIdentity([string]$Remote) {
    if (!$Remote -or $Remote -match '[\p{Cc}\p{Cf}]') { return $null }
    $hostName=''; $repoPath=''; $port=''
    if($Remote -notmatch '://' -and $Remote -match '^(?:[^@/:]+@)?(?<host>[A-Za-z0-9.-]+):(?<path>[^?#\s]+)$'){
        $hostName=$Matches.host.ToLowerInvariant();$repoPath=$Matches.path
    }else{
        $uri=$null
        if(![Uri]::TryCreate($Remote,[UriKind]::Absolute,[ref]$uri) -or $uri.Scheme -notin @('https','http','ssh','git')){return $null}
        $hostName=$uri.IdnHost.ToLowerInvariant();$repoPath=$uri.AbsolutePath.Trim('/')
        if(!$uri.IsDefaultPort -and !(($uri.Scheme -eq 'ssh' -and $uri.Port -eq 22) -or ($uri.Scheme -eq 'git' -and $uri.Port -eq 9418))){$port=':'+$uri.Port}
    }
    $repoPath=$repoPath.Trim('/');if($repoPath.EndsWith('.git',[StringComparison]::OrdinalIgnoreCase)){$repoPath=$repoPath.Substring(0,$repoPath.Length-4)}
    if(!$hostName -or !$repoPath -or $repoPath -match '(^|/)\.\.?(/|$)|[?#\s\\]'){return $null}
    if($hostName -eq 'github.com'){$repoPath=$repoPath.ToLowerInvariant()}
    if($hostName -eq 'ssh.dev.azure.com' -and $repoPath -match '^v3/([^/]+)/([^/]+)/(.+)$'){$hostName='dev.azure.com';$repoPath=$Matches[1]+'/'+$Matches[2]+'/_git/'+$Matches[3]}
    $hostName+$port+'/'+$repoPath
}
function Resolve-SBRealPath([string]$Path) {
    # Risolve junction e symlink di ogni componente esistente, cosi percorsi alias e reali si confrontano come uguali.
    $full=[IO.Path]::GetFullPath($Path).TrimEnd('\','/')
    $root=[IO.Path]::GetPathRoot($full).TrimEnd('\','/')
    $current=$root
    foreach($segment in @($full.Substring($root.Length) -split '[\\/]' | Where-Object {$_})){
        $next=$current+[IO.Path]::DirectorySeparatorChar+$segment
        $item=Get-Item -LiteralPath $next -Force -ErrorAction SilentlyContinue
        if($item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)){
            $target=$item.ResolveLinkTarget($true)
            if($target){$next=$target.FullName.TrimEnd('\','/')}
        }
        $current=$next
    }
    $current
}
function Get-SBBrainIdentity([string]$BrainRoot='') {
    if(!$BrainRoot){$BrainRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))}
    # Un cervello senza repository proprio (ZIP, cartella annidata) non eredita l'origin di un repository padre.
    $top=Invoke-SBGit $BrainRoot @('rev-parse','--show-toplevel')
    if($top.code -ne 0 -or !$top.output -or (Resolve-SBRealPath $top.output) -ine (Resolve-SBRealPath $BrainRoot)){return ''}
    $origin=Invoke-SBGit $BrainRoot @('config','--get','remote.origin.url')
    if($origin.code -eq 0 -and $origin.output){$identity=ConvertTo-SBRepositoryIdentity $origin.output;if($identity){return $identity}}
    ''
}
function Test-SBRepositoryIdentity([string]$Identity,[string[]]$AllowedOwners=@()) {
    if(!$Identity -or $Identity -match '[\p{Cc}\p{Cf}\s?#\\]' -or $Identity -match '(^|/)\.\.?(/|$)'){return $false}
    if($null -ne $AllowedOwners -and @($AllowedOwners).Count){return $Identity -match '^github\.com/([^/]+)/[^/]+$' -and ($Matches[1] -in $AllowedOwners -or $Identity -eq (Get-SBBrainIdentity))}
    return $Identity -match '^local:[a-f0-9]{32}$|^[a-zA-Z0-9.-]+(?::[0-9]+)?/[^/]+(?:/[^/]+)*$'
}
function Resolve-SBBoundIdentity([string]$Checkout,$Bindings=@()) {
    $git=Invoke-SBGit $Checkout @('rev-parse','--show-toplevel')
    if($git.code -ne 0){return $null};$root=[IO.Path]::GetFullPath($git.output)
    $origin=Invoke-SBGit $root @('config','--get','remote.origin.url')
    if($origin.code -notin @(0,1)){return $null}
    $remote=if($origin.code -eq 0){ConvertTo-SBRepositoryIdentity $origin.output}else{$null}
    $matches=@($Bindings|Where-Object {$null -ne $_ -and [IO.Path]::GetFullPath($_.path) -eq $root})
    if($matches.Count -gt 1){throw 'Associazione checkout ambigua'}
    if($matches.Count -eq 1){if($matches[0].remoteIdentity -cne $remote){throw 'Origin cambiato: riconciliazione esplicita richiesta'};return $matches[0].identity}
    $remote
}
function Resolve-SBWorkingRepository([string]$Path='',$Bindings=@()) {
    # Repository del checkout in lavoro (default: directory corrente); $null se non e un checkout Git con identita.
    if(!$Path){$Path=(Get-Location).Path}
    if(!(Test-Path -LiteralPath $Path -PathType Container)){return $null}
    Resolve-SBBoundIdentity $Path $Bindings
}
function Test-SBCheckoutScope($Config,[string]$Checkout) {
    $full=[IO.Path]::GetFullPath($Checkout)
    if($Config.ContainsKey('mode') -and $Config.mode -eq 'portable'){
        return @($Config.bindings|Where-Object {[IO.Path]::GetFullPath($_.path) -eq $full}).Count -eq 1
    }
    $boundary=[IO.Path]::GetFullPath($Config.repositoryRoot).TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
    $full.StartsWith($boundary,[StringComparison]::OrdinalIgnoreCase)
}
function Get-SBLocalRoot([string]$BrainRoot,[string]$WorkstationId='default') {
    if($WorkstationId -notmatch '^[a-zA-Z0-9][a-zA-Z0-9_-]{0,63}$'){throw 'WorkstationId non valido'}
    [IO.Path]::GetFullPath((Join-Path $BrainRoot ('.runtime/hosts/'+$WorkstationId)))
}
function Assert-SBCentralDataPath([string]$BrainRoot,[string]$Path) {
    $boundary=[IO.Path]::GetFullPath((Join-Path $BrainRoot '.runtime')).TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
    $full=[IO.Path]::GetFullPath($Path)
    if(!$full.StartsWith($boundary,[StringComparison]::OrdinalIgnoreCase)){throw 'Output operativo fuori da SecondBrain/.runtime: '+$full}
    Assert-SBPlainPath $full
    $full
}
function Test-SBIDEObservation($Ide,[string]$ExpectedHash,$Observations,[string]$BrainRoot,[string]$WorkstationId) {
    try{
        if(!$Ide.ContainsKey('id')){return $false}
        $matches=@($Observations|Where-Object {$null -ne $_ -and $_.ideId -eq $Ide.id})
        if($matches.Count -ne 1){return $false};$observation=$matches[0]
        foreach($key in @('workstationId','profile','observedAt','observedHash','loadingVerified','sessionId','evidencePath','evidenceSha256')){if(!$observation.ContainsKey($key)){return $false}}
        if($observation.workstationId -ne $WorkstationId -or $observation.observedHash -ne $ExpectedHash -or !$observation.loadingVerified -or !$observation.sessionId){return $false}
        if($Ide.ContainsKey('profile') -and $observation.profile -cne $Ide.profile){return $false}
        if($Ide.ContainsKey('environment') -and (!$observation.ContainsKey('environment') -or $observation.environment -cne $Ide.environment)){return $false}
        if($Ide.mode -eq 'manual'){
            if(!$Ide.ContainsKey('accountAlias') -or !$Ide.accountAlias -or !$observation.ContainsKey('accountAlias') -or $observation.accountAlias -cne $Ide.accountAlias -or !$observation.ContainsKey('accountVerified') -or !$observation.accountVerified){return $false}
        }
        $at=[DateTimeOffset]::MinValue
        if(![DateTimeOffset]::TryParse($observation.observedAt,[ref]$at) -or $at -lt [DateTimeOffset]::UtcNow.AddMinutes(-15) -or $at -gt [DateTimeOffset]::UtcNow.AddMinutes(1)){return $false}
        $evidence=Assert-SBCentralDataPath $BrainRoot $observation.evidencePath
        return (Get-SBFileHash $evidence) -eq $observation.evidenceSha256
    }catch{return $false}
}
function Get-SBManagedContent([string]$Text, [string]$Id) {
    $pattern = '(?s)<!-- secondbrain:'+[regex]::Escape($Id)+':begin -->.*?<!-- secondbrain:'+[regex]::Escape($Id)+':end -->'
    $matches = [regex]::Matches($Text,$pattern)
    if ($matches.Count -gt 1) { throw "Blocco duplicato: $Id" }
    if ($matches.Count -eq 1) { return $matches[0].Value }
    if ($Text.Contains("<!-- secondbrain:${Id}:")) { throw "Blocco incompleto: $Id" }
    return $null
}
function Set-SBManagedContent {
    param([string]$Path,[string]$Body,[string]$Id,[hashtable]$State,[bool]$Check,[string]$BackupRoot,[switch]$WholeFile,[switch]$AfterTitle)
    $beforeHash = Get-SBFileHash $Path
    $text = if ($beforeHash -eq 'absent') { '' } else { Read-SBText $Path }
    $key = [IO.Path]::GetFullPath($Path)+'|'+$Id
    $wanted = if ($WholeFile) { $Body } else { "<!-- secondbrain:${Id}:begin -->`n"+$Body.Trim()+"`n<!-- secondbrain:${Id}:end -->" }
    $existing = if ($WholeFile) { $text } else { Get-SBManagedContent $text $Id }
    $oldHash = if ($null -eq $existing -or ($WholeFile -and $beforeHash -eq 'absent')) { 'absent' } else { Get-SBTextHash $existing }
    if ($existing -ceq $wanted) {
        if (!$Check) { $State[$key] = Get-SBTextHash $wanted }
        return 'aligned'
    }
    if ($State.ContainsKey($key)) {
        if ($State[$key] -ne $oldHash) { return 'conflict' }
    } elseif ($oldHash -ne 'absent') { return 'conflict' }
    if ($Check) { return 'pending' }
    $updated = if ($WholeFile) { $wanted } elseif ($null -ne $existing) { $text.Replace($existing,$wanted) } elseif ($AfterTitle -and $text.Length) {
        $title=[regex]::Match($text,'\A# [^\r\n]*(?:\r?\n|$)')
        if($title.Success){$text.Insert($title.Length,"`n"+$wanted+"`n")}else{$wanted+"`n`n"+$text}
    } elseif ($text.Length) { $text+"`n`n"+$wanted+"`n" } else { $wanted+"`n" }
    try { Write-SBFile $Path ([Text.Encoding]::UTF8.GetBytes($updated)) $beforeHash $BackupRoot | Out-Null }
    catch {
        if ($_.Exception.Message -like 'File tracciato con modifiche non committate*') { Write-Warning $_.Exception.Message; return 'conflict' }
        throw
    }
    $State[$key] = Get-SBTextHash $wanted
    'updated'
}
function Get-SBApprovedDirectiveRevision([string]$BrainRoot) {
    if (!(Test-SBApproval $BrainRoot)) { return $null }
    $text = Read-SBText (Join-Path $BrainRoot 'direttive/AGENTS.global_ide.md')
    $revision = [regex]::Match($text, '(?m)^Revisione (?<version>\d+(?:\.\d+)+) — (?<date>\d{4}-\d{2}-\d{2})\.')
    if (!$revision.Success) { return $null }
    $approval = Read-SBJson (Join-Path $BrainRoot 'direttive/approved.json') @{}
    @{version=$revision.Groups['version'].Value; date=$revision.Groups['date'].Value;
      globalHash=$approval.files['direttive/AGENTS.global_ide.md']; workstationHash=$approval.files['direttive/workstation.template.md']}
}

function Initialize-SBFileRemoval {
    if ('SecondBrain.FileRemoval' -as [type]) { return }
    # Windows share modes exclude writers and renames until disposition and close.
    # Delete the verified file object by handle, never a newly replaced pathname.
    Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.IO;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
namespace SecondBrain {
    public static class FileRemoval {
        [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
        private static extern SafeFileHandle CreateFileW(string name, uint access, uint share,
            IntPtr security, uint creation, uint flags, IntPtr template);
        [DllImport("kernel32.dll", SetLastError=true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool SetFileInformationByHandle(SafeFileHandle handle, int kind,
            ref byte information, uint size);
        public static FileStream Open(string path) {
            var handle = CreateFileW(path, 0x80010000, 1, IntPtr.Zero, 3, 0x80, IntPtr.Zero);
            if (handle.IsInvalid) {
                int error = Marshal.GetLastWin32Error(); handle.Dispose();
                throw new Win32Exception(error);
            }
            try { return new FileStream(handle, FileAccess.Read); }
            catch { handle.Dispose(); throw; }
        }
        public static void Delete(FileStream stream) {
            byte disposition = 1; // FILE_DISPOSITION_INFO.DeleteFile (BOOLEAN)
            if (!SetFileInformationByHandle(stream.SafeFileHandle, 4, ref disposition, 1))
                throw new Win32Exception(Marshal.GetLastWin32Error());
        }
    }
}
'@
}

function Remove-SBFile([string]$Path, [string]$AllowedRoot, [string]$ExpectedHash, [string]$BackupRoot) {
    Assert-SBWriteGuard
    $full=[IO.Path]::GetFullPath($Path)
    $boundary=[IO.Path]::GetFullPath($AllowedRoot).TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
    if(!$full.StartsWith($boundary,[StringComparison]::OrdinalIgnoreCase)){throw 'Rimozione fuori perimetro: '+$full}
    Assert-SBPlainPath $full
    if((Get-SBFileHash $full) -ne $ExpectedHash -or $ExpectedHash -eq 'absent'){throw 'File cambiato prima della rimozione: '+$full}
    $script:SBWriteGeneration++
    Assert-SBPlainPath $BackupRoot
    Initialize-SBFileRemoval
    $stream=[SecondBrain.FileRemoval]::Open($full)
    try {
        $copy=[IO.MemoryStream]::new()
        try{$stream.CopyTo($copy);$bytes=$copy.ToArray()}finally{$copy.Dispose()}
        if((Get-SBHash $bytes) -ne $ExpectedHash){throw 'Modifica concorrente prima della rimozione'}
        [IO.Directory]::CreateDirectory($BackupRoot)|Out-Null
        $backup=Join-Path $BackupRoot ([guid]::NewGuid().ToString('N')+'.bin')
        [IO.File]::WriteAllBytes($backup,$bytes)
        if((Get-SBFileHash $backup) -ne $ExpectedHash){throw 'Backup rimozione non verificato'}
        $metadata=@{path=$full;previousHash=$ExpectedHash;deployedHash='absent';backup=$backup;reason='authorized-cleanup'}
        [IO.File]::WriteAllText($backup+'.json',(ConvertTo-SBJson $metadata),[Text.UTF8Encoding]::new($false))
        Assert-SBWriteGuard
        [SecondBrain.FileRemoval]::Delete($stream)
    } finally { $stream.Dispose() }
    $metadata
}

function Test-SBApproval([string]$BrainRoot) {
    $approval = Read-SBJson (Join-Path $BrainRoot 'direttive/approved.json') @{}
    if (!$approval.ContainsKey('files') -or !$approval.ContainsKey('authorization')) { return $false }
    foreach ($relative in @('direttive/AGENTS.global_ide.md','direttive/workstation.template.md')) {
        if (!$approval.files.ContainsKey($relative) -or $approval.files[$relative] -ne (Get-SBFileHash (Join-Path $BrainRoot $relative))) { return $false }
    }
    return $true
}
Export-ModuleMember -Function @(
    'Set-SBWriteGuard',
    'Assert-SBWriteGuard',
    'Get-SBHash',
    'Get-SBTextHash',
    'Get-SBVersion',
    'Read-SBText',
    'Get-SBFileHash',
    'Read-SBJson',
    'ConvertTo-SBComparablePath',
    'Test-SBSamePath',
    'Convert-SBBrainAlias',
    'ConvertTo-SBStableValue',
    'ConvertTo-SBJson',
    'Assert-SBPlainPath',
    'Get-SBWriteGeneration',
    'Write-SBFile',
    'Get-SBStageRetention',
    'Get-SBRuntimeRetention',
    'Get-SBRuntimeCleanupProposal',
    'Get-SBRegenerableRuntimeTargets',
    'Remove-SBRuntimeTree',
    'Invoke-SBGit',
    'Get-SBGitObjectInfo',
    'Read-SBGitBlobs',
    'ConvertTo-SBRepositoryIdentity',
    'Get-SBBrainIdentity',
    'Test-SBRepositoryIdentity',
    'Resolve-SBBoundIdentity',
    'Resolve-SBWorkingRepository',
    'Test-SBCheckoutScope',
    'Get-SBLocalRoot',
    'Assert-SBCentralDataPath',
    'Test-SBIDEObservation',
    'Get-SBManagedContent',
    'Set-SBManagedContent',
    'Get-SBApprovedDirectiveRevision',
    'Remove-SBFile',
    'Test-SBApproval'
)
