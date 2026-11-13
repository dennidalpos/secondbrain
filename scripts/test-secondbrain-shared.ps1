#requires -Version 7.5
# Shared root with two simulated identities (#487): two workstation states (own runtime/backup roots, own checkout and binding)
# on one authoritative dossier. Real CLI processes run concurrently; synthetic data only, fixture under Get-SBTestRoot.
# Declared limit: both identities run under this PC and user (same MachineName/SID); the real two-PC qualification stays in #348.
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Para.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Tracker.psm1') -Force
. (Join-Path $PSScriptRoot 'test-helpers.ps1')
$script:checks=0
$script:observations=[Collections.Generic.List[string]]::new()
function Assert-Shared($Condition,[string]$Message,[string]$Detail=''){if(!$Condition){throw ('FAIL SHARED: '+$Message+$(if($Detail){' ['+$Detail+']'}else{''}))};$script:checks++;'PASS SHARED: '+$Message}
function Add-Observation([string]$Text){$script:observations.Add($Text);'INFO SHARED: '+$Text}
$stamp=[guid]::NewGuid().ToString('N').Substring(0,12)
$root=Join-Path (Get-SBTestRoot) ('shared-'+$stamp)
$brain=Join-Path $root 'brain'
$identity='github.com/test/shared'
function Put([string]$rel,[string]$text){$p=Join-Path $brain $rel;[IO.Directory]::CreateDirectory((Split-Path $p))|Out-Null;[IO.File]::WriteAllText($p,$text)}
foreach($sub in @('scripts','config')){Copy-Item -LiteralPath (Join-Path $PSScriptRoot ('../'+$sub)) -Destination (Join-Path $brain $sub) -Recurse -Force}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../VERSION') -Destination (Join-Path $brain 'VERSION')
Put 'config/shared.json' (ConvertTo-SBJson @{schemaVersion=1;allowedOwners=@('test');excludedDirectories=@('.git');lockWaitSeconds=60})
Put 'direttive/AGENTS.global_ide.md' "# Synthetic`nRevisione 1.0 - 2026-11-04."
Put 'direttive/workstation.template.md' '<!-- secondbrain:tracker-contract:1 -->'
$approval=@{authorization='synthetic test fixture';files=@{}}
foreach($name in @('AGENTS.global_ide.md','workstation.template.md')){$approval.files['direttive/'+$name]=Get-SBFileHash (Join-Path $brain ('direttive/'+$name))}
Put 'direttive/approved.json' (ConvertTo-SBJson $approval)
# One authoritative dossier shared by both identities.
$dossier='01-projects/shared'
Put "$dossier/repository.json" (ConvertTo-SBJson @{schemaVersion=1;identity=$identity;tracker=@{location='dossier';path='tracker.json';schemaVersion=1}})
Put "$dossier/para.json" (ConvertTo-SBJson @{schemaVersion=1;id='dossier-shared';kind='project';title='shared';status='active'})
Put "$dossier/brief.md" '# shared'
Put "$dossier/context.md" "# Contesto`nstato iniziale`n"
Put "$dossier/memory.md" "# Memoria`n"
Put "$dossier/history/fonte.md" "fonte sintetica`n"
$seed=New-SBTrackerTask @{id='T-SEED';title='Seme';status='done'} $identity 'test' 'fonte.md' (Get-SBTextHash 'fonte') 'line:1'
$seed.seq=1;$seed.title=('#001 '+[char]0x2014+' Seme')
Put "$dossier/tracker.json" (ConvertTo-SBJson @{schemaVersion=1;repository=$identity;updatedAt=[DateTimeOffset]::UtcNow.ToString('o');tasks=@($seed);history=@();extensions=@{lastSeq=1}})

