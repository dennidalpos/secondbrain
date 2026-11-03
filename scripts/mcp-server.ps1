#requires -Version 7.5
<#
.SYNOPSIS
Server MCP (Model Context Protocol) stdio locale in sola lettura per SecondBrain.
Espone contesto di avvio, task pronti (-ReadyOnly), dettaglio integro di un task (get_task), ricerca trasversale paginata, catalogo prompt e verifica di pubblicabilità (SEC07) agli IDE conformi.
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
    [ValidateSet('codex', 'claude', 'claude-code', 'cursor', 'vscode', 'antigravity', 'windsurf', 'all')][string]$Target = 'all',

    [Parameter(ParameterSetName = 'Pair')]
    [string]$WorkspacePath,

    [Parameter(ParameterSetName = 'Pair')]
    [switch]$Apply,

    [Parameter(Mandatory, ParameterSetName = 'ExportPackage')]
    [switch]$ExportPackage,

    [Parameter(ParameterSetName = 'ExportPackage')]
    [string]$OutDir,

    [ValidateSet('en', 'it')][string]$Language
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Mcp.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
if ($Language) { $env:SECONDBRAIN_LANG = $Language }
Add-SBMessages @{
    'mcpcli.package.exported' = @{ it = '=== Pacchetto MCP SecondBrain esportato ==='; en = '=== SecondBrain MCP package exported ===' }
    'mcpcli.package.folder' = @{ it = 'Cartella destinazione: {0}'; en = 'Destination folder: {0}' }
    'mcpcli.package.files' = @{ it = 'File generati ({0}):'; en = 'Generated files ({0}):' }
    'mcpcli.apply.done' = @{ it = '=== Configurazione MCP SecondBrain applicata ==='; en = '=== SecondBrain MCP configuration applied ===' }
    'mcpcli.apply.file' = @{ it = '  • File: {0}'; en = '  • File: {0}' }
    'mcpcli.apply.outcome' = @{ it = '  • Esito: {0}'; en = '  • Outcome: {0}' }
    'mcpcli.apply.backup' = @{ it = '  • Backup preventivo: {0}'; en = '  • Backup taken before the change: {0}' }
    'mcpcli.pair.configured' = @{ it = 'CONFIGURATO'; en = 'CONFIGURED' }
    'mcpcli.pair.todo' = @{ it = 'DA CONFIGURARE'; en = 'TO CONFIGURE' }
    'mcpcli.pair.header' = @{ it = '=== Accoppiamento MCP SecondBrain per {0} {1} ==='; en = '=== SecondBrain MCP pairing for {0} {1} ===' }
    'mcpcli.pair.configfile' = @{ it = 'Config file: {0}'; en = 'Config file: {0}' }
    'mcpcli.pair.codefile' = @{ it = 'Claude Code (sola lettura): {0}'; en = 'Claude Code (read-only): {0}' }
    'mcpcli.pair.snippet' = @{ it = '--- Configurazione {0} da inserire ---'; en = '--- {0} configuration to insert ---' }
    'mcpcli.pair.permissions' = @{ it = '--- Permessi opzionali (settings.json di Claude Code): evitano i popup per i soli strumenti di lettura ---'; en = '--- Optional permissions (Claude Code settings.json): avoid the pop-ups for the read-only tools ---' }
    'mcpcli.pair.cli' = @{ it = '--- Comando CLI equivalente ---'; en = '--- Equivalent CLI command ---' }
    'mcpcli.pair.cliuser' = @{ it = "--- Comando CLI per l'ambito utente (tutti i progetti) ---"; en = '--- CLI command for the user scope (all projects) ---' }
}
# Scrittura occupata oltre l'attesa: exit 3 (il titolare e nel messaggio).
trap { if (Test-SBBusyError $_) { [Console]::Error.WriteLine($_.Exception.Message); exit 3 }; break }

if (!$BrainRoot) {
    $BrainRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
}

