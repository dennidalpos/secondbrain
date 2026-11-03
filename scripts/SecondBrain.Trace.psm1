#requires -Version 7.5
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Host.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Add-SBMessages @{
    'trace.settings.json' = @{ it = 'settings.json non e JSON valido: nessuna modifica'; en = 'settings.json is not valid JSON: no change made' }
    'trace.settings.object' = @{ it = 'settings.json non e un oggetto JSON: nessuna modifica'; en = 'settings.json is not a JSON object: no change made' }
}

# Traccia di fine turno: metadati senza testo di prompt in .runtime/trace/<host>/<yyyy-MM-dd>.jsonl, una riga per evento.
# Serve solo a contare i turni dall'ultima compattazione; non e una fonte di conoscenza e non autorizza nulla.
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

# Accoda un evento. Non usa il lock dei writer (un file per postazione e giorno, append serializzato da un lock breve sul giorno) e non scrive mai il contenuto del prompt.
function Add-SBTraceEvent([string]$BrainRoot,[string]$EventName='stop',[string]$InputJson='',[string]$Ide='claude-code') {
    $payload=@{}
    if($InputJson.Trim()){try{$parsed=$InputJson|ConvertFrom-Json -AsHashtable -ErrorAction Stop;if($parsed -is [Collections.IDictionary]){$payload=$parsed}}catch{}}
    $cwd=if($payload.ContainsKey('cwd')){[string]$payload.cwd}else{(Get-Location).Path}
    $session=if($payload.ContainsKey('session_id')){[string]$payload.session_id}else{''}
    if($session -notmatch '^[A-Za-z0-9_.-]{0,128}$'){$session=''}
    $record=[ordered]@{schemaVersion=1;ts=[DateTimeOffset]::Now.ToString('o');ide=$Ide;sessionId=$session;event=$EventName;repository=(Resolve-SBTraceRepository $BrainRoot $cwd);cwdHash=(Get-SBTextHash $cwd.ToLowerInvariant()).Substring(0,16).ToLowerInvariant()}
    $directory=Join-Path (Get-SBTraceRoot $BrainRoot) (Get-SBHostId)
    $target=Assert-SBCentralDataPath $BrainRoot (Join-Path $directory ([DateTime]::Now.ToString('yyyy-MM-dd')+'.jsonl'))
    [IO.Directory]::CreateDirectory($directory)|Out-Null
    $bytes=[Text.UTF8Encoding]::new($false).GetBytes((($record|ConvertTo-Json -Compress -Depth 4)+"`n"))
    # FileMode.Append di .NET scrive all'offset letto all'apertura: due scrittori simultanei si sovrascrivono. Un lock breve su <giorno>.jsonl.lock
    # serializza gli append; se non si ottiene entro ~2 s si accoda comunque (l'hook resta fail-open e non blocca il turno).
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

# Turni registrati per un repository dopo l'istante indicato (tutte le postazioni). Righe illeggibili ignorate.
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

# Hook Stop di Claude Code: voce in settings.json che esegue trace.ps1 a fine turno. Riconosciuta dal percorso dello script; le voci altrui non si toccano.
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

Export-ModuleMember -Function @('Get-SBTraceRoot','Resolve-SBTraceRepository','Add-SBTraceEvent','Get-SBTraceTurns','Get-SBTraceHookCommand','Get-SBTraceSettingsPath','Get-SBTraceHookState','Set-SBTraceHook')
