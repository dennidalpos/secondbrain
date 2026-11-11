#requires -Version 7.5
<#
.SYNOPSIS
Team activity register (F6): validation, derived index/map and Trace import.
.DESCRIPTION
-Operation Validate: reads history/activity/report.md and reports records (read-only).
-Operation Index: previews the derived index.json and map.md (Mermaid); -Apply writes them (never edits the log).
-Operation Trace: previews register records derived from metadata-only Trace turns; -Apply appends them and
requires activityLogEnabled=true in the configuration (real activation is a separate, explicit step).
-Operation Retention: previews replacing named records older than -RetentionMonths (default 12, relative to -AsOf, default today UTC) with user-free aggregates in retention.json; -Apply requires the -PreviewSha256 shown by the preview and rewrites the log once without a binary backup of the expired records, then regenerates existing views.
-Operation RetentionBackups: lists register backups in backupRoot that still hold named records and are recoverable without them (index/map copies, log copies whose records are expired or unchanged in the current log); blocked items are kept. -Apply needs -PreviewSha256 and a log with no expired records, re-checks hashes and removes only the listed .bin/.bin.json pairs.
.EXAMPLE
pwsh -NoProfile -File scripts/activity.ps1 -Operation Validate -Repository github.com/my-org/my-product
pwsh -NoProfile -File scripts/activity.ps1 -Operation Index -Repository github.com/my-org/my-product -Apply
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Validate','Index','Trace','Retention','RetentionBackups')][string]$Operation,
    [Parameter(Mandatory)][string]$Repository,
    [string]$Since,[string]$AsOf,[ValidateRange(1,120)][int]$RetentionMonths=12,[string]$PreviewSha256,[string]$ConfigPath,[string]$SessionId,[switch]$Apply,[ValidateSet('it','en')][string]$Language
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($Language){$env:SECONDBRAIN_LANG=$Language}
foreach($m in 'Core','Access','Host','Para','Knowledge','Activity'){Import-Module (Join-Path $PSScriptRoot ('SecondBrain.'+$m+'.psm1'))}
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
$brain=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if(!(Test-SBRepositoryIdentity $Repository)){throw (New-SBError 'activity.invalid' @('repository'))}
$dossier=Resolve-SBParaPath $brain (Resolve-SBWorkingDossier $brain $Repository)
if($Operation -eq 'Validate'){
    $log=Read-SBActivityLog $dossier
    ConvertTo-SBJson @{state='valid';records=$log.records.Count;sourceSha256=$log.hash};exit 0
}
$sinceValue=[DateTimeOffset]::MinValue
if($Since -and ![DateTimeOffset]::TryParse($Since,[ref]$sinceValue)){throw (New-SBError 'activity.invalid' @('since'))}
$asOfValue=[DateTimeOffset]::UtcNow
if($AsOf -and ![DateTimeOffset]::TryParse($AsOf,[ref]$asOfValue)){throw (New-SBError 'activity.invalid' @('asOf'))}
$config=Read-SBConfiguration $ConfigPath -ReadOnly:(!$Apply)
$owned=$null;$lock=$null
try{
    if($Apply -and !$SessionId){$owned=& (Join-Path $PSScriptRoot 'access.ps1') -Start -Mode Write -Client activity -Repository $Repository -ConfigPath $config.configPath|ConvertFrom-Json -AsHashtable;$SessionId=$owned.sessionId}
    $lock=Enter-SBOperation $config $SessionId -ReadOnly:(!$Apply)
    $result=switch($Operation){
        'Retention' {Invoke-SBActivityRetention $dossier $asOfValue $config.backupRoot $RetentionMonths -Apply:$Apply -PreviewSha256:$PreviewSha256}
        'RetentionBackups' {Invoke-SBActivityBackupRetention $dossier $asOfValue $config.backupRoot $RetentionMonths -Apply:$Apply -PreviewSha256:$PreviewSha256}
        'Index' {Save-SBActivityViews $dossier $config.backupRoot -Apply:$Apply}
        'Trace' {
            $records=Get-SBActivityFromTrace $brain $Repository ([Security.Principal.WindowsIdentity]::GetCurrent().Name) ([Environment]::MachineName) $sinceValue
            Add-SBActivityRecords $dossier $records $config.backupRoot $config -Apply:$Apply
        }
    }
    ConvertTo-SBJson $result
}finally{
    if($lock){Exit-SBOperation $lock}
    if($owned){& (Join-Path $PSScriptRoot 'access.ps1') -End -SessionId $SessionId -ConfigPath $config.configPath|Out-Null}
}
