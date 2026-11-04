#requires -Version 7.5
# Direct entry point for the consolidated audit2 scenarios.
$ErrorActionPreference='Stop'
& (Join-Path $PSScriptRoot 'test-secondbrain.ps1') -Only 'audit2'
