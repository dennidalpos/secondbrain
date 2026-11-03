#requires -Version 7.5
<#
.SYNOPSIS
Verifica che l'indice Git di SecondBrain contenga solo file pubblici consentiti per la distribuzione.
.DESCRIPTION
Accerta che nessun file locale (01-projects/, 02-areas/, 03-resources/, 04-archives/, .runtime/,
PARA.md, para-index.json) sia presente nell'indice Git o pronto per il push.
Verifica che tutti i file tracciati appartengano alle cartelle/file pubblici autorizzati:
scripts/, config/, direttive/, docs/, README.md, AGENTS.md, LICENSE, VERSION, CHANGELOG.md, CREDITS.md, .gitattributes, .gitignore.
Restituisce exit code 0 su working tree conforme, 1 in presenza di violazioni.
#>
[CmdletBinding()]
param(
    [string]$RepositoryPath,
    [switch]$CheckStagedOnly
)

$ErrorActionPreference = 'Stop'
try {
    if ([Console]::OutputEncoding.CodePage -ne 65001) {
        [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
    }
} catch { }
$OutputEncoding = [Text.UTF8Encoding]::new($false)

$repo = if ($RepositoryPath) { [IO.Path]::GetFullPath($RepositoryPath) } else { [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')) }

# Cartelle e file ammessi nella radice di distribuzione pubblica
$allowedPrefixes = @(
    'scripts/',
    'config/',
    'direttive/',
    'docs/'
)

$allowedRootFiles = @(
    'README.md',
    'AGENTS.md',
    'LICENSE',
    'VERSION',
    'CHANGELOG.md',
    'CREDITS.md',
    'SECURITY.md',
    '.gitattributes',
    '.gitignore'
)

# Prefissi e file locali severamente vietati nell'indice Git
$forbiddenPatterns = @(
    '^01-projects/',
    '^02-areas/',
    '^03-resources/',
    '^04-archives/',
    '^\.runtime/',
    '^PARA\.md$',
    '^para-index\.json$'
)

# Verifica file indicizzati (tracciati da Git)
$previousEncoding = [Console]::OutputEncoding
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
try {
    $trackedFiles = if ($CheckStagedOnly) {
        & git -c core.quotepath=false -C $repo diff --cached --name-only
    } else {
        & git -c core.quotepath=false -C $repo ls-files
    }
    if ($LASTEXITCODE -ne 0) {
        throw "Errore durante l'interrogazione dell'indice Git nel repository $repo"
    }
} finally {
    [Console]::OutputEncoding = $previousEncoding
}

$violations = [System.Collections.Generic.List[string]]::new()
$forbiddenFound = [System.Collections.Generic.List[string]]::new()

foreach ($line in $trackedFiles) {
    $f = $line.Trim().Replace('\', '/')
    if (!$f) { continue }

    $isParaSkeleton = ($f -match '^0[1-4]-[a-z]+(?:/[a-z]+)*/\.gitkeep$')

    # Controllo pattern vietati (escludendo i marker .gitkeep previsti da .gitignore per lo scheletro PARA)
    if (!$isParaSkeleton) {
        foreach ($pattern in $forbiddenPatterns) {
            if ($f -match $pattern) {
                $forbiddenFound.Add($f)
                break
            }
        }
    }

    # Controllo perimetro consentito
    $isAllowed = $false
    if ($allowedRootFiles -contains $f -or $isParaSkeleton) {
        $isAllowed = $true
    } else {
        foreach ($prefix in $allowedPrefixes) {
            if ($f.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                $isAllowed = $true
                break
            }
        }
    }

    if (!$isAllowed) {
        $violations.Add($f)
    }
}

$hasErrors = $false

# Le violazioni sono stampate (non Write-Error terminante) cosi il messaggio finale e l'exit 1 sono sempre raggiunti.
if ($forbiddenFound.Count -gt 0) {
    $hasErrors = $true
    Write-Output "VIOLAZIONE CRITICA: Rilevati file locali/privati tracciati nell'indice Git:`n$($forbiddenFound -join "`n")"
}

if ($violations.Count -gt 0) {
    $hasErrors = $true
    Write-Output "VIOLAZIONE PERIMETRO: Rilevati file non ammessi per la distribuzione:`n$($violations -join "`n")"
}

if ($hasErrors) {
    Write-Output "DISTRIBUTION CHECK FAILED: Working tree non conforme alla policy di distribuzione solo-codice."
    exit 1
}

Write-Output "DISTRIBUTION CHECK SUCCESS: Tutti i $($trackedFiles.Count) file tracciati sono conformi al perimetro di distribuzione."
exit 0
