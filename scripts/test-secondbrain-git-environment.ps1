#requires -Version 7.5
# Direct entry point for the consolidated git-environment scenarios.
$ErrorActionPreference='Stop'
& (Join-Path $PSScriptRoot 'test-secondbrain.ps1') -Only 'git-environment'
