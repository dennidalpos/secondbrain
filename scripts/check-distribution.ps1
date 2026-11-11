#requires -Version 7.5
<#
.SYNOPSIS
Checks that the SecondBrain Git index contains only public files permitted for distribution.
.DESCRIPTION
Ensures that no local file (01-projects/, 02-areas/, 03-resources/, 04-archives/, .runtime/,
PARA.md, para-index.json) is in the Git index or ready to push.
Checks that every tracked file belongs to the permitted public folders/files:
scripts/, config/, direttive/, docs/, .github/, README.md, AGENTS.md, CLAUDE.md, GEMINI.md, LICENSE, VERSION, CHANGELOG.md, CREDITS.md, SECURITY.md, CONTRIBUTING.md, CODE_OF_CONDUCT.md, .gitattributes, .gitignore.
Returns exit code 0 for a compliant working tree, 1 for violations.
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

# Permitted folders and files in the public distribution root.
$allowedPrefixes = @(
    'scripts/',
    'config/',
    'direttive/',
    'docs/',
    '.github/'
)

$allowedRootFiles = @(
    'README.md',
    'AGENTS.md',
    'CLAUDE.md',
    'GEMINI.md',
    'LICENSE',
    'VERSION',
    'CHANGELOG.md',
    'CREDITS.md',
    'SECURITY.md',
    'CONTRIBUTING.md',
    'CODE_OF_CONDUCT.md',
    '.gitattributes',
    '.gitignore'
)

# Local prefixes and files strictly forbidden in the Git index.
$forbiddenPatterns = @(
    '^01-projects/',
    '^02-areas/',
    '^03-resources/',
    '^04-archives/',
    '^\.runtime/',
    '^PARA\.md$',
    '^para-index\.json$'
)

# Check indexed files (tracked by Git).
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

    # The PARA skeleton is public: .gitkeep markers and the four top-level READMEs that .gitignore keeps tracked.
    $isParaSkeleton = ($f -match '^0[1-4]-[a-z]+(?:/[a-z]+)*/\.gitkeep$' -or $f -match '^0[1-4]-[a-z]+/README\.md$')

    # Check forbidden patterns (excluding .gitkeep markers allowed by .gitignore for the PARA skeleton).
    if (!$isParaSkeleton) {
        foreach ($pattern in $forbiddenPatterns) {
            if ($f -match $pattern) {
                $forbiddenFound.Add($f)
                break
            }
        }
    }

    # Check the permitted scope.
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

# Print violations without terminating Write-Error so the final message and exit 1 are always reached.
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
