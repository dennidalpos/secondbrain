#requires -Version 7.5
<#
.SYNOPSIS
Validates the catalog and prompt cards; generates direttive/prompts/README.md.
.DESCRIPTION
-Check verifies without writing: exit 0 when aligned, 1 when regeneration is required.
The prompt catalog lives in the SecondBrain root. Use -SessionId in Write sessions.
#>
[CmdletBinding()]
param([string]$ConfigPath,[string]$SessionId,[switch]$Check)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1') -Force
# Writer busy beyond the wait limit: exit 3 (the message identifies the owner).
trap { if (Test-SBWriteDeniedError $_) { Write-SBWriteDeniedDiagnostic $_ $PSCommandPath $PSBoundParameters; exit 4 }; if (Test-SBBusyError $_) { [Console]::Error.WriteLine($_.Exception.Message); exit 3 }; break }
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Prompts.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.PrivateAssets.psm1')
# -Check only reads repository files: on a clean clone (CI) without an activated workstation it runs without the operation lock.
$config=$null;$lock=$null
try{$config=Read-SBConfiguration $ConfigPath}catch{if(!$Check){throw}}
if($config){$lock=Enter-SBOperation $config $SessionId -ReadOnly:$Check}
try {
    $brain=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    $publicCatalog=Read-SBWorkflowCatalog $brain -ValidateBodies -ValidateReferences
    # #589: private dossier cards and workflows (keys, collisions, references) and no private ID or key in public files.
    $private=Test-SBPrivateAssets -BrainRoot $brain -PublicCatalog $publicCatalog
    $index=New-SBWorkflowIndex $brain
    $catalog=$index.catalog
    $drift=@(Get-SBWorkflowDrift $brain)
    if($Check){
        foreach($item in $drift){'Da rigenerare: '+$item.path}
        if($drift.Count){exit 1}
    }else{
        foreach($item in $drift){
            $path=Join-Path $brain $item.path
            Write-SBFile $path ([Text.Encoding]::UTF8.GetBytes($item.text)) (Get-SBFileHash $path) $config.backupRoot -BackupDirty | Out-Null
            'Aggiornato: '+$item.path
        }
    }
    "Catalogo allineato: $($catalog.prompts.Count) prompt ($($catalog.prompts[0].code)-$($catalog.prompts[-1].code))"
    "Private assets: $($private.prompts) cards and $($private.workflows) workflows in $($private.dossiers) dossiers; no public reference to them"
    exit 0
}finally{if($lock){Exit-SBOperation $lock}}
