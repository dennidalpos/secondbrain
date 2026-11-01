#requires -Version 7.5
<#
.SYNOPSIS
Audit GitHub GET esplicito, separato da Check e Sync. Vedere docs/external-audit.md.
#>
[CmdletBinding()]
param([string]$ConfigPath,[string]$SessionId,[string[]]$Repository,[string]$OutputPath)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.ExternalAudit.psm1')
$lock=$null
try {
    $config=Read-SBConfiguration $ConfigPath
    $lock=Enter-SBOperation $config $SessionId -ReadOnly:(!$OutputPath)
    $portable=$config.ContainsKey('mode') -and $config.mode -eq 'portable'
    $inventoryPath=if($portable){Join-Path $config.runtimeRoot 'inventory.json'}else{Join-Path $config.brainRoot 'inventory.json'}
    $inventoryHash=Get-SBFileHash $inventoryPath;$inventory=Read-SBJson $inventoryPath $null
    if(!$inventory -or $inventory.schemaVersion -notin @(3,4)){throw 'Inventario locale richiesto; eseguire prima Sync'}
    $managed=if($portable){@($config.bindings|Where-Object {$_.status -eq 'managed' -and $_.identity.StartsWith('github.com/',[StringComparison]::Ordinal)}|ForEach-Object identity|Sort-Object -Unique)}else{@($inventory.repositories|Where-Object status -eq 'active'|ForEach-Object identities|Sort-Object -Unique)}
    $identities=if($Repository){@($Repository)}else{$managed}
    foreach($identity in $identities){Assert-SBAuditIdentity $identity $config.allowedOwners;if($identity -notin $managed){throw 'Repository fuori inventario attivo'}}
    $target=$null;$expected=$null
    if($OutputPath){
        $target=[IO.Path]::GetFullPath($OutputPath);Assert-SBPlainPath $target
        if($portable){$target=Assert-SBCentralDataPath $config.brainRoot $target}
        # Artefatti nuovi soltanto: non sovrascrivere tracker, codice o audit precedenti.
        if([IO.Path]::GetExtension($target) -ne '.json' -or (Test-Path -LiteralPath $target)){throw 'Output JSON nuovo richiesto'}
        $expected=Get-SBFileHash $target
    }
    $audit=Invoke-SBGitHubAudit $identities $config.allowedOwners
    $audit.inventory=@{path='inventory.json';sha256=$inventoryHash;unchanged=((Get-SBFileHash $inventoryPath) -eq $inventoryHash)}
    if(!$audit.inventory.unchanged){throw 'Inventario modificato durante audit; risultato non pubblicato'}
    $json=ConvertTo-SBJson $audit
    if($target){[void](Write-SBFile $target ([Text.Encoding]::UTF8.GetBytes($json)) $expected $config.backupRoot);'Audit salvato: '+$target}else{$json}
    if(!$audit.complete){exit 1}
    exit 0
} catch {[Console]::Error.WriteLine($_.Exception.Message);exit 2}
finally {Exit-SBOperation $lock}
