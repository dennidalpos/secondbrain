#requires -Version 7.5
# Fixtures for delegated IDE verification (#155): two accounts alternating on the same IDE. Synthetic data only.
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.IdeObservation.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Host.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Portable.psm1') -Force
. (Join-Path $PSScriptRoot 'test-helpers.ps1')
$script:obsChecks=0
function Assert-Obs($Condition,[string]$Message){if(!$Condition){throw ('FAIL IDE OBSERVATION: '+$Message)};$script:obsChecks++}
function Reject-Obs([scriptblock]$Action,[string]$Message){$rejected=$false;try{& $Action|Out-Null}catch{$rejected=$true};Assert-Obs $rejected $Message}
$root=Join-Path (Get-SBTestRoot) ('ideobs-'+[guid]::NewGuid().ToString('N'))
$brain=Join-Path $root 'brain';$backups=Join-Path $brain '.runtime/backups';$hostId=Get-SBHostId
$evidenceDir=Join-Path $brain ('.runtime/hosts/'+$hostId+'/ide-evidence');[void][IO.Directory]::CreateDirectory($evidenceDir)
$global="# Istruzioni globali`nRevisione 1.0 fixture`n"
$expected=Get-SBTextHash $global.Trim()
$map=@{schemaVersion=1;workstationId=$hostId;ides=@(
    @{name='Claude Desktop';id='claude-desktop-a';mode='manual';accountAlias='work';profile='default'},
    @{name='Claude Desktop';id='claude-desktop-b';mode='manual';accountAlias='personal';profile='default'})}
