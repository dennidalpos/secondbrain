#requires -Version 7.5
<#
.SYNOPSIS
Valida catalogo e schede, genera direttive/prompts/README.md.
.DESCRIPTION
-Check verifica senza scrivere: exit 0 allineato, 1 da rigenerare.
Il catalogo prompt è nella radice SecondBrain. Usare -SessionId nelle sessioni Write.
#>
[CmdletBinding()]
param([string]$ConfigPath,[string]$SessionId,[switch]$Check)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1') -Force
# Scrittura occupata oltre l'attesa: exit 3 (il titolare e nel messaggio).
trap { if (Test-SBWriteDeniedError $_) { Write-SBWriteDeniedDiagnostic $_ $PSCommandPath $PSBoundParameters; exit 4 }; if (Test-SBBusyError $_) { [Console]::Error.WriteLine($_.Exception.Message); exit 3 }; break }
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Prompts.psm1')
$config=Read-SBConfiguration $ConfigPath
$lock=Enter-SBOperation $config $SessionId -ReadOnly:$Check
try {
    $brain=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
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
