#requires -Version 7.5
<#
.SYNOPSIS
Traccia di fine turno per l'avviso di compattazione (hook Stop di Claude Code).
.DESCRIPTION
-Event stop accoda una riga di soli metadati (ora, sessione, repository, hash della cartella) in .runtime/trace/<postazione>/<data>.jsonl,
leggendo l'eventuale JSON dell'hook da stdin. Non contiene testo di prompt, non usa il lock dei writer, non misura il contesto e
fallisce in modo aperto: esce sempre con 0 e non blocca mai il turno. La lettura e l'avviso sono in secondbrain.ps1 -Check.
-InstallHook / -UninstallHook / -HookStatus gestiscono la voce Stop in ~/.claude/settings.json (o -SettingsPath): senza -Apply
mostrano solo l'anteprima, con -Apply salvano con backup; le voci di altri strumenti non vengono toccate.
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
    # Fail-open: qualsiasi errore e ignorato, il turno non viene mai bloccato.
    try{
        Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Trace.psm1')
        $stdin=''
        if([Console]::IsInputRedirected){$stdin=[Console]::In.ReadToEnd()}
        [void](Add-SBTraceEvent $brain $Event $stdin $Ide)
    }catch{}
    exit 0
}
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1') -Force
# Scrittura occupata oltre l'attesa: exit 3 (il titolare e nel messaggio).
trap { if (Test-SBBusyError $_) { [Console]::Error.WriteLine($_.Exception.Message); exit 3 }; break }
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Trace.psm1') -Force
if(!$SettingsPath){$SettingsPath=Get-SBTraceSettingsPath}
if($HookStatus){
    $state=Get-SBTraceHookState $brain $SettingsPath
    ConvertTo-SBJson @{installed=$state.installed;settingsPath=$state.settingsPath;command=$state.command}
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
