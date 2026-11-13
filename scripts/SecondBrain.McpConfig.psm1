#requires -Version 7.5
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Add-SBMessages @{
    'mcp.pair.scope' = @{ it = 'Ambito non supportato per {0}: {1}'; en = 'Unsupported scope for {0}: {1}' }
}
function Get-SBMcpReadOnlyToolNames {
    # Compatibility entry point: recovery-enabled tools no longer qualify as read-only.
    @()
}
function Get-SBMcpKnowledgeToolNames {
    @('get_startup_context', 'get_ready_tasks', 'get_task', 'search_knowledge', 'list_prompts', 'get_prompt', 'get_prompt_home')
}
function Test-SBClaudeCodeRegistration([string]$ConfigFile) {
    # Read-only .claude.json access: user-level server (mcpServers) or project-local server (projects.<path>.mcpServers).
    if (!$ConfigFile -or !(Test-Path -LiteralPath $ConfigFile -PathType Leaf)) { return $false }
    try {
        $document = Get-Content -LiteralPath $ConfigFile -Raw -ErrorAction Stop | ConvertFrom-Json -AsHashtable -ErrorAction Stop
        if ($document -isnot [System.Collections.IDictionary]) { return $false }
        if ($document.ContainsKey('mcpServers') -and $document.mcpServers -is [System.Collections.IDictionary] -and $document.mcpServers.ContainsKey('secondbrain')) { return $true }
        if ($document.ContainsKey('projects') -and $document.projects -is [System.Collections.IDictionary]) {
            foreach ($project in $document.projects.Values) {
                if ($project -is [System.Collections.IDictionary] -and $project.ContainsKey('mcpServers') -and $project.mcpServers -is [System.Collections.IDictionary] -and $project.mcpServers.ContainsKey('secondbrain')) { return $true }
            }
        }
    } catch { Write-Verbose $_.Exception.Message }
    $false
}
Add-SBMessages @{
    'mcp.pair.json' = @{ it = 'Configurazione MCP non è JSON rigoroso (errori o commenti), nessuna modifica: {0}. Inserisci a mano il frammento mostrato da mcp-server.ps1 -Pair.'; en = 'MCP configuration is not strict JSON (errors or comments), no change made: {0}. Add by hand the fragment shown by mcp-server.ps1 -Pair.' }
    'mcp.pair.toml' = @{ it = 'TOML ambiguo o non supportato, nessuna modifica: {0}'; en = 'Ambiguous or unsupported TOML, no change made: {0}' }
    'mcp.pair.permissions.conflict' = @{ it = 'Regola esistente concede consenso a check_publication; nessuna modifica: {0}'; en = 'Existing rule approves check_publication; no change made: {0}' }
    'mcp.pair.permissions.scope' = @{ it = 'Selezionare un solo ambito di approvazione MCP'; en = 'Select only one MCP permission scope' }
    'mcp.pair.root' = @{ it = 'Configurazione MCP con radice non oggetto, nessuna modifica: {0}'; en = 'MCP configuration with a non-object root, no change made: {0}' }
}
# Private pairing helpers.
function Read-SBMcpSettings([string]$Path) {
    if(!(Test-Path -LiteralPath $Path -PathType Leaf)){return @{}}
    $raw=Read-SBText $Path
    if(!$raw.Trim()){return @{}}
    try {
        $document=[Text.Json.JsonDocument]::Parse($raw)
        try{
            function Assert-UniqueMcpKeys($Node){
                if($Node.ValueKind -eq [Text.Json.JsonValueKind]::Object){
                    $keys=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
                    foreach($property in $Node.EnumerateObject()){
                        if(!$keys.Add($property.Name)){throw (New-SBError 'mcp.pair.json' @($Path))}
                        Assert-UniqueMcpKeys $property.Value
                    }
                }elseif($Node.ValueKind -eq [Text.Json.JsonValueKind]::Array){foreach($item in $Node.EnumerateArray()){Assert-UniqueMcpKeys $item}}
            }
            Assert-UniqueMcpKeys $document.RootElement
        }finally{$document.Dispose()}
        $data=ConvertFrom-Json -InputObject $raw -AsHashtable
        if($data -isnot [Collections.IDictionary]){throw (New-SBError 'mcp.pair.root' @($Path))}
        $data
    } catch { throw (New-SBError 'mcp.pair.json' @($Path)) }
}
function Get-SBMcpPermissionPlan($Pairing,[switch]$ApproveAllTools) {
    $names=@(Get-SBMcpKnowledgeToolNames)
    if($ApproveAllTools){$names+='check_publication'}
    $requiresConsent=@('check_publication'|Where-Object {$_ -notin $names})
    $status='manual';$path=$null;$snippet=$null;$manualStep=$null
    switch($Pairing.Target){
        'codex' {
            $status='supported';$path=$Pairing.ConfigFile
            $lines=@('[mcp_servers.secondbrain]','default_tools_approval_mode = "prompt"')
            foreach($name in $names){$lines+=@("[mcp_servers.secondbrain.tools.$name]",'approval_mode = "approve"')}
            if($requiresConsent.Count){$lines+=@('[mcp_servers.secondbrain.tools.check_publication]','approval_mode = "prompt"')}
            $snippet=$lines -join "`n"
        }
        'claude-code' {
            $status='supported'
            $path=Join-Path (Split-Path $Pairing.ConfigFile) '.claude/settings.json'
            # CLAUDE_CONFIG_DIR is itself the settings directory, unlike the default profile root.
            $claudeRoot=[Environment]::GetEnvironmentVariable('CLAUDE_CONFIG_DIR','User')
            if(!$claudeRoot){$claudeRoot=$env:CLAUDE_CONFIG_DIR}
            if($Pairing.Scope -eq 'user'){
                $directory=Split-Path $Pairing.ConfigFile
                if(($claudeRoot -and (Test-SBSamePath $directory $claudeRoot)) -or
                    ((Split-Path $Pairing.ConfigFile -Leaf) -eq '.claude.json' -and !(Test-SBSamePath $directory $env:USERPROFILE))){$path=Join-Path $directory 'settings.json'}
            }
            $snippet=ConvertTo-SBJson @{permissions=@{allow=@($names|ForEach-Object {"mcp__secondbrain__$_"});ask=@($requiresConsent|ForEach-Object {"mcp__secondbrain__$_"})}}
        }
        'cursor' {
            $status='supported';$path=Join-Path $env:USERPROFILE '.cursor/permissions.json'
            if($Pairing.Scope -eq 'user'){$path=Join-Path (Split-Path $Pairing.ConfigFile) 'permissions.json'}
            $snippet=ConvertTo-SBJson @{mcpAllowlist=@($names|ForEach-Object {"secondbrain:$_"})}
        }
        'antigravity' {$status='unverified'}
        'windsurf' {$status='unverified'}
        'vscode' {$manualStep='Chat: Manage Tool Approval → SecondBrain → select the listed tools in the intended profile.'}
        'claude' {$manualStep='Open a new Claude Desktop session and review the per-tool permissions offered by the client.'}
    }
    @{status=$status;path=$path;snippet=$snippet;tools=$names;requiresConsent=$requiresConsent;manualStep=$manualStep;approveAllTools=[bool]$ApproveAllTools;contract='knowledge-with-authorized-pending-writes';automaticDossierWrites=$true}
}
function Set-SBMcpTomlValue([string]$Text,[string]$Table,[string]$Key,[string]$Value,[switch]$KeepRestrictive) {
    # Edit only a single-line string in an exact table. Preserve all other bytes/comments;
    # reject ambiguous/dotted encodings rather than rewriting arbitrary TOML.
    $header='(?m)^\['+[regex]::Escape($Table)+'\][ \t]*(?:#[^\r\n]*)?\r?$'
    $matches=[regex]::Matches($Text,$header)
    if($matches.Count -gt 1){throw (New-SBError 'mcp.pair.toml' @($Table))}
    if(!$matches.Count){return $Text.TrimEnd("`r","`n")+"`n`n[$Table]`n$Key = `"$Value`"`n"}
    $start=$matches[0].Index+$matches[0].Length
    $next=[regex]::Match($Text.Substring($start),'(?m)^\[')
    $end=if($next.Success){$start+$next.Index}else{$Text.Length}
    $body=$Text.Substring($start,$end-$start)
    $pattern='(?m)^(?<indent>[ \t]*)'+[regex]::Escape($Key)+'[ \t]*=[ \t]*["''](?<value>[A-Za-z-]+)["''](?<suffix>[ \t]*(?:#[^\r\n]*)?\r?)$'
    $values=[regex]::Matches($body,$pattern)
    $keyLines=[regex]::Matches($body,'(?m)^[ \t]*'+[regex]::Escape($Key)+'[ \t]*=')
    if($values.Count -gt 1 -or $keyLines.Count -ne $values.Count){throw (New-SBError 'mcp.pair.toml' @($Table+'.'+$Key))}
    if($values.Count){
        $current=$values[0].Groups['value'].Value
        if($current -notin @('auto','prompt','writes','approve')){throw (New-SBError 'mcp.pair.toml' @($Table+'.'+$Key))}
        if($KeepRestrictive -and $current -ne 'approve'){return $Text}
        $replacement=$values[0].Groups['indent'].Value+$Key+' = "'+$Value+'"'+$values[0].Groups['suffix'].Value
        $body=$body.Remove($values[0].Index,$values[0].Length).Insert($values[0].Index,$replacement)
    }else{$body=$body.TrimEnd("`r","`n")+"`n$Key = `"$Value`"`n"}
    $Text.Substring(0,$start)+$body+$Text.Substring($end)
}
function Get-SBMcpPermissionContent($Pairing) {
    $plan=$Pairing.PermissionPlan
    if($plan.status -ne 'supported'){return $null}
    if($Pairing.Target -eq 'codex'){
        $text=if(Test-Path -LiteralPath $plan.path){Read-SBText $plan.path}else{''}
        # Dotted or quoted policy tables need a TOML-aware editor. Never create conflicting tables.
        if($text -match '(?m)^\s*(?:["'']?mcp_servers["'']?\s*\.|\[\s*["'']mcp_servers|\[mcp_servers\.["'']secondbrain)'){
            throw (New-SBError 'mcp.pair.toml' @($plan.path))
        }
        if($text -match '(?m)^\s*\[\[?mcp_servers\.secondbrain[^\r\n]*["'']' -or
            $text -match '(?m)^\s*(?:tools\.|secondbrain\s*=|["'']?(?:default_tools_approval_mode|approval_mode)["'']\s*=)'){
            throw (New-SBError 'mcp.pair.toml' @($plan.path))
        }
        $text=Set-SBMcpTomlValue $text 'mcp_servers.secondbrain' 'default_tools_approval_mode' 'prompt'
        foreach($name in $plan.tools){$text=Set-SBMcpTomlValue $text ('mcp_servers.secondbrain.tools.'+$name) 'approval_mode' 'approve' -KeepRestrictive:(!$plan.approveAllTools)}
        if($plan.requiresConsent.Count){$text=Set-SBMcpTomlValue $text 'mcp_servers.secondbrain.tools.check_publication' 'approval_mode' 'prompt'}
        return $text
    }
    $data=Read-SBMcpSettings $plan.path
    $requested=ConvertFrom-Json -InputObject $plan.snippet -AsHashtable
    if($Pairing.Target -eq 'cursor'){
        if($data.ContainsKey('mcpAllowlist') -and ($data.mcpAllowlist -isnot [array] -or @($data.mcpAllowlist|Where-Object {$_ -isnot [string]}).Count)){throw (New-SBError 'mcp.pair.json' @($plan.path))}
        $previous=if($data.ContainsKey('mcpAllowlist')){@($data.mcpAllowlist)}else{@()}
        foreach($entry in $previous){
            $pieces=([string]$entry) -split ':',2
            if($pieces.Count -eq 2 -and 'secondbrain' -like $pieces[0] -and
                (($plan.approveAllTools -and $pieces[1] -match '[*?\[]') -or (!$plan.approveAllTools -and 'check_publication' -like $pieces[1]))){
                throw (New-SBError 'mcp.pair.permissions.conflict' @($plan.path))
            }
        }
        $data.mcpAllowlist=@(@($previous)+@($requested.mcpAllowlist)|Select-Object -Unique)
    }else{
        if(!$data.ContainsKey('permissions')){$data.permissions=@{}}
        if($data.permissions -isnot [Collections.IDictionary]){throw (New-SBError 'mcp.pair.json' @($plan.path))}
        foreach($key in @('allow','ask')){
            if($data.permissions.ContainsKey($key) -and ($data.permissions[$key] -isnot [array] -or @($data.permissions[$key]|Where-Object {$_ -isnot [string]}).Count)){throw (New-SBError 'mcp.pair.json' @($plan.path))}
            $previous=if($data.permissions.ContainsKey($key)){@($data.permissions[$key])}else{@()}
            if($plan.approveAllTools -and $key -eq 'ask'){$previous=@($previous|Where-Object {$_ -cne 'mcp__secondbrain__check_publication'})}
            $data.permissions[$key]=@(@($previous)+@($requested.permissions[$key])|Select-Object -Unique)
        }
    }
    ConvertTo-SBJson $data
}
function Invoke-SBMcpNative([string]$Command,[string[]]$Arguments,[string]$WorkingDirectory,[hashtable]$Environment) {
    $executable=Get-Command $Command -CommandType Application -ErrorAction SilentlyContinue|Select-Object -First 1
    if(!$executable){return @{status='cli-unavailable';exitCode=$null}}
    $info=[Diagnostics.ProcessStartInfo]::new($executable.Source)
    if([IO.Path]::GetExtension($executable.Source) -in @('.cmd','.bat')){
        $quoted=@(@($executable.Source)+@($Arguments)|ForEach-Object {"'"+([string]$_).Replace("'","''")+"'"})
        $invocation='& '+($quoted -join ' ')+'; exit $LASTEXITCODE'
        $info=[Diagnostics.ProcessStartInfo]::new((Get-Command pwsh -CommandType Application|Select-Object -First 1).Source)
        foreach($item in @('-NoProfile','-NonInteractive','-EncodedCommand',[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($invocation)))){$info.ArgumentList.Add($item)}
    }else{foreach($item in $Arguments){$info.ArgumentList.Add($item)}}
    $info.UseShellExecute=$false;$info.CreateNoWindow=$true
    $info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
    if($WorkingDirectory){$info.WorkingDirectory=$WorkingDirectory}
    foreach($key in $Environment.Keys){$info.Environment[$key]=[string]$Environment[$key]}
    $process=[Diagnostics.Process]::new();$process.StartInfo=$info
    try{
        [void]$process.Start();$stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
        if(!$process.WaitForExit(30000)){$process.Kill($true);return @{status='cli-timeout';exitCode=$null}}
        # CLI output may contain personal settings. Keep only the status, never echo it.
        [void]$stdout.GetAwaiter().GetResult();[void]$stderr.GetAwaiter().GetResult()
        @{status=$(if($process.ExitCode -eq 0){'applied'}else{'cli-failed'});exitCode=$process.ExitCode}
    }finally{$process.Dispose()}
}
function Test-SBMcpNativeDefinition($Pairing) {
    $present=$false;$matches=$false
    if($Pairing.Target -eq 'claude-code'){
        $data=Read-SBMcpSettings $Pairing.ConfigFile
        $present=$data.ContainsKey('mcpServers') -and $data.mcpServers -is [Collections.IDictionary] -and $data.mcpServers.ContainsKey('secondbrain')
        if($present){
            $definition=$data.mcpServers.secondbrain
            $matches=$definition -is [Collections.IDictionary] -and $definition.ContainsKey('command') -and $definition.command -eq 'pwsh' -and $definition.ContainsKey('args') -and (ConvertTo-SBJson @($definition.args)) -ceq (ConvertTo-SBJson @($Pairing.ServerDefinition.args))
        }
    }else{
        $text=if(Test-Path -LiteralPath $Pairing.ConfigFile -PathType Leaf){Read-SBText $Pairing.ConfigFile}else{''}
        $section=[regex]::Match($text,'(?ms)^\[mcp_servers\.secondbrain\][^\r\n]*\r?\n(?<body>.*?)(?=^\[|\z)')
        $present=$section.Success
        if($present){
            $body=$section.Groups['body'].Value
            $command=[regex]::Match($body,'(?m)^command\s*=\s*"pwsh"\s*(?:#.*)?\r?$')
            $argsMatch=[regex]::Match($body,'(?m)^args\s*=\s*(\[[^\r\n]*\])\s*$')
            if($command.Success -and $argsMatch.Success){try{$nativeArgs=ConvertFrom-Json $argsMatch.Groups[1].Value;$matches=(ConvertTo-SBJson @($nativeArgs)) -ceq (ConvertTo-SBJson @($Pairing.ServerDefinition.args))}catch { Write-Verbose $_.Exception.Message }}
        }
    }
    @{present=$present;matches=$matches}
}
function Save-SBMcpNativeSnapshot([string]$Path,[string]$BackupRoot,[string]$ExpectedHash) {
    if((Get-SBFileHash $Path) -ne $ExpectedHash){throw (New-SBError 'core.concurrent.modified' @($Path))}
    if($ExpectedHash -eq 'absent'){return $null}
    $backup=Join-Path $BackupRoot ((New-SBId)+'.bin')
    $bytes=[IO.File]::ReadAllBytes($Path)
    if((Get-SBHash $bytes) -ne $ExpectedHash){throw (New-SBError 'core.concurrent.modified' @($Path))}
    [void](Write-SBFile $backup $bytes 'absent' $BackupRoot)
    $metadata=@{path=[IO.Path]::GetFullPath($Path);previousHash=$ExpectedHash;backup=$backup;deployedHash=$null;native=$true}
    [void](Write-SBFile ($backup+'.json') ([Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $metadata))) 'absent' $BackupRoot)
    $backup
}

function Get-SBMcpPairing {
    [CmdletBinding()]
    param(
        [string]$BrainRoot,
        [Parameter()][ValidateSet('codex', 'claude', 'claude-code', 'cursor', 'vscode', 'antigravity', 'windsurf', 'all')][string]$Target = 'all',
        [string]$WorkspacePath,
        [string]$ClaudeCodeConfigFile,[Alias('ConfigFile')][string]$OverrideConfigFile,
        [ValidateSet('user','project')][string]$Scope,[switch]$ApproveAllTools
    )
    if (!$BrainRoot) {
        $BrainRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    }
    $BrainRoot = [IO.Path]::GetFullPath($BrainRoot)
    $serverScript = Join-Path $BrainRoot 'scripts/mcp-server.ps1'
    $serverScriptNormalized = $serverScript.Replace('\', '/')
    $effectiveScope=if($Scope){$Scope}elseif($WorkspacePath){'project'}else{'user'}
    if($effectiveScope -eq 'project' -and (!$WorkspacePath -or $Target -notin @('claude-code','cursor','vscode','antigravity'))){throw (New-SBError 'mcp.pair.scope' @($Target,$effectiveScope))}
    $workspaceRoot = if ($effectiveScope -eq 'project' -and $WorkspacePath) { [IO.Path]::GetFullPath($WorkspacePath) } else { $null }
    $quotedScript="'"+$serverScript.Replace("'","''")+"'"
    $escapedScript = $serverScript.Replace('\', '\\')

    [string[]]$targetsToProcess = if ($Target.ToLowerInvariant() -eq 'all') {
        @('codex', 'claude', 'claude-code', 'cursor', 'vscode', 'antigravity', 'windsurf')
    } else {
        @($Target.ToLowerInvariant())
    }

    [object[]]$results = @()
    foreach ($t in $targetsToProcess) {
        switch ($t) {
            'codex' {
                $codexRoot = [Environment]::GetEnvironmentVariable('CODEX_HOME','User')
                if (!$codexRoot) { $codexRoot = $env:CODEX_HOME }
                if (!$codexRoot) { $codexRoot = Join-Path $env:USERPROFILE '.codex' }
                $configFile = Join-Path $codexRoot 'config.toml'
                
                $toml = @(
                    '[mcp_servers.secondbrain]',
                    'command = "pwsh"',
                    "args = [`"-NoProfile`", `"-File`", `"$escapedScript`"]"
                ) -join "`n"
                $cliCommand = "codex mcp add secondbrain -- pwsh -NoProfile -File $quotedScript"
                
                $results += [PSCustomObject]@{
                    Target = 'codex'
                    Name = 'OpenAI Codex'
                    ConfigFile = $configFile
                    ConfigFormat = 'toml'
                    Toml = $toml
                    Snippet = $toml
                    CliCommand = $cliCommand
                    ServerDefinition = @{
                        command = 'pwsh'
                        args = @('-NoProfile', '-File', $serverScriptNormalized)
                    }
                    Configured = (Test-Path -LiteralPath $configFile -PathType Leaf) -and ((Get-Content -LiteralPath $configFile -Raw -ErrorAction SilentlyContinue) -match '(?m)\[mcp_servers\.secondbrain\]')
                }
            }
            'claude' {
                $claudeRoot = [Environment]::GetEnvironmentVariable('CLAUDE_CONFIG_DIR','User')
                if (!$claudeRoot) { $claudeRoot = $env:CLAUDE_CONFIG_DIR }
                $cliCommand = $null
                # Claude Code registers servers in .claude.json (under CLAUDE_CONFIG_DIR when set, otherwise the user profile), not claude_desktop_config.json.
                $claudeCodeFile = if ($ClaudeCodeConfigFile) { $ClaudeCodeConfigFile } elseif ($claudeRoot) { Join-Path $claudeRoot '.claude.json' } else { Join-Path $env:USERPROFILE '.claude.json' }
                $configFile = Join-Path $env:APPDATA 'Claude/claude_desktop_config.json'

                $snippetObj = [ordered]@{
                    mcpServers = [ordered]@{
                        secondbrain = [ordered]@{
                            command = 'pwsh'
                            args = @('-NoProfile', '-File', $serverScriptNormalized)
                        }
                    }
                }
                $json = ConvertTo-Json -InputObject $snippetObj -Depth 10
                # Claude Code: settings.json permission rules only for knowledge tools, to paste after user approval.

                $results += [PSCustomObject]@{
                    Target = 'claude'
                    Name = 'Claude Desktop'
                    ConfigFile = $configFile
                    ConfigFormat = 'json'
                    Toml = $null
                    Snippet = $json
                    PermissionsSnippet = $null
                    CliCommand = $cliCommand
                    ServerDefinition = @{
                        command = 'pwsh'
                        args = @('-NoProfile', '-File', $serverScriptNormalized)
                    }
                    Configured = (Test-Path -LiteralPath $configFile -PathType Leaf) -and ((Get-Content -LiteralPath $configFile -Raw -ErrorAction SilentlyContinue) -match '"secondbrain"')
                    DesktopConfigFile = $configFile
                    DesktopConfigured = (Test-Path -LiteralPath $configFile -PathType Leaf) -and ((Get-Content -LiteralPath $configFile -Raw -ErrorAction SilentlyContinue) -match '"secondbrain"')
                    CodeConfigFile = $claudeCodeFile
                    CodeConfigured = Test-SBClaudeCodeRegistration $claudeCodeFile
                }
            }
            'cursor' {
                $cursorRoot = if ($workspaceRoot) { Join-Path $workspaceRoot '.cursor' } else { Join-Path $env:USERPROFILE '.cursor' }
                $configFile = Join-Path $cursorRoot 'mcp.json'

                $snippetObj = [ordered]@{
                    mcpServers = [ordered]@{
                        secondbrain = [ordered]@{
                            command = 'pwsh'
                            args = @('-NoProfile', '-File', $serverScriptNormalized)
                        }
                    }
                }
                $json = ConvertTo-Json -InputObject $snippetObj -Depth 10

                $results += [PSCustomObject]@{
                    Target = 'cursor'
                    Name = 'Cursor IDE'
                    ConfigFile = $configFile
                    ConfigFormat = 'json'
                    Toml = $null
                    Snippet = $json
                    CliCommand = $null
                    ServerDefinition = @{
                        command = 'pwsh'
                        args = @('-NoProfile', '-File', $serverScriptNormalized)
                    }
                    Configured = (Test-Path -LiteralPath $configFile -PathType Leaf) -and ((Get-Content -LiteralPath $configFile -Raw -ErrorAction SilentlyContinue) -match '"secondbrain"')
                }
            }
            'vscode' {
                # VS Code reads MCP servers from mcp.json (servers key, required type): user profile or, with -WorkspacePath, the project's .vscode/.
                $configFile = if ($workspaceRoot) { Join-Path $workspaceRoot '.vscode/mcp.json' } else { Join-Path $env:APPDATA 'Code/User/mcp.json' }

                $snippetObj = [ordered]@{
                    servers = [ordered]@{
                        secondbrain = [ordered]@{
                            type = 'stdio'
                            command = 'pwsh'
                            args = @('-NoProfile', '-File', $serverScriptNormalized)
                        }
                    }
                }
                $json = ConvertTo-Json -InputObject $snippetObj -Depth 10

                $results += [PSCustomObject]@{
                    Target = 'vscode'
                    Name = 'Visual Studio Code'
                    ConfigFile = $configFile
                    ConfigFormat = 'json'
                    Toml = $null
                    Snippet = $json
                    CliCommand = $null
                    ServerDefinition = @{
                        command = 'pwsh'
                        args = @('-NoProfile', '-File', $serverScriptNormalized)
                    }
                    Configured = (Test-Path -LiteralPath $configFile -PathType Leaf) -and ((Get-Content -LiteralPath $configFile -Raw -ErrorAction SilentlyContinue) -match '"secondbrain"')
                }
            }
            'claude-code' {
                # Claude Code: project scope = .mcp.json in the project root (mcpServers key); user scope lives in ~/.claude.json, managed by the CLI.
                $configFile = if ($workspaceRoot) { Join-Path $workspaceRoot '.mcp.json' } else { $null }
                $claudeRootCode = [Environment]::GetEnvironmentVariable('CLAUDE_CONFIG_DIR','User')
                if (!$claudeRootCode) { $claudeRootCode = $env:CLAUDE_CONFIG_DIR }
                $userFile = if ($ClaudeCodeConfigFile) { $ClaudeCodeConfigFile } elseif ($claudeRootCode) { Join-Path $claudeRootCode '.claude.json' } else { Join-Path $env:USERPROFILE '.claude.json' }
                if(!$workspaceRoot){$configFile=$userFile}

                $snippetObj = [ordered]@{
                    mcpServers = [ordered]@{
                        secondbrain = [ordered]@{
                            command = 'pwsh'
                            args = @('-NoProfile', '-File', $serverScriptNormalized)
                        }
                    }
                }
                $json = ConvertTo-Json -InputObject $snippetObj -Depth 10
                $projectConfigured = $workspaceRoot -and (Test-Path -LiteralPath $configFile -PathType Leaf) -and ((Get-Content -LiteralPath $configFile -Raw -ErrorAction SilentlyContinue) -match '"secondbrain"')

                $results += [PSCustomObject]@{
                    Target = 'claude-code'
                    Name = 'Claude Code'
                    ConfigFile = $configFile
                    ConfigFormat = 'json'
                    Toml = $null
                    Snippet = $json
                    CliCommand = "claude mcp add --transport stdio --scope $effectiveScope secondbrain -- pwsh -NoProfile -File $quotedScript"
                    CliCommandUser = "claude mcp add --transport stdio --scope user secondbrain -- pwsh -NoProfile -File $quotedScript"
                    ServerDefinition = @{
                        command = 'pwsh'
                        args = @('-NoProfile', '-File', $serverScriptNormalized)
                    }
                    Configured = if($workspaceRoot){[bool]$projectConfigured}else{Test-SBClaudeCodeRegistration $userFile}
                    ProjectConfigured = [bool]$projectConfigured
                    UserConfigFile = $userFile
                    UserConfigured = Test-SBClaudeCodeRegistration $userFile
                }
            }
            'antigravity' {
                # Antigravity 2.0 shares configuration in ~/.gemini/config/mcp_config.json; earlier versions use ~/.gemini/antigravity/mcp_config.json. Prefer the new file when present.
                $agShared = Join-Path $env:USERPROFILE '.gemini/config/mcp_config.json'
                $agLegacy = Join-Path $env:USERPROFILE '.gemini/antigravity/mcp_config.json'
                $configFile = if($workspaceRoot){Join-Path $workspaceRoot '.agents/mcp_config.json'}elseif((Test-Path -LiteralPath $agLegacy -PathType Leaf) -and !(Test-Path -LiteralPath $agShared -PathType Leaf)){$agLegacy}else{$agShared}

                $snippetObj = [ordered]@{
                    mcpServers = [ordered]@{
                        secondbrain = [ordered]@{
                            command = 'pwsh'
                            args = @('-NoProfile', '-File', $serverScriptNormalized)
                        }
                    }
                }
                $json = ConvertTo-Json -InputObject $snippetObj -Depth 10

                $results += [PSCustomObject]@{
                    Target = 'antigravity'
                    Name = 'Google Antigravity'
                    ConfigFile = $configFile
                    ConfigFormat = 'json'
                    Toml = $null
                    Snippet = $json
                    CliCommand = $null
                    ServerDefinition = @{
                        command = 'pwsh'
                        args = @('-NoProfile', '-File', $serverScriptNormalized)
                    }
                    Configured = (Test-Path -LiteralPath $configFile -PathType Leaf) -and ((Get-Content -LiteralPath $configFile -Raw -ErrorAction SilentlyContinue) -match '"secondbrain"')
                }
            }
            'windsurf' {
                $windsurfRoot = Join-Path $env:USERPROFILE '.codeium/windsurf'
                $configFile = Join-Path $windsurfRoot 'mcp_config.json'

                $snippetObj = [ordered]@{
                    mcpServers = [ordered]@{
                        secondbrain = [ordered]@{
                            command = 'pwsh'
                            args = @('-NoProfile', '-File', $serverScriptNormalized)
                        }
                    }
                }
                $json = ConvertTo-Json -InputObject $snippetObj -Depth 10

                $results += [PSCustomObject]@{
                    Target = 'windsurf'
                    Name = 'Windsurf'
                    ConfigFile = $configFile
                    ConfigFormat = 'json'
                    Toml = $null
                    Snippet = $json
                    CliCommand = $null
                    ServerDefinition = @{
                        command = 'pwsh'
                        args = @('-NoProfile', '-File', $serverScriptNormalized)
                    }
                    Configured = (Test-Path -LiteralPath $configFile -PathType Leaf) -and ((Get-Content -LiteralPath $configFile -Raw -ErrorAction SilentlyContinue) -match '"secondbrain"')
                }
            }
        }
    }

    if($OverrideConfigFile -and $results.Count -ne 1){throw (New-SBError 'mcp.pair.scope' @('ConfigFile','all'))}
    foreach($result in $results){
        if($OverrideConfigFile){$result.ConfigFile=[IO.Path]::GetFullPath($OverrideConfigFile)}
        $result | Add-Member Scope $effectiveScope
        if($OverrideConfigFile){
            $result.Configured=if($result.Target -in @('codex','claude-code')){(Test-SBMcpNativeDefinition $result).matches}
                else{[IO.File]::Exists($result.ConfigFile) -and (Read-SBText $result.ConfigFile) -match '"secondbrain"'}
        }
        $plan=Get-SBMcpPermissionPlan $result -ApproveAllTools:$ApproveAllTools
        $result | Add-Member PermissionPlan $plan
        $result | Add-Member PermissionsStatus $plan.status
        $result | Add-Member -NotePropertyName PermissionsSnippet -NotePropertyValue $plan.snippet -Force
    }

    if ($Target.ToLowerInvariant() -ne 'all' -and $results.Length -eq 1) {
        return $results[0]
    }
    return $results
}

function Set-SBMcpConfiguration {
    [CmdletBinding()]
    param(
        [string]$BrainRoot,
        [ValidateSet('codex','claude','claude-code','cursor','vscode','antigravity','windsurf','all')][string]$Target='all',
        [string]$WorkspacePath,[string]$ConfigFile,[string]$BackupRoot,
        [ValidateSet('user','project')][string]$Scope,[Alias('ApproveKnowledgeTools')][switch]$ApproveReadTools,
        [switch]$ApproveAllTools,[scriptblock]$CliInvoker
    )
    if(!$BrainRoot){$BrainRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))}
    $backupDir=if($BackupRoot){$BackupRoot}else{Join-Path $BrainRoot '.runtime/backups/mcp-pairing'}
    if($ApproveReadTools -and $ApproveAllTools){throw (New-SBError 'mcp.pair.permissions.scope')}
    $approvePermissions=$ApproveReadTools -or $ApproveAllTools
    $options=@{BrainRoot=$BrainRoot;Target=$Target;WorkspacePath=$WorkspacePath;ApproveAllTools=$ApproveAllTools;ConfigFile=$ConfigFile}
    if($Scope){$options.Scope=$Scope}
    $pairings=@(Get-SBMcpPairing @options)
    if($ConfigFile -and $pairings.Count -ne 1){throw (New-SBError 'mcp.pair.scope' @('ConfigFile','all'))}
    $applied=@()
    foreach($pairing in $pairings){
        $targetFile=$pairing.ConfigFile;$expectedHash=Get-SBFileHash $targetFile
        $backupPath=$null;$action='unchanged';$cliResult=$null;$permissionAction='not-requested'
        # Preflight all files before native registration or any write; JSONC is refused intact.
        $data=if($pairing.Target -ne 'codex'){Read-SBMcpSettings $targetFile}else{$null}
        $permissionHash=if($approvePermissions -and $pairing.PermissionPlan.path){Get-SBFileHash $pairing.PermissionPlan.path}else{$null}
        $permissionContent=if($approvePermissions){Get-SBMcpPermissionContent $pairing}else{$null}
        $native=$pairing.Target -in @('codex','claude-code')
        if($native){
            $state=Test-SBMcpNativeDefinition $pairing;$present=$state.present;$matches=$state.matches
            if($present -and !$matches){$action='conflict'}
            elseif(!$matches){
                $command=if($pairing.Target -eq 'codex'){'codex'}else{'claude'}
                if(!$CliInvoker -and !(Get-Command $command -CommandType Application -ErrorAction SilentlyContinue)){$action='cli-unavailable'}
                else{
                    $backupPath=Save-SBMcpNativeSnapshot $targetFile $backupDir $expectedHash
                    $argsList=if($command -eq 'codex'){@('mcp','add','secondbrain','--','pwsh','-NoProfile','-File',$pairing.ServerDefinition.args[2])}else{@('mcp','add','--transport','stdio','--scope',$pairing.Scope,'secondbrain','--','pwsh','-NoProfile','-File',$pairing.ServerDefinition.args[2])}
                    $cliEnvironment=@{}
                    if($command -eq 'codex'){$cliEnvironment.CODEX_HOME=Split-Path $targetFile}
                    elseif($pairing.Scope -eq 'user' -and $ConfigFile -and !(Test-SBSamePath (Split-Path $targetFile) $env:USERPROFILE)){$cliEnvironment.CLAUDE_CONFIG_DIR=Split-Path $targetFile}
                    $workingDirectory=if($pairing.Scope -eq 'project'){$WorkspacePath}else{$BrainRoot}
                    if((Get-SBFileHash $targetFile) -ne $expectedHash){throw (New-SBError 'core.concurrent.modified' @($targetFile))}
                    $cliResult=if($CliInvoker){& $CliInvoker $command $argsList $workingDirectory $cliEnvironment $targetFile $pairing.ServerDefinition}else{Invoke-SBMcpNative $command $argsList $workingDirectory $cliEnvironment}
                    $action=$cliResult.status
                    if($action -eq 'applied' -and !(Test-SBMcpNativeDefinition $pairing).matches){$action='cli-unverified'}

                }
            }
        }else{
            $key=if($pairing.Target -eq 'vscode'){'servers'}else{'mcpServers'}
            if(!$data.ContainsKey($key)){$data[$key]=@{}}
            if($data[$key] -isnot [Collections.IDictionary]){throw (New-SBError 'mcp.pair.json' @($targetFile))}
            # Preserve extension fields on an existing server entry.
            if(!$data[$key].Contains('secondbrain')){$data[$key].secondbrain=@{}}
            if($data[$key].secondbrain -isnot [Collections.IDictionary]){throw (New-SBError 'mcp.pair.json' @($targetFile))}
            $data[$key].secondbrain.command='pwsh';$data[$key].secondbrain.args=@($pairing.ServerDefinition.args)
            if($pairing.Target -eq 'vscode'){$data[$key].secondbrain.type='stdio'}
            $written=Write-SBFile $targetFile ([Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $data))) $expectedHash $backupDir
            if($written){$action=if($expectedHash -eq 'absent'){'created'}else{'updated'}}
            if($written -and $expectedHash -ne 'absent'){
                $meta=Get-ChildItem -LiteralPath $backupDir -Filter '*.bin.json' -File|Sort-Object LastWriteTimeUtc -Descending|Where-Object {(Read-SBJson $_.FullName @{}).path -eq $targetFile}|Select-Object -First 1
                if($meta){$backupPath=$meta.FullName.Substring(0,$meta.FullName.Length-5)}
            }
        }
        if($approvePermissions){
            if($pairing.PermissionPlan.status -ne 'supported'){$permissionAction=$pairing.PermissionPlan.status}
            elseif($action -in @('created','updated','applied','unchanged')){
                # Native registration changes config.toml: recompute only after checking its new hash.
                if($pairing.Target -eq 'codex'){$permissionHash=Get-SBFileHash $targetFile;$permissionContent=Get-SBMcpPermissionContent $pairing}
                $changed=Write-SBFile $pairing.PermissionPlan.path ([Text.Encoding]::UTF8.GetBytes($permissionContent)) $permissionHash $backupDir
                $permissionAction=if($changed){'applied'}else{'unchanged'}
            }else{$permissionAction='skipped'}
        }
        if($native -and $backupPath){
            $meta=Read-SBJson ($backupPath+'.json') @{};$meta.deployedHash=Get-SBFileHash $targetFile;$meta.status=$action
            [void](Write-SBFile ($backupPath+'.json') ([Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $meta))) (Get-SBFileHash ($backupPath+'.json')) $backupDir)
        }
        $applied+=[pscustomobject]@{Target=$pairing.Target;Name=$pairing.Name;Scope=$pairing.Scope;ConfigFile=$targetFile;Action=$action;BackupFile=$backupPath;PermissionAction=$permissionAction;PermissionStatus=$pairing.PermissionPlan.status;ManualStep=$pairing.PermissionPlan.manualStep;ClientSessionVerified=$false;CliResult=$cliResult}
    }
    if($Target -ne 'all'){return $applied[0]}
    $applied
}
Export-ModuleMember -Function @(
    'Get-SBMcpPairing',
    'Get-SBMcpReadOnlyToolNames',
    'Get-SBMcpKnowledgeToolNames',
    'Set-SBMcpConfiguration'
)
