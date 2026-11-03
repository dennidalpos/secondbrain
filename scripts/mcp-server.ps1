#requires -Version 7.5
<#
.SYNOPSIS
Server MCP (Model Context Protocol) stdio locale in sola lettura per SecondBrain.
Espone contesto di avvio, task pronti (-ReadyOnly), dettaglio integro di un task (get_task), ricerca trasversale paginata, catalogo prompt e verifica di pubblicabilità (REP05) agli IDE conformi.
Supporta l'accoppiamento con tutti i principali IDE (-Pair -Target <ide> o -Target all) e la generazione di pacchetti di configurazione (-ExportPackage).

.EXAMPLE
pwsh -NoProfile -File scripts/mcp-server.ps1
pwsh -NoProfile -File scripts/mcp-server.ps1 -Pair -Target codex
pwsh -NoProfile -File scripts/mcp-server.ps1 -Pair -Target all -Apply
pwsh -NoProfile -File scripts/mcp-server.ps1 -ExportPackage -OutDir .runtime/mcp-package
#>
[CmdletBinding(DefaultParameterSetName = 'Server')]
param(
    [Parameter(ParameterSetName = 'Server')]
    [string]$BrainRoot,

    [Parameter(ParameterSetName = 'Server')]
    [string]$ConfigPath,

    [Parameter(Mandatory, ParameterSetName = 'Pair')]
    [switch]$Pair,

    [Parameter(ParameterSetName = 'Pair')]
    [ValidateSet('codex', 'claude', 'cursor', 'vscode', 'antigravity', 'windsurf', 'all')][string]$Target = 'all',

    [Parameter(ParameterSetName = 'Pair')]
    [switch]$Apply,

    [Parameter(Mandatory, ParameterSetName = 'ExportPackage')]
    [switch]$ExportPackage,

    [Parameter(ParameterSetName = 'ExportPackage')]
    [string]$OutDir
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Mcp.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1')
# Scrittura occupata oltre l'attesa: exit 3 (il titolare e nel messaggio).
trap { if (Test-SBBusyError $_) { [Console]::Error.WriteLine($_.Exception.Message); exit 3 }; break }

if (!$BrainRoot) {
    $BrainRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
}

if ($ExportPackage) {
    $pkg = New-SBMcpPackage -BrainRoot $BrainRoot -OutDir $OutDir
    Write-Host "=== Pacchetto MCP SecondBrain esportato ===" -ForegroundColor Green
    Write-Host "Cartella destinazione: $($pkg.PackageDir)"
    Write-Host "File generati ($($pkg.FileCount)):"
    foreach ($f in $pkg.Files) {
        Write-Host "  • $f"
    }
    return $pkg
}

if ($Pair) {
    if ($Apply) {
        # Le configurazioni degli IDE sono scritte fuori dal cervello: stessa coda FIFO e lock di ogni writer, anche a postazione non attivata.
        $pairLock = Enter-SBOperation @{coordinationRoot=(Join-Path $BrainRoot '.runtime/access');brainRoot=$BrainRoot;workstationId='non-attivata'} -LockOnly
        try { $applied = Set-SBMcpConfiguration -BrainRoot $BrainRoot -Target $Target } finally { Exit-SBOperation $pairLock }
        Write-Host "=== Configurazione MCP SecondBrain applicata ===" -ForegroundColor Green
        $items = if ($applied -is [array]) { $applied } else { @($applied) }
        foreach ($item in $items) {
            Write-Host "`n[$($item.Target.ToUpper())] $($item.Name)" -ForegroundColor Cyan
            Write-Host "  • File: $($item.ConfigFile)"
            Write-Host "  • Esito: $($item.Action)"
            if ($item.BackupFile) {
                Write-Host "  • Backup preventivo: $($item.BackupFile)" -ForegroundColor Yellow
            }
        }
        return $applied
    }

    $info = Get-SBMcpPairing -BrainRoot $BrainRoot -Target $Target
    $items = if ($info -is [array]) { $info } else { @($info) }
    foreach ($item in $items) {
        $hasSplit = $item.PSObject.Properties['CodeConfigured'] -and $item.PSObject.Properties['DesktopConfigured']
        # Claude: Desktop e Code hanno file e stato distinti (la scrittura -Apply riguarda solo claude_desktop_config.json).
        $configured = if ($hasSplit) { [bool]$item.DesktopConfigured -and [bool]$item.CodeConfigured } else { [bool]$item.Configured }
        $statusStr = if ($hasSplit) {
            '[Desktop: ' + $(if ($item.DesktopConfigured) { 'CONFIGURATO' } else { 'DA CONFIGURARE' }) + ' | Code: ' + $(if ($item.CodeConfigured) { 'CONFIGURATO' } else { 'DA CONFIGURARE' }) + ']'
        } elseif ($item.Configured) { "[CONFIGURATO]" } else { "[DA CONFIGURARE]" }
        $color = if ($configured) { "Green" } else { "Yellow" }
        Write-Host "`n=== Accoppiamento MCP SecondBrain per $($item.Name) $statusStr ===" -ForegroundColor $color
        Write-Host "Config file: $($item.ConfigFile)"
        if ($hasSplit) { Write-Host "Claude Code (sola lettura): $($item.CodeConfigFile)" }
        Write-Host "`n--- Configurazione $($item.ConfigFormat.ToUpper()) da inserire ---"
        Write-Host $item.Snippet
        if ($item.PSObject.Properties['PermissionsSnippet'] -and $item.PermissionsSnippet) {
            Write-Host "`n--- Permessi opzionali (settings.json di Claude Code): evitano i popup per i soli strumenti di lettura ---"
            Write-Host $item.PermissionsSnippet
        }
        if ($item.CliCommand) {
            Write-Host "`n--- Comando CLI equivalente ---"
            Write-Host $item.CliCommand
        }
    }
    return $info
}

Start-SBMcpServer -BrainRoot $BrainRoot -ConfigPath $ConfigPath
