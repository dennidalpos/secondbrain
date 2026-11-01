#requires -Version 7.5
[CmdletBinding(DefaultParameterSetName='Capture')]
param([Parameter(Mandatory)][string]$RepositoryPath,[Parameter(Mandatory)][string]$ManifestPath,[string]$ConfigPath,[string]$SessionId,
    [Parameter(Mandatory,ParameterSetName='Capture')][string]$SourcePath,[Parameter(Mandatory,ParameterSetName='Capture')][string]$Application,
    [Parameter(Mandatory,ParameterSetName='Capture')][string]$Version,[Parameter(Mandatory,ParameterSetName='Capture')][string]$Scenario,
    [Parameter(Mandatory,ParameterSetName='Capture')][string]$CaptureTool,[Parameter(Mandatory,ParameterSetName='Capture')][string]$Reproduction,
    [Parameter(Mandatory,ParameterSetName='Export')][switch]$Export,[Parameter(Mandatory,ParameterSetName='Export')][string]$Name,
    [Parameter(ParameterSetName='Export')][switch]$Apply)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Host.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Publication.psm1')
$config=Read-SBConfiguration $ConfigPath;$lock=Enter-SBOperation $config $SessionId -ReadOnly:($Export -and !$Apply)
try{
    if($Export){ConvertTo-SBJson (Export-SBPublicCapture -BrainRoot $config.brainRoot -ManifestPath $ManifestPath -RepositoryPath $RepositoryPath -Name $Name -BackupRoot $config.backupRoot -Apply:$Apply -Bindings $config.bindings)}
    else{
        $checkout=Get-SBCheckoutAsset $RepositoryPath $config.bindings
        if(!@($config.bindings|Where-Object {$_.path -eq $checkout.path -and $_.identity -ceq $checkout.identity}).Count){throw 'Repository non gestito'}
        $commit=Invoke-SBGit $checkout.path @('rev-parse','HEAD');$status=Invoke-SBGit $checkout.path @('status','--porcelain=v1')
        if($commit.code -ne 0){throw 'Registrare un commit di riferimento prima della cattura'}
        $record=New-SBCaptureRecord -BrainRoot $config.brainRoot -SourcePath $SourcePath -Repository $checkout.identity -Application $Application -Version $Version -Commit $commit.output -Dirty:([bool]$status.output) -Scenario $Scenario -CaptureTool $CaptureTool -Reproduction $Reproduction
        $path=Assert-SBCentralDataPath $config.brainRoot $ManifestPath
        [IO.Directory]::CreateDirectory((Split-Path $path))|Out-Null
        Write-SBFile $path ([Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $record))) 'absent' $config.backupRoot|Out-Null
        ConvertTo-SBJson $record
    }
}finally{Exit-SBOperation $lock}
