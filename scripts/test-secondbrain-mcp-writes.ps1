#requires -Version 7.5
# Extended synthetic MCP write coverage; Full runs this suite as a separate process.
$ErrorActionPreference='Stop'
& (Join-Path $PSScriptRoot 'test-secondbrain-essential.ps1') -Groups @('mcp-writes')