# Two identities: own local state (runtime and backup roots), own checkout with binding. The shared root holds only the dossier and coordination.
$ids=@{}
foreach($name in @('pc-a','pc-b')){
    $checkout=Join-Path $root ('checkouts/'+$name+'/shared');[IO.Directory]::CreateDirectory($checkout)|Out-Null
    $null=& git -C $checkout init -q;$null=& git -C $checkout remote add origin 'https://github.com/test/shared.git'
    $runtime=Get-SBLocalRoot $brain $name
    $cfg=Join-Path $runtime 'workstation.json'
    Put ([IO.Path]::GetRelativePath($brain,$cfg)) (ConvertTo-SBJson @{schemaVersion=1;mode='portable';workstationId=$name;runtimeRoot=$runtime;backupRoot=(Join-Path $runtime 'backups');ides=@();bindings=@(@{identity=$identity;remoteIdentity=$identity;path=$checkout;dossier=$dossier;fingerprint=('fixture-'+$name)})})
    $ids[$name]=@{name=$name;config=$cfg;checkout=$checkout;runtime=$runtime}
}
$script:brainScripts=Join-Path $brain 'scripts'
# Runs a CLI process; $Environment values are set only for it. Returns exit code and output.
function Start-Cli([string]$Script,[string[]]$Arguments){
    $info=[Diagnostics.ProcessStartInfo]::new((Get-Command pwsh).Source)
    foreach($a in @('-NoProfile','-File',(Join-Path $script:brainScripts $Script))+$Arguments){$info.ArgumentList.Add($a)}
    $info.UseShellExecute=$false;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true;$info.Environment['SECONDBRAIN_LANG']='en'
    $info.Environment.Remove('SECONDBRAIN_HOME')|Out-Null
    $process=[Diagnostics.Process]::Start($info)
    @{process=$process;out=$process.StandardOutput.ReadToEndAsync();err=$process.StandardError.ReadToEndAsync()}
}
function Wait-Cli($Handle){$Handle.process.WaitForExit();@{code=$Handle.process.ExitCode;out=$Handle.out.Result;err=$Handle.err.Result}}
function Invoke-Cli([string]$Script,[string[]]$Arguments){Wait-Cli (Start-Cli $Script $Arguments)}
function Get-IdArgs($Id){@('-ConfigPath',$Id.config,'-CheckoutPath',$Id.checkout)}
$trackerPath=Join-Path $brain "$dossier/tracker.json"
function Read-Tracker{Read-SBJson $trackerPath $null}

# 1. Distinct local state per identity; same dossier.
Assert-Shared ($ids['pc-a'].runtime -ine $ids['pc-b'].runtime -and $ids['pc-a'].checkout -ine $ids['pc-b'].checkout) 'the two identities have different local state and checkouts'
foreach($id in $ids.Values){
    $r=Invoke-Cli 'knowledge.ps1' (@('-Startup')+(Get-IdArgs $id))
    Assert-Shared ($r.code -eq 0 -and $r.out -match 'stato iniziale') ("$($id.name): startup reads the shared dossier through its own binding") ($r.err+$r.out.Substring(0,[Math]::Min(300,$r.out.Length)))
}

# 2. Concurrent task creation from both identities (3 processes each): no lost write, unique numbers, valid tracker.
$handles=@();$titles=@()
foreach($i in 1..3){foreach($id in $ids.Values){
    $title="Concorrente $($id.name) n$i";$titles+=$title
    $handles+=,@{id=$id.name;h=(Start-Cli 'knowledge.ps1' (@('-NewTask',$title,'-Provenance','history/fonte.md','-Acceptance','ok')+(Get-IdArgs $id)))}
}}
$results=@($handles|ForEach-Object {$r=Wait-Cli $_.h;$r.id=$_.id;$r})
Assert-Shared (@($results|Where-Object {$_.code -notin @(0,3)}).Count -eq 0) ('concurrent creations end with 0 or 3 (busy); exits '+(($results|ForEach-Object code) -join ',')) (@($results|Where-Object {$_.code -notin @(0,3)}|ForEach-Object {$_.err})-join ' | ')
foreach($id in $ids.Values){
    $r=Invoke-Cli 'knowledge.ps1' (@('-FlushPending')+(Get-IdArgs $id))
    Assert-Shared ($r.code -eq 0) ("$($id.name): -FlushPending integrates queued requests") ($r.err+$r.out)
}
$data=Read-Tracker;$seqs=@($data.tasks|ForEach-Object seq)
$missing=@($titles|Where-Object {$t=$_;@($data.tasks|Where-Object {$_.title -like "*$t"}).Count -ne 1})
Assert-Shared ($missing.Count -eq 0) 'every request from both identities appears exactly once in the shared tracker' ($missing -join '; ')
Assert-Shared ($data.tasks.Count -eq 7 -and @($seqs|Sort-Object -Unique).Count -eq $seqs.Count -and $data.extensions.lastSeq -eq ($seqs|Measure-Object -Maximum).Maximum) 'tracker valid: 1 + 6 tasks, no duplicate numbers, lastSeq consistent'
Assert-Shared (!(Test-Path -LiteralPath (Join-Path $brain '.runtime/access/para-transaction.json'))) 'no pending transaction marker after the race'
$pend=Invoke-Cli 'knowledge.ps1' (@('-PendingWrites','-PendingState','conflict','-PendingSummary')+(Get-IdArgs $ids['pc-a']))
Add-Observation ('pending conflicts after task creation: '+($pend.out -replace '\s+',' ').Trim())

