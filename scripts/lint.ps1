#requires -Version 7.5
<#
.SYNOPSIS
Runs PSScriptAnalyzer on scripts/ and fails on findings not in the tracked baseline.
.DESCRIPTION
Uses config/PSScriptAnalyzerSettings.psd1. The baseline (config/lint-baseline.json) records the deferred
findings as rule + file + count, so edits that only move lines do not fail. New findings, or more findings
of a rule in a file, exit 1. Read-only: it writes nothing. -ExportBaseline prints the current findings as
baseline JSON on the output stream for a reviewed manual update of config/lint-baseline.json.
Requires the PSScriptAnalyzer module (1.25.0 or later).
#>
[CmdletBinding()]
param([switch]$ExportBaseline)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Add-SBMessages @{
    'lint.module.missing' = @{ it = 'Modulo PSScriptAnalyzer assente: Install-Module PSScriptAnalyzer -Scope CurrentUser'; en = 'PSScriptAnalyzer module missing: Install-Module PSScriptAnalyzer -Scope CurrentUser' }
    'lint.new'            = @{ it = 'Nuovi riscontri rispetto alla baseline: {0} {1} (baseline {2}, trovati {3})'; en = 'New findings over the baseline: {0} {1} (baseline {2}, found {3})' }
    'lint.ok'             = @{ it = 'Analisi statica conforme alla baseline ({0} riscontri differiti)'; en = 'Static analysis matches the baseline ({0} deferred findings)' }
    'lint.fixed'          = @{ it = 'Riscontri risolti: aggiornare la baseline con -ExportBaseline ({0} in meno)'; en = 'Findings resolved: refresh the baseline with -ExportBaseline ({0} fewer)' }
}
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (!(Get-Module -ListAvailable -Name PSScriptAnalyzer)) { throw (New-SBError 'lint.module.missing') }
$findings = Invoke-ScriptAnalyzer -Path (Join-Path $repo 'scripts') -Recurse -Settings (Join-Path $repo 'config/PSScriptAnalyzerSettings.psd1')
$current = @($findings | Group-Object { '{0}|{1}' -f $_.RuleName, [IO.Path]::GetRelativePath($repo, $_.ScriptPath).Replace('\', '/') } |
    Sort-Object Name | ForEach-Object {
        $rule, $file = $_.Name -split '\|', 2
        [ordered]@{ rule = $rule; file = $file; count = $_.Count }
    })
if ($ExportBaseline) {
    [ordered]@{ schemaVersion = 1; findings = $current } | ConvertTo-Json -Depth 4
    return
}
$baselinePath = Join-Path $repo 'config/lint-baseline.json'
$baseline = @{}
if (Test-Path -LiteralPath $baselinePath) {
    foreach ($entry in (Get-Content -LiteralPath $baselinePath -Raw | ConvertFrom-Json).findings) { $baseline["$($entry.rule)|$($entry.file)"] = [int]$entry.count }
}
$failed = $false
$known = 0
foreach ($entry in $current) {
    $allowed = [int]($baseline["$($entry.rule)|$($entry.file)"])
    if ($entry.count -gt $allowed) {
        $failed = $true
        [Console]::Error.WriteLine((Get-SBMessage 'lint.new' @($entry.rule, $entry.file, $allowed, $entry.count)))
    }
    $known += [Math]::Min($entry.count, $allowed)
}
$total = ($baseline.Values | Measure-Object -Sum).Sum
if ($total -gt $known -and !$failed) { Write-Output (Get-SBMessage 'lint.fixed' @(($total - $known))) }
if ($failed) { exit 1 }
Write-Output (Get-SBMessage 'lint.ok' @($known))
