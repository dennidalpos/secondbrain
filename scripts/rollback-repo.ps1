#requires -Version 7.5
<#
.SYNOPSIS
Esegue il rollback di un repository dismesso o vietato da SecondBrain: restituisce i dati nel repository target ed elimina ogni residuo in SecondBrain per tutela della privacy.
.DESCRIPTION
Senza -Apply mostra solo l'anteprima e non modifica nulla.
Richiede una sessione di scrittura (Enter-SBOperation, opzionale -SessionId) e rifiuta il dossier del cervello stesso.
1. Copia l'intero dossier (inclusi history/, snapshots/ e tracker.md) in <TargetRepo>/.secondbrain/ e ne verifica gli hash. Senza checkout (-Force) il dossier e salvato in backupRoot (rollback-<id>) prima della rimozione.
2. Aggiorna workstation.json (binding rimosso, repository aggiunto a forbiddenRepositories con -Forbid) e state.json.
3. Rimuove il blocco managed SecondBrain da AGENTS.md del repository target.
4. Solo a questo punto rimuove il dossier e la cache di runtime, poi rigenera para-index.json e PARA.md.
Un errore nei passi 1-3 lascia il dossier intatto: il rollback e ripetibile.
.EXAMPLE
pwsh -NoProfile -File scripts/rollback-repo.ps1 -RepositoryIdentity "github.com/my-org/my-project" -Forbid -Apply
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory=$true)][string]$RepositoryIdentity,
    [string]$DestinationPath,
    [string]$BrainRoot,
    [string]$ConfigPath,
    [string]$SessionId,
    [switch]$Forbid,
    [switch]$Force,
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'
$brain = if ($BrainRoot) { [IO.Path]::GetFullPath($BrainRoot) } else { [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')) }
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1') -Force
# Scrittura occupata oltre l'attesa: exit 3 (il titolare e nel messaggio).
trap { if (Test-SBBusyError $_) { [Console]::Error.WriteLine($_.Exception.Message); exit 3 }; break }
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Para.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Portable.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Host.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Add-SBMessages @{
    'rollback.reparse' = @{ it = 'Reparse point nel dossier, rollback rifiutato: {0}'; en = 'Reparse point in the dossier, rollback refused: {0}' }
    'rollback.hash.copy' = @{ it = 'Verifica hash fallita nella copia: {0}'; en = 'Hash verification failed in the copy: {0}' }
    'rollback.identity.dossiers' = @{ it = 'Identita ambigua: {0} dossier corrispondono a ''{1}'' ({2}). Indicare l''identita completa del repository.'; en = 'Ambiguous identity: {0} dossiers match ''{1}'' ({2}). Give the full repository identity.' }
    'rollback.identity.folders' = @{ it = 'Identita ambigua: {0} cartelle corrispondono a ''{1}'' ({2}). Indicare l''identita completa del repository.'; en = 'Ambiguous identity: {0} folders match ''{1}'' ({2}). Give the full repository identity.' }
    'rollback.dossier.missing' = @{ it = 'Dossier non trovato per l''identita o nome: {0}'; en = 'Dossier not found for the identity or name: {0}' }
    'rollback.self.repository' = @{ it = 'Rollback rifiutato: ''{0}'' e il repository di SecondBrain stesso.'; en = 'Rollback refused: ''{0}'' is the SecondBrain repository itself.' }
    'rollback.checkout.missing' = @{ it = 'Checkout di destinazione non trovato per {0} (specificare -DestinationPath o usare -Force se il checkout locale e rimosso).'; en = 'Destination checkout not found for {0} (give -DestinationPath or use -Force if the local checkout is removed).' }
    'rollback.self.checkout' = @{ it = 'Rollback rifiutato: il checkout di destinazione e SecondBrain stesso.'; en = 'Rollback refused: the destination checkout is SecondBrain itself.' }
    'rollback.out.start' = @{ it = 'Inizio Rollback Privacy per: {0}'; en = 'Starting privacy rollback for: {0}' }
    'rollback.out.source' = @{ it = '  Dossier sorgente: {0}'; en = '  Source dossier: {0}' }
    'rollback.out.target' = @{ it = '  Checkout target : {0}'; en = '  Target checkout : {0}' }
    'rollback.out.preview' = @{ it = 'Anteprima: nessuna modifica. Rilanciare con -Apply per restituire i dati, aggiornare la postazione ed eliminare il dossier.'; en = 'Preview: no changes made. Re-run with -Apply to return the data, update the workstation and delete the dossier.' }
    'rollback.out.copied' = @{ it = '  Copiati {0} file del dossier -> .secondbrain/ (hash verificati)'; en = '  Copied {0} dossier files -> .secondbrain/ (hashes verified)' }
    'rollback.out.excluded' = @{ it = '  Aggiunto .secondbrain/ a .git/info/exclude'; en = '  Added .secondbrain/ to .git/info/exclude' }
    'rollback.out.nocheckout' = @{ it = 'Checkout assente: dossier salvato in {0} (nessun trasferimento nel repository).'; en = 'Checkout missing: dossier saved in {0} (nothing transferred to the repository).' }
    'rollback.out.forbidden' = @{ it = '  Aggiunto a forbiddenRepositories: {0}'; en = '  Added to forbiddenRepositories: {0}' }
    'rollback.out.workstation' = @{ it = '  Aggiornato workstation.json'; en = '  Updated workstation.json' }
    'rollback.out.state' = @{ it = '  Rimosso managed state per {0}'; en = '  Removed managed state for {0}' }
    'rollback.out.block' = @{ it = '  Rimosso blocco gestito SecondBrain da {0}'; en = '  Removed SecondBrain managed block from {0}' }
    'rollback.out.dossier' = @{ it = '  Eliminato dossier: {0}'; en = '  Deleted dossier: {0}' }
    'rollback.out.runtime' = @{ it = '  Eliminata directory runtime: {0}'; en = '  Deleted runtime directory: {0}' }
    'rollback.out.index' = @{ it = '  Aggiornato para-index.json e PARA.md'; en = '  Updated para-index.json and PARA.md' }
    'rollback.out.done' = @{ it = 'Rollback completato con successo per {0}.'; en = 'Rollback completed successfully for {0}.' }
}

function ConvertTo-RollbackPath([string]$Path) { [IO.Path]::GetFullPath($Path).TrimEnd('\','/') }

# Copia ricorsiva dell'intero dossier con verifica hash file per file; rifiuta reparse point.
function Copy-RollbackTree([string]$Source,[string]$Destination) {
    $sourceRoot = ConvertTo-RollbackPath $Source
    $files = @(Get-ChildItem -LiteralPath $sourceRoot -Recurse -Force -File)
    foreach ($item in @(Get-ChildItem -LiteralPath $sourceRoot -Recurse -Force)) {
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw (New-SBError 'rollback.reparse' @($item.FullName)) }
    }
    [IO.Directory]::CreateDirectory($Destination) | Out-Null
    foreach ($file in $files) {
        $relative = $file.FullName.Substring($sourceRoot.Length).TrimStart('\','/')
        $target = Join-Path $Destination $relative
        [IO.Directory]::CreateDirectory((Split-Path $target)) | Out-Null
        Copy-Item -LiteralPath $file.FullName -Destination $target -Force
        if ((Get-SBFileHash $file.FullName) -ne (Get-SBFileHash $target)) { throw (New-SBError 'rollback.hash.copy' @($relative)) }
    }
    $files.Count
}

$config = Read-SBConfiguration $ConfigPath
$workstationConfigPath = Get-SBHostConfigPath $brain
$workstationConfig = Read-SBJson $workstationConfigPath @{}
$operation = Enter-SBOperation $config $SessionId
try {
    # 1. Individua il dossier in 02-areas/products (confronti case-sensitive, ambiguita sempre rifiutata)
    $entities = @(Get-SBParaEntities $brain @())
    $matchedEntities = @($entities | Where-Object {
        $_.kind -eq 'area' -and (
            $_.repository -ceq $RepositoryIdentity -or
            ($_.path -and ($_.path -split '[\\/]')[-1] -ceq $RepositoryIdentity) -or
            ($_.title -and $_.title -ceq $RepositoryIdentity)
        )
    })
    if ($matchedEntities.Count -gt 1) {
        throw (New-SBError 'rollback.identity.dossiers' @($matchedEntities.Count, $RepositoryIdentity, (($matchedEntities | ForEach-Object path) -join ', ')))
    }

    $dossierPath = $null
    $dossierRelative = $null
    $resolvedIdentity = $RepositoryIdentity

    if ($matchedEntities.Count -gt 0) {
        $target = $matchedEntities[0]
        $dossierRelative = $target.path
        $dossierPath = Join-Path $brain $dossierRelative
        if ($target.repository) { $resolvedIdentity = $target.repository }
    } else {
        $areasDir = Join-Path $brain '02-areas/products'
        $folderMatches = @()
        if (Test-Path -LiteralPath $areasDir) {
            foreach ($dir in Get-ChildItem -LiteralPath $areasDir -Directory) {
                $repoMeta = Join-Path $dir.FullName 'repository.json'
                if (Test-Path -LiteralPath $repoMeta) {
                    $meta = Read-SBJson $repoMeta @{}
                    if (($meta.ContainsKey('identity') -and $meta.identity -ceq $RepositoryIdentity) -or $dir.Name -ceq $RepositoryIdentity) {
                        $folderMatches += @{ path = $dir.FullName; relative = '02-areas/products/' + $dir.Name; identity = $(if ($meta.ContainsKey('identity')) { [string]$meta.identity } else { '' }) }
                    }
                }
            }
        }
        if ($folderMatches.Count -gt 1) {
            throw (New-SBError 'rollback.identity.folders' @($folderMatches.Count, $RepositoryIdentity, (($folderMatches | ForEach-Object { $_.relative }) -join ', ')))
        }
        if ($folderMatches.Count -eq 1) {
            $dossierPath = $folderMatches[0].path
            $dossierRelative = $folderMatches[0].relative
            if ($folderMatches[0].identity) { $resolvedIdentity = $folderMatches[0].identity }
        }
    }

    if (!$dossierPath -or !(Test-Path -LiteralPath $dossierPath)) {
        throw (New-SBError 'rollback.dossier.missing' @($RepositoryIdentity))
    }

    # Il dossier del cervello stesso non e mai restituibile ne eliminabile.
    $brainIdentity = Get-SBBrainIdentity $brain
    if (($brainIdentity -and $resolvedIdentity -ceq $brainIdentity) -or (ConvertTo-RollbackPath $dossierPath) -ieq (ConvertTo-RollbackPath $brain)) {
        throw (New-SBError 'rollback.self.repository' @($resolvedIdentity))
    }

    # 2. Risolvi il checkout target
    $checkoutPath = $DestinationPath
    if (!$checkoutPath -and $workstationConfig.ContainsKey('bindings')) {
        $binding = @($workstationConfig.bindings | Where-Object { $_.identity -ceq $resolvedIdentity -or $_.dossier -ceq $dossierRelative }) | Select-Object -First 1
        if ($binding) { $checkoutPath = $binding.path }
    }
    $hasCheckout = [bool]($checkoutPath -and (Test-Path -LiteralPath $checkoutPath))
    if (!$hasCheckout -and !$Force) {
        throw (New-SBError 'rollback.checkout.missing' @($RepositoryIdentity))
    }
    if ($hasCheckout -and (ConvertTo-RollbackPath $checkoutPath) -ieq (ConvertTo-RollbackPath $brain)) {
        throw (New-SBError 'rollback.self.checkout')
    }

    Write-Host (Get-SBMessage 'rollback.out.start' @($resolvedIdentity)) -ForegroundColor Cyan
    Write-Host (Get-SBMessage 'rollback.out.source' @($dossierPath))
    Write-Host (Get-SBMessage 'rollback.out.target' @($checkoutPath))

    if (!$Apply) {
        Write-Host (Get-SBMessage 'rollback.out.preview') -ForegroundColor Yellow
        return @{ identity = $resolvedIdentity; checkout = $checkoutPath; dossierDeleted = $null; forbidden = [bool]$Forbid; status = 'preview' }
    }
    if (!$PSCmdlet.ShouldProcess($dossierPath, 'Rollback: restituzione dei dati, aggiornamento postazione ed eliminazione del dossier SecondBrain')) {
        return @{ identity = $resolvedIdentity; checkout = $checkoutPath; dossierDeleted = $null; forbidden = [bool]$Forbid; status = 'skipped' }
    }

    # 3. Trasferimento: tutto il dossier nel repository target, oppure backup centrale se il checkout e assente.
    $transferred = 0
    $backupPath = $null
    if ($hasCheckout) {
        $transferred = Copy-RollbackTree $dossierPath (Join-Path $checkoutPath '.secondbrain')
        Write-Host (Get-SBMessage 'rollback.out.copied' @($transferred)) -ForegroundColor Green
        $gitDir = Join-Path $checkoutPath '.git'
        if (Test-Path -LiteralPath $gitDir) {
            $excludeFile = Join-Path $gitDir 'info/exclude'
            if (Test-Path -LiteralPath $excludeFile) {
                $excludeContent = [IO.File]::ReadAllText($excludeFile)
                if ($excludeContent -notmatch '(?m)^\.secondbrain/?$') {
                    [IO.File]::AppendAllText($excludeFile, "`n.secondbrain/`n", [Text.Encoding]::UTF8)
                    Write-Host (Get-SBMessage 'rollback.out.excluded') -ForegroundColor Green
                }
            }
        }
    } else {
        $backupPath = Join-Path $config.backupRoot ('rollback-' + [guid]::NewGuid().ToString('N'))
        $transferred = Copy-RollbackTree $dossierPath (Join-Path $backupPath 'dossier')
        Write-Warning (Get-SBMessage 'rollback.out.nocheckout' @($backupPath))
    }

    # 4. workstation.json e state.json prima di qualunque eliminazione: un errore qui lascia il dossier intatto.
    $bindings = @()
    if ($workstationConfig.ContainsKey('bindings')) {
        $bindings = @($workstationConfig.bindings | Where-Object { $_.identity -ne $resolvedIdentity -and $_.dossier -ne $dossierRelative })
        $workstationConfig.bindings = $bindings
    }
    $forbidden = @()
    if ($workstationConfig.ContainsKey('forbiddenRepositories')) { $forbidden = @($workstationConfig.forbiddenRepositories) }
    if ($Forbid) {
        $alreadyForbidden = $forbidden | Where-Object { $_.identity -eq $resolvedIdentity -or ($checkoutPath -and $_.path -eq $checkoutPath) }
        if (!$alreadyForbidden) {
            $forbidden += @{
                identity = $resolvedIdentity
                path = if ($checkoutPath) { $checkoutPath } else { '' }
                reason = 'user-requested-rollback'
                forbiddenAt = [DateTimeOffset]::UtcNow.ToString('o')
            }
            Write-Host (Get-SBMessage 'rollback.out.forbidden' @($resolvedIdentity)) -ForegroundColor Magenta
        }
    }
    $workstationConfig.forbiddenRepositories = $forbidden
    Write-SBFile $workstationConfigPath ([Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $workstationConfig))) (Get-SBFileHash $workstationConfigPath) $config.backupRoot | Out-Null
    Write-Host (Get-SBMessage 'rollback.out.workstation') -ForegroundColor Green

    $statePath = Join-Path $workstationConfig.runtimeRoot 'state.json'
    if ($checkoutPath -and (Test-Path -LiteralPath $statePath)) {
        $state = Read-SBJson $statePath @{ managed = @{} }
        $key = [IO.Path]::GetFullPath((Join-Path $checkoutPath 'AGENTS.md')) + '|repository'
        if ($state.managed.ContainsKey($key)) {
            $state.managed.Remove($key)
            Write-SBFile $statePath ([Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $state))) (Get-SBFileHash $statePath) $config.backupRoot | Out-Null
            Write-Host (Get-SBMessage 'rollback.out.state' @($key)) -ForegroundColor Green
        }
    }

    # 5. Pulisci AGENTS.md nel repository target
    if ($hasCheckout) {
        $agentsPath = Join-Path $checkoutPath 'AGENTS.md'
        if (Test-Path -LiteralPath $agentsPath) {
            $content = [IO.File]::ReadAllText($agentsPath, [Text.UTF8Encoding]::new($false))
            $pattern = '(?s)\r?\n?<!-- secondbrain:repository:begin -->.*?<!-- secondbrain:repository:end -->\r?\n?'
            if ($content -match $pattern) {
                $newContent = ($content -replace $pattern, "`n").Trim() + "`n"
                # Scrittura con controllo hash e backup verificato (ripristinabile con restore-managed.ps1).
                Write-SBFile $agentsPath ([Text.UTF8Encoding]::new($false).GetBytes($newContent)) (Get-SBFileHash $agentsPath) $config.backupRoot -BackupDirty | Out-Null
                Write-Host (Get-SBMessage 'rollback.out.block' @($agentsPath)) -ForegroundColor Green
            }
        }
    }

    # 6. Eliminazioni (dopo trasferimento e aggiornamento della postazione)
    Remove-Item -LiteralPath $dossierPath -Recurse -Force
    Write-Host (Get-SBMessage 'rollback.out.dossier' @($dossierPath)) -ForegroundColor Yellow
    if ($resolvedIdentity) {
        $repoRuntimeDir = Join-Path $workstationConfig.runtimeRoot ('repositories/' + (Get-SBTextHash $resolvedIdentity).Substring(0,24).ToLowerInvariant())
        if (Test-Path -LiteralPath $repoRuntimeDir) {
            Remove-Item -LiteralPath $repoRuntimeDir -Recurse -Force
            Write-Host (Get-SBMessage 'rollback.out.runtime' @($repoRuntimeDir)) -ForegroundColor Yellow
        }
    }

    # 7. Rigenera para-index.json e PARA.md
    Update-SBParaIndex $config | Out-Null
    Write-Host (Get-SBMessage 'rollback.out.index') -ForegroundColor Green

    Write-Host (Get-SBMessage 'rollback.out.done' @($resolvedIdentity)) -ForegroundColor Green
    return @{
        identity = $resolvedIdentity
        checkout = $checkoutPath
        dossierDeleted = $dossierPath
        filesTransferred = $transferred
        backup = $backupPath
        forbidden = [bool]$Forbid
        status = 'completed'
    }
} finally { Exit-SBOperation $operation }
