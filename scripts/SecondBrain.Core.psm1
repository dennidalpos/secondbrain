#requires -Version 7.5
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
try {
    if ([Console]::OutputEncoding.CodePage -ne 65001) {
        [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
    }
} catch { }
$OutputEncoding = [Text.UTF8Encoding]::new($false)
$script:SBWriteGuard = $null

function Set-SBWriteGuard([scriptblock]$Guard) { $script:SBWriteGuard=$Guard }
function Get-SBWriteGuard { $script:SBWriteGuard }
function Assert-SBWriteGuard { if($script:SBWriteGuard){ & $script:SBWriteGuard } }

function Get-SBHash([byte[]]$Bytes) {
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes))
}
function Get-SBTextHash([string]$Text) { Get-SBHash ([Text.Encoding]::UTF8.GetBytes($Text)) }
# Product version: the VERSION file in the clone root is the single source.
function Get-SBVersion {
    $path=Join-Path $PSScriptRoot '../VERSION'
    if(!(Test-Path -LiteralPath $path -PathType Leaf)){throw (New-SBError 'core.version.missing')}
    (Get-Content -LiteralPath $path -Raw).Trim()
}

function Read-SBText([string]$Path) { [IO.File]::ReadAllText($Path, [Text.UTF8Encoding]::new($false, $true)) }
function Get-SBFileHash([string]$Path) {
    if ([IO.File]::Exists($Path)) { Get-SBHash ([IO.File]::ReadAllBytes($Path)) } else { 'absent' }
}
function Read-SBJson([string]$Path, $Default) {
    if (!(Test-Path -LiteralPath $Path)) { return $Default }
    # On a share, atomic replacement by another host may cause a transient sharing violation.
    for ($attempt = 1; $attempt -le 5; $attempt++) {
        try { return (Read-SBText $Path | ConvertFrom-Json -AsHashtable -DateKind String) }
        catch [IO.IOException] {
            if (($_.Exception.HResult -band 0xffff) -notin @(32, 33) -or $attempt -eq 5) { throw }
            Start-Sleep -Milliseconds (50 * $attempt)
        }
    }
}
function ConvertTo-SBComparablePath([string]$Path) {
    # Comparison form for path aliases: case, mapped drive or local administrative share, and UNC with short host name or FQDN.
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
    # Rewrite a path recorded by another host (UNC alias, mapped drive) relative to the current brain root.
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
    # VerifiedAncestors (optional, managed by the caller for a multi-file cycle): ancestor directories already checked
    # for reparse points in this run; always check the specified path, skipping only ancestors.
    $current = [IO.Path]::GetFullPath($Path)
    # Inside the brain, verification stops at its root: the chosen installation location
    # (OneDrive, junction, DFS) is not a redirection introduced inside the data.
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
                throw (New-SBError 'core.reparse.unwritable' @($current))
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
    # Read-only: $null if the file is absent, Git is unavailable or the file is untracked (ignored dossiers, global IDEs, MCP config).
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
    # Read-only: true only if a .bin.json's .bin duplicates Git (copy SHA-256 equals previousHash, tracked clean source, content present as a blob).
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
# Returns the underlying I/O exception when a write failed because another writer holds or has just replaced the file
# (sharing/lock violation, file exists, file or directory vanished, replace failures); $null for every other error (disk full, access denied, coded errors).
function Get-SBWriteContention($Exception) {
    if ($Exception.Data.Contains('code')) { return $null }
    $io = if ($Exception -is [IO.IOException]) { $Exception } elseif ($Exception.InnerException -is [IO.IOException]) { $Exception.InnerException } else { $null }
    if ($null -eq $io) { return $null }
    if ($io -is [IO.FileNotFoundException] -or $io -is [IO.DirectoryNotFoundException]) { return $io }
    if (($io.HResult -band 0xffff) -in @(2, 3, 32, 33, 80, 183, 1175, 1176, 1177)) { return $io }
    $null
}
function Get-SBWriteDeniedException($Exception) {
    while ($null -ne $Exception) {
        if ($Exception -is [UnauthorizedAccessException] -or $Exception -is [Security.SecurityException] -or
            ($Exception -is [IO.IOException] -and ($Exception.HResult -band 0xffff) -eq 5)) { return $Exception }
        $Exception = $Exception.InnerException
    }
    $null
}
function ConvertTo-SBWriteError($Exception, [string]$Path) {
    if (Test-SBError $Exception 'core.write.denied') { return $Exception }
    $denied = Get-SBWriteDeniedException $Exception
    if ($denied) {
        $error = New-SBError 'core.write.denied' @($Path) ([IO.IOException]) 0 $Exception
        $error.Data['path'] = $Path
        return $error
    }
    $Exception
}
function Test-SBWriteDeniedError($ErrorRecord) {
    $exception=if($ErrorRecord -is [Management.Automation.ErrorRecord]){$ErrorRecord.Exception}else{$ErrorRecord}
    (Test-SBError $exception 'core.write.denied') -or ($null -ne (Get-SBWriteDeniedException $exception))
}
function Get-SBRetryCommand([string]$ScriptPath, [Collections.IDictionary]$Parameters) {
    # A PowerShell invocation, not a shell-evaluated concatenation of argument values.
    $quote = { param($value) "'" + ([string]$value).Replace("'", "''") + "'" }
    $parts = [Collections.Generic.List[string]]::new()
    $parts.Add('& ' + (& $quote $ScriptPath))
    foreach ($key in $Parameters.Keys) {
        if ($key -notmatch '^[A-Za-z][A-Za-z0-9]*$') { throw (New-SBError 'core.retry.parameter') }
        $value = $Parameters[$key]
        if ($value -is [Management.Automation.SwitchParameter] -or $value -is [bool]) {
            $parts.Add('-' + $key + ':$' + ([bool]$value).ToString().ToLowerInvariant())
        } elseif ($value -is [array]) {
            $parts.Add('-' + $key + ' @(' + ((@($value | ForEach-Object { & $quote $_ })) -join ',') + ')')
        } else { $parts.Add('-' + $key + ' ' + (& $quote $value)) }
    }
    $parts -join ' '
}
function Write-SBWriteDeniedDiagnostic($ErrorRecord, [string]$ScriptPath, [Collections.IDictionary]$Parameters) {
    $exception = if ($ErrorRecord -is [Management.Automation.ErrorRecord]) { $ErrorRecord.Exception } else { $ErrorRecord }
    $error = ConvertTo-SBWriteError $exception $ScriptPath
    [Console]::Error.WriteLine('[core.write.denied] ' + $error.Message)
    [Console]::Error.WriteLine((Get-SBMessage 'core.write.retry' @((Get-SBRetryCommand $ScriptPath $Parameters))))
}
function Get-SBIDEWriteScope($Ide) {
    if ($Ide.ContainsKey('writeScope')) {
        $scope = $Ide.writeScope
        if ($scope -is [Collections.IDictionary] -and $scope.ContainsKey('status') -and
            $scope.status -in @('unverified','verified','denied') -and $scope.ContainsKey('roots') -and
            $scope.roots -is [array] -and $scope.ContainsKey('evidence')) {
            if ($scope.status -eq 'unverified' -or (@($scope.roots).Count -gt 0 -and $scope.evidence)) { return $scope }
        }
    }
    @{status='unverified';roots=@();evidence=$null}
}
function Write-SBFile {
    param([string]$Path, [byte[]]$Bytes, [string]$ExpectedHash, [string]$BackupRoot, [switch]$BackupDirty)
    try {
    Assert-SBWriteGuard
    Assert-SBPlainPath $Path
    if ((Get-SBFileHash $Path) -ne $ExpectedHash) { throw (New-SBError 'core.concurrent.modified' @($Path)) }
    if ((Get-SBHash $Bytes) -eq $ExpectedHash) { return $false }
    # Git preserves tracked files: clean = no .bin (commit and blob recorded); dirty = refused unless -BackupDirty (regenerated files retain the .bin).
    $git = Get-SBGitFileState $Path
    if ($null -ne $git -and $git.dirty -and !$BackupDirty) {
        throw (New-SBError 'core.tracked.dirty' @($Path))
    }
    $gitOnly = ($null -ne $git -and !$git.dirty)
    $script:SBWriteGeneration++
    $parent = Split-Path -Parent $Path
    $temp = Join-Path $parent ('.secondbrain-' + [guid]::NewGuid().ToString('N') + '.tmp')
    $backup = $null
    $completed=$false
    $stageRecordPath=Join-Path $BackupRoot ([guid]::NewGuid().ToString('N')+'.stage')
    $stageRecord=@{schemaVersion=1;path=[IO.Path]::GetFullPath($Path);staging=$temp;expectedHash=$ExpectedHash;status='writing'}
    $failure=$null;$stageRegistered=$false
    try {
        [IO.Directory]::CreateDirectory($parent) | Out-Null
        [IO.Directory]::CreateDirectory($BackupRoot)|Out-Null
        [IO.File]::WriteAllText($stageRecordPath,(ConvertTo-SBJson $stageRecord),[Text.UTF8Encoding]::new($false))
        $stageRegistered=$true
        $stream = [IO.FileStream]::new($temp, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        try { $stream.Write($Bytes); $stream.Flush($true) } finally { $stream.Dispose() }
        if ((Get-SBFileHash $temp) -ne (Get-SBHash $Bytes)) { throw (New-SBError 'core.readback.staging') }
        if ((Get-SBFileHash $Path) -ne $ExpectedHash) { throw (New-SBError 'core.concurrent.modified' @($Path)) }
        Assert-SBWriteGuard
        if ($ExpectedHash -ne 'absent') {
            [IO.Directory]::CreateDirectory($BackupRoot) | Out-Null
            $backup = Join-Path $BackupRoot ([guid]::NewGuid().ToString('N') + '.bin')
            # Replace preserves the replaced file exactly, detecting races in the final window too.
            $localBackup = Join-Path $parent ('.secondbrain-' + [guid]::NewGuid().ToString('N') + '.recovery')
            $stageRecord.recovery=$localBackup
            [IO.File]::Replace($temp, $Path, $localBackup)
            if ($gitOnly) {
                $actual = Get-SBFileHash $localBackup
                $backup = $null
                $record = @{ schemaVersion = 1; path = $Path; previousHash = $actual; deployedHash = Get-SBHash $Bytes; gitCommit = $git.commit; gitBlob = $git.blob }
                [IO.File]::WriteAllText((Join-Path $BackupRoot ([guid]::NewGuid().ToString('N') + '.git.json')), (ConvertTo-SBJson $record), [Text.UTF8Encoding]::new($false))
                if ($actual -ne $ExpectedHash) { throw (New-SBError 'core.race.kept' @($localBackup)) }
                [IO.File]::Delete($localBackup)
            } else {
                [IO.File]::Copy($localBackup, $backup)
                $actual = Get-SBFileHash $backup
                if ($actual -ne (Get-SBFileHash $localBackup)) { throw (New-SBError 'core.backup.unverified' @($localBackup)) }
                $metadata = @{ path = $Path; previousHash = $actual; deployedHash = Get-SBHash $Bytes; backup = $backup }
                [IO.File]::WriteAllText($backup + '.json', (ConvertTo-SBJson $metadata), [Text.UTF8Encoding]::new($false))
                [IO.File]::Delete($localBackup)
            }
            if ($actual -ne $ExpectedHash) {
                # Never attempt rollback with Copy(overwrite): an external editor
                # may have changed the file again after the hash check.
                throw (New-SBError 'core.race.kept' @($backup))
            }
        } else { [IO.File]::Move($temp, $Path) }
        if ((Get-SBFileHash $Path) -ne (Get-SBHash $Bytes)) { throw (New-SBError 'core.readback.destination' @($Path)) }
        $completed=$true
        return $true
    } catch {
        $failure=$_.Exception
        # A competing writer holds or has just replaced the destination: stable code, original error kept as inner exception.
        $contention = Get-SBWriteContention $_.Exception
        if ($null -eq $contention) { throw }
        throw (New-SBError 'core.write.contended' @($Path) ([IO.IOException]) 0 $contention)
    } finally {
        try {
        $stageRecord.status=if($completed){'completed'}else{'interrupted'}
        if([IO.File]::Exists($temp)){
            if($completed){[IO.File]::Delete($temp)}else{Write-Warning (Get-SBMessage 'core.staging.kept' @($temp))}
        }
        if($stageRegistered){[IO.File]::WriteAllText($stageRecordPath,(ConvertTo-SBJson $stageRecord),[Text.UTF8Encoding]::new($false))}
        } catch {
            if(!$failure){throw}
            # Keep the primary failure; recovery materials are never removed on failure.
            Write-Warning (Get-SBMessage 'core.write.finalization' @($stageRecordPath,$_.Exception.Message))
        }
    }
    } catch { throw (ConvertTo-SBWriteError $_.Exception $Path) }
}
function Get-SBStageRetention([string[]]$BackupRoot,[int]$OlderThanDays=90) {
    # Read-only: list completed .stage records older than the threshold in one or more backupRoot locations, recursively. Never select .bin/.bin.json backups, interrupted stages or unreadable records.
    if($OlderThanDays -lt 1){throw (New-SBError 'core.olderthan.min')}
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
    # Read-only: inventory top-level .runtime entries with age (last write), size, textual references and protection.
    # Does not list files for removal or follow reparse points: removal still requires a reviewed manifest (cleanup.ps1 -ManifestPath).
    if($OlderThanDays -lt 1){throw (New-SBError 'core.olderthan.min')}
    $runtime=[IO.Path]::GetFullPath((Join-Path $BrainRoot '.runtime')).TrimEnd('\','/')
    if(!(Test-Path -LiteralPath $runtime -PathType Container)){return @{olderThanDays=$OlderThanDays;entries=@();reviewable=@();totalBytes=0L;nested=@();legacy=@()}}
    $cutoff=[DateTime]::UtcNow.AddDays(-$OlderThanDays)
    $fixed=@{'access'='runtime-access';'hosts'='runtime-hosts';'cleanup'='runtime-cleanup';'state.json'='runtime-state';'para-transaction.json'='runtime-para-marker'}
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
        $reason=$null;$reasonCode=$null
        if(!$followed){$reasonCode='reparse-point'}
        elseif($fixed.ContainsKey($item.Name.ToLowerInvariant())){$reasonCode=$fixed[$item.Name.ToLowerInvariant()]}
        elseif($byConfig.ContainsKey($item.Name.ToLowerInvariant())){$reasonCode='config-path'}
        if($reasonCode){$reason=Get-SBMessage ('core.runtime.reason.'+$reasonCode)}
        $classification=Get-SBRuntimeCategory $item.Name ([bool]$reason)
        $entries+=@{name=$item.Name;kind=$kind;files=$count;bytes=$size;newestWriteUtc=$newest.ToString('o');ageDays=[int][Math]::Floor(([DateTime]::UtcNow-$newest).TotalDays);olderThanThreshold=($newest -lt $cutoff);protected=[bool]$reason;protectedReason=$reason;protectedReasonCode=$reasonCode;category=$classification.category;recovery=$classification.recovery;references=@{mentions=0;samples=@()}}
    }
    # Textual references to .runtime/<entry> in versioned surfaces and dossiers (text files up to 2 MB).
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
    @{olderThanDays=$OlderThanDays;entries=$entries;reviewable=@($entries|Where-Object {!$_.protected -and $_.olderThanThreshold}|ForEach-Object {$_.name});totalBytes=[long]$entryBytes;byCategory=$byCategory;nested=@(Get-SBRuntimeNested $BrainRoot $OlderThanDays);legacy=@(Get-SBRuntimeLegacy $BrainRoot $entries)}
}
# Top-level .runtime categories: protected (configuration/access), evidence (proof to preserve), backup (recovery), regenerable (recreatable), working (agent temporary work to review).
function Get-SBRuntimeCategory([string]$Name,[bool]$IsProtected) {
    $key=$Name.ToLowerInvariant()
    if($IsProtected){return @{category='protected';recovery='non rimuovere: configurazione, accessi o stato attivo'}}
    if($key -eq 'tests'){return @{category='regenerable';recovery='si ricrea rieseguendo le suite test-secondbrain*.ps1'}}
    if($key -eq 'index.md'){return @{category='regenerable';recovery='vista derivata: si rigenera con cleanup.ps1 -RuntimeReport'}}
    if($key -eq 'mcp-handshake'){return @{category='regenerable';recovery='si ricrea rieseguendo test-secondbrain-mcp-handshake.ps1'}}
    if($key -eq 'logs'){return @{category='regenerable';recovery='log di esecuzione: si ricreano a ogni esecuzione'}}
    if($key -eq 'install-backups'){return @{category='backup';recovery='copie di configurazioni prima di un intervento: rimuovere solo dopo verifica e con manifest revisionato'}}
    if($key -in @('cleanup','captures','publication','directives-activation','trace')){return @{category='evidence';recovery='prova o provenienza: non si rigenera identica'}}
    # Agent folder convention <category>-<yyyyMMdd>-<slug>: the prefix declares the type of work.
    if($key -match '^(evidence|report)-'){return @{category='evidence';recovery='prova o rapporto: non si rigenera identico'}}
    if($key -match '^(work|fixture|tmp)-'){return @{category='working';recovery='lavoro temporaneo dichiarato dal prefisso: verificare riferimenti e proprietà prima di valutarlo'}}
    if($key -in @('backups','workstations')){return @{category='backup';recovery='recupero di file gestiti: rimuovere solo con manifest revisionato (cleanup.ps1)'}}
    @{category='working';recovery='lavoro temporaneo: verificare riferimenti e proprietà prima di valutarlo'}
}
# Code-managed top-level entries are never legacy. All other .runtime entries predate hosts/<id>/repos/<repo>/<category>/<yyyyMMdd>-<slug>.
$script:SBRuntimeManagedTopLevel = @('access','hosts','cleanup','state.json','para-transaction.json','tests','mcp-handshake','captures','publication','directives-activation','trace','backups','logs','workstations','mcp-package','index.md')
# Read-only inventory of hosts/<id>/repos/<repo>/<area>[/<folder>] (area = category or temp). Does not follow reparse points.
function Get-SBRuntimeNested([string]$BrainRoot,[int]$OlderThanDays=90) {
    $runtime=[IO.Path]::GetFullPath((Join-Path $BrainRoot '.runtime')).TrimEnd('\','/')
    $hostsDir=Join-Path $runtime 'hosts'
    if(!(Test-Path -LiteralPath $hostsDir -PathType Container)){return @()}
    $cutoff=[DateTime]::UtcNow.AddDays(-$OlderThanDays)
    $options=[IO.EnumerationOptions]::new();$options.RecurseSubdirectories=$true;$options.IgnoreInaccessible=$true;$options.AttributesToSkip=[IO.FileAttributes]::ReparsePoint
    $dirs={param([string]$Path) if(Test-Path -LiteralPath $Path -PathType Container){@(Get-ChildItem -LiteralPath $Path -Directory -Force|Where-Object {!($_.Attributes -band [IO.FileAttributes]::ReparsePoint)}|Sort-Object Name)}else{@()}}
    $entries=@()
    foreach($hostDir in (& $dirs $hostsDir)){
        foreach($repoDir in (& $dirs (Join-Path $hostDir.FullName 'repos'))){
            foreach($areaDir in (& $dirs $repoDir.FullName)){
                $areaIsCategory=$areaDir.Name -cin @('work','evidence','report','fixture','tmp')
                $targets=if($areaIsCategory){& $dirs $areaDir.FullName}else{@($areaDir)}
                foreach($target in $targets){
                    $count=0;$size=0L;$newest=[DateTime]::MinValue
                    foreach($file in ([IO.DirectoryInfo]::new($target.FullName)).EnumerateFiles('*',$options)){$count++;$size+=$file.Length;if($file.LastWriteTimeUtc -gt $newest){$newest=$file.LastWriteTimeUtc}}
                    if($newest -eq [DateTime]::MinValue){$newest=$target.LastWriteTimeUtc}
                    $classification=if($areaIsCategory){Get-SBRuntimeCategory ($areaDir.Name+'-x') $false}elseif($areaDir.Name -eq 'temp'){@{category='working';recovery='area TEMP/TMP del repository: si ricrea a ogni esecuzione'}}else{Get-SBRuntimeCategory 'x' $false}
                    $relative=$target.FullName.Substring($runtime.Length+1).Replace('\','/')
                    $entries+=@{path=$relative;host=$hostDir.Name;repo=$repoDir.Name;area=$areaDir.Name;files=$count;bytes=$size;newestWriteUtc=$newest.ToString('o');ageDays=[int][Math]::Floor(([DateTime]::UtcNow-$newest).TotalDays);olderThanThreshold=($newest -lt $cutoff);category=$classification.category;recovery=$classification.recovery;conventional=($areaIsCategory -and $target.Name -cmatch '^\d{8}-[a-z0-9][a-z0-9-]*$') -or $areaDir.Name -eq 'temp';manifest=[bool]($areaIsCategory -and (Test-Path -LiteralPath (Join-Path $target.FullName 'MANIFEST.json') -PathType Leaf))}
                }
            }
        }
    }
    $entries
}
# Folders predating the nested layout (read-only): show a proposed destination for each. Nothing is moved, renamed or removed.
function Get-SBRuntimeLegacy([string]$BrainRoot,$Entries) {
    $runtime=[IO.Path]::GetFullPath((Join-Path $BrainRoot '.runtime')).TrimEnd('\','/')
    $options=[IO.EnumerationOptions]::new();$options.RecurseSubdirectories=$true;$options.IgnoreInaccessible=$true;$options.AttributesToSkip=[IO.FileAttributes]::ReparsePoint
    $legacy=@()
    $target={param([string]$Name,[DateTime]$Newest)
        if($Name -cmatch '^(?<c>work|evidence|report|fixture|tmp)-(?<d>\d{8})-(?<s>[a-z0-9][a-z0-9-]*)$'){return @{kind='flat-convention';suggested='hosts/<id>/repos/<repo>/'+$Matches.c+'/'+$Matches.d+'-'+$Matches.s}}
        $slug=(($Name.ToLowerInvariant() -replace '[^a-z0-9]+','-').Trim('-'));if(!$slug){$slug='cartella'};if($slug.Length -gt 60){$slug=$slug.Substring(0,60).Trim('-')}
        $category=if((Get-SBRuntimeCategory $Name $false).category -eq 'evidence'){'evidence'}else{'work'}
        @{kind='unconventional';suggested='hosts/<id>/repos/<repo>/'+$category+'/'+$Newest.ToString('yyyyMMdd')+'-'+$slug}}
    foreach($entry in @($Entries)){
        if($entry.kind -ne 'directory' -or $entry.name.ToLowerInvariant() -in $script:SBRuntimeManagedTopLevel){continue}
        $t=& $target $entry.name ([DateTime]::Parse($entry.newestWriteUtc,[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::RoundtripKind))
        $legacy+=@{path=$entry.name+'/';kind=$t.kind;files=$entry.files;bytes=$entry.bytes;newestWriteUtc=$entry.newestWriteUtc;suggestedPath=$t.suggested;action='spostamento proposto, non eseguito'}
    }
    # Previous per-workstation layout: hosts/<id>/repositories/<hash>/<Project>/<Runtime>.
    $hostsDir=Join-Path $runtime 'hosts'
    if(Test-Path -LiteralPath $hostsDir -PathType Container){
        foreach($hostDir in @(Get-ChildItem -LiteralPath $hostsDir -Directory -Force|Where-Object {!($_.Attributes -band [IO.FileAttributes]::ReparsePoint)}|Sort-Object Name)){
            $old=Join-Path $hostDir.FullName 'repositories'
            if(!(Test-Path -LiteralPath $old -PathType Container)){continue}
            foreach($repoDir in @(Get-ChildItem -LiteralPath $old -Directory -Force|Where-Object {!($_.Attributes -band [IO.FileAttributes]::ReparsePoint)}|Sort-Object Name)){
                foreach($projectDir in @(Get-ChildItem -LiteralPath $repoDir.FullName -Directory -Force|Where-Object {!($_.Attributes -band [IO.FileAttributes]::ReparsePoint)}|Sort-Object Name)){
                    foreach($runtimeDir in @(Get-ChildItem -LiteralPath $projectDir.FullName -Directory -Force|Where-Object {!($_.Attributes -band [IO.FileAttributes]::ReparsePoint)}|Sort-Object Name)){
                        $count=0;$size=0L;$newest=[DateTime]::MinValue
                        foreach($file in ([IO.DirectoryInfo]::new($runtimeDir.FullName)).EnumerateFiles('*',$options)){$count++;$size+=$file.Length;if($file.LastWriteTimeUtc -gt $newest){$newest=$file.LastWriteTimeUtc}}
                        if($newest -eq [DateTime]::MinValue){$newest=$runtimeDir.LastWriteTimeUtc}
                        $slug=((($projectDir.Name+'-'+$runtimeDir.Name).ToLowerInvariant() -replace '[^a-z0-9]+','-').Trim('-'));if($slug.Length -gt 60){$slug=$slug.Substring(0,60).Trim('-')}
                        $legacy+=@{path=$runtimeDir.FullName.Substring($runtime.Length+1).Replace('\','/')+'/';kind='repositories';files=$count;bytes=$size;newestWriteUtc=$newest.ToString('o');suggestedPath='hosts/'+$hostDir.Name+'/repos/<repo>/work/'+$newest.ToString('yyyyMMdd')+'-'+$slug;action='spostamento proposto, non eseguito'}
                    }
                }
            }
        }
    }
    $legacy
}
# Readable .runtime index (read-only): top-level entries sorted by category, then size, with writers and recovery instructions.
function Get-SBRuntimeIndex([string]$BrainRoot,[string[]]$ProtectedPaths=@(),[int]$OlderThanDays=90) {
    $report=Get-SBRuntimeRetention $BrainRoot $ProtectedPaths $OlderThanDays
    $runtime=[IO.Path]::GetFullPath((Join-Path $BrainRoot '.runtime')).TrimEnd('\','/')
    $writers=@{access='access.ps1 / Enter-SBOperation';hosts='secondbrain.ps1 -Setup/-Activate/-Sync, backup';backups='mcp-server.ps1 -Pair, trace.ps1, publication.ps1, tracker';logs='cleanup.ps1 -Migrate (log delle esecuzioni)';workstations='host legacy (registro accessi)';tests='test-secondbrain*.ps1';'mcp-handshake'='test-secondbrain-mcp-handshake.ps1';cleanup='cleanup.ps1';publication='publication.ps1';captures='assets.ps1 / REP07';'directives-activation'='agente (SYS03)';'mcp-package'='mcp-server.ps1 -Package';trace='trace.ps1';'state.json'='secondbrain.ps1';'para-transaction.json'='para.ps1';'index.md'='cleanup.ps1 -RuntimeReport'}
    $order=@{protected=0;evidence=1;backup=2;working=3;regenerable=4}
    $format={param([long]$Bytes) if($Bytes -ge 1GB){('{0:N1} GB' -f ($Bytes/1GB))}elseif($Bytes -ge 1MB){('{0:N1} MB' -f ($Bytes/1MB))}else{('{0:N0} KB' -f ($Bytes/1KB))}}
    $options=[IO.EnumerationOptions]::new();$options.RecurseSubdirectories=$true;$options.IgnoreInaccessible=$true;$options.AttributesToSkip=[IO.FileAttributes]::ReparsePoint
    $rows=@();$details=@()
    foreach($entry in @($report.entries|Sort-Object @{Expression={$order[$_.category]}},@{Expression={$_.bytes};Descending=$true},name)){
        $key=$entry.name.ToLowerInvariant()
        $owner=if($writers.ContainsKey($key)){$writers[$key]}else{'agente o attività manuale (nessun codice)'}
        $conventional=$entry.name -match '^(work|evidence|fixture|tmp|report)-\d{8}-[a-z0-9][a-z0-9-]*$'
        $name=$entry.name+$(if($entry.kind -eq 'directory'){'/'}else{''})
        $rows+='| `'+$name+'` | '+$entry.category+' | '+(& $format $entry.bytes)+' | '+$entry.files+' | '+$entry.newestWriteUtc.Substring(0,10)+' | '+$entry.references.mentions+' | '+$owner+$(if($conventional){' (nome conforme)'}else{''})+' | '+$entry.recovery+' |'
        if($entry.kind -eq 'directory' -and $entry.bytes -ge 50MB){
            $children=@()
            foreach($child in Get-ChildItem -LiteralPath (Join-Path $runtime $entry.name) -Force|Where-Object {!($_.Attributes -band [IO.FileAttributes]::ReparsePoint)}){
                $size=0L;$count=0
                if($child.PSIsContainer){foreach($f in ([IO.DirectoryInfo]::new($child.FullName)).EnumerateFiles('*',$options)){$size+=$f.Length;$count++}}else{$size=$child.Length;$count=1}
                $children+=@{name=$child.Name;bytes=$size;files=$count}
            }
            $details+=''
            $details+='### `'+$entry.name+'/`'
            $details+=''
            foreach($child in @($children|Sort-Object @{Expression={$_.bytes};Descending=$true}|Select-Object -First 5)){$details+='- `'+$child.name+'`: '+(& $format $child.bytes)+', '+$child.files+' file'}
        }
    }
    $lines=@('# Indice di .runtime','','Vista generata da `cleanup.ps1 -RuntimeReport`: non è una fonte, si rigenera quando serve e non autorizza cancellazioni.','',
        ('Totale: '+(& $format $report.totalBytes)+' in '+@($report.entries).Count+' voci. Ordine: categoria (protected, evidence, backup, working, regenerable), poi dimensione. Soglia di età: '+$OlderThanDays+' giorni.'),'',
        '| Voce | Categoria | Dimensione | File | Ultima scrittura | Rif. | Chi la scrive | Recupero |','|---|---|---:|---:|---|---:|---|---|')
    $lines+=$rows
    $lines+=@('','Per le nuove cartelle degli agenti usare `hosts/<id>/repos/<repo>/<categoria>/<yyyyMMdd>-<slug>` con categoria `work`, `evidence`, `fixture`, `tmp` o `report` (`work.ps1 -Category -Slug -Init`, che scrive `MANIFEST.json`); TEMP e TMP stanno in `hosts/<id>/repos/<repo>/temp`. Le cartelle piatte e non conformi si riordinano con `cleanup.ps1 -Migrate` (anteprima, poi `-Apply -Authorization`).')
    if(@($report.nested).Count){
        $lines+=@('','## Livelli annidati (hosts/<id>/repos)','','| Cartella | Categoria | Dimensione | File | Ultima scrittura | Nome |','|---|---|---:|---:|---|---|')
        foreach($n in @($report.nested|Sort-Object path)){$lines+='| `'+$n.path+'/` | '+$n.category+' | '+(& $format $n.bytes)+' | '+$n.files+' | '+$n.newestWriteUtc.Substring(0,10)+' | '+$(if($n.conventional){'conforme'}else{'non conforme'})+$(if($n.manifest){' + manifest'}elseif($n.area -in @('work','evidence','report')){' (senza manifest)'})+' |'}
    }
    if(@($report.legacy).Count){
        $lines+=@('','## Cartelle legacy (spostamento proposto, non eseguito)','','Precedono il layout annidato. Questa vista non sposta, non rinomina e non rimuove nulla: `<id>` e `<repo>` vanno risolti prima di un eventuale spostamento deciso dall''utente.','','| Cartella | Tipo | Dimensione | File | Ultima scrittura | Destinazione proposta |','|---|---|---:|---:|---|---|')
        foreach($l in @($report.legacy|Sort-Object path)){$lines+='| `'+$l.path+'` | '+$l.kind+' | '+(& $format $l.bytes)+' | '+$l.files+' | '+$l.newestWriteUtc.Substring(0,10)+' | `'+$l.suggestedPath+'` |'}
    }
    if($details.Count){$lines+=@('','## Dettaglio delle voci grandi')+$details}
    @{markdown=($lines -join "`n")+"`n";entries=$report.entries;totalBytes=$report.totalBytes;byCategory=$report.byCategory;nested=$report.nested;legacy=$report.legacy}
}
# Read-only .runtime cleanup proposal, NOT an executable manifest. Lists candidate folders with size, age, references and recovery instructions.
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
    # 1. Test fixtures: retain the latest; recreate the rest by rerunning suites.
    $testsDir=Join-Path $runtime 'tests'
    if(Test-Path -LiteralPath $testsDir -PathType Container){
        $folders=@(Get-ChildItem -LiteralPath $testsDir -Directory -Force|Where-Object {!($_.Attributes -band [IO.FileAttributes]::ReparsePoint)}|Sort-Object LastWriteTimeUtc -Descending)
        $old=@($folders|Select-Object -Skip $KeepFixtures)
        if($old.Count){
            $files=0;$bytes=0L;foreach($folder in $old){$m=& $measure $folder.FullName;$files+=$m.files;$bytes+=$m.bytes}
            $candidates+=@{path='tests/';category='regenerable';action=('rimuovere '+$old.Count+' cartelle fixture più vecchie su '+$folders.Count+', tenendo le ultime '+$KeepFixtures);folders=$old.Count;files=$files;bytes=$bytes;oldestUtc=($old|Sort-Object LastWriteTimeUtc|Select-Object -First 1).LastWriteTimeUtc.ToString('o');recovery='si ricrea rieseguendo le suite test-secondbrain*.ps1';references=(& $mentions 'tests')}
        }
    }
    # 2. MCP handshake reports beyond the threshold.
    $handshake=Join-Path $runtime 'mcp-handshake'
    if(Test-Path -LiteralPath $handshake -PathType Container){
        $oldFiles=@(Get-ChildItem -LiteralPath $handshake -File -Force|Where-Object {$_.LastWriteTimeUtc -lt $cutoff})
        if($oldFiles.Count){$candidates+=@{path='mcp-handshake/';category='regenerable';action=('rimuovere '+$oldFiles.Count+' rapporti oltre '+$OlderThanDays+' giorni');folders=0;files=$oldFiles.Count;bytes=[long](($oldFiles|Measure-Object Length -Sum).Sum);oldestUtc=($oldFiles|Sort-Object LastWriteTimeUtc|Select-Object -First 1).LastWriteTimeUtc.ToString('o');recovery='si ricrea rieseguendo test-secondbrain-mcp-handshake.ps1';references=(& $mentions 'mcp-handshake')}}
    }
    # 3. Per host: source Python environment (regenerable) and backup ZIPs beyond the two latest.
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
            # .bin backups whose content exists as a Git blob (SHA-256 equals previousHash, source tracked and clean): duplicates to review. Without a blob, the .bin is the only copy and is not a candidate.
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
    # 4. Agent work folders beyond the threshold, unprotected and unreferenced: review only.
    foreach($entry in @($report.entries|Where-Object {$_.category -eq 'working' -and !$_.protected -and $_.olderThanThreshold -and $_.references.mentions -eq 0})){
        $candidates+=@{path=$entry.name+'/';category='working';action='valutare la rimozione (lavoro temporaneo senza riferimenti nel repository)';folders=1;files=$entry.files;bytes=$entry.bytes;oldestUtc=$entry.newestWriteUtc;recovery=$entry.recovery;references=0}
    }
    # 5. Nested hosts/<id>/repos/<repo>: review only work folders beyond the threshold, excluding evidence and reports.
    foreach($n in @($report.nested|Where-Object {$_.category -eq 'working' -and $_.olderThanThreshold})){
        $candidates+=@{path=$n.path+'/';category='working';action='valutare la rimozione (lavoro temporaneo annidato oltre soglia)';folders=1;files=$n.files;bytes=$n.bytes;oldestUtc=$n.newestWriteUtc;recovery=$n.recovery;references=0}
    }
    $regenerable=0L;foreach($c in $candidates){if($c.category -eq 'regenerable'){$regenerable+=[long]$c.bytes}}
    @{scope='runtime-cleanup-proposal';applied=$false;generatedAt=[DateTimeOffset]::UtcNow.ToString('o');olderThanDays=$OlderThanDays;keepFixtures=$KeepFixtures;totalBytes=$report.totalBytes;byCategory=$report.byCategory;regenerableCandidateBytes=$regenerable;candidates=$candidates;legacy=@($report.legacy);
        note='Proposta di sola lettura, non un manifest eseguibile. Nessuna cartella è stata rimossa. L''applicazione richiede una richiesta esplicita e un perimetro concreto; i file con backup passano da cleanup.ps1 -ManifestPath.'}
}
# Clean only regenerable .runtime folders (test fixtures beyond the latest N, source Python environment): fixed scope, never arbitrary name-based selection.
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
            # Nested fixture/tmp folders: keep the latest N per repository and category, the rest is recreated by the suites.
            foreach($repoDir in @(Get-ChildItem -LiteralPath (Join-Path $hostDir.FullName 'repos') -Directory -Force -ErrorAction SilentlyContinue|Where-Object {!($_.Attributes -band [IO.FileAttributes]::ReparsePoint)})){
                foreach($category in @('fixture','tmp')){
                    $categoryDir=Join-Path $repoDir.FullName $category
                    if(!(Test-Path -LiteralPath $categoryDir -PathType Container)){continue}
                    $folders=@(Get-ChildItem -LiteralPath $categoryDir -Directory -Force|Where-Object {!($_.Attributes -band [IO.FileAttributes]::ReparsePoint)}|Sort-Object LastWriteTimeUtc -Descending)
                    foreach($folder in @($folders|Select-Object -Skip $KeepFixtures)){$candidates+=@{path=$folder.FullName;kind=('nested-'+$category);recovery='si ricrea rieseguendo le suite o il comando che l''ha creata'}}
                }
            }
        }
    }
    # Flat legacy fixture/tmp folders (<fixture|tmp>-<yyyyMMdd>-<slug>), the handshake reports and empty top-level folders are regenerable by definition.
    foreach($top in @(Get-ChildItem -LiteralPath $runtime -Directory -Force|Where-Object {!($_.Attributes -band [IO.FileAttributes]::ReparsePoint)})){
        $name=$top.Name.ToLowerInvariant()
        if($name -cmatch '^(fixture|tmp)-\d{8}-[a-z0-9][a-z0-9-]*$'){$candidates+=@{path=$top.FullName;kind='fixture-flat';recovery='si ricrea rieseguendo le suite o il comando che l''ha creata'};continue}
        if($name -eq 'mcp-handshake'){$candidates+=@{path=$top.FullName;kind='handshake-reports';recovery='si ricrea rieseguendo test-secondbrain-mcp-handshake.ps1'};continue}
        if($name -in $script:SBRuntimeManagedTopLevel -or $name -in @('backup','backups')){continue}
        if(!(Get-ChildItem -LiteralPath $top.FullName -Recurse -File -Force -ErrorAction SilentlyContinue|Select-Object -First 1)){$candidates+=@{path=$top.FullName;kind='empty-folder';recovery='cartella vuota: nessun contenuto da recuperare'}}
    }
    $targets=@();$skipped=@()
    foreach($candidate in $candidates){
        $path=$candidate.path;$item=Get-Item -LiteralPath $path -Force
        $relative=$path.Substring($runtime.Length+1).Replace('\','/')
        $reason=$null;$reasonCode=$null
        if($item.Attributes -band [IO.FileAttributes]::ReparsePoint){$reasonCode='reparse-point';$reason=Get-SBMessage 'core.runtime.reason.reparse-point'}
        elseif(@($protected|Where-Object {$_ -ieq $path -or $_.StartsWith($path+$sep,[StringComparison]::OrdinalIgnoreCase)}).Count){$reasonCode='protected-path';$reason=Get-SBMessage 'core.runtime.reason.protected-path'}
        $files=0;$bytes=0L;$newest=$item.LastWriteTimeUtc
        if(!$reason){
            foreach($file in ([IO.DirectoryInfo]::new($path)).EnumerateFiles('*',$options)){$files++;$bytes+=$file.Length;if($file.LastWriteTimeUtc -gt $newest){$newest=$file.LastWriteTimeUtc}}
            if($MinAgeMinutes -gt 0 -and $newest -gt [DateTime]::UtcNow.AddMinutes(-$MinAgeMinutes)){$reasonCode='recently-written';$reason=Get-SBMessage 'core.runtime.reason.recently-written' @($MinAgeMinutes)}
        }
        $entry=@{path=$path;relative=$relative;kind=$candidate.kind;files=$files;bytes=$bytes;newestWriteUtc=$newest.ToString('o');recovery=$candidate.recovery}
        if($reason){$entry.reason=$reason;$entry.reasonCode=$reasonCode;$skipped+=$entry}else{$targets+=$entry}
    }
    $totalBytes=0L;$totalFiles=0L;foreach($target in $targets){$totalBytes+=$target.bytes;$totalFiles+=$target.files}
    @{targets=@($targets);skipped=@($skipped);keepFixtures=$KeepFixtures;minAgeMinutes=$MinAgeMinutes;bytes=$totalBytes;files=$totalFiles}
}
# Normalizes a runtime folder name to <yyyyMMdd>-<slug>: strips repeated category prefixes and duplicate dates, keeps the original date (or the last write date).
function ConvertTo-SBRuntimeFolderName([string]$Name,[DateTime]$Newest) {
    $n=$Name.ToLowerInvariant();$date=$null
    for($i=0;$i -lt 6;$i++){
        if($n -match '^(?:work|evidence|report|fixture|tmp|backup)-(.+)$'){$n=$Matches[1];continue}
        if($n -match '^(\d{8})-(.+)$'){if(!$date){$date=$Matches[1]};$n=$Matches[2];continue}
        break
    }
    if(!$date){$date=$Newest.ToString('yyyyMMdd')}
    $slug=(($n -replace '[^a-z0-9]+','-').Trim('-'));if(!$slug){$slug='cartella'}
    if($slug.Length -gt 50){$slug=$slug.Substring(0,50).Trim('-')}
    $date+'-'+$slug
}
# Read-only plan that reorders .runtime into the nested layout. Flat fixture/tmp folders are not migrated (regenerable: removed by cleanup -Regenerable).
# Moves: flat work/evidence/report folders, host-level evidence/report folders, duplicate repository segments, non-conforming nested names,
# flat backup-<date>-* folders (hosts/<id>/install-backups), backup/* into backups/*, root *.log into logs/.
function Get-SBRuntimeMigrationPlan([string]$BrainRoot,[string]$HostId,[string]$Segment,[int]$MinAgeMinutes=10) {
    $runtime=[IO.Path]::GetFullPath((Join-Path $BrainRoot '.runtime')).TrimEnd('\','/')
    $hostRoot=Join-Path $runtime ('hosts/'+$HostId)
    $options=[IO.EnumerationOptions]::new();$options.RecurseSubdirectories=$true;$options.IgnoreInaccessible=$true;$options.AttributesToSkip=[IO.FileAttributes]::ReparsePoint
    $moves=@();$skipped=@();$taken=@{}
    $newestOf={param([string]$Path) $t=[DateTime]::MinValue;foreach($f in ([IO.DirectoryInfo]::new($Path)).EnumerateFiles('*',$options)){if($f.LastWriteTimeUtc -gt $t){$t=$f.LastWriteTimeUtc}};if($t -eq [DateTime]::MinValue){$t=(Get-Item -LiteralPath $Path -Force).LastWriteTimeUtc};$t}
    $sizeOf={param([string]$Path) $n=0;$b=0L;foreach($f in ([IO.DirectoryInfo]::new($Path)).EnumerateFiles('*',$options)){$n++;$b+=$f.Length};@{files=$n;bytes=$b}}
    $rel={param([string]$Path) $Path.Substring($runtime.Length+1).Replace('\','/')}
    $dirs={param([string]$Path) if(Test-Path -LiteralPath $Path -PathType Container){@(Get-ChildItem -LiteralPath $Path -Directory -Force|Sort-Object Name)}else{@()}}
    $add={param($Item,[string]$Kind,[string]$Destination,[string]$Category)
        if($Item.Attributes -band [IO.FileAttributes]::ReparsePoint){$script:skippedLocal+=@{from=(& $rel $Item.FullName);reason='reparse-point'};return}
        $isDir=[bool]($Item.Attributes -band [IO.FileAttributes]::Directory)
        $newest=if($isDir){& $newestOf $Item.FullName}else{$Item.LastWriteTimeUtc}
        if($MinAgeMinutes -gt 0 -and $newest -gt [DateTime]::UtcNow.AddMinutes(-$MinAgeMinutes)){$script:skippedLocal+=@{from=(& $rel $Item.FullName);reason='recently-written'};return}
        $target=$Destination;$i=1
        while($taken.ContainsKey($target.ToLowerInvariant()) -or (Test-Path -LiteralPath $target)){$i++;$target=$Destination+'-'+$i}
        if($target -ieq $Item.FullName){return}
        $taken[$target.ToLowerInvariant()]=$true
        $m=if($isDir){& $sizeOf $Item.FullName}else{@{files=1;bytes=$Item.Length}}
        $script:movesLocal+=@{from=$Item.FullName;to=$target;fromRelative=(& $rel $Item.FullName);toRelative=(& $rel $target);kind=$Kind;category=$Category;directory=$isDir;files=$m.files;bytes=$m.bytes;newestWriteUtc=$newest.ToString('o')}
    }
    $script:movesLocal=@();$script:skippedLocal=@()
    $repoRoot=Join-Path $hostRoot ('repos/'+$Segment)
    # 1. Flat work/evidence/report at the top level of .runtime.
    foreach($d in (& $dirs $runtime)){
        if($d.Name -cmatch '^(?<c>work|evidence|report)-\d{8}-'){$c=$Matches.c;& $add $d ('flat-'+$c) (Join-Path $repoRoot ($c+'/'+(ConvertTo-SBRuntimeFolderName $d.Name (& $newestOf $d.FullName)))) $c}
        elseif($d.Name -cmatch '^backup-\d{8}-'){& $add $d 'install-backup' (Join-Path $hostRoot ('install-backups/'+(ConvertTo-SBRuntimeFolderName $d.Name (& $newestOf $d.FullName)))) 'install-backup'}
    }
    # 2. backup/* into backups/*.
    foreach($child in @(Get-ChildItem -LiteralPath (Join-Path $runtime 'backup') -Force -ErrorAction SilentlyContinue)){& $add $child 'backup-merge' (Join-Path $runtime ('backups/'+$child.Name)) 'backup'}
    # 3. Root logs.
    foreach($f in @(Get-ChildItem -LiteralPath $runtime -File -Force -Filter '*.log')){& $add $f 'log' (Join-Path $runtime ('logs/'+$f.Name)) 'log'}
    # 4. Host-level evidence/report/work folders.
    foreach($d in (& $dirs $hostRoot)){
        if($d.Name -cmatch '^(?<c>work|evidence|report)-\d{8}-'){$c=$Matches.c;& $add $d ('host-'+$c) (Join-Path $repoRoot ($c+'/'+(ConvertTo-SBRuntimeFolderName $d.Name (& $newestOf $d.FullName)))) $c}
    }
    # 5. Repository segments of this host: merge segments without hash into the canonical one, normalize non-conforming names.
    foreach($seg in (& $dirs (Join-Path $hostRoot 'repos'))){
        $canonical=($seg.Name -ceq $Segment);$hasHash=($seg.Name -cmatch '-[0-9a-f]{8}$')
        foreach($category in @('work','evidence','report')){
            foreach($d in (& $dirs (Join-Path $seg.FullName $category))){
                $name=ConvertTo-SBRuntimeFolderName $d.Name (& $newestOf $d.FullName)
                if(!$hasHash -or $canonical){
                    if($canonical -and $d.Name -ceq $name){continue}
                    $kind=if($canonical){'rename'}else{'merge-segment'}
                    & $add $d $kind (Join-Path $repoRoot ($category+'/'+$name)) $category
                }elseif($d.Name -cne $name){& $add $d 'rename' (Join-Path $seg.FullName ($category+'/'+$name)) $category}
            }
        }
    }
    $totalFiles=0L;$totalBytes=0L;foreach($m in $script:movesLocal){$totalFiles+=[long]$m.files;$totalBytes+=[long]$m.bytes}
    @{hostId=$HostId;segment=$Segment;minAgeMinutes=$MinAgeMinutes;moves=@($script:movesLocal);skipped=@($script:skippedLocal);files=$totalFiles;bytes=$totalBytes}
}
# Applies the moves of Get-SBRuntimeMigrationPlan (same volume, no copies): rename/move only, writes MANIFEST.json for work/evidence/report folders, removes emptied sources.
function Invoke-SBRuntimeMigration([string]$BrainRoot,$Plan) {
    $runtime=[IO.Path]::GetFullPath((Join-Path $BrainRoot '.runtime')).TrimEnd('\','/')
    $inside={param([string]$Path) $full=[IO.Path]::GetFullPath($Path);$full.StartsWith($runtime+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)}
    $done=@();$failed=@();$parents=@{}
    foreach($move in @($Plan.moves)){
        try{
            if(!(& $inside $move.from) -or !(& $inside $move.to)){throw (New-SBError 'core.runtime.outside')}
            if(Test-Path -LiteralPath $move.to){throw (New-SBError 'core.migrate.destination' @($move.toRelative))}
            [IO.Directory]::CreateDirectory((Split-Path $move.to))|Out-Null
            if($move.directory){[IO.Directory]::Move($move.from,$move.to)}else{[IO.File]::Move($move.from,$move.to)}
            $parents[(Split-Path $move.from)]=$true
            if($move.directory -and $move.category -in @('work','evidence','report')){
                $manifest=Join-Path $move.to 'MANIFEST.json'
                if(!(Test-Path -LiteralPath $manifest)){
                    $leaf=Split-Path $move.to -Leaf
                    $created=if($leaf -match '^(\d{4})(\d{2})(\d{2})-'){"$($Matches[1])-$($Matches[2])-$($Matches[3])"}else{$null}
                    $record=@{schemaVersion=1;category=$move.category;name=$leaf;created=$created;hostId=$Plan.hostId;repository=$Plan.segment;sessionId=$null;task=$null;status='migrated';expires=$null;migratedFrom=$move.fromRelative;migratedAt=[DateTimeOffset]::Now.ToString('o')}
                    [IO.File]::WriteAllText($manifest,(ConvertTo-SBJson $record),[Text.UTF8Encoding]::new($false))
                }
            }
            $done+=@{from=$move.fromRelative;to=$move.toRelative;kind=$move.kind;files=$move.files;bytes=$move.bytes}
        }catch{$failed+=@{from=$move.fromRelative;to=$move.toRelative;error=$_.Exception.Message}}
    }
    # Remove only emptied sources (never a non-empty folder, never a protected top-level one).
    $removed=@()
    foreach($parent in @($parents.Keys|Sort-Object {$_.Length} -Descending)){
        $p=$parent
        while($p -and (& $inside $p) -and (Test-Path -LiteralPath $p -PathType Container) -and !(Get-ChildItem -LiteralPath $p -Force|Select-Object -First 1)){
            $leaf=Split-Path $p -Leaf
            if($leaf -in @('hosts','repos','access','backups','logs','trace','publication','cleanup') -or $leaf -like 'ws-*'){break}
            [IO.Directory]::Delete($p);$removed+=$p.Substring($runtime.Length+1).Replace('\','/');$p=Split-Path $p
        }
    }
    @{moved=@($done);failed=@($failed);removedEmpty=@($removed)}
}
function Remove-SBRuntimeTree([string]$Path,[string]$BrainRoot) {
    # Remove a folder under .runtime without following junctions/symlinks (unlink only), clearing read-only attributes (Git objects).
    $runtime=[IO.Path]::GetFullPath((Join-Path $BrainRoot '.runtime')).TrimEnd('\','/')
    $full=[IO.Path]::GetFullPath($Path).TrimEnd('\','/')
    if(!$full.StartsWith($runtime+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw (New-SBError 'core.runtime.outside')}
    $root=Get-Item -LiteralPath $full -Force
    if($root.Attributes -band [IO.FileAttributes]::ReparsePoint){throw (New-SBError 'core.runtime.reparse')}
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
    # Git emits UTF-8: without an explicit encoding, accented paths become corrupted.
    $start.StandardOutputEncoding = [Text.UTF8Encoding]::new($false); $start.StandardErrorEncoding = [Text.UTF8Encoding]::new($false)
    $prefix = @('--no-optional-locks','-c','core.fsmonitor=false','-c','core.quotepath=false')
    # A brain on a share often has a different owner from the current user: Git refuses the path ("dubious ownership").
    # Consent is limited to the brain itself, never product checkouts.
    $brainRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    if ($Root.StartsWith('\\') -and (Test-SBSamePath $Root $brainRoot)) { $prefix += @('-c', ('safe.directory=' + ($Root -replace '\\', '/'))) }
    foreach ($arg in $prefix + @('-C',$Root) + $GitArguments) { $start.ArgumentList.Add($arg) }
    $start
}
function Invoke-SBGit([string]$Root, [string[]]$GitArguments, [int]$TimeoutMs = 10000, [switch]$PreserveOutput, [string]$InputText) {
    $start = New-SBGitStartInfo $Root $GitArguments
    $start.RedirectStandardInput = $PSBoundParameters.ContainsKey('InputText')
    $process = [Diagnostics.Process]::Start($start)
    try {
        $stdout = $process.StandardOutput.ReadToEndAsync(); $stderr = $process.StandardError.ReadToEndAsync()
        $inputWriter = if ($start.RedirectStandardInput) { $process.StandardInput.WriteAsync($InputText) }
        if ($inputWriter) {
            if (!$inputWriter.Wait($TimeoutMs)) { $process.Kill($true); throw (New-SBError 'core.git.timeout' @($Root)) }
            $process.StandardInput.Close()
        }
        if (!$process.WaitForExit($TimeoutMs)) { $process.Kill($true); throw (New-SBError 'core.git.timeout' @($Root)) }
        $output=$stdout.GetAwaiter().GetResult()
        @{ code = $process.ExitCode; output = $(if($PreserveOutput){$output}else{$output.Trim()}); error = $stderr.GetAwaiter().GetResult().Trim() }
    } finally { $process.Dispose() }
}
# Types and sizes of many objects in one process (cat-file --batch-check): oid -> @{type;size}; omit missing objects.
function Get-SBGitObjectInfo([string]$Root, [string[]]$ObjectIds, [int]$TimeoutMs = 120000, [switch]$NoReplaceObjects) {
    $info = @{}
    if (!$ObjectIds.Count) { return $info }
    $gitArguments = @('cat-file','--batch-check')
    if ($NoReplaceObjects) { $gitArguments = @('--no-replace-objects') + $gitArguments }
    $start = New-SBGitStartInfo $Root $gitArguments
    $start.RedirectStandardInput = $true; $start.StandardInputEncoding = [Text.UTF8Encoding]::new($false)
    $process = [Diagnostics.Process]::Start($start)
    try {
        $stdout = $process.StandardOutput.ReadToEndAsync(); $stderr = $process.StandardError.ReadToEndAsync()
        $process.StandardInput.Write((($ObjectIds -join "`n") + "`n")); $process.StandardInput.Close()
        if (!$process.WaitForExit($TimeoutMs)) { $process.Kill($true); throw (New-SBError 'core.git.timeout' @($Root)) }
        foreach ($line in $stdout.GetAwaiter().GetResult() -split "`n") {
            if ($line -match '^([a-f0-9]{40,64}) (blob|tree|commit|tag) (\d+)\s*$') { $info[$Matches[1]] = @{ type = $Matches[2]; size = [long]$Matches[3] } }
        }
        if ($process.ExitCode -ne 0) { throw (New-SBError 'core.git.batchcheck' @($stderr.GetAwaiter().GetResult().Trim())) }
    } finally { $process.Dispose() }
    $info
}
# Stream many blobs through one process (cat-file --batch), in Entries order (use in a pipeline).
# Each entry: @{Oid;Skip}. Entries with Skip are not read (Bytes null). Emits @{Entry;Bytes;Missing}.
function Read-SBGitBlobs([string]$Root, [object[]]$Entries, [int]$ReadTimeoutMs = 60000, [switch]$NoReplaceObjects) {
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
            $gitArguments = @('cat-file','--batch')
            if ($NoReplaceObjects) { $gitArguments = @('--no-replace-objects') + $gitArguments }
            $start = New-SBGitStartInfo $Root $gitArguments
            $start.RedirectStandardInput = $true; $start.StandardInputEncoding = [Text.UTF8Encoding]::new($false)
            $process = [Diagnostics.Process]::Start($start)
            $stderr = $process.StandardError.ReadToEndAsync()
            $writer = $process.StandardInput.WriteAsync((($wanted -join "`n") + "`n"))
            $reader = [SBGitBatchReader]::new($process.StandardOutput.BaseStream, $ReadTimeoutMs)
        }
        foreach ($entry in $Entries) {
            if ($entry.Skip) { [pscustomobject]@{ Entry = $entry; Bytes = $null; Missing = $false }; continue }
            $header = $reader.ReadLine()
            if ($null -eq $header) { throw (New-SBError 'core.git.stream') }
            if ($header -match '^[a-f0-9]{40,64} missing$') { [pscustomobject]@{ Entry = $entry; Bytes = $null; Missing = $true }; continue }
            if ($header -notmatch '^([a-f0-9]{40,64}) \S+ (\d+)$' -or $Matches[1] -ne $entry.Oid) { throw (New-SBError 'core.git.header' @($header)) }
            $bytes = $reader.ReadBytes([long]$Matches[2]); $null = $reader.ReadBytes(1)
            [pscustomobject]@{ Entry = $entry; Bytes = $bytes; Missing = $false }
        }
        if ($process) { $writer.Wait(); $process.StandardInput.Close(); if (!$process.WaitForExit($ReadTimeoutMs)) { throw (New-SBError 'core.git.timeout' @($Root)) } }
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
    # Resolve junctions and symlinks in every existing component so aliases and real paths compare equal.
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
    # A brain without its own repository (ZIP, nested folder) does not inherit a parent repository's origin.
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
    if($matches.Count -gt 1){throw (New-SBError 'core.checkout.ambiguous')}
    if($matches.Count -eq 1){if($matches[0].remoteIdentity -cne $remote){throw (New-SBError 'core.origin.changed')};return $matches[0].identity}
    $remote
}
function Resolve-SBWorkingRepository([string]$Path='',$Bindings=@()) {
    # Working checkout repository (default: current directory); $null unless it is a Git checkout with an identity.
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
    if($WorkstationId -notmatch '^[a-zA-Z0-9][a-zA-Z0-9_-]{0,63}$'){throw (New-SBError 'core.workstation.invalid')}
    [IO.Path]::GetFullPath((Join-Path $BrainRoot ('.runtime/hosts/'+$WorkstationId)))
}
function Assert-SBCentralDataPath([string]$BrainRoot,[string]$Path) {
    $boundary=[IO.Path]::GetFullPath((Join-Path $BrainRoot '.runtime')).TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
    $full=[IO.Path]::GetFullPath($Path)
    if(!$full.StartsWith($boundary,[StringComparison]::OrdinalIgnoreCase)){throw (New-SBError 'core.output.outside' @($full))}
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
    if ($matches.Count -gt 1) { throw (New-SBError 'core.block.duplicate' @($Id)) }
    if ($matches.Count -eq 1) { return $matches[0].Value }
    if ($Text.Contains("<!-- secondbrain:${Id}:")) { throw (New-SBError 'core.block.incomplete' @($Id)) }
    return $null
}
function Set-SBManagedContent {
    param([string]$Path,[string]$Body,[string]$Id,[hashtable]$State,[bool]$Check,[string]$BackupRoot,[switch]$WholeFile,[switch]$AfterTitle)
    $beforeHash = Get-SBFileHash $Path
    $text = if ($beforeHash -eq 'absent') { '' } else { Read-SBText $Path }
    $key = [IO.Path]::GetFullPath($Path)+'|'+$Id
    $wanted = if ($WholeFile) { $Body } else { "<!-- secondbrain:${Id}:begin -->`n"+$Body.Trim()+"`n<!-- secondbrain:${Id}:end -->" }
    $existing = if ($WholeFile) { $text } else { Get-SBManagedContent $text $Id }
    # Git checkouts with autocrlf rewrite line endings: a block that differs only by CRLF is aligned, not a conflict.
    $comparable = if ($null -ne $existing) { $existing.Replace("`r`n","`n") } else { $null }
    $oldHash = if ($null -eq $existing -or ($WholeFile -and $beforeHash -eq 'absent')) { 'absent' } else { Get-SBTextHash $comparable }
    if ($comparable -ceq $wanted) {
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
        if (Test-SBError $_ 'core.tracked.dirty') { Write-Warning $_.Exception.Message; return 'conflict' }
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
        private static string GetNativePath(string path) {
            // Extended paths are already literal; ordinary paths must be normalized
            // before disabling Win32 parsing (relative segments and forward slashes).
            if (path.StartsWith(@"\\?\", StringComparison.Ordinal) ||
                path.StartsWith(@"\\.\", StringComparison.Ordinal)) return path;
            string full = Path.GetFullPath(path).Replace('/', '\\');
            return full.StartsWith(@"\\", StringComparison.Ordinal)
                ? @"\\?\UNC\" + full.Substring(2)
                : @"\\?\" + full;
        }
        public static FileStream Open(string path) {
            var handle = CreateFileW(GetNativePath(path), 0x80010000, 1, IntPtr.Zero, 3, 0x80, IntPtr.Zero);
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
    if(!$full.StartsWith($boundary,[StringComparison]::OrdinalIgnoreCase)){throw (New-SBError 'core.remove.outside' @($full))}
    Assert-SBPlainPath $full
    if((Get-SBFileHash $full) -ne $ExpectedHash -or $ExpectedHash -eq 'absent'){throw (New-SBError 'core.remove.changed' @($full))}
    $script:SBWriteGeneration++
    Assert-SBPlainPath $BackupRoot
    Initialize-SBFileRemoval
    $stream=[SecondBrain.FileRemoval]::Open($full)
    try {
        $copy=[IO.MemoryStream]::new()
        try{$stream.CopyTo($copy);$bytes=$copy.ToArray()}finally{$copy.Dispose()}
        if((Get-SBHash $bytes) -ne $ExpectedHash){throw (New-SBError 'core.remove.concurrent')}
        [IO.Directory]::CreateDirectory($BackupRoot)|Out-Null
        $backup=Join-Path $BackupRoot ([guid]::NewGuid().ToString('N')+'.bin')
        [IO.File]::WriteAllBytes($backup,$bytes)
        if((Get-SBFileHash $backup) -ne $ExpectedHash){throw (New-SBError 'core.remove.backup')}
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
    $repositorySource='direttive/AGENTS.repo.managed.md'
    $repositoryHash=Get-SBFileHash (Join-Path $BrainRoot $repositorySource)
    if($approval.files.ContainsKey($repositorySource) -or $repositoryHash -ne 'absent'){
        if($repositoryHash -eq 'absent' -or $approval.files[$repositorySource] -cne $repositoryHash){return $false}
    }
    return $true
}
Export-ModuleMember -Function @(
    'Set-SBWriteGuard',
    'Get-SBWriteGuard',
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
    'Get-SBWriteDeniedException',
    'Test-SBWriteDeniedError',
    'ConvertTo-SBWriteError',
    'Get-SBRetryCommand',
    'Write-SBWriteDeniedDiagnostic',
    'Get-SBIDEWriteScope',
    'Get-SBStageRetention',
    'Get-SBRuntimeRetention',
    'Get-SBRuntimeIndex',
    'Get-SBRuntimeCleanupProposal',
    'Get-SBRegenerableRuntimeTargets',
    'ConvertTo-SBRuntimeFolderName',
    'Get-SBRuntimeMigrationPlan',
    'Invoke-SBRuntimeMigration',
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
