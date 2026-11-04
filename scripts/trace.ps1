#requires -Version 7.5
<#
.SYNOPSIS
End-of-turn trace for compaction advice (Claude Code Stop hook).
.DESCRIPTION
-Event stop appends a metadata-only line (time, session, repository, folder hash) to .runtime/trace/<workstation>/<date>.jsonl,
reading optional hook JSON from stdin. Contains no prompt text, uses no writer lock, does not measure context and
fails open: always exits 0 and never blocks the turn. Reading and advice live in secondbrain.ps1 -Check.
-InstallHook / -UninstallHook / -HookStatus manage the Stop entry in ~/.claude/settings.json (or -SettingsPath): without -Apply,
preview only; with -Apply, save with backup; leave other tools' entries untouched.
.EXAMPLE
pwsh -NoProfile -File scripts/trace.ps1 -InstallHook
pwsh -NoProfile -File scripts/trace.ps1 -InstallHook -Apply -SessionId <id di una sessione Write>
#>
[CmdletBinding(DefaultParameterSetName='Event')]
param(
    [Parameter(Mandatory,ParameterSetName='Event')][ValidateSet('stop')][string]$Event,
    [Parameter(ParameterSetName='Event')][string]$Ide='claude-code',
    [Parameter(Mandatory,ParameterSetName='Install')][switch]$InstallHook,
    [Parameter(Mandatory,ParameterSetName='Uninstall')][switch]$UninstallHook,
    [Parameter(Mandatory,ParameterSetName='Status')][switch]$HookStatus,
    [Parameter(ParameterSetName='Install')][Parameter(ParameterSetName='Uninstall')][switch]$Apply,
    [Parameter(ParameterSetName='Install')][Parameter(ParameterSetName='Uninstall')][Parameter(ParameterSetName='Status')][string]$SettingsPath,
    [Parameter(ParameterSetName='Install')][Parameter(ParameterSetName='Uninstall')][string]$ConfigPath,
    [Parameter(ParameterSetName='Install')][Parameter(ParameterSetName='Uninstall')][string]$SessionId,
    [ValidateSet('en','it')][string]$Language
)
if($Language){$env:SECONDBRAIN_LANG=$Language}
$brain=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if($PSCmdlet.ParameterSetName -eq 'Event'){
    # Fail-open: ignore every error; never block the turn.
    try{
        Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Trace.psm1')
        $stdin=''
        if([Console]::IsInputRedirected){$stdin=[Console]::In.ReadToEnd()}
        [void](Add-SBTraceEvent $brain $Event $stdin $Ide)
    }catch{
        # stderr never becomes a blocking hook response; diagnostics must also be fail-open.
        try {
            Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
            [Console]::Error.WriteLine('[trace.event.lost] ' + (Get-SBMessage 'trace.event.lost' @($_.Exception.Message)))
        } catch {}
    }
    exit 0
}
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1') -Force
# Writer busy beyond the wait limit: exit 3 (the message identifies the owner).
trap { if (Test-SBWriteDeniedError $_) { Write-SBWriteDeniedDiagnostic $_ $PSCommandPath $PSBoundParameters; exit 4 }; if (Test-SBBusyError $_) { [Console]::Error.WriteLine($_.Exception.Message); exit 3 }; break }
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Trace.psm1') -Force
if(!$SettingsPath){$SettingsPath=Get-SBTraceSettingsPath}
if($HookStatus){
    $state=Get-SBTraceHookState $brain $SettingsPath
    ConvertTo-SBJson @{installed=$state.installed;settingsPath=$state.settingsPath;command=$state.command}
    exit 0
}
if(!$Apply){
    $result=Set-SBTraceHook $brain (Join-Path $brain '.runtime/backup/trace') -Remove:$UninstallHook -SettingsPath $SettingsPath
    ConvertTo-SBJson $result
    exit 0
}
$writing=[bool]$Apply
$config=Read-SBConfiguration $ConfigPath -ReadOnly:(!$writing)
$lock=Enter-SBOperation $config $SessionId -ReadOnly:(!$writing)
try{
    $result=Set-SBTraceHook $brain $config.backupRoot -Remove:$UninstallHook -Apply:$Apply -SettingsPath $SettingsPath
    if(!$Apply){$result.message='Anteprima: nessuna modifica. Con -Apply (e una sessione Write) il file viene salvato con backup.'}
    ConvertTo-SBJson $result
}finally{Exit-SBOperation $lock}
