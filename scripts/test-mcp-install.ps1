# Included by portable: all paths and native CLI invocations are synthetic.
$installRoot=Join-Path $fixture 'mcp-install'
$nativeCalls=[Collections.Generic.List[object]]::new()
$installNative={
    param($nativeCommand,$nativeArguments,$nativeCwd,$nativeEnvironment,$destination,$definition)
    $nativeCalls.Add(@{command=$nativeCommand;arguments=$nativeArguments;cwd=$nativeCwd;environment=$nativeEnvironment})
    [IO.Directory]::CreateDirectory((Split-Path $destination))|Out-Null
    if($nativeCommand -eq 'codex'){
        $before=if(Test-Path -LiteralPath $destination){Read-SBText $destination}else{''}
        $nativeText=$before+"`n[mcp_servers.secondbrain]`ncommand = `"pwsh`"`nargs = "+(ConvertTo-Json -InputObject @($definition.args) -Compress)+"`n"
    }else{
        $settings=if(Test-Path -LiteralPath $destination){Read-SBJson $destination @{}}else{@{}}
        if(!$settings.ContainsKey('mcpServers')){$settings.mcpServers=@{}}
        $settings.mcpServers.secondbrain=$definition;$nativeText=ConvertTo-SBJson $settings
    }
    [IO.File]::WriteAllText($destination,$nativeText)
    @{status='applied';exitCode=0}
}.GetNewClosure()
foreach($target in @('codex','claude','claude-code','cursor','vscode','antigravity','windsurf')){
    $directory=Join-Path $installRoot $target
    $configFile=Join-Path $directory $(if($target -eq 'codex'){'config.toml'}else{'config.json'})
    $before=if($target -eq 'codex'){"# personal comment`n[other]`nvalue = `"keep`"`n"}else{ConvertTo-SBJson @{personal='keep';mcpServers=@{other=@{command='other'}}}}
    Put-Portable $configFile $before
    $installed=Set-SBMcpConfiguration -BrainRoot $brain -Target $target -Scope user -ConfigFile $configFile -BackupRoot (Join-Path $directory 'backup') -ApproveReadTools -CliInvoker $installNative
    Assert-Portable ($installed.Action -in @('updated','applied') -and $installed.BackupFile -and (Read-SBText $installed.BackupFile) -ceq $before) ("MCP $target : original bytes backed up")
    $installedHash=Get-SBFileHash $configFile
    $again=Set-SBMcpConfiguration -BrainRoot $brain -Target $target -Scope user -ConfigFile $configFile -BackupRoot (Join-Path $directory 'backup') -ApproveReadTools -CliInvoker $installNative
    Assert-Portable ($again.Action -eq 'unchanged' -and (Get-SBFileHash $configFile) -eq $installedHash) ("MCP $target : idempotent")
    if($target -eq 'codex'){
        $content=Read-SBText $configFile
        Assert-Portable ($content.Contains('# personal comment') -and $content.Contains('[other]') -and $content.Contains('[mcp_servers.secondbrain.tools.check_publication]')) 'Codex preserves unrelated TOML and explicitly prompts for publication'
        $policyTables=[regex]::Matches($content,'(?ms)^\[mcp_servers\.secondbrain\.tools\.(?<name>[^\]]+)\]\n(?<body>.*?)(?=^\[|\z)')
        $auto=@($policyTables|Where-Object {$_.Groups['body'].Value -match 'approval_mode = "approve"'}|ForEach-Object {$_.Groups['name'].Value})
        Assert-Portable ($auto.Count -eq 7 -and 'check_publication' -notin $auto -and $auto -notcontains '*') 'Codex approves exactly seven named tools with authorized pending recovery'
        $meta=Read-SBJson ($installed.BackupFile+'.json') @{}
        Assert-Portable ($meta.deployedHash -eq $installedHash) 'native backup metadata records final policy bytes'
    }elseif($target -eq 'claude-code'){
        $permissions=Read-SBJson (Join-Path $directory '.claude/settings.json') @{}
        Assert-Portable ($permissions.permissions.allow.Count -eq 7 -and $permissions.permissions.ask -contains 'mcp__secondbrain__check_publication') 'Claude Code explicit allow names and publication ask'
    }elseif($target -eq 'cursor'){
        $permissions=Read-SBJson (Join-Path $directory 'permissions.json') @{}
        Assert-Portable ($permissions.mcpAllowlist.Count -eq 7 -and 'secondbrain:check_publication' -notin $permissions.mcpAllowlist) 'Cursor knowledge allowlist excludes publication'
    }else{
        Assert-Portable ($installed.PermissionAction -in @('manual','unverified')) ("MCP $target : no invented permission format")
    }
}
Assert-Portable ($nativeCalls.Count -eq 2 -and @($nativeCalls|Where-Object {$_.command -eq 'claude' -and $_.arguments -contains 'user'}).Count -eq 1) 'native CLI used once per native target with user scope'
$failedFile=Join-Path $installRoot 'failed/config.json'
Put-Portable $failedFile '{"other":"keep"}'
$failure=Set-SBMcpConfiguration -BrainRoot $brain -Target claude-code -ConfigFile $failedFile -BackupRoot (Join-Path $installRoot 'failed/backup') -ApproveReadTools -CliInvoker {param($nativeCommand,$nativeArguments,$nativeCwd,$nativeEnvironment,$destination,$definition) @{status='cli-failed';exitCode=9}}
Assert-Portable ($failure.Action -eq 'cli-failed' -and $failure.PermissionAction -eq 'skipped' -and (Read-SBText $failedFile) -ceq '{"other":"keep"}') 'CLI failure preserves configuration and skips policy'
$unverified=Set-SBMcpConfiguration -BrainRoot $brain -Target claude-code -ConfigFile $failedFile -BackupRoot (Join-Path $installRoot 'failed/backup') -CliInvoker {param($nativeCommand,$nativeArguments,$nativeCwd,$nativeEnvironment,$destination,$definition) @{status='applied';exitCode=0}}
Assert-Portable ($unverified.Action -eq 'cli-unverified') 'CLI success without expected registration is not accepted'
$missing=Set-SBMcpConfiguration -BrainRoot $brain -Target claude-code -ConfigFile $failedFile -BackupRoot (Join-Path $installRoot 'failed/backup') -CliInvoker {param($nativeCommand,$nativeArguments,$nativeCwd,$nativeEnvironment,$destination,$definition) @{status='cli-unavailable';exitCode=$null}}
Assert-Portable ($missing.Action -eq 'cli-unavailable') 'missing native CLI has explicit outcome, no fallback'
$failedLauncher=Join-Path $installRoot "native launcher's failure.cmd"
Put-Portable $failedLauncher "@echo off`r`nexit /b 9`r`n"
$launcherResult=& (Get-Module SecondBrain.Mcp) {param($launcher) Invoke-SBMcpNative $launcher @('literal $()','two words') $null @{}} $failedLauncher
Assert-Portable ($launcherResult.status -eq 'cli-failed' -and $launcherResult.exitCode -eq 9) 'native Windows command launcher preserves a nonzero process exit code'
$conflictDir=Join-Path $installRoot 'cursor-conflict'
Put-Portable (Join-Path $conflictDir 'permissions.json') '{"mcpAllowlist":["secondbrain:*"]}'
$conflictFile=Join-Path $conflictDir 'mcp.json'
Reject-Portable {Set-SBMcpConfiguration -BrainRoot $brain -Target cursor -ConfigFile $conflictFile -ApproveReadTools} 'Cursor wildcard requires an explicit decision before changes'
Assert-Portable (!(Test-Path -LiteralPath $conflictFile)) 'permission conflict preflight precedes server registration'
Put-Portable (Join-Path $conflictDir 'permissions.json') "{ // personal comment`n `"mcpAllowlist`": [] }"
Reject-Portable {Set-SBMcpConfiguration -BrainRoot $brain -Target cursor -ConfigFile $conflictFile -ApproveReadTools} 'JSONC policy refused intact'
Put-Portable (Join-Path $conflictDir 'permissions.json') '{"mcpAllowlist":[],"mcpAllowlist":["secondbrain:*"]}'
Reject-Portable {Set-SBMcpConfiguration -BrainRoot $brain -Target cursor -ConfigFile $conflictFile -ApproveReadTools} 'duplicate JSON keys refused without losing a policy'
Put-Portable (Join-Path $conflictDir 'permissions.json') '{"mcpAllowlist":"secondbrain:*"}'
Reject-Portable {Set-SBMcpConfiguration -BrainRoot $brain -Target cursor -ConfigFile $conflictFile -ApproveReadTools} 'malformed permission containers refused intact'
# Existing restrictive Claude rules and unrelated settings must survive.
$claudeSettings=Join-Path $installRoot 'claude-code/.claude/settings.json'
Put-Portable $claudeSettings (ConvertTo-SBJson @{theme='keep';permissions=@{deny=@('mcp__secondbrain__search_knowledge');ask=@('mcp__secondbrain__get_task');allow=@('unrelated')}})
$null = Set-SBMcpConfiguration -BrainRoot $brain -Target claude-code -ConfigFile (Join-Path $installRoot 'claude-code/config.json') -ApproveReadTools -CliInvoker $installNative
$preserved=Read-SBJson $claudeSettings @{}
Assert-Portable ($preserved.theme -eq 'keep' -and $preserved.permissions.deny -contains 'mcp__secondbrain__search_knowledge' -and $preserved.permissions.ask -contains 'mcp__secondbrain__get_task' -and $preserved.permissions.allow -contains 'unrelated') 'existing ask/deny and unrelated settings preserved'
# Exact PowerShell quoting round-trip: metacharacters remain data.
$retryTarget=Join-Path $installRoot "retry's script.ps1"
Put-Portable $retryTarget 'param([string]$Text,[string[]]$Items,[switch]$Flag) ConvertTo-Json -InputObject @{Text=$Text;Items=$Items;Flag=[bool]$Flag} -Compress'
$retryValues=@{Text='literal $() ` ; '' "';Items=@('one','two space');Flag=$true}
$retry=Get-SBRetryCommand $retryTarget $retryValues
$roundtrip=& ([scriptblock]::Create($retry))|ConvertFrom-Json
Assert-Portable ($roundtrip.Text -ceq $retryValues.Text -and $roundtrip.Items.Count -eq 2 -and $roundtrip.Flag) 'retry command preserves apostrophes, arrays and shell metacharacters'
Assert-Portable ((Get-SBIDEWriteScope @{name='old'}).status -eq 'unverified' -and (Get-SBIDEWriteScope @{writeScope=@{status='verified';roots=@();evidence=$null}}).status -eq 'unverified') 'old or incomplete write capability remains unverified'
if(Get-Variable cfg -ErrorAction SilentlyContinue){
    $savedIdes=$cfg.ides
    try{
        $capabilityIde=@{id='fixture-capability';name='Fixture capability';mode='manual';accountAlias='fixture'}
        $cfg.ides=@($capabilityIde)
        $generation=Get-SBWriteGeneration
        $unknownCheck=Invoke-SBPortableSync -Config $cfg -Check
        Assert-Portable (@($unknownCheck.environment|Where-Object kind -eq 'ide-write-scope-unverified').Count -eq 1 -and (Get-SBWriteGeneration) -eq $generation) 'Check reports unverified write capability without write probes'
        $capabilityIde.writeScope=@{status='denied';roots=@($fixture);evidence='synthetic ACL fixture, not a live IDE session'}
        $deniedCheck=Invoke-SBPortableSync -Config $cfg -Check
        Assert-Portable (@($deniedCheck.environment|Where-Object kind -eq 'ide-write-scope-denied').Count -eq 1) 'Check distinguishes observed denial from missing evidence'
    }finally{$cfg.ides=$savedIdes}
}
