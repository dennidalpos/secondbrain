#requires -Version 7.5
<#
.SYNOPSIS
Controlla, sincronizza e attiva SecondBrain sulla postazione.
.DESCRIPTION
Exit code: 0 allineato, 1 attenzione, 2 errore, 3 archivio occupato (lock di scrittura non ottenuto entro -WaitSeconds, predefinito 60).
Le letture (-Check) non prendono lock bloccanti: un writer attivo o una transazione pendente compaiono come warnings.
-Setup: attivazione guidata (preflight, discovery, proposta, conferma, anteprima, -Apply); 0 anteprima valida o attivazione applicata,
1 proposta non confermata o discovery in pausa. Report e selezione per host in .runtime/hosts/<id>/.
-Setup -Status: stato di binding, IDE e ultima ricevuta di selezione (sola lettura, exit 0).
-Setup -Unbind <repo|percorso|idIDE|nomeIDE>[,..]: disassocia repository e integrazioni IDE gestiti con proposta, conferma (-Yes o -Interactive) e anteprima come l'attivazione; -Apply per applicare. I dossier e i file IDE non vengono eliminati.
-Setup -Output <repo|percorso> -OutputStatus verified|exception-accepted|unverified [-Evidence <file sotto .runtime>] [-Exception <motivo>]: registra nel binding l'esito della collocazione degli output dopo la prova dell'agent prodotto (anteprima, conferma -Yes o -Interactive, -Apply). verified lega la prova ai suoi byte (SHA-256); exception-accepted richiede un motivo; nessuna build o test dei prodotti viene eseguito.
Operazioni e contratti portabili: docs/riferimento/portable-brain.md.
.EXAMPLE
pwsh -NoProfile -File scripts/secondbrain.ps1 -Check
pwsh -NoProfile -File scripts/secondbrain.ps1 -Sync
pwsh -NoProfile -File scripts/secondbrain.ps1 -Check -Repository github.com/my-org/my-product
pwsh -NoProfile -File scripts/secondbrain.ps1 -Discover -Roots D:\Projects
pwsh -NoProfile -File scripts/secondbrain.ps1 -Setup -Interactive
pwsh -NoProfile -File scripts/secondbrain.ps1 -Setup -Roots D:\Projects -Select my-product -Yes -Apply
pwsh -NoProfile -File scripts/secondbrain.ps1 -Setup -Status
pwsh -NoProfile -File scripts/secondbrain.ps1 -Setup -Unbind github.com/my-org/my-product -Yes -Apply
pwsh -NoProfile -File scripts/secondbrain.ps1 -Setup -Output github.com/my-org/my-product -OutputStatus verified -Evidence .runtime/proofs/my-product-output.json -Yes -Apply
#>
[CmdletBinding(DefaultParameterSetName='Check')]
param(
    [Parameter(ParameterSetName='Check')][switch]$Check,
    [Parameter(Mandatory,ParameterSetName='Sync')][switch]$Sync,
    [Parameter(Mandatory,ParameterSetName='Discover')][switch]$Discover,
    [Parameter(ParameterSetName='Discover')][Parameter(ParameterSetName='Setup')][string[]]$Roots=@(),
    [Parameter(ParameterSetName='Discover')][string]$ReportPath,
    [Parameter(ParameterSetName='Discover')][string]$ResumePath,
    [Parameter(ParameterSetName='Discover')][Parameter(ParameterSetName='Setup')][int]$MaxDirectories=0,
    [Parameter(Mandatory,ParameterSetName='Activate')][switch]$Activate,
    [Parameter(Mandatory,ParameterSetName='Activate')][string]$SelectionPath,
    [Parameter(ParameterSetName='Activate')][Parameter(ParameterSetName='Setup')][switch]$Apply,
    [Parameter(Mandatory,ParameterSetName='Setup')][switch]$Setup,
    [Parameter(ParameterSetName='Setup')][string[]]$Select=@(),
    [Parameter(ParameterSetName='Setup')][switch]$All,
    [Parameter(ParameterSetName='Setup')][string[]]$Ides=@(),
    [Parameter(ParameterSetName='Setup')][switch]$AllIdes,
    [Parameter(ParameterSetName='Setup')][switch]$ApproveExistingBlocks,
    [Parameter(ParameterSetName='Setup')][switch]$Interactive,
    [Parameter(ParameterSetName='Setup')][switch]$Yes,
    [Parameter(ParameterSetName='Setup')][switch]$NoRegisterEnvironment,
    [Parameter(ParameterSetName='Setup')][switch]$AndSync,
    [Parameter(ParameterSetName='Setup')][switch]$Status,
    [Parameter(ParameterSetName='Setup')][string[]]$Unbind=@(),
    [Parameter(ParameterSetName='Setup')][string]$Output,
    [Parameter(ParameterSetName='Setup')][string]$OutputStatus,
    [Parameter(ParameterSetName='Setup')][string]$Evidence,
    [Parameter(ParameterSetName='Setup')][string]$Exception,
    [Parameter(ParameterSetName='Check')][Parameter(ParameterSetName='Sync')][string]$Repository,
    [string]$ConfigPath,[string]$ObservationPath,
    [string]$SessionId,
    [ValidateRange(0,600)][int]$WaitSeconds
)
$ErrorActionPreference = 'Stop'
# Attesa massima del lock di scrittura (predefinita 60 s, o lockWaitSeconds in config/shared.json); exit 3 solo a timeout.
if ($PSBoundParameters.ContainsKey('WaitSeconds')) { $env:SECONDBRAIN_LOCK_WAIT_SECONDS = [string]$WaitSeconds }
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Portable.psm1')

