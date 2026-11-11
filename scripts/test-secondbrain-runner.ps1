#requires -Version 7.5
# Behavioral fixture for run-ready-tasks.ps1 -Run with a fake agent (never a real claude) and a synthetic tracker.
# The fixture brain receives a copy of scripts/, so the runner resolves only the synthetic dossier; the real trackers are hashed before and after.
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Host.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Tracker.psm1')
. (Join-Path $PSScriptRoot 'test-helpers.ps1')
$script:runnerChecks=0
# Per-phase timing (seconds), printed with the summary so slow phases show up in the Full report.
$script:phaseWatch=[Diagnostics.Stopwatch]::StartNew();$script:phases=[ordered]@{}
function Close-RunnerPhase([string]$Name){$script:phases[$Name]=[math]::Round($script:phaseWatch.Elapsed.TotalSeconds,1);$script:phaseWatch.Restart()}
function Assert-Runner($Condition,[string]$Message){if(!$Condition){throw ('FAIL RUNNER: '+$Message)};$script:runnerChecks++}
function Put-Runner([string]$Path,[string]$Text){[IO.Directory]::CreateDirectory((Split-Path $Path))|Out-Null;[IO.File]::WriteAllText($Path,$Text,[Text.UTF8Encoding]::new($false))}
function Get-RealTrackerHashes {
    $real=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    $map=[ordered]@{}
    foreach($para in @('01-projects','02-areas','03-resources','04-archives')){
        $dir=Join-Path $real $para
        if(Test-Path -LiteralPath $dir){Get-ChildItem -LiteralPath $dir -Recurse -File -Filter 'tracker.json'|Sort-Object FullName|ForEach-Object {$map[$_.FullName]=Get-SBFileHash $_.FullName}}
    }
    $map
}
$realBefore=Get-RealTrackerHashes
$fixture=Join-Path (Get-SBTestRoot) ('runner-'+[guid]::NewGuid().ToString('N'))
$brain=Join-Path $fixture 'brain'
$dossier=Join-Path $brain '02-areas/products/Runner'
$checkout=Join-Path $fixture 'checkout'
$identity='github.com/test/runner'
$hostId=Get-SBHostId
$runtime=Join-Path $brain ('.runtime/hosts/'+$hostId)
$configPath=Join-Path $runtime 'workstation.json'
$trackerPath=Join-Path $dossier 'tracker.json'
$fake=Join-Path $fixture 'agent/fake-agent.ps1'
$envNames=@('SB_RUNNER_FAKE_BRAIN','SB_RUNNER_FAKE_CONFIG','SB_RUNNER_FAKE_CHECKOUT2')
try {
    [IO.Directory]::CreateDirectory((Join-Path $brain 'scripts'))|Out-Null
    Get-ChildItem -LiteralPath $PSScriptRoot -File|Copy-Item -Destination (Join-Path $brain 'scripts')
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'templates') -Destination (Join-Path $brain 'scripts') -Recurse
    Put-Runner (Join-Path $brain 'VERSION') (Read-SBText (Join-Path $PSScriptRoot '../VERSION'))
    Put-Runner (Join-Path $brain 'config/shared.json') (ConvertTo-SBJson @{schemaVersion=1;allowedOwners=@('test');excludedDirectories=@('.git')})
    Put-Runner (Join-Path $brain 'config/tracker.schema.json') (Read-SBText (Join-Path $PSScriptRoot '../config/tracker.schema.json'))
    Put-Runner (Join-Path $brain 'config/agent-models.json') (Read-SBText (Join-Path $PSScriptRoot '../config/agent-models.json'))
    Put-Runner (Join-Path $brain 'direttive/AGENTS.global_ide.md') '# Synthetic directives'
    Put-Runner (Join-Path $brain 'direttive/workstation.template.md') '<!-- secondbrain:tracker-contract:1 -->'
    $approval=@{authorization='isolated runner fixture';files=@{}}
    foreach($file in @('AGENTS.global_ide.md','workstation.template.md')){$approval.files['direttive/'+$file]=Get-SBFileHash (Join-Path $brain ('direttive/'+$file))}
    Put-Runner (Join-Path $brain 'direttive/approved.json') (ConvertTo-SBJson $approval)
    Put-Runner (Join-Path $dossier 'para.json') (ConvertTo-SBJson @{schemaVersion=1;id='runner-area';kind='area';title='Runner';status='active'})
    Put-Runner (Join-Path $dossier 'repository.json') (ConvertTo-SBJson @{schemaVersion=1;identity=$identity;tracker=@{location='dossier';path='tracker.json';schemaVersion=1}})
    Put-Runner (Join-Path $dossier 'context.md') "# Context`n"
    Put-Runner (Join-Path $dossier 'brief.md') '# Synthetic runner fixture'
    Put-Runner (Join-Path $dossier 'memory.md') "# Memory`n"
    Put-Runner (Join-Path $dossier 'history/seed/report.md') 'Synthetic provenance'
    # R-* are runnable; X-* are excluded by stream, execution mode or a human wait.
    $specs=@(
        @{id='R-1';priority='P1';execution='autonomous';stream='evoluzione-team'},
        @{id='R-2';priority='P2';execution='autonomous';stream='evoluzione-team'},
        @{id='R-3';priority='P2';execution='autonomous';stream='evoluzione-team'},
        @{id='R-4';priority='P2';execution='autonomous';stream='evoluzione-team'},
        @{id='R-5';priority='P3';execution='autonomous';stream='evoluzione-team';reads=@('github.com/test/runner2')},
        @{id='X-1';priority='P0';execution='autonomous';stream='qualifica-finale'},
        @{id='X-2';priority='P0';execution='autonomous';stream='intervento-su-richiesta'},
        @{id='X-3';priority='P0';execution='autonomous';stream='coordinamento-prodotti'},
        @{id='X-4';priority='P0';execution='user_required';stream='evoluzione-team'},
        @{id='X-5';priority='P0';execution='autonomous';stream='evoluzione-team';awaiting='owner-confirmation'},
        @{id='X-6';priority='P0';execution='autonomous';stream='evoluzione-team';requires=@('computer-use')}
    )
    $tasks=@();$number=0
    foreach($spec in $specs){
        $number++
        $task=New-SBTrackerTask @{id=$spec.id;title=('Task '+$spec.id);status='todo'} $identity 'fixture' 'history/seed/report.md' (Get-SBTextHash 'Synthetic provenance') 'fixture'
        $task.seq=$number;$task.title='#'+$number.ToString('000')+' — Task '+$spec.id;$task.priority=$spec.priority;$task.execution=$spec.execution
        $ext=@{stream=$spec.stream};if($spec.ContainsKey('awaiting')){$ext.awaiting=$spec.awaiting};if($spec.ContainsKey('reads')){$ext.readRepositories=$spec.reads};if($spec.ContainsKey('requires')){$ext.requires=$spec.requires};$task.extensions=$ext
        $tasks+=,$task
    }
    Put-Runner $trackerPath (ConvertTo-SBJson @{schemaVersion=1;repository=$identity;updatedAt=[DateTimeOffset]::UtcNow.ToString('o');tasks=$tasks;history=@();extensions=@{lastSeq=$number}})
    [IO.Directory]::CreateDirectory($checkout)|Out-Null
    & git -c core.longpaths=true -C $checkout init -q
    & git -c core.longpaths=true -C $checkout remote add origin 'https://github.com/test/runner.git'
    if($LASTEXITCODE){throw 'fixture git'}
    # Second managed repository: its own dossier, tracker and checkout, to exercise the per-repository launcher and installer.
    $identity2='github.com/test/runner2'
    $dossier2=Join-Path $brain '02-areas/products/Runner2'
    $checkout2=Join-Path $fixture 'checkout2'
    $trackerPath2=Join-Path $dossier2 'tracker.json'
    Put-Runner (Join-Path $dossier2 'para.json') (ConvertTo-SBJson @{schemaVersion=1;id='runner2-area';kind='area';title='Runner2';status='active'})
    Put-Runner (Join-Path $dossier2 'repository.json') (ConvertTo-SBJson @{schemaVersion=1;identity=$identity2;tracker=@{location='dossier';path='tracker.json';schemaVersion=1}})
    Put-Runner (Join-Path $dossier2 'context.md') "# Context`n"
    Put-Runner (Join-Path $dossier2 'brief.md') '# Synthetic runner fixture 2'
    Put-Runner (Join-Path $dossier2 'memory.md') "# Memory`n"
    Put-Runner (Join-Path $dossier2 'history/seed/report.md') 'Synthetic provenance'
    $tasks2=@();$number2=0
    foreach($spec in @(@{id='S-1';priority='P1';stream='evoluzione-team'},@{id='S-2';priority='P3';stream='evoluzione-team'},@{id='Y-1';priority='P0';stream='qualifica-finale'})){
        $number2++
        $task=New-SBTrackerTask @{id=$spec.id;title=('Task '+$spec.id);status='todo'} $identity2 'fixture' 'history/seed/report.md' (Get-SBTextHash 'Synthetic provenance') 'fixture'
        $task.seq=$number2;$task.title='#'+$number2.ToString('000')+' — Task '+$spec.id;$task.priority=$spec.priority;$task.execution='autonomous';$task.extensions=@{stream=$spec.stream}
        $tasks2+=,$task
    }
    Put-Runner $trackerPath2 (ConvertTo-SBJson @{schemaVersion=1;repository=$identity2;updatedAt=[DateTimeOffset]::UtcNow.ToString('o');tasks=$tasks2;history=@();extensions=@{lastSeq=$number2}})
    [IO.Directory]::CreateDirectory($checkout2)|Out-Null
    & git -c core.longpaths=true -C $checkout2 init -q
    & git -c core.longpaths=true -C $checkout2 remote add origin 'https://github.com/test/runner2.git'
    if($LASTEXITCODE){throw 'fixture git 2'}
    $cfg=@{schemaVersion=1;mode='portable';workstationId=$hostId;runtimeRoot=$runtime;backupRoot=(Join-Path $runtime 'backups');bindings=@(@{identity=$identity;path=$checkout;remoteIdentity=$identity},@{identity=$identity2;path=$checkout2;remoteIdentity=$identity2},@{identity='github.com/test/missing';path=(Join-Path $fixture 'no-such-checkout');remoteIdentity='github.com/test/missing'});ides=@()}
    Put-Runner $configPath (ConvertTo-SBJson $cfg)
    # Fake agent (mode as its only positional argument): reads the prompt from stdin and echoes it in a claude-like JSON envelope; the mode drives the outcome.
    Put-Runner $fake @'
