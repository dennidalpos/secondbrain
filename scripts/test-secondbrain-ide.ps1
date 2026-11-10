#requires -Version 7.5
# IDE detection on a synthetic profile: known install paths, scopes, multi-select parsing, ide-detect.ps1 and the MCP tool list_ides.
# Environment variables of the process point at a fixture; the real profile is never read for the asserted evidence.
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Host.psm1') -Force
. (Join-Path $PSScriptRoot 'test-helpers.ps1')
$script:ideChecks=0
function Assert-Ide($Condition,[string]$Message){if(!$Condition){throw ('FAIL IDE: '+$Message)};$script:ideChecks++}
function Put-Ide([string]$Path){[IO.Directory]::CreateDirectory((Split-Path $Path))|Out-Null;[IO.File]::WriteAllText($Path,'x',[Text.UTF8Encoding]::new($false))}
$fixture=Join-Path (Get-SBTestRoot) ('ide-'+[guid]::NewGuid().ToString('N'))
$profileDir=Join-Path $fixture 'profile';$roaming=Join-Path $profileDir 'AppData/Roaming';$local=Join-Path $profileDir 'AppData/Local'
$programFiles=Join-Path $fixture 'ProgramFiles';$workspace=Join-Path $fixture 'workspace'
$saved=@{};foreach($name in @('USERPROFILE','APPDATA','LOCALAPPDATA','ProgramFiles','ProgramData','CLAUDE_CONFIG_DIR','CODEX_HOME')){$saved[$name]=[Environment]::GetEnvironmentVariable($name,'Process')}
try {
    Put-Ide (Join-Path $local 'Programs/cursor/Cursor.exe')
    Put-Ide (Join-Path $local 'Programs/Microsoft VS Code/Code.exe')
    Put-Ide (Join-Path $programFiles 'Android/Android Studio/bin/studio64.exe')
    [IO.Directory]::CreateDirectory((Join-Path $programFiles 'ClaudeCode'))|Out-Null
    [IO.Directory]::CreateDirectory($workspace)|Out-Null
    $env:USERPROFILE=$profileDir;$env:APPDATA=$roaming;$env:LOCALAPPDATA=$local;$env:ProgramFiles=$programFiles;$env:ProgramData=Join-Path $fixture 'ProgramData'
    foreach($name in @('CLAUDE_CONFIG_DIR','CODEX_HOME')){[Environment]::SetEnvironmentVariable($name,$null,'Process')}
    # Known paths
    Assert-Ide (@(Get-SBIDEKnownPaths 'Cursor').Count -eq 1) 'Cursor found by its per-user install path'
    Assert-Ide (@(Get-SBIDEKnownPaths 'VS Code').Count -eq 1) 'VS Code found by its per-user install path'
    Assert-Ide (@(Get-SBIDEKnownPaths 'Android Studio').Count -eq 1) 'Android Studio found under Program Files'
    Assert-Ide (@(Get-SBIDEKnownPaths 'Windsurf').Count -eq 0) 'absent IDE has no known path'
    # Scopes
    $vscode=@(Get-SBIDEScopes 'VS Code' $workspace)
    Assert-Ide (($vscode|Where-Object {$_.scope -eq 'project'}).available -and ($vscode|Where-Object {$_.scope -eq 'project'}).location -like '*.vscode*mcp.json') 'VS Code project scope with a workspace'
    Assert-Ide (!(@(Get-SBIDEScopes 'VS Code' '')|Where-Object {$_.scope -eq 'project'}).available) 'project scope needs a workspace'
    Assert-Ide ((@(Get-SBIDEScopes 'Codex' $workspace)|Where-Object {$_.scope -eq 'project'}).reason -eq 'unsupported') 'Codex is user-only'
    Assert-Ide ((@(Get-SBIDEScopes 'Claude Code' $workspace)|Where-Object {$_.scope -eq 'system'}).available) 'Claude Code system scope when the machine-wide folder exists'
    Assert-Ide (!(@(Get-SBIDEScopes 'Cursor' $workspace)|Where-Object {$_.scope -eq 'system'}).available) 'Cursor has no system scope'
    # Detection
    $detected=@(Get-SBIDEDetection $workspace)
    $cursor=@($detected|Where-Object {$_.name -eq 'Cursor'})
    Assert-Ide ($cursor.Count -eq 1 -and $cursor[0].confidence -eq 'high' -and @($cursor[0].evidence|Where-Object {$_ -like 'Path: *Cursor.exe'}).Count -eq 1) 'detection reports Cursor with high confidence and its evidence'
    Assert-Ide (@($detected|Where-Object {$_.confidence -eq 'none'}).Count -eq 0) 'entries without any evidence are not listed'
    Assert-Ide (@($detected|ForEach-Object {$_.name}|Select-Object -Unique).Count -eq $detected.Count) 'each IDE is listed once'
    # Multi-select parsing
    Assert-Ide ((Resolve-SBIDESelection '1, 3' 4) -join ',' -eq '1,3') 'selection by numbers'
    Assert-Ide ((Resolve-SBIDESelection 'all' 3) -join ',' -eq '1,2,3') 'selection of all'
    Assert-Ide ((Resolve-SBIDESelection 'tutti' 2) -join ',' -eq '1,2') 'selection of all (Italian)'
    Assert-Ide (@(Resolve-SBIDESelection '' 3).Count -eq 0) 'empty answer selects nothing'
    foreach($bad in @('0','9','x')){$failed=$false;try{[void](Resolve-SBIDESelection $bad 3)}catch{$failed=$true};Assert-Ide $failed "invalid choice rejected: $bad"}
    # CLI, non-interactive (child process inherits the fixture environment)
    $json=& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'ide-detect.ps1') -Ides 'cursor,VS Code' -Scope user 2>&1
    Assert-Ide ($LASTEXITCODE -eq 0) 'ide-detect.ps1 accepts a user-scope selection'
    $parsed=($json|Out-String)|ConvertFrom-Json
    Assert-Ide (@($parsed.selection).Count -eq 2 -and $parsed.selection[0].name -eq 'Cursor' -and $parsed.selection[1].scope -eq 'user') 'selection echoes names and scope'
    Assert-Ide ($parsed.selection[1].pairCommand -match '-Pair -Target vscode -Scope user$' -and $parsed.selection[1].pairCommand -notmatch '-Apply') 'selection carries a preview-only Pair command'
    $projectJson=(& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'ide-detect.ps1') -Ides 'Cursor' -Scope project -WorkspacePath $workspace 2>&1|Out-String)|ConvertFrom-Json
    Assert-Ide ($projectJson.selection[0].pairCommand -match '-Target cursor -Scope project -WorkspacePath') 'project scope Pair command carries the workspace'
    $null=& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'ide-detect.ps1') -Ides 'Codex' -Scope project 2>&1
    Assert-Ide ($LASTEXITCODE -eq 2) 'unavailable scope is an error'
    $null=& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'ide-detect.ps1') -Ides 'Cursor' 2>&1
    Assert-Ide ($LASTEXITCODE -eq 2) '-Ides without -Scope is an error'
    $all=(& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'ide-detect.ps1') -Json -WorkspacePath $workspace 2>&1|Out-String)|ConvertFrom-Json
    Assert-Ide (@($all.ides|Where-Object {$_.name -eq 'VS Code'}).Count -eq 1) '-Json lists the detected IDEs'
    # MCP tool
    Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Mcp.psm1') -Force
    $brainRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    $reply=(Invoke-SBMcpToolCall $brainRoot 'list_ides' @{workspacePath=$workspace})|ConvertFrom-Json
    Assert-Ide (@($reply.ides|Where-Object {$_.name -eq 'Cursor'}).Count -eq 1) 'MCP list_ides returns the detected IDEs'
    $failed=$false;try{[void](Invoke-SBMcpToolCall $brainRoot 'list_ides' @{workspacePath='relative/path'})}catch{$failed=$true}
    Assert-Ide $failed 'MCP list_ides rejects a relative workspace path'
    "SUCCESS IDE: $($script:ideChecks) verifiche"
} finally {
    foreach($name in $saved.Keys){[Environment]::SetEnvironmentVariable($name,$saved[$name],'Process')}
    if(Test-Path -LiteralPath $fixture){Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue}
}
