#requires -Version 7.5
<#
.SYNOPSIS
Explicit GitHub GET audit, separate from Check and Sync. See docs/riferimento/external-audit.md.
#>
[CmdletBinding()]
param([string]$ConfigPath,[string]$SessionId,[string[]]$Repository,[string]$OutputPath)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
trap { if (Test-SBWriteDeniedError $_) { Write-SBWriteDeniedDiagnostic $_ $PSCommandPath $PSBoundParameters; exit 4 }; break }
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.ExternalAudit.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Add-SBMessages @{
    'audit.inventory.required' = @{ it = 'Inventario locale richiesto; eseguire prima Sync'; en = 'Local inventory required; run Sync first' }
    'audit.repository.outside' = @{ it = 'Repository fuori inventario attivo'; en = 'Repository outside the active inventory' }
    'audit.output.new' = @{ it = 'Output JSON nuovo richiesto'; en = 'New JSON output required' }
    'audit.inventory.changed' = @{ it = 'Inventario modificato durante audit; risultato non pubblicato'; en = 'Inventory modified during the audit; result not published' }
}
$lock=$null
try {
    $config=Read-SBConfiguration $ConfigPath
    $lock=Enter-SBOperation $config $SessionId -ReadOnly:(!$OutputPath)
    $portable=$config.ContainsKey('mode') -and $config.mode -eq 'portable'
    $inventoryPath=if($portable){Join-Path $config.runtimeRoot 'inventory.json'}else{Join-Path $config.brainRoot 'inventory.json'}
    $inventoryHash=Get-SBFileHash $inventoryPath;$inventory=Read-SBJson $inventoryPath $null
    if(!$inventory -or $inventory.schemaVersion -ne 1){throw (New-SBError 'audit.inventory.required')}
    $managed=if($portable){@($config.bindings|Where-Object {$_.status -eq 'managed' -and $_.identity.StartsWith('github.com/',[StringComparison]::Ordinal)}|ForEach-Object identity|Sort-Object -Unique)}else{@($inventory.repositories|Where-Object status -eq 'active'|ForEach-Object identities|Sort-Object -Unique)}
    $identities=if($Repository){@($Repository)}else{$managed}
    foreach($identity in $identities){Assert-SBAuditIdentity $identity $config.allowedOwners;if($identity -notin $managed){throw (New-SBError 'audit.repository.outside')}}
    $target=$null;$expected=$null
    if($OutputPath){
        $target=[IO.Path]::GetFullPath($OutputPath);Assert-SBPlainPath $target
        if($portable){$target=Assert-SBCentralDataPath $config.brainRoot $target}
        # New artifacts only: never overwrite trackers, code or previous audits.
        if([IO.Path]::GetExtension($target) -ne '.json' -or (Test-Path -LiteralPath $target)){throw (New-SBError 'audit.output.new')}
        $expected=Get-SBFileHash $target
    }
    $audit=Invoke-SBGitHubAudit $identities $config.allowedOwners
    $audit.inventory=@{path='inventory.json';sha256=$inventoryHash;unchanged=((Get-SBFileHash $inventoryPath) -eq $inventoryHash)}
    if(!$audit.inventory.unchanged){throw (New-SBError 'audit.inventory.changed')}
    $json=ConvertTo-SBJson $audit
    if($target){[void](Write-SBFile $target ([Text.Encoding]::UTF8.GetBytes($json)) $expected $config.backupRoot);'Audit salvato: '+$target}else{$json}
    if(!$audit.complete){exit 1}
    exit 0
} catch {[Console]::Error.WriteLine($_.Exception.Message);exit $(if(Test-SBBusyError $_){3}else{2})}
finally {Exit-SBOperation $lock}
