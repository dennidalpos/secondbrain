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

    [Parameter(Mandatory,ParameterSetName='MigratePolicy')]
    [switch]$MigratePolicy,

    [Parameter(ParameterSetName='MigratePolicy')]
    [switch]$ApplyMigration,

    [Parameter(ParameterSetName='Check')]
    [int]$MaxHistoryBlobs=10000,

    [Parameter(ParameterSetName='Check')]
    [switch]$Initial,

    [Parameter(ParameterSetName='Check')]
    [switch]$PrePushInput,

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
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Add-SBMessages @{
    'publication.push.input' = @{ it = 'Aggiornamento pre-push Git non valido'; en = 'Invalid Git pre-push update' }
}
trap { if (Test-SBWriteDeniedError $_) { Write-SBWriteDeniedDiagnostic $_ $PSCommandPath $PSBoundParameters; exit 4 }; break }
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
    if($MigratePolicy){
        ConvertTo-SBJson (Move-SBPublicationPolicy -BrainRoot $brain -Apply:$ApplyMigration)
        exit 0
    }
    $PolicyPath=Resolve-SBPublicationPolicyPath $brain $PolicyPath
    $pushObjects=@(if($PrePushInput){
        while($null -ne ($update=[Console]::In.ReadLine())){
            if($update -cnotmatch '^(\S+) ([a-f0-9]{40}|[a-f0-9]{64}) \S+ ([a-f0-9]{40}|[a-f0-9]{64})$'){
                throw (New-SBError 'publication.push.input')
            }
            $deletion=$Matches[1] -ceq '(delete)'
            $localObject=$Matches[2]
            if($localObject.Length -ne $Matches[3].Length -or $deletion -ne ($localObject -match '^0+$')){
                throw (New-SBError 'publication.push.input')
            }
            if(!$deletion){$localObject}
        }
    })
    $report=Test-SBPublication -RepositoryPath $RepositoryPath -BrainRoot $brain -PolicyPath $PolicyPath -MaxHistoryBlobs $MaxHistoryBlobs -Initial:$Initial -PushObjectIds $pushObjects
    if($ReportPath){$path=Assert-SBCentralDataPath $brain $ReportPath;[IO.Directory]::CreateDirectory((Split-Path $path))|Out-Null;Write-SBFile $path ([Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $report))) (Get-SBFileHash $path) (Join-Path $brain '.runtime/backups/publication')|Out-Null}
    ConvertTo-SBJson $report
    if(!$report.complete){exit 2};if(!$report.ready){exit 1}
}catch{if(Test-SBWriteDeniedError $_){Write-SBWriteDeniedDiagnostic $_ $PSCommandPath $PSBoundParameters;exit 4};Write-Error $_ -ErrorAction Continue;exit 2}