# 3. Same file, same base hash, two identities: exactly one content wins, the other is a visible conflict and nothing is lost silently.
$contextPath=Join-Path $brain "$dossier/context.md";$base=Get-SBFileHash $contextPath
$payloads=@{};foreach($id in $ids.Values){$p=Join-Path $root ('payload-'+$id.name+'.md');[IO.File]::WriteAllText($p,"# Contesto`naggiornamento di $($id.name)`n");$payloads[$id.name]=$p}
$handles=@($ids.Values|ForEach-Object {@{id=$_.name;h=(Start-Cli 'knowledge.ps1' (@('-SaveFile','context.md','-ContentPath',$payloads[$_.name],'-ExpectedHash',$base)+(Get-IdArgs $_)))}})
$saveResults=@($handles|ForEach-Object {$r=Wait-Cli $_.h;$r.id=$_.id;$r})
Assert-Shared (@($saveResults|Where-Object {$_.code -notin @(0,3,5)}).Count -eq 0 -and @($saveResults|Where-Object code -eq 0).Count -ge 1) ('conflicting saves end with 0 (applied), 3 (busy) or 5 (conflict recorded), at least one applied; exits '+(($saveResults|ForEach-Object code) -join ',')) (@($saveResults|ForEach-Object {$_.err+$_.out})-join ' | ')
foreach($id in $ids.Values){$null=Invoke-Cli 'knowledge.ps1' (@('-FlushPending')+(Get-IdArgs $id))}
$final=[IO.File]::ReadAllText($contextPath)
$winners=@($ids.Keys|Where-Object {$final -ceq "# Contesto`naggiornamento di $_`n"})
Assert-Shared ($winners.Count -eq 1) 'shared file: final content is exactly one identity''s content, never mixed or the original' $final
$loser=@($ids.Keys|Where-Object {$_ -ne $winners[0]})[0]
$conflicts=Invoke-Cli 'knowledge.ps1' (@('-PendingWrites','-PendingState','conflict')+(Get-IdArgs $ids[$loser]))
Assert-Shared ($conflicts.code -eq 0 -and $conflicts.out -match 'conflict') "the losing identity ($loser) has its write kept as a visible conflict, not lost" $conflicts.out
$backupHit=@(Get-ChildItem -LiteralPath (Join-Path $brain '.runtime') -Recurse -File -ErrorAction SilentlyContinue|Where-Object {$_.Name -like '*.bin' -or $_.Name -like '*.git.json'}|Where-Object {$_.Length -gt 0}).Count
Add-Observation ("saved context.md winner: $($winners[0]); loser: $loser; backup files under .runtime: $backupHit")

