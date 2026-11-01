#requires -Version 7.5
<#
.SYNOPSIS
Esegue il backup compresso deterministico dei dati locali di SecondBrain o ne verifica l'integrità.
.DESCRIPTION
Include le directory PARA (01-projects, 02-areas, 03-resources, 04-archives), PARA.md, para-index.json
e .runtime/hosts. Inserisce un manifest crittografico SHA-256 nell'archivio.
-Verify convalida la coerenza di ciascun file incluso rispetto al manifest.
#>
[CmdletBinding(DefaultParameterSetName='Backup')]
param(
    [Parameter(ParameterSetName='Backup')]
    [string]$ConfigPath,
    [Parameter(ParameterSetName='Backup')]
    [string]$OutputPath,
    [Parameter(Mandatory,ParameterSetName='Verify')]
    [switch]$Verify,
    [Parameter(ParameterSetName='Verify')]
    [string]$BackupPath
)

$ErrorActionPreference = 'Stop'
try {
    if ([Console]::OutputEncoding.CodePage -ne 65001) {
        [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
    }
} catch { }
$OutputEncoding = [Text.UTF8Encoding]::new($false)

Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1') -Force

$brain = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))

if ($Verify) {
    $targetZip = $BackupPath
    if (!$targetZip) {
        $cfg = $null
        try { $cfg = Read-SBConfiguration $ConfigPath } catch { }
        $backupDirs = @()
        if ($cfg -and $cfg.backupRoot) { $backupDirs += $cfg.backupRoot }
        $backupDirs += (Join-Path $brain '.runtime/backups')
        $hostsDir = Join-Path $brain '.runtime/hosts'
        if (Test-Path -LiteralPath $hostsDir) {
            Get-ChildItem -LiteralPath $hostsDir -Directory | ForEach-Object {
                $hBackup = Join-Path $_.FullName 'backups'
                if (Test-Path -LiteralPath $hBackup) { $backupDirs += $hBackup }
            }
        }
        foreach ($dir in ($backupDirs | Sort-Object -Unique)) {
            if (Test-Path -LiteralPath $dir) {
                $found = Get-ChildItem -LiteralPath $dir -Filter 'secondbrain-backup-*.zip' -File | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
                if ($found) { $targetZip = $found.FullName; break }
            }
        }
    }
    if (!$targetZip -or !(Test-Path -LiteralPath $targetZip -PathType Leaf)) {
        throw "Archivio di backup non trovato per la verifica: '$targetZip'"
    }
    $targetZip = [IO.Path]::GetFullPath($targetZip)
    Write-Output "Verifica archivio: $targetZip"

    $zip = [System.IO.Compression.ZipFile]::OpenRead($targetZip)
    try {
        $manifestEntry = $zip.GetEntry('manifest.json')
        if (!$manifestEntry) {
            throw "Archivio corrotto o non conforme: 'manifest.json' assente in $targetZip"
        }
        $manifestText = $null
        $stream = $manifestEntry.Open()
        try {
            $reader = [System.IO.StreamReader]::new($stream, [System.Text.Encoding]::UTF8)
            try { $manifestText = $reader.ReadToEnd() } finally { $reader.Dispose() }
        } finally { $stream.Dispose() }

        $manifest = ConvertFrom-Json -InputObject $manifestText -AsHashtable
        if (!$manifest -or $manifest.schemaVersion -ne 1) {
            throw "Manifest non valido o schema non supportato in $targetZip"
        }

        $verifiedCount = 0
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try {
            foreach ($rel in $manifest.files.Keys) {
                $expected = $manifest.files[$rel]
                $entry = $zip.GetEntry($rel)
                if (!$entry) {
                    throw "File dichiarato nel manifest mancante nell'archivio: $rel"
                }
                $entryStream = $entry.Open()
                $hash = $null
                try {
                    $hashBytes = $sha.ComputeHash($entryStream)
                    $hash = [BitConverter]::ToString($hashBytes).Replace('-', '')
                } finally { $entryStream.Dispose() }

                if ($hash -ne $expected.sha256) {
                    throw "Integrità crittografica compromessa per '$rel': atteso $($expected.sha256), calcolato $hash"
                }
                if ($entry.Length -ne $expected.size) {
                    throw "Dimensione divergente per '$rel': atteso $($expected.size), trovato $($entry.Length)"
                }
                $verifiedCount++
            }
        } finally { $sha.Dispose() }

        Write-Output "VERIFY SUCCESS: $verifiedCount file verificati con successo in $targetZip (SHA-256 conforme)."
        exit 0
    } finally {
        $zip.Dispose()
    }
}

