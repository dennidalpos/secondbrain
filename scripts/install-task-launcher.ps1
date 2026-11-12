#requires -Version 7.5
<#
.SYNOPSIS
Installs the per-repository task launcher (.secondbrain/run-tasks.ps1) in the managed checkouts.
.DESCRIPTION
Preview by default: lists every managed checkout (bindings of the workstation configuration) and what would happen. -Apply writes the launcher
only where it is absent (or already identical) and replaces a launcher installed from an earlier template (state outdated, matched by hash,
with a verified backup); any other existing file is never overwritten and is reported as different. Nothing is committed,
staged or deleted, and no personal path is written into the repository: the launcher finds SecondBrain through the SECONDBRAIN_HOME environment variable.
-Repository limits the run to the named identities. Writes use Write-SBFile with a verified backup root.
#>
[CmdletBinding()]
param([string[]]$Repository,[string]$ConfigPath,[switch]$Apply)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1')
Add-SBMessages @{
    'launcher.template.missing' = @{it='Modello del lanciatore non trovato: {0}';en='Launcher template not found: {0}'}
}
$template=Join-Path $PSScriptRoot 'templates/run-tasks.launcher.ps1'
if(!(Test-Path -LiteralPath $template)){throw (New-SBError 'launcher.template.missing' $template)}
$bytes=[IO.File]::ReadAllBytes($template)
$hash=Get-SBHash $bytes
# SHA-256 of the earlier official templates: a launcher with one of these hashes was never edited locally and is safe to replace.
$previousHashes=@('4D4725AEB58EAD7EC4327806BE5F68933A248C04328CF526E0160A9DA73D0879')
$config=Read-SBConfiguration $ConfigPath
$wanted=if($Repository){@($Repository|ForEach-Object {([string]$_).ToLowerInvariant()})}else{$null}
$results=@();$seen=@{}
foreach($b in @($config.bindings|Where-Object {$_.identity -and $_.path})){
    $id=[string]$b.identity
    if($wanted -and $id.ToLowerInvariant() -notin $wanted){continue}
    if($seen.ContainsKey($id.ToLowerInvariant())){continue}
    $seen[$id.ToLowerInvariant()]=1
    $checkout=[IO.Path]::GetFullPath([string]$b.path)
    $target=Join-Path $checkout '.secondbrain/run-tasks.ps1'
    # SecondBrain itself already holds the runner in scripts/: it gets no launcher.
    $selfRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')).TrimEnd('\','/')
    $current=if(Test-Path -LiteralPath $target -PathType Leaf){Get-SBFileHash $target}else{$null}
    $state=if([string]::Equals($checkout.TrimEnd('\','/'),$selfRoot,[StringComparison]::OrdinalIgnoreCase)){'self'}
        elseif(!(Test-Path -LiteralPath $checkout)){'checkout-missing'}
        elseif(!(Test-Path -LiteralPath $target)){'new'}
        elseif($current -ceq $hash){'identical'}
        elseif($current -in $previousHashes){'outdated'}
        else{'different'}
    $written=$false
    if($Apply -and $state -eq 'new'){
        [IO.Directory]::CreateDirectory((Split-Path $target))|Out-Null
        # New file in a managed checkout: expected hash 'absent', verified stage record under the workstation backups.
        $written=[bool](Write-SBFile $target $bytes 'absent' (Join-Path $config.runtimeRoot 'backups'))
    }
    elseif($Apply -and $state -eq 'outdated'){
        # Unedited earlier template: replaced against its own hash, so a concurrent local edit is refused, with a verified backup.
        $written=[bool](Write-SBFile $target $bytes $current (Join-Path $config.runtimeRoot 'backups'))
    }
    $results+=,[ordered]@{repository=$id;path=$target;state=$state;written=$written}
}
foreach($w in @($wanted)){if($w -and !$seen.ContainsKey($w)){$results+=,[ordered]@{repository=$w;path=$null;state='not-bound';written=$false}}}
ConvertTo-SBJson @{apply=[bool]$Apply;templateSha256=$hash;repositories=$results}
