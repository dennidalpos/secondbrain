#requires -Version 7.5
<#
.SYNOPSIS
Read-only status of the first-run setup and of the optional features that can be enabled.
.DESCRIPTION
Prints JSON: whether the workstation is activated, the detected IDEs, usage counts from the optional Trace files
(counts only, never contents) and one entry per feature with its state (enabled, available, unsupported, blocked),
evidence, the preview command that would enable it, prerequisites, risk and a recommendation with its reason.
Nothing is written, locked or enabled. Exit: 0 nothing recommended, 1 recommendations or not activated, 2 error.
#>
[CmdletBinding()]
param([string]$WorkspacePath,[string]$SettingsPath)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.SetupStatus.psm1') -Force
try{
    $brain=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    $status=Get-SBSetupWizardStatus -BrainRoot $brain -WorkspacePath $WorkspacePath -SettingsPath $SettingsPath
    ConvertTo-SBJson $status
    if(!$status.activated -or $status.recommended.Count){exit 1};exit 0
}catch{
    Write-Error $_ -ErrorAction Continue
    exit 2
}