function New-Receipt([string]$id,[string]$alias,[string]$text='proof'){
    $evidence=Join-Path $evidenceDir ($id+'.txt');[IO.File]::WriteAllText($evidence,$text+' '+$id)
    @{ideId=$id;workstationId=$hostId;profile='default';accountAlias=$alias;accountVerified=$true;observedAt=[DateTimeOffset]::UtcNow.ToString('o');observedHash=$expected;loadingVerified=$true;sessionId=('new-session-'+$id);evidencePath=$evidence;evidenceSha256=(Get-SBFileHash $evidence)}
}
# Package: guides a new-session observation, names the alias, carries the hash, and states the boundary.
$package=Get-SBIdeObservationPackage $map.ides[0] $global $brain $hostId
$packageText=ConvertTo-SBJson $package
Assert-Obs ($package.ideId -ceq 'claude-desktop-a' -and $package.accountAlias -ceq 'work' -and $package.expectedHash -ceq $expected -and $package.receiptTemplate.accountAlias -ceq 'work' -and $packageText -match 'NEW session' -and $packageText -match 'does not log in') 'package carries id, alias, expected hash, new-session steps and boundary'
Assert-Obs ((Get-SBIdeObservationPackage $map.ides[1] $global $brain $hostId).receiptTemplate.accountAlias -ceq 'personal') 'each account gets its own package'
# Register: preview writes nothing; Apply needs the previewed hash.
$a=New-Receipt 'claude-desktop-a' 'work'
$storePath=Get-SBIdeObservationStorePath $brain
$preview=Register-SBIdeObservation $map 'claude-desktop-a' $a $global $brain $hostId $backups
Assert-Obs ($preview.state -eq 'preview' -and !(Test-Path $storePath)) 'preview stores nothing'
Reject-Obs {Register-SBIdeObservation $map 'claude-desktop-a' $a $global $brain $hostId $backups -Apply} 'Apply without preview hash is rejected'
Reject-Obs {Register-SBIdeObservation $map 'claude-desktop-a' $a $global $brain $hostId $backups -Apply -PreviewSha256 ('0'*64)} 'Apply with a different preview hash is rejected'
Assert-Obs (!(Test-Path $storePath)) 'rejected Apply leaves no store'
$tampered=@{}+$a;$tampered.sessionId='another-session'
Reject-Obs {Register-SBIdeObservation $map 'claude-desktop-a' $tampered $global $brain $hostId $backups -Apply -PreviewSha256 $preview.previewSha256} 'receipt changed after preview is rejected'
Assert-Obs ((Register-SBIdeObservation $map 'claude-desktop-a' $a $global $brain $hostId $backups -Apply -PreviewSha256 $preview.previewSha256).state -eq 'registered') 'matching preview hash registers'
# Two accounts alternate on the same IDE, one id per alias.
$b=New-Receipt 'claude-desktop-b' 'personal'
$previewB=Register-SBIdeObservation $map 'claude-desktop-b' $b $global $brain $hostId $backups
[void](Register-SBIdeObservation $map 'claude-desktop-b' $b $global $brain $hostId $backups -Apply -PreviewSha256 $previewB.previewSha256)
$store=Read-SBIdeObservationStore $brain
Assert-Obs ($store.observations.Count -eq 2) 'both accounts registered'
foreach($ide in $map.ides){Assert-Obs (Test-SBIDEObservation $ide $expected $store.observations $brain $hostId) ('store qualifies '+$ide.id+' through the ide-map predicate')}
$wrongAlias=New-Receipt 'claude-desktop-b' 'work'
Reject-Obs {Register-SBIdeObservation $map 'claude-desktop-b' $wrongAlias $global $brain $hostId $backups} 'receipt for the other account alias is rejected'
Reject-Obs {Register-SBIdeObservation $map 'claude-desktop-a' $b $global $brain $hostId $backups} 'receipt of one account cannot register another id'
# Negative receipts.
$stale=New-Receipt 'claude-desktop-a' 'work';$stale.observedAt=[DateTimeOffset]::UtcNow.AddMinutes(-30).ToString('o')
Reject-Obs {Register-SBIdeObservation $map 'claude-desktop-a' $stale $global $brain $hostId $backups} 'stale observation rejected'
$wrongHash=New-Receipt 'claude-desktop-a' 'work';$wrongHash.observedHash='0'*64
Reject-Obs {Register-SBIdeObservation $map 'claude-desktop-a' $wrongHash $global $brain $hostId $backups} 'observation of other instruction text rejected'
$noLoad=New-Receipt 'claude-desktop-a' 'work';$noLoad.loadingVerified=$false
Reject-Obs {Register-SBIdeObservation $map 'claude-desktop-a' $noLoad $global $brain $hostId $backups} 'unverified loading rejected'
$badEvidence=New-Receipt 'claude-desktop-a' 'work';$badEvidence.evidenceSha256='1'*64
Reject-Obs {Register-SBIdeObservation $map 'claude-desktop-a' $badEvidence $global $brain $hostId $backups} 'evidence hash mismatch rejected'
$outside=Join-Path $root 'outside.txt';[IO.File]::WriteAllText($outside,'x')
$outsideReceipt=New-Receipt 'claude-desktop-a' 'work';$outsideReceipt.evidencePath=$outside;$outsideReceipt.evidenceSha256=Get-SBFileHash $outside
Reject-Obs {Register-SBIdeObservation $map 'claude-desktop-a' $outsideReceipt $global $brain $hostId $backups} 'evidence outside the runtime area rejected'
$extra=New-Receipt 'claude-desktop-a' 'work';$extra.password='x'
Reject-Obs {Register-SBIdeObservation $map 'claude-desktop-a' $extra $global $brain $hostId $backups} 'unknown field (for example a credential) rejected'
Reject-Obs {Register-SBIdeObservation $map 'unknown-ide' $a $global $brain $hostId $backups} 'unknown IDE id rejected'
# Re-registering replaces the entry for that id only.
$a2=New-Receipt 'claude-desktop-a' 'work' 'second proof'
$p2=Register-SBIdeObservation $map 'claude-desktop-a' $a2 $global $brain $hostId $backups
[void](Register-SBIdeObservation $map 'claude-desktop-a' $a2 $global $brain $hostId $backups -Apply -PreviewSha256 $p2.previewSha256)
$store=Read-SBIdeObservationStore $brain
Assert-Obs ($store.observations.Count -eq 2 -and @($store.observations|Where-Object ideId -eq 'claude-desktop-a')[0].evidenceSha256 -ceq $a2.evidenceSha256) 're-registration replaces only the same id'
# Retiring an account (as -Unbind removes it from the map) prunes only its receipt.
$retired=@{schemaVersion=1;workstationId=$hostId;ides=@($map.ides[0])}
$prune=Remove-SBStaleIdeObservations $retired $brain $backups
Assert-Obs ($prune.state -eq 'preview' -and $prune.removed -ceq 'claude-desktop-b' -and (Read-SBIdeObservationStore $brain).observations.Count -eq 2) 'prune preview changes nothing'
Assert-Obs ((Remove-SBStaleIdeObservations $retired $brain $backups -Apply).state -eq 'pruned') 'prune removes the retired account receipt'
$store=Read-SBIdeObservationStore $brain
Assert-Obs ($store.observations.Count -eq 1 -and $store.observations[0].ideId -ceq 'claude-desktop-a' -and (Remove-SBStaleIdeObservations $retired $brain $backups -Apply).state -eq 'unchanged') 'remaining account kept; prune is idempotent'
# #188: revision and hash for -IdeAccount come from a receipt under .runtime, not from typed values.
$receiptDir=Join-Path $brain ('.runtime/hosts/'+$hostId+'/account-receipts');[void][IO.Directory]::CreateDirectory($receiptDir)
function Put-Receipt([string]$name,$value){$path=Join-Path $receiptDir $name;[IO.File]::WriteAllText($path,($value|ConvertTo-Json -Depth 5));$path}
$goodHash=('ab'*32)
$good=Put-Receipt 'good.json' @{schemaVersion=1;ideId='claude-desktop-a';accountAlias='work';observedRevision='1.0';observedHash=$goodHash}
$read=Read-SBAccountObservationReceipt $brain $good 'claude-desktop-a' 'work'
Assert-Obs ($read.observedRevision -ceq '1.0' -and $read.observedHash -ceq $goodHash.ToUpperInvariant() -and $read.receiptSha256 -ceq (Get-SBFileHash $good)) 'valid account receipt yields revision, normalized hash and file hash'
$minimal=Put-Receipt 'minimal.json' @{schemaVersion=1;observedRevision='2.1.3';observedHash=$goodHash}
Assert-Obs ((Read-SBAccountObservationReceipt $brain $minimal 'claude-desktop-b' 'personal').observedRevision -ceq '2.1.3') 'receipt without id/alias is accepted for the entry that cites it'
Reject-Obs {Read-SBAccountObservationReceipt $brain (Put-Receipt 'short.json' @{schemaVersion=1;observedRevision='1.0';observedHash='abc'}) 'claude-desktop-a' 'work'} 'invalid hash (typo) rejected'
Reject-Obs {Read-SBAccountObservationReceipt $brain (Put-Receipt 'rev.json' @{schemaVersion=1;observedRevision='v1';observedHash=$goodHash}) 'claude-desktop-a' 'work'} 'invalid revision rejected'
Reject-Obs {Read-SBAccountObservationReceipt $brain (Put-Receipt 'schema.json' @{schemaVersion=2;observedRevision='1.0';observedHash=$goodHash}) 'claude-desktop-a' 'work'} 'wrong schema version rejected'
Reject-Obs {Read-SBAccountObservationReceipt $brain (Put-Receipt 'extra.json' @{schemaVersion=1;observedRevision='1.0';observedHash=$goodHash;token='x'}) 'claude-desktop-a' 'work'} 'unknown field rejected'
Reject-Obs {Read-SBAccountObservationReceipt $brain $good 'claude-desktop-b' 'work'} 'receipt of another IDE id rejected'
Reject-Obs {Read-SBAccountObservationReceipt $brain $good 'claude-desktop-a' 'personal'} 'receipt of another account alias rejected'
$outsideReceipt2=Join-Path $root 'outside-receipt.json';[IO.File]::WriteAllText($outsideReceipt2,[IO.File]::ReadAllText($good))
Reject-Obs {Read-SBAccountObservationReceipt $brain $outsideReceipt2 'claude-desktop-a' 'work'} 'path outside .runtime rejected'
Reject-Obs {Read-SBAccountObservationReceipt $brain (Join-Path $receiptDir 'missing.json') 'claude-desktop-a' 'work'} 'missing receipt rejected'
$notJson=Join-Path $receiptDir 'broken.json';[IO.File]::WriteAllText($notJson,'{broken')
Reject-Obs {Read-SBAccountObservationReceipt $brain $notJson 'claude-desktop-a' 'work'} 'malformed receipt rejected'
# No IDE file or credential store is touched by this module.
Assert-Obs (@(Get-ChildItem -LiteralPath $root -Recurse -File|Where-Object {$_.FullName -notmatch '[\\/]\.runtime[\\/]' -and $_.Name -notin @('outside.txt','outside-receipt.json')}).Count -eq 0) 'only runtime files were written'
'SUCCESS IDE OBSERVATION: '+$script:obsChecks+' checks; retained fixture '+$root