try {
    $brain = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    if ($Setup) {
        $outputBound = $PSBoundParameters.ContainsKey('Output')
        $outputOptions = @('OutputStatus', 'Evidence', 'Exception') | Where-Object { $PSBoundParameters.ContainsKey($_) }
        if ($outputOptions -and !$outputBound) { throw ('-' + ($outputOptions -join ', -') + ' richiede -Output') }
        if ($Status -or $outputBound -or $Unbind.Count -or $PSBoundParameters.ContainsKey('Unbind')) {
            if ((@($Status.IsPresent, $outputBound, $PSBoundParameters.ContainsKey('Unbind')) | Where-Object { $_ }).Count -gt 1) { throw '-Status, -Unbind e -Output sono alternativi' }
            $conflicting = @('Roots', 'MaxDirectories', 'Select', 'All', 'Ides', 'AllIdes', 'ApproveExistingBlocks', 'NoRegisterEnvironment', 'AndSync') | Where-Object { $PSBoundParameters.ContainsKey($_) }
            if ($conflicting) { throw ('-Status/-Unbind/-Output non accettano: -' + ($conflicting -join ', -')) }
            if ($Status) {
                if ($Apply -or $Yes -or $Interactive) { throw '-Status e di sola lettura: -Apply, -Yes e -Interactive non si applicano' }
                $result = Get-SBSetupStatus $brain
            } elseif ($outputBound) {
                $result = Invoke-SBSetupOutput -BrainRoot $brain -Target $Output -OutputStatus $OutputStatus -Evidence $Evidence -Exception $Exception -Interactive:$Interactive -Yes:$Yes -Apply:$Apply -SessionId $SessionId
            } else {
                $result = Invoke-SBSetupUnbind -BrainRoot $brain -Targets $Unbind -Interactive:$Interactive -Yes:$Yes -Apply:$Apply -SessionId $SessionId
            }
            ConvertTo-SBJson $result
            if ($result.stage -in @('status', 'preview', 'applied')) { exit 0 }
            exit 1
        }
        $result = Invoke-SBSetup -BrainRoot $brain -Roots $Roots -MaxDirectories $MaxDirectories -Select $Select -All:$All -Ides $Ides -AllIdes:$AllIdes `
            -ApproveExistingBlocks:$ApproveExistingBlocks -Interactive:$Interactive -Yes:$Yes -Apply:$Apply -NoRegisterEnvironment:$NoRegisterEnvironment -AndSync:$AndSync -SessionId $SessionId
        ConvertTo-SBJson $result
        # 0: anteprima valida o attivazione applicata; 1: proposta senza conferma, discovery in pausa o controllo successivo non eseguibile.
        if ($result.stage -in @('preview', 'applied') -and !($result.Contains('check') -and $result.check.Contains('error'))) { exit 0 }
        exit 1
    }
    if ($Discover) {
        if (!$ReportPath) { $ReportPath = (Get-SBSetupPaths $brain).report }
        $result = Invoke-SBHostDiscovery -BrainRoot $brain -Roots $Roots -ReportPath $ReportPath -ResumePath $ResumePath -MaxDirectories $MaxDirectories
        ConvertTo-SBJson $result
        if (!$result.complete) { exit 2 }
        exit 0
    }
    if ($Activate) {
        ConvertTo-SBJson (Invoke-SBHostActivation -BrainRoot $brain -SelectionPath $SelectionPath -SessionId $SessionId -Apply:$Apply -RegisterEnvironment:$Apply)
        exit 0
    }
    $config = Read-SBConfiguration $ConfigPath -ReadOnly:(!$Sync)
    $result = Invoke-SBPortableSync -Config $config -Check:(!$Sync) -SessionId $SessionId -ObservationPath $ObservationPath -Repository $Repository
    ConvertTo-SBJson $result
    if (!$result.aligned) { exit 1 }
    exit 0
} catch {
    $failure = $_
    $base = $failure.Exception.GetBaseException()
    if ($base -is [IO.IOException] -and ($base.HResult -band 0xffff) -in @(32, 33)) {
        Write-Output $failure.Exception.Message
        exit 3
    }
    Write-Error $failure -ErrorAction Continue
    exit 2
}
