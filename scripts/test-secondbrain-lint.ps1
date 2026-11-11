#requires -Version 7.5
# Static analysis gate: scripts/lint.ps1 must match config/lint-baseline.json (no new PSScriptAnalyzer findings).
$ErrorActionPreference='Stop'
if(!(Get-Module -ListAvailable -Name PSScriptAnalyzer)){
    Write-Output 'INFO LINT: modulo PSScriptAnalyzer assente, analisi saltata'
    Write-Output 'SUCCESS LINT: 0 verifiche (PSScriptAnalyzer non installato)'
    return
}
$output=@(& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'lint.ps1') 2>&1|ForEach-Object {[string]$_})
if($LASTEXITCODE -ne 0){
    $output|Write-Output
    throw 'FAIL LINT: lint.ps1 ha riportato nuovi riscontri rispetto alla baseline'
}
$output|Write-Output
Write-Output 'SUCCESS LINT: analisi statica conforme alla baseline'
