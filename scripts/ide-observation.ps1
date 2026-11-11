#requires -Version 7.5
<#
.SYNOPSIS
Delegated IDE/agent verification: instruction package, receipt registration and pruning (#155).
.DESCRIPTION
-Operation Package -IdeId <id>: prints the instructions an installed agent follows in a NEW session and the receipt template (read-only).
-Operation Register -IdeId <id> -InputPath <receipt.json>: validates the receipt like ide-map.ps1 -Verify and previews it;
with -PreviewSha256 <previewed hash> and -Apply it stores it in .runtime/hosts/<host>/ide-observations.json. A missing or different hash is rejected before any write.
-Operation Prune: previews/removes receipts of integrations no longer in the map (for example after -Unbind).
Never edits IDE files, reads authentication stores or automates login. Verify with: ide-map.ps1 -Verify -ObservationPath <store>.
.EXAMPLE
pwsh -NoProfile -File scripts/ide-observation.ps1 -Operation Package -IdeId claude-desktop-work
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Package','Register','Prune')][string]$Operation,
    [string]$IdeId,[string]$InputPath,[string]$PreviewSha256,
    [string]$ConfigPath,[string]$SessionId,[switch]$Apply,[ValidateSet('it','en')][string]$Language
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($Language){$env:SECONDBRAIN_LANG=$Language}
foreach($m in 'Core','Access','Host','IdeObservation'){Import-Module (Join-Path $PSScriptRoot ('SecondBrain.'+$m+'.psm1'))}
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
$config=Read-SBConfiguration $ConfigPath -ReadOnly:(!$Apply)
$mapPath=Join-Path $config.localStateRoot 'ide-map.json'
$globalPath=Join-Path $config.localStateRoot 'istruzioni-globali.md'
if(!(Test-Path -LiteralPath $mapPath) -or !(Test-Path -LiteralPath $globalPath)){throw (New-SBError 'ideobs.invalid' @('map or global text absent; run secondbrain.ps1 -Sync'))}
$map=Read-SBJson $mapPath $null
if(!$map -or $map.schemaVersion -ne 1 -or $map.workstationId -ne $config.workstationId -or $map.ides -isnot [array]){throw (New-SBError 'ideobs.invalid' @('ide map'))}
$global=Read-SBText $globalPath
if($Operation -in @('Package','Register') -and !$IdeId){throw (New-SBError 'ideobs.invalid' @('IdeId'))}
if($Operation -eq 'Package'){
    $ide=@($map.ides|Where-Object {$_ -is [Collections.IDictionary] -and $_.ContainsKey('id') -and $_.id -ceq $IdeId})
    if($ide.Count -ne 1){throw (New-SBError 'ideobs.invalid' @('ide id'))}
    ConvertTo-SBJson (Get-SBIdeObservationPackage $ide[0] $global $config.brainRoot $config.workstationId);exit 0
}
$owned=$null;$lock=$null
try{
    if($Apply -and !$SessionId){$owned=& (Join-Path $PSScriptRoot 'access.ps1') -Start -Mode Write -Client ide-observation -ConfigPath $config.configPath|ConvertFrom-Json -AsHashtable;$SessionId=$owned.sessionId}
    $lock=Enter-SBOperation $config $SessionId -ReadOnly:(!$Apply)
    $result=switch($Operation){
        'Register' {
            if(!$InputPath){throw (New-SBError 'ideobs.invalid' @('InputPath'))}
            Assert-SBCentralDataPath $config.brainRoot $InputPath|Out-Null
            if(([IO.FileInfo]::new($InputPath)).Length -gt 1MB){throw (New-SBError 'ideobs.invalid' @('input size'))}
            $receipt=Get-Content -LiteralPath $InputPath -Raw|ConvertFrom-Json -AsHashtable -DateKind String
            Register-SBIdeObservation $map $IdeId $receipt $global $config.brainRoot $config.workstationId $config.backupRoot -Apply:$Apply -PreviewSha256 $PreviewSha256
        }
        'Prune' {Remove-SBStaleIdeObservations $map $config.brainRoot $config.backupRoot -Apply:$Apply}
    }
    ConvertTo-SBJson $result
}finally{
    if($lock){Exit-SBOperation $lock}
    if($owned){& (Join-Path $PSScriptRoot 'access.ps1') -End -SessionId $SessionId -ConfigPath $config.configPath|Out-Null}
}
