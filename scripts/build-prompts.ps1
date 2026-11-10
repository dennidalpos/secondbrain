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
$config=Read-SBConfiguration $ConfigPath
$lock=Enter-SBOperation $config $SessionId -ReadOnly:$Check
try {
    $brain=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    [void](Read-SBWorkflowCatalog $brain -ValidateBodies -ValidateReferences)
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
    exit 0
}finally{Exit-SBOperation $lock}