param([string]$Mode='ok')
$prompt=[Console]::In.ReadToEnd()
$id=if($prompt -match 'SOLO il task (\S+)'){$Matches[1]}else{''}
switch($Mode){
    'ok' {
        & pwsh -NoProfile -File (Join-Path $env:SB_RUNNER_FAKE_BRAIN 'scripts/knowledge.ps1') -ConfigPath $env:SB_RUNNER_FAKE_CONFIG -CheckoutPath (Get-Location).Path -UpdateTaskId $id -Status in_progress -StateReason 'Fake agent run'|Out-Null
        if($LASTEXITCODE){[Console]::Error.WriteLine('update failed');exit 5}
        [Console]::Out.Write((@{type='result';is_error=$false;result=$prompt}|ConvertTo-Json -Compress));exit 0
    }
    # Parking modes: exit 0 with an answer; 'noop' leaves the task todo, 'done' and 'blocked' set a terminal or waiting status through the agent session.
    'noop' {[Console]::Out.Write((@{type='result';is_error=$false;result='no progress'}|ConvertTo-Json -Compress));exit 0}
    {$_ -in @('done','blocked')} {
        & pwsh -NoProfile -File (Join-Path $env:SB_RUNNER_FAKE_BRAIN 'scripts/knowledge.ps1') -ConfigPath $env:SB_RUNNER_FAKE_CONFIG -CheckoutPath (Get-Location).Path -UpdateTaskId $id -Status $Mode -StateReason ('Fake agent '+$Mode)|Out-Null
        if($LASTEXITCODE){[Console]::Error.WriteLine('update failed');exit 5}
        [Console]::Out.Write((@{type='result';is_error=$false;result=$Mode}|ConvertTo-Json -Compress));exit 0
    }
    # Read-scope guard (#382): probes knowledge.ps1 inside the runner session and reports exit codes and messages; then marks the task in progress.
    'guard' {
        $k=Join-Path $env:SB_RUNNER_FAKE_BRAIN 'scripts/knowledge.ps1';$c=@('-ConfigPath',$env:SB_RUNNER_FAKE_CONFIG,'-CheckoutPath',(Get-Location).Path)
        function Probe([string[]]$A){$o=(& pwsh -NoProfile -File $k @A 2>&1|Out-String);@{code=$LASTEXITCODE;text=$o}}
        $r=[ordered]@{repository=$env:SECONDBRAIN_RUNNER_REPOSITORY;reads=$env:SECONDBRAIN_RUNNER_READS}
        $r.all=Probe (@('-Tasks','-All')+$c)
        $r.allDossiers=Probe (@('-Search','Context','-AllDossiers')+$c)
        $r.own=Probe (@('-Tasks')+$c)
        $r.allowed=Probe (@('-Tasks','-Repository','github.com/test/runner2')+$c)
        $r.allowedSearch=Probe (@('-Search','Context','-Repository','github.com/test/runner2')+$c)
        $r.allowedCheckout=Probe @('-Tasks','-ConfigPath',$env:SB_RUNNER_FAKE_CONFIG,'-CheckoutPath',$env:SB_RUNNER_FAKE_CHECKOUT2)
        $r.foreignWrite=Probe @('-UpdateTaskId','S-1','-Status','in_progress','-ConfigPath',$env:SB_RUNNER_FAKE_CONFIG,'-CheckoutPath',$env:SB_RUNNER_FAKE_CHECKOUT2)
        $saved=$env:SECONDBRAIN_RUNNER_READS;$env:SECONDBRAIN_RUNNER_READS='';$r.notAllowed=Probe (@('-Tasks','-Repository','github.com/test/runner2')+$c);$r.foreignCheckout=Probe @('-Tasks','-ConfigPath',$env:SB_RUNNER_FAKE_CONFIG,'-CheckoutPath',$env:SB_RUNNER_FAKE_CHECKOUT2);$env:SECONDBRAIN_RUNNER_READS=$saved
        & pwsh -NoProfile -File $k -UpdateTaskId $id -Status in_progress -StateReason 'Fake agent guard' @c|Out-Null
        if($LASTEXITCODE){[Console]::Error.WriteLine('update failed');exit 5}
        [Console]::Out.Write((@{type='result';is_error=$false;result=($r|ConvertTo-Json -Compress -Depth 4)}|ConvertTo-Json -Compress));exit 0
    }
    'quota' {[Console]::Out.Write((@{type='result';is_error=$true;result='Claude AI usage limit reached|usage_limit_reached'}|ConvertTo-Json -Compress));exit 1}
    'fail' {[Console]::Error.WriteLine('synthetic failure');exit 2}
    'hang' {Start-Sleep -Seconds 600;exit 0}
    'crash' {exit -1073740791}
    'empty' {exit 0}
}
'@
    $env:SB_RUNNER_FAKE_BRAIN=$brain;$env:SB_RUNNER_FAKE_CONFIG=$configPath;$env:SB_RUNNER_FAKE_CHECKOUT2=$checkout2
    $runner=Join-Path $brain 'scripts/run-ready-tasks.ps1'
    function Invoke-Runner([string[]]$RunnerArguments){
        $lines=@(& pwsh -NoProfile -File $runner -CheckoutPath $checkout -ConfigPath $configPath -AgentPath $fake @RunnerArguments 2>&1|ForEach-Object {[string]$_})
        $code=$LASTEXITCODE;$text=$lines -join "`n"
        $i=$text.IndexOf('{');$data=$null
        if($i -ge 0){try{$data=$text.Substring($i)|ConvertFrom-Json -AsHashtable}catch{}}
        @{code=$code;text=$text;data=$data}
    }
    function Assert-Folder($Record,[string]$Label){
        $root=$Record.folder
        Assert-Runner ($root -and $root.StartsWith($runtime,[StringComparison]::OrdinalIgnoreCase)) ($Label+': report folder lives in the fixture runtime')
        $manifest=Read-SBJson (Join-Path $root 'MANIFEST.json') $null
        Assert-Runner ($manifest.category -eq 'report' -and $manifest.status -eq 'closed') ($Label+': report folder is closed')
        $report=Read-SBJson (Join-Path $root 'report.json') $null
        Assert-Runner ($report.id -eq $Record.id -and $report.state -eq $Record.state -and $report.exitCode -eq $Record.exitCode) ($Label+': report.json matches the run record')
        Assert-Runner ((Test-Path -LiteralPath (Join-Path $root 'agent-output.json')) -and (Test-Path -LiteralPath (Join-Path $root 'agent-error.txt'))) ($Label+': agent output and error are kept')
    }

    Close-RunnerPhase 'setup'
    # Preview: selection by stream, execution, wait, priority and MaxTasks; nothing written.
    $hash=Get-SBFileHash $trackerPath
    $preview=Invoke-Runner @('-MaxTasks','10')
    Assert-Runner ($preview.code -eq 0 -and !$preview.data.run) ('preview succeeds without running: '+$preview.text)
    Assert-Runner ((@($preview.data.tasks|ForEach-Object id) -join ',') -ceq 'R-1,R-2,R-3,R-4,R-5') 'preview selects only autonomous todo tasks outside excluded streams and human waits, by priority and seq'
    Assert-Runner (@($preview.data.tasks|Where-Object {$_.prompt -notmatch 'nessun commit, push'}).Count -eq 0) 'every planned prompt forbids commit and push'
    Assert-Runner ((Get-SBFileHash $trackerPath) -ceq $hash -and !(Test-Path -LiteralPath (Join-Path $runtime 'repos'))) 'preview writes neither the tracker nor work folders'

    # Exclusion reasons (#384): every ready task left out is listed in skipped with its reason; -MaxTasks cuts are reported too.
    $reasons=@{};foreach($s in @($preview.data.skipped)){if($s.Contains('id')){$reasons[[string]$s.id]=[string]$s.reason}}
    Assert-Runner ($reasons['X-1'] -ceq 'stream:qualifica-finale' -and $reasons['X-2'] -ceq 'stream:intervento-su-richiesta' -and $reasons['X-3'] -ceq 'stream:coordinamento-prodotti') ('preview skipped explains the excluded streams: '+($reasons|ConvertTo-Json -Compress))
    Assert-Runner ($reasons['X-4'] -ceq 'execution:user_required' -and $reasons['X-5'] -ceq 'awaiting:owner-confirmation') 'preview skipped explains execution mode and human wait'
    Assert-Runner ($reasons['X-6'] -ceq 'requires:computer-use') 'preview skipped explains a task that needs computer use'
    Assert-Runner ($reasons.Count -eq 6) 'preview skipped lists only the excluded ready tasks'
    $cut=Invoke-Runner @('-MaxTasks','2')
    $cutReasons=@($cut.data.skipped|Where-Object {$_.Contains('id') -and $_.reason -ceq 'max-tasks'}|ForEach-Object id)
    Assert-Runner (($cutReasons -join ',') -ceq 'R-3,R-4,R-5') ('preview skipped reports the tasks cut by MaxTasks: '+$cut.text)

    Close-RunnerPhase 'preview'
    # Success: prompt delivered on stdin, the agent updates the task through its own CLI session, closed report folder.
    $ok=Invoke-Runner @('-Run','-MaxTasks','1','-AgentArguments','ok')
    Assert-Runner ($ok.code -eq 0 -and $ok.data.run -and $null -eq $ok.data.stopReason -and @($ok.data.tasks).Count -eq 1) ('fake agent run succeeds: '+$ok.text)
    $record=@($ok.data.tasks)[0]
    Assert-Runner ($record.id -eq 'R-1' -and $record.state -eq 'finished' -and $record.exitCode -eq 0) 'highest-priority task runs and finishes'
    Assert-Runner ($record.statusBefore -eq 'todo' -and $record.statusAfter -eq 'in_progress') 'status after is read back from the tracker updated by the agent session'
    Assert-Folder $record 'ok'
    $output=Read-SBJson (Join-Path $record.folder 'agent-output.json') $null
    $expectedPrompt=& {Import-Module (Join-Path $PSScriptRoot 'SecondBrain.TaskRunner.psm1') -Force;New-SBTaskRunPrompt ([pscustomobject]@{id='R-1';seq=1}) (Join-Path $brain 'scripts') $checkout}
    $firstDiff=0;while($firstDiff -lt [Math]::Min($output.result.Length,$expectedPrompt.Length) -and $output.result[$firstDiff] -ceq $expectedPrompt[$firstDiff]){$firstDiff++}
    Assert-Runner ($output.result -ceq $expectedPrompt) ('the agent received the fixed prompt on stdin (lengths '+$output.result.Length+'/'+$expectedPrompt.Length+', first difference at '+$firstDiff+'; got: '+$output.result.Substring(0,[Math]::Min(60,$output.result.Length))+')')

    Close-RunnerPhase 'ok'
    # Quota: the run stops at the first exhausted-plan answer and the runner itself never writes the tracker.
    $hash=Get-SBFileHash $trackerPath
    $quota=Invoke-Runner @('-Run','-MaxTasks','3','-AgentArguments','quota')
    Assert-Runner ($quota.code -eq 1 -and $quota.data.stopReason -eq 'quota' -and @($quota.data.tasks).Count -eq 1 -and @($quota.data.tasks)[0].state -eq 'quota') ('quota stops the run after one task: '+$quota.text)
    Assert-Folder @($quota.data.tasks)[0] 'quota'
    Assert-Runner ((Get-SBFileHash $trackerPath) -ceq $hash) 'the runner does not write the tracker'

    Close-RunnerPhase 'quota'
    # Three consecutive failures stop the run before the fourth task.
    $fail=Invoke-Runner @('-Run','-MaxTasks','4','-AgentArguments','fail')
    Assert-Runner ($fail.code -eq 1 -and $fail.data.stopReason -eq 'failures' -and (@($fail.data.tasks|ForEach-Object id) -join ',') -ceq 'R-2,R-3,R-4') ('three consecutive failures stop the run: '+$fail.text)
    Assert-Runner (@($fail.data.tasks|Where-Object {$_.state -ne 'finished' -or $_.exitCode -ne 2}).Count -eq 0) 'failures keep the agent exit code'
    foreach($r in @($fail.data.tasks)){Assert-Folder $r ('fail '+$r.id)}

    Close-RunnerPhase 'failures'
    # A crashed agent (negative exit code) and an empty answer are never reported as finished.
    $crash=Invoke-Runner @('-Run','-MaxTasks','1','-AgentArguments','crash')
    Assert-Runner ($crash.code -eq 1 -and @($crash.data.tasks).Count -eq 1 -and @($crash.data.tasks)[0].state -eq 'crashed' -and @($crash.data.tasks)[0].exitCode -eq -1073740791) ('crashed agent is classified crashed: '+$crash.text)
    Assert-Folder @($crash.data.tasks)[0] 'crash'
    $empty=Invoke-Runner @('-Run','-MaxTasks','1','-AgentArguments','empty')
    Assert-Runner ($empty.code -eq 1 -and @($empty.data.tasks)[0].state -eq 'no-output') ('empty answer is classified no-output: '+$empty.text)
    Assert-Folder @($empty.data.tasks)[0] 'empty'

    Close-RunnerPhase 'crash-empty'
    # Timeout: the hung agent is killed after the minimum timeout (1 minute).
    $watch=[Diagnostics.Stopwatch]::StartNew()
    $hang=Invoke-Runner @('-Run','-MaxTasks','1','-TimeoutMinutes','1','-AgentArguments','hang')
    $watch.Stop()
    Assert-Runner ($hang.code -eq 1 -and @($hang.data.tasks).Count -eq 1 -and @($hang.data.tasks)[0].state -eq 'timeout') ('hung agent ends in timeout: '+$hang.text)
    Assert-Runner ($watch.Elapsed.TotalSeconds -lt 180) ('timeout kills the agent promptly: '+[math]::Round($watch.Elapsed.TotalSeconds,1)+' s')
    Assert-Folder @($hang.data.tasks)[0] 'timeout'
    Assert-Runner ((Get-SBFileHash $trackerPath) -ceq $hash) 'failed and timed-out runs leave the tracker unchanged'

    Close-RunnerPhase 'timeout'
    # Parking (#380): a finished run that leaves the task todo turns it user_required; done or blocked tasks keep their execution mode.
    function Get-FixtureTask([string]$Id){
        $tr=Read-SBJson $trackerPath $null
        $hit=@(@($tr.tasks)+@($tr.history)|Where-Object {$_ -and [string]$_.id -eq $Id})
        if($hit.Count -ge 1){$hit[0]}else{$null}
    }
    $noop=Invoke-Runner @('-Run','-MaxTasks','1','-AgentArguments','noop')
    $parked=@($noop.data.tasks)[0]
    Assert-Runner ($noop.code -eq 0 -and $parked.id -eq 'R-2' -and $parked.state -eq 'finished' -and $parked.statusAfter -eq 'todo' -and $parked.parked) ('a run that leaves the task todo parks it: '+$noop.text)
    $parkedTask=Get-FixtureTask 'R-2'
    Assert-Runner ($parkedTask.status -eq 'todo' -and $parkedTask.execution -eq 'user_required') 'the parked task stays todo with execution user_required'
    Assert-Runner ((Read-SBJson (Join-Path $parked.folder 'report.json') $null).parked -eq $true) 'report.json records the parking'
    Assert-Folder $parked 'noop'
    $done=Invoke-Runner @('-Run','-MaxTasks','1','-AgentArguments','done')
    $doneRecord=@($done.data.tasks)[0]
    Assert-Runner ($done.code -eq 0 -and $doneRecord.id -eq 'R-3' -and $doneRecord.statusAfter -eq 'done' -and !$doneRecord.parked) ('a done task is not parked: '+$done.text)
    $doneTask=Get-FixtureTask 'R-3'
    Assert-Runner ($null -eq $doneTask -or $doneTask.execution -eq 'autonomous') 'a done task keeps execution autonomous'
    $blocked=Invoke-Runner @('-Run','-MaxTasks','1','-AgentArguments','blocked')
    $blockedRecord=@($blocked.data.tasks)[0]
    Assert-Runner ($blocked.code -eq 0 -and $blockedRecord.id -eq 'R-4' -and $blockedRecord.statusAfter -eq 'blocked' -and !$blockedRecord.parked) ('a blocked task is not parked: '+$blocked.text)
    $blockedTask=Get-FixtureTask 'R-4'
    Assert-Runner ($blockedTask.status -eq 'blocked' -and $blockedTask.execution -eq 'autonomous') 'a blocked task keeps status blocked and execution autonomous'
    $after=Invoke-Runner @('-MaxTasks','10')
    Assert-Runner ((@($after.data.tasks|ForEach-Object id) -join ',') -ceq 'R-5') ('parked, done and blocked tasks leave the selection: '+$after.text)
    Close-RunnerPhase 'parking'
    # Read-scope guard (#382): the runner passes the task repository and its read allowlist to the agent; global reads, foreign repositories and writes outside the task repository are refused in code.
    $hash2=Get-SBFileHash $trackerPath2
    $guard=Invoke-Runner @('-Run','-MaxTasks','1','-AgentArguments','guard')
    $guardRecord=@($guard.data.tasks)[0]
    Assert-Runner ($guard.code -eq 0 -and $guardRecord.id -eq 'R-5' -and $guardRecord.statusAfter -eq 'in_progress') ('guard run finishes: '+$guard.text)
    $probe=(Read-SBJson (Join-Path $guardRecord.folder 'agent-output.json') $null).result|ConvertFrom-Json -AsHashtable
    Assert-Runner ($probe.repository -ceq $identity -and $probe.reads -ceq 'github.com/test/runner2') ('the agent session receives the task repository and its read allowlist: '+($probe|ConvertTo-Json -Compress -Depth 4))
    $scopeText='runner session|sessione del runner'
    Assert-Runner ($probe.all.code -eq 2 -and $probe.all.text -match $scopeText) ('-All is refused in a runner session: '+$probe.all.text)
    Assert-Runner ($probe.allDossiers.code -eq 2 -and $probe.allDossiers.text -match $scopeText) ('-AllDossiers is refused in a runner session: '+$probe.allDossiers.text)
    Assert-Runner ($probe.notAllowed.code -eq 2 -and $probe.notAllowed.text -match $scopeText) ('a repository outside the allowlist is refused: '+$probe.notAllowed.text)
    Assert-Runner ($probe.foreignCheckout.code -eq 2 -and $probe.foreignCheckout.text -match $scopeText) ('-CheckoutPath of a repository outside the allowlist is refused: '+$probe.foreignCheckout.text)
    Assert-Runner ($probe.foreignWrite.code -eq 2 -and $probe.foreignWrite.text -match $scopeText -and (Get-SBFileHash $trackerPath2) -ceq $hash2) ('the allowlist is read-only: a write to it is refused and its tracker unchanged: '+$probe.foreignWrite.text)
    Assert-Runner ($probe.own.code -eq 0 -and $probe.allowed.code -eq 0 -and $probe.allowedCheckout.code -eq 0 -and $probe.allowed.text -match 'S-1' -and $probe.allowedSearch.code -eq 0) ('the task repository and the allowlisted repository stay readable: '+$probe.allowed.text+$probe.allowedSearch.text)
    # MCP tools in a runner session, in a separate process so the variables never reach this test: all=true and allDossiers=true refused, allowlist readable.
    $mcpProbe=Join-Path $fixture 'agent/mcp-probe.ps1'
    Put-Runner $mcpProbe @'
