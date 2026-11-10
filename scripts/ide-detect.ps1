#requires -Version 7.5
<#
.SYNOPSIS
Detects the IDEs and AI clients installed on this workstation and lets you choose them and their scope.
.DESCRIPTION
Read-only. Lists every detected IDE with its confidence, evidence and the scopes it supports (user, project, system).
-Interactive shows a numbered list with multiple selection and asks the scope for each chosen IDE.
-Ides with -Scope validates a non-interactive selection. -Json prints the result as JSON (the chat uses the same data through the MCP tool list_ides).
Nothing is written: the selection is applied with the usual flows (secondbrain.ps1 -Setup, mcp-server.ps1 -Pair).
.EXAMPLE
pwsh -NoProfile -File scripts/ide-detect.ps1 -Interactive -WorkspacePath .
.EXAMPLE
pwsh -NoProfile -File scripts/ide-detect.ps1 -Ides 'Claude Code','VS Code' -Scope user -Json
#>
[CmdletBinding()]
param(
    [string[]]$Ides,
    [ValidateSet('user','project','system')][string]$Scope,
    [string]$WorkspacePath,
    [switch]$Interactive,
    [switch]$Json
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Host.psm1') -Force
Add-SBMessages @{
    'idedetect.none' = @{ it = 'Nessuna IDE rilevata'; en = 'No IDE detected' }
    'idedetect.line' = @{ it = '{0}. {1} [affidabilità {2}] ambiti: {3}'; en = '{0}. {1} [confidence {2}] scopes: {3}' }
    'idedetect.prompt.ides' = @{ it = 'Numeri delle IDE da gestire separati da virgola, tutti, invio = nessuna'; en = 'Numbers of the IDEs to manage, comma-separated, all, Enter = none' }
    'idedetect.prompt.scope' = @{ it = 'Ambito per {0} ({1})'; en = 'Scope for {0} ({1})' }
    'idedetect.unknown' = @{ it = 'IDE non rilevata: {0}'; en = 'IDE not detected: {0}' }
    'idedetect.scope' = @{ it = 'Ambito {1} non disponibile per {0}: {2}'; en = 'Scope {1} not available for {0}: {2}' }
    'idedetect.scope.required' = @{ it = 'Indicare -Scope con -Ides'; en = 'Give -Scope together with -Ides' }
    'idedetect.workspace' = @{ it = 'Percorso del progetto non valido: {0}'; en = 'Invalid workspace path: {0}' }
}
try {
    $workspace=''
    if($WorkspacePath){
        if(!(Test-Path -LiteralPath $WorkspacePath -PathType Container)){throw (New-SBError 'idedetect.workspace' @($WorkspacePath))}
        $workspace=(Resolve-Path -LiteralPath $WorkspacePath).ProviderPath
    }
    # -File passes 'a','b' as one string: accept both forms.
    $Ides=@($Ides|ForEach-Object {$_ -split ','}|ForEach-Object {$_.Trim()}|Where-Object {$_})
    $detected=@(Get-SBIDEDetection $workspace)
    $availableScopes={param($ide) @($ide.scopes|Where-Object {$_.available}|ForEach-Object {$_.scope})}
    # Selection stays informative: each entry carries the preview-only Pair command (no -Apply) for the chosen IDE and scope.
    $pairTargets=@{'Claude Code'='claude-code';'Codex'='codex';'Antigravity'='antigravity';'VS Code'='vscode';'Cursor'='cursor';'Windsurf'='windsurf'}
    $pairCommand={param($name,$scope)
        if(!$pairTargets.ContainsKey($name) -or $scope -notin @('user','project')){return $null}
        $command="pwsh -NoProfile -File scripts/mcp-server.ps1 -Pair -Target $($pairTargets[$name]) -Scope $scope"
        if($scope -eq 'project' -and $workspace){$command+=" -WorkspacePath '$workspace'"}
        $command
    }
    $selection=@()
    if($Interactive){
        if(!$detected.Count){Get-SBMessage 'idedetect.none';exit 0}
        for($i=0;$i -lt $detected.Count;$i++){Get-SBMessage 'idedetect.line' @(($i+1),$detected[$i].name,$detected[$i].confidence,((& $availableScopes $detected[$i]) -join ', '))}
        foreach($n in @(Resolve-SBIDESelection (Read-Host (Get-SBMessage 'idedetect.prompt.ides')) $detected.Count)){
            $ide=$detected[$n-1];$options=@(& $availableScopes $ide)
            $chosen=if($options.Count -eq 1){$options[0]}else{([string](Read-Host (Get-SBMessage 'idedetect.prompt.scope' @($ide.name,($options -join '/'))))).Trim().ToLowerInvariant()}
            if($chosen -notin $options){throw (New-SBError 'idedetect.scope' @($ide.name,$chosen,(($ide.scopes|Where-Object {$_.scope -eq $chosen}|ForEach-Object {$_.reason}) -join '')))}
            $selection+=@{name=$ide.name;scope=$chosen;location=[string](@($ide.scopes|Where-Object {$_.scope -eq $chosen})[0].location);pairCommand=(& $pairCommand $ide.name $chosen)}
        }
    }
    elseif($Ides){
        if(!$Scope){throw (New-SBError 'idedetect.scope.required')}
        foreach($name in $Ides){
            $ide=@($detected|Where-Object {$_.name -ieq $name})
            if($ide.Count -ne 1){throw (New-SBError 'idedetect.unknown' @($name))}
            $entry=@($ide[0].scopes|Where-Object {$_.scope -eq $Scope})[0]
            if(!$entry.available){throw (New-SBError 'idedetect.scope' @($ide[0].name,$Scope,$entry.reason))}
            $selection+=@{name=$ide[0].name;scope=$Scope;location=[string]$entry.location;pairCommand=(& $pairCommand $ide[0].name $Scope)}
        }
    }
    if($Json){ConvertTo-Json -Depth 8 @{ides=$detected;selection=$selection};exit 0}
    if($Interactive -or $Ides){ConvertTo-Json -Depth 4 @{selection=$selection};exit 0}
    if(!$detected.Count){Get-SBMessage 'idedetect.none';exit 0}
    for($i=0;$i -lt $detected.Count;$i++){Get-SBMessage 'idedetect.line' @(($i+1),$detected[$i].name,$detected[$i].confidence,((& $availableScopes $detected[$i]) -join ', '))}
    exit 0
} catch { Write-Error $_ -ErrorAction Continue; exit 2 }
