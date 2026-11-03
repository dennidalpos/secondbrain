#requires -Version 7.5
<#
.SYNOPSIS
Handshake stdio reale del server MCP di SecondBrain per le configurazioni dei 6 IDE.
Per ogni IDE avvia il comando registrato (stesso command/args scritti da -Pair) e verifica initialize, tools/list (8 strumenti),
tools/call di ciascuno strumento, prompts/list, resources/list e resources/read. La prova visiva nelle GUI degli IDE non e coperta.
.EXAMPLE
pwsh -NoProfile -File scripts/test-secondbrain-mcp-handshake.ps1
pwsh -NoProfile -File scripts/test-secondbrain-mcp-handshake.ps1 -Target codex,vscode -ReportPath .runtime/mcp-handshake/live.json
#>
[CmdletBinding()]
param(
    [string]$BrainRoot,
    [string]$Target = 'all',
    [string]$PublicationPath,
    [string]$ReportPath,
    [int]$TimeoutSeconds = 300
)
$env:SECONDBRAIN_LANG='it'
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Mcp.psm1') -Force
if (!$BrainRoot) { $BrainRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')) }
$BrainRoot = [IO.Path]::GetFullPath($BrainRoot)
if (!$PublicationPath) { $PublicationPath = $BrainRoot }
$expectedTools = @('check_publication','get_prompt','get_prompt_home','get_ready_tasks','get_startup_context','get_task','list_prompts','search_knowledge')

$failures = 0
function Assert-Handshake([bool]$Condition, [string]$Name, [string]$Ide) {
    if ($Condition) { Write-Host ("PASS MCP[{0}]: {1}" -f $Ide, $Name) }
    else { Write-Host ("FAIL MCP[{0}]: {1}" -f $Ide, $Name); $script:failures++ }
    [ordered]@{ ide = $Ide; check = $Name; passed = $Condition }
}

# Dossier di esempio (relativo) per get_startup_context: il primo con context.md; assente = strumento verificato come saltato.
$dossierRelative = $null
$productsRoot = Join-Path $BrainRoot '02-areas/products'
if (Test-Path -LiteralPath $productsRoot -PathType Container) {
    $first = Get-ChildItem -LiteralPath $productsRoot -Directory | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'context.md') } | Sort-Object Name | Select-Object -First 1
    if ($first) { $dossierRelative = '02-areas/products/' + $first.Name }
}
$isGit = (Invoke-SBGit $PublicationPath @('rev-parse','--is-inside-work-tree')).output -eq 'true'

$requests = [System.Collections.Generic.List[hashtable]]::new()
$next = 1
function Add-Request([string]$Method, $Params) { $script:requests.Add(@{ jsonrpc = '2.0'; id = $script:next; method = $Method; params = $Params }); $script:next++ }
Add-Request 'initialize' @{ protocolVersion = '2024-11-05'; capabilities = @{}; clientInfo = @{ name = 'secondbrain-handshake'; version = '1' } }
Add-Request 'tools/list' @{}
$calls = [ordered]@{}
if ($dossierRelative) { $calls['get_startup_context'] = @{ dossier = $dossierRelative; budget = 20000 } }
$calls['get_ready_tasks'] = @{ all = $true }
# get_task: primo task del tracker del dossier di esempio (assente = strumento verificato come saltato).
if ($dossierRelative) {
    $sampleTracker = Read-SBJson (Join-Path $BrainRoot ($dossierRelative + '/tracker.json')) $null
    if ($sampleTracker -and $sampleTracker.ContainsKey('tasks') -and @($sampleTracker.tasks).Count) { $calls['get_task'] = @{ dossier = $dossierRelative; task = [string]@($sampleTracker.tasks)[0].id } }
}
$calls['search_knowledge'] = @{ query = 'SecondBrain'; budget = 20000 }
$calls['list_prompts'] = @{}
$calls['get_prompt'] = @{ prompt = 'SYS03' }
$calls['get_prompt_home'] = @{}
if ($isGit) { $calls['check_publication'] = @{ repositoryPath = $PublicationPath } }
$callIds = @{}
foreach ($name in $calls.Keys) { $callIds[$name] = $next; Add-Request 'tools/call' @{ name = $name; arguments = $calls[$name] } }
Add-Request 'prompts/list' @{}
Add-Request 'resources/list' @{}
Add-Request 'resources/read' @{ uri = 'secondbrain://prompts/catalog' }

$targets = @($Target -split ',' | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ })
$validTargets = @('codex','claude','claude-code','cursor','vscode','antigravity','windsurf','all')
if (!$targets.Count -or @($targets | Where-Object { $_ -notin $validTargets }).Count) { throw ('Target non valido: usare ' + ($validTargets -join ', ') + ' (separati da virgola)') }
$pairings = @(@(Get-SBMcpPairing -BrainRoot $BrainRoot -Target 'all') + @(Get-SBMcpPairing -BrainRoot $BrainRoot -Target 'claude-code') | Where-Object { $targets -contains 'all' -or $_.Target -in $targets })
$report = [ordered]@{ schemaVersion = 1; generatedAt = [DateTimeOffset]::UtcNow.ToString('o'); brainRoot = $BrainRoot; guiVerified = $false; note = 'Handshake stdio con il comando registrato per ogni IDE; la visualizzazione degli strumenti nelle GUI non e verificata.'
    skippedTools = @(@($expectedTools | Where-Object { $_ -notin $calls.Keys })); ides = @(); checks = @() }

