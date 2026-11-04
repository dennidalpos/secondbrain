#requires -Version 7.5
# One shared synthetic brain; API tests own logic, CLI tests own process boundaries.
[CmdletBinding()]
param([string[]]$Groups=@('portable','trackers','workflows','pending'),[switch]$Extended)
$ErrorActionPreference='Stop'
foreach($name in @('Core','Access','Host','Para','Tracker','Knowledge','Pending','Portable','Mcp','Publication')){Import-Module (Join-Path $PSScriptRoot ('SecondBrain.'+$name+'.psm1'))}
. (Join-Path $PSScriptRoot 'test-helpers.ps1')
. (Join-Path $PSScriptRoot 'test-run-evidence.ps1')
$checks=0
function Check($Value,[string]$Message){if(!$Value){throw ('FAIL ESSENTIAL: '+$Message)};$script:checks++;'PASS ESSENTIAL: '+$Message}
function Reject([scriptblock]$Action,[string]$Message){$caught=$false;try{& $Action|Out-Null}catch{$caught=$true};Check $caught $Message}
function Put([string]$Path,[string]$Text){[void][IO.Directory]::CreateDirectory((Split-Path $Path));[IO.File]::WriteAllText($Path,$Text,[Text.UTF8Encoding]::new($false))}
$fixture=Join-Path (Get-SBTestRoot) ('e-'+[guid]::NewGuid().ToString('N').Substring(0,6))
$brain=Join-Path $fixture 'b';$repo=Join-Path $fixture 'r';$identity='github.com/test/essential'
$dossier=Join-Path $brain '02-areas/products/Essential';$trackerPath=Join-Path $dossier 'tracker.json'
foreach($path in @((Join-Path $brain 'scripts'),$repo)){[void][IO.Directory]::CreateDirectory($path)}
Get-ChildItem -LiteralPath $PSScriptRoot -File|Where-Object {$_.Name -notlike 'test-*'}|Copy-Item -Destination (Join-Path $brain 'scripts')
Put (Join-Path $brain 'VERSION') '1.0.0'
Put (Join-Path $brain 'config/shared.json') (ConvertTo-SBJson @{schemaVersion=1;allowedOwners=@('test');excludedDirectories=@('.git')})
Put (Join-Path $brain 'config/tracker.schema.json') (Read-SBText (Join-Path $PSScriptRoot '../config/tracker.schema.json'))
Put (Join-Path $brain 'direttive/AGENTS.global_ide.md') "# Synthetic`nRevisione 1.0 — 2026-11-04."
Put (Join-Path $brain 'direttive/workstation.template.md') '<!-- secondbrain:tracker-contract:1 -->'
$approval=@{authorization='synthetic test fixture';files=@{}}
foreach($name in @('AGENTS.global_ide.md','workstation.template.md')){$approval.files['direttive/'+$name]=Get-SBFileHash (Join-Path $brain ('direttive/'+$name))}
Put (Join-Path $brain 'direttive/approved.json') (ConvertTo-SBJson $approval)
Put (Join-Path $dossier 'para.json') (ConvertTo-SBJson @{schemaVersion=1;id='essential-area';kind='area';title='Essential';status='active'})
Put (Join-Path $dossier 'repository.json') (ConvertTo-SBJson @{schemaVersion=1;identity=$identity;tracker=@{location='dossier';path='tracker.json';schemaVersion=1}})
Put (Join-Path $dossier 'context.md') "# Context`n`n## Stato corrente`nSynthetic current state.`n`n## Vincoli`nKeep bytes.`n`n## Problemi aperti`nT-1.`n`n## Prossimo passo`nT-1.`n"
Put (Join-Path $dossier 'memory.md') "# Memory`n`n## Decisions`n- Decisione: preserve data — Motivo: synthetic test.`n`n## Events (storico)`nHistorical detail.`n"
Put (Join-Path $dossier 'brief.md') '# Synthetic'
Put (Join-Path $dossier 'history/seed/report.md') 'Synthetic provenance'
$tasks=@(foreach($seq in @(1,2)){$task=New-SBTrackerTask @{id=('T-'+$seq);title=('Task '+$seq);status='todo'} $identity 'fixture' 'history/seed/report.md' (Get-SBTextHash 'Synthetic provenance') 'fixture';$task.seq=$seq;$task.title=('#00'+$seq+' — Task '+$seq);$task})
Put $trackerPath (ConvertTo-SBJson @{schemaVersion=1;repository=$identity;updatedAt=[DateTimeOffset]::UtcNow.ToString('o');tasks=$tasks;history=@();extensions=@{lastSeq=2}})
$otherDossier=Join-Path $brain '02-areas/products/Other'
Put (Join-Path $otherDossier 'brief.md') '# Synthetic other repository'
Put (Join-Path $otherDossier 'context.md') '# Other context'
Put (Join-Path $otherDossier 'memory.md') '# Other memory'
Put (Join-Path $otherDossier 'para.json') (ConvertTo-SBJson @{schemaVersion=1;id='other-area';kind='area';title='Other';status='active'})
Put (Join-Path $otherDossier 'repository.json') (ConvertTo-SBJson @{schemaVersion=1;identity='github.com/test/other';tracker=@{location='dossier';path='tracker.json';schemaVersion=1}})
$otherTask=New-SBTrackerTask @{id='O-1';title='Other';status='done'} 'github.com/test/other' 'fixture' 'history/seed/report.md' (Get-SBTextHash 'Synthetic provenance') 'fixture'
$otherTask.seq=1;$otherTask.title='#001 — Other'
Put (Join-Path $otherDossier 'tracker.json') (ConvertTo-SBJson @{schemaVersion=1;repository='github.com/test/other';updatedAt=[DateTimeOffset]::UtcNow.ToString('o');tasks=@($otherTask);history=@();extensions=@{lastSeq=1}})
& git -C $repo init -q
if($LASTEXITCODE){throw 'Git fixture init failed'}
& git -C $repo remote add origin 'https://github.com/test/essential.git'
if($LASTEXITCODE){throw 'Git fixture remote failed'}
Check ((& git -C $repo rev-parse --show-toplevel).Replace('\','/') -ceq $repo.Replace('\','/')) 'Git fixture is isolated'
$hostId=Get-SBHostId;$runtime=Join-Path $brain ('.runtime/hosts/'+$hostId);$configPath=Join-Path $runtime 'workstation.json'
$cfg=@{schemaVersion=1;mode='portable';brainRoot=$brain;workstationId=$hostId;runtimeRoot=$runtime;backupRoot=(Join-Path $runtime 'backups');repositoryRoot=$brain;coordinationRoot=(Join-Path $brain '.runtime/access');bindings=@(@{identity=$identity;path=$repo;remoteIdentity=$identity});ides=@();sessionTimeoutMinutes=30;lockWaitMs=1000;configPath=$configPath}
Put $configPath (ConvertTo-SBJson $cfg)
$argsBase=@{BrainRoot=$brain;Identity=$identity;WorkingRepository=$identity}
function Invoke-EssentialCli([string[]]$Arguments){$out=@(& pwsh -NoProfile -File (Join-Path $brain 'scripts/knowledge.ps1') -ConfigPath $configPath -CheckoutPath $repo @Arguments 2>&1);@{code=$LASTEXITCODE;text=($out -join "`n")}}

if('portable' -in $Groups){
    $portableModule=Get-Module SecondBrain.Portable
    foreach($case in @(@('',1,$false),@('git version 2.41.9',0,$false),@('unrecognized',0,$false),@('git version 2.42.0',0,$true),@('git version 2.56.0.windows.4',0,$true),@('git version 2.56.0',1,$false))){
        $result=& $portableModule {param($text,$code) Test-SBGitRequirement $text $code} $case[0] $case[1]
        Check ($result.ok -eq $case[2]) ('Git requirement: '+$case[0]+'/'+$case[1])
    }
    $preflight=& $portableModule {param($root) Test-SBSetupPreflight $root} $brain
    Check (@($preflight|Where-Object name -eq 'git')[0].ok) 'installed Git satisfies real preflight'
    $approved=Join-Path $brain 'direttive/workstation.template.md'
    $original=Read-SBText $approved;Put $approved 'unapproved'
    Check (!(Test-SBApproval $brain)) 'changed directives cannot be distributed'
    Put $approved $original
    Check (Test-SBApproval $brain) 'matching approval hashes accepted'
    $discoveryPath=Join-Path $brain '.runtime/discovery.json'
    $discovery=Invoke-SBHostDiscovery -BrainRoot $brain -Roots @($repo) -ReportPath $discoveryPath
    $selectionPath=Join-Path $brain '.runtime/selection.json'
    $selection=@{schemaVersion=1;confirmed=$false;confirmation='fixture';reportPath=$discoveryPath;reportSha256=(Get-SBFileHash $discoveryPath);repositories=@(@{id=$discovery.repositories[0].id});ides=@()}
    Put $selectionPath (ConvertTo-SBJson $selection)
    Reject {Invoke-SBHostActivation $brain $selectionPath -Apply} 'activation without confirmation rejected'
    $selection.confirmed=$true;Put $selectionPath (ConvertTo-SBJson $selection)
    $one=Invoke-SBHostActivation $brain $selectionPath -Apply
    $two=Invoke-SBHostActivation $brain $selectionPath -Apply
    Check ($one.applied -and $two.applied -and (Read-SBJson $one.configuration $null).bindings.Count -eq 1) 'activation is idempotent on one synthetic checkout'
    # Restore the synthetic runtime model used by the following boundary tests.
    Put $configPath (ConvertTo-SBJson $cfg)
    # In-process activation uses the loaded module's root for its registry.
    # Reconcile only this synthetic registry with the copied CLI's root.
    & pwsh -NoProfile -File (Join-Path $brain 'scripts/access.ps1') -Reconcile -ConfigPath $configPath|Out-Null
    if($LASTEXITCODE){throw 'Synthetic registry reconciliation failed'}
    $wire=@('{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26"}}','{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}') -join "`n"
    $out=@($wire|& pwsh -NoProfile -File (Join-Path $brain 'scripts/mcp-server.ps1') -BrainRoot $brain -ConfigPath $configPath)
    $messages=@($out|ForEach-Object {$_|ConvertFrom-Json -AsHashtable})
    Check ($LASTEXITCODE -eq 0 -and $messages[0].result.protocolVersion -eq '2025-03-26' -and $messages[1].result.tools.Count -eq 8) 'real MCP stdio negotiates and exposes eight tools'
}
if('trackers' -in $Groups){
    Reject {Update-SBTrackerTask @argsBase -TaskId T-1} 'empty update rejected'
    foreach($field in @('Priority','Execution')){$bad=@{$field='invalid'};Reject {Update-SBTrackerTask @argsBase -TaskId T-1 @bad} ('invalid '+$field+' rejected')}
    $snapshot=Read-SBJson $trackerPath $null
    [void](Update-SBTrackerTask @argsBase -TaskId T-1 -Priority P1)
    $task=(Read-SBJson $trackerPath $null).tasks[0]
    Check ($task.priority -eq 'P1' -and $task.status -eq $snapshot.tasks[0].status -and $task.execution -eq $snapshot.tasks[0].execution) 'single update preserves omitted fields'
    [void](Update-SBTrackerTask @argsBase -TaskId T-1 -Execution user_required -DependsOn @('T-2') -Stream urgent -StateReason 'synthetic')
    $task=(Read-SBJson $trackerPath $null).tasks[0]
    Check ($task.dependencies[0].id -eq 'T-2' -and $task.extensions.stream -eq 'urgent' -and $task.execution -eq 'user_required') 'combined metadata update'
    $before=Get-SBFileHash $trackerPath
    Reject {Update-SBTrackerTask @argsBase -TaskId T-2 -DependsOn T-1} 'cyclic dependency rejected'
    Reject {Update-SBTrackerTask @argsBase -TaskId T-1 -DependsOn missing} 'missing dependency rejected'
    Reject {Update-SBTrackerTask @argsBase -TaskId T-1 -DependsOn 'github.com/test/missing#T-2'} 'unmanaged repository dependency rejected'
    Reject {Update-SBTrackerTask -BrainRoot $brain -Identity $identity -WorkingRepository 'github.com/test/foreign' -TaskId T-1 -Priority P0} 'foreign tracker write rejected'
    Check ((Get-SBFileHash $trackerPath) -ceq $before) 'rejected updates preserve tracker bytes'
    $closed=Update-SBTrackerTask @argsBase -TaskId T-2 -Status done
    Check ($closed.ContainsKey('closureAdvice')) 'explicit done produces closure advice'
    $meta=Update-SBTrackerTask @argsBase -TaskId T-2 -Priority P2
    Check (!$meta.ContainsKey('closureAdvice')) 'metadata update on done task does not produce closure advice'
    [void](Update-SBTrackerTask @argsBase -TaskId T-1 -DependsOn ($identity+'#T-2;github.com/test/other#O-1'))
    Check ((Read-SBJson $trackerPath $null).tasks[0].dependencies.Count -eq 2) 'semicolon-separated qualified dependencies preserve managed repository identities'
    $cli=Invoke-EssentialCli @('-UpdateTaskId','T-1','-DependsOn','','-Stream','','-Priority','P2')
    $task=(Read-SBJson $trackerPath $null).tasks[0]
    Check ($cli.code -eq 0 -and !$task.dependencies.Count -and !$task.extensions.ContainsKey('stream') -and $task.priority -eq 'P2') ('CLI clears explicit empty metadata: '+$cli.text)
    $cli=Invoke-EssentialCli @('-UpdateTaskId','T-1')
    Check ($cli.code -ne 0) 'CLI rejects update without fields'
    $cli=Invoke-EssentialCli @('-Tasks')
    Check ($cli.code -eq 0 -and @($cli.text|ConvertFrom-Json).Count -eq 1) 'CLI lists only open local tasks'
}
if('workflows' -in $Groups){
    $startup=Get-SBStartupContext -BrainRoot $brain -Dossier $dossier -CheckoutPath $repo -Budget 20000 -Profile Slim
    Check ($startup.withinBudget -and !$startup.parts.memory.Contains('Historical detail') -and $startup.omittedParts.Count -gt 0) 'Slim omits history without truncating source'
    $before=Get-SBFileHash (Join-Path $dossier 'memory.md')
    $under=Get-SBStartupContext -BrainRoot $brain -Dossier $dossier -CheckoutPath $repo -Budget ([int]$startup.characters-1) -Profile Slim
    Check (!$under.withinBudget -and (Get-SBFileHash (Join-Path $dossier 'memory.md')) -ceq $before) 'over-budget startup reports failure without changing source'
    $candidatePath=Join-Path $brain '.runtime/candidate.json'
    $candidate=@{schemaVersion=1;repository=$identity;sources=@{};summaries=@{};openTaskIds=@((Read-SBJson $trackerPath $null).tasks|Where-Object status -notin @('done','cancelled')|ForEach-Object id);reviewed=$true;reviewNote='synthetic conservation test'}
    foreach($name in @('context.md','memory.md')){$candidate.sources[$name]=Get-SBFileHash (Join-Path $dossier $name);$candidate.summaries[$name]=Read-SBText (Join-Path $dossier $name)}
    Put $candidatePath (ConvertTo-SBJson $candidate)
    $preview=Invoke-SBDossierCompaction -BrainRoot $brain -Dossier $dossier -CandidatePath $candidatePath -BackupRoot $cfg.backupRoot -Budget 16000 -CheckoutPath $repo
    Check (!$preview.applied -and (Get-SBFileHash (Join-Path $dossier 'memory.md')) -ceq $before) 'compaction preview preserves source'
    [void](Invoke-SBDossierCompaction -BrainRoot $brain -Dossier $dossier -CandidatePath $candidatePath -BackupRoot $cfg.backupRoot -Budget 16000 -CheckoutPath $repo -Apply)
    Check ((Get-SBFileHash (Join-Path $dossier ('history/compaction/'+$before.ToLowerInvariant()+'/memory.md'))) -ceq $before) 'compaction preserves byte-exact original'
    Reject {Invoke-SBDossierCompaction -BrainRoot $brain -Dossier $dossier -CandidatePath $candidatePath -BackupRoot $cfg.backupRoot -Budget 16000 -Apply} 'stale compaction candidate rejected'
}
if('pending' -in $Groups){
    Reject {New-SBPendingWrite -BrainRoot $brain -Repository $identity -Operation task.update -Arguments @{TaskId='T-1';DependsOn=@('T-1')} -Config $cfg} 'invalid dependency graph rejected before queuing'
    $target=Join-Path $brain 'untracked.txt';Put $target 'original';$hash=Get-SBFileHash $target
    [void](Write-SBFile $target ([Text.Encoding]::UTF8.GetBytes('updated')) $hash $cfg.backupRoot)
    Check (@(Get-ChildItem $cfg.backupRoot -Filter '*.bin'|Where-Object {(Get-SBFileHash $_.FullName) -ceq $hash}).Count -gt 0) 'write preserves original backup bytes'
    Reject {Write-SBFile $target ([Text.Encoding]::UTF8.GetBytes('lost')) $hash $cfg.backupRoot} 'stale write hash rejected'
    $holder=Enter-SBOperation $cfg -WaitMs 0
    try{
        $first=New-SBPendingWrite -BrainRoot $brain -Repository $identity -Operation task.update -Arguments @{TaskId='T-1';Priority='P0';Stream='queued'} -Config $cfg
        $second=New-SBPendingWrite -BrainRoot $brain -Repository $identity -Operation task.update -Arguments @{TaskId='T-1';Priority='P3'} -Config $cfg
        $deferred=Complete-SBPendingSubmission $first $cfg
        Check (!$deferred.applied -and $deferred.state -eq 'deferred') 'busy writer preserves durable request without applying'
    }finally{Exit-SBOperation $holder}
    $drain=Invoke-SBPendingWrites -BrainRoot $brain -Config $cfg
    $task=(Read-SBJson $trackerPath $null).tasks[0]
    Check ($drain.applied.Count -eq 1 -and $drain.conflicts.Count -eq 1 -and $task.priority -eq 'P0') 'first queued update applies and stale concurrent update conflicts'
    $after=Get-SBFileHash $trackerPath
    [void](Invoke-SBPendingWrites -BrainRoot $brain -Config $cfg)
    Check ((Get-SBFileHash $trackerPath) -ceq $after) 'replay applies no duplicate update'
    $receipt=@(Get-SBPendingWrites $brain|Where-Object id -eq $first.id)[0].receipt
    Check ($receipt.state -eq 'applied' -and $receipt.result.taskId -eq 'T-1') 'receipt identifies atomically applied task'
    $legacy=New-SBPendingWrite -BrainRoot $brain -Repository $identity -Operation task.status -Arguments @{TaskId='T-1';Status='in_progress'} -Config $cfg
    Check ((Complete-SBPendingSubmission $legacy $cfg).applied) 'existing task.status request remains supported'
    [void](Update-SBTrackerTask @argsBase -TaskId T-2 -Status done)
    $metadata=New-SBPendingWrite -BrainRoot $brain -Repository $identity -Operation task.update -Arguments @{TaskId='T-2';Priority='P1'} -Config $cfg
    $response=Complete-SBPendingSubmission $metadata $cfg
    Check ($response.applied -and !$response.ContainsKey('closureAdvice')) 'queued metadata on a done task emits no closure signal'
}
if('audit2' -in $Groups){
    $target=Join-Path $brain 'denied.txt';Put $target 'updated'
    [IO.File]::SetAttributes($target,[IO.FileAttributes]::ReadOnly)
    try{
        $denied=$null;try{Write-SBFile $target ([Text.Encoding]::UTF8.GetBytes('denied')) (Get-SBFileHash $target) $cfg.backupRoot|Out-Null}catch{$denied=$_}
        Check ($denied -and (Test-SBError $denied 'core.write.denied') -and (Read-SBText $target) -ceq 'updated') 'access denied preserves destination and stable error code'
    }finally{[IO.File]::SetAttributes($target,[IO.FileAttributes]::Normal)}
    Reject {Assert-SBCentralDataPath $brain (Join-Path $fixture 'outside')} 'runtime path escape rejected'
    $outside=Join-Path $fixture 'outside';[void][IO.Directory]::CreateDirectory($outside)
    $junction=Join-Path $brain '.runtime/junction'
    New-Item -ItemType Junction -Path $junction -Target $outside|Out-Null
    Reject {Assert-SBCentralDataPath $brain (Join-Path $junction 'payload')} 'junction escape rejected'
    $tx=Join-Path $brain 'transaction.txt';Put $tx 'before'
    $manifest=Invoke-SBParaTransaction @(@{path=$tx;expected=(Get-SBFileHash $tx);bytes=[Text.Encoding]::UTF8.GetBytes('after')}) $cfg.backupRoot $brain
    [void](Restore-SBParaTransaction $manifest $brain $cfg.backupRoot)
    Check ((Read-SBText $tx) -ceq 'before') 'transaction rollback recovers original bytes'
    Put $tx 'changed';Reject {Restore-SBParaTransaction $manifest $brain $cfg.backupRoot} 'rollback refuses changed destination'
    $clean=@(Test-SBPublicationText 'Public synthetic documentation.' 'README.md' 'working')
    $privateText='token=gh'+'p_'+('x'*36)
    $private=@(Test-SBPublicationText $privateText 'README.md' 'working')
    Check (!$clean.Count -and $private.Count -gt 0) 'publication distinguishes public prose and private attribution fixture'
    Put (Join-Path $repo 'README.md') 'Public synthetic documentation.'
    Put (Join-Path $repo 'big.txt') ('safe public text '*100)
    & git -C $repo -c user.name=Fixture -c user.email=fixture@example.invalid add README.md big.txt
    & git -C $repo -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm base
    if($LASTEXITCODE){throw 'Synthetic publication commit failed'}
    $oid=(& git -C $repo hash-object big.txt).Trim()
    foreach($case in @(@($oid,0),@(('0'*40),1))){
        $policy=Join-Path $brain '.runtime/publication/size-policy.json'
        Put $policy (ConvertTo-SBJson @{schemaVersion=1;allowances=@();binaryReviews=@(@{path='big.txt';sha256=('0'*64);gitBlob=$case[0];reviewed=$true;reason='synthetic review'})})
        $pub=Test-SBPublication -BrainRoot $brain -RepositoryPath $repo -PolicyPath $policy -MaxTextBytes 400
        Check (@($pub.incomplete|Where-Object {$_.surface -eq 'history' -and $_.reason -eq 'size-limit'}).Count -eq $case[1]) 'reviewed historical blob is bound to the exact object'
    }
    Put (Join-Path $repo 'README.md') $privateText
    & git -C $repo add README.md
    $pub=Test-SBPublication -BrainRoot $brain -RepositoryPath $repo
    Check (!$pub.ready -and @($pub.findings|Where-Object {$_.rule -eq 'credential' -and $_.surface -eq 'index'}).Count -gt 0 -and !(ConvertTo-SBJson $pub).Contains($privateText)) 'real staged private fixture blocks publication without leaking its value'
}
if('git-environment' -in $Groups){
    $before=@{};foreach($name in @('GIT_CONFIG_COUNT','GIT_CONFIG_GLOBAL','GIT_TEMPLATE_DIR')){$before[$name]=[Environment]::GetEnvironmentVariable($name,'Process')}
    $nested=Enter-SBTestGitEnvironment
    try{Assert-SBTestGitEnvironment;Check $true 'isolated Git environment is effective'}finally{Exit-SBTestGitEnvironment $nested}
    foreach($name in $before.Keys){Check ([Environment]::GetEnvironmentVariable($name,'Process') -ceq $before[$name]) ('Git environment restored: '+$name)}
    $run=New-SBTestRun ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))) 'Only' @{}
    Check ($run.parent -and (Split-Path $run.directory) -eq (Split-Path $env:SECONDBRAIN_TEST_ROOT)) 'nested run is a sibling with parent evidence'
    $run.inputsBefore=Get-SBTestInputSnapshot $run.brainRoot
    Complete-SBTestRun $run $true 1 @() $false
    Check ((Read-SBJson $run.report $null).status -eq 'passed' -and (Test-Path $run.directory)) 'nested report is durable and fixtures retained'
}
'SUCCESS ESSENTIAL: '+$checks+' behavioral checks; retained fixture: '+$fixture
