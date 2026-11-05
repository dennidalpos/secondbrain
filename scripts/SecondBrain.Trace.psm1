#requires -Version 7.5
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Host.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Add-SBMessages @{
    'trace.settings.json' = @{ it = 'settings.json non e JSON valido: nessuna modifica'; en = 'settings.json is not valid JSON: no change made' }
    'trace.settings.object' = @{ it = 'settings.json non e un oggetto JSON: nessuna modifica'; en = 'settings.json is not a JSON object: no change made' }
}

# End-of-turn trace: metadata without prompt text in .runtime/trace/<host>/<yyyy-MM-dd>.jsonl, one event per line.
# Used only to count turns since compaction; not a knowledge source and grants no authorization.
function Get-SBTraceRoot([string]$BrainRoot) { Join-Path ([IO.Path]::GetFullPath($BrainRoot)) '.runtime/trace' }

function Resolve-SBTraceRepository([string]$BrainRoot,[string]$Cwd) {
    if(!$Cwd){return ''}
    $configPath=Get-SBHostConfigPath $BrainRoot
    if(!(Test-Path -LiteralPath $configPath -PathType Leaf)){return ''}
    $config=Read-SBJson $configPath $null
    if(!$config -or !$config.ContainsKey('bindings')){return ''}
    $full=[IO.Path]::GetFullPath($Cwd).TrimEnd('\','/')
    $best='';$bestLength=-1
    foreach($binding in @($config.bindings)){
        if(!$binding.ContainsKey('path') -or !$binding.ContainsKey('identity')){continue}
        $root=[IO.Path]::GetFullPath([string]$binding.path).TrimEnd('\','/')
        if(($full -ieq $root -or $full.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) -and $root.Length -gt $bestLength){$best=[string]$binding.identity;$bestLength=$root.Length}
    }
    $best
}

# Append an event. Uses no writer lock (one file per workstation/day; appends serialized by a short day lock) and never writes prompt contents.
function Add-SBTraceEvent([string]$BrainRoot,[string]$EventName='stop',[string]$InputJson='',[string]$Ide='claude-code') {
    $payload=@{}
    if($InputJson.Trim()){try{$parsed=$InputJson|ConvertFrom-Json -AsHashtable -ErrorAction Stop;if($parsed -is [Collections.IDictionary]){$payload=$parsed}}catch{}}
    # A legacy hook without per-turn permission is intentionally silent. Installation grants no consent.
    if(!$payload.ContainsKey('persistence') -or $payload.persistence -cne 'allowed' -or
       !$payload.ContainsKey('policyEvidence') -or [string]::IsNullOrWhiteSpace([string]$payload.policyEvidence)){return $null}
    $cwd=if($payload.ContainsKey('cwd')){[string]$payload.cwd}else{(Get-Location).Path}
    $session=if($payload.ContainsKey('session_id')){[string]$payload.session_id}else{''}
    if($session -notmatch '^[A-Za-z0-9_.-]{0,128}$'){$session=''}
    $record=[ordered]@{schemaVersion=1;ts=[DateTimeOffset]::Now.ToString('o');ide=$Ide;sessionId=$session;event=$EventName;repository=(Resolve-SBTraceRepository $BrainRoot $cwd);cwdHash=(Get-SBTextHash $cwd.ToLowerInvariant()).Substring(0,16).ToLowerInvariant()}
    $directory=Join-Path (Get-SBTraceRoot $BrainRoot) (Get-SBHostId)
    $target=Assert-SBCentralDataPath $BrainRoot (Join-Path $directory ([DateTime]::Now.ToString('yyyy-MM-dd')+'.jsonl'))
    [IO.Directory]::CreateDirectory($directory)|Out-Null
    $bytes=[Text.UTF8Encoding]::new($false).GetBytes((($record|ConvertTo-Json -Compress -Depth 4)+"`n"))
    # .NET FileMode.Append writes at the offset read on open: simultaneous writers overwrite each other. A short <day>.jsonl.lock
    # serializes appends; if not acquired within ~2 s, append anyway (the hook stays fail-open and never blocks the turn).
    $gate=$null
    for($attempt=0;$attempt -lt 200 -and $null -eq $gate;$attempt++){
        try{$gate=[IO.FileStream]::new($target+'.lock',[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}
        catch [IO.IOException]{Start-Sleep -Milliseconds 10}
        catch [UnauthorizedAccessException]{throw}
    }
    try{
        $stream=[IO.FileStream]::new($target,[IO.FileMode]::Append,[IO.FileAccess]::Write,[IO.FileShare]::ReadWrite)
        try{$stream.Write($bytes,0,$bytes.Length);$stream.Flush()}finally{$stream.Dispose()}
    }finally{if($gate){$gate.Dispose()}}
    $target
}

# Recorded turns for a repository after the specified time (all workstations). Ignore unreadable lines.
function Get-SBTraceTurns([string]$BrainRoot,[string]$Repository,[DateTimeOffset]$Since=[DateTimeOffset]::MinValue) {
    $root=Get-SBTraceRoot $BrainRoot
    if(!$Repository -or !(Test-Path -LiteralPath $root -PathType Container)){return 0}
    $sinceDay=if($Since -eq [DateTimeOffset]::MinValue){''}else{$Since.ToLocalTime().ToString('yyyy-MM-dd')}
    $count=0
    foreach($file in Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.jsonl' -Force){
        if($sinceDay -and $file.BaseName -lt $sinceDay){continue}
        foreach($line in [IO.File]::ReadLines($file.FullName)){
            if(!$line.Contains($Repository)){continue}
            try{$entry=$line|ConvertFrom-Json -AsHashtable -ErrorAction Stop}catch{continue}
            if($entry.event -ne 'stop' -or $entry.repository -cne $Repository){continue}
            if([DateTimeOffset]::Parse([string]$entry.ts) -gt $Since){$count++}
        }
    }
    $count
}

function Get-SBCapturedTraceTurns([string]$BrainRoot,[string]$Repository,[DateTimeOffset]$Since=[DateTimeOffset]::MinValue) {
    # Metadata indexes only: never load raw captured conversations to count turns.
    if(!(Test-SBRepositoryIdentity $Repository)){return 0}
    $root=Join-Path $BrainRoot ('.runtime/hosts/'+(Get-SBHostId)+'/repos/'+(Get-SBRuntimeRepoSegment $Repository)+'/evidence')
    Assert-SBPlainPath $root
    if(![IO.Directory]::Exists($root)){return 0}
    $seen=@{}
    foreach($folder in Get-ChildItem -LiteralPath $root -Directory){
        $path=Join-Path $folder.FullName 'turns-index.json';Assert-SBPlainPath $path
        if(![IO.File]::Exists($path)){continue}
        $index=Read-SBJson $path $null
        if(!$index -or $index.repository -cne $Repository -or $index.schemaVersion -ne 1){continue}
        foreach($turn in @($index.turns)){
            $date=[DateTimeOffset]::MinValue
            if($turn.id -cmatch '^[a-f0-9]{64}$' -and [DateTimeOffset]::TryParse([string]$turn.capturedAt,[ref]$date) -and $date -gt $Since){$seen[$turn.id]=$true}
        }
    }
    $seen.Count
}

# Claude Code Stop hook: settings.json entry running trace.ps1 at turn end. Recognized by script path; leave other entries intact.
function Get-SBTraceHookCommand([string]$BrainRoot) {
    $script=([IO.Path]::GetFullPath((Join-Path $BrainRoot 'scripts/trace.ps1'))).Replace('\','/')
    'pwsh -NoProfile -File "'+$script+'" -Event stop'
}
function Get-SBTraceSettingsPath { Join-Path ([Environment]::GetFolderPath('UserProfile')) '.claude/settings.json' }
function Get-SBTraceHookState([string]$BrainRoot,[string]$SettingsPath=(Get-SBTraceSettingsPath)) {
    $command=Get-SBTraceHookCommand $BrainRoot
    $settings=@{}
    if(Test-Path -LiteralPath $SettingsPath -PathType Leaf){
        $text=Read-SBText $SettingsPath
        if($text.Trim()){try{$settings=$text|ConvertFrom-Json -AsHashtable -ErrorAction Stop}catch{throw (New-SBError 'trace.settings.json')}}
    }
    if($settings -isnot [Collections.IDictionary]){throw (New-SBError 'trace.settings.object')}
    $installed=$false
    if($settings.ContainsKey('hooks') -and $settings.hooks -is [Collections.IDictionary] -and $settings.hooks.ContainsKey('Stop')){
        foreach($group in @($settings.hooks.Stop)){
            if($group -is [Collections.IDictionary] -and $group.ContainsKey('hooks')){foreach($hook in @($group.hooks)){if($hook -is [Collections.IDictionary] -and $hook.ContainsKey('command') -and [string]$hook.command -eq $command){$installed=$true}}}
        }
    }
    @{settingsPath=$SettingsPath;command=$command;installed=$installed;settings=$settings;hash=(Get-SBFileHash $SettingsPath)}
}
function Set-SBTraceHook([string]$BrainRoot,[string]$BackupRoot,[switch]$Remove,[switch]$Apply,[string]$SettingsPath=(Get-SBTraceSettingsPath)) {
    $state=Get-SBTraceHookState $BrainRoot $SettingsPath
    $settings=$state.settings
    $changes=$false
    if($Remove){
        if($state.installed){
            $kept=@()
            foreach($group in @($settings.hooks.Stop)){
                $remaining=@(@($group.hooks)|Where-Object {!($_ -is [Collections.IDictionary] -and $_.ContainsKey('command') -and [string]$_.command -eq $state.command)})
                if($remaining.Count){$group.hooks=$remaining;$kept+=$group}
            }
            if($kept.Count){$settings.hooks.Stop=$kept}else{$settings.hooks.Remove('Stop');if(!$settings.hooks.Count){$settings.Remove('hooks')}}
            $changes=$true
        }
    }elseif(!$state.installed){
        if(!$settings.ContainsKey('hooks') -or $settings.hooks -isnot [Collections.IDictionary]){$settings.hooks=@{}}
        $groups=if($settings.hooks.ContainsKey('Stop')){@($settings.hooks.Stop)}else{@()}
        $settings.hooks.Stop=@($groups)+@(@{hooks=@(@{type='command';command=$state.command})})
        $changes=$true
    }
    $result=@{applied=$false;preview=!$Apply;installed=$state.installed;changed=$changes;settingsPath=$state.settingsPath;command=$state.command}
    if(!$Apply -or !$changes){return $result}
    $bytes=[Text.UTF8Encoding]::new($false).GetBytes((ConvertTo-SBJson $settings))
    [void](Write-SBFile $state.settingsPath $bytes $state.hash $BackupRoot -BackupDirty)
    $result.applied=$true;$result.installed=!$Remove
    $result
}

Export-ModuleMember -Function @('Get-SBTraceRoot','Resolve-SBTraceRepository','Add-SBTraceEvent','Get-SBTraceTurns','Get-SBCapturedTraceTurns','Get-SBTraceHookCommand','Get-SBTraceSettingsPath','Get-SBTraceHookState','Set-SBTraceHook')