foreach ($pairing in $pairings) {
    $ide = [string]$pairing.Target
    $definition = $pairing.ServerDefinition
    $start = [Diagnostics.ProcessStartInfo]::new([string]$definition.command)
    foreach ($argument in @($definition.args)) { $start.ArgumentList.Add([string]$argument) }
    $start.UseShellExecute = $false; $start.CreateNoWindow = $true
    $start.RedirectStandardInput = $true; $start.RedirectStandardOutput = $true; $start.RedirectStandardError = $true
    $start.StandardInputEncoding = [Text.UTF8Encoding]::new($false); $start.StandardOutputEncoding = [Text.UTF8Encoding]::new($false)
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $process = [Diagnostics.Process]::Start($start)
    $exit = -1; $responses = @{}; $stderrText = ''
    try {
        $stdout = $process.StandardOutput.ReadToEndAsync(); $stderr = $process.StandardError.ReadToEndAsync()
        foreach ($request in $requests) { $process.StandardInput.WriteLine((ConvertTo-Json $request -Depth 10 -Compress)) }
        $process.StandardInput.Flush(); $process.StandardInput.Close()
        if (!$process.WaitForExit($TimeoutSeconds * 1000)) { $process.Kill($true); throw "Timeout dopo $TimeoutSeconds s" }
        $exit = $process.ExitCode
        foreach ($line in ($stdout.GetAwaiter().GetResult() -split "`n")) {
            $line = $line.Trim(); if (!$line) { continue }
            try { $message = ConvertFrom-Json -InputObject $line -AsHashtable; if ($message.ContainsKey('id')) { $responses[[int]$message.id] = $message } } catch { }
        }
        $stderrText = $stderr.GetAwaiter().GetResult().Trim()
    } finally { if (!$process.HasExited) { try { $process.Kill($true) } catch { } }; $process.Dispose() }
    $watch.Stop()
    $checks = @()
    $checks += Assert-Handshake ($exit -eq 0) 'processo terminato con exit 0 alla chiusura di stdin' $ide
    $checks += Assert-Handshake ($responses.Count -eq $requests.Count) ("tutte le {0} richieste hanno una risposta" -f $requests.Count) $ide
    $init = $responses[1]
    $checks += Assert-Handshake ($init -and $init.ContainsKey('result') -and $init.result.serverInfo.name -eq 'secondbrain-mcp') 'initialize: serverInfo secondbrain-mcp' $ide
    $list = $responses[2]
    $names = if ($list -and $list.ContainsKey('result')) { @($list.result.tools | ForEach-Object { $_.name } | Sort-Object) } else { @() }
    $checks += Assert-Handshake (($names -join ',') -eq ($expectedTools -join ',')) 'tools/list: esattamente gli 8 strumenti attesi' $ide
    foreach ($name in $calls.Keys) {
        $response = $responses[[int]$callIds[$name]]
        $ok = $response -and $response.ContainsKey('result') -and $response.result.isError -eq $false -and @($response.result.content).Count -ge 1 -and [string]@($response.result.content)[0].text
        $checks += Assert-Handshake ([bool]$ok) ("tools/call {0}: risposta senza errore" -f $name) $ide
    }
    $promptsId = $requests | Where-Object { $_.method -eq 'prompts/list' } | ForEach-Object { $_.id }
    $resourcesId = $requests | Where-Object { $_.method -eq 'resources/list' } | ForEach-Object { $_.id }
    $readId = $requests | Where-Object { $_.method -eq 'resources/read' } | ForEach-Object { $_.id }
    $checks += Assert-Handshake ($responses[[int]$promptsId].result.prompts.Count -ge 1) 'prompts/list: catalogo non vuoto' $ide
    $checks += Assert-Handshake (@($responses[[int]$resourcesId].result.resources | Where-Object { $_.uri -eq 'secondbrain://prompts/catalog' }).Count -eq 1) 'resources/list: catalogo prompt esposto' $ide
    $checks += Assert-Handshake ([bool]$responses[[int]$readId].result.contents[0].text) 'resources/read: catalogo leggibile' $ide
    $report.ides += [ordered]@{ ide = $ide; configFile = [string]$pairing.ConfigFile; registeredInIde = [bool]$pairing.Configured; command = [string]$definition.command; args = @($definition.args); exitCode = $exit; seconds = [math]::Round($watch.Elapsed.TotalSeconds, 1); stderrLength = $stderrText.Length }
    $report.checks += $checks
}
$report.failures = $failures
if (!$ReportPath) { $ReportPath = Join-Path $BrainRoot ('.runtime/mcp-handshake/handshake-' + [DateTimeOffset]::UtcNow.ToString('yyyyMMddTHHmmss') + '.json') }
$ReportPath = Assert-SBCentralDataPath $BrainRoot $ReportPath
[IO.Directory]::CreateDirectory((Split-Path $ReportPath)) | Out-Null
[IO.File]::WriteAllText($ReportPath, (ConvertTo-Json $report -Depth 8), [Text.UTF8Encoding]::new($false))
Write-Host ("{0} MCP-HANDSHAKE: {1} IDE, {2} verifiche, {3} fallite; rapporto: {4}" -f $(if ($failures) { 'FAILURE' } else { 'SUCCESS' }), $report.ides.Count, $report.checks.Count, $failures, $ReportPath)
if ($failures) { exit 1 }
