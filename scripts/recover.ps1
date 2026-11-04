#requires -Version 7.5
<#
.SYNOPSIS
Checks or restores an interrupted PARA transaction from its manifest.
.DESCRIPTION
Without -Apply, previews the destinations to restore. With -Apply, performs the
verified restoration (previous hash, payload in the manifest journal) and removes the
.runtime/para-transaction.json marker; preserves the original manifest.
Without -ConfigPath, uses the default portable configuration (including partial activation);
with -ConfigPath, uses backupRoot and operational paths from the specified workstation.
.EXAMPLE
pwsh -NoProfile -File scripts/recover.ps1 -ManifestPath .runtime/hosts/<id>/backups/<transazione>/manifest.json
pwsh -NoProfile -File scripts/recover.ps1 -ManifestPath <manifest> -Apply
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$ManifestPath,[switch]$Apply,[string]$ConfigPath,[string]$SessionId)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Portable.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Para.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Add-SBMessages @{
    'recover.path.missing' = @{ it = 'Percorso non trovato: {0}'; en = 'Path not found: {0}' }
    'recover.manifest.foreign' = @{ it = 'Manifest di altra installazione o non valido'; en = 'Manifest of another installation or invalid' }
    'recover.destination.outside' = @{ it = 'Destinazione recupero fuori da SecondBrain'; en = 'Recovery destination outside SecondBrain' }
    'recover.refused.changed' = @{ it = 'Recupero rifiutato: destinazione modificata successivamente'; en = 'Recovery refused: destination modified afterwards' }
    'recover.payload.invalid' = @{ it = 'Payload di recupero non valido'; en = 'Invalid recovery payload' }
}
# Writer busy beyond the wait limit: exit 3 (the message identifies the owner).
trap { if (Test-SBWriteDeniedError $_) { Write-SBWriteDeniedDiagnostic $_ $PSCommandPath $PSBoundParameters; exit 4 }; if (Test-SBBusyError $_) { [Console]::Error.WriteLine($_.Exception.Message); exit 3 }; break }
$brain=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
# With -ConfigPath, the manifest may live in the workstation backupRoot, even outside .runtime: Restore-SBParaTransaction verifies confinement.
$resolvePath={param($p) if($ConfigPath){if(!(Test-Path -LiteralPath $p)){throw (New-SBError 'recover.path.missing' @($p))};[IO.Path]::GetFullPath($p)}else{Assert-SBCentralDataPath $brain $p}}
$manifestPath=& $resolvePath $ManifestPath
$journal=Read-SBJson $manifestPath $null
if(!$journal -or $journal.schemaVersion -ne 1 -or !(Test-SBSamePath $journal.brainRoot $brain)){throw (New-SBError 'recover.manifest.foreign')}
$allowedPaths=@()
if($ConfigPath){
    $config=Read-SBConfiguration $ConfigPath -AllowPendingTransaction
    $allowedPaths=@(Get-SBParaRuntimePaths $config)
    $backupRoot=$config.backupRoot
}else{
    $config=New-SBPortableConfiguration $brain
    $config.brainRoot=$brain;$config.coordinationRoot=Join-Path $brain '.runtime/access';$config.sessionTimeoutMinutes=30
    $backupRoot=Split-Path $manifestPath
}
$lock=Enter-SBOperation $config $SessionId -ReadOnly:(!$Apply)
try{
    $changes=@()
    $boundary=$brain.TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
    foreach($record in $journal.records){
        # Journal written by another host using a different alias of the same brain (UNC, mapped drive).
        $record.path=Convert-SBBrainAlias $record.path $journal.brainRoot $brain
        if($record.backup){$record.backup=Convert-SBBrainAlias $record.backup $journal.brainRoot $brain}
        $path=[IO.Path]::GetFullPath($record.path)
        if(!$path.StartsWith($boundary,[StringComparison]::OrdinalIgnoreCase) -and $path -notin $allowedPaths){throw (New-SBError 'recover.destination.outside')}
        Assert-SBPlainPath $path
        $current=Get-SBFileHash $path
        if($current -eq $record.previousHash){continue}
        if($current -ne $record.deployedHash){throw (New-SBError 'recover.refused.changed')}
        if($record.previousHash -ne 'absent'){
            $payload=& $resolvePath $record.backup
            if(!$payload.StartsWith((Split-Path $manifestPath)+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or (Get-SBFileHash $payload) -ne $record.previousHash){throw (New-SBError 'recover.payload.invalid')}
        }
        $changes+=@{path=$path;current=$current;restore=$record.previousHash}
    }
    if($Apply){Restore-SBParaTransaction $manifestPath $brain $backupRoot $allowedPaths | Out-Null}
    ConvertTo-SBJson @{applied=[bool]$Apply;changes=$changes;originalManifestRetained=$true;environmentNote='Check SECONDBRAIN_HOME after recovery; user environment is not rewritten by this command.'}
}finally{Exit-SBOperation $lock}