# 4. Read during writing: identity A holds an exclusive write session; identity B reads without a blocking wait.
$start=Invoke-Cli 'access.ps1' (@('-Start','-Mode','Write','-Exclusive','-Client','shared-fixture','-ConfigPath',$ids['pc-a'].config,'-TargetPath',$ids['pc-a'].checkout))
Assert-Shared ($start.code -eq 0) 'pc-a opens an exclusive write session' ($start.err+$start.out)
$sessionA=($start.out|ConvertFrom-Json).sessionId
try{
    $watch=[Diagnostics.Stopwatch]::StartNew()
    $read=Invoke-Cli 'knowledge.ps1' (@('-Startup')+(Get-IdArgs $ids['pc-b']))
    $watch.Stop()
    Assert-Shared ($read.code -eq 0 -and $watch.Elapsed.TotalSeconds -lt 30) ('pc-b reads while pc-a writes, without a blocking wait ('+[int]$watch.Elapsed.TotalSeconds+' s)') ($read.err+$read.out.Substring(0,[Math]::Min(200,$read.out.Length)))
    Assert-Shared ($read.err -match 'writ|scritt|session|sessione|owner|active|attiv' -or $read.out -match 'writ|scritt') 'the read reports the active writer' $read.err
    # Writer vs writer: pc-b cannot take the exclusive write lock while pc-a holds it (exit 3 after a short wait).
    $busy=Invoke-Cli 'access.ps1' (@('-Start','-Mode','Write','-Exclusive','-Client','shared-fixture','-WaitSeconds','2','-ConfigPath',$ids['pc-b'].config,'-TargetPath',$ids['pc-b'].checkout))
    Assert-Shared ($busy.code -eq 3) 'a second exclusive writer from the other identity times out with exit 3' ($busy.err+$busy.out)
}finally{
    $null=Invoke-Cli 'access.ps1' @('-End','-SessionId',$sessionA,'-ConfigPath',$ids['pc-a'].config)
}
# After release, pc-b takes the writer lock and the registry holds both identities with distinct roots.
$start=Invoke-Cli 'access.ps1' (@('-Start','-Mode','Write','-Exclusive','-Client','shared-fixture','-ConfigPath',$ids['pc-b'].config,'-TargetPath',$ids['pc-b'].checkout))
Assert-Shared ($start.code -eq 0) 'after pc-a ends, pc-b opens its exclusive write session' ($start.err+$start.out)
$null=Invoke-Cli 'access.ps1' @('-End','-SessionId',(($start.out|ConvertFrom-Json).sessionId),'-ConfigPath',$ids['pc-b'].config)
$registry=Read-SBJson (Join-Path $brain '.runtime/access/workstations.json') @{}
Assert-Shared ($registry.ContainsKey('pc-a') -and $registry.ContainsKey('pc-b') -and $registry['pc-a'].runtimeRoot -ine $registry['pc-b'].runtimeRoot) 'the workstation registry lists both identities with distinct runtime roots'

# 5. A third identity cannot reuse another identity's local state (runtime/backup roots) on the shared root.
$clash=Join-Path $brain '.runtime/hosts/pc-c/workstation.json'
$cfgA=Read-SBJson $ids['pc-a'].config $null;$cfgA.workstationId='pc-c'
Put ([IO.Path]::GetRelativePath($brain,$clash)) (ConvertTo-SBJson $cfgA)
$r=Invoke-Cli 'knowledge.ps1' @('-Compact','-Apply','-ConfigPath',$clash,'-CheckoutPath',$ids['pc-a'].checkout)
Assert-Shared ($r.code -ne 0 -and ($r.err+$r.out) -match 'runtime|backup|root|radic|percors') 'a different identity pointing at pc-a''s runtime/backup roots is refused' ($r.err+$r.out)

$esito=[ordered]@{schemaVersion=1;suite='shared';checks=$script:checks;observedAt=[DateTimeOffset]::UtcNow.ToString('o');fixture=$root;observations=@($script:observations)
    limits=@('Both identities run on this PC and user: MachineName and SID are the same; only workstationId, local state, checkout and binding differ.','No SMB, NAS or Samba: the root is local; FileShare, leases, latency and clock skew across PCs are not exercised.','Real two-PC qualification remains in #348.')}
[IO.File]::WriteAllText((Join-Path $root 'report.json'),(ConvertTo-SBJson $esito),[Text.UTF8Encoding]::new($false))
'SUCCESS SHARED: '+$script:checks+' checks; retained fixture '+$root
