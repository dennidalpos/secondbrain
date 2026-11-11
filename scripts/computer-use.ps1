#requires -Version 7.5
<#
.SYNOPSIS
Computer use without a person present: capability table per IDE and the opt-in Codex pre-approval (Windows only).
.DESCRIPTION
-Table prints which IDEs can pre-approve computer use (read-only).
-CodexApps -AppId <id>[,<id>] previews adding the apps to `[computer_use.windows] always_allowed_app_ids` in the Codex config.toml; nothing is written.
Add -Apply -PreviewSha256 <hash from the preview> to write it (verified backup under .runtime/backups/computer-use). Entries are only added, never removed.
This pre-approves apps for unattended sessions: use only with the apps you accept to be opened without a prompt.
#>
[CmdletBinding(DefaultParameterSetName='Table')]
param([Parameter(Mandatory,ParameterSetName='Table')][switch]$Table,
    [Parameter(Mandatory,ParameterSetName='Codex')][switch]$CodexApps,
    [Parameter(Mandatory,ParameterSetName='Codex')][string[]]$AppId,
    [Parameter(ParameterSetName='Codex')][string]$CodexConfigPath,
    [Parameter(ParameterSetName='Codex')][switch]$Apply,
    [Parameter(ParameterSetName='Codex')][string]$PreviewSha256,
    [ValidateSet('en','it')][string]$Language)
if($Language){$env:SECONDBRAIN_LANG=$Language}
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.ComputerUse.psm1')
try{
    if($Table){ConvertTo-SBJson @{capabilities=@(Get-SBComputerUseCapabilities)};exit 0}
    $brain=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    ConvertTo-SBJson (Set-SBCodexComputerUseApps -BrainRoot $brain -AppIds $AppId -ConfigPath $CodexConfigPath -Apply:$Apply -PreviewSha256 $PreviewSha256)
    exit 0
}catch{
    Write-Error $_ -ErrorAction Continue
    exit 2
}
