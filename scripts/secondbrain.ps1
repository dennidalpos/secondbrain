#requires -Version 7.5
<#
.SYNOPSIS
Checks, synchronizes and activates SecondBrain on the workstation.
.DESCRIPTION
Exit code: 0 aligned, 1 attention required, 2 error, 3 archive busy (writer lock not acquired within -WaitSeconds, default 60).
Reads (-Check) take no blocking locks: an active writer or pending transaction appears in warnings.
-Setup: guided activation (preflight, discovery, preview, confirmation and activation); 0 valid preview or activation applied,
1 unconfirmed proposal or paused discovery. Per-host report and selection in .runtime/hosts/<id>/.
-Setup registers SECONDBRAIN_HOME on confirmed activation unless -NoRegisterEnvironment is supplied.
-Setup -Status: binding, IDE and latest selection receipt status (read-only, exit 0).
-Setup -Unbind <repo|path|ideId|ideName>[,..]: unbinds managed repositories and IDE integrations with proposal, confirmation (-Yes or -Interactive) and preview, like activation; -Apply applies it. Dossiers and IDE files are not deleted.
Portable operations and contracts: docs/riferimento/portable-brain.md.
.EXAMPLE
pwsh -NoProfile -File scripts/secondbrain.ps1 -Check
pwsh -NoProfile -File scripts/secondbrain.ps1 -Sync
pwsh -NoProfile -File scripts/secondbrain.ps1 -Check -Repository github.com/my-org/my-product
pwsh -NoProfile -File scripts/secondbrain.ps1 -Discover -Roots D:\Projects
pwsh -NoProfile -File scripts/secondbrain.ps1 -Setup -Interactive
pwsh -NoProfile -File scripts/secondbrain.ps1 -Setup -Roots D:\Projects -Select my-product -Yes -Apply
pwsh -NoProfile -File scripts/secondbrain.ps1 -Setup -Roots D:\Projects -Select my-product -Yes -Apply -RegisterEnvironment
pwsh -NoProfile -File scripts/secondbrain.ps1 -Activate -SelectionPath .runtime/hosts/<id>/selection.json -Apply -NoRegisterEnvironment
pwsh -NoProfile -File scripts/secondbrain.ps1 -Setup -Status
pwsh -NoProfile -File scripts/secondbrain.ps1 -Setup -Unbind github.com/my-org/my-product -Yes -Apply
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
    [Parameter(ParameterSetName='Setup')][string[]]$McpTargets=@(),
    [Parameter(ParameterSetName='Setup')][Alias('ApproveMcpKnowledgeTools')][switch]$ApproveMcpReadTools,
    [Parameter(ParameterSetName='Setup')][string[]]$IdeAccount=@(),
    [Parameter(ParameterSetName='Setup')][switch]$ApproveExistingBlocks,
    [Parameter(ParameterSetName='Setup')][switch]$Interactive,
    [Parameter(ParameterSetName='Setup')][switch]$PreviewOnly,
    [Parameter(ParameterSetName='Setup')][string]$TeamRoot,
    [Parameter(ParameterSetName='Setup')][switch]$Yes,
    [Parameter(ParameterSetName='Setup')][switch]$RegisterEnvironment,
    [Parameter(ParameterSetName='Setup')][Parameter(ParameterSetName='Activate')][switch]$NoRegisterEnvironment,
    [Parameter(ParameterSetName='Setup')][switch]$AndSync=$true,
    [Parameter(ParameterSetName='Setup')][switch]$Status,
    [Parameter(ParameterSetName='Setup')][string[]]$Unbind=@(),
    [Parameter(ParameterSetName='Check')][Parameter(ParameterSetName='Sync')][string]$Repository,
    [string]$ConfigPath,[string]$ObservationPath,
    [string]$SessionId,
    [ValidateRange(0,600)][int]$WaitSeconds,
    [ValidateSet('en','it')][string]$Language
)
if($Language){$env:SECONDBRAIN_LANG=$Language}
$ErrorActionPreference = 'Stop'
# Maximum writer-lock wait (default 60 s, or lockWaitSeconds in config/shared.json); exit 3 only on timeout.
if ($PSBoundParameters.ContainsKey('WaitSeconds')) { $env:SECONDBRAIN_LOCK_WAIT_SECONDS = [string]$WaitSeconds }
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1') -Force
trap { if (Test-SBWriteDeniedError $_) { Write-SBWriteDeniedDiagnostic $_ $PSCommandPath $PSBoundParameters; exit 4 }; break }
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Host.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Portable.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Pending.psm1')
Add-SBMessages @{
    'cli.setup.team.root' = @{ it = '-TeamRoot richiede una radice UNC raggiungibile'; en = '-TeamRoot requires a reachable UNC root' }
    'cli.setup.team.mode' = @{ it = '-TeamRoot richiede -PreviewOnly, -Interactive oppure -Yes -Apply'; en = '-TeamRoot requires -PreviewOnly, -Interactive or -Yes -Apply' }
    'cli.setup.conflict' = @{ it = '-Status/-Unbind non accettano: -{0}'; en = '-Status/-Unbind do not accept: -{0}' }
    'cli.alternatives' = @{ it = '-Status e -Unbind sono alternativi'; en = '-Status and -Unbind are alternatives' }
    'cli.status.readonly' = @{ it = '-Status e di sola lettura: -Apply, -Yes e -Interactive non si applicano'; en = '-Status is read-only: -Apply, -Yes and -Interactive do not apply' }
}

