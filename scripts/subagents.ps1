#requires -Version 7.5
<#
.SYNOPSIS
Subagent definitions (F8): validation, inherited permissions and per-client export.
.DESCRIPTION
Definitions live in <dossier>/subagents/<name>.json (one format: role, context, permissions, MCP tools).
-Operation Validate: checks every definition (read-only).
-Operation Resolve: shows effective permissions against a parent (-ParentTools, -ParentWrite); requesting more than the parent is an error.
-Operation Export: renders definitions for -Client into -OutputPath (under .runtime); preview unless -Apply. Never writes into a checkout.
A definition carries no authorization; writes stay behind the parent's reviewed MCP write path.
.EXAMPLE
pwsh -NoProfile -File scripts/subagents.ps1 -Operation Export -Repository github.com/my-org/my-product -Client claude-code -OutputPath .runtime/export/agents
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Validate','Resolve','Export')][string]$Operation,
    [Parameter(Mandatory)][string]$Repository,
    [string[]]$ParentTools,[switch]$ParentWrite,
    [ValidateSet('claude-code','codex','antigravity','vscode','android-studio','claude','cursor','windsurf','continue','jetbrains')][string]$Client,
    [string]$OutputPath,[string]$ConfigPath,[string]$SessionId,[switch]$Apply,[ValidateSet('it','en')][string]$Language
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($Language){$env:SECONDBRAIN_LANG=$Language}
foreach($m in 'Core','Access','Host','Para','Knowledge','Subagents'){Import-Module (Join-Path $PSScriptRoot ('SecondBrain.'+$m+'.psm1'))}
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Add-SBMessages @{'subagent.cli'=@{it='Subagenti: parametro mancante o fuori perimetro ({0})';en='Subagents: missing or out-of-scope parameter ({0})'}}
$brain=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if(!(Test-SBRepositoryIdentity $Repository)){throw (New-SBError 'subagent.cli' @('repository'))}
$dossier=Resolve-SBParaPath $brain (Resolve-SBWorkingDossier $brain $Repository)
$tools=Get-SBSubagentTools
$parent=@{tools=@(if($PSBoundParameters.ContainsKey('ParentTools')){$ParentTools}else{$tools.read});write=[bool]$ParentWrite}
if($Operation -eq 'Validate'){
    $entries=Read-SBSubagentDefinitions $dossier
    ConvertTo-SBJson @{state='valid';definitions=@($entries|ForEach-Object {@{name=$_.definition.name;sha256=$_.sha256}})};exit 0
}
if($Operation -eq 'Resolve'){
    $entries=Read-SBSubagentDefinitions $dossier
    ConvertTo-SBJson @{parent=$parent;agents=@($entries|ForEach-Object {Resolve-SBSubagentPermissions $_.definition $parent})};exit 0
}
if(!$Client){throw (New-SBError 'subagent.cli' @('client'))}
if(!$OutputPath){throw (New-SBError 'subagent.cli' @('outputPath'))}
$scope=[IO.Path]::GetFullPath((Join-Path $brain '.runtime')).TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
$root=[IO.Path]::GetFullPath($OutputPath,$brain)
if(!$root.StartsWith($scope,[StringComparison]::OrdinalIgnoreCase)){throw (New-SBError 'subagent.cli' @('outputPath'))}
$config=Read-SBConfiguration $ConfigPath -ReadOnly:(!$Apply)
$owned=$null;$lock=$null
try{
    if($Apply -and !$SessionId){$owned=& (Join-Path $PSScriptRoot 'access.ps1') -Start -Mode Write -Client subagents -Repository $Repository -ConfigPath $config.configPath|ConvertFrom-Json -AsHashtable;$SessionId=$owned.sessionId}
    $lock=Enter-SBOperation $config $SessionId -ReadOnly:(!$Apply)
    ConvertTo-SBJson (Export-SBSubagents $dossier $Client $parent $root $config.backupRoot -Apply:$Apply)
}finally{
    if($lock){Exit-SBOperation $lock}
    if($owned){& (Join-Path $PSScriptRoot 'access.ps1') -End -SessionId $SessionId -ConfigPath $config.configPath|Out-Null}
}
