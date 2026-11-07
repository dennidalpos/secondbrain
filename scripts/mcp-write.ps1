#requires -Version 7.5
[CmdletBinding()]
param([Parameter(Mandatory)][switch]$Approve,[Parameter(Mandatory)][string]$PlanPath,
    [Parameter(Mandatory)][string]$ExpectedPlanHash,[Parameter(Mandatory)][string]$Authorization,
    [Parameter(Mandatory)][string]$SessionId,[string]$ConfigPath)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.McpWrites.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Add-SBMessages @{
    'mcpwritecli.size' = @{it='Il piano supera il limite di 256 KiB';en='Plan exceeds the 256 KiB limit'}
}
$lock=$null
try {
    Assert-SBPlainPath $PlanPath
    if((Get-Item -LiteralPath $PlanPath).Length -gt 256KB){throw (New-SBError 'mcpwritecli.size')}
    $plan=Read-SBJson $PlanPath $null
    $brain=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    $config=Read-SBConfiguration $ConfigPath
    $lock=Enter-SBOperation $config $SessionId
    $result=Approve-SBMcpWritePlan $brain $ConfigPath $plan $ExpectedPlanHash $Authorization $SessionId
    ConvertTo-SBJson $result
}catch{
    if(Test-SBWriteDeniedError $_){Write-SBWriteDeniedDiagnostic $_ $PSCommandPath $PSBoundParameters;exit 4}
    if(Test-SBBusyError $_){[Console]::Error.WriteLine($_.Exception.Message);exit 3}
    Write-Error $_ -ErrorAction Continue;exit 2
}finally{Exit-SBOperation $lock}