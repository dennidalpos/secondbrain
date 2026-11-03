#requires -Version 7.5
[CmdletBinding(DefaultParameterSetName='Prepare')]
param(
    [string]$ConfigPath,[string]$SessionId,
    [Parameter(Mandatory,ParameterSetName='Prepare')][string]$Repository,
    [Parameter(Mandatory,ParameterSetName='Prepare')][string]$SourcePath,
    [Parameter(ParameterSetName='Prepare')][string]$HistoryPath,
    [Parameter(ParameterSetName='Prepare')][string]$ReviewPath,
    [Parameter(Mandatory,ParameterSetName='Resume')][string]$ResumeManifest,
    [Parameter(Mandatory,ParameterSetName='Rollback')][string]$RollbackManifest,
    [Parameter(ParameterSetName='Prepare')][Parameter(ParameterSetName='Resume')][switch]$Activate,
    [switch]$Apply
)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1') -Force
# Scrittura occupata oltre l'attesa: exit 3 (il titolare e nel messaggio).
trap { if (Test-SBBusyError $_) { [Console]::Error.WriteLine($_.Exception.Message); exit 3 }; break }
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Para.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Tracker.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.TrackerImport.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Add-SBMessages @{
    'importtracker.source.diverged' = @{ it = 'Sorgente diversa dal tracker autorevole'; en = 'Source differs from the authoritative tracker' }
}
$config=Read-SBConfiguration $ConfigPath
$lock=Enter-SBOperation $config $SessionId -ReadOnly:(!$Apply)
try {
    if(!$Apply){
        if($ResumeManifest -or $RollbackManifest){Read-SBTrackerManifest $config $(if($ResumeManifest){$ResumeManifest}else{$RollbackManifest})|ConvertTo-SBJson}
        else{
            $resolved=Resolve-SBTracker -BrainRoot $config.brainRoot -Identity $Repository -CheckoutPath (Split-Path ([IO.Path]::GetFullPath($SourcePath))) -AllowedOwners $config.allowedOwners
            if(!$resolved.path -or [IO.Path]::GetFullPath($resolved.path) -ne [IO.Path]::GetFullPath($SourcePath)){throw (New-SBError 'importtracker.source.diverged')}
            $data=ConvertTo-SBTracker -SourcePath $SourcePath -Identity $Repository -HistoryPath $HistoryPath -ReviewPath $ReviewPath
            $entities=@(Get-SBParaEntities $config.brainRoot $config.allowedOwners)
            [void](Test-SBTrackerData $data $Repository @($entities|Where-Object kind -eq 'area'|ForEach-Object repository) (Join-Path $PSScriptRoot '../config/tracker.schema.json') (Get-SBTrackerRelatedData $config.brainRoot $Repository $entities))
            ConvertTo-SBJson @{mode='preview';repository=$Repository;tasks=$data.tasks.Count;review=@($data.tasks|Where-Object status -eq 'unknown'|ForEach-Object id);activationApproved=Test-SBTrackerPolicy $config.brainRoot}
        }
        exit 0
    }
    if($RollbackManifest){Restore-SBTrackerImport $config $RollbackManifest;'Importazione tracker ripristinata';exit 0}
    $arguments=@{Config=$config;Activate=$Activate}
    if($ResumeManifest){$arguments.ManifestPath=$ResumeManifest}else{$arguments.Identity=$Repository;$arguments.SourcePath=$SourcePath;$arguments.HistoryPath=$HistoryPath;$arguments.ReviewPath=$ReviewPath}
    $manifest=Invoke-SBTrackerImport @arguments
    $state=Read-SBTrackerManifest $config $manifest
    'Migrazione tracker: '+$state.phase+'; manifest='+$manifest
    if($state.phase -ne 'completed'){'Fonte precedente ancora autorevole; attivazione separata dopo approvazione';exit 1}
    exit 0
} finally {Exit-SBOperation $lock}
