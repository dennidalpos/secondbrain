#requires -Version 7.5
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.McpConfig.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Add-SBMessages @{
    'mcp.package.destination' = @{it='Scegliere una cartella nuova sotto .runtime: {0}';en='Choose a new folder under .runtime: {0}'}
    'mcp.package.root' = @{ it = 'Impossibile trovare scripts/mcp-server.ps1 nella radice SecondBrain: {0}'; en = 'Cannot find scripts/mcp-server.ps1 in SecondBrain root: {0}' }
    'mcp.package.applying' = @{ it = 'Applicazione configurazione MCP SecondBrain a tutti gli IDE...'; en = 'Applying SecondBrain MCP configuration to all IDEs...' }
}

function ConvertTo-SBMcpJson($Value) {
    if ($null -eq $Value) { return $null }
    ConvertTo-SBStableValue $Value | ConvertTo-Json -Depth 40 -Compress
}

function New-SBMcpDesktopBundle {
    $manifest = ConvertTo-SBMcpJson @{
        manifest_version='0.3';name='secondbrain';version=(Read-SBText (Join-Path $PSScriptRoot '../VERSION')).Trim()
        description='Launch the local SecondBrain MCP server';author=@{name='SecondBrain contributors'}
        compatibility=@{platforms=@('win32')}
        user_config=@{clone=@{type='directory';title='SecondBrain checkout';description='Select the local SecondBrain clone';required=$true}}
        server=@{type='node';entry_point='launcher.cjs';mcp_config=@{
            command='node';args=@('${__dirname}/launcher.cjs','${user_config.clone}')
        }}
        tools_generated=$true
    }
    $launcher = @'
const { spawn } = require('node:child_process');
const { join } = require('node:path');

const checkout = process.argv[2];
if (!checkout) {
  console.error('Select the SecondBrain checkout in the extension settings.');
  process.exitCode = 1;
} else {
  const server = spawn('pwsh', ['-NoProfile', '-File', join(checkout, 'scripts', 'mcp-server.ps1')], {
    stdio: 'inherit',
    windowsHide: true,
  });
  server.on('error', (error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
  server.on('exit', (code) => { process.exitCode = code ?? 1; });
}
'@
    $buffer = [IO.MemoryStream]::new()
    try {
        $archive = [IO.Compression.ZipArchive]::new($buffer,[IO.Compression.ZipArchiveMode]::Create,$true)
        try {
            foreach ($entry in @{ 'manifest.json'=$manifest; 'launcher.cjs'=$launcher }.GetEnumerator()) {
                $writer = [IO.StreamWriter]::new($archive.CreateEntry($entry.Key).Open(),[Text.UTF8Encoding]::new($false))
                try { $writer.Write($entry.Value) } finally { $writer.Dispose() }
            }
        } finally { $archive.Dispose() }
        return ,$buffer.ToArray()
    } finally { $buffer.Dispose() }
}

function New-SBMcpPackage {
    [CmdletBinding()]
    param(
        [string]$BrainRoot,
        [string]$OutDir
    )
    if (!$BrainRoot) {
        $BrainRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    }
    $BrainRoot = [IO.Path]::GetFullPath($BrainRoot)
    if (!$OutDir) {
        $OutDir = Join-Path $BrainRoot '.runtime/mcp-package'
    }
    $runtime = Join-Path $BrainRoot '.runtime'
    $OutDir = [IO.Path]::GetFullPath($OutDir).TrimEnd([char[]]@('/', '\'))
    $relative = [IO.Path]::GetRelativePath($runtime,$OutDir)
    if ($relative -in '.','..' -or $relative.StartsWith('..'+[IO.Path]::DirectorySeparatorChar) -or
        [IO.Path]::IsPathRooted($relative) -or $relative -match '[:]|[. ](?:[\\/]|$)') {
        throw (New-SBError 'mcp.package.destination' @($OutDir))
    }
    Assert-SBPlainPath $OutDir
    if (Test-Path -LiteralPath $OutDir) { throw (New-SBError 'mcp.package.destination' @($OutDir)) }

    $files = [ordered]@{}
    foreach ($pairing in Get-SBMcpPairing -BrainRoot $BrainRoot -Target all) {
        $name = switch ($pairing.Target) {
            'codex' { 'config.toml' }
            'claude' { 'claude_desktop_config.json' }
            'claude-code' { 'user-registration.json' }
            { $_ -in 'cursor','vscode' } { 'mcp.json' }
            default { 'mcp_config.json' }
        }
        $files["$($pairing.Target)/$name"] = $pairing.Snippet + "`n"
        if ($pairing.PermissionsSnippet) {
            $extension = if ($pairing.Target -eq 'codex') { 'toml' } else { 'json' }
            $files["$($pairing.Target)/permissions-preview.$extension"] = $pairing.PermissionsSnippet + "`n"
        }
    }
    $files['codex/snippet.toml'] = $files['codex/config.toml']
    $files['claude/secondbrain.mcpb'] = New-SBMcpDesktopBundle
    $files['SecondBrain.Messages.psm1'] = Read-SBText (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
    $server = @{command='pwsh';args=@('-NoProfile','-File',(Join-Path $BrainRoot 'scripts/mcp-server.ps1'))}
    $vsCode = ConvertTo-Json -InputObject ($server + @{name='secondbrain';type='stdio'}) -Compress
    $cursor = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes((ConvertTo-SBMcpJson $server)))

    $packageMessages = @{}
    foreach($key in @('mcp.package.root','mcp.package.applying')){
        $packageMessages[$key] = @{it=(Get-SBMessage $key @() 'it');en=(Get-SBMessage $key @() 'en')}
    }
    # Install script one-click
    $installContent = @(
        '#requires -Version 7.5',
        '<#',
        '.SYNOPSIS',
        'Installa automaticamente il server MCP SecondBrain in tutti gli IDE supportati.',
        '#>',
        '[CmdletBinding()]',
        'param([ValidateSet(''en'',''it'')][string]$Language,[switch]$ApproveKnowledgeTools)',
        'Import-Module (Join-Path $PSScriptRoot ''SecondBrain.Messages.psm1'') -Force',
        'if($Language){Set-SBUiLanguage $Language;$env:SECONDBRAIN_LANG=$Language}',
        ('Add-SBMessages (ConvertFrom-Json -AsHashtable -InputObject ''' + (ConvertTo-SBMcpJson $packageMessages).Replace("'","''") + ''')'),
        '$ErrorActionPreference = ''Stop''',
        "`$brain = '$($BrainRoot.Replace('\', '/').Replace("'", "''"))'",
        'if (!(Test-Path -LiteralPath (Join-Path $brain ''scripts/mcp-server.ps1''))) {',
        '    if ($env:SECONDBRAIN_HOME -and (Test-Path -LiteralPath (Join-Path $env:SECONDBRAIN_HOME ''scripts/mcp-server.ps1''))) {',
        '        $brain = $env:SECONDBRAIN_HOME',
        '    } else {',
        '        throw (New-SBError ''mcp.package.root'' @($brain))',
        '    }',
        '}',
        'Write-Host (Get-SBMessage ''mcp.package.applying'') -ForegroundColor Cyan',
        '$options = @{Pair=$true;Target=''all'';Apply=$true;ApproveReadTools=$ApproveKnowledgeTools}',
        '& (Join-Path $brain ''scripts/mcp-server.ps1'') @options'
    ) -join "`n"
    $files['install-all-ides.ps1'] = $installContent + "`n"
    $readmeContent = @(
        '# Pacchetto di Configurazione MCP: SecondBrain',
        '',
        'Questo pacchetto contiene le configurazioni pronte all''uso per integrare il server locale **Model Context Protocol (MCP)** di SecondBrain (`scripts/mcp-server.ps1`) negli IDE supportati.',
        '',
        '## 1. Installazione Rapida Automatica',
        'Per applicare automaticamente la configurazione a tutti gli IDE rilevati con backup preventivo del file originale:',
        '```powershell',
        'pwsh -NoProfile -File install-all-ides.ps1',
        '```',
        '',
        'Oppure direttamente dalla radice di SecondBrain:',
        '```powershell',
        'pwsh -NoProfile -File scripts/mcp-server.ps1 -Pair -Target all -Apply',
        '```',
        '',
        '---',
        '',
        'I consensi sono opzionali. Riesaminare i file permissions-preview prima di usare -ApproveKnowledgeTools. Il piano mantiene la conferma per check_publication.',
        '',
        '- Claude Desktop: aprire claude/secondbrain.mcpb e selezionare il clone locale. Richiede PowerShell 7.5+ sul PATH.',
        ('- Cursor: [Importa SecondBrain](cursor://anysphere.cursor-deeplink/mcp/install?name=secondbrain&config=' + [uri]::EscapeDataString($cursor) + ')'),
        '- VS Code, da PowerShell:',
        '',
        '```powershell',
        ("code --add-mcp '" + $vsCode.Replace("'", "''") + "'"),
        '```',
        '',
        '- Codex: usare scripts/mcp-server.ps1 -Pair -Target codex -Apply dal clone.',
        '- Claude Code: usare scripts/mcp-server.ps1 -Pair -Target claude-code -Apply dal clone.',
        '- Antigravity 2.x: per un progetto usare -Pair -Target antigravity -Scope project -WorkspacePath <progetto> -Apply (.agents/mcp_config.json).',
        '',
        'I frammenti e i link sono specifici del clone di esportazione. Il bundle Desktop chiede la radice alla persona che lo importa.',
        '',
        '## 2. Installazione Manuale per Singolo IDE',
        '',
        '| IDE | File nel pacchetto | Destinazione nel sistema |',
        '| :--- | :--- | :--- |',
        '| **OpenAI Codex** | `codex/snippet.toml` | `%USERPROFILE%\.codex\config.toml` |',
        '| **Claude Desktop** | `claude/claude_desktop_config.json` | `%APPDATA%\Claude\claude_desktop_config.json` |',
        '| **Cursor IDE** | `cursor/mcp.json` | `%USERPROFILE%\.cursor\mcp.json` |',
        '| **VS Code** | `vscode/mcp.json` | `%APPDATA%\Code\User\mcp.json` (oppure `.vscode/mcp.json` del progetto) |',
        '| **Claude Code** | `claude-code/user-registration.json` (frammento, usare la CLI) | `claude mcp add --transport stdio --scope user secondbrain -- pwsh -NoProfile -File <radice>/scripts/mcp-server.ps1`, oppure `.mcp.json` del progetto con `-Pair -Target claude-code -WorkspacePath <progetto> -Apply` |',
        '| **Google Antigravity** | `antigravity/mcp_config.json` | `%USERPROFILE%\.gemini\config\mcp_config.json` (legacy esistente riconosciuto) |',
        '| **Windsurf** | `windsurf/mcp_config.json` | `%USERPROFILE%\.codeium\windsurf\mcp_config.json` |',
        '',
        '---',
        '',
        '## 3. Verifica Connessione JSON-RPC',
        'Dal clone, inviare una richiesta di test al server:',
        '```powershell',
        '''{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'' | pwsh -NoProfile -File scripts/mcp-server.ps1 -NoRecovery',
        '```'
    ) -join "`n"
    $files['README.md'] = $readmeContent + "`n"
    $checksums = foreach ($name in @($files.Keys)) {
        if ($files[$name] -is [string]) { $files[$name] = [Text.Encoding]::UTF8.GetBytes($files[$name]) }
        "$(Get-SBHash $files[$name])  $name"
    }
    $files['SHA256SUMS'] = [Text.Encoding]::UTF8.GetBytes(($checksums -join "`n") + "`n")
    $lock = Enter-SBOperation @{coordinationRoot=(Join-Path $runtime 'access');brainRoot=$BrainRoot;workstationId='non-attivata'} -LockOnly
    try {
        Assert-SBPlainPath $OutDir
        if (Test-Path -LiteralPath $OutDir) { throw (New-SBError 'mcp.package.destination' @($OutDir)) }
        $createdFiles = foreach ($name in $files.Keys) {
            $destination = Join-Path $OutDir $name
            Write-SBFile $destination $files[$name] 'absent' (Join-Path $runtime 'backups') | Out-Null
            $destination
        }
    } finally { Exit-SBOperation $lock }

    return [PSCustomObject]@{
        PackageDir = $OutDir
        FileCount = $createdFiles.Count
        Files = $createdFiles
    }
}

Export-ModuleMember -Function @(
    'New-SBMcpPackage'
)
