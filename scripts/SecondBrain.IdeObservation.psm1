#requires -Version 7.5
# Delegated IDE/agent verification (#155): SecondBrain builds an instruction package, an installed agent observes a
# NEW session and produces a receipt; this module validates and registers it. It never edits IDE files, never reads
# authentication stores and never automates a login.
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Host.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Add-SBMessages @{
    'ideobs.invalid' = @{it='Osservazione IDE: dato non valido ({0})';en='IDE observation: invalid data ({0})'}
    'ideobs.preview' = @{it='Osservazione IDE: hash dell anteprima mancante o diverso; eseguire una nuova anteprima';en='IDE observation: preview hash missing or different; run a new preview'}
}
$script:SBIdeObservationFields=@('ideId','workstationId','profile','environment','accountAlias','accountVerified','observedAt','observedHash','loadingVerified','sessionId','evidencePath','evidenceSha256')

function Get-SBIdeObservationStorePath([string]$BrainRoot) {
    Join-Path ([IO.Path]::GetFullPath($BrainRoot)) ('.runtime/hosts/'+(Get-SBHostId)+'/ide-observations.json')
}

function Find-SBIdeEntry($Map,[string]$IdeId) {
    $found=@($Map.ides|Where-Object {$_ -is [Collections.IDictionary] -and $_.ContainsKey('id') -and $_.id -ceq $IdeId -and (!$_.ContainsKey('selected') -or $_.selected)})
    if($found.Count -ne 1){throw (New-SBError 'ideobs.invalid' @('ide id'))}
    $found[0]
}

# Package for an installed agent: what to verify in a new session and the exact receipt to produce.
function Get-SBIdeObservationPackage($Ide,[string]$GlobalText,[string]$BrainRoot,[string]$WorkstationId) {
    $hash=Get-SBTextHash $GlobalText.Trim()
    $revision=if($GlobalText -match 'Revisione (\d+(?:\.\d+)+)'){$Matches[1]}else{'unknown'}
    $evidenceDir=Join-Path ([IO.Path]::GetFullPath($BrainRoot)) ('.runtime/hosts/'+$WorkstationId+'/ide-evidence')
    $template=[ordered]@{ideId=$Ide.id;workstationId=$WorkstationId;profile=$(if($Ide.ContainsKey('profile')){$Ide.profile}else{'default'});observedAt='<ISO 8601 UTC, at most 15 minutes old>';
        observedHash=$hash;loadingVerified=$true;sessionId='<id of the NEW session>';evidencePath=(Join-Path $evidenceDir ($Ide.id+'.txt'));evidenceSha256='<sha256 of the evidence file>'}
    if($Ide.ContainsKey('environment')){$template.environment=$Ide.environment}
    if($Ide.mode -eq 'manual'){$template.accountAlias=$Ide.accountAlias;$template.accountVerified=$true}
    $steps=@(
        'Open a NEW session in the client/profile below; do not reuse an older conversation.',
        'Confirm the active account is the one declared by the alias. Do not read, copy or print credentials, tokens or authentication stores, and do not sign in or out on behalf of the user.',
        ('Ask the session to quote the revision line and state whether the SecondBrain global instructions are loaded ("Revisione '+$revision+'").'),
        'Save a short proof (revision line and session id, no secrets) to the evidencePath and compute its SHA-256.',
        ('Write the receipt below as JSON under .runtime and register it with: pwsh -NoProfile -File scripts/ide-observation.ps1 -Operation Register -IdeId '+$Ide.id+' -InputPath <receipt.json>; review the preview and repeat with -PreviewSha256 <hash> -Apply.'))
    [ordered]@{schemaVersion=1;ideId=$Ide.id;name=$Ide.name;mode=$Ide.mode;accountAlias=$(if($Ide.ContainsKey('accountAlias')){$Ide.accountAlias}else{$null});
        expectedRevision=$revision;expectedHash=$hash;steps=$steps;receiptTemplate=$template;
        boundary='SecondBrain does not log in, read authentication stores or modify IDE files. The receipt is declared by the observing agent and proven only by the evidence file hash.'}
}

