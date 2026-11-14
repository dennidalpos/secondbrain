#requires -Version 7.5
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Host.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Para.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Tracker.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Knowledge.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Pending.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Mcp.psm1')
. (Join-Path $PSScriptRoot 'test-helpers.ps1')
$checks=0
function Assert-Pending($Value,[string]$Message){if(!$Value){throw ('FAIL PENDING: '+$Message)};$script:checks++;'PASS PENDING: '+$Message}
function Put-Pending([string]$Path,[string]$Text){[IO.Directory]::CreateDirectory((Split-Path $Path))|Out-Null;[IO.File]::WriteAllText($Path,$Text,[Text.UTF8Encoding]::new($false))}
$fixture=Join-Path (Get-SBTestRoot) ('pending-'+[guid]::NewGuid().ToString('N'))
$brain=Join-Path $fixture 'brain'
$dossier=Join-Path $brain '02-areas/products/Pending'
$checkout=Join-Path $fixture 'checkout'
$identity='github.com/test/pending'
$hostId=Get-SBHostId
$runtime=Join-Path $brain ('.runtime/hosts/'+$hostId)
$configPath=Join-Path $runtime 'workstation.json'
$sessions=@();$holder=$null
function Invoke-PendingCli([string]$Script,[string[]]$CliArguments){
    $stderr=Join-Path $fixture ([guid]::NewGuid().ToString('N')+'.stderr')
    $lines=@(& pwsh -NoProfile -File (Join-Path $brain ('scripts/'+$Script)) -ConfigPath $configPath @CliArguments 2> $stderr)
    $code=$LASTEXITCODE
    $text=$lines -join "`n"
    $data=$null;try{$data=$text|ConvertFrom-Json -AsHashtable}catch { Write-Verbose $_.Exception.Message }
    @{code=$code;text=$text;data=$data;stderr=$stderr}
}
try {
    [IO.Directory]::CreateDirectory((Join-Path $brain 'scripts'))|Out-Null
    Get-ChildItem -LiteralPath $PSScriptRoot -File|Copy-Item -Destination (Join-Path $brain 'scripts')
    Put-Pending (Join-Path $brain 'VERSION') (Read-SBText (Join-Path $PSScriptRoot '../VERSION'))
    Put-Pending (Join-Path $brain 'config/shared.json') (ConvertTo-SBJson @{schemaVersion=1;allowedOwners=@('test');excludedDirectories=@('.git')})
    Put-Pending (Join-Path $brain 'config/tracker.schema.json') (Read-SBText (Join-Path $PSScriptRoot '../config/tracker.schema.json'))
    Put-Pending (Join-Path $brain 'direttive/AGENTS.global_ide.md') '# Synthetic directives'
    Put-Pending (Join-Path $brain 'direttive/workstation.template.md') '<!-- secondbrain:tracker-contract:1 -->'
    $approval=@{authorization='isolated pending fixture';files=@{}}
    foreach($file in @('AGENTS.global_ide.md','workstation.template.md')){$approval.files['direttive/'+$file]=Get-SBFileHash (Join-Path $brain ('direttive/'+$file))}
    Put-Pending (Join-Path $brain 'direttive/approved.json') (ConvertTo-SBJson $approval)
    Put-Pending (Join-Path $dossier 'para.json') (ConvertTo-SBJson @{schemaVersion=1;id='pending-area';kind='area';title='Pending';status='active'})
    Put-Pending (Join-Path $dossier 'repository.json') (ConvertTo-SBJson @{schemaVersion=1;identity=$identity;tracker=@{location='dossier';path='tracker.json';schemaVersion=1}})
    Put-Pending (Join-Path $dossier 'context.md') "# Context`n"
    Put-Pending (Join-Path $dossier 'brief.md') '# Synthetic pending fixture'
    Put-Pending (Join-Path $dossier 'memory.md') "# Memory`n"
    Put-Pending (Join-Path $dossier 'history/seed/report.md') 'Synthetic provenance'
    $tasks=@()
    foreach($number in @(1,2)){
        $task=New-SBTrackerTask @{id=('T-'+$number);title=('Task '+$number);status='todo'} $identity 'fixture' 'history/seed/report.md' (Get-SBTextHash 'Synthetic provenance') 'fixture'
        $task.seq=$number;$task.title='#'+$number.ToString('000')+' — Task '+$number
        $tasks+=,$task
    }
    $trackerPath=Join-Path $dossier 'tracker.json'
    Put-Pending $trackerPath (ConvertTo-SBJson @{schemaVersion=1;repository=$identity;updatedAt=[DateTimeOffset]::UtcNow.ToString('o');tasks=$tasks;history=@();extensions=@{lastSeq=2}})
    [IO.Directory]::CreateDirectory($checkout)|Out-Null
    & git -c core.longpaths=true -C $checkout init -q
    & git -c core.longpaths=true -C $checkout remote add origin 'https://github.com/test/pending.git'
    if($LASTEXITCODE){throw 'fixture git'}
    $cfg=@{schemaVersion=1;mode='portable';brainRoot=$brain;workstationId=$hostId;runtimeRoot=$runtime;backupRoot=(Join-Path $runtime 'backups');repositoryRoot=$brain;coordinationRoot=(Join-Path $brain '.runtime/access');bindings=@(@{identity=$identity;path=$checkout;remoteIdentity=$identity});ides=@();sessionTimeoutMinutes=30;lockWaitMs=60000;configPath=$configPath}
    Put-Pending $configPath (ConvertTo-SBJson $cfg)

    $holder=Enter-SBOperation $cfg -WaitMs 0
    $guard=Get-SBWriteGuard
    $watch=[Diagnostics.Stopwatch]::StartNew()
    $diagnostics=@{}
    $first=New-SBPendingWrite -BrainRoot $brain -Repository $identity -Operation task.status -Arguments @{TaskId='T-1';Status='in_progress'} -Config $cfg -Diagnostics $diagnostics
    $prepareSeconds=$watch.Elapsed.TotalSeconds
    $lockWatch=[Diagnostics.Stopwatch]::StartNew()
    $deferred=Complete-SBPendingSubmission $first $cfg -Diagnostics $diagnostics
    $lockWatch.Stop()
    $watch.Stop()
    Assert-Pending (!$deferred.applied -and $deferred.state -eq 'deferred' -and $lockWatch.Elapsed.TotalSeconds -lt ($cfg.lockWaitMs/1000)) ('busy writer returns before the configured lock timeout; prepare='+[math]::Round($prepareSeconds,3)+' s; attempt='+[math]::Round($lockWatch.Elapsed.TotalSeconds,3)+' s; '+$deferred.state)
    Assert-Pending ($diagnostics.prepareMs -ge 0 -and $diagnostics.writeFlushMs -ge 0 -and $diagnostics.readbackMs -ge 0 -and $diagnostics.scanMs -ge 0 -and $diagnostics.lockAttemptMs -ge 0 -and $diagnostics.responseMs -ge $diagnostics.scanMs -and $diagnostics.lockAttempts -eq 1 -and $diagnostics.queueDepth -eq 1) 'optional diagnostics separate preparation, durable I/O, scan and non-blocking lock attempt'
    Assert-Pending (!$first.request.ContainsKey('diagnostics') -and !$deferred.ContainsKey('diagnostics')) 'diagnostics do not alter durable request or ordinary response schemas'
    Assert-Pending ((Get-SBWriteGuard) -eq $guard) 'failed nested acquisition preserves the outer write guard'
    Assert-Pending ((Read-SBJson $trackerPath $null).tasks[0].status -eq 'todo') 'deferred is not reported as applied'
    foreach($client in @('agent-a','agent-b')){
        $session=Invoke-PendingCli 'access.ps1' @('-Start','-Mode','Write','-Client',$client,'-WaitSeconds','0')
        Assert-Pending ($session.code -eq 0 -and !$session.data.exclusive) ('ordinary write session does not reserve the writer: '+$client)
        $sessions+=$session.data.sessionId
    }
    $ownId=[guid]::NewGuid().ToString('N')
    $own=Invoke-PendingCli 'access.ps1' @('-Start','-Mode','Write','-Client','own-id','-WaitSeconds','0','-SessionId',$ownId)
    Assert-Pending ($own.code -eq 0 -and $own.data.sessionId -eq $ownId) '-Start honours a caller-supplied SessionId'
    $sessions+=$ownId
    $dup=Invoke-PendingCli 'access.ps1' @('-Start','-Mode','Write','-Client','own-id','-WaitSeconds','0','-SessionId',$ownId)
    Assert-Pending ($dup.code -ne 0) '-Start refuses a SessionId already in use'
    $content=Join-Path $fixture 'append.txt';Put-Pending $content "Pending report`n"
    $queuedCli=Invoke-PendingCli 'knowledge.ps1' @('-CheckoutPath',$checkout,'-AppendFile','history/session/report.md','-ContentPath',$content,'-SessionId',$sessions[0])
    Assert-Pending ($queuedCli.code -eq 5 -and $queuedCli.data.state -eq 'deferred') 'CLI queues a dossier report while another writer is active and exits 5 (not applied)'
    Exit-SBOperation $holder;$holder=$null

    $init='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26"}}'
    $mcpStderr=Join-Path $fixture 'mcp.stderr'
    $wire=$init|& pwsh -NoProfile -File (Join-Path $brain 'scripts/mcp-server.ps1') -BrainRoot $brain -ConfigPath $configPath 2> $mcpStderr
    Assert-Pending ($LASTEXITCODE -eq 0 -and ($wire|ConvertFrom-Json).result.protocolVersion -eq '2025-03-26') 'MCP starts with the read-only contract and clean stdio'
    Assert-Pending ((Read-SBJson $trackerPath $null).tasks[0].status -eq 'todo' -and !(Test-Path -LiteralPath (Join-Path $dossier 'history/session/report.md')) -and (Get-SBPendingWrites $brain|Where-Object id -eq $first.id).state -eq 'deferred') '#474: MCP startup leaves a terminated producer requests deferred'
    foreach($readArgs in @(@('-Startup'),@('-Tasks'),@('-Search','Task'),@('-Task','T-1'),@('-PendingWrites'))){
        $readOnlyRun=Invoke-PendingCli 'knowledge.ps1' (@('-CheckoutPath',$checkout)+$readArgs)
        Assert-Pending ($readOnlyRun.code -eq 0 -and (Read-SBJson $trackerPath $null).tasks[0].status -eq 'todo' -and (Get-SBPendingWrites $brain|Where-Object id -eq $first.id).state -eq 'deferred') ('#474: knowledge '+($readArgs -join ' ')+' never integrates pending writes')
    }
    $explicitFlush=Invoke-PendingCli 'knowledge.ps1' @('-CheckoutPath',$checkout,'-FlushPending')
    Assert-Pending ($explicitFlush.code -eq 0 -and (Read-SBJson $trackerPath $null).tasks[0].status -eq 'in_progress' -and (Read-SBText (Join-Path $dossier 'history/session/report.md')) -eq "Pending report`n") '#474: explicit -FlushPending integrates the requests of the own dossier'
    $firstReceipt=(Get-SBPendingWrites $brain|Where-Object id -eq $first.id).receipt
    Assert-Pending ($firstReceipt.repository -eq $identity -and $firstReceipt.appliedBy.workstationId -eq $hostId) 'receipts identify the repository and importing workstation without ambiguous task IDs'
    Assert-Pending ((Read-SBText (Join-Path $dossier 'history/index.md')).Contains('session/')) 'report integration regenerates the history index in the same journal'
    $reportHash=Get-SBFileHash (Join-Path $dossier 'history/session/report.md')
    $again=Invoke-SBPendingWrites -BrainRoot $brain -Config $cfg
    Assert-Pending (!$again.applied.Count -and (Get-SBFileHash (Join-Path $dossier 'history/session/report.md')) -eq $reportHash -and (Test-Path -LiteralPath $first.path)) 'receipts prevent duplicate application and original requests are retained'

    # #593: a #seq TaskId is stored as the task ID in the request, so the deferred write names the same task; an unknown number is refused.
    $bySeq=New-SBPendingWrite -BrainRoot $brain -Repository $identity -Operation task.update -Arguments @{TaskId='#002';Priority='P3'} -Config $cfg
    $bySeqRequest=Read-SBJson $bySeq.path $null
    $bySeqResult=Complete-SBPendingSubmission $bySeq $cfg
    Assert-Pending ($bySeqRequest.arguments.TaskId -ceq 'T-2' -and $bySeqResult.applied -and @((Read-SBJson $trackerPath $null).tasks|Where-Object id -eq 'T-2')[0].priority -ceq 'P3') '#593: task.update with #seq is submitted by ID and applied'
    $seqRefused=$null
    try{[void](New-SBPendingWrite -BrainRoot $brain -Repository $identity -Operation task.update -Arguments @{TaskId='#99';Priority='P3'} -Config $cfg)}catch{$seqRefused=$_}
    Assert-Pending ((Test-SBError $seqRefused 'tracker.task.notfound') -and [string]$seqRefused -match 'task ID') '#593: unknown #seq is refused at submission naming the ID form'

    # #595: a batch of task updates in one process, one writer lock and one transaction, each with its task hash, receipt and executor.
    $batchFile=Join-Path $fixture 'batch.json'
    $queueBefore=@(Get-SBPendingWrites $brain).Count
    Put-Pending $batchFile (ConvertTo-Json -Depth 6 -InputObject @(@{taskId='T-1';status='in_progress';stateReason='batch reason'},@{taskId='#002';priority='P2';stream='batch-stream';evidence=@('history/seed/report.md|passed')}))
    $batchOk=Invoke-PendingCli 'knowledge.ps1' @('-CheckoutPath',$checkout,'-UpdateTasksFile',$batchFile)
    $afterBatch=Read-SBJson $trackerPath $null
    $batchT1=@($afterBatch.tasks|Where-Object id -eq 'T-1')[0];$batchT2=@($afterBatch.tasks|Where-Object id -eq 'T-2')[0]
    Assert-Pending ($batchOk.code -eq 0 -and $batchOk.data.applied -and $batchOk.data.count -eq 2 -and $batchT1.extensions.stateReason -ceq 'batch reason' -and $batchT2.priority -ceq 'P2' -and $batchT2.extensions.stream -ceq 'batch-stream' -and @($batchT2.evidence|Where-Object outcome -eq 'passed').Count -eq 1) '#595: one -UpdateTasksFile call applies every update of the batch'
    $batchEntries=@(Get-SBPendingWrites $brain|Where-Object {$_.id -in @($batchOk.data.items|ForEach-Object requestId)})
    $batchRequests=@($batchEntries|ForEach-Object {Read-SBJson $_.path $null})
    Assert-Pending ($batchEntries.Count -eq 2 -and !@($batchEntries|Where-Object state -ne 'applied').Count -and !@($batchEntries|Where-Object {$_.receipt.batch.size -ne 2}).Count -and @($batchEntries|ForEach-Object {$_.receipt.observedAt}|Select-Object -Unique).Count -eq 1 -and @(Get-SBPendingWrites $brain).Count -eq $queueBefore+2) '#595: each update keeps its own request and applied receipt, written in the same transaction'
    Assert-Pending (!@($batchRequests|Where-Object {$_.expected.taskHash -notmatch '^[A-Fa-f0-9]{64}$' -or !$_.arguments.Executor}).Count -and @($batchRequests|Where-Object {$_.arguments.TaskId -ceq 'T-2'}).Count -eq 1 -and $batchOk.data.items[1].taskId -ceq 'T-2') '#595: each request keeps its task hash and executor; #seq is stored as the task ID'
    $again2=Invoke-SBPendingWrites -BrainRoot $brain -Config $cfg -Repository $identity
    Assert-Pending (!@($again2.applied|Where-Object {$_.id -in @($batchOk.data.items|ForEach-Object requestId)}).Count -and (Get-SBFileHash $trackerPath) -eq $batchOk.data.trackerHash) '#595: a later drain never applies batch requests a second time'
    $bytesBefore=Get-SBFileHash $trackerPath;$queueBefore=@(Get-SBPendingWrites $brain).Count
    foreach($case in @(
        @{name='an invalid value';items=@(@{taskId='T-1';priority='P1'},@{taskId='T-2';priority='P9'});needle='Update 2 (T-2)'},
        @{name='an unknown field';items=@(@{taskId='T-1';priority='P1'},@{taskId='T-2';colour='red'});needle='Update 2 (T-2)'},
        @{name='a duplicate task';items=@(@{taskId='T-1';priority='P1'},@{taskId='#001';priority='P3'});needle='Update 2 (T-1)'},
        @{name='an unknown task';items=@(@{taskId='T-404';priority='P1'});needle='Update 1 (T-404)'})){
        Put-Pending $batchFile (ConvertTo-Json -Depth 6 -InputObject @($case.items))
        $refused=Invoke-PendingCli 'knowledge.ps1' @('-CheckoutPath',$checkout,'-UpdateTasksFile',$batchFile,'-Language','en')
        $stderrText=Read-SBText $refused.stderr
        Assert-Pending ($refused.code -eq 2 -and (Get-SBFileHash $trackerPath) -eq $bytesBefore -and @(Get-SBPendingWrites $brain).Count -eq $queueBefore -and $stderrText.Contains($case.needle)) ('#595: '+$case.name+' leaves tracker bytes and queue unchanged and names the item'+$(if($refused.code -ne 2 -or !$stderrText.Contains($case.needle)){' [code '+$refused.code+': '+$stderrText+$refused.text+']'}))
    }
    $preparedBatch=New-SBPendingTaskBatch -BrainRoot $brain -Repository $identity -Items @(@{TaskId='T-1';Priority='P1'},@{TaskId='T-2';Priority='P4'}) -Config $cfg
    [void](Update-SBTrackerTask -BrainRoot $brain -Identity $identity -WorkingRepository $identity -TaskId T-2 -Stream 'concurrent' -BackupRoot $cfg.backupRoot)
    $conflictBytes=Get-SBFileHash $trackerPath;$queueBefore=@(Get-SBPendingWrites $brain).Count
    $batchConflict=$null
    try{[void](Invoke-SBPendingTaskBatch -BrainRoot $brain -Repository $identity -Prepared $preparedBatch -Config $cfg)}catch{$batchConflict=$_}
    Assert-Pending ((Test-SBError $batchConflict 'tracker.batch.item') -and [string]$batchConflict -match '2 \(T-2\)' -and (Get-SBFileHash $trackerPath) -eq $conflictBytes -and @(Get-SBPendingWrites $brain).Count -eq $queueBefore -and @((Read-SBJson $trackerPath $null).tasks|Where-Object id -eq 'T-1')[0].priority -cne 'P1') '#595: a task changed after preparation is a conflict naming the item; nothing of the batch is written'
    $holderBatch=Enter-SBOperation $cfg -WaitMs 0
    try{
        $busy=$null
        try{[void](Invoke-SBPendingTaskBatch -BrainRoot $brain -Repository $identity -Items @(@{TaskId='T-1';Priority='P1'}) -Config $cfg -WaitMs 0)}catch{$busy=$_}
        Assert-Pending ((Test-SBBusyError $busy) -and (Get-SBFileHash $trackerPath) -eq $conflictBytes -and @(Get-SBPendingWrites $brain).Count -eq $queueBefore) '#595: a busy writer refuses the batch without queuing part of it'
    }finally{Exit-SBOperation $holderBatch}
    $independent=New-SBPendingWrite -BrainRoot $brain -Repository $identity -Operation task.status -Arguments @{TaskId='T-1';Status='done'} -Config $cfg
    [void](Set-SBTrackerTaskStatus -BrainRoot $brain -Identity $identity -WorkingRepository $identity -TaskId T-2 -Status in_progress -BackupRoot $cfg.backupRoot)
    $done=Complete-SBPendingSubmission $independent $cfg
    $archived=Read-SBJson (Join-Path $dossier 'history/tracker-archive.json') $null
    Assert-Pending ($done.applied -and $done.closureAdvice.code -eq 'tracker.closure.advice' -and $archived.tasks[0].id -eq 'T-1' -and (Read-SBJson $trackerPath $null).tasks[0].status -eq 'in_progress') 'closure archives the task without replacing another task changes'
    $taskReceipt=(Get-SBPendingWrites $brain|Where-Object id -eq $independent.id).receipt
    Assert-Pending ($taskReceipt.schemaVersion -eq 1 -and $taskReceipt.state -eq 'applied' -and !$taskReceipt.error -and $taskReceipt.result.taskId -eq 'T-1' -and $taskReceipt.result.status -eq 'done' -and $taskReceipt.result.ContainsKey('closureAdvice') -and $taskReceipt.requestHash -and $taskReceipt.sourceHash -and $taskReceipt.observedAt) '#466: applied task receipt keeps schema, result keys, hashes and timestamp'
    $validTracker=Read-SBText $trackerPath
    $invalidTracker=Read-SBJson $trackerPath $null;$invalidTracker.tasks[0].unexpectedField='invalid central schema'
    Put-Pending $trackerPath (ConvertTo-SBJson $invalidTracker)
    $duringInvalid=New-SBPendingWrite -BrainRoot $brain -Repository $identity -Operation task.status -Arguments @{TaskId='T-1';Status='in_progress'} -Config $cfg
    $invalidCentral=Complete-SBPendingSubmission $duringInvalid $cfg
    Assert-Pending (!$invalidCentral.applied -and $invalidCentral.state -eq 'deferred' -and $invalidCentral.pendingWrites.errors.Count -gt 0) 'an unrelated central validation error preserves the intent without applying invalid data'
    Put-Pending $trackerPath $validTracker
    Assert-Pending ((Complete-SBPendingSubmission $duringInvalid $cfg).applied) 'full graph validation is retried after central data is repaired'
    $conflict=New-SBPendingWrite -BrainRoot $brain -Repository $identity -Operation task.status -Arguments @{TaskId='T-2';Status='done'} -Config $cfg
    [void](Set-SBTrackerTaskStatus -BrainRoot $brain -Identity $identity -WorkingRepository $identity -TaskId T-2 -Status blocked -BackupRoot $cfg.backupRoot)
    $conflicted=Complete-SBPendingSubmission $conflict $cfg
    Assert-Pending ($conflicted.state -eq 'conflict' -and !$conflicted.applied -and (Read-SBJson $trackerPath $null).tasks[0].status -eq 'blocked' -and (Test-Path -LiteralPath $conflict.path)) 'same-task conflict preserves the central value and request'
    $conflictReceipt=(Get-SBPendingWrites $brain|Where-Object id -eq $conflict.id).receipt
    Assert-Pending ($conflictReceipt.state -eq 'conflict' -and $conflictReceipt.error -eq 'pending.conflict' -and $conflictReceipt.result.Count -eq 0 -and $conflictReceipt.repository -eq $identity) '#466: conflict receipt carries pending.conflict and an empty result'
    # #563: a task.new whose dependency can never resolve is terminal (invalid), not retried forever, and -DiscardPending retires it.
    $orphanNew=New-SBPendingWrite -BrainRoot $brain -Repository $identity -Operation task.new -Arguments @{Title='Orphan dependency';Id='';Description='';Priority='P3';Execution='autonomous';DependsOn=@('#9999');Acceptance=@('never applied');ProvenanceReference='context.md';ProvenancePointer='test'} -Config $cfg
    $trackerBeforeOrphan=Get-SBFileHash $trackerPath
    $orphanResult=Complete-SBPendingSubmission $orphanNew $cfg
    $orphanEntry=@(Get-SBPendingWrites $brain|Where-Object id -eq $orphanNew.id)
    Assert-Pending (!$orphanResult.applied -and $orphanResult.state -eq 'invalid' -and !@($orphanResult.pendingWrites.errors|Where-Object id -eq $orphanNew.id).Count -and (Get-SBFileHash $trackerPath) -eq $trackerBeforeOrphan) '#563: task.new with a missing dependency gets an invalid receipt without touching the tracker'
    Assert-Pending ($orphanEntry.Count -eq 1 -and $orphanEntry[0].state -eq 'invalid' -and [string]$orphanEntry[0].receipt.error -and $orphanEntry[0].receipt.error -ne 'pending.conflict') '#563: the invalid receipt keeps the validation error'
    $orphanBytes=Get-SBFileHash $orphanNew.path
    $orphanDiscard=Invoke-PendingCli 'knowledge.ps1' @('-DiscardPending',$orphanNew.id)
    Assert-Pending ($orphanDiscard.code -eq 0 -and $orphanDiscard.data.previousState -eq 'invalid' -and (Get-SBFileHash (Join-Path $orphanDiscard.data.archive ($orphanNew.id+'.json'))) -eq $orphanBytes -and !@(Get-SBPendingWrites $brain|Where-Object id -eq $orphanNew.id).Count -and (Test-Path -LiteralPath $conflict.path)) '#563: -DiscardPending retires the invalid task.new with its original bytes and leaves other entries in the queue'

    # #588: user decision records (decisions.json) through decisions.ps1, the queue, the tracker link and MCP get_decisions.
    Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Decisions.psm1')
    $decisionsPath=Join-Path $dossier 'decisions.json'
    $decisionSchema=Read-SBText (Join-Path $PSScriptRoot '../config/decision.schema.json')
    $emptyList=Invoke-PendingCli 'decisions.ps1' @('-CheckoutPath',$checkout)
    Assert-Pending ($emptyList.code -eq 0 -and $emptyList.data.hash -eq 'absent' -and @($emptyList.data.decisions).Count -eq 0 -and !(Test-Path -LiteralPath $decisionsPath)) '#588: listing without decisions.json is an empty read'
    $optionsJson=ConvertTo-Json -Compress -Depth 4 -InputObject @(@{id='per-dossier';label='Per dossier';description='One lock per dossier';recommended=$true},@{id='global';label='Global';description='Keep the global lock'})
    $openArgs=@('-CheckoutPath',$checkout,'-Open','-Kind','choice','-Question','Which lock key should the access layer use?','-OptionsJson',$optionsJson,'-Scope','task','-TaskId','T-2','-Through','structured-tool')
    $preview=Invoke-PendingCli 'decisions.ps1' ($openArgs+@('-WhatIf'))
    Assert-Pending ($preview.code -eq 0 -and $preview.data.preview -and $preview.data.expectedHash -eq 'absent' -and $preview.data.record.status -eq 'open' -and !(Test-Path -LiteralPath $decisionsPath)) '#588: -WhatIf shows the plan and its hashes without writing'
    $opened=Invoke-PendingCli 'decisions.ps1' $openArgs
    $decisionId=[string]$opened.data.decision.id
    $stored=Read-SBJson $decisionsPath $null
    $storedRecord=@($stored.decisions)[0]
    Assert-Pending ($opened.code -eq 0 -and $opened.data.applied -and $decisionId -cmatch '^dec-[0-9a-f]{8}$' -and $storedRecord.status -eq 'open' -and !$storedRecord.Contains('answer') -and $storedRecord.options[0].recommended -and $storedRecord.asked.through -eq 'structured-tool') '#588: an opened decision is stored open; its recommended option is not an answer'
    Assert-Pending ((Read-SBText $decisionsPath)|Test-Json -Schema $decisionSchema) '#588: decisions.json validates against config/decision.schema.json'
    $badOrder=ConvertTo-Json -Compress -Depth 4 -InputObject @(@{id='a';label='A';description='first'},@{id='b';label='B';description='second';recommended=$true})
    $refusedOrder=Invoke-PendingCli 'decisions.ps1' @('-CheckoutPath',$checkout,'-Open','-Kind','choice','-Question','Order?','-OptionsJson',$badOrder,'-Scope','task','-Through','text-fallback')
    Assert-Pending ($refusedOrder.code -eq 2 -and @((Read-SBJson $decisionsPath $null).decisions).Count -eq 1) '#588: a recommended option that is not listed first is refused'
    $hashOpen=Get-SBFileHash $decisionsPath
    $noChoice=Invoke-PendingCli 'decisions.ps1' @('-CheckoutPath',$checkout,'-Answer',$decisionId)
    Assert-Pending ($noChoice.code -eq 2 -and (Get-SBFileHash $decisionsPath) -eq $hashOpen) '#588: an answer without an explicit option or text is refused (no default, no recommendation taken)'
    $aged=Read-SBJson $decisionsPath $null;@($aged.decisions)[0].asked.at=[DateTimeOffset]::UtcNow.AddYears(-2).ToString('o')
    Put-Pending $decisionsPath (ConvertTo-SBJson $aged)
    $agedList=Invoke-PendingCli 'decisions.ps1' @('-CheckoutPath',$checkout,'-Status','open')
    Assert-Pending ($agedList.code -eq 0 -and @($agedList.data.decisions).Count -eq 1 -and @($agedList.data.decisions)[0].status -eq 'open') '#588: a decision asked two years ago is still open (no expiry counts as an answer)'
    foreach($fake in @('timeout','recommendation','agent')){
        $forged=Read-SBJson $decisionsPath $null;$r=@($forged.decisions)[0];$r.status='answered';$r.answer=@{optionId='per-dossier';by=$fake;at=[DateTimeOffset]::UtcNow.ToString('o')}
        $rejected=$false;try{Assert-SBDecisionData $forged $identity}catch{$rejected=(Test-SBError $_ 'decision.invalid')}
        Assert-Pending $rejected ('#588: an answer by "'+$fake+'" is refused by the contract')
    }
    $forged=Read-SBJson $decisionsPath $null;$r=@($forged.decisions)[0];$r.status='answered';$r.answer=@{optionId='per-dossier';by='timeout';at=[DateTimeOffset]::UtcNow.ToString('o')}
    $forgedWrite=New-SBPendingWrite -BrainRoot $brain -Repository $identity -Operation file.save -Arguments @{relativePath='decisions.json';content=(ConvertTo-SBJson $forged)} -Expected @{hash=(Get-SBFileHash $decisionsPath)} -Config $cfg
    $forgedResult=Complete-SBPendingSubmission $forgedWrite $cfg
    Assert-Pending ($forgedResult.state -eq 'invalid' -and !$forgedResult.applied -and @((Read-SBJson $decisionsPath $null).decisions)[0].status -eq 'open') '#588: a queued decisions.json with a non-user answer gets an invalid receipt and is never applied'
    [void](Move-SBPendingConflict $brain $forgedWrite.id)
    $appendRefused=$false;try{[void](New-SBPendingWrite -BrainRoot $brain -Repository $identity -Operation file.append -Arguments @{relativePath='decisions.json';content='x'} -Config $cfg)}catch{$appendRefused=$true}
    Assert-Pending $appendRefused '#588: decisions.json accepts only a whole file.save'
    # Tracker link: awaiting=owner-consent plus extensions.decision, checked against decisions.json.
    $linkNoAwait=Invoke-PendingCli 'knowledge.ps1' @('-CheckoutPath',$checkout,'-UpdateTaskId','T-2','-Decision',$decisionId)
    $unlinked=@((Read-SBJson $trackerPath $null).tasks|Where-Object id -eq 'T-2')[0]
    Assert-Pending ($linkNoAwait.code -ne 0 -and !($unlinked.Contains('extensions') -and $unlinked.extensions -and $unlinked.extensions.Contains('decision'))) '#588: a decision link without awaiting=owner-consent is refused'
    $linkMissing=Invoke-PendingCli 'knowledge.ps1' @('-CheckoutPath',$checkout,'-UpdateTaskId','T-2','-Awaiting','owner-consent','-Decision','dec-00000000')
    Assert-Pending ($linkMissing.code -ne 0) '#588: a link to a decision that does not exist is refused'
    $linked=Invoke-PendingCli 'knowledge.ps1' @('-CheckoutPath',$checkout,'-UpdateTaskId','T-2','-Awaiting','owner-consent','-Decision',$decisionId)
    $linkedTask=@((Read-SBJson $trackerPath $null).tasks|Where-Object id -eq 'T-2')[0]
    Assert-Pending ($linked.code -eq 0 -and $linkedTask.extensions.decision -ceq $decisionId -and $linkedTask.extensions.awaiting -eq 'owner-consent') '#588: a waiting task links its open decision'
    $wrongTask=Invoke-PendingCli 'knowledge.ps1' @('-CheckoutPath',$checkout,'-UpdateTaskId','T-1','-Awaiting','owner-consent','-Decision',$decisionId)
    Assert-Pending ($wrongTask.code -ne 0) '#588: a decision tied to T-2 cannot be linked from another task'
    $mcpOpen=(Invoke-SBMcpToolCall $brain 'get_decisions' @{repository=$identity;status='open'})|ConvertFrom-Json -AsHashtable
    Assert-Pending (@($mcpOpen.decisions).Count -eq 1 -and @($mcpOpen.decisions)[0].id -ceq $decisionId -and $mcpOpen.hash -eq (Get-SBFileHash $decisionsPath)) '#588: MCP get_decisions reads the open decisions'
    $answered=Invoke-PendingCli 'decisions.ps1' @('-CheckoutPath',$checkout,'-Answer',$decisionId,'-Option','per-dossier')
    $answeredRecord=@((Read-SBJson $decisionsPath $null).decisions)[0]
    Assert-Pending ($answered.code -eq 0 -and $answeredRecord.status -eq 'answered' -and $answeredRecord.answer.optionId -eq 'per-dossier' -and $answeredRecord.answer.by -eq 'user') '#588: the user answer records the option and by=user'
    $again=Invoke-PendingCli 'decisions.ps1' @('-CheckoutPath',$checkout,'-Answer',$decisionId,'-Text','changed my mind')
    Assert-Pending ($again.code -eq 2) '#588: an answered decision cannot be answered again'
    $relink=Invoke-PendingCli 'knowledge.ps1' @('-CheckoutPath',$checkout,'-UpdateTaskId','T-2','-Decision',$decisionId)
    Assert-Pending ($relink.code -ne 0) '#588: linking an answered decision is refused'
    $mcpAnswered=(Invoke-SBMcpToolCall $brain 'get_decisions' @{repository=$identity;status='open'})|ConvertFrom-Json -AsHashtable
    Assert-Pending (@($mcpAnswered.decisions).Count -eq 0) '#588: MCP status filter leaves out answered decisions'
    # Durable decision: the answer needs a lesson, appended to memory.md with the ID.
    $durable=Invoke-PendingCli 'decisions.ps1' @('-CheckoutPath',$checkout,'-Open','-Kind','approval','-Question','Approve the shared lock policy?','-OptionsJson',(ConvertTo-Json -Compress -InputObject @(@{id='yes';label='Approve';description='Adopt it'},@{id='no';label='Reject';description='Keep the current one'})),'-Scope','durable','-Through','text-fallback')
    $durableId=[string]$durable.data.decision.id
    $noLesson=Invoke-PendingCli 'decisions.ps1' @('-CheckoutPath',$checkout,'-Answer',$durableId,'-Option','yes')
    Assert-Pending ($durable.code -eq 0 -and $noLesson.code -eq 2) '#588: a durable answer without a lesson is refused'
    $lesson=Invoke-PendingCli 'decisions.ps1' @('-CheckoutPath',$checkout,'-Answer',$durableId,'-Option','yes','-Lesson','Decision: one lock per dossier — Reason: dossiers do not share state')
    Assert-Pending ($lesson.code -eq 0 -and $lesson.data.memory.applied -and (Read-SBText (Join-Path $dossier 'memory.md')).Contains('- Decision: one lock per dossier — Reason: dossiers do not share state ('+$durableId+')')) '#588: a durable answer appends one memory line citing the ID'
    $withdrawable=Invoke-PendingCli 'decisions.ps1' @('-CheckoutPath',$checkout,'-Open','-Kind','confirm','-Question','Run the migration now?','-OptionsJson',(ConvertTo-Json -Compress -InputObject @(@{id='go';label='Run';description='Run it'},@{id='wait';label='Wait';description='Later'})),'-Scope','task','-Through','structured-tool')
    $withdrawId=[string]$withdrawable.data.decision.id
    $withdrawn=Invoke-PendingCli 'decisions.ps1' @('-CheckoutPath',$checkout,'-Withdraw',$withdrawId,'-Reason','migration no longer needed')
    $lateAnswer=Invoke-PendingCli 'decisions.ps1' @('-CheckoutPath',$checkout,'-Answer',$withdrawId,'-Option','go')
    Assert-Pending ($withdrawn.code -eq 0 -and @((Read-SBJson $decisionsPath $null).decisions|Where-Object id -eq $withdrawId)[0].status -eq 'withdrawn' -and $lateAnswer.code -eq 2) '#588: a withdrawn decision stays withdrawn and cannot be answered'
    Assert-Pending ((Read-SBText $decisionsPath)|Test-Json -Schema $decisionSchema) '#588: the final decisions.json still validates against the schema'

    $saved=New-SBPendingWrite -BrainRoot $brain -Repository $identity -Operation file.save -Arguments @{relativePath='context.md';content='Queued replacement'} -Expected @{hash=(Get-SBFileHash (Join-Path $dossier 'context.md'))} -Config $cfg
    Put-Pending (Join-Path $dossier 'context.md') 'Other agent context'
    $fileConflict=Complete-SBPendingSubmission $saved $cfg
    Assert-Pending ($fileConflict.state -eq 'conflict' -and (Read-SBText (Join-Path $dossier 'context.md')) -eq 'Other agent context') 'file replacement requires the original hash'
    $append=New-SBPendingWrite -BrainRoot $brain -Repository $identity -Operation file.append -Arguments @{relativePath='memory.md';content="Verified note`n"} -Config $cfg
    Put-Pending (Join-Path $dossier 'memory.md') "Other agent note`n"
    Assert-Pending ((Complete-SBPendingSubmission $append $cfg).applied -and (Read-SBText (Join-Path $dossier 'memory.md')) -eq "Other agent note`nVerified note`n") 'explicit append preserves intervening text'
    $appendReceipt=(Get-SBPendingWrites $brain|Where-Object id -eq $append.id).receipt
    Assert-Pending ($appendReceipt.state -eq 'applied' -and $appendReceipt.result.relativePath -eq 'memory.md') '#466: applied file receipt reports the relative path'
    Assert-Pending ((Read-SBText (Join-Path $dossier 'memory.agent.md')) -eq (ConvertTo-SBAgentMemoryView (Read-SBText (Join-Path $dossier 'memory.md')))) 'memory integration regenerates its agent view atomically'
    $null = New-SBPendingWrite -BrainRoot $brain -Repository $identity -Operation file.append -Arguments @{relativePath='memory.md';content="Root override recovery`n"} -Config $cfg
    $rootInit=Invoke-SBMcpMessage $brain @{jsonrpc='2.0';id=100;method='initialize';params=@{}}|ConvertFrom-Json
    Assert-Pending (!$rootInit.error -and !(Read-SBText (Join-Path $dossier 'memory.md')).Contains('Root override recovery')) '#474: MCP initialize does not integrate queued writes'
    [void](Invoke-SBPendingWrites -BrainRoot $brain -Config $cfg -Repository $identity)

    $serverStart=[Diagnostics.ProcessStartInfo]::new((Get-Command pwsh).Source)
    $serverStart.UseShellExecute=$false;$serverStart.CreateNoWindow=$true;$serverStart.RedirectStandardInput=$true;$serverStart.RedirectStandardOutput=$true
    foreach($arg in @('-NoProfile','-File',(Join-Path $brain 'scripts/mcp-server.ps1'),'-BrainRoot',$brain,'-ConfigPath',$configPath)){$serverStart.ArgumentList.Add($arg)}
    $server=[Diagnostics.Process]::Start($serverStart)
    try{
        $server.StandardInput.WriteLine($init);$server.StandardInput.Flush()
        $read=$server.StandardOutput.ReadLineAsync();if(!$read.Wait(60000)){throw 'MCP fixture initialization timeout'}
        $null = New-SBPendingWrite -BrainRoot $brain -Repository $identity -Operation file.append -Arguments @{relativePath='memory.md';content="MCP read recovery`n"} -Config $cfg
        $server.StandardInput.WriteLine('{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"get_task","arguments":{"task":"T-1","repository":"github.com/test/pending"}}}')
        $server.StandardInput.Flush()
        $read=$server.StandardOutput.ReadLineAsync();if(!$read.Wait(60000)){throw 'MCP fixture tool timeout'}
        $response=$read.Result|ConvertFrom-Json
        Assert-Pending (!$response.result.isError -and $response.result.content.Count -eq 1 -and !(Read-SBText (Join-Path $dossier 'memory.md')).Contains('MCP read recovery')) '#474: a running MCP server reads without integrating new requests'
        $server.StandardInput.WriteLine('{"jsonrpc":"2.0","id":3,"method":"tools/list","params":{}}');$server.StandardInput.Flush()
        $read=$server.StandardOutput.ReadLineAsync();if(!$read.Wait(60000)){throw 'MCP fixture definitions timeout'}
        $definitions=($read.Result|ConvertFrom-Json).result.tools
        Assert-Pending ($definitions.Count -eq 13 -and @($definitions|Where-Object {!$_.annotations.readOnlyHint}).Count -eq 1 -and @($definitions|Where-Object {!$_.annotations.readOnlyHint})[0].name -eq 'submit_dossier_write') '#474: every MCP tool but submit_dossier_write declares readOnlyHint=true'
    }finally{$server.StandardInput.Close();if(!$server.WaitForExit(5000)){$server.Kill();$server.WaitForExit()};$server.Dispose()}

    $txFirst=Join-Path $brain '.runtime/interruption-first.txt';$txSecond=Join-Path $brain '.runtime/interruption-second.txt'
    Put-Pending $txFirst 'before';Put-Pending $txSecond 'before'
    $firstHash=Get-SBFileHash $txFirst
    Set-SBWriteGuard {if((Get-SBFileHash $txFirst) -cne $firstHash){throw 'synthetic transaction interruption'}}.GetNewClosure()
    try{
        $interrupted=$false
        try{[void](Invoke-SBParaTransaction @(@{path=$txFirst;expected=$firstHash;bytes=[Text.Encoding]::UTF8.GetBytes('after')},@{path=$txSecond;expected=(Get-SBFileHash $txSecond);bytes=[Text.Encoding]::UTF8.GetBytes('after')}) $cfg.backupRoot $brain)}catch{$interrupted=$true}
        Assert-Pending ($interrupted -and (Get-SBPendingTransaction $brain)) 'interrupted transaction preserves a recoverable journal'
    }finally{Set-SBWriteGuard $null}
    $afterCrash=New-SBPendingWrite -BrainRoot $brain -Repository $identity -Operation file.append -Arguments @{relativePath='memory.md';content="After recovery`n"} -Config $cfg
    $waitingRecovery=Invoke-SBPendingWrites -BrainRoot $brain -Config $cfg
    Assert-Pending ($waitingRecovery.state -eq 'recovery-required' -and $waitingRecovery.pending -ge 1) 'a recovery gate retains new requests without forcing the interrupted transaction'
    $gateSession=Invoke-PendingCli 'access.ps1' @('-Start','-Mode','Write','-Client','recovery-session','-WaitSeconds','0')
    Assert-Pending ($gateSession.code -eq 0) 'session metadata can be opened while central data needs recovery'
    $sessions+=$gateSession.data.sessionId
    $gateEnd=Invoke-PendingCli 'access.ps1' @('-End','-SessionId',$gateSession.data.sessionId)
    Assert-Pending ($gateEnd.code -eq 0) 'session End is never prevented by an interrupted data transaction'
    $marker=Get-SBPendingTransaction $brain
    [void](Restore-SBParaTransaction $marker.manifest $brain $cfg.backupRoot)
    Assert-Pending ((Complete-SBPendingSubmission $afterCrash $cfg).applied -and !(Get-SBPendingTransaction $brain)) 'normal recovery releases the gate and deferred work is integrated'
    $activeRequest=New-SBPendingWrite -BrainRoot $brain -Repository $identity -Operation file.append -Arguments @{relativePath='memory.md';content="After active transaction`n"} -Config $cfg
    $holder=Enter-SBOperation $cfg -WaitMs 0
    $normalGuard=Get-SBWriteGuard;$observed=@{state=$null}
    $wrappedGuard={
        & $normalGuard
        if(!$observed.state -and (Get-SBPendingTransaction $brain)){$observed.state=(Invoke-SBPendingWrites -BrainRoot $brain -Config $cfg).state}
    }.GetNewClosure()
    Set-SBWriteGuard $wrappedGuard
    try{[void](Invoke-SBParaTransaction @(@{path=(Join-Path $brain '.runtime/active-transaction.txt');expected='absent';bytes=[Text.Encoding]::UTF8.GetBytes('normal transaction')}) $cfg.backupRoot $brain)}finally{Exit-SBOperation $holder;$holder=$null}
    Assert-Pending ($observed.state -eq 'busy' -and (Complete-SBPendingSubmission $activeRequest $cfg).applied) 'a live transaction is busy and is never mistaken for an abandoned recovery gate'

    $memoryPath=Join-Path $dossier 'memory.md'
    $denied=New-SBPendingWrite -BrainRoot $brain -Repository $identity -Operation file.append -Arguments @{relativePath='memory.md';content="After denied write`n"} -Config $cfg
    [IO.File]::SetAttributes($memoryPath,[IO.FileAttributes]::ReadOnly)
    try{
        $deniedStderr=Join-Path $fixture 'mcp-denied.stderr'
        $deniedWire=@($init|& pwsh -NoProfile -File (Join-Path $brain 'scripts/mcp-server.ps1') -BrainRoot $brain -ConfigPath $configPath 2> $deniedStderr)
        $deniedInit=$deniedWire -join "`n"|ConvertFrom-Json
        Assert-Pending ($LASTEXITCODE -eq 0 -and $deniedWire.Count -eq 1 -and $deniedInit.result.protocolVersion -eq '2025-03-26') 'MCP storage warnings stay on stderr and never corrupt JSON-RPC stdout'
        $deniedResult=Invoke-SBPendingWrites -BrainRoot $brain -Config $cfg
        Assert-Pending ($deniedResult.pending -ge 1 -and !$deniedResult.applied.Count -and (Test-Path -LiteralPath $denied.path)) 'permission denial never acknowledges unsaved central data'
    }finally{[IO.File]::SetAttributes($memoryPath,[IO.FileAttributes]::Normal)}
    $marker=Get-SBPendingTransaction $brain
    if($marker){[void](Restore-SBParaTransaction $marker.manifest $brain $cfg.backupRoot)}
    Assert-Pending ((Complete-SBPendingSubmission $denied $cfg).applied) 'a preserved request succeeds after permissions and recovery are restored'

    $invalid=New-SBPendingWrite -BrainRoot $brain -Repository $identity -Operation file.append -Arguments @{relativePath='memory.md';content='Invalid'} -Config $cfg
    Put-Pending $invalid.path '{not-json'
    $valid=New-SBPendingWrite -BrainRoot $brain -Repository $identity -Operation file.append -Arguments @{relativePath='memory.md';content="After invalid`n"} -Config $cfg
    $mixed=Invoke-SBPendingWrites -BrainRoot $brain -Config $cfg
    Assert-Pending (@($mixed.conflicts|Where-Object id -eq $invalid.id).Count -eq 1 -and @($mixed.applied|Where-Object id -eq $valid.id).Count -eq 1) 'invalid input is retained and does not block independent requests'
    foreach($badPath in @('../repository.json','repository.json','history/seed/other.json')){
        $rejected=$false;try{New-SBPendingWrite -BrainRoot $brain -Repository $identity -Operation file.append -Arguments @{relativePath=$badPath;content='bad'} -Config $cfg|Out-Null}catch{$rejected=$true}
        Assert-Pending $rejected ('configuration and traversal are rejected: '+$badPath)
    }
    $newTask=Invoke-PendingCli 'knowledge.ps1' @('-CheckoutPath',$checkout,'-NewTask','Queued task','-Acceptance','Fixture criterion','-Provenance','history/seed/report.md')
    Assert-Pending ($newTask.code -eq 0 -and $newTask.data.applied -and $newTask.data.seq -eq 3) 'new tasks retain authoritative numbering and provenance'
    foreach($bad in @(@('-TaskId','S'),@('-TaskId','bad id!'),@('-Priority','B'))){
        $badCli=Invoke-PendingCli 'knowledge.ps1' (@('-CheckoutPath',$checkout,'-NewTask','Rejected task','-Acceptance','Fixture criterion','-Provenance','history/seed/report.md')+$bad)
        Assert-Pending ($badCli.code -ne 0) ('new task rejects '+($bad -join ' '))
    }
    $badTitle=Invoke-PendingCli 'knowledge.ps1' @('-CheckoutPath',$checkout,'-NewTask','12 --','-Acceptance','Fixture criterion','-Provenance','history/seed/report.md')
    Assert-Pending ($badTitle.code -ne 0) 'new task rejects a title without letters'
    $inputFile=Join-Path $fixture 'context.txt';Put-Pending $inputFile 'Saved context'
    $saveCli=Invoke-PendingCli 'knowledge.ps1' @('-CheckoutPath',$checkout,'-SaveFile','context.md','-ContentPath',$inputFile,'-ExpectedHash',(Get-SBFileHash (Join-Path $dossier 'context.md')))
    Assert-Pending ($saveCli.code -eq 0 -and $saveCli.data.applied -and (Read-SBText (Join-Path $dossier 'context.md')) -eq 'Saved context') 'CLI saves a context file with its expected hash'

    $null = New-SBPendingWrite -BrainRoot $brain -Repository $identity -Operation file.append -Arguments @{relativePath='memory.md';content="Exactly once`n"} -Config $cfg
    $workers=@()
    foreach($number in @(1,2)){
        $start=[Diagnostics.ProcessStartInfo]::new((Get-Command pwsh).Source);$start.UseShellExecute=$false;$start.CreateNoWindow=$true
        foreach($arg in @('-NoProfile','-File',(Join-Path $brain 'scripts/knowledge.ps1'),'-ConfigPath',$configPath,'-CheckoutPath',$checkout,'-FlushPending')){$start.ArgumentList.Add($arg)}
        $workers+=[Diagnostics.Process]::Start($start)
    }
    foreach($worker in $workers){$worker.WaitForExit();Assert-Pending ($worker.ExitCode -eq 0) 'concurrent importer completes without a waiting session';$worker.Dispose()}
    Assert-Pending ([regex]::Matches((Read-SBText (Join-Path $dossier 'memory.md')),'Exactly once').Count -eq 1) 'two importing processes apply the same append once'
    $list=Invoke-PendingCli 'knowledge.ps1' @('-PendingWrites')
    Assert-Pending ($list.code -eq 0 -and @($list.data|Where-Object state -eq 'conflict').Count -ge 2) 'pending list exposes preserved conflicts'
    $onlyConflicts=Invoke-PendingCli 'knowledge.ps1' @('-PendingWrites','-PendingState','conflict')
    Assert-Pending ($onlyConflicts.code -eq 0 -and @($onlyConflicts.data).Count -eq @($list.data|Where-Object state -eq 'conflict').Count -and @($onlyConflicts.data|Where-Object state -ne 'conflict').Count -eq 0) 'pending list filters by state'
    $summary=Invoke-PendingCli 'knowledge.ps1' @('-PendingWrites','-PendingSummary')
    Assert-Pending ($summary.code -eq 0 -and $summary.data.total -eq @($list.data).Count -and $summary.data.states.conflict -eq @($list.data|Where-Object state -eq 'conflict').Count -and $summary.data.next) 'pending summary counts requests per state with a next step'
    $discardId=@($list.data|Where-Object state -eq 'conflict')[0].id
    $discardBefore=Get-SBFileHash (@($list.data|Where-Object id -eq $discardId)[0].path)
    $deferredId=@($list.data|Where-Object state -eq 'applied')[0].id
    $refusedApplied=$false;try{[void](Move-SBPendingConflict $brain $deferredId)}catch{$refusedApplied=(Test-SBError $_.Exception 'pending.discard.state')}
    Assert-Pending $refusedApplied 'discard refuses an applied request'
    $discarded=Move-SBPendingConflict $brain $discardId
    Assert-Pending ($discarded.state -eq 'discarded' -and $discarded.previousState -eq 'conflict' -and (Get-SBFileHash (Join-Path $discarded.archive ($discardId+'.json'))) -eq $discardBefore -and (Test-Path -LiteralPath (Join-Path $discarded.archive 'discarded.json'))) 'discard archives a conflict with its original bytes and a note'
    Assert-Pending (@(Get-SBPendingWrites $brain|Where-Object id -eq $discardId).Count -eq 0) 'a discarded conflict leaves the queue'
    $scanProbe=Join-Path $fixture 'scan-probe'
    foreach($suffix in @('0','1')){Put-Pending (Join-Path $scanProbe ('.runtime/access/pending-writes/'+('f'*31)+$suffix+'.json')) '{}'}
    $junctionTarget=Join-Path $fixture 'receipt-junction-target';[IO.Directory]::CreateDirectory($junctionTarget)|Out-Null
    $seen=0;$rejected=$false
    try{
        Get-SBPendingWrites $scanProbe | ForEach-Object {
            $seen++
            if($seen -eq 1){New-Item -ItemType Junction -Path (Join-Path $scanProbe '.runtime/access/pending-receipts') -Target $junctionTarget|Out-Null}
        }
    }catch{$rejected=(Test-SBError $_.Exception 'core.reparse.unwritable')}
    Assert-Pending ($rejected -and $seen -eq 1) 'scan-local ancestor reuse still rejects a receipt directory replaced by a junction between items'
    # #497: an abandoned write session closes by itself (expiry without renewal, or holder interrupted) and frees writer.lock.
    $sharedPath=Join-Path $brain 'config/shared.json'
    $sharedBase=Read-SBJson $sharedPath $null
    foreach($bad in @(0,9,86401,'60')){
        Put-Pending $sharedPath (ConvertTo-SBJson ($sharedBase+@{sessionTimeoutSeconds=$bad}))
        $rejectedTimeout=Invoke-PendingCli 'access.ps1' @('-Status')
        Assert-Pending ($rejectedTimeout.code -ne 0) ('sessionTimeoutSeconds out of range or not an integer is rejected: '+$bad)
    }
    Put-Pending $sharedPath (ConvertTo-SBJson ($sharedBase+@{sessionTimeoutSeconds=10}))
    $sessionRoot=Join-Path $brain '.runtime/access/sessions'
    $expiring=Invoke-PendingCli 'access.ps1' @('-Start','-Mode','Write','-Exclusive','-Client','lease-expiry','-WaitSeconds','0')
    Assert-Pending ($expiring.code -eq 0 -and $expiring.data.exclusive -and $expiring.data.status -eq 'active') 'exclusive session opens with the short timeout'
    $expiringId=$expiring.data.sessionId;$sessions+=$expiringId
    $busyProbe=try{Enter-SBOperation $cfg -WaitMs 0}catch{$null}
    Assert-Pending (!$busyProbe) 'an unrenewed exclusive session holds writer.lock while it is alive'
    if($busyProbe){Exit-SBOperation $busyProbe}
    $closed=$null
    for($i=0;$i -lt 300;$i++){$closed=Read-SBJson (Join-Path $sessionRoot ($expiringId+'.json')) $null;if($closed.status -ne 'active'){break};Start-Sleep -Milliseconds 100}
    Assert-Pending ($closed.status -eq 'expired') 'a session left without -Renew or -End closes by itself as expired'
    $freed=$null
    for($i=0;$i -lt 50 -and !$freed;$i++){$freed=try{Enter-SBOperation $cfg -WaitMs 0}catch{$null};if(!$freed){Start-Sleep -Milliseconds 100}}
    Assert-Pending ([bool]$freed) 'the expired session releases writer.lock without forcing any lock'
    if($freed){Exit-SBOperation $freed}
    Assert-Pending (!(Test-Path -LiteralPath (Join-Path $sessionRoot ($expiringId+'.lease')))) 'the expired session leaves no lease behind'
    $guarded=Invoke-PendingCli 'knowledge.ps1' @('-CheckoutPath',$checkout,'-AppendFile','history/session/expired.md','-ContentPath',$content,'-SessionId',$expiringId)
    Assert-Pending ($guarded.code -ne 0 -and !(Test-Path -LiteralPath (Join-Path $dossier 'history/session/expired.md'))) 'an expired SessionId can no longer write'
    $renewed=Invoke-PendingCli 'access.ps1' @('-Start','-Mode','Write','-Client','lease-renew','-WaitSeconds','0')
    $renewedId=$renewed.data.sessionId;$sessions+=$renewedId
    for($i=0;$i -lt 4;$i++){Start-Sleep -Seconds 4;[void](Invoke-PendingCli 'access.ps1' @('-Renew','-SessionId',$renewedId))}
    Assert-Pending ((Read-SBJson (Join-Path $sessionRoot ($renewedId+'.json')) $null).status -eq 'active') 'a renewed session outlives the timeout'
    $interrupted=Invoke-PendingCli 'access.ps1' @('-Start','-Mode','Write','-Exclusive','-Client','lease-kill','-WaitSeconds','0')
    $interruptedId=$interrupted.data.sessionId;$sessions+=$interruptedId
    Stop-Process -Id $interrupted.data.processId -Force
    $abandoned=$null
    for($i=0;$i -lt 50;$i++){$abandoned=@((Invoke-PendingCli 'access.ps1' @('-Status')).data|Where-Object sessionId -eq $interruptedId);if($abandoned.Count -and $abandoned[0].status -eq 'abandoned'){break};Start-Sleep -Milliseconds 100}
    Assert-Pending ($abandoned.Count -eq 1 -and $abandoned[0].status -eq 'abandoned') 'an interrupted holder is reported abandoned, not active'
    $freedAfterKill=$null
    for($i=0;$i -lt 50 -and !$freedAfterKill;$i++){$freedAfterKill=try{Enter-SBOperation $cfg -WaitMs 0}catch{$null};if(!$freedAfterKill){Start-Sleep -Milliseconds 100}}
    Assert-Pending ([bool]$freedAfterKill) 'an interrupted exclusive holder releases writer.lock'
    if($freedAfterKill){Exit-SBOperation $freedAfterKill}
    $purged=Invoke-PendingCli 'access.ps1' @('-Status','-Purge')
    Assert-Pending ($purged.code -eq 0 -and (Read-SBJson (Join-Path $sessionRoot ($interruptedId+'.json')) $null).status -eq 'abandoned') '-Purge persists abandonment of the interrupted session'
    Put-Pending $sharedPath (ConvertTo-SBJson $sharedBase)
    'SUCCESS PENDING: '+$checks+' verifiche; fixture conservata: '+$fixture
} finally {
    Exit-SBOperation $holder
    foreach($sessionId in $sessions){[void](Invoke-PendingCli 'access.ps1' @('-End','-SessionId',$sessionId))}
    'Fixture pending conservata: '+$fixture
}
