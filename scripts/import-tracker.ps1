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
# Writer busy beyond the wait limit: exit 3 (the message identifies the owner).
trap { if (Test-SBWriteDeniedError $_) { Write-SBWriteDeniedDiagnostic $_ $PSCommandPath $PSBoundParameters; exit 4 }; if (Test-SBBusyError $_) { [Console]::Error.WriteLine($_.Exception.Message); exit 3 }; break }
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
        if($ResumeManifest -or $RollbackManifest){
            $manifestPath=if($ResumeManifest){$ResumeManifest}else{$RollbackManifest}
            $manifest=Read-SBTrackerManifest $config $manifestPath
            ConvertTo-SBJson $manifest
        }
        else{
            $resolved=Resolve-SBTracker -BrainRoot $config.brainRoot -Identity $Repository -CheckoutPath (Split-Path ([IO.Path]::GetFullPath($SourcePath))) -AllowedOwners $config.allowedOwners -AllowUndeclaredImportSource
            if(!$resolved.path -or [IO.Path]::GetFullPath($resolved.path) -ne [IO.Path]::GetFullPath($SourcePath)){throw (New-SBError 'importtracker.source.diverged')}
            $data=ConvertTo-SBTracker -SourcePath $SourcePath -Identity $Repository -HistoryPath $HistoryPath -ReviewPath $ReviewPath
            $null = @(Get-SBParaEntities $config.brainRoot $config.allowedOwners)
            Assert-SBTrackerWriteData $config.brainRoot $Repository $data
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
