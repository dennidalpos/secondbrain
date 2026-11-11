#requires -Version 7.5
<#
.SYNOPSIS
Computer use without a person present: capability table per IDE and the opt-in Codex pre-approval (Windows only).
.DESCRIPTION
-Table prints which IDEs can pre-approve computer use (read-only).
-CodexApps -AppId <id>[,<id>] previews adding the apps to `[computer_use.windows] always_allowed_app_ids` in the Codex config.toml; nothing is written. The preview prints the exact apply command.
Add -Apply -PreviewSha256 <hash from the preview> to write it (verified backup under .runtime/backups/computer-use). Entries are only added, never removed.
This pre-approves apps for unattended sessions: use only with the apps you accept to be opened without a prompt.
Without arguments the script lists the available modes and exits with 2.
#>
[CmdletBinding()]
param([switch]$Table,
    [switch]$CodexApps,
    [string[]]$AppId,
    [string]$CodexConfigPath,
    [switch]$Apply,
    [string]$PreviewSha256,
    [ValidateSet('en','it')][string]$Language)
if($Language){$env:SECONDBRAIN_LANG=$Language}
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.ComputerUse.psm1')
try{
    if($Table){ConvertTo-SBJson @{capabilities=@(Get-SBComputerUseCapabilities|ForEach-Object {$_})};exit 0}
    if(!$CodexApps){throw (New-SBError 'computeruse.usage')}
    if(!@($AppId|Where-Object {$_}).Count){throw (New-SBError 'computeruse.appid.required')}
    $brain=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    ConvertTo-SBJson (Set-SBCodexComputerUseApps -BrainRoot $brain -AppIds $AppId -ConfigPath $CodexConfigPath -Apply:$Apply -PreviewSha256 $PreviewSha256)
    exit 0
}catch{
    Write-Error $_ -ErrorAction Continue
    exit 2
}
