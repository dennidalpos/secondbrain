#requires -Version 7.5
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Capture','Promote','Index','Context','Maintenance','Adapter')][string]$Operation,
    [string]$Repository,[string]$InputPath,[string]$Workspace,[string[]]$AttachmentPath=@(),
    [string[]]$TaskIds=@(),[string]$PreviousRevision,[int]$Budget=30000,
    [ValidateSet('claude-code','codex','antigravity','vscode','android-studio','claude','cursor','windsurf','continue','jetbrains')][string]$Client='codex',
    [string]$ConfigPath,[string]$SessionId,[string]$ObservationPath,[switch]$Apply,[ValidateSet('it','en')][string]$Language
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($Language){$env:SECONDBRAIN_LANG=$Language}
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.MemoryCycle.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Add-SBMessages @{'cycle.invalid'=@{it='Ciclo memorie: input non valido ({0})';en='Memory cycle: invalid input ({0})'}}
$brain=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if($Operation -eq 'Adapter'){ConvertTo-SBJson (Get-SBCycleAdapter $Client $brain $Repository $ObservationPath);exit 0}
$inputObject=$null
if($Operation -in @('Capture','Promote')){
    if(!$InputPath){throw (New-SBError 'cycle.invalid' @('InputPath'))}
    Assert-SBPlainPath $InputPath
    if(([IO.FileInfo]::new($InputPath)).Length -gt 8MB){throw (New-SBError 'cycle.invalid' @('input > 8 MiB'))}
    $inputObject=Read-SBJson $InputPath $null
    # Return before configuration, sessions, workspaces or pending-write recovery can write anything.
    if(!(Test-SBCyclePersistence $inputObject)){ConvertTo-SBJson @{state='suppressed';writes=0};exit 0}
    if($Repository -and $Repository -cne $inputObject.repository){throw (New-SBError 'cycle.invalid' @('repository mismatch'))}
    $Repository=$inputObject.repository
}
if(!$Repository){throw (New-SBError 'cycle.invalid' @('Repository'))}
$dossier=Resolve-SBCycleDossier $brain $Repository
if($Operation -eq 'Context'){ConvertTo-SBJson (Get-SBCycleContext $brain $Repository $TaskIds $PreviousRevision $Budget);exit 0}
if($Operation -eq 'Maintenance'){
    if($Apply){throw (New-SBError 'cycle.invalid' @('Maintenance is inventory only; apply reviewed SYS05 candidates separately'))}
    $index=Get-SBCycleKnowledgeIndex $brain $Repository
    ConvertTo-SBJson @{repository=$Repository;revision=$index.revision;batches=@($index.entries|Group-Object topic|ForEach-Object {@{topic=$_.Name;sources=@($_.Group);requires='SYS05 preview and explicit batch confirmation'}})}
    exit 0
}
$config=Read-SBConfiguration $ConfigPath -ReadOnly:(!$Apply)
if(!$Apply -and $Operation -eq 'Capture' -and !$Workspace){ConvertTo-SBJson (ConvertTo-SBCycleTurn $inputObject);exit 0}
$owned=$null;$lock=$null
try{
    if($Apply -and !$SessionId){$owned=& (Join-Path $PSScriptRoot 'access.ps1') -Start -Mode Write -Client memory-cycle -Repository $Repository -ConfigPath $config.configPath|ConvertFrom-Json -AsHashtable;$SessionId=$owned.sessionId}
    $lock=Enter-SBOperation $config $SessionId -ReadOnly:(!$Apply)
    if($Operation -eq 'Capture' -and !$Workspace){
        $slug='memcycle-'+(Get-SBTextHash ($Repository+':'+$inputObject.client+':'+$inputObject.sessionId)).Substring(0,16).ToLowerInvariant()
        $work=& (Join-Path $PSScriptRoot 'work.ps1') -Repository $Repository -Category evidence -Slug $slug -Init -Task 'memory cycle current session' -SessionId $SessionId -ConfigPath $config.configPath|ConvertFrom-Json -AsHashtable
        $Workspace=$work.root
    }
    $result=switch($Operation){
        'Capture' {Save-SBCycleTurn -BrainRoot $brain -Envelope $inputObject -Workspace $Workspace -BackupRoot $config.backupRoot -AllowedAttachmentPaths $AttachmentPath -Apply:$Apply}
        'Promote' {Invoke-SBCyclePromotion -BrainRoot $brain -Candidate $inputObject -Workspace $Workspace -BackupRoot $config.backupRoot -Apply:$Apply}
        'Index' {Save-SBCycleKnowledgeIndex $brain $Repository $config.backupRoot -Apply:$Apply}
    }
    ConvertTo-SBJson $result
}finally{
    if($lock){Exit-SBOperation $lock}
    if($owned){& (Join-Path $PSScriptRoot 'access.ps1') -End -SessionId $SessionId -ConfigPath $config.configPath|Out-Null}
}