if ($ExportPackage) {
    $pkg = New-SBMcpPackage -BrainRoot $BrainRoot -OutDir $OutDir
    Write-Host (Get-SBMessage 'mcpcli.package.exported') -ForegroundColor Green
    Write-Host (Get-SBMessage 'mcpcli.package.folder' @($pkg.PackageDir))
    Write-Host (Get-SBMessage 'mcpcli.package.files' @($pkg.FileCount))
    foreach ($f in $pkg.Files) {
        Write-Host "  • $f"
    }
    return $pkg
}

if ($Pair) {
    if ($Apply) {
        # Le configurazioni degli IDE sono scritte fuori dal cervello: stessa coda FIFO e lock di ogni writer, anche a postazione non attivata.
        $pairLock = Enter-SBOperation @{coordinationRoot=(Join-Path $BrainRoot '.runtime/access');brainRoot=$BrainRoot;workstationId='non-attivata'} -LockOnly
        try { $applied = Set-SBMcpConfiguration -BrainRoot $BrainRoot -Target $Target -WorkspacePath $WorkspacePath } finally { Exit-SBOperation $pairLock }
        Write-Host (Get-SBMessage 'mcpcli.apply.done') -ForegroundColor Green
        $items = if ($applied -is [array]) { $applied } else { @($applied) }
        foreach ($item in $items) {
            Write-Host "`n[$($item.Target.ToUpper())] $($item.Name)" -ForegroundColor Cyan
            Write-Host (Get-SBMessage 'mcpcli.apply.file' @($item.ConfigFile))
            Write-Host (Get-SBMessage 'mcpcli.apply.outcome' @($item.Action))
            if ($item.BackupFile) {
                Write-Host (Get-SBMessage 'mcpcli.apply.backup' @($item.BackupFile)) -ForegroundColor Yellow
            }
        }
        return $applied
    }

    $info = Get-SBMcpPairing -BrainRoot $BrainRoot -Target $Target -WorkspacePath $WorkspacePath
    $items = if ($info -is [array]) { $info } else { @($info) }
    foreach ($item in $items) {
        $hasSplit = $item.PSObject.Properties['CodeConfigured'] -and $item.PSObject.Properties['DesktopConfigured']
        # Claude: Desktop e Code hanno file e stato distinti (la scrittura -Apply riguarda solo claude_desktop_config.json).
        $configured = if ($hasSplit) { [bool]$item.DesktopConfigured -and [bool]$item.CodeConfigured } else { [bool]$item.Configured }
        $okText = Get-SBMessage 'mcpcli.pair.configured'
        $todoText = Get-SBMessage 'mcpcli.pair.todo'
        $statusStr = if ($hasSplit) {
            '[Desktop: ' + $(if ($item.DesktopConfigured) { $okText } else { $todoText }) + ' | Code: ' + $(if ($item.CodeConfigured) { $okText } else { $todoText }) + ']'
        } elseif ($item.Configured) { "[$okText]" } else { "[$todoText]" }
        $color = if ($configured) { "Green" } else { "Yellow" }
        Write-Host ("`n" + (Get-SBMessage 'mcpcli.pair.header' @($item.Name, $statusStr))) -ForegroundColor $color
        Write-Host (Get-SBMessage 'mcpcli.pair.configfile' @($item.ConfigFile))
        if ($hasSplit) { Write-Host (Get-SBMessage 'mcpcli.pair.codefile' @($item.CodeConfigFile)) }
        Write-Host ("`n" + (Get-SBMessage 'mcpcli.pair.snippet' @($item.ConfigFormat.ToUpper())))
        Write-Host $item.Snippet
        if ($item.PSObject.Properties['PermissionsSnippet'] -and $item.PermissionsSnippet) {
            Write-Host ("`n" + (Get-SBMessage 'mcpcli.pair.permissions'))
            Write-Host $item.PermissionsSnippet
        }
        if ($item.CliCommand) {
            Write-Host ("`n" + (Get-SBMessage 'mcpcli.pair.cli'))
            Write-Host $item.CliCommand
        }
        if ($item.PSObject.Properties['CliCommandUser'] -and $item.CliCommandUser) {
            Write-Host ("`n" + (Get-SBMessage 'mcpcli.pair.cliuser'))
            Write-Host $item.CliCommandUser
        }
    }
    return $info
}

Start-SBMcpServer -BrainRoot $BrainRoot -ConfigPath $ConfigPath