function Test-SBIdeObservationInput($Input_,[string]$IdeId) {
    if($Input_ -isnot [Collections.IDictionary]){throw (New-SBError 'ideobs.invalid' @('receipt'))}
    foreach($key in $Input_.Keys){if($key -cnotin $script:SBIdeObservationFields){throw (New-SBError 'ideobs.invalid' @('field '+$key))}}
    if(!$Input_.ContainsKey('ideId') -or $Input_.ideId -cne $IdeId){throw (New-SBError 'ideobs.invalid' @('ideId'))}
    foreach($key in 'workstationId','profile','observedAt','observedHash','loadingVerified','sessionId','evidencePath','evidenceSha256'){
        if(!$Input_.ContainsKey($key)){throw (New-SBError 'ideobs.invalid' @('missing '+$key))}
    }
    if($Input_.sessionId -isnot [string] -or [string]::IsNullOrWhiteSpace($Input_.sessionId) -or $Input_.sessionId.Length -gt 256){throw (New-SBError 'ideobs.invalid' @('sessionId'))}
    if($Input_.evidenceSha256 -isnot [string] -or $Input_.evidenceSha256 -cnotmatch '^[A-Fa-f0-9]{64}$'){throw (New-SBError 'ideobs.invalid' @('evidenceSha256'))}
}

function Read-SBIdeObservationStore([string]$BrainRoot) {
    $path=Get-SBIdeObservationStorePath $BrainRoot
    Assert-SBPlainPath $path
    $store=Read-SBJson $path $null
    if($store -and $store.schemaVersion -eq 1 -and $store.observations -is [array]){return @{path=$path;hash=(Get-SBFileHash $path);observations=@($store.observations)}}
    @{path=$path;hash=(Get-SBFileHash $path);observations=@()}
}

function Save-SBIdeObservationStore($Store,$Observations,[string]$BackupRoot) {
    $document=[ordered]@{schemaVersion=1;observations=@($Observations)}
    [void][IO.Directory]::CreateDirectory((Split-Path $Store.path))
    [void](Write-SBFile $Store.path ([Text.UTF8Encoding]::new($false).GetBytes((ConvertTo-SBJson $document))) $Store.hash $BackupRoot)
}

# Validates with the same predicate used by ide-map/Check; the receipt replaces any previous one for the same IDE id.
function Register-SBIdeObservation($Map,[string]$IdeId,$Receipt,[string]$GlobalText,[string]$BrainRoot,[string]$WorkstationId,[string]$BackupRoot,[switch]$Apply,[string]$PreviewSha256) {
    $ide=Find-SBIdeEntry $Map $IdeId
    Test-SBIdeObservationInput $Receipt $IdeId
    $expected=Get-SBTextHash $GlobalText.Trim()
    if(!(Test-SBIDEObservation $ide $expected @($Receipt) $BrainRoot $WorkstationId)){throw (New-SBError 'ideobs.invalid' @('observation does not qualify this IDE/account'))}
    $normalized=ConvertTo-SBStableValue $Receipt
    $previewHash=Get-SBTextHash (ConvertTo-SBJson $normalized)
    $store=Read-SBIdeObservationStore $BrainRoot
    if($Apply){
        if($PreviewSha256 -cnotmatch '^[A-Fa-f0-9]{64}$' -or $PreviewSha256 -ine $previewHash){throw (New-SBError 'ideobs.preview')}
        $kept=@($store.observations|Where-Object {$_.ideId -cne $IdeId})
        Save-SBIdeObservationStore $store (@($kept)+@(,$normalized)) $BackupRoot
    }
    @{state=$(if($Apply){'registered'}else{'preview'});ideId=$IdeId;accountAlias=$(if($ide.ContainsKey('accountAlias')){$ide.accountAlias}else{$null});previewSha256=$previewHash;store=$store.path}
}

# Receipts of integrations no longer in the map (for example after -Unbind) are removed; others are untouched.
function Remove-SBStaleIdeObservations($Map,[string]$BrainRoot,[string]$BackupRoot,[switch]$Apply) {
    $active=@($Map.ides|Where-Object {$_ -is [Collections.IDictionary] -and $_.ContainsKey('id') -and (!$_.ContainsKey('selected') -or $_.selected)}|ForEach-Object id)
    $store=Read-SBIdeObservationStore $BrainRoot
    $stale=@($store.observations|Where-Object {$_.ideId -cnotin $active})
    if($Apply -and $stale.Count){Save-SBIdeObservationStore $store @($store.observations|Where-Object {$_.ideId -cin $active}) $BackupRoot}
    @{state=$(if(!$stale.Count){'unchanged'}elseif($Apply){'pruned'}else{'preview'});removed=@($stale|ForEach-Object ideId)}
}
Export-ModuleMember -Function @('Get-SBIdeObservationStorePath','Get-SBIdeObservationPackage','Register-SBIdeObservation','Remove-SBStaleIdeObservations','Read-SBIdeObservationStore')
