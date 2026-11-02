#requires -Version 7.5
[CmdletBinding(DefaultParameterSetName='Check')]
param(
    [Parameter(Mandatory,ParameterSetName='Check')]
    [Parameter(Mandatory,ParameterSetName='InstallHook')]
    [Parameter(Mandatory,ParameterSetName='UninstallHook')]
    [Parameter(Mandatory,ParameterSetName='HookStatus')]
    [string]$RepositoryPath,

    [Parameter(ParameterSetName='Check')]
    [string]$PolicyPath,

    [Parameter(ParameterSetName='Check')]
    [string]$ReportPath,

    [Parameter(ParameterSetName='Check')]
    [int]$MaxHistoryBlobs=10000,

    [Parameter(ParameterSetName='Check')]
    [switch]$Initial,

    [Parameter(Mandatory,ParameterSetName='InstallHook')]
    [switch]$InstallHook,

    [Parameter(Mandatory,ParameterSetName='UninstallHook')]
    [switch]$UninstallHook,

    [Parameter(Mandatory,ParameterSetName='HookStatus')]
    [switch]$HookStatus,

    [Parameter(ParameterSetName='InstallHook')]
    [Parameter(ParameterSetName='UninstallHook')]
    [switch]$Apply,

    [Parameter(ParameterSetName='InstallHook')]
    [switch]$Force
)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Publication.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
$brain=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
try{
    if($InstallHook){
        $res=Install-SBPublicationHook -RepositoryPath $RepositoryPath -BrainRoot $brain -Apply:$Apply -Force:$Force
        ConvertTo-SBJson $res
        exit 0
    }
    if($UninstallHook){
        $res=Uninstall-SBPublicationHook -RepositoryPath $RepositoryPath -Apply:$Apply
        ConvertTo-SBJson $res
        exit 0
    }
    if($HookStatus){
        $res=Get-SBPublicationHookStatus -RepositoryPath $RepositoryPath
        ConvertTo-SBJson $res
        exit 0
    }
    $PolicyPath=Resolve-SBPublicationPolicyPath $brain $PolicyPath
    $report=Test-SBPublication -RepositoryPath $RepositoryPath -BrainRoot $brain -PolicyPath $PolicyPath -MaxHistoryBlobs $MaxHistoryBlobs -Initial:$Initial
    if($ReportPath){$path=Assert-SBCentralDataPath $brain $ReportPath;[IO.Directory]::CreateDirectory((Split-Path $path))|Out-Null;Write-SBFile $path ([Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $report))) (Get-SBFileHash $path) (Join-Path $brain '.runtime/backups/publication')|Out-Null}
    ConvertTo-SBJson $report
    if(!$report.complete){exit 2};if(!$report.ready){exit 1}
}catch{Write-Error $_ -ErrorAction Continue;exit 2}