try {
    $brain = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    if ($Setup) {
        if ($Status -or $PSBoundParameters.ContainsKey('Unbind')) {
            if ($Status -and $PSBoundParameters.ContainsKey('Unbind')) { throw (New-SBError 'cli.alternatives') }
            $conflicting = @('Roots', 'MaxDirectories', 'Select', 'All', 'Ides', 'AllIdes', 'IdeAccount', 'ApproveExistingBlocks', 'RegisterEnvironment', 'NoRegisterEnvironment', 'AndSync', 'McpTargets', 'ApproveMcpReadTools', 'PreviewOnly', 'TeamRoot') | Where-Object { $PSBoundParameters.ContainsKey($_) }
            if ($conflicting) { throw (New-SBError 'cli.setup.conflict' @(($conflicting -join ', -'))) }
            if ($Status) {
                if ($Apply -or $Yes -or $Interactive) { throw (New-SBError 'cli.status.readonly') }
                $result = Get-SBSetupStatus $brain
            } else {
                $result = Invoke-SBSetupUnbind -BrainRoot $brain -Targets $Unbind -Interactive:$Interactive -Yes:$Yes -Apply:$Apply -SessionId $SessionId
            }
            ConvertTo-SBJson $result
            if ($result.stage -in @('status', 'preview', 'applied')) { exit 0 }
            exit 1
        }
        if ($PreviewOnly -and ($Yes -or $Apply -or $RegisterEnvironment)) {
            throw (New-SBError 'cli.setup.conflict' @('-PreviewOnly / -Yes / -Apply / -RegisterEnvironment'))
        }
        $personalRoot=$null
        if ($PSBoundParameters.ContainsKey('TeamRoot')) {
            if ($TeamRoot -notmatch '^\\\\[^\\.?][^\\]*\\[^\\]+' -or ![IO.Directory]::Exists($TeamRoot)) {
                throw (New-SBError 'cli.setup.team.root')
            }
            if (!$PreviewOnly -and !$Interactive -and !($Yes -and $Apply)) {
                throw (New-SBError 'cli.setup.team.mode')
            }
            if (!$Roots.Count) { $Roots=@($brain) }
            $personalRoot=$brain
            $brain=[IO.Path]::GetFullPath($TeamRoot)
        }
        $result = Invoke-SBSetup -BrainRoot $brain -Roots $Roots -MaxDirectories $MaxDirectories -Select $Select -All:$All -Ides $Ides -AllIdes:$AllIdes -IdeAccount $IdeAccount `
            -McpTargets $McpTargets -ApproveMcpReadTools:$ApproveMcpReadTools -ApproveExistingBlocks:$ApproveExistingBlocks -Interactive:$Interactive -Yes:$Yes -Apply:$Apply -RegisterEnvironment:$RegisterEnvironment -NoRegisterEnvironment:$NoRegisterEnvironment -AndSync:$AndSync -SessionId $SessionId -PreviewOnly:$PreviewOnly -PersonalRoot $personalRoot
        if ($PreviewOnly -or $personalRoot) {
            $result.mode=if ($brain.StartsWith('\\')) {'team'} else {'single'}
            $result.brainRoot=$brain
        }
        ConvertTo-SBJson $result
        # 0: valid preview or activation applied; 1: unconfirmed proposal, paused discovery or unavailable subsequent check.
        if($result.Contains('mcp') -and $result.mcp.Contains('complete') -and !$result.mcp.complete){exit 1}
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
        ConvertTo-SBJson (Invoke-SBHostActivation -BrainRoot $brain -SelectionPath $SelectionPath -SessionId $SessionId -Apply:$Apply -RegisterEnvironment:($Apply -and !$NoRegisterEnvironment))
        exit 0
    }
    $config = Read-SBConfiguration $ConfigPath -ReadOnly:(!$Sync)
    if(!$Sync){
        $pendingWrites=Invoke-SBPendingWrites -BrainRoot $brain -Config $config -SessionId $SessionId
        if($pendingWrites.applied.Count -or $pendingWrites.conflicts.Count -or $pendingWrites.pending -or $pendingWrites.errors.Count){[Console]::Error.WriteLine((Format-SBPendingNotice $pendingWrites))}
    }
    $result = Invoke-SBPortableSync -Config $config -Check:(!$Sync) -SessionId $SessionId -ObservationPath $ObservationPath -Repository $Repository
    ConvertTo-SBJson $result
    if (!$result.aligned) { exit 1 }
    exit 0
} catch {
    if (Test-SBWriteDeniedError $_) { Write-SBWriteDeniedDiagnostic $_ $PSCommandPath $PSBoundParameters; exit 4 };
    $failure = $_
    $base = $failure.Exception.GetBaseException()
    if ($base -is [IO.IOException] -and ($base.HResult -band 0xffff) -in @(32, 33)) {
        Write-Output $failure.Exception.Message
        exit 3
    }
    Write-Error $failure -ErrorAction Continue
    exit 2
}