param([string]$Brain,[string]$Config,[string]$Checkout,[string]$Reads)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $Brain 'scripts/SecondBrain.Mcp.psm1')
$env:SECONDBRAIN_CONFIG=$Config
Set-Location -LiteralPath $Checkout
function Probe($Tool,$Arguments){try{[void](Invoke-SBMcpToolCall $Brain $Tool $Arguments);'ok'}catch{'refused: '+$_.Exception.Message}}
$r=[ordered]@{}
$r.userAll=Probe 'get_ready_tasks' @{all=$true}
$r.userSearch=Probe 'search_knowledge' @{query='Context';allDossiers=$true}
$env:SECONDBRAIN_RUNNER_REPOSITORY='github.com/test/runner';$env:SECONDBRAIN_RUNNER_READS=$Reads
$r.all=Probe 'get_ready_tasks' @{all=$true}
$r.allDossiers=Probe 'search_knowledge' @{query='Context';allDossiers=$true}
$r.allowed=Probe 'get_ready_tasks' @{repository='github.com/test/runner2'}
$r.foreignWrite=Probe 'preview_dossier_write' @{repository='github.com/test/runner2';checkoutPath='x';requestId=('0'*32);operation='task.status';payload=@{taskId='S-1';status='done'}}
$env:SECONDBRAIN_RUNNER_READS=''
$r.notAllowed=Probe 'get_ready_tasks' @{repository='github.com/test/runner2'}
$r|ConvertTo-Json -Compress
'@
    # Project isolation is the default: global views and unscoped searches are refused until crossProjectReads is enabled.
    $isolated=(& pwsh -NoProfile -File (Join-Path $brain 'scripts/knowledge.ps1') -Tasks -All -ConfigPath $configPath -CheckoutPath $checkout 2>&1|Out-String)
    Assert-Runner ($LASTEXITCODE -ne 0 -and $isolated -match 'Isolamento per progetto|Project isolation') ('by default -All is refused by project isolation: '+$isolated)
    $isolatedSearch=(& pwsh -NoProfile -File (Join-Path $brain 'scripts/knowledge.ps1') -Search 'Context' -AllDossiers -ConfigPath $configPath -CheckoutPath $checkout 2>&1|Out-String)
    Assert-Runner ($LASTEXITCODE -ne 0 -and $isolatedSearch -match 'Isolamento per progetto|Project isolation') ('by default -AllDossiers is refused by project isolation: '+$isolatedSearch)
    $sharedFile=Join-Path $brain 'config/shared.json';[void](New-Item -ItemType Directory -Force (Split-Path $sharedFile))
    $sharedPolicy=Get-Content -LiteralPath $sharedFile -Raw -ErrorAction SilentlyContinue|ConvertFrom-Json -AsHashtable
    if(!$sharedPolicy){$sharedPolicy=@{allowedOwners=@();excludedDirectories=@('.git');forbiddenRepositories=@();schemaVersion=1}}
    $sharedPolicy.crossProjectReads=$true
    [IO.File]::WriteAllText($sharedFile,($sharedPolicy|ConvertTo-Json -Depth 5))
    $mcp=(& pwsh -NoProfile -File $mcpProbe -Brain $brain -Config $configPath -Checkout $checkout -Reads 'github.com/test/runner2' 2>&1|Out-String)
    $mcpResult=$mcp.Substring($mcp.IndexOf('{'))|ConvertFrom-Json -AsHashtable
    Assert-Runner ($mcpResult.userAll -eq 'ok' -and $mcpResult.userSearch -eq 'ok') ('outside a runner session MCP all=true and allDossiers=true keep working: '+$mcp)
    Assert-Runner ($mcpResult.all -match $scopeText -and $mcpResult.allDossiers -match $scopeText) ('MCP all=true and allDossiers=true are refused in a runner session: '+$mcp)
    Assert-Runner ($mcpResult.allowed -eq 'ok' -and $mcpResult.notAllowed -match $scopeText -and $mcpResult.foreignWrite -match $scopeText) ('MCP reads follow the allowlist and writes stay in the task repository: '+$mcp)
    # No regression: without the runner variables a person keeps the global views.
    $userAll=(& pwsh -NoProfile -File (Join-Path $brain 'scripts/knowledge.ps1') -Tasks -All -ConfigPath $configPath -CheckoutPath $checkout 2>&1|Out-String)
    Assert-Runner ($LASTEXITCODE -eq 0 -and $userAll -match 'S-1' -and $userAll -match 'R-5') ('outside a runner session -All lists every repository: '+$userAll)
    $userSearch=(& pwsh -NoProfile -File (Join-Path $brain 'scripts/knowledge.ps1') -Search 'Context' -AllDossiers -ConfigPath $configPath -CheckoutPath $checkout 2>&1|Out-String)
    Assert-Runner ($LASTEXITCODE -eq 0) ('outside a runner session -AllDossiers works: '+$userSearch)
    Close-RunnerPhase 'guard'
    # Per-repository launcher: the generator previews by default, writes only new files, never overwrites a different one and skips SecondBrain itself.
    $hash2=Get-SBFileHash $trackerPath2
    $installer=Join-Path $brain 'scripts/install-task-launcher.ps1'
    function Invoke-Installer([string[]]$InstallerArguments){
        $text=(& pwsh -NoProfile -File $installer -ConfigPath $configPath @InstallerArguments 2>&1|Out-String)
        $i=$text.IndexOf('{');@{code=$LASTEXITCODE;text=$text;data=$(if($i -ge 0){$text.Substring($i)|ConvertFrom-Json -AsHashtable}else{$null})}
    }
    $launcher1=Join-Path $checkout '.secondbrain/run-tasks.ps1'
    $launcher2=Join-Path $checkout2 '.secondbrain/run-tasks.ps1'
    $prev=Invoke-Installer @()
    Assert-Runner ($prev.code -eq 0 -and !$prev.data.apply -and @($prev.data.repositories|Where-Object {$_.state -eq 'new'}).Count -eq 2) ('installer preview lists both checkouts as new: '+$prev.text)
    Assert-Runner (@($prev.data.repositories|Where-Object {$_.repository -eq 'github.com/test/missing' -and $_.state -eq 'checkout-missing'}).Count -eq 1) 'a binding without a checkout is reported, not written'
    Assert-Runner (!(Test-Path -LiteralPath $launcher1) -and !(Test-Path -LiteralPath $launcher2)) 'installer preview writes nothing'
    Put-Runner $launcher2 '# a different local launcher'
    $app=Invoke-Installer @('-Apply')
    Assert-Runner ($app.code -eq 0 -and $app.data.apply -and (Test-Path -LiteralPath $launcher1)) ('installer apply writes the launcher where absent: '+$app.text)
    Assert-Runner ((Get-SBFileHash $launcher1) -ceq $app.data.templateSha256) 'the installed launcher is the template byte for byte'
    Assert-Runner ((Read-SBText $launcher2) -ceq '# a different local launcher' -and @($app.data.repositories|Where-Object {$_.repository -eq $identity2 -and $_.state -eq 'different' -and !$_.written}).Count -eq 1) 'a different existing launcher is never overwritten'
    $again=Invoke-Installer @('-Apply')
    Assert-Runner (@($again.data.repositories|Where-Object {$_.repository -eq $identity -and $_.state -eq 'identical' -and !$_.written}).Count -eq 1) 'a second apply is idempotent'
    Assert-Runner ($null -eq (& git -C $checkout status --porcelain --untracked-files=no) -or !(& git -C $checkout status --porcelain --untracked-files=no)) 'the installer stages and commits nothing'
    Remove-Item -LiteralPath $launcher2 -Force
    $only=Invoke-Installer @('-Apply','-Repository',$identity2)
    Assert-Runner ($only.code -eq 0 -and (Test-Path -LiteralPath $launcher2) -and @($only.data.repositories).Count -eq 1) '-Repository limits the installer to the named repository'
    Close-RunnerPhase 'installer'
    # The launcher runs the runner for its own checkout only, found through SECONDBRAIN_HOME.
    $savedHome=$env:SECONDBRAIN_HOME
    try {
        $env:SECONDBRAIN_HOME=$brain
        $lines=@(& pwsh -NoProfile -File $launcher2 -MaxTasks 10 2>&1|ForEach-Object {[string]$_})
        $code=$LASTEXITCODE;$text=$lines -join "`n";$i=$text.IndexOf('{');$data=$text.Substring($i)|ConvertFrom-Json -AsHashtable
        Assert-Runner ($code -eq 0 -and !$data.run -and (@($data.tasks|ForEach-Object id) -join ',') -ceq 'S-1,S-2') ('the launcher previews only its own repository tasks: '+$text)
        Assert-Runner (@($data.tasks|Where-Object {$_.prompt -notmatch 'Strumenti SecondBrain in '}).Count -eq 0) 'prompts launched from a product checkout name the SecondBrain tools and the checkout'
        $env:SECONDBRAIN_HOME=(Join-Path $fixture 'no-such-home')
        & pwsh -NoProfile -File $launcher2 *> $null
        Assert-Runner ($LASTEXITCODE -eq 2) 'the launcher stops with exit 2 when SecondBrain cannot be found'
        # Absent variable (#387): a fixture copy that does not read the User scope, so the workstation variable is never touched.
        $noUser=Join-Path $fixture 'launcher-nouser/run-tasks.ps1'
        $templateLines=@(Get-Content -LiteralPath $launcher2)
        $kept=@($templateLines|Where-Object {$_ -notmatch "GetEnvironmentVariable\('SECONDBRAIN_HOME','User'\)"})
        Assert-Runner ($kept.Count -eq $templateLines.Count-1) 'the fixture copy drops exactly the User-scope lookup'
        Put-Runner $noUser (($kept -join "`n")+"`n")
        Remove-Item Env:SECONDBRAIN_HOME -ErrorAction SilentlyContinue
        foreach($culture in @(@{name='it-IT';pattern='non impostata'},@{name='en-US';pattern='is not set'})){
            $wrapper="[Threading.Thread]::CurrentThread.CurrentUICulture=[Globalization.CultureInfo]::new('$($culture.name)');& '$noUser';exit `$LASTEXITCODE"
            $out=(& pwsh -NoProfile -Command $wrapper 2>&1|Out-String)
            Assert-Runner ($LASTEXITCODE -eq 2 -and $out -match $culture.pattern) ('the launcher without SECONDBRAIN_HOME exits 2 with the '+$culture.name+' message: '+$out)
        }
    } finally { $env:SECONDBRAIN_HOME=$savedHome }
    Assert-Runner ((Get-SBFileHash $trackerPath2) -ceq $hash2) 'launcher previews write nothing'

    Close-RunnerPhase 'launcher'
    # Provider adapters, explicit queue, stop file and JSON events (desktop orchestrator), on the second repository.
    function Invoke-Runner2([string[]]$RunnerArguments){
        $errFile=Join-Path $fixture ('runner2-'+[guid]::NewGuid().ToString('N')+'.err')
        $out=(& pwsh -NoProfile -File $runner -CheckoutPath $checkout2 -ConfigPath $configPath @RunnerArguments 2>$errFile|Out-String)
        $code=$LASTEXITCODE;$err=[IO.File]::ReadAllText($errFile)
        $i=$out.IndexOf('{');$data=if($i -ge 0){$out.Substring($i)|ConvertFrom-Json -AsHashtable}else{$null}
        @{code=$code;text=$out+$err;err=$err;data=$data}
    }
    $hash2=Get-SBFileHash $trackerPath2
    $queue=Invoke-Runner2 @('-AgentPath',$fake,'-AgentArguments','ok','-MaxTasks','0','-TaskIds','S-2,S-1;Y-1,NOPE')
    $queueReasons=@{};foreach($s in @($queue.data.skipped)){if($s.Contains('id')){$queueReasons[[string]$s.id]=[string]$s.reason}}
    Assert-Runner ($queue.code -eq 0 -and (@($queue.data.tasks|ForEach-Object id) -join ',') -ceq 'S-2,S-1') ('-TaskIds keeps the given order of runnable tasks: '+$queue.text)
    Assert-Runner ($queueReasons['Y-1'] -ceq 'stream:qualifica-finale' -and $queueReasons['NOPE'] -ceq 'not-ready' -and $queueReasons.Count -eq 2) ('-TaskIds reports excluded and unknown IDs: '+($queueReasons|ConvertTo-Json -Compress))
    $codexHomeFixture=Join-Path $fixture 'codex-home';[IO.Directory]::CreateDirectory($codexHomeFixture)|Out-Null
    $savedCodexHome=$env:CODEX_HOME
    try{
        $env:CODEX_HOME=$codexHomeFixture
        $fakeCodex=Join-Path $fixture 'agent/codex.ps1'
        Put-Runner $fakeCodex "if(`$args -contains '--version'){'codex-cli 0.1.0';exit 0}`n'Usage: codex exec [OPTIONS] [PROMPT]'`n'  -c, --config <key=value>  Override'`n'  -m, --model <MODEL>  Model'`n'  -s, --sandbox <MODE>  Sandbox'`n'      --json  JSONL'`n"
        $codexPreview=Invoke-Runner2 @('-Provider','codex','-AgentPath',$fakeCodex,'-Model','m1','-AllowCustomModel','-Effort','high','-MaxTasks','1')
        $codexArgs=@($codexPreview.data.arguments) -join ' '
        Assert-Runner ($codexPreview.code -eq 0 -and $codexPreview.data.provider -eq 'codex' -and $codexArgs -ceq 'exec --json --sandbox workspace-write --model m1 --config model_reasoning_effort="high" -') ('-Provider codex builds the headless arguments from the probed help: '+$codexArgs)
        Assert-Runner ((@($codexPreview.data.omitted) -join ',') -ceq '--skip-git-repo-check' -and $codexPreview.err -match 'skip-git-repo-check') 'a flag missing from the installed help is omitted and reported'
        $badModel=Invoke-Runner2 @('-Provider','codex','-AgentPath',$fakeCodex,'-Model','m1','-MaxTasks','1')
        Assert-Runner ($badModel.code -eq 2 -and $badModel.err -match 'AllowCustomModel') ('an unknown model stops before any run with the next step: '+$badModel.text)
    }finally{$env:CODEX_HOME=$savedCodexHome}
    $stopFile=Join-Path $fixture 'stop.flag';Put-Runner $stopFile 'stop'
    $stopped=Invoke-Runner2 @('-Run','-AgentPath',$fake,'-AgentArguments','ok','-MaxTasks','2','-StopFile',$stopFile,'-Events')
    Assert-Runner ($stopped.code -eq 0 -and $stopped.data.stopReason -eq 'requested' -and @($stopped.data.tasks).Count -eq 0) ('an existing stop file ends the run before the next task: '+$stopped.text)
    $events=@($stopped.err -split "`r?`n"|Where-Object {$_.Trim()}|ForEach-Object {$_|ConvertFrom-Json -AsHashtable})
    Assert-Runner (@($events|Where-Object {$_.event -eq 'repo'}).Count -eq 1 -and @($events|Where-Object {$_.event -eq 'stop' -and $_.reason -eq 'requested'}).Count -eq 1 -and @($events|Where-Object {!$_.message}).Count -eq 0) ('-Events writes one JSON object per progress line: '+$stopped.err)
    Assert-Runner ((Get-SBFileHash $trackerPath2) -ceq $hash2) 'queue previews and a stopped run leave the tracker unchanged'
    # Queue default selection (#517): the window preselects nothing, so no consent-gated task starts without an explicit choice.
    $orchMain=Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\app\orchestrator\src\main.ts') -Raw
    Assert-Runner ($orchMain -match 'state\.selected\s*=\s*new Set<string>\(\);' -and $orchMain -notmatch 'state\.selected\s*=\s*new Set\(state\.tasks') 'orchestrator queue preselects no task'
    Close-RunnerPhase 'orchestrator'
    $realAfter=Get-RealTrackerHashes
    # The real trackers may legitimately change during this long run (parallel Full suites, a pending queue integrated by a read, the session
    # itself): a plain before/after hash comparison failed intermittently (#460). The guard checks the actual risk instead: every real tracker
    # that changed or appeared must be free of this fixture's identity and task IDs, so the runner never wrote to the real brain.
    $changedReal=@($realAfter.Keys|Where-Object {!$realBefore.Contains($_) -or $realAfter[$_] -cne $realBefore[$_]})
    $contaminated=@($changedReal|Where-Object {(Read-SBText $_) -match ([regex]::Escape($identity)+'|"id"\s*:\s*"(R|X)-\d"')})
    Assert-Runner ($contaminated.Count -eq 0) ('real trackers free of runner fixture data ('+$realAfter.Count+' hashed, '+$changedReal.Count+' changed concurrently, 0 contaminated)')
    Close-RunnerPhase 'final'
    'PHASES RUNNER: '+(@($script:phases.Keys|ForEach-Object {$_+'='+$script:phases[$_]+'s'}) -join ', ')
    'SUCCESS RUNNER: '+$script:runnerChecks+' checks; retained fixture '+$fixture
} finally {
    foreach($name in $envNames){Remove-Item -LiteralPath ('Env:'+$name) -ErrorAction SilentlyContinue}
}