# Modalità Backup
$config = $null
# Senza -ConfigPath una postazione non attivata usa la cartella predefinita; un -ConfigPath esplicito non valido e un errore.
if ($ConfigPath) { $config = Read-SBConfiguration $ConfigPath }
else { try { $config = Read-SBConfiguration } catch { Write-Warning ('Configurazione di postazione non disponibile, backup in .runtime/backups: ' + $_.Exception.Message) } }
$backupRoot = if ($config -and $config.backupRoot) { $config.backupRoot } else { Join-Path $brain '.runtime/backups' }
[System.IO.Directory]::CreateDirectory($backupRoot) | Out-Null

if (!$OutputPath) {
    $timestamp = [DateTimeOffset]::UtcNow.ToString('yyyyMMdd-HHmmss')
    $OutputPath = Join-Path $backupRoot ("secondbrain-backup-$timestamp.zip")
}
$resolvedOutput = [IO.Path]::GetFullPath($OutputPath)
[System.IO.Directory]::CreateDirectory((Split-Path $resolvedOutput)) | Out-Null

$includeTargets = @(
    @{ type = 'dir';  path = '01-projects' },
    @{ type = 'dir';  path = '02-areas' },
    @{ type = 'dir';  path = '03-resources' },
    @{ type = 'dir';  path = '04-archives' },
    @{ type = 'file'; path = 'PARA.md' },
    @{ type = 'file'; path = 'para-index.json' },
    @{ type = 'dir';  path = '.runtime/hosts' }
)

$fileList = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($target in $includeTargets) {
    $full = Join-Path $brain $target.path
    if ($target.type -eq 'file') {
        if (Test-Path -LiteralPath $full -PathType Leaf) {
            $fileList.Add([PSCustomObject]@{
                FullPath = $full
                Relative = $target.path.Replace('\', '/')
            })
        }
    } elseif ($target.type -eq 'dir') {
        if (Test-Path -LiteralPath $full -PathType Container) {
            foreach ($item in Get-ChildItem -LiteralPath $full -Recurse -File -Force) {
                # Escludi file temporanei o di lock
                if ($item.Name -in @('.git', 'Thumbs.db', 'desktop.ini') -or $item.Extension -in @('.tmp', '.lock')) {
                    continue
                }
                $rel = [IO.Path]::GetRelativePath($brain, $item.FullName).Replace('\', '/')
                # I backup e i giornali delle postazioni non rientrano in un nuovo archivio.
                if ($rel -match '^\.runtime/hosts/[^/]+/backups/' -or $item.FullName.StartsWith($backupRoot.TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
                    continue
                }
                $fileList.Add([PSCustomObject]@{
                    FullPath = $item.FullName
                    Relative = $rel
                })
            }
        }
    }
}

if ($fileList.Count -eq 0) {
    throw "Nessun file trovato da includere nel backup in $brain."
}

# Calcolo hash per il manifest
$manifestFiles = @{}
$sha = [System.Security.Cryptography.SHA256]::Create()
try {
    foreach ($f in $fileList) {
        $bytes = [System.IO.File]::ReadAllBytes($f.FullPath)
        $hashBytes = $sha.ComputeHash($bytes)
        $hash = [BitConverter]::ToString($hashBytes).Replace('-', '')
        $manifestFiles[$f.Relative] = @{
            sha256 = $hash
            size   = $bytes.Length
        }
    }
} finally { $sha.Dispose() }

$manifestObj = @{
    schemaVersion = 1
    createdAt     = [DateTimeOffset]::UtcNow.ToString('o')
    generator     = 'scripts/backup.ps1'
    fileCount     = $fileList.Count
    files         = $manifestFiles
}
$manifestJson = ConvertTo-SBJson $manifestObj

# Creazione archivio ZIP
if (Test-Path -LiteralPath $resolvedOutput) {
    [System.IO.File]::Delete($resolvedOutput)
}

$zip = [System.IO.Compression.ZipFile]::Open($resolvedOutput, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    # Aggiungi manifest.json
    $manifestEntry = $zip.CreateEntry('manifest.json', [System.IO.Compression.CompressionLevel]::Optimal)
    $mStream = $manifestEntry.Open()
    try {
        $mBytes = [System.Text.Encoding]::UTF8.GetBytes($manifestJson)
        $mStream.Write($mBytes, 0, $mBytes.Length)
    } finally { $mStream.Dispose() }

    # Aggiungi ciascun file
    foreach ($f in $fileList) {
        $entry = $zip.CreateEntry($f.Relative, [System.IO.Compression.CompressionLevel]::Optimal)
        $entryStream = $entry.Open()
        try {
            $bytes = [System.IO.File]::ReadAllBytes($f.FullPath)
            $entryStream.Write($bytes, 0, $bytes.Length)
        } finally { $entryStream.Dispose() }
    }
} finally {
    $zip.Dispose()
}

$zipHash = Get-SBFileHash $resolvedOutput
$zipSize = (Get-Item -LiteralPath $resolvedOutput).Length

Write-Output "BACKUP SUCCESS: Creato archivio in $resolvedOutput"
Write-Output "File inclusi: $($fileList.Count) | Dimensione: $zipSize bytes | SHA-256: $zipHash"
exit 0
