#requires -Version 7.5
<#
.SYNOPSIS
Creates a deterministic compressed backup of local SecondBrain data or verifies its integrity.
.DESCRIPTION
Includes PARA directories (01-projects, 02-areas, 03-resources, 04-archives), PARA.md, para-index.json
and .runtime/hosts. Adds a cryptographic SHA-256 manifest to the archive.
-Verify checks each included file against the manifest.
#>
[CmdletBinding(DefaultParameterSetName='Backup')]
param(
    [Parameter(ParameterSetName='Backup')]
    [string]$ConfigPath,
    [Parameter(ParameterSetName='Backup')]
    [string]$OutputPath,
    [Parameter(ParameterSetName='Backup')]
    [string]$SessionId,
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
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Add-SBMessages @{
    'backup.config.unavailable' = @{ it = 'Configurazione di postazione non disponibile, backup in .runtime/backups: {0}'; en = 'Workstation configuration unavailable, backup in .runtime/backups: {0}' }
    'backup.archive.missing' = @{ it = 'Archivio di backup non trovato per la verifica: ''{0}'''; en = 'Backup archive not found for verification: ''{0}''' }
    'backup.archive.corrupt' = @{ it = 'Archivio corrotto o non conforme: ''manifest.json'' assente in {0}'; en = 'Corrupt or non-conforming archive: ''manifest.json'' missing in {0}' }
    'backup.manifest.invalid' = @{ it = 'Manifest non valido o schema non supportato in {0}'; en = 'Invalid manifest or unsupported schema in {0}' }
    'backup.file.missing' = @{ it = 'File dichiarato nel manifest mancante nell''archivio: {0}'; en = 'File declared in the manifest is missing from the archive: {0}' }
    'backup.integrity.hash' = @{ it = 'Integrità crittografica compromessa per ''{0}'': atteso {1}, calcolato {2}'; en = 'Cryptographic integrity compromised for ''{0}'': expected {1}, computed {2}' }
    'backup.size.diverged' = @{ it = 'Dimensione divergente per ''{0}'': atteso {1}, trovato {2}'; en = 'Size diverges for ''{0}'': expected {1}, found {2}' }
    'backup.files.none' = @{ it = 'Nessun file trovato da includere nel backup in {0}.'; en = 'No file found to include in the backup in {0}.' }
}
# Writer busy beyond the wait limit: exit 3 (the message identifies the owner).
trap { if (Test-SBWriteDeniedError $_) { Write-SBWriteDeniedDiagnostic $_ $PSCommandPath $PSBoundParameters; exit 4 }; if (Test-SBBusyError $_) { [Console]::Error.WriteLine($_.Exception.Message); exit 3 }; break }

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
        throw (New-SBError 'backup.archive.missing' @($targetZip))
    }
    $targetZip = [IO.Path]::GetFullPath($targetZip)
    Write-Output "Verifica archivio: $targetZip"

    $zip = [System.IO.Compression.ZipFile]::OpenRead($targetZip)
    try {
        $manifestEntry = $zip.GetEntry('manifest.json')
        if (!$manifestEntry) {
            throw (New-SBError 'backup.archive.corrupt' @($targetZip))
        }
        $manifestText = $null
        $stream = $manifestEntry.Open()
        try {
            $reader = [System.IO.StreamReader]::new($stream, [System.Text.Encoding]::UTF8)
            try { $manifestText = $reader.ReadToEnd() } finally { $reader.Dispose() }
        } finally { $stream.Dispose() }

        $manifest = ConvertFrom-Json -InputObject $manifestText -AsHashtable
        if (!$manifest -or $manifest.schemaVersion -ne 1) {
            throw (New-SBError 'backup.manifest.invalid' @($targetZip))
        }

        $verifiedCount = 0
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try {
            foreach ($rel in $manifest.files.Keys) {
                $expected = $manifest.files[$rel]
                $entry = $zip.GetEntry($rel)
                if (!$entry) {
                    throw (New-SBError 'backup.file.missing' @($rel))
                }
                $entryStream = $entry.Open()
                $hash = $null
                try {
                    $hashBytes = $sha.ComputeHash($entryStream)
                    $hash = [BitConverter]::ToString($hashBytes).Replace('-', '')
                } finally { $entryStream.Dispose() }

                if ($hash -ne $expected.sha256) {
                    throw (New-SBError 'backup.integrity.hash' @($rel, $expected.sha256, $hash))
                }
                if ($entry.Length -ne $expected.size) {
                    throw (New-SBError 'backup.size.diverged' @($rel, $expected.size, $entry.Length))
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

# Backup mode
$config = $null
# Without -ConfigPath, an inactive workstation uses the default folder; an invalid explicit -ConfigPath is an error.
if ($ConfigPath) { $config = Read-SBConfiguration $ConfigPath }
else { try { $config = Read-SBConfiguration } catch { Write-Warning (Get-SBMessage 'backup.config.unavailable' @($_.Exception.Message)) } }
$backupRoot = if ($config -and $config.backupRoot) { $config.backupRoot } else { Join-Path $brain '.runtime/backups' }
[System.IO.Directory]::CreateDirectory($backupRoot) | Out-Null

$usedDefaultName = !$OutputPath
if (!$OutputPath) {
    $timestamp = [DateTimeOffset]::UtcNow.ToString('yyyyMMdd-HHmmss')
    $OutputPath = Join-Path $backupRoot ("secondbrain-backup-$timestamp.zip")
}
$resolvedOutput = [IO.Path]::GetFullPath($OutputPath)
[System.IO.Directory]::CreateDirectory((Split-Path $resolvedOutput)) | Out-Null

# Backup reads data modified by writers: join the FIFO queue and acquire the writer lock (exit 3 on timeout).
# On an inactive workstation, the lock uses the brain's default coordination folder.
$lockConfig = if ($config) { $config } else { @{ brainRoot = $brain; coordinationRoot = (Join-Path $brain '.runtime/access'); workstationId = 'non-attivata'; sessionTimeoutMinutes = 30; lockWaitMs = 60000 } }
$lock = Enter-SBOperation $lockConfig $SessionId -LockOnly
try {
# Two backups in the same second would share a name: the default name never overwrites an existing archive (suffix -2, -3, ...).
# An explicit -OutputPath retains the behavior specified by the caller.
if ($usedDefaultName) {
    $baseName = [IO.Path]::GetFileNameWithoutExtension($resolvedOutput); $suffix = 1
    while (Test-Path -LiteralPath $resolvedOutput) { $suffix++; $resolvedOutput = Join-Path (Split-Path $resolvedOutput) ($baseName + '-' + $suffix + '.zip') }
}
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
                # Exclude temporary and lock files.
                if ($item.Name -in @('.git', 'Thumbs.db', 'desktop.ini') -or $item.Extension -in @('.tmp', '.lock')) {
                    continue
                }
                $rel = [IO.Path]::GetRelativePath($brain, $item.FullName).Replace('\', '/')
                # Workstation backups and journals are excluded from a new archive.
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
    throw (New-SBError 'backup.files.none' @($brain))
}

# Compute manifest hashes.
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

# Create the ZIP archive.
if (Test-Path -LiteralPath $resolvedOutput) {
    [System.IO.File]::Delete($resolvedOutput)
}

$zip = [System.IO.Compression.ZipFile]::Open($resolvedOutput, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    # Add manifest.json.
    $manifestEntry = $zip.CreateEntry('manifest.json', [System.IO.Compression.CompressionLevel]::Optimal)
    $mStream = $manifestEntry.Open()
    try {
        $mBytes = [System.Text.Encoding]::UTF8.GetBytes($manifestJson)
        $mStream.Write($mBytes, 0, $mBytes.Length)
    } finally { $mStream.Dispose() }

    # Add each file.
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
} finally { Exit-SBOperation $lock }
exit 0
