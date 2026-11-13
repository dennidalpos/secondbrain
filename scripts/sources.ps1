#requires -Version 7.5
<#
.SYNOPSIS
Source registry: local Check, remote Probe, candidate collection and index. No scheduled execution.
.DESCRIPTION
Exit: 0 normal, 1 pending changes/reviews, 2 error/incomplete coverage, 3 contention, 4 write denied.
Check and Probe without SaveReport do not write. Collect does not accept a version.
Decide closes a version: reject (candidate no longer pending), accept (verified version, or candidate with -ReviewScope and the
three -Reviewed* confirmations), known-variant (verified version the live endpoint may return again). Each decision is appended
to entries/<id>/decisions.json. AddEffectiveDate records an effective date; an unknown date stays requires-verification without -Date.
Propose (read-only, no network) prints the proposed card (metadata.json, always reference-only) for every unresolved reference in normative-queue.json, or for -Reference (with -SourceId as origin when the reference is not in the queue).
.EXAMPLE
pwsh -NoProfile -File scripts/sources.ps1 -Decide -SourceId nist-ssdf -VersionId 20261110-1241458c6d8c85b3 -Decision reject -Reason "Identical PDF" -DecidedBy "Owner" -SessionId <id>
#>
[CmdletBinding(DefaultParameterSetName='Check')]
param(
    [string]$ConfigPath,[string]$SessionId,
    [Parameter(ParameterSetName='Check')][switch]$Check,
    [Parameter(Mandatory,ParameterSetName='Probe')][switch]$Probe,
    [Parameter(ParameterSetName='Probe')][switch]$SaveReport,
    [Parameter(Mandatory,ParameterSetName='Collect')][switch]$Collect,
    [Parameter(Mandatory,ParameterSetName='Collect')][Parameter(Mandatory,ParameterSetName='Decide')][Parameter(Mandatory,ParameterSetName='EffectiveDate')][Parameter(ParameterSetName='Propose')][ValidatePattern('^[a-z0-9][a-z0-9-]{0,95}$')][string]$SourceId,
    [Parameter(Mandatory,ParameterSetName='Propose')][switch]$Propose,
    [Parameter(ParameterSetName='Collect')][string]$PythonPath,
    [Parameter(Mandatory,ParameterSetName='Index')][switch]$BuildIndex,
    [Parameter(Mandatory,ParameterSetName='Decide')][switch]$Decide,
    [Parameter(Mandatory,ParameterSetName='Decide')][ValidatePattern('^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,95}$')][string]$VersionId,
    [Parameter(Mandatory,ParameterSetName='Decide')][ValidateSet('accept','reject','known-variant')][string]$Decision,
    [Parameter(Mandatory,ParameterSetName='Decide')][string]$Reason,
    [Parameter(Mandatory,ParameterSetName='Decide')][string]$DecidedBy,
    [Parameter(ParameterSetName='Decide')][string]$ReviewScope,
    [Parameter(ParameterSetName='Decide')][switch]$ReviewedStructure,
    [Parameter(ParameterSetName='Decide')][switch]$ReviewedNumbersAndTables,
    [Parameter(ParameterSetName='Decide')][switch]$ReviewedCitedPassages,
    [Parameter(Mandatory,ParameterSetName='EffectiveDate')][switch]$AddEffectiveDate,
    [Parameter(Mandatory,ParameterSetName='EffectiveDate')][string]$Provision,
    [Parameter(ParameterSetName='EffectiveDate')][string]$Date,
    [Parameter(Mandatory,ParameterSetName='EffectiveDate')][ValidateSet('verified','requires-verification')][string]$DateStatus,
    [Parameter(Mandatory,ParameterSetName='EffectiveDate')][Parameter(ParameterSetName='Propose')][string]$Reference
)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1') -Force
trap { if (Test-SBWriteDeniedError $_) { Write-SBWriteDeniedDiagnostic $_ $PSCommandPath $PSBoundParameters; exit 4 }; break }
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Sources.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Add-SBMessages @{
    'sourcescli.resource.archived' = @{ it = 'Risorsa archiviata'; en = 'Archived resource' }
}
$lock=$null
try {
    $config=Read-SBConfiguration $ConfigPath
    $readonly=$PSCmdlet.ParameterSetName -in @('Check','Probe','Propose')
    $lock=Enter-SBOperation $config $SessionId -ReadOnly:$readonly
    $registry=Read-SBSourceRegistry $config.brainRoot
    if($Probe){
        # Network operations hold no archive lock. Card fingerprints bind the report to the snapshot.
        Exit-SBOperation $lock;$lock=$null
        $report=Invoke-SBSourceProbe $registry
        if($SaveReport){
            $lock=Enter-SBOperation $config $SessionId
            $report['reportPath']=Save-SBSourceReport $config $report
        }
        ConvertTo-SBJson $report
        if(!$report.complete){exit 2}
        if(@($report.sources|Where-Object status -in @('changed','unbaselined')).Count){exit 1}
        exit 0
    }
    if($Propose){
        # Read-only: proposes metadata.json for references in the review queue (or for -Reference); never downloads.
        ConvertTo-SBJson (Get-SBSourceCardProposals $registry $Reference $SourceId);exit 0
    }
    if($BuildIndex){
        if($registry.archived){throw (New-SBError 'sourcescli.resource.archived')}
        $null=Write-SBSourceIndex $config $config.brainRoot
        'Indice fonti allineato';exit 0
    }
    if($Decide){
        $review=if($ReviewScope -or $ReviewedStructure -or $ReviewedNumbersAndTables -or $ReviewedCitedPassages){@{scope=$ReviewScope;structure=$ReviewedStructure.IsPresent;numbersAndTables=$ReviewedNumbersAndTables.IsPresent;citedPassages=$ReviewedCitedPassages.IsPresent}}else{$null}
        ConvertTo-SBJson (Invoke-SBSourceDecision $config $registry $SourceId $VersionId $Decision $Reason $DecidedBy $review);exit 0
    }
    if($AddEffectiveDate){
        ConvertTo-SBJson (Add-SBSourceEffectiveDate $config $registry $SourceId $Provision $Date $DateStatus $Reference);exit 0
    }
    if($Collect){
        if(!$PythonPath){$PythonPath=if($config.ContainsKey('sourcePythonPath')){$config.sourcePythonPath}else{Join-Path $config.localStateRoot 'sources/python/Scripts/python.exe'}}
        $collected=Invoke-SBSourceCollect $config $registry $SourceId $PythonPath
        ConvertTo-SBJson $collected
        if($collected.status -in @('extracted','unchanged')){exit 0};exit 1
    }
    $issues=@(Get-SBSourceChecks $registry $config -IncludeDossiers)
    ConvertTo-SBJson @{schemaVersion=1;sources=$registry.sources.Count;issues=$issues}
    if($issues.Count){exit 1};exit 0
} catch {
    if (Test-SBWriteDeniedError $_) { Write-SBWriteDeniedDiagnostic $_ $PSCommandPath $PSBoundParameters; exit 4 };
    $busy=$_.Exception -is [IO.IOException] -and $_.Exception.Data['code'] -ceq 'access.busy'
    Write-Error $_ -ErrorAction Continue
    if($busy){exit 3};exit 2
} finally {Exit-SBOperation $lock}
