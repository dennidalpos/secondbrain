#requires -Version 7.5
<#
.SYNOPSIS
03-resources: layout check, control files and indexes, and sync of the authoritative-source registry.
.DESCRIPTION
Check (default) is read-only: layout, CONTROL.json drift, INDEX.md drift. BuildIndex rewrites CONTROL.json and INDEX.md
for every resource folder. Sync probes the registry, collects new candidate versions (never accepting them, never
removing existing versions), follows related sources and detected references up to MaxDepth/MaxSources, queues what
it cannot resolve in normative-queue.json, then rebuilds the indexes. With IfStale, Sync runs only when the latest
probe report is older than 14 days. Originals are not in Git (#478): Sync and Restore download every missing original of a public-reusable source again, write it only if its SHA-256 equals the manifest and report a different content. Exit: 0 normal, 1 pending issues, 2 error, 3 contention, 4 write denied.
#>
[CmdletBinding(DefaultParameterSetName='Check')]
param(
    [string]$ConfigPath,[string]$SessionId,
    [Parameter(ParameterSetName='Check')][switch]$Check,
    [Parameter(Mandatory,ParameterSetName='Index')][switch]$BuildIndex,
    [Parameter(Mandatory,ParameterSetName='Restore')][switch]$Restore,
    [Parameter(Mandatory,ParameterSetName='Sync')][switch]$Sync,
    [Parameter(ParameterSetName='Sync')][switch]$IfStale,
    [Parameter(ParameterSetName='Sync')][string]$PythonPath,
    [Parameter(ParameterSetName='Sync')][ValidateRange(0,10)][int]$MaxDepth=3,
    [Parameter(ParameterSetName='Sync')][ValidateRange(1,500)][int]$MaxSources=50
)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1') -Force
trap { if (Test-SBWriteDeniedError $_) { Write-SBWriteDeniedDiagnostic $_ $PSCommandPath $PSBoundParameters; exit 4 }; break }
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Sources.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Resources.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
$lock=$null
try {
    $config=Read-SBConfiguration $ConfigPath
    $writes=$PSCmdlet.ParameterSetName -in @('Index','Sync','Restore')
    $lock=Enter-SBOperation $config $SessionId -ReadOnly:(!$writes)
    if($BuildIndex){
        ConvertTo-SBJson @{schemaVersion=1;written=@(Update-SBResourceViews $config)}
        exit 0
    }
    if($Restore){
        $registry=Read-SBSourceRegistry $config.brainRoot
        $restore=Restore-SBSourceOriginals $config $registry
        ConvertTo-SBJson @{schemaVersion=1;restored=@($restore.restored).Count;failed=@($restore.failed)}
        if(@($restore.failed).Count){exit 1};exit 0
    }
    if($Sync){
        if($IfStale -and !(Test-SBResourceStale $config)){ConvertTo-SBJson @{schemaVersion=1;status='fresh'};exit 0}
        if(!$PythonPath){$PythonPath=if($config.ContainsKey('sourcePythonPath')){$config.sourcePythonPath}else{Join-Path $config.localStateRoot 'sources/python/Scripts/python.exe'}}
        $registry=Read-SBSourceRegistry $config.brainRoot
        $result=Invoke-SBResourceSync $config $registry $PythonPath $MaxDepth $MaxSources
        ConvertTo-SBJson $result
        if(!$result.complete -or $result.queued -or @($result.restoreFailed).Count -or @($result.collected|Where-Object {$_.status -notin @('extracted','unchanged')}).Count){exit 1};exit 0
    }
    $issues=@(Get-SBResourceChecks $config.brainRoot)
    ConvertTo-SBJson @{schemaVersion=1;issues=$issues}
    if($issues.Count){exit 1};exit 0
} catch {
    if (Test-SBWriteDeniedError $_) { Write-SBWriteDeniedDiagnostic $_ $PSCommandPath $PSBoundParameters; exit 4 };
    $busy=$_.Exception -is [IO.IOException] -and $_.Exception.Data['code'] -ceq 'access.busy'
    Write-Error $_ -ErrorAction Continue
    if($busy){exit 3};exit 2
} finally {Exit-SBOperation $lock}
