#requires -Version 7.5
<#
.SYNOPSIS
Source registry: local Check, remote Probe, candidate collection and index. No scheduled execution.
.DESCRIPTION
Exit: 0 normal, 1 pending changes/reviews, 2 error/incomplete coverage, 3 contention.
Check and Probe without SaveReport do not write. Collect does not accept a version.
#>
[CmdletBinding(DefaultParameterSetName='Check')]
param(
    [string]$ConfigPath,[string]$SessionId,
    [Parameter(ParameterSetName='Check')][switch]$Check,
    [Parameter(Mandatory,ParameterSetName='Probe')][switch]$Probe,
    [Parameter(ParameterSetName='Probe')][switch]$SaveReport,
    [Parameter(Mandatory,ParameterSetName='Collect')][switch]$Collect,
    [Parameter(Mandatory,ParameterSetName='Collect')][ValidatePattern('^[a-z0-9][a-z0-9-]{0,95}$')][string]$SourceId,
    [Parameter(ParameterSetName='Collect')][string]$PythonPath,
    [Parameter(Mandatory,ParameterSetName='Index')][switch]$BuildIndex
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
    $readonly=$PSCmdlet.ParameterSetName -in @('Check','Probe')
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
    if($BuildIndex){
        if($registry.archived){throw (New-SBError 'sourcescli.resource.archived')}
        $catalog=Get-SBSourceCatalog $registry
        foreach($view in @(@{name='catalog.json';text=$catalog.json},@{name='README.md';text=$catalog.markdown})){
            $path=Join-Path $registry.root $view.name
            Write-SBFile $path ([Text.Encoding]::UTF8.GetBytes($view.text)) (Get-SBFileHash $path) $config.backupRoot|Out-Null
        }
        'Indice fonti allineato';exit 0
    }
    if($Collect){
        if(!$PythonPath){$PythonPath=if($config.ContainsKey('sourcePythonPath')){$config.sourcePythonPath}else{Join-Path $config.runtimeRoot 'sources/python/Scripts/python.exe'}}
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
