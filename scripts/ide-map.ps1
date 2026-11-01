#requires -Version 7.5
<#
.SYNOPSIS
Verifica le istruzioni globali degli IDE elencati nella mappa della postazione.
.DESCRIPTION
Legge runtimeRoot/ide-map.json, generato da secondbrain.ps1 -Sync, e confronta
il blocco secondbrain:global di ogni IDE di tipo file con runtimeRoot/istruzioni-globali.md.
Non scrive nulla. Exit code: 0 tutto allineato, 1 IDE da riallineare o mappa assente, 2 errore.
Schema della mappa: docs/adapters.md.
.EXAMPLE
pwsh -NoProfile -File scripts/ide-map.ps1 -Verify
#>
[CmdletBinding()]
param([switch]$Verify,[string]$ConfigPath,[string]$SessionId,[string]$ObservationPath)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1') -Force
$config=Read-SBConfiguration $ConfigPath -ReadOnly
$lock=Enter-SBOperation $config $SessionId -ReadOnly
try {
    Write-SBReadWarnings $lock $config
    $mapPath=Join-Path $config.runtimeRoot 'ide-map.json'
    $globalPath=Join-Path $config.runtimeRoot 'istruzioni-globali.md'
    if(!(Test-Path -LiteralPath $globalPath)){'Istruzioni globali assenti: eseguire secondbrain.ps1 -Sync';exit 1}
    if(!(Test-Path -LiteralPath $mapPath)){'Mappa IDE assente: '+$mapPath+'; eseguire secondbrain.ps1 -Sync';exit 1}
    $expected=(Read-SBText $globalPath).Trim()
    $expectedRevision=if($expected -match 'Revisione (\d+(?:\.\d+)+)'){$Matches[1]}else{'sconosciuta'}
    $wanted="<!-- secondbrain:global:begin -->`n"+$expected+"`n<!-- secondbrain:global:end -->"
    $map=Read-SBJson $mapPath $null
    if(!$map -or $map.schemaVersion -notin @(1,2) -or $map.workstationId -ne $config.workstationId -or $map.ides -isnot [array]){throw 'Mappa IDE non valida o di un''altra postazione: '+$mapPath}
    $pending=0
    $observations=@()
    if($ObservationPath){$receipt=Read-SBJson (Assert-SBCentralDataPath $config.brainRoot $ObservationPath) $null;if(!$receipt -or $receipt.schemaVersion -ne 1){throw 'Osservazioni IDE non valide'};$observations=@($receipt.observations)}
    "Revisione attesa: $expectedRevision; schema mappa $($map.schemaVersion)"
    foreach($ide in $map.ides){
        if(!$ide.name -or $ide.mode -notin @('file','manual')){throw 'Voce della mappa non valida: '+(ConvertTo-SBJson $ide)}
        if($ide.ContainsKey('selected') -and !$ide.selected){continue}
        if($ide.mode -eq 'manual'){
            $valid=Test-SBIDEObservation $ide (Get-SBTextHash $expected) $observations $config.brainRoot $config.workstationId
            if(!$valid){$pending++}
            "$($ide.name): manuale, account/profilo e caricamento "+$(if($valid){'verificati nella sessione osservata'}else{'non verificati o disallineati'})
            continue
        }
        if(![IO.Path]::IsPathFullyQualified([string]$ide.instructions)){throw "Percorso assoluto richiesto per $($ide.name)"}
        if(!(Test-Path -LiteralPath $ide.instructions -PathType Leaf)){$pending++;"$($ide.name): file assente $($ide.instructions)";continue}
        $text=(Read-SBText $ide.instructions) -replace "`r`n","`n"
        $block=Get-SBManagedContent $text 'global'
        $source=if($null -ne $block){$block}else{$text}
        $found=if($source -match 'Revisione (\d+(?:\.\d+)+)'){$Matches[1]}else{'assente'}
        if($null -ne $block -and $block -ceq $wanted){
            "$($ide.name): allineato (revisione $found); il file non certifica account o caricamento"
            if($map.schemaVersion -eq 2 -and !(Test-SBIDEObservation $ide (Get-SBTextHash $expected) $observations $config.brainRoot $config.workstationId)){$pending++}
            continue
        }
        $pending++
        if($null -eq $block){"$($ide.name): testo senza blocco secondbrain:global (revisione $found), da riallineare con SYS01 (secondbrain.ps1 -Sync)"}
        else{"$($ide.name): blocco da riallineare (revisione $found)"}
    }
    if($pending){exit 1}
    exit 0
} catch { Write-Error $_ -ErrorAction Continue; exit 2 } finally { Exit-SBOperation $lock }
