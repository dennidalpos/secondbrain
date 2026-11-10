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
    $data=$null;try{$data=$text|ConvertFrom-Json -AsHashtable}catch{}
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
    $content=Join-Path $fixture 'append.txt';Put-Pending $content "Pending report`n"
    $queuedCli=Invoke-PendingCli 'knowledge.ps1' @('-CheckoutPath',$checkout,'-AppendFile','history/session/report.md','-ContentPath',$content,'-SessionId',$sessions[0])
    Assert-Pending ($queuedCli.code -eq 0 -and $queuedCli.data.state -eq 'deferred') 'CLI queues a dossier report while another writer is active'
    Exit-SBOperation $holder;$holder=$null

    $init='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26"}}'
    $mcpStderr=Join-Path $fixture 'mcp.stderr'
    $wire=$init|& pwsh -NoProfile -File (Join-Path $brain 'scripts/mcp-server.ps1') -BrainRoot $brain -ConfigPath $configPath 2> $mcpStderr
    Assert-Pending ($LASTEXITCODE -eq 0 -and ($wire|ConvertFrom-Json).result.protocolVersion -eq '2025-03-26') 'MCP starts with the recovery contract and clean stdio'
    Assert-Pending ((Read-SBJson $trackerPath $null).tasks[0].status -eq 'in_progress' -and (Read-SBText (Join-Path $dossier 'history/session/report.md')) -eq "Pending report`n") 'a later MCP startup integrates a terminated producer requests'
    $firstReceipt=(Get-SBPendingWrites $brain|Where-Object id -eq $first.id).receipt
    Assert-Pending ($firstReceipt.repository -eq $identity -and $firstReceipt.appliedBy.workstationId -eq $hostId) 'receipts identify the repository and importing workstation without ambiguous task IDs'
    Assert-Pending ((Read-SBText (Join-Path $dossier 'history/index.md')).Contains('session/')) 'report integration regenerates the history index in the same journal'
    $reportHash=Get-SBFileHash (Join-Path $dossier 'history/session/report.md')
    $again=Invoke-SBPendingWrites -BrainRoot $brain -Config $cfg
    Assert-Pending (!$again.applied.Count -and (Get-SBFileHash (Join-Path $dossier 'history/session/report.md')) -eq $reportHash -and (Test-Path -LiteralPath $first.path)) 'receipts prevent duplicate application and original requests are retained'

    $independent=New-SBPendingWrite -BrainRoot $brain -Repository $identity -Operation task.status -Arguments @{TaskId='T-1';Status='done'} -Config $cfg
    [void](Set-SBTrackerTaskStatus -BrainRoot $brain -Identity $identity -WorkingRepository $identity -TaskId T-2 -Status in_progress -BackupRoot $cfg.backupRoot)
    $done=Complete-SBPendingSubmission $independent $cfg
    $archived=Read-SBJson (Join-Path $dossier 'history/tracker-archive.json') $null
    Assert-Pending ($done.applied -and $done.closureAdvice.code -eq 'tracker.closure.advice' -and $archived.tasks[0].id -eq 'T-1' -and (Read-SBJson $trackerPath $null).tasks[0].status -eq 'in_progress') 'closure archives the task without replacing another task changes'
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

    $saved=New-SBPendingWrite -BrainRoot $brain -Repository $identity -Operation file.save -Arguments @{relativePath='context.md';content='Queued replacement'} -Expected @{hash=(Get-SBFileHash (Join-Path $dossier 'context.md'))} -Config $cfg
    Put-Pending (Join-Path $dossier 'context.md') 'Other agent context'
    $fileConflict=Complete-SBPendingSubmission $saved $cfg
    Assert-Pending ($fileConflict.state -eq 'conflict' -and (Read-SBText (Join-Path $dossier 'context.md')) -eq 'Other agent context') 'file replacement requires the original hash'
    $append=New-SBPendingWrite -BrainRoot $brain -Repository $identity -Operation file.append -Arguments @{relativePath='memory.md';content="Verified note`n"} -Config $cfg
    Put-Pending (Join-Path $dossier 'memory.md') "Other agent note`n"
    Assert-Pending ((Complete-SBPendingSubmission $append $cfg).applied -and (Read-SBText (Join-Path $dossier 'memory.md')) -eq "Other agent note`nVerified note`n") 'explicit append preserves intervening text'
    Assert-Pending ((Read-SBText (Join-Path $dossier 'memory.agent.md')) -eq (ConvertTo-SBAgentMemoryView (Read-SBText (Join-Path $dossier 'memory.md')))) 'memory integration regenerates its agent view atomically'
    $override=New-SBPendingWrite -BrainRoot $brain -Repository $identity -Operation file.append -Arguments @{relativePath='memory.md';content="Root override recovery`n"} -Config $cfg
    $rootInit=Invoke-SBMcpMessage $brain @{jsonrpc='2.0';id=100;method='initialize';params=@{}}|ConvertFrom-Json
    Assert-Pending (!$rootInit.error -and (Read-SBText (Join-Path $dossier 'memory.md')).Contains('Root override recovery')) 'MCP code outside the selected brain uses that brain configuration'

    $serverStart=[Diagnostics.ProcessStartInfo]::new((Get-Command pwsh).Source)
    $serverStart.UseShellExecute=$false;$serverStart.CreateNoWindow=$true;$serverStart.RedirectStandardInput=$true;$serverStart.RedirectStandardOutput=$true
    foreach($arg in @('-NoProfile','-File',(Join-Path $brain 'scripts/mcp-server.ps1'),'-BrainRoot',$brain,'-ConfigPath',$configPath)){$serverStart.ArgumentList.Add($arg)}
    $server=[Diagnostics.Process]::Start($serverStart)
    try{
        $server.StandardInput.WriteLine($init);$server.StandardInput.Flush()
        $read=$server.StandardOutput.ReadLineAsync();if(!$read.Wait(60000)){throw 'MCP fixture initialization timeout'}
        $duringRead=New-SBPendingWrite -BrainRoot $brain -Repository $identity -Operation file.append -Arguments @{relativePath='memory.md';content="MCP read recovery`n"} -Config $cfg
        $server.StandardInput.WriteLine('{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"get_task","arguments":{"task":"T-1","repository":"github.com/test/pending"}}}')
        $server.StandardInput.Flush()
        $read=$server.StandardOutput.ReadLineAsync();if(!$read.Wait(60000)){throw 'MCP fixture tool timeout'}
        $response=$read.Result|ConvertFrom-Json
        Assert-Pending (!$response.result.isError -and $response.result.content.Count -ge 2 -and (Read-SBText (Join-Path $dossier 'memory.md')).Contains('MCP read recovery')) 'an already running MCP server integrates new requests before reading'
        $server.StandardInput.WriteLine('{"jsonrpc":"2.0","id":3,"method":"tools/list","params":{}}');$server.StandardInput.Flush()
        $read=$server.StandardOutput.ReadLineAsync();if(!$read.Wait(60000)){throw 'MCP fixture definitions timeout'}
        $definitions=($read.Result|ConvertFrom-Json).result.tools
        Assert-Pending ($definitions.Count -eq 11 -and @($definitions|Where-Object {$_.annotations.readOnlyHint}).Count -eq 1 -and @($definitions|Where-Object {$_.annotations.readOnlyHint})[0].name -eq 'preview_dossier_write') 'only pure preview is read-only; recovery-enabled tools declare their write side effects'
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
    $inputFile=Join-Path $fixture 'context.txt';Put-Pending $inputFile 'Saved context'
    $saveCli=Invoke-PendingCli 'knowledge.ps1' @('-CheckoutPath',$checkout,'-SaveFile','context.md','-ContentPath',$inputFile,'-ExpectedHash',(Get-SBFileHash (Join-Path $dossier 'context.md')))
    Assert-Pending ($saveCli.code -eq 0 -and $saveCli.data.applied -and (Read-SBText (Join-Path $dossier 'context.md')) -eq 'Saved context') 'CLI saves a context file with its expected hash'

    $last=New-SBPendingWrite -BrainRoot $brain -Repository $identity -Operation file.append -Arguments @{relativePath='memory.md';content="Exactly once`n"} -Config $cfg
    $workers=@()
    foreach($number in @(1,2)){
        $start=[Diagnostics.ProcessStartInfo]::new((Get-Command pwsh).Source);$start.UseShellExecute=$false;$start.CreateNoWindow=$true
        foreach($arg in @('-NoProfile','-File',(Join-Path $brain 'scripts/knowledge.ps1'),'-ConfigPath',$configPath,'-FlushPending')){$start.ArgumentList.Add($arg)}
        $workers+=[Diagnostics.Process]::Start($start)
    }
    foreach($worker in $workers){$worker.WaitForExit();Assert-Pending ($worker.ExitCode -eq 0) 'concurrent importer completes without a waiting session';$worker.Dispose()}
    Assert-Pending ([regex]::Matches((Read-SBText (Join-Path $dossier 'memory.md')),'Exactly once').Count -eq 1) 'two importing processes apply the same append once'
    $list=Invoke-PendingCli 'knowledge.ps1' @('-PendingWrites')
    Assert-Pending ($list.code -eq 0 -and @($list.data|Where-Object state -eq 'conflict').Count -ge 2) 'pending list exposes preserved conflicts'
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
    'SUCCESS PENDING: '+$checks+' verifiche; fixture conservata: '+$fixture
} finally {
    Exit-SBOperation $holder
    foreach($sessionId in $sessions){[void](Invoke-PendingCli 'access.ps1' @('-End','-SessionId',$sessionId))}
    'Fixture pending conservata: '+$fixture
}
