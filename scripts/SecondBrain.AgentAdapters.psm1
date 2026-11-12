#requires -Version 7.5
# Agent CLI adapters for the task runner and the desktop orchestrator: Claude Code (claude -p), Codex (codex exec) and Gemini CLI (gemini).
# Capabilities come from the installed CLI (--version, --help), its local configuration and, last, the fallback table config/agent-models.json.
# Every model and effort level carries its source (probe, config, fallback). Only flags present in the installed --help are passed.
# The probe runs --version and --help with a timeout and reads configuration files. Invoke-SBAgentProcess starts one agent process and
# writes only the output log its caller names; selection, prompts and tracker writes stay with the callers.
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Host.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Add-SBMessages @{
    'agents.provider.unknown' = @{it='Provider sconosciuto: {0}. Valori ammessi: {1}';en='Unknown provider: {0}. Allowed values: {1}'}
    'agents.model.unsupported' = @{it='{0} installato non accetta la scelta del modello (manca {1} in --help). Ometti -Model o aggiorna la CLI';en='The installed {0} does not accept a model choice ({1} is missing from --help). Omit -Model or update the CLI'}
    'agents.model.unknown' = @{it='Modello {0} non tra quelli noti per {1} ({2}). Scegline uno con scripts/agents.ps1 -Probe -Provider {3} oppure aggiungi -AllowCustomModel';en='Model {0} is not among the known models for {1} ({2}). Pick one with scripts/agents.ps1 -Probe -Provider {3} or add -AllowCustomModel'}
    'agents.effort.unsupported' = @{it='{0} non espone un livello di impegno da riga di comando. Ometti -Effort';en='{0} exposes no effort level on the command line. Omit -Effort'}
    'agents.effort.unknown' = @{it='Impegno {0} non supportato da {1} per il modello {2}. Valori ammessi: {3}';en='Effort {0} is not supported by {1} for model {2}. Allowed values: {3}'}
    'agents.table.invalid' = @{it='Tabella dei modelli non valida: {0}. Correggi il JSON (schemaVersion 1, providers.<id>.models/efforts)';en='Invalid model table: {0}. Fix the JSON (schemaVersion 1, providers.<id>.models/efforts)'}
}
# Fixed permission profile for unattended runs: file edits inside the checkout, no git history changes, no deletion.
$script:SBClaudeAllowed='Bash,Read,Edit,Write,Grep,Glob,Skill'
$script:SBClaudeDenied=@('Bash(git commit:*)','Bash(git push:*)','Bash(git tag:*)','Bash(git reset:*)','Bash(git clean:*)','Bash(rm:*)','Bash(Remove-Item:*)')
# Read-only profile of one-shot analyses: file reads and searches only, no shell, no edits, no network.
$script:SBClaudeReadOnlyTools='Read,Grep,Glob'
$script:SBClaudeReadOnlyDenied=@('Bash','Edit','Write','NotebookEdit','WebFetch','WebSearch')
$script:SBAgentProviders=[ordered]@{
    claude=@{id='claude';name='Claude Code';command='claude';modelFlag='--model';effortFlag='--effort'}
    codex=@{id='codex';name='Codex';command='codex';modelFlag='--model';effortFlag='--config'}
    gemini=@{id='gemini';name='Gemini CLI';command='gemini';modelFlag='--model';effortFlag=''}
}
function Get-SBAgentProviderIds { ,@($script:SBAgentProviders.Keys) }
function Get-SBAgentProvider([string]$Provider) {
    if(!$script:SBAgentProviders.Contains($Provider)){throw (New-SBError 'agents.provider.unknown' @($Provider,(@($script:SBAgentProviders.Keys) -join ', ')))}
    $script:SBAgentProviders[$Provider].Clone()
}
function Get-SBAgentProviderForPath([string]$AgentPath) {
    # Provider from the executable name only (claude, codex, gemini); anything else is a custom agent.
    if(!$AgentPath){return $null}
    $leaf=[IO.Path]::GetFileNameWithoutExtension($AgentPath).ToLowerInvariant()
    if($script:SBAgentProviders.Contains($leaf)){$leaf}else{$null}
}
function Get-SBAgentSearchDirectories {
    # Folders where agent CLIs live but that the inherited PATH can miss: PATH re-read from the registry (a CLI installed after the
    # session started), package-manager shims and per-user installs. Existing folders only (all of them with -IncludeMissing), no duplicates.
    # SECONDBRAIN_AGENT_SEARCH_PATH adds folders first (path-separator list); with SECONDBRAIN_AGENT_SEARCH_ONLY=1 they are the only ones
    # (isolated end-to-end tests with fake CLIs). -Platform and -ProfileRoot make the list testable.
    param([ValidateSet('','windows','unix')][string]$Platform='',[string]$ProfileRoot,[switch]$IncludeMissing)
    $windows=if($Platform){$Platform -eq 'windows'}else{[bool]$IsWindows}
    if(!$ProfileRoot){$ProfileRoot=if($env:USERPROFILE){[string]$env:USERPROFILE}else{[string]$env:HOME}}
    $dirs=[Collections.Generic.List[string]]::new()
    $candidates=[Collections.Generic.List[string]]::new()
    foreach($d in ([string]$env:SECONDBRAIN_AGENT_SEARCH_PATH -split [regex]::Escape([string][IO.Path]::PathSeparator))){if($d.Trim()){$candidates.Add($d.Trim())}}
    if($env:SECONDBRAIN_AGENT_SEARCH_ONLY){
        foreach($d in $candidates){if($IncludeMissing -or (Test-Path -LiteralPath $d -PathType Container)){$dirs.Add($d)}}
        return $dirs.ToArray()
    }
    if($windows){
        if(!$Platform -or $IsWindows){foreach($scope in @('User','Machine')){foreach($d in ([string][Environment]::GetEnvironmentVariable('Path',$scope) -split ';')){if($d.Trim()){$candidates.Add([Environment]::ExpandEnvironmentVariables($d.Trim()))}}}}
        $local=if($env:LOCALAPPDATA){[string]$env:LOCALAPPDATA}else{Join-Path $ProfileRoot 'AppData\Local'}
        $roaming=if($env:APPDATA){[string]$env:APPDATA}else{Join-Path $ProfileRoot 'AppData\Roaming'}
        foreach($d in @((Join-Path $local 'Microsoft\WinGet\Links'),(Join-Path $local 'Microsoft\WindowsApps'),(Join-Path $roaming 'npm'),(Join-Path $local 'pnpm'),
            (Join-Path $local 'Volta\bin'),(Join-Path $ProfileRoot 'scoop\shims'),(Join-Path $ProfileRoot '.local\bin'),(Join-Path $ProfileRoot '.bun\bin'),
            $(if($env:ProgramFiles){Join-Path $env:ProgramFiles 'nodejs'}))){if($d){$candidates.Add($d)}}
    }else{
        $unixHome=$ProfileRoot.TrimEnd('/','\')
        if($env:NPM_CONFIG_PREFIX){$candidates.Add($env:NPM_CONFIG_PREFIX.TrimEnd('/')+'/bin')}
        foreach($d in @('/opt/homebrew/bin','/usr/local/bin','/usr/bin',($unixHome+'/.local/bin'),($unixHome+'/.npm-global/bin'),
            ($unixHome+'/.bun/bin'),($unixHome+'/.volta/bin'),($unixHome+'/.local/share/pnpm'),'/snap/bin',
            ($unixHome+'/.local/share/fnm/aliases/default/bin'),($unixHome+'/Library/Application Support/fnm/aliases/default/bin'))){$candidates.Add($d)}
        # nvm: the newest installed Node version.
        $nvm=$unixHome+'/.nvm/versions/node'
        if(Test-Path -LiteralPath $nvm -PathType Container){
            $newest=@(Get-ChildItem -LiteralPath $nvm -Directory -ErrorAction SilentlyContinue|Sort-Object {try{[version]($_.Name.TrimStart('v'))}catch{[version]'0.0'}} -Descending|Select-Object -First 1)
            if($newest.Count){$candidates.Add((Join-Path $newest[0].FullName 'bin'))}
        }
    }
    foreach($d in $candidates){
        $key=$d.TrimEnd('\','/')
        if(!$key -or @($dirs|Where-Object {[string]::Equals($_,$key,[StringComparison]::OrdinalIgnoreCase)}).Count){continue}
        if($IncludeMissing -or (Test-Path -LiteralPath $key -PathType Container)){$dirs.Add($key)}
    }
    $dirs.ToArray()
}
function Find-SBAgentInDirectories([string]$Command,[string[]]$Directories) {
    # First executable named after the command: .exe/.cmd/.bat/.ps1 on Windows, the bare name elsewhere.
    $names=if($IsWindows){@("$Command.exe","$Command.cmd","$Command.bat","$Command.ps1")}else{@($Command)}
    foreach($d in @($Directories)){foreach($n in $names){$p=Join-Path $d $n;if(Test-Path -LiteralPath $p -PathType Leaf){return $p}}}
    $null
}
function Get-SBAgentPackageExecutable([string]$Command) {
    # CLIs shipped inside a Microsoft Store package: the Codex desktop app bundles codex.exe in app\resources, outside PATH.
    if(!$IsWindows -or $Command -ne 'codex' -or $env:SECONDBRAIN_AGENT_NO_PACKAGES -or $env:SECONDBRAIN_AGENT_SEARCH_ONLY){return $null}
    try{$packages=@(Get-AppxPackage -Name 'OpenAI.Codex' -ErrorAction Stop)}catch{return $null}
    foreach($p in @($packages|Sort-Object {[version]$_.Version} -Descending)){
        if(!$p.InstallLocation){continue}
        $candidate=Join-Path $p.InstallLocation 'app\resources\codex.exe'
        if(Test-Path -LiteralPath $candidate -PathType Leaf){return $candidate}
    }
    $null
}
function Get-SBAgentProcessPath([string]$AgentDirectory) {
    # PATH for an agent process: the agent folder, the inherited PATH, then the search folders (a .cmd shim found outside PATH still needs node).
    $parts=[Collections.Generic.List[string]]::new()
    foreach($d in @(@($AgentDirectory)+@([string]$env:PATH -split [regex]::Escape([string][IO.Path]::PathSeparator))+@(Get-SBAgentSearchDirectories))){
        if($d -and !@($parts|Where-Object {[string]::Equals($_.TrimEnd('\','/'),$d.TrimEnd('\','/'),[StringComparison]::OrdinalIgnoreCase)}).Count){$parts.Add($d)}
    }
    $parts -join [IO.Path]::PathSeparator
}
function Resolve-SBAgentExecutable([string]$Command) {
    # Prefer a real executable or a .cmd shim; a .ps1 shim (npm) cannot be started directly, so it is wrapped in pwsh -File.
    # A bare command missing from PATH is looked up in the search folders, then (codex on Windows) in its Store package.
    # origin: path (inherited PATH or an explicit path), search (a search folder), package (Store package).
    if(!$Command){return $null}
    $origin='path'
    $found=@(Get-Command $Command -All -ErrorAction SilentlyContinue)
    if(!$found.Count -and $Command -notmatch '[\\/]'){
        $candidate=Find-SBAgentInDirectories $Command (Get-SBAgentSearchDirectories)
        if($candidate){$found=@(Get-Command $candidate -ErrorAction SilentlyContinue);$origin='search'}
        else{
            $package=Get-SBAgentPackageExecutable $Command
            if($package){return @{path=$package;prefix=@();origin='package'}}
        }
    }
    if(!$found.Count){return $null}
    # Windows starts only .exe/.cmd/.bat (an extensionless npm shim is a sh script); elsewhere a file without extension is the executable.
    $pattern=if($IsWindows){'\.(exe|cmd|bat)$'}else{'\.(exe|cmd|bat)$|/[^/.]+$'}
    $app=@($found|Where-Object {$_.CommandType -eq 'Application' -and $_.Source -match $pattern}|Sort-Object @{e={if($_.Source -like '*.exe'){0}else{1}}})|Select-Object -First 1
    if($app){return @{path=$app.Source;prefix=@();origin=$origin}}
    $source=$found[0].Source
    if($source -like '*.ps1'){return @{path=(Get-Process -Id $PID).Path;prefix=@('-NoProfile','-File',$source);script=$source;origin=$origin}}
    @{path=$source;prefix=@();origin=$origin}
}
function Invoke-SBAgentProbeCommand($Executable,[string[]]$Arguments,[int]$TimeoutSeconds=20) {
    # Runs one read-only probe (--version, --help) and returns stdout+stderr, or $null on timeout or start failure.
    try{
        $start=[Diagnostics.ProcessStartInfo]::new($Executable.path);$start.UseShellExecute=$false;$start.CreateNoWindow=$true
        $start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true;$start.RedirectStandardInput=$true
        $start.StandardOutputEncoding=[Text.UTF8Encoding]::new($false);$start.StandardErrorEncoding=[Text.UTF8Encoding]::new($false)
        foreach($a in (@($Executable.prefix)+$Arguments)){$start.ArgumentList.Add([string]$a)}
        $start.Environment['PATH']=Get-SBAgentProcessPath (Split-Path -Parent ([string]$Executable.path))
        $process=[Diagnostics.Process]::Start($start)
        try{
            $process.StandardInput.Close()
            $out=$process.StandardOutput.ReadToEndAsync();$err=$process.StandardError.ReadToEndAsync()
            if(!$process.WaitForExit($TimeoutSeconds*1000)){$process.Kill($true);return $null}
            $out.GetAwaiter().GetResult()+"`n"+$err.GetAwaiter().GetResult()
        }finally{$process.Dispose()}
    }catch{$null}
}
function Get-SBAgentVersion([string]$Text) {
    if(!$Text){return $null}
    $m=[regex]::Match($Text,'\d+\.\d+(?:\.\d+)?(?:[-+][0-9A-Za-z.-]+)?')
    if($m.Success){$m.Value}else{$null}
}
function Get-SBAgentHelpFlags([string]$HelpText) {
    # Long options and the short -m/-c/-p aliases advertised by --help.
    if(!$HelpText){return ,@()}
    $long=@([regex]::Matches($HelpText,'(?<![\w-])--[a-zA-Z][\w-]*')|ForEach-Object {$_.Value})
    $short=@([regex]::Matches($HelpText,'(?m)^\s*(-[a-zA-Z])[,\s]')|ForEach-Object {$_.Groups[1].Value})
    ,@(@($long+$short)|Sort-Object -Unique)
}
function Get-SBAgentHelpBlock([string]$HelpText,[string]$Flag) {
    # Description of one option: from the flag to the next option line.
    if(!$HelpText){return ''}
    $m=[regex]::Match($HelpText,'(?ms)^[ \t]*(?:-\w,\s*)?'+[regex]::Escape($Flag)+'\b(?<body>.*?)(?=^[ \t]*-{1,2}\w|\z)')
    if($m.Success){$m.Groups['body'].Value}else{''}
}
function ConvertFrom-SBAgentHelp([string]$Provider,[string]$HelpText) {
    # Models and efforts that the help text names explicitly (Claude Code lists effort choices and model aliases).
    $result=@{flags=(Get-SBAgentHelpFlags $HelpText);models=@();efforts=@()}
    if($Provider -eq 'claude'){
        $effort=Get-SBAgentHelpBlock $HelpText '--effort'
        $list=[regex]::Match($effort,'\(([a-z]+(?:\s*,\s*[a-z]+)+)\)')
        if($list.Success){$result.efforts=@($list.Groups[1].Value -split '\s*,\s*'|Where-Object {$_})}
        $model=Get-SBAgentHelpBlock $HelpText '--model'
        $result.models=@([regex]::Matches($model,"'([a-z][a-z0-9.-]*)'")|ForEach-Object {$_.Groups[1].Value}|Select-Object -Unique)
    }
    $result
}
function Read-SBAgentJsonFile([string]$Path) {
    if(!$Path -or !(Test-Path -LiteralPath $Path -PathType Leaf)){return $null}
    try{Read-SBText $Path|ConvertFrom-Json -AsHashtable}catch{$null}
}
function Read-SBTomlTopString([string]$Text,[string]$Key) {
    # Top-level `key = "value"` before the first table header; enough for model and model_reasoning_effort.
    if(!$Text){return $null}
    $head=[regex]::Split($Text,'(?m)^\s*\[')[0]
    $m=[regex]::Match($head,'(?m)^[ \t]*'+[regex]::Escape($Key)+'[ \t]*=[ \t]*["''](?<v>[^"''\r\n]*)["'']')
    if($m.Success){$m.Groups['v'].Value}else{$null}
}
function Get-SBAgentConfigRoot([string]$Variable,[string]$Default) {
    # Same precedence as the IDE detection: user environment, then process environment, then the default folder.
    $value=[Environment]::GetEnvironmentVariable($Variable,'User')
    if(!$value){$value=[Environment]::GetEnvironmentVariable($Variable,'Process')}
    if($value){$value}else{$Default}
}
function Get-SBAgentConfigPaths([string]$Provider) {
    $profileRoot=if($env:USERPROFILE){[string]$env:USERPROFILE}else{[string]$env:HOME}
    switch($Provider){
        'claude' {$root=Get-SBAgentConfigRoot 'CLAUDE_CONFIG_DIR' (Join-Path $profileRoot '.claude');@{settings=(Join-Path $root 'settings.json')}}
        'codex' {$root=Get-SBAgentConfigRoot 'CODEX_HOME' (Join-Path $profileRoot '.codex');@{config=(Join-Path $root 'config.toml');models=(Join-Path $root 'models_cache.json')}}
        'gemini' {@{settings=(Join-Path (Join-Path $profileRoot '.gemini') 'settings.json')}}
    }
}
function Read-SBCodexModelsCache([string]$Path) {
    # Codex keeps the model list it fetched (slug, supported_reasoning_levels, visibility); hidden models are left out.
    $data=Read-SBAgentJsonFile $Path
    if(!$data -or !$data.ContainsKey('models')){return ,@()}
    $models=@()
    foreach($m in @($data.models)){
        if($m -isnot [hashtable] -or !$m.ContainsKey('slug')){continue}
        if($m.ContainsKey('visibility') -and [string]$m.visibility -eq 'hide'){continue}
        $levels=@();if($m.ContainsKey('supported_reasoning_levels')){$levels=@($m.supported_reasoning_levels|ForEach-Object {if($_ -is [hashtable]){[string]$_.effort}else{[string]$_}}|Where-Object {$_})}
        $models+=,@{id=[string]$m.slug;label=$(if($m.ContainsKey('display_name')){[string]$m.display_name}else{[string]$m.slug});source='config';efforts=$levels;defaultEffort=$(if($m.ContainsKey('default_reasoning_level')){[string]$m.default_reasoning_level}else{$null})}
    }
    ,$models
}
function Read-SBAgentConfigured([string]$Provider,$Paths) {
    # The model and effort the user configured for the CLI (used when the queue leaves them empty).
    $configured=@{model=$null;effort=$null}
    switch($Provider){
        'claude' {$s=Read-SBAgentJsonFile $Paths.settings;if($s){if($s.ContainsKey('model')){$configured.model=[string]$s.model};if($s.ContainsKey('effortLevel')){$configured.effort=[string]$s.effortLevel}}}
        'codex' {
            if(Test-Path -LiteralPath $Paths.config -PathType Leaf){$t=[IO.File]::ReadAllText($Paths.config);$configured.model=Read-SBTomlTopString $t 'model';$configured.effort=Read-SBTomlTopString $t 'model_reasoning_effort'}
        }
        'gemini' {$s=Read-SBAgentJsonFile $Paths.settings;if($s -and $s.ContainsKey('model')){if($s.model -is [hashtable]){if($s.model.ContainsKey('name')){$configured.model=[string]$s.model.name}}else{$configured.model=[string]$s.model}}}
    }
    $configured
}
function Read-SBAgentModelTable([string]$BrainRoot) {
    # Fallback table plus the workstation override (.runtime/hosts/<host>/agent-models.local.json), entries appended per provider.
    $table=@{}
    foreach($path in @((Join-Path $BrainRoot 'config/agent-models.json'),(Join-Path $BrainRoot ('.runtime/hosts/'+(Get-SBHostId)+'/agent-models.local.json')))){
        if(!(Test-Path -LiteralPath $path -PathType Leaf)){continue}
        try{$data=Read-SBText $path|ConvertFrom-Json -AsHashtable}catch{throw (New-SBError 'agents.table.invalid' @($path))}
        if($data -isnot [hashtable] -or $data.schemaVersion -ne 1 -or $data.providers -isnot [hashtable]){throw (New-SBError 'agents.table.invalid' @($path))}
        foreach($p in $data.providers.Keys){
            if(!$table.ContainsKey($p)){$table[$p]=@{models=@();efforts=@()}}
            $entry=$data.providers[$p]
            foreach($m in @($entry['models'])){if($m -is [hashtable] -and $m.ContainsKey('id')){$table[$p].models+=,@{id=[string]$m.id;label=$(if($m.ContainsKey('label')){[string]$m.label}else{[string]$m.id});efforts=@($(if($m.ContainsKey('efforts')){$m.efforts}else{@()}))}}}
            foreach($e in @($entry['efforts'])){if($e){$table[$p].efforts+=[string]$e}}
        }
    }
    $table
}
function Merge-SBAgentModels($Lists) {
    # First occurrence wins: probe before config before fallback.
    $seen=@{};$merged=@()
    foreach($list in $Lists){foreach($m in @($list)){if($m -and !$seen.ContainsKey($m.id)){$seen[$m.id]=$true;$merged+=,$m}}}
    ,$merged
}
function Get-SBAgentCapabilities {
    # Capabilities of one installed agent. -HelpText/-VersionText/-ConfigPaths/-Executable make the probe testable without a real CLI.
    param([Parameter(Mandatory)][string]$Provider,[string]$BrainRoot,[string]$AgentPath,$Executable,[AllowNull()][string]$HelpText,[AllowNull()][string]$VersionText,$ConfigPaths,[switch]$NoProbe)
    $info=Get-SBAgentProvider $Provider
    if(!$BrainRoot){$BrainRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))}
    if(!$Executable -and !$NoProbe){$Executable=Resolve-SBAgentExecutable $(if($AgentPath){$AgentPath}else{$info.command})}
    if($Executable -and !$NoProbe){
        if(!$PSBoundParameters.ContainsKey('VersionText')){$VersionText=Invoke-SBAgentProbeCommand $Executable @('--version')}
        if(!$PSBoundParameters.ContainsKey('HelpText')){$HelpText=Invoke-SBAgentProbeCommand $Executable $(if($Provider -eq 'codex'){@('exec','--help')}else{@('--help')})}
    }
    $paths=if($ConfigPaths){$ConfigPaths}else{Get-SBAgentConfigPaths $Provider}
    $parsed=ConvertFrom-SBAgentHelp $Provider $HelpText
    $table=Read-SBAgentModelTable $BrainRoot
    $fallback=if($table.ContainsKey($Provider)){$table[$Provider]}else{@{models=@();efforts=@()}}
    $configured=Read-SBAgentConfigured $Provider $paths
    $probeModels=@($parsed.models|ForEach-Object {@{id=$_;label=$_;source='probe';efforts=@();defaultEffort=$null}})
    $configModels=@()
    if($Provider -eq 'codex'){foreach($m in (Read-SBCodexModelsCache $paths.models)){$configModels+=,$m}}
    if($configured.model -and !@($configModels|Where-Object {$_.id -eq $configured.model}).Count){$configModels+=,@{id=$configured.model;label=$configured.model;source='config';efforts=@();defaultEffort=$configured.effort}}
    $fallbackModels=@($fallback.models|ForEach-Object {@{id=$_.id;label=$_.label;source='fallback';efforts=@($_.efforts);defaultEffort=$null}})
    # Only what the installed CLI exposes (probe, its configuration) is offered; the fallback table validates a typed model but is not listed.
    $installed=[bool]$Executable
    $models=if($installed){Merge-SBAgentModels @($probeModels,$configModels)}else{,@()}
    $flags=@($parsed.flags)
    $known=@($flags).Count -gt 0
    $responding=if(!$installed){$false}elseif($NoProbe){$null}else{[bool]($VersionText -or $HelpText)}
    $status=if(!$installed){'not-found'}elseif($responding -eq $false){'not-responding'}else{'ready'}
    $supportsModel=if($known){$info.modelFlag -in $flags -or '-m' -in $flags}else{$false}
    $supportsEffort=if(!$info.effortFlag){$false}elseif($known){$info.effortFlag -in $flags -or ($Provider -eq 'codex' -and '-c' -in $flags)}else{$false}
    # Streaming output (stream-json) when the installed --help names it: the runner then shows the agent's steps while it works.
    $streamJson=[bool]($HelpText -and $HelpText -match 'stream-json')
    $efforts=@()
    if($installed -and ($supportsEffort -or !$known)){
        if(@($parsed.efforts).Count){$efforts=@($parsed.efforts|ForEach-Object {@{id=$_;source='probe'}})}
        else{
            $fromModels=@($models|ForEach-Object {@($_.efforts)}|Where-Object {$_}|Select-Object -Unique)
            if($fromModels.Count){$efforts=@($fromModels|ForEach-Object {@{id=$_;source='config'}})}
            elseif(@($fallback.efforts).Count -and $info.effortFlag){$efforts=@($fallback.efforts|Select-Object -Unique|ForEach-Object {@{id=$_;source='fallback'}})}
        }
    }
    [ordered]@{
        provider=$Provider;name=$info.name;command=$info.command
        installed=$installed;status=$status;origin=$(if($Executable -and $Executable.ContainsKey('origin')){$Executable.origin}else{$null})
        path=$(if($Executable){$(if($Executable.ContainsKey('script')){$Executable.script}else{$Executable.path})}else{$null})
        version=(Get-SBAgentVersion $VersionText);helpRead=$known
        flags=$flags;supports=[ordered]@{model=$supportsModel;effort=$supportsEffort;streamJson=$streamJson}
        configured=$configured;models=@($models);efforts=@($efforts);fallbackModels=@($fallbackModels|ForEach-Object {$_.id})
    }
}
function Get-SBAgentCapabilitiesAll {
    # Every provider probed in parallel (each probe waits on two CLI processes): the slowest CLI sets the time, not the sum.
    param([string[]]$Provider,[string]$BrainRoot)
    $ids=@(if($Provider){$Provider}else{@(Get-SBAgentProviderIds)|ForEach-Object {$_}})
    if(!$BrainRoot){$BrainRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))}
    if($ids.Count -le 1){return @($ids|ForEach-Object {Get-SBAgentCapabilities -Provider $_ -BrainRoot $BrainRoot})}
    $module=Join-Path $PSScriptRoot 'SecondBrain.AgentAdapters.psm1'
    $results=@($ids|ForEach-Object -ThrottleLimit 4 -Parallel {
        Import-Module $using:module
        Get-SBAgentCapabilities -Provider $_ -BrainRoot $using:BrainRoot
    })
    # Parallel output order follows completion: restore the provider order.
    $ids|ForEach-Object {$id=$_;@($results|Where-Object {$_.provider -eq $id})[0]}
}
function Test-SBAgentSelection($Capabilities,[string]$Model,[string]$Effort,[switch]$AllowCustomModel) {
    # Validates the queue choice against the probe; errors name the next step.
    $c=$Capabilities;$name=$c.name
    if($Model){
        if(!$c.supports.model){throw (New-SBError 'agents.model.unsupported' @($name,(Get-SBAgentProvider $c.provider).modelFlag))}
        $ids=@($c.models|ForEach-Object {$_.id})
        $reserve=@($(if($c.Contains('fallbackModels')){$c.fallbackModels}))
        if($Model -notin $ids -and $Model -notin $reserve -and !$AllowCustomModel){throw (New-SBError 'agents.model.unknown' @($Model,$name,($ids -join ', '),$c.provider))}
    }
    if($Effort){
        if(!$c.supports.effort){throw (New-SBError 'agents.effort.unsupported' @($name))}
        $target=$(if($Model){$Model}else{$c.configured.model})
        $hit=@($c.models|Where-Object {$_.id -eq $target -and @($_.efforts).Count})
        $allowed=@($(if($hit.Count){$hit[0].efforts}else{$c.efforts|ForEach-Object {$_.id}}))
        if($allowed.Count -and $Effort -notin $allowed){throw (New-SBError 'agents.effort.unknown' @($Effort,$name,$(if($target){$target}else{'-'}),($allowed -join ', ')))}
    }
    $true
}
function Add-SBAgentFlag($State,[string]$Flag,[string[]]$Values,[string]$Alias) {
    # Unprobed help (no flags known) passes every flag; a probed help passes only the flags it lists.
    $flags=@($State.flags)
    if($flags.Count -eq 0 -or $Flag -in $flags -or ($Alias -and $Alias -in $flags)){$State.list.Add($Flag);foreach($v in @($Values)){$State.list.Add($v)}}else{$State.omitted.Add($Flag)}
}
function Test-SBAgentFlagAvailable($Capabilities,[string]$Flag,[string]$Alias) {
    # A flag is used only when the probed --help lists it (an unprobed help passes nothing optional).
    $flags=@($(if($Capabilities){$Capabilities.flags}))
    [bool]($flags.Count -and ($Flag -in $flags -or ($Alias -and $Alias -in $flags)))
}
function New-SBAgentInvocation {
    # Headless arguments per provider with the fixed permission profile; the prompt always goes on stdin.
    # With a probed --help, flags it does not list are left out and reported in omitted.
    # -Profile ReadOnly (one-shot analyses): no edits, no shell, plan/read-only modes; a JSON schema goes to the CLI natively
    # when the installed --help offers it (claude --json-schema, codex --output-schema), and nativeSchema says whether it did.
    param([Parameter(Mandatory)][string]$Provider,$Capabilities,[string]$Model,[string]$Effort,[ValidateSet('Edit','ReadOnly')][string]$Profile='Edit',
        [string]$SchemaPath,[switch]$NoInlineSchema)
    $state=@{flags=@($(if($Capabilities){$Capabilities.flags}));list=[Collections.Generic.List[string]]::new();omitted=[Collections.Generic.List[string]]::new()}
    $list=$state.list
    function Add-Flag([string]$Flag,[string[]]$Values=@(),[string]$Alias){Add-SBAgentFlag $state $Flag $Values $Alias}
    if($Profile -eq 'ReadOnly'){
        $native=$false
        switch($Provider){
            'claude' {
                $list.Add('-p')
                Add-Flag '--output-format' @('json')
                Add-Flag '--permission-mode' @('plan')
                Add-Flag '--allowedTools' @($script:SBClaudeReadOnlyTools)
                Add-Flag '--disallowedTools' $script:SBClaudeReadOnlyDenied
                # The schema travels as one JSON argument: only to a real executable, never through a .cmd shim that re-parses quotes.
                if($SchemaPath -and !$NoInlineSchema -and (Test-SBAgentFlagAvailable $Capabilities '--json-schema')){
                    # The CLI validator does not load the draft 2020-12 meta-schema: drop the $schema declaration (the
                    # analysis schemas use no 2020-12-only keyword; local validation still reads the whole file).
                    $inline=(Read-SBText $SchemaPath)|ConvertFrom-Json -AsHashtable;[void]$inline.Remove('$schema')
                    $list.Add('--json-schema');$list.Add(($inline|ConvertTo-Json -Depth 40 -Compress));$native=$true
                }
                if($Model){Add-Flag '--model' @($Model)}
                if($Effort){Add-Flag '--effort' @($Effort)}
            }
            'codex' {
                $list.Add('exec')
                Add-Flag '--json'
                Add-Flag '--sandbox' @('read-only') '-s'
                Add-Flag '--skip-git-repo-check'
                if($SchemaPath -and (Test-SBAgentFlagAvailable $Capabilities '--output-schema')){$list.Add('--output-schema');$list.Add($SchemaPath);$native=$true}
                if($Model){Add-Flag '--model' @($Model) '-m'}
                if($Effort){Add-Flag '--config' @('model_reasoning_effort="'+$Effort+'"') '-c'}
                $list.Add('-')
            }
            'gemini' {
                Add-Flag '--output-format' @('json') '-o'
                Add-Flag '--approval-mode' @('plan')
                if($Model){Add-Flag '--model' @($Model) '-m'}
            }
            default {throw (New-SBError 'agents.provider.unknown' @($Provider,(@($script:SBAgentProviders.Keys) -join ', ')))}
        }
        return @{arguments=@($state.list);omitted=@($state.omitted);nativeSchema=$native;profile='ReadOnly'}
    }
    # Codex --json already streams JSONL events; Claude Code and Gemini CLI stream with stream-json when the probe found it.
    $stream=[bool]($Capabilities -and $Capabilities.supports -and $Capabilities.supports.Contains('streamJson') -and $Capabilities.supports.streamJson)
    switch($Provider){
        'claude' {
            $list.Add('-p')
            if($stream){Add-Flag '--output-format' @('stream-json');Add-Flag '--verbose'}else{Add-Flag '--output-format' @('json')}
            Add-Flag '--permission-mode' @('acceptEdits')
            Add-Flag '--allowedTools' @($script:SBClaudeAllowed)
            Add-Flag '--disallowedTools' $script:SBClaudeDenied
            if($Model){Add-Flag '--model' @($Model)}
            if($Effort){Add-Flag '--effort' @($Effort)}
        }
        'codex' {
            $list.Add('exec')
            Add-Flag '--json'
            Add-Flag '--sandbox' @('workspace-write') '-s'
            Add-Flag '--skip-git-repo-check'
            if($Model){Add-Flag '--model' @($Model) '-m'}
            if($Effort){Add-Flag '--config' @('model_reasoning_effort="'+$Effort+'"') '-c'}
            $list.Add('-')
        }
        'gemini' {
            Add-Flag '--output-format' @($(if($stream){'stream-json'}else{'json'})) '-o'
            Add-Flag '--approval-mode' @('auto_edit')
            if($Model){Add-Flag '--model' @($Model) '-m'}
        }
        default {throw (New-SBError 'agents.provider.unknown' @($Provider,(@($script:SBAgentProviders.Keys) -join ', ')))}
    }
    @{arguments=@($state.list);omitted=@($state.omitted)}
}
function Get-SBAgentLimitPatterns([string]$Provider) {
    # Per-provider texts of a plan limit (quota: the run stops) and of transient throttling (throttled: the run goes on).
    # Applied only to the final error envelope of the agent (Get-SBAgentErrorText), never to the agent's own text or to tool output.
    # Claude Code strings come from the installed 2.1 binary ("You've hit your limit", "You've reached your ...", "You're out of usage credits");
    # Codex from its usage_limit_reached error; Gemini from the RESOURCE_EXHAUSTED envelope, daily quota only.
    switch($Provider){
        'codex' {@{quota="usage_limit_reached|You['’]ve hit your usage limit|usage limit reached";throttle='rate_limit_exceeded|\b429\b|Too Many Requests'}}
        'gemini' {@{quota='exhausted your (?:daily )?quota|Quota exceeded for quota metric[^\r\n]*(?:per ?day|daily)|RESOURCE_EXHAUSTED[^\r\n]*(?:per ?day|daily)';throttle='RESOURCE_EXHAUSTED|\b429\b|Too Many Requests|per ?minute'}}
        default {@{quota="You['’]ve hit your (?:[\w'-]+ )*limit|You['’]ve reached your (?:[\w'-]+ )*limit|You['’]re out of (?:extra )?usage|usage limit reached|usage_limit_reached|out of extra usage|weekly limit reached";throttle='rate_limit_error|overloaded_error|\b429\b|\b529\b'}}
    }
}
function ConvertFrom-SBAgentRateLimitEvent([string]$Line) {
    # Claude Code stream-json rate_limit_event (rate_limit_info.status allowed|allowed_warning|rejected, resetsAt epoch seconds, rateLimitType).
    if(!$Line -or $Line -notmatch 'rate_limit_event'){return $null}
    try{$o=$Line|ConvertFrom-Json -AsHashtable -Depth 32 -ErrorAction Stop}catch{return $null}
    if($o -isnot [System.Collections.IDictionary] -or [string]$o['type'] -ne 'rate_limit_event'){return $null}
    $info=if($o.Contains('rate_limit_info') -and $o.rate_limit_info -is [System.Collections.IDictionary]){$o.rate_limit_info}else{@{}}
    $status=[string]$info['status']
    $reset=$null;if($info.Contains('resetsAt') -and $info.resetsAt){try{$reset=[DateTimeOffset]::FromUnixTimeSeconds([long]$info.resetsAt).ToString('o')}catch{$reset=$null}}
    [ordered]@{state=$(if($status -eq 'rejected'){'exhausted'}elseif($status -like 'allowed*'){'available'}else{'unknown'});status=$status;kind=[string]$info['rateLimitType'];resetAt=$reset}
}
function Get-SBAgentErrorText {
    # The agent's error envelope only: Claude/Gemini result lines with is_error or an error status, Codex error and turn.failed events,
    # a single JSON error object, a rejected rate_limit_event; plus the tail of standard error when the process exited non-zero.
    # Assistant messages, tool output and the stderr of a timed-out or killed agent are left out, so a task that talks about quotas is not a quota stop.
    param([string]$Provider,[string]$Output,[string]$ErrorOutput,$ExitCode)
    $parts=[Collections.Generic.List[string]]::new()
    foreach($line in @([string]$Output -split "`r?`n")){
        $l=$line.Trim();if(!$l.StartsWith('{')){continue}
        try{$o=$l|ConvertFrom-Json -AsHashtable -Depth 64 -ErrorAction Stop}catch{continue}
        if($o -isnot [System.Collections.IDictionary]){continue}
        $type=[string]$o['type']
        $err=if($o.Contains('error')){$o.error}else{$null}
        $errMsg=if($err -is [System.Collections.IDictionary]){(@($err['message'],$err['status'],$err['code'],$err['type'])|Where-Object {$_}) -join ' '}elseif($err -is [string]){$err}else{''}
        switch -Regex ($type){
            '^result$' {if(($o.Contains('is_error') -and [bool]$o.is_error) -or ($o.Contains('status') -and [string]$o.status -notin @('','success'))){$parts.Add(((@([string]$o['result'],[string]$o['subtype'],$errMsg))|Where-Object {$_}) -join ' ')}}
            '^(error|turn\.failed)$' {$parts.Add($(if($errMsg){$errMsg}else{[string]$o['message']}))}
            '^rate_limit_event$' {$r=ConvertFrom-SBAgentRateLimitEvent $l;if($r -and $r.state -eq 'exhausted'){$parts.Add('usage limit reached '+$r.kind)}}
            '^$' {if($errMsg){$parts.Add($errMsg)}}
        }
    }
    if($null -ne $ExitCode -and $ExitCode -ne 0 -and $ErrorOutput){$parts.Add(((@($ErrorOutput -split "`r?`n")|Where-Object {$_.Trim()}|Select-Object -Last 20) -join "`n"))}
    ($parts|Where-Object {$_}) -join "`n"
}
function Get-SBAgentLimitState {
    # quota (plan exhausted: stop the run), throttled (transient rate limit: go on) or $null, with the matching line as message.
    param([string]$Provider,[string]$Output,[string]$ErrorOutput,$ExitCode)
    $text=Get-SBAgentErrorText -Provider $Provider -Output $Output -ErrorOutput $ErrorOutput -ExitCode $ExitCode
    if(!$text){return $null}
    $p=Get-SBAgentLimitPatterns $Provider
    foreach($kind in @('quota','throttle')){
        $m=[regex]::Match($text,$p[$kind],[Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if($m.Success){
            $line=@($text -split "`r?`n"|Where-Object {$_ -match [regex]::Escape($m.Value)}|Select-Object -First 1)[0]
            return [ordered]@{state=$(if($kind -eq 'quota'){'quota'}else{'throttled'});match=$m.Value;message=([string]$line).Trim()}
        }
    }
    $null
}
function Read-SBCodexRateLimits {
    # The last rate_limits record Codex wrote in its session files (CODEX_HOME/sessions/yyyy/MM/dd/rollout-*.jsonl, newest first):
    # primary (5 h) and secondary (weekly) windows with used_percent and resets_at. $null when no session of the last 8 days has one.
    param([string]$CodexHome,[int]$Files=6)
    if(!$CodexHome){$CodexHome=Split-Path -Parent (Get-SBAgentConfigPaths 'codex').config}
    $sessions=Join-Path $CodexHome 'sessions'
    if(!(Test-Path -LiteralPath $sessions -PathType Container)){return $null}
    $since=(Get-Date).AddDays(-8)
    $candidates=@(Get-ChildItem -LiteralPath $sessions -Recurse -File -Filter 'rollout-*.jsonl' -ErrorAction SilentlyContinue|Where-Object {$_.LastWriteTime -ge $since}|Sort-Object LastWriteTime -Descending|Select-Object -First $Files)
    foreach($f in $candidates){
        $hit=$null
        try{$hit=@(Select-String -LiteralPath $f.FullName -Pattern '"rate_limits"\s*:\s*\{' -SimpleMatch:$false -ErrorAction Stop|Select-Object -Last 1)}catch{continue}
        if(!$hit.Count){continue}
        try{$o=$hit[0].Line|ConvertFrom-Json -AsHashtable -Depth 64 -DateKind String -ErrorAction Stop}catch{continue}
        $limits=$null
        foreach($node in @($o,$o['payload'],$(if($o['payload'] -is [System.Collections.IDictionary]){$o.payload['info']}))){if($node -is [System.Collections.IDictionary] -and $node.Contains('rate_limits')){$limits=$node.rate_limits;break}}
        if($limits -isnot [System.Collections.IDictionary]){continue}
        $windows=@()
        foreach($name in @('primary','secondary')){
            $w=$limits[$name];if($w -isnot [System.Collections.IDictionary]){continue}
            $reset=$null;if($w['resets_at']){try{$reset=[DateTimeOffset]::FromUnixTimeSeconds([long]$w.resets_at)}catch{$reset=$null}}
            $windows+=,[ordered]@{name=$name;usedPercent=[double]$w['used_percent'];windowMinutes=$w['window_minutes'];resetAt=$(if($reset){$reset.ToString('o')}else{$null})}
        }
        $observed=if($o['timestamp']){[string]$o.timestamp}else{([DateTimeOffset]$f.LastWriteTimeUtc).ToString('o')}
        return [ordered]@{observedAt=$observed;file=$f.FullName;windows=$windows}
    }
    $null
}
function ConvertTo-SBQuotaTime($Value) {
    # Stored times are ISO strings; a DateTime from an older JSON read is accepted too.
    if($Value -is [DateTimeOffset]){$Value}elseif($Value -is [datetime]){[DateTimeOffset]$Value}else{[DateTimeOffset]::Parse([string]$Value,[Globalization.CultureInfo]::InvariantCulture)}
}
function Get-SBAgentQuota {
    # Quota read at the moment of use (never cached): available, exhausted (with resetAt) or unknown. Unknown never stops a run:
    # the runner proceeds until the agent itself reports the limit. Sources: Codex session files; for Claude Code and Gemini CLI,
    # which offer no headless usage read, the last observation the runner recorded (-Observation: rate_limit_event or a quota stop).
    param([Parameter(Mandatory)][string]$Provider,[string]$CodexHome,$Observation,[DateTimeOffset]$Now=[DateTimeOffset]::UtcNow)
    $result=[ordered]@{provider=$Provider;state='unknown';resetAt=$null;source='none';observedAt=$null;windows=@()}
    if($Provider -eq 'codex'){
        $r=Read-SBCodexRateLimits -CodexHome $CodexHome
        if($r){
            $result.source='codex-session';$result.observedAt=$r.observedAt;$result.windows=@($r.windows)
            $current=@($r.windows|Where-Object {$_.resetAt -and (ConvertTo-SBQuotaTime $_.resetAt) -gt $Now})
            $full=@($current|Where-Object {$_.usedPercent -ge 100})
            if($full.Count){$result.state='exhausted';$result.resetAt=@($full|Sort-Object {(ConvertTo-SBQuotaTime $_.resetAt)} -Descending)[0].resetAt}
            elseif($current.Count){$result.state='available'}
        }
        return $result
    }
    if($Observation -and $Observation.observedAt){
        $result.source='runner-observation';$result.observedAt=[string]$Observation.observedAt
        $age=($Now-(ConvertTo-SBQuotaTime $Observation.observedAt)).TotalMinutes
        $reset=if($Observation.resetAt){(ConvertTo-SBQuotaTime $Observation.resetAt)}else{$null}
        if($Observation.state -eq 'exhausted' -and $reset -and $reset -gt $Now){$result.state='exhausted';$result.resetAt=$reset.ToString('o')}
        elseif($Observation.state -eq 'available' -and $age -le 60){$result.state='available';$result.resetAt=$(if($reset){$reset.ToString('o')})}
    }
    $result
}
function Invoke-SBAgentProcess {
    # One agent process: prompt on stdin, UTF-8 both ways, stdout read line by line (kept in -OutputLog as it arrives), stderr collected,
    # timeout as the only kill. Shared by the task runner and the one-shot analyses. Callbacks run in the caller's scope:
    # OnOutputLine (each stdout line), OnTick (every -TickSeconds, with the elapsed seconds), OnStall (once, after -StallMinutes of silence,
    # with the silent minutes), OnResume (first output after a stall), OnIdle (each loop pass, e.g. a heartbeat).
    # Returns state (finished, timeout), exitCode, output, error, seconds.
    param([Parameter(Mandatory)]$Executable,[string[]]$Arguments=@(),[string]$Prompt='',[string]$WorkingDirectory,[hashtable]$Environment=@{},
        [int]$TimeoutSeconds=1800,[double]$StallMinutes=0,[string]$OutputLog,[int]$TickSeconds=60,
        [scriptblock]$OnOutputLine,[scriptblock]$OnTick,[scriptblock]$OnStall,[scriptblock]$OnResume,[scriptblock]$OnIdle)
    $utf8=[Text.UTF8Encoding]::new($false)
    $start=[Diagnostics.ProcessStartInfo]::new([string]$Executable.path);$start.UseShellExecute=$false;$start.CreateNoWindow=$true
    if($WorkingDirectory){$start.WorkingDirectory=$WorkingDirectory}
    $start.RedirectStandardInput=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
    $start.StandardInputEncoding=$utf8;$start.StandardOutputEncoding=$utf8;$start.StandardErrorEncoding=$utf8
    foreach($a in (@($Executable.prefix)+@($Arguments))){if($null -ne $a){$start.ArgumentList.Add([string]$a)}}
    $start.Environment['PATH']=Get-SBAgentProcessPath (Split-Path -Parent ([string]$Executable.path))
    foreach($k in @($Environment.Keys)){$start.Environment[[string]$k]=[string]$Environment[$k]}
    $began=Get-Date
    $process=[Diagnostics.Process]::Start($start);$state='finished';$code=$null
    $outBuilder=[Text.StringBuilder]::new();$errBuilder=[Text.StringBuilder]::new()
    $outLog=if($OutputLog){[IO.StreamWriter]::new($OutputLog,$false,$utf8)}else{$null}
    try{
        $process.StandardInput.Write($Prompt);$process.StandardInput.Close()
        $outRead=$process.StandardOutput.ReadLineAsync();$errRead=$process.StandardError.ReadLineAsync()
        $outDone=$false;$errDone=$false;$lastActivity=Get-Date;$stallReported=$false;$nextTick=$TickSeconds;$exitedAt=$null
        while($true){
            $progress=$false
            while(!$outDone -and $outRead.IsCompleted){
                $line=$outRead.GetAwaiter().GetResult()
                if($null -eq $line){$outDone=$true;break}
                [void]$outBuilder.AppendLine($line)
                if($outLog){$outLog.WriteLine($line);$outLog.Flush()}
                $lastActivity=Get-Date;$progress=$true
                if($OnOutputLine){& $OnOutputLine $line}
                $outRead=$process.StandardOutput.ReadLineAsync()
            }
            while(!$errDone -and $errRead.IsCompleted){
                $line=$errRead.GetAwaiter().GetResult()
                if($null -eq $line){$errDone=$true;break}
                [void]$errBuilder.AppendLine($line);$lastActivity=Get-Date;$progress=$true
                $errRead=$process.StandardError.ReadLineAsync()
            }
            if($progress -and $stallReported){$stallReported=$false;if($OnResume){& $OnResume}}
            if($process.HasExited){
                if($outDone -and $errDone){break}
                # A grandchild that inherited the pipes can keep them open after the agent exits: stop waiting after five seconds.
                if(!$exitedAt){$exitedAt=Get-Date}elseif(((Get-Date)-$exitedAt).TotalSeconds -ge 5){break}
            }
            $elapsed=((Get-Date)-$began).TotalSeconds
            if($elapsed -ge $TimeoutSeconds){$process.Kill($true);$process.WaitForExit();$state='timeout';break}
            if($TickSeconds -gt 0 -and $elapsed -ge $nextTick){if($OnTick){& $OnTick ([int]$elapsed)};$nextTick+=$TickSeconds}
            $silent=((Get-Date)-$lastActivity).TotalMinutes
            if($StallMinutes -gt 0 -and !$stallReported -and $silent -ge $StallMinutes){$stallReported=$true;if($OnStall){& $OnStall ([math]::Round($silent,1))}}
            if($OnIdle){& $OnIdle}
            if(!$progress){Start-Sleep -Milliseconds 250}
        }
        if($state -eq 'finished'){$process.WaitForExit();$code=$process.ExitCode}
    }finally{if($outLog){$outLog.Dispose()};$process.Dispose()}
    [ordered]@{state=$state;exitCode=$code;output=$outBuilder.ToString();error=$errBuilder.ToString();seconds=[int]((Get-Date)-$began).TotalSeconds}
}
function Get-SBJsonObjectText([string]$Text) {
    # The JSON object inside an answer: fenced ```json blocks first, then the span from the first { to the last }.
    if([string]::IsNullOrWhiteSpace($Text)){return $null}
    $fence=[regex]::Match($Text,'(?s)```(?:json)?\s*(\{.*\})\s*```')
    if($fence.Success){return $fence.Groups[1].Value}
    $a=$Text.IndexOf('{');$b=$Text.LastIndexOf('}')
    if($a -lt 0 -or $b -le $a){return $null}
    $Text.Substring($a,$b-$a+1)
}
function ConvertFrom-SBAgentStructuredOutput {
    # The structured answer of a one-shot run as JSON text, whatever the CLI envelope: Claude Code result (structured_output or result),
    # Codex JSONL (last agent_message), Gemini CLI JSON (response), or plain text holding one JSON object. text is the raw answer.
    param([string]$Provider,[string]$Output)
    $answer=$null;$structured=$null
    $documents=@()
    foreach($line in @([string]$Output -split "`r?`n")){$l=$line.Trim();if($l.StartsWith('{')){try{$documents+=,($l|ConvertFrom-Json -AsHashtable -Depth 64 -ErrorAction Stop)}catch{[void]$_}}}
    if(!$documents.Count){try{$whole=([string]$Output).Trim();if($whole.StartsWith('{')){$documents=@(($whole|ConvertFrom-Json -AsHashtable -Depth 64 -ErrorAction Stop))}}catch{[void]$_}}
    foreach($o in $documents){
        if($o -isnot [System.Collections.IDictionary]){continue}
        $type=[string]$o['type']
        if($type -eq 'result'){
            if($o.Contains('structured_output') -and $o.structured_output -is [System.Collections.IDictionary]){$structured=$o.structured_output}
            if($o.Contains('result')){$answer=[string]$o.result}
        }elseif($type -eq 'item.completed' -and $o['item'] -is [System.Collections.IDictionary] -and [string]$o.item['type'] -in @('agent_message','assistant_message')){
            $answer=[string]$o.item['text']
        }elseif($o.Contains('response') -and $o.response -is [string]){$answer=[string]$o.response}
    }
    if($structured){return @{json=($structured|ConvertTo-Json -Depth 40 -Compress);text=$answer}}
    if($null -eq $answer -and !$documents.Count){$answer=[string]$Output}
    if($null -eq $answer -and $documents.Count -eq 1 -and !$documents[0].Contains('type')){return @{json=($documents[0]|ConvertTo-Json -Depth 40 -Compress);text=$null}}
    @{json=(Get-SBJsonObjectText $answer);text=$answer}
}
function Test-SBAgentStructuredOutput([string]$Json,[string]$SchemaText) {
    # Validation of the answer against the JSON schema (Test-Json); errors are returned, never thrown.
    if([string]::IsNullOrWhiteSpace($Json)){return @{valid=$false;errors=@('no JSON object in the answer')}}
    $errs=$null
    $ok=Test-Json -Json $Json -Schema $SchemaText -ErrorAction SilentlyContinue -ErrorVariable errs
    @{valid=[bool]$ok;errors=@(@($errs)|ForEach-Object {[string]$_.Exception.Message}|Where-Object {$_}|Select-Object -First 8)}
}
Export-ModuleMember -Function @('Invoke-SBAgentProcess','ConvertFrom-SBAgentStructuredOutput','Test-SBAgentStructuredOutput','Get-SBJsonObjectText','Test-SBAgentFlagAvailable','Get-SBAgentProviderIds','Get-SBAgentProvider','Get-SBAgentProviderForPath','Get-SBAgentSearchDirectories','Find-SBAgentInDirectories','Get-SBAgentPackageExecutable','Get-SBAgentProcessPath','Resolve-SBAgentExecutable','Invoke-SBAgentProbeCommand','Get-SBAgentVersion','Get-SBAgentHelpFlags','ConvertFrom-SBAgentHelp','Read-SBCodexModelsCache','Read-SBAgentConfigured','Get-SBAgentConfigPaths','Read-SBAgentModelTable','Get-SBAgentCapabilities','Get-SBAgentCapabilitiesAll','Test-SBAgentSelection','New-SBAgentInvocation','Get-SBAgentLimitPatterns','ConvertFrom-SBAgentRateLimitEvent','Get-SBAgentErrorText','Get-SBAgentLimitState','Read-SBCodexRateLimits','Get-SBAgentQuota')
