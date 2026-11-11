#requires -Version 7.5
# Agent CLI adapters for the task runner and the desktop orchestrator: Claude Code (claude -p), Codex (codex exec) and Gemini CLI (gemini).
# Capabilities come from the installed CLI (--version, --help), its local configuration and, last, the fallback table config/agent-models.json.
# Every model and effort level carries its source (probe, config, fallback). Only flags present in the installed --help are passed.
# Read-only: the probe runs --version and --help with a timeout and reads configuration files; nothing here writes.
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
function Resolve-SBAgentExecutable([string]$Command) {
    # Prefer a real executable or a .cmd shim; a .ps1 shim (npm) cannot be started directly, so it is wrapped in pwsh -File.
    if(!$Command){return $null}
    $found=@(Get-Command $Command -All -ErrorAction SilentlyContinue)
    if(!$found.Count){return $null}
    $app=@($found|Where-Object {$_.CommandType -eq 'Application' -and $_.Source -match '\.(exe|cmd|bat)$|^[^.]*$|/[^/.]+$'}|Sort-Object @{e={if($_.Source -like '*.exe'){0}else{1}}})|Select-Object -First 1
    if($app){return @{path=$app.Source;prefix=@()}}
    $source=$found[0].Source
    if($source -like '*.ps1'){return @{path=(Get-Process -Id $PID).Path;prefix=@('-NoProfile','-File',$source);script=$source}}
    @{path=$source;prefix=@()}
}
function Invoke-SBAgentProbeCommand($Executable,[string[]]$Arguments,[int]$TimeoutSeconds=20) {
    # Runs one read-only probe (--version, --help) and returns stdout+stderr, or $null on timeout or start failure.
    try{
        $start=[Diagnostics.ProcessStartInfo]::new($Executable.path);$start.UseShellExecute=$false;$start.CreateNoWindow=$true
        $start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true;$start.RedirectStandardInput=$true
        foreach($a in (@($Executable.prefix)+$Arguments)){$start.ArgumentList.Add([string]$a)}
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
    $models=Merge-SBAgentModels @($probeModels,$configModels,$fallbackModels)
    $flags=@($parsed.flags)
    $known=@($flags).Count -gt 0
    $supportsModel=if($known){$info.modelFlag -in $flags -or '-m' -in $flags}else{$false}
    $supportsEffort=if(!$info.effortFlag){$false}elseif($known){$info.effortFlag -in $flags -or ($Provider -eq 'codex' -and '-c' -in $flags)}else{$false}
    $efforts=@()
    if($supportsEffort -or !$known){
        if(@($parsed.efforts).Count){$efforts=@($parsed.efforts|ForEach-Object {@{id=$_;source='probe'}})}
        else{
            $fromModels=@($models|ForEach-Object {@($_.efforts)}|Where-Object {$_}|Select-Object -Unique)
            if($fromModels.Count){$efforts=@($fromModels|ForEach-Object {@{id=$_;source='config'}})}
            elseif(@($fallback.efforts).Count -and $info.effortFlag){$efforts=@($fallback.efforts|Select-Object -Unique|ForEach-Object {@{id=$_;source='fallback'}})}
        }
    }
    [ordered]@{
        provider=$Provider;name=$info.name;command=$info.command
        installed=[bool]$Executable;path=$(if($Executable){$(if($Executable.ContainsKey('script')){$Executable.script}else{$Executable.path})}else{$null})
        version=(Get-SBAgentVersion $VersionText);helpRead=$known
        flags=$flags;supports=[ordered]@{model=$supportsModel;effort=$supportsEffort}
        configured=$configured;models=@($models);efforts=@($efforts)
    }
}
function Test-SBAgentSelection($Capabilities,[string]$Model,[string]$Effort,[switch]$AllowCustomModel) {
    # Validates the queue choice against the probe; errors name the next step.
    $c=$Capabilities;$name=$c.name
    if($Model){
        if(!$c.supports.model){throw (New-SBError 'agents.model.unsupported' @($name,(Get-SBAgentProvider $c.provider).modelFlag))}
        $ids=@($c.models|ForEach-Object {$_.id})
        if($Model -notin $ids -and !$AllowCustomModel){throw (New-SBError 'agents.model.unknown' @($Model,$name,($ids -join ', '),$c.provider))}
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
function New-SBAgentInvocation {
    # Headless arguments per provider with the fixed permission profile; the prompt always goes on stdin.
    # With a probed --help, flags it does not list are left out and reported in omitted.
    param([Parameter(Mandatory)][string]$Provider,$Capabilities,[string]$Model,[string]$Effort)
    $state=@{flags=@($(if($Capabilities){$Capabilities.flags}));list=[Collections.Generic.List[string]]::new();omitted=[Collections.Generic.List[string]]::new()}
    $list=$state.list
    function Add-Flag([string]$Flag,[string[]]$Values=@(),[string]$Alias){Add-SBAgentFlag $state $Flag $Values $Alias}
    switch($Provider){
        'claude' {
            $list.Add('-p')
            Add-Flag '--output-format' @('json')
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
            Add-Flag '--output-format' @('json') '-o'
            Add-Flag '--approval-mode' @('auto_edit')
            if($Model){Add-Flag '--model' @($Model) '-m'}
        }
        default {throw (New-SBError 'agents.provider.unknown' @($Provider,(@($script:SBAgentProviders.Keys) -join ', ')))}
    }
    @{arguments=@($state.list);omitted=@($state.omitted)}
}
function Get-SBAgentQuotaPattern {
    # Exhausted plan or rate limit, as reported by Claude Code, Codex and Gemini CLI.
    'usage_limit_reached|usage limit|weekly limit|rate_limit_error|rate limit|quota|RESOURCE_EXHAUSTED'
}
function Test-SBAgentErrorOutput([string]$Text) {
    # A JSON envelope that reports an error even with exit 0 (claude is_error, gemini error object).
    [bool]($Text -match '"is_error"\s*:\s*true|"error"\s*:\s*\{')
}
Export-ModuleMember -Function @('Get-SBAgentProviderIds','Get-SBAgentProvider','Get-SBAgentProviderForPath','Resolve-SBAgentExecutable','Invoke-SBAgentProbeCommand','Get-SBAgentVersion','Get-SBAgentHelpFlags','ConvertFrom-SBAgentHelp','Read-SBCodexModelsCache','Read-SBAgentConfigured','Get-SBAgentConfigPaths','Read-SBAgentModelTable','Get-SBAgentCapabilities','Test-SBAgentSelection','New-SBAgentInvocation','Get-SBAgentQuotaPattern','Test-SBAgentErrorOutput')
