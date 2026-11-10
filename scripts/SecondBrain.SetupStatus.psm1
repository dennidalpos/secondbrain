#requires -Version 7.5
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Host.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Trace.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Add-SBMessages @{
    'setupstatus.env.reason'        = @{ it = 'Il lanciatore dei task e l''hook di pubblicazione richiedono SECONDBRAIN_HOME.'; en = 'The task launcher and the publication hook require SECONDBRAIN_HOME.' }
    'setupstatus.mcp.reason'        = @{ it = 'IDE rilevato senza server MCP SecondBrain: l''agent non vede dossier e prompt.'; en = 'IDE detected without the SecondBrain MCP server: the agent cannot reach dossiers and prompts.' }
    'setupstatus.trace.reason'      = @{ it = 'Claude Code rilevato: l''hook Stop segnala la compattazione; non concede alcun permesso di scrittura.'; en = 'Claude Code detected: the Stop hook signals compaction; it grants no write permission.' }
    'setupstatus.resources.reason'  = @{ it = 'Aggiorna le fonti autorevoli all''avvio della sessione se l''ultimo controllo ha piu di 14 giorni.'; en = 'Refreshes the authoritative sources at session start when the last check is older than 14 days.' }
    'setupstatus.publication.reason' = @{ it = 'Il repository ha un remote: l''hook pre-push esegue la scansione di pubblicazione prima di ogni push.'; en = 'The repository has a remote: the pre-push hook runs the publication scan before every push.' }
    'setupstatus.launcher.reason'   = @{ it = 'Permette di eseguire i task pronti con il runner; richiede SECONDBRAIN_HOME.'; en = 'Lets the runner execute ready tasks; requires SECONDBRAIN_HOME.' }
    'setupstatus.activity.reason'   = @{ it = 'Registro attivita di team, facoltativo: richiede un''informativa e una ritenzione dichiarate.'; en = 'Optional team activity register: requires a declared privacy notice and retention.' }
    'setupstatus.blocked.inactive'  = @{ it = 'Postazione non attivata: eseguire prima SYS03.'; en = 'Workstation not activated: run SYS03 first.' }
}
function New-SBFeature([string]$Id,[string]$State,[string]$Evidence,[string]$Command,[string[]]$Prerequisites=@(),[string]$Risk='low',[bool]$Recommended=$false,[string]$ReasonKey,[string]$Scope='') {
    [ordered]@{id=$Id;scope=$Scope;state=$State;evidence=$Evidence;enableCommand=$Command;prerequisites=@($Prerequisites);risk=$Risk;recommended=$Recommended;reason=$(if($ReasonKey){Get-SBMessage $ReasonKey}else{''})}
}
function Get-SBTraceUsage([string]$BrainRoot) {
    # Counts only: files and events per day. Never reads event contents.
    $root=Join-Path ([IO.Path]::GetFullPath($BrainRoot)) '.runtime/trace'
    $files=@(if(Test-Path -LiteralPath $root){Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.jsonl' -ErrorAction SilentlyContinue})
    $events=0;foreach($file in $files){$events+=@([IO.File]::ReadLines($file.FullName)).Count}
    [ordered]@{present=($files.Count -gt 0);files=$files.Count;events=$events}
}
function Get-SBSetupFeatureStatus {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$BrainRoot,[string]$HomeValue=$env:SECONDBRAIN_HOME,[string]$SettingsPath,[object[]]$Ides,[object[]]$Bindings,[hashtable]$Config)
    $brain=[IO.Path]::GetFullPath($BrainRoot)
    if(!$SettingsPath){$SettingsPath=Get-SBTraceSettingsPath}
    $features=@()
    $homeSet=[bool]$HomeValue
    $features+=New-SBFeature 'environment' $(if($homeSet){'enabled'}else{'available'}) $(if($homeSet){'SECONDBRAIN_HOME set'}else{'SECONDBRAIN_HOME not set'}) 'pwsh -NoProfile -File scripts/secondbrain.ps1 -Setup -Interactive -RegisterEnvironment' @('workstation-activated') 'low' (!$homeSet) 'setupstatus.env.reason'
    foreach($ide in @($Ides)){
        $configured=[bool]$ide.mcpConfigured
        $adapter=[string]$ide.adapter
        $target=$null
        foreach($pair in @(@('claude-code','claude-code'),@('codex','codex'),@('cursor','cursor'),@('antigravity','antigravity'),@('windsurf','windsurf'),@('vscode','vscode'),@('code','vscode'),@('claude','claude'))){if($adapter -match $pair[0]){$target=$pair[1];break}}
        if(!$target){$features+=New-SBFeature 'mcp' 'unsupported' ('no MCP target for '+$ide.name) $null @() 'low' $false $null $ide.name;continue}
        $features+=New-SBFeature 'mcp' $(if($configured){'enabled'}else{'available'}) ($ide.name+' mcpConfigured='+$configured) ('pwsh -NoProfile -File scripts/mcp-server.ps1 -Pair -Target '+$target) @() 'medium' (!$configured) 'setupstatus.mcp.reason' $ide.name
    }
    $hasClaudeCode=@($Ides|Where-Object {[string]$_.adapter -match 'claude-code' -or [string]$_.name -match 'Claude Code'}).Count -gt 0
    if($hasClaudeCode){
        $state=try{Get-SBTraceHookState $brain $SettingsPath}catch{$null}
        $installed=[bool]($state -and $state.installed)
        $features+=New-SBFeature 'trace-hook' $(if($state){$(if($installed){'enabled'}else{'available'})}else{'blocked'}) ('settings '+$SettingsPath) 'pwsh -NoProfile -File scripts/trace.ps1 -InstallHook' @() 'low' (!$installed -and [bool]$state) 'setupstatus.trace.reason' 'claude-code'
        $resourcesInstalled=$false
        if($state -and $state.settings.ContainsKey('hooks') -and $state.settings.hooks -is [Collections.IDictionary] -and $state.settings.hooks.ContainsKey('SessionStart')){
            $resourcesInstalled=$null -ne (ConvertTo-Json $state.settings.hooks.SessionStart -Depth 8 | Select-String -SimpleMatch 'resources-hook.ps1')
        }
        $features+=New-SBFeature 'resources-hook' $(if($resourcesInstalled){'enabled'}else{'available'}) 'SessionStart entry in Claude Code settings' 'pwsh -NoProfile -File scripts/resources-hook.ps1 -ShowConfiguration' @('resources-registry') 'low' (!$resourcesInstalled -and (Test-Path -LiteralPath (Join-Path $brain '03-resources/authoritative-sources/entries'))) 'setupstatus.resources.reason' 'claude-code'
    }
    foreach($binding in @($Bindings)){
        $path=[string]$binding.path
        if(!$path -or !(Test-Path -LiteralPath $path)){continue}
        $remote=$false
        try{$top=(& git -C $path rev-parse --show-toplevel 2>$null);if($LASTEXITCODE -eq 0 -and [IO.Path]::GetFullPath([string]$top).TrimEnd('','/') -ieq [IO.Path]::GetFullPath($path).TrimEnd('','/')){$remote=@(& git -C $path remote 2>$null).Count -gt 0}}catch{$remote=$false}
        $hookFile=Join-Path $path '.git/hooks/pre-push'
        $hookOn=(Test-Path -LiteralPath $hookFile -PathType Leaf) -and ([IO.File]::ReadAllText($hookFile) -match 'SecondBrain pre-push hook')
        $features+=New-SBFeature 'publication-hook' $(if($hookOn){'enabled'}elseif($remote){'available'}else{'unsupported'}) ('pre-push in '+$path) ('pwsh -NoProfile -File scripts/publication.ps1 -InstallHook -RepositoryPath "'+$path+'"') @('SECONDBRAIN_HOME') 'low' ($remote -and !$hookOn) 'setupstatus.publication.reason' ([string]$binding.identity)
        $launcher=Join-Path $path '.secondbrain/run-tasks.ps1'
        $launcherOn=Test-Path -LiteralPath $launcher -PathType Leaf
        $features+=New-SBFeature 'task-launcher' $(if($launcherOn){'enabled'}else{'available'}) ('launcher in '+$path) ('pwsh -NoProfile -File scripts/install-task-launcher.ps1 -Repository '+[string]$binding.identity) @('SECONDBRAIN_HOME') 'medium' $false 'setupstatus.launcher.reason' ([string]$binding.identity)
    }
    $activity=$Config -and $Config.ContainsKey('activityLogEnabled') -and [bool]$Config.activityLogEnabled
    $features+=New-SBFeature 'activity-register' $(if($activity){'enabled'}else{'available'}) 'activityLogEnabled in the host configuration' 'edit the host configuration (explicit, with privacy notice)' @('privacy-notice','retention') 'high' $false 'setupstatus.activity.reason'
    @($features)
}
function Get-SBSetupWizardStatus {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$BrainRoot,[string]$WorkspacePath,[string]$SettingsPath)
    $brain=[IO.Path]::GetFullPath($BrainRoot)
    $configPath=Get-SBHostConfigPath $brain
    $activated=Test-Path -LiteralPath $configPath -PathType Leaf
    $config=if($activated){Read-SBJson $configPath @{}}else{@{}}
    $bindings=if($config.ContainsKey('bindings')){@($config.bindings)}else{@()}
    $detected=@(Get-SBIDEDetection $WorkspacePath)
    $features=if($activated){@(Get-SBSetupFeatureStatus -BrainRoot $brain -SettingsPath $SettingsPath -Ides $detected -Bindings $bindings -Config $config)}else{@()}
    [ordered]@{
        schemaVersion=1;hostId=(Get-SBHostId);activated=$activated
        blocked=$(if($activated){$null}else{Get-SBMessage 'setupstatus.blocked.inactive'})
        ides=@($detected|ForEach-Object {[ordered]@{name=$_.name;adapter=$_.adapter;confidence=$_.confidence;mcpConfigured=$_.mcpConfigured;scopes=@($_.scopes)}})
        usage=(Get-SBTraceUsage $brain)
        features=$features
        recommended=@($features|Where-Object {$_.recommended}|ForEach-Object {$_.id+$(if($_.scope){':'+$_.scope}else{''})})
    }
}
Export-ModuleMember -Function @('Get-SBTraceUsage','Get-SBSetupFeatureStatus','Get-SBSetupWizardStatus')
