#requires -Version 7.5
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Repository,[Parameter(Mandatory)][string]$Target,
    [Parameter(Mandatory)][string]$OutputDirectory,[string]$CheckoutPath=(Get-Location).Path,
    [switch]$Apply,[string]$ExpectedPlanHash,[string]$ConfigPath,[string]$SessionId)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Sandbox.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
$lock=$null
try {
    $config=Read-SBConfiguration $ConfigPath -ReadOnly:(!$Apply)
    if($Apply){
        $lock=Enter-SBOperation $config $SessionId
        $result=Set-SBSandboxConfiguration $config $Repository $CheckoutPath $Target $OutputDirectory $ExpectedPlanHash $SessionId
    }else{
        # Preview neither acquires a lease nor flushes pending writes.
        $result=Get-SBSandboxPlan $config $Repository $CheckoutPath $Target $OutputDirectory
    }
    ConvertTo-SBJson $result
}catch{
    if(Test-SBWriteDeniedError $_){Write-SBWriteDeniedDiagnostic $_ $PSCommandPath $PSBoundParameters;exit 4}
    if(Test-SBBusyError $_){[Console]::Error.WriteLine($_.Exception.Message);exit 3}
    Write-Error $_ -ErrorAction Continue;exit 2
}finally{Exit-SBOperation $lock}