#requires -Version 7.5
# .runtime layout: folder names, migration plan/apply, regenerable targets, protected areas. Synthetic fixture only.
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Host.psm1') -Force
. (Join-Path $PSScriptRoot 'test-helpers.ps1')
$script:runtimeChecks=0
function Assert-Runtime($Condition,[string]$Message){if(!$Condition){throw 'FAIL RUNTIME: '+$Message};$script:runtimeChecks++;'PASS RUNTIME: '+$Message}
$stamp=Get-Date -Format 'yyyyMMdd'
$root=Join-Path (Get-SBTestRoot) ('fixture-'+$stamp+'-runtime-'+[guid]::NewGuid().ToString('N').Substring(0,8))
$brain=Join-Path $root 'brain';$runtime=Join-Path $brain '.runtime'
$hostId='ws-0123456789abcdef';$segment='demo-0a1b2c3d'
function New-Dir([string]$Relative,[string]$File='data.txt'){$p=Join-Path $runtime $Relative;[IO.Directory]::CreateDirectory($p)|Out-Null;if($File){[IO.File]::WriteAllText((Join-Path $p $File),'x')};$p}
function Set-Old([string]$Path){Get-ChildItem -LiteralPath $Path -Recurse -Force|ForEach-Object {$_.LastWriteTimeUtc=[DateTime]::UtcNow.AddDays(-3)};(Get-Item -LiteralPath $Path).LastWriteTimeUtc=[DateTime]::UtcNow.AddDays(-3)}
# Folder names.
$d=[DateTime]::new(2026,11,5)
Assert-Runtime ((ConvertTo-SBRuntimeFolderName 'work-20261103-lotto-241' $d) -ceq '20261103-lotto-241') 'prefisso di categoria rimosso'
Assert-Runtime ((ConvertTo-SBRuntimeFolderName '20261104-work-20261104-lotto-299' $d) -ceq '20261104-lotto-299') 'data e prefisso duplicati rimossi'
Assert-Runtime ((ConvertTo-SBRuntimeFolderName 'Cartella Strana!' $d) -ceq '20261105-cartella-strana') 'nome libero normalizzato con la data di scrittura'
Assert-Runtime ((ConvertTo-SBRuntimeFolderName 'report-20261104-mem04-b948e421' $d) -cmatch '^20261104-mem04-b948e421$') 'report con hash conservato'
# Nested path validation.
Assert-Runtime ((Get-SBRuntimeWorkPath $brain $hostId 'github.com/o/demo' 'work' 'prova' $d) -match 'repos[\\/]demo-[0-9a-f]{8}[\\/]work[\\/]20261105-prova$') 'percorso annidato work'
$rejected=$false;try{Get-SBRuntimeWorkPath $brain $hostId 'github.com/o/demo' 'altro' 'prova' $d|Out-Null}catch{$rejected=$true}
Assert-Runtime $rejected 'categoria sconosciuta rifiutata'
# Fixture .runtime.
New-Dir 'access' 'writer.lock'|Out-Null
New-Dir 'work-20261103-uno'|Out-Null;New-Dir 'evidence-20261103-due'|Out-Null;New-Dir 'report-20261103-tre'|Out-Null
New-Dir 'backup-20261103-install-abc'|Out-Null;New-Dir 'backup/mcp-pairing' 'a.bin'|Out-Null
New-Dir 'fixture-20261103-vecchia'|Out-Null;New-Dir 'tmp-20261103-vecchia'|Out-Null;New-Dir 'vuota' $null|Out-Null
New-Dir 'mcp-handshake' 'handshake-1.json'|Out-Null
[IO.File]::WriteAllText((Join-Path $runtime 'fast-run.log'),'log')
New-Dir ('hosts/'+$hostId+'/evidence-20261105-host') 'e.txt'|Out-Null
New-Dir ('hosts/'+$hostId+'/repos/demo/work/work-20261103-dup') 'w.txt'|Out-Null
New-Dir ('hosts/'+$hostId+'/repos/'+$segment+'/work/20261104-work-20261104-doppio') 'w.txt'|Out-Null
New-Dir ('hosts/'+$hostId+'/repos/'+$segment+'/work/20261104-ok') 'w.txt'|Out-Null
New-Dir ('hosts/'+$hostId+'/repos/'+$segment+'/work/work-20261104-dup') 'w.txt'|Out-Null
New-Dir ('hosts/'+$hostId+'/repos/'+$segment+'/work/20261104-dup') 'w.txt'|Out-Null
foreach($n in 1..7){New-Dir ('hosts/'+$hostId+'/repos/'+$segment+'/fixture/2026110'+$n+'-f'+$n) 'f.txt'|Out-Null}
foreach($p in Get-ChildItem -LiteralPath $runtime -Directory -Force){Set-Old $p.FullName}
(Get-Item -LiteralPath (Join-Path $runtime 'fast-run.log')).LastWriteTimeUtc=[DateTime]::UtcNow.AddDays(-3)
foreach($p in Get-ChildItem -LiteralPath (Join-Path $runtime 'hosts') -Recurse -Directory -Force){Set-Old $p.FullName}
# Migration plan: preview changes nothing.
$plan=Get-SBRuntimeMigrationPlan $brain $hostId $segment 10
$kinds=@($plan.moves|ForEach-Object {$_.kind}|Sort-Object -Unique)
Assert-Runtime (Test-Path -LiteralPath (Join-Path $runtime 'work-20261103-uno')) 'anteprima: nessuna cartella spostata'
foreach($k in 'flat-work','flat-evidence','flat-report','install-backup','backup-merge','log','host-evidence','merge-segment','rename'){Assert-Runtime ($k -in $kinds) ('piano contiene '+$k)}
Assert-Runtime (!@($plan.moves|Where-Object {$_.fromRelative -like 'fixture-*' -or $_.fromRelative -like 'tmp-*'})) 'fixture e tmp piatte non migrate (si rimuovono come rigenerabili)'
$destinations=@($plan.moves|ForEach-Object {$_.to.ToLowerInvariant()})
Assert-Runtime ($destinations.Count -eq @($destinations|Sort-Object -Unique).Count) 'destinazioni uniche (collisioni risolte con suffisso)'
Assert-Runtime (@($plan.moves|Where-Object {$_.toRelative -like '*20261104-dup-2'}).Count -eq 1) 'collisione di nome risolta'
# Recently written folders are skipped.
$fresh=New-Dir 'work-20261105-appena';$freshPlan=Get-SBRuntimeMigrationPlan $brain $hostId $segment 10
Assert-Runtime (@($freshPlan.skipped|Where-Object {$_.from -eq 'work-20261105-appena'}).Count -eq 1) 'cartella appena scritta saltata'
Remove-Item -LiteralPath $fresh -Recurse -Force
# Apply.
$result=Invoke-SBRuntimeMigration $brain $plan
Assert-Runtime ($result.failed.Count -eq 0) 'migrazione senza errori'
$target=Join-Path $runtime ('hosts/'+$hostId+'/repos/'+$segment)
Assert-Runtime (Test-Path -LiteralPath (Join-Path $target 'work/20261103-uno/data.txt')) 'work piatta nel layout annidato'
Assert-Runtime (Test-Path -LiteralPath (Join-Path $target 'evidence/20261103-due/MANIFEST.json')) 'MANIFEST.json scritto per evidence'
$manifest=Get-Content -LiteralPath (Join-Path $target 'work/20261103-uno/MANIFEST.json') -Raw|ConvertFrom-Json
Assert-Runtime ($manifest.status -eq 'migrated' -and $manifest.category -eq 'work' -and $manifest.created -eq '2026-11-03') 'manifest con categoria, data e stato'
Assert-Runtime (Test-Path -LiteralPath (Join-Path $runtime ('hosts/'+$hostId+'/install-backups/20261103-install-abc'))) 'backup di installazione riordinato'
Assert-Runtime ((Test-Path -LiteralPath (Join-Path $runtime 'backups/mcp-pairing/a.bin')) -and !(Test-Path -LiteralPath (Join-Path $runtime 'backup'))) 'backup/ unito in backups/ e rimosso'
Assert-Runtime ((Test-Path -LiteralPath (Join-Path $runtime 'logs/fast-run.log')) -and !(Test-Path -LiteralPath (Join-Path $runtime 'fast-run.log'))) 'log spostato in logs/'
Assert-Runtime (!(Test-Path -LiteralPath (Join-Path $runtime ('hosts/'+$hostId+'/repos/demo')))) 'segmento duplicato svuotato e rimosso'
Assert-Runtime (Test-Path -LiteralPath (Join-Path $target 'work/20261103-dup/w.txt')) 'segmento duplicato unito'
Assert-Runtime (Test-Path -LiteralPath (Join-Path $runtime 'access/writer.lock')) 'access/ intatto'
Assert-Runtime (!@((Get-SBRuntimeMigrationPlan $brain $hostId $segment 0).moves)) 'seconda esecuzione: nulla da spostare'
# Regenerable selector: retain legacy data, require explicit verified ownership.
$identity=@{HostId=$hostId;OwnerUser='fixture-user';OwnerComputer='fixture-pc'}
$legacy=Get-SBRegenerableRuntimeTargets $brain @() 5 0 @identity
Assert-Runtime ($legacy.targets.Count -eq 0) 'legacy e manifest mancanti esclusi'
Assert-Runtime (@($legacy.skipped|Where-Object reasonCode -eq 'unsupported-layout').Count -ge 4) 'legacy, handshake e cartelle vuote con motivo'
$unknown=Get-SBRegenerableRuntimeTargets $brain @() 0 0
Assert-Runtime ($unknown.targets.Count -eq 0 -and $unknown.skipped[0].reasonCode -eq 'identity-unverified') 'identita sconosciuta non seleziona dati'
# Separate synthetic brain: none of the migration evidence above is removed.
$safeBrain=Join-Path $root 'selector';$safeRuntime=Join-Path $safeBrain '.runtime'
$testBackups=Join-Path $root 'write-backups'
function Write-RuntimeFixture([string]$Path,[string]$Text){
    Write-SBFile $Path ([Text.UTF8Encoding]::new($false).GetBytes($Text)) (Get-SBFileHash $Path) $testBackups|Out-Null
}
function New-SafeFolder([string]$Name,[hashtable]$Overrides=@{},[string]$Category='fixture',[string]$Repo=$segment,[string]$HostName=$hostId){
    $path=Join-Path $safeRuntime ('hosts/'+$HostName+'/repos/'+$Repo+'/'+$Category+'/'+$Name)
    [IO.Directory]::CreateDirectory($path)|Out-Null
    $record=@{schemaVersion=1;name=$Name;hostId=$HostName;repository=$Repo;category=$Category;owner=@{user=$identity.OwnerUser;computer=$identity.OwnerComputer;client='test'};status='closed';expires=(Get-Date).AddDays(-1).ToString('yyyy-MM-dd');task='synthetic runtime selector checks';sessionId='fixture'}
    foreach($key in $Overrides.Keys){$record[$key]=$Overrides[$key]}
    Write-RuntimeFixture (Join-Path $path 'MANIFEST.json') (ConvertTo-SBJson $record)
    Write-RuntimeFixture (Join-Path $path 'data.txt') 'safe'
    Set-Old $path
    $path
}
function Get-SafePlan([int]$Keep=0,[int]$Age=0,[string[]]$Protected=@()){
    Get-SBRegenerableRuntimeTargets $safeBrain $Protected $Keep $Age @identity
}
function Assert-SafeSkip([string]$Path,[string]$Code){
    $entry=@((Get-SafePlan).skipped|Where-Object {Test-SBSamePath $_.path $Path})
    Assert-Runtime ($entry.Count -eq 1 -and $entry[0].reasonCode -eq $Code) ('esclusione '+$Code+': '+(Split-Path $Path -Leaf))
}
function Get-SafeTarget([string]$Path){(Get-SafePlan).targets|Where-Object {Test-SBSamePath $_.path $Path}}
function Remove-SafeTarget($Target,[int]$Keep=0){
    Remove-SBRegenerableRuntimeTarget $Target $safeBrain @() $Keep 0 @identity
}
# Deterministic newest-five retention is independent per repository/category.
foreach($n in 1..7){
    $folder=New-SafeFolder ('2020010'+$n+'-f'+$n)
    (Get-Item -LiteralPath $folder).LastWriteTimeUtc=[DateTime]::new(2020,1,1,0,0,0,[DateTimeKind]::Utc).AddDays($n)
}
$plan=Get-SafePlan 5
Assert-Runtime ($plan.targets.Count -eq 2 -and $plan.skipped.Count -eq 5) 'ultime cinque cartelle conservate'
Assert-Runtime ($plan.targets[0].relative -like '*20200102-f2' -and $plan.targets[1].relative -like '*20200101-f1') 'ordine dalla piu recente, oltre retention'
$other=New-SafeFolder '20200101-other' @{} 'fixture' 'other-12345678'
$tmp=New-SafeFolder '20200101-tmp' @{} 'tmp'
Assert-Runtime ((Get-SafePlan 5).targets.Count -eq 2) 'retention separata per repository e categoria'
# All metadata/date boundaries, including path consistency and malformed types.
$cases=@(
    @{name='schema';change=@{schemaVersion=2};code='manifest-invalid'},
    @{name='string-schema';change=@{schemaVersion='1'};code='manifest-invalid'},
    @{name='bool-schema';change=@{schemaVersion=$true};code='manifest-invalid'},
    @{name='host';change=@{hostId='ws-other'};code='manifest-invalid'},
    @{name='repository';change=@{repository='wrong'};code='manifest-invalid'},
    @{name='category';change=@{category='work'};code='manifest-invalid'},
    @{name='name';change=@{name='wrong'};code='manifest-invalid'},
    @{name='owner-invalid';change=@{owner='wrong'};code='manifest-invalid'},
    @{name='owner';change=@{owner=@{user='other';computer=$identity.OwnerComputer}};code='foreign-owner'},
    @{name='computer';change=@{owner=@{user=$identity.OwnerUser;computer='other'}};code='foreign-owner'},
    @{name='open';change=@{status='open'};code='manifest-not-closed'},
    @{name='migrated';change=@{status='migrated'};code='manifest-not-closed'},
    @{name='expiry-null';change=@{expires=$null};code='manifest-expiry-invalid'},
    @{name='expiry-invalid';change=@{expires='2026-02-30'};code='manifest-expiry-invalid'},
    @{name='expiry-today';change=@{expires=(Get-Date).ToString('yyyy-MM-dd')};code='manifest-not-expired'},
    @{name='expiry-future';change=@{expires=(Get-Date).AddDays(1).ToString('yyyy-MM-dd')};code='manifest-not-expired'}
)
foreach($case in $cases){$path=New-SafeFolder ('20200101-'+$case.name) $case.change;Assert-SafeSkip $path $case.code}
$foreign=New-SafeFolder '20200101-foreign' @{} 'fixture' $segment 'ws-foreign'
Assert-SafeSkip (Join-Path $safeRuntime 'hosts/ws-foreign') 'foreign-host'
$missing=Join-Path $safeRuntime ('hosts/'+$hostId+'/repos/'+$segment+'/tmp/20200101-missing')
[IO.Directory]::CreateDirectory($missing)|Out-Null
Assert-SafeSkip $missing 'manifest-missing'
$corrupt=New-SafeFolder '20200101-corrupt';Write-RuntimeFixture (Join-Path $corrupt 'MANIFEST.json') '{bad'
Assert-SafeSkip $corrupt 'manifest-invalid'
$incomplete=New-SafeFolder '20200101-incomplete'
Write-RuntimeFixture (Join-Path $incomplete 'MANIFEST.json') '{"schemaVersion":1}'
Assert-SafeSkip $incomplete 'manifest-invalid'
$invalidName=New-SafeFolder 'not-a-dated-folder'
Assert-SafeSkip $invalidName 'unsupported-layout'
$protected=New-SafeFolder '20200101-protected'
$protectedPlan=Get-SafePlan 0 0 @((Join-Path $protected 'data.txt'))
Assert-Runtime (@($protectedPlan.skipped|Where-Object {$_.path -eq $protected -and $_.reasonCode -eq 'protected-path'}).Count -eq 1) 'contenuto protetto escluso'
$fresh=New-SafeFolder '20200101-fresh'
(Get-Item -LiteralPath (Join-Path $fresh 'data.txt')).LastWriteTimeUtc=[DateTime]::UtcNow
Assert-Runtime (@((Get-SafePlan 0 10).skipped|Where-Object {$_.path -eq $fresh -and $_.reasonCode -eq 'recently-written'}).Count -eq 1) 'scrittura recente esclusa anche con scadenza trascorsa'
# Ties use path order, so repeated previews select the same folder.
$tieA=New-SafeFolder '20200101-a' @{} 'fixture' 'tie-12345678'
$tieB=New-SafeFolder '20200101-b' @{} 'fixture' 'tie-12345678'
foreach($path in @($tieA,$tieB)){(Get-Item -LiteralPath $path).LastWriteTimeUtc=[DateTime]::new(2020,1,1)}
$tiePlan=Get-SafePlan 1
Assert-Runtime (@($tiePlan.skipped|Where-Object {$_.path -eq $tieA -and $_.reasonCode -eq 'retention'}).Count -eq 1 -and @($tiePlan.targets|Where-Object path -eq $tieB).Count -eq 1) 'spareggio deterministico sul percorso'
# Junctions at the folder, category and content boundaries never expose their target.
$sentinel=Join-Path $root 'sentinel';[IO.Directory]::CreateDirectory($sentinel)|Out-Null
Write-RuntimeFixture (Join-Path $sentinel 'keep.txt') 'unchanged'
$linkFolder=New-SafeFolder '20200101-link-content'
New-Item -ItemType Junction -Path (Join-Path $linkFolder 'link') -Target $sentinel|Out-Null
Assert-SafeSkip $linkFolder 'reparse-point'
$folderLink=Join-Path $safeRuntime ('hosts/'+$hostId+'/repos/'+$segment+'/tmp/20200101-link-folder')
New-Item -ItemType Junction -Path $folderLink -Target $sentinel|Out-Null
Assert-SafeSkip $folderLink 'reparse-point'
$linkedRepo=Join-Path $safeRuntime ('hosts/'+$hostId+'/repos/link-12345678')
[IO.Directory]::CreateDirectory($linkedRepo)|Out-Null
New-Item -ItemType Junction -Path (Join-Path $linkedRepo 'fixture') -Target $sentinel|Out-Null
Assert-SafeSkip (Join-Path $linkedRepo 'fixture') 'reparse-point'
Assert-Runtime ((Read-SBText (Join-Path $sentinel 'keep.txt')) -ceq 'unchanged') 'contenuto dietro junction conservato'
# Preview is read-only and repeatable; unknown identity never produces candidates.
$before=Get-SBFileHash (Join-Path $other 'MANIFEST.json')
$first=Get-SafePlan;$second=Get-SafePlan
Assert-Runtime ((ConvertTo-SBJson $first) -ceq (ConvertTo-SBJson $second) -and (Get-SBFileHash (Join-Path $other 'MANIFEST.json')) -ceq $before) 'anteprime identiche, nessuna modifica'
# Apply rechecks the manifest, data hashes, membership, retention and protected paths.
$changed=New-SafeFolder '20200101-changed'
$selected=Get-SafeTarget $changed
$record=Read-SBJson (Join-Path $changed 'MANIFEST.json') $null;$record.status='open'
Write-RuntimeFixture (Join-Path $changed 'MANIFEST.json') (ConvertTo-SBJson $record)
$outcome=Remove-SafeTarget $selected
Assert-Runtime (!$outcome.removed -and $outcome.reasonCode -eq 'target-changed' -and (Test-Path -LiteralPath $changed)) 'manifest cambiato dopo selezione: rimozione rifiutata'
$dataChanged=New-SafeFolder '20200101-data-changed'
$selected=Get-SafeTarget $dataChanged;$dataPath=Join-Path $dataChanged 'data.txt';$time=(Get-Item -LiteralPath $dataPath).LastWriteTimeUtc
Write-RuntimeFixture $dataPath 'edit';(Get-Item -LiteralPath $dataPath).LastWriteTimeUtc=$time
Assert-Runtime (!(Remove-SafeTarget $selected).removed -and (Test-Path -LiteralPath $dataChanged)) 'stessa dimensione e data, contenuto modificato conservato'
$added=New-SafeFolder '20200101-added';$selected=Get-SafeTarget $added
Write-RuntimeFixture (Join-Path $added 'new.txt') 'new'
Assert-Runtime (!(Remove-SafeTarget $selected).removed -and (Test-Path -LiteralPath $added)) 'nuovo file dopo selezione conservato'
$retained=New-SafeFolder '20200101-retained' @{} 'fixture' 'retained-12345678';$selected=Get-SafeTarget $retained
Assert-Runtime (!(Remove-SafeTarget $selected 1).removed -and (Test-Path -LiteralPath $retained)) 'retention ricontrollata in applicazione'
$selected=Get-SafeTarget $protected
$outcome=Remove-SBRegenerableRuntimeTarget $selected $safeBrain @((Join-Path $protected 'data.txt')) 0 0 @identity
Assert-Runtime (!$outcome.removed -and (Test-Path -LiteralPath $protected)) 'protezione ricontrollata in applicazione'
$selected=Get-SafeTarget $tmp
$outcome=Remove-SafeTarget $selected
Assert-Runtime ($outcome.removed -and !(Test-Path -LiteralPath $tmp)) 'target tmp invariato rimosso solo nella fixture sintetica'
# Test-runner fixture lifecycle: managed manifest opens with the run, closes on every outcome and is selected only after expiry.
. (Join-Path $PSScriptRoot 'test-run-evidence.ps1')
$runnerIdentity=@{HostId=$hostId;OwnerUser="$env:USERNAME";OwnerComputer="$env:COMPUTERNAME"}
$runnerBase=Join-Path $safeRuntime ('hosts/'+$hostId+'/repos/tests-0a1b2c3d/fixture/20200101-minimal')
[IO.Directory]::CreateDirectory((Join-Path $runnerBase 'run-aaaaaaaa'))|Out-Null
function Get-RunnerEntry{
    $plan=Get-SBRegenerableRuntimeTargets $safeBrain @() 0 0 @runnerIdentity
    @($plan.targets+$plan.skipped|Where-Object {Test-SBSamePath $_.path $runnerBase})
}
$runnerManifest=Open-SBTestFixtureManifest $runnerBase $hostId 'tests-0a1b2c3d'
$opened=Read-SBJson $runnerManifest $null
Assert-Runtime ($opened.status -ceq 'open' -and $opened.category -ceq 'fixture' -and $opened.name -ceq '20200101-minimal' -and $opened.hostId -ceq $hostId) 'manifest fixture runner aperto con campi coerenti'
Assert-Runtime (@(Get-RunnerEntry)[0].reasonCode -ceq 'manifest-not-closed') 'fixture runner aperta mai selezionata'
$runnerRun=@{manifest=$runnerManifest;baseRoot=$runnerBase;runId='run-aaaaaaaa'}
[IO.Directory]::CreateDirectory((Join-Path $runnerBase 'run-bbbbbbbb'))|Out-Null
[IO.File]::WriteAllText((Join-Path $runnerBase 'run-bbbbbbbb/run.json'),'{"status":"running"}')
Close-SBTestFixtureManifest $runnerRun
Assert-Runtime ((Read-SBJson $runnerManifest $null).status -ceq 'open') 'esecuzione concorrente attiva: contenitore non chiuso'
[IO.File]::WriteAllText((Join-Path $runnerBase 'run-bbbbbbbb/run.json'),'{"status":"failed"}')
Close-SBTestFixtureManifest $runnerRun
$closed=Read-SBJson $runnerManifest $null
Assert-Runtime ($closed.status -ceq 'closed' -and $closed.closed) 'manifest chiuso anche dopo esecuzione fallita'
$closed.expires=(Get-Date).AddDays(-1).ToString('yyyy-MM-dd')
Write-RuntimeFixture $runnerManifest (ConvertTo-SBJson $closed)
Set-Old $runnerBase
$entry=@(Get-RunnerEntry)
Assert-Runtime ($entry.Count -eq 1 -and !$entry[0].ContainsKey('reasonCode') -and $entry[0].kind -ceq 'nested-fixture') 'fixture runner chiusa e scaduta selezionabile'
$reopened=Read-SBJson (Open-SBTestFixtureManifest $runnerBase $hostId 'tests-0a1b2c3d') $null
Assert-Runtime ($reopened.status -ceq 'open' -and !$reopened.ContainsKey('closed') -and $reopened.created -ceq $closed.created) 'ripresa nello stesso giorno riapre senza perdere la data di creazione'
$legacyRunner=Join-Path $safeRuntime ('hosts/'+$hostId+'/repos/tests-0a1b2c3d/fixture/fixture-20200101-minimal')
[IO.Directory]::CreateDirectory($legacyRunner)|Out-Null
Assert-SafeSkip $legacyRunner 'unsupported-layout'
Assert-Runtime (!(Test-Path -LiteralPath (Join-Path $legacyRunner 'MANIFEST.json'))) 'fixture storiche senza manifest retroattivo'
Assert-Runtime ((Test-Path -LiteralPath $foreign) -and (Test-Path -LiteralPath $missing) -and (Test-Path -LiteralPath (Join-Path $runtime 'fixture-20261103-vecchia')) -and (Test-Path -LiteralPath (Join-Path $target 'work/20261103-uno'))) 'dati esclusi, prove e legacy conservati'
# Real CLI in an isolated synthetic installation: no access to workstation data.
$cliBrain=Join-Path $root 'cli';$cliScripts=Join-Path $cliBrain 'scripts'
[IO.Directory]::CreateDirectory($cliScripts)|Out-Null
foreach($file in @('cleanup.ps1','SecondBrain.Core.psm1','SecondBrain.Messages.psm1','SecondBrain.Access.psm1','SecondBrain.Host.psm1')){
    Write-RuntimeFixture (Join-Path $cliScripts $file) (Read-SBText (Join-Path $PSScriptRoot $file))
}
$cliHost=Get-SBHostId;$cliHostRoot=Join-Path $cliBrain ('.runtime/hosts/'+$cliHost)
$cliConfig=Join-Path $cliHostRoot 'workstation.json'
Write-RuntimeFixture $cliConfig (ConvertTo-SBJson @{schemaVersion=1;mode='portable';workstationId=$cliHost;runtimeRoot=$cliHostRoot;backupRoot=(Join-Path $cliHostRoot 'backups');bindings=@();ides=@()})
Write-RuntimeFixture (Join-Path $cliBrain 'config/shared.json') (ConvertTo-SBJson @{schemaVersion=1;allowedOwners=@('fixture');excludedDirectories=@()})
$cliFolder=Join-Path $cliHostRoot ('repos/'+$segment+'/tmp/20200101-cli')
[IO.Directory]::CreateDirectory($cliFolder)|Out-Null
$cliManifest=@{schemaVersion=1;hostId=$cliHost;repository=$segment;category='tmp';name='20200101-cli';owner=@{user=([Security.Principal.WindowsIdentity]::GetCurrent().Name -split '\\')[-1];computer=[Environment]::MachineName};status='closed';expires=(Get-Date).AddDays(-1).ToString('yyyy-MM-dd');task='isolated CLI regression'}
Write-RuntimeFixture (Join-Path $cliFolder 'MANIFEST.json') (ConvertTo-SBJson $cliManifest)
Write-RuntimeFixture (Join-Path $cliFolder 'data.txt') 'cli-data'
Set-Old $cliFolder
$cliArgs=@('-NoProfile','-File',(Join-Path $cliScripts 'cleanup.ps1'),'-ConfigPath',$cliConfig,'-Regenerable','-KeepFixtures','0','-MinAgeMinutes','0')
$preview=@(& pwsh @cliArgs);$previewCode=$LASTEXITCODE
$previewData=($preview -join [Environment]::NewLine)|ConvertFrom-Json
Assert-Runtime ($previewCode -eq 0 -and !$previewData.applied -and $previewData.targets.Count -eq 1 -and (Test-Path -LiteralPath $cliFolder) -and !(Test-Path -LiteralPath (Join-Path $cliBrain '.runtime/cleanup'))) 'CLI anteprima: target valido, nessuna rimozione o journal'
$denied=@(& pwsh @cliArgs -Apply 2>&1);$deniedCode=$LASTEXITCODE
Assert-Runtime ($deniedCode -ne 0 -and (Test-Path -LiteralPath $cliFolder)) 'CLI Apply senza Authorization rifiutato'
$application=@(& pwsh @cliArgs -Apply -Authorization 'Task 328 approved plan: removal only inside this newly created synthetic CLI fixture')
$applicationCode=$LASTEXITCODE;$appliedData=($application -join [Environment]::NewLine)|ConvertFrom-Json
$journal=Read-SBJson $appliedData.registry $null
Assert-Runtime ($applicationCode -eq 0 -and $appliedData.applied -and $journal.status -eq 'completed' -and $journal.items.Count -eq 1 -and $journal.items[0].relative -eq $previewData.targets[0].relative -and !(Test-Path -LiteralPath $cliFolder)) 'CLI applicazione e journal concordano con anteprima nella sola fixture'
Assert-Runtime ((Read-SBText (Join-Path $sentinel 'keep.txt')) -ceq 'unchanged' -and (Test-Path -LiteralPath $foreign)) 'CLI non raggiunge dati esclusi o altre fixture'
"SUCCESS RUNTIME: $script:runtimeChecks checks"
