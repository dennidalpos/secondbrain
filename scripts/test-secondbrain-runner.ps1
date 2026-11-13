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
        @{id='R-5';priority='P3';execution='autonomous';stream='evoluzione-team'},
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
        $ext=@{stream=$spec.stream};if($spec.ContainsKey('awaiting')){$ext.awaiting=$spec.awaiting};if($spec.ContainsKey('requires')){$ext.requires=$spec.requires};$task.extensions=$ext
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
# The runner talks UTF-8 on stdin and stdout, like the real agent CLIs.
[Console]::InputEncoding=[Text.UTF8Encoding]::new($false);[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
$prompt=[Console]::In.ReadToEnd()
$id=if($prompt -match 'SOLO il task (\S+)'){$Matches[1]}else{''}
function Set-FakeInProgress([string]$Reason){
    & pwsh -NoProfile -File (Join-Path $env:SB_RUNNER_FAKE_BRAIN 'scripts/knowledge.ps1') -ConfigPath $env:SB_RUNNER_FAKE_CONFIG -CheckoutPath (Get-Location).Path -UpdateTaskId $id -Status in_progress -StateReason $Reason|Out-Null
    if($LASTEXITCODE){[Console]::Error.WriteLine('update failed');exit 5}
}
switch($Mode){
    # Streaming (Claude Code stream-json shape): init, a tool step and a text step, a pause long enough for status.json to be read, then the result.
    'stream' {
        [Console]::Out.WriteLine((@{type='system';subtype='init';model='fake-model'}|ConvertTo-Json -Compress));[Console]::Out.Flush()
        [Console]::Out.WriteLine((@{type='assistant';message=@{content=@(@{type='tool_use';name='Read';input=@{file_path='src/app.ts'}})}}|ConvertTo-Json -Compress -Depth 6));[Console]::Out.Flush()
        Start-Sleep -Seconds 4
        [Console]::Out.WriteLine((@{type='assistant';message=@{content=@(@{type='text';text="Analisi completata`nseconda riga"})}}|ConvertTo-Json -Compress -Depth 6));[Console]::Out.Flush()
        Set-FakeInProgress 'Fake agent stream'
        [Console]::Out.WriteLine((@{type='result';subtype='success';is_error=$false;result='streamed è ok'}|ConvertTo-Json -Compress));exit 0
    }
    # Silent for 9 seconds, then a normal answer: with a short -StallMinutes the runner reports one possible stall and still finishes.
    'quiet' {Start-Sleep -Seconds 9;Set-FakeInProgress 'Fake agent quiet';[Console]::Out.Write((@{type='result';is_error=$false;result='late'}|ConvertTo-Json -Compress));exit 0}
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
        $r=[ordered]@{repository=$env:SECONDBRAIN_RUNNER_REPOSITORY}
        $r.all=Probe (@('-Tasks','-All')+$c)
        $r.allDossiers=Probe (@('-Search','Context','-AllDossiers')+$c)
        $r.own=Probe (@('-Tasks')+$c)
        $r.notAllowed=Probe (@('-Tasks','-Repository','github.com/test/runner2')+$c)
        $r.notAllowedSearch=Probe (@('-Search','Context','-Repository','github.com/test/runner2')+$c)
        $r.foreignCheckout=Probe @('-Tasks','-ConfigPath',$env:SB_RUNNER_FAKE_CONFIG,'-CheckoutPath',$env:SB_RUNNER_FAKE_CHECKOUT2)
        $r.foreignWrite=Probe @('-UpdateTaskId','S-1','-Status','in_progress','-ConfigPath',$env:SB_RUNNER_FAKE_CONFIG,'-CheckoutPath',$env:SB_RUNNER_FAKE_CHECKOUT2)
        & pwsh -NoProfile -File $k -UpdateTaskId $id -Status in_progress -StateReason 'Fake agent guard' @c|Out-Null
        if($LASTEXITCODE){[Console]::Error.WriteLine('update failed');exit 5}
        [Console]::Out.Write((@{type='result';is_error=$false;result=($r|ConvertTo-Json -Compress -Depth 4)}|ConvertTo-Json -Compress));exit 0
    }
    'quota' {[Console]::Out.Write((@{type='result';is_error=$true;result='Claude AI usage limit reached|usage_limit_reached'}|ConvertTo-Json -Compress));exit 1}
    # Quota words in the agent's own text and in a failure: not a limit (only the final error envelope counts).
    'quotawords' {
        [Console]::Out.WriteLine((@{type='assistant';message=@{content=@(@{type='text';text='Checked the quota code: usage limit reached, rate limit, RESOURCE_EXHAUSTED'})}}|ConvertTo-Json -Compress -Depth 6))
        [Console]::Out.Write((@{type='result';is_error=$false;result='quota handling reviewed'}|ConvertTo-Json -Compress));[Console]::Error.WriteLine('synthetic failure');exit 2
    }
    # Real Claude Code shape of a limit: a rejected rate_limit_event with its reset, the task left in progress, an error result with the typographic apostrophe.
    'quotarl' {
        $reset=[DateTimeOffset]::UtcNow.AddHours(2).ToUnixTimeSeconds()
        [Console]::Out.WriteLine((@{type='rate_limit_event';rate_limit_info=@{status='rejected';resetsAt=$reset;rateLimitType='five_hour'}}|ConvertTo-Json -Compress -Depth 4));[Console]::Out.Flush()
        Set-FakeInProgress 'Fake agent quota'
        [Console]::Out.Write((@{type='result';is_error=$true;result=('You'+[char]0x2019+'ve hit your limit · resets 5pm')}|ConvertTo-Json -Compress));exit 1
    }
    # Echoes the prompt and fails: the task stays todo and the prompt can be checked.
    'echofail' {[Console]::Out.Write((@{type='result';is_error=$false;result=$prompt}|ConvertTo-Json -Compress));exit 2}
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
        if($i -ge 0){try{$data=$text.Substring($i)|ConvertFrom-Json -AsHashtable}catch { Write-Verbose $_.Exception.Message }}
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
    # Unattended start needs an explicit model and effort read now from the probe (or -UseCliDefault): a CLI that accepts both is refused without them.
    $choiceCli=Join-Path $fixture 'agent/claude.ps1'
    Put-Runner $choiceCli ("if(`$args -contains '--version'){'4.5.6 (Claude Code)';exit 0}`n"+
        "if(`$args -contains '--help'){`"Options:``n  --model <model>  Model for the session``n  --effort <level>  Effort level (low, high)``n  --output-format <format>  Output format`";exit 0}`nexit 9`n")
    $hashChoice=Get-SBFileHash $trackerPath
    $noChoiceText=(& pwsh -NoProfile -File $runner -CheckoutPath $checkout -ConfigPath $configPath -AgentPath $choiceCli -Run -MaxTasks 1 2>&1|Out-String);$noChoiceCode=$LASTEXITCODE
    Assert-Runner ($noChoiceCode -eq 2 -and $noChoiceText -match 'UseCliDefault' -and $noChoiceText -match 'low, high') ('-Run without model and effort is refused with the choices read now: '+$noChoiceText)
    Assert-Runner ((Get-SBFileHash $trackerPath) -ceq $hashChoice) 'the refused start runs no agent and writes nothing to the tracker'
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
    Assert-Runner ($quota.text -match 'Quota claude: unknown') ('the quota is read before the task and an unknown state proceeds: '+$quota.text)
    # False positives: quota words in the agent text and a plain failure are a failure, not a quota stop.
    $words=Invoke-Runner @('-Run','-MaxTasks','1','-AgentArguments','quotawords')
    Assert-Runner ($words.code -eq 1 -and $null -eq $words.data.stopReason -and @($words.data.tasks)[0].state -eq 'finished' -and @($words.data.tasks)[0].exitCode -eq 2) ('quota words outside the error envelope do not stop the run: '+$words.text)
    # A real limit: rejected rate_limit_event and error result; the interrupted task goes back to todo and resume.json keeps the queue.
    $limited=Invoke-Runner @('-Run','-MaxTasks','3','-AgentArguments','quotarl')
    $limitedRecord=@($limited.data.tasks)[0]
    Assert-Runner ($limited.data.stopReason -eq 'quota' -and $limitedRecord.state -eq 'quota' -and $limitedRecord.statusAfter -eq 'todo' -and $limitedRecord.requeued) ('a limit stops the run and puts the task back to todo: '+$limited.text)
    $limitedFolder=Split-Path $limited.data.status -Parent
    $point=Read-SBJson (Join-Path $limitedFolder 'resume.json') $null
    Assert-Runner ($point -and $point.reason -eq 'quota' -and $point.interrupted.id -eq $limitedRecord.id -and (@($point.remaining) -join ',') -ceq 'R-2,R-3,R-4' -and $point.quota.state -eq 'exhausted' -and $point.quota.resetAt) ('resume.json names the interrupted task, the remaining queue and the reset: '+($point|ConvertTo-Json -Compress -Depth 5))
    # The next run reads the observed exhaustion (reset in the future) and does not start any agent.
    $refused=Invoke-Runner @('-Run','-MaxTasks','1','-AgentArguments','ok')
    Assert-Runner ($refused.data.stopReason -eq 'quota' -and @($refused.data.tasks).Count -eq 0 -and $refused.text -match 'Quota claude: exhausted') ('an exhausted quota with a future reset stops before starting: '+$refused.text)
    # Reset reached: drop the observations, then resume the stopped run by name; the interrupted task runs first with the resume note.
    foreach($s in @(Get-ChildItem -LiteralPath $runtime -Recurse -Filter 'status.json' -File)){$j=Read-SBText $s.FullName|ConvertFrom-Json -AsHashtable;if($j.ContainsKey('quotaObserved')){$j.quotaObserved=$null;Put-Runner $s.FullName (ConvertTo-SBJson $j)}}
    $resumed=Invoke-Runner @('-Run','-MaxTasks','1','-AgentArguments','echofail','-Resume',(Split-Path $limitedFolder -Leaf))
    $resumedRecord=@($resumed.data.tasks)[0]
    $resumedPrompt=(Read-SBJson (Join-Path $resumedRecord.folder 'agent-output.json') $null).result
    Assert-Runner ($resumedRecord.id -eq $limitedRecord.id -and $resumedPrompt -match 'Ripresa:' -and $resumedPrompt -match [regex]::Escape($limitedRecord.folder)) ('-Resume runs the interrupted task first with the resume note: '+$resumed.text)
    Assert-Runner ((Read-SBJson (Join-Path $limitedFolder 'resume.json') $null).resumedBy) 'the resume point is marked as used'
    # The limit case wrote the tracker through the agent and the requeue: the following checks start from this state.
    $hash=Get-SBFileHash $trackerPath

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
    # Read-scope guard (#382, #475): the runner passes the task repository to the agent; global reads, foreign repositories and writes outside the task repository are refused in code.
    $hash2=Get-SBFileHash $trackerPath2
    $guard=Invoke-Runner @('-Run','-MaxTasks','1','-AgentArguments','guard')
    $guardRecord=@($guard.data.tasks)[0]
    Assert-Runner ($guard.code -eq 0 -and $guardRecord.id -eq 'R-5' -and $guardRecord.statusAfter -eq 'in_progress') ('guard run finishes: '+$guard.text)
    $probe=(Read-SBJson (Join-Path $guardRecord.folder 'agent-output.json') $null).result|ConvertFrom-Json -AsHashtable
    Assert-Runner ($probe.repository -ceq $identity) ('the agent session receives the task repository: '+($probe|ConvertTo-Json -Compress -Depth 4))
    $scopeText='runner session|sessione del runner'
    Assert-Runner ($probe.all.code -eq 2 -and $probe.all.text -match $scopeText) ('-All is refused in a runner session: '+$probe.all.text)
    Assert-Runner ($probe.allDossiers.code -eq 2 -and $probe.allDossiers.text -match $scopeText) ('-AllDossiers is refused in a runner session: '+$probe.allDossiers.text)
    Assert-Runner ($probe.notAllowed.code -eq 2 -and $probe.notAllowed.text -match $scopeText -and $probe.notAllowedSearch.code -eq 2 -and $probe.notAllowedSearch.text -match $scopeText) ('another repository is refused for reads: '+$probe.notAllowed.text)
    Assert-Runner ($probe.foreignCheckout.code -eq 2 -and $probe.foreignCheckout.text -match $scopeText) ('-CheckoutPath of another repository is refused: '+$probe.foreignCheckout.text)
    Assert-Runner ($probe.foreignWrite.code -eq 2 -and $probe.foreignWrite.text -match $scopeText -and (Get-SBFileHash $trackerPath2) -ceq $hash2) ('a write to another repository is refused and its tracker unchanged: '+$probe.foreignWrite.text)
    Assert-Runner ($probe.own.code -eq 0) 'the task repository stays readable'
    # MCP tools in a runner session, in a separate process so the variables never reach this test: global views and foreign repositories refused.
    $mcpProbe=Join-Path $fixture 'agent/mcp-probe.ps1'
    Put-Runner $mcpProbe @'
param([string]$Brain,[string]$Config,[string]$Checkout)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $Brain 'scripts/SecondBrain.Mcp.psm1')
$env:SECONDBRAIN_CONFIG=$Config
Set-Location -LiteralPath $Checkout
function Probe($Tool,$Arguments){try{[void](Invoke-SBMcpToolCall $Brain $Tool $Arguments);'ok'}catch{'refused: '+$_.Exception.Message}}
$r=[ordered]@{}
$r.userAll=Probe 'get_ready_tasks' @{all=$true}
$r.userSearch=Probe 'search_knowledge' @{query='Context';allDossiers=$true}
$env:SECONDBRAIN_RUNNER_REPOSITORY='github.com/test/runner'
$r.all=Probe 'get_ready_tasks' @{all=$true}
$r.allDossiers=Probe 'search_knowledge' @{query='Context';allDossiers=$true}
$r.notAllowed=Probe 'get_ready_tasks' @{repository='github.com/test/runner2'}
$r.foreignWrite=Probe 'preview_dossier_write' @{repository='github.com/test/runner2';checkoutPath='x';requestId=('0'*32);operation='task.status';payload=@{taskId='S-1';status='done'}}
$r|ConvertTo-Json -Compress
'@
    # Project isolation has no switch (#475): global views and unscoped searches are always refused, for a person and for the runner.
    $isolated=(& pwsh -NoProfile -File (Join-Path $brain 'scripts/knowledge.ps1') -Tasks -All -ConfigPath $configPath -CheckoutPath $checkout 2>&1|Out-String)
    Assert-Runner ($LASTEXITCODE -ne 0 -and $isolated -match 'Isolamento per progetto|Project isolation') ('-All is refused by project isolation: '+$isolated)
    $isolatedSearch=(& pwsh -NoProfile -File (Join-Path $brain 'scripts/knowledge.ps1') -Search 'Context' -AllDossiers -ConfigPath $configPath -CheckoutPath $checkout 2>&1|Out-String)
    Assert-Runner ($LASTEXITCODE -ne 0 -and $isolatedSearch -match 'Isolamento per progetto|Project isolation') ('-AllDossiers is refused by project isolation: '+$isolatedSearch)
    $mcp=(& pwsh -NoProfile -File $mcpProbe -Brain $brain -Config $configPath -Checkout $checkout 2>&1|Out-String)
    $mcpResult=$mcp.Substring($mcp.IndexOf('{'))|ConvertFrom-Json -AsHashtable
    Assert-Runner ($mcpResult.userAll -match 'Isolamento per progetto|Project isolation' -and $mcpResult.userSearch -match 'Isolamento per progetto|Project isolation') ('outside a runner session MCP all=true and allDossiers=true are refused by isolation: '+$mcp)
    Assert-Runner ($mcpResult.all -match $scopeText -and $mcpResult.allDossiers -match $scopeText) ('MCP all=true and allDossiers=true are refused in a runner session: '+$mcp)
    Assert-Runner ($mcpResult.notAllowed -match $scopeText -and $mcpResult.foreignWrite -match $scopeText) ('MCP reads and writes stay in the task repository: '+$mcp)
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
    # An unedited launcher from the earlier template (no model choice) is outdated and replaced; the rebuild must match the hash the installer knows.
    $current=Read-SBText $launcher2
    $earlier=$current.Replace("-Run also needs the choice the runner asks for: -Model and -Effort, or -UseCliDefault. -Provider, -Model, -Effort, -UseCliDefault and`n-AllowCustomModel are passed to the runner unchanged.`n",'').
        Replace("  pwsh -NoProfile -File .secondbrain/run-tasks.ps1                                   # preview`n  pwsh -NoProfile -File .secondbrain/run-tasks.ps1 -MaxTasks 1 -Run -UseCliDefault   # run the next task with the CLI defaults",
            "  pwsh -NoProfile -File .secondbrain/run-tasks.ps1                    # preview`n  pwsh -NoProfile -File .secondbrain/run-tasks.ps1 -MaxTasks 1 -Run   # run the next task").
        Replace("param([int]`$MaxTasks=3,[ValidateRange(1,240)][int]`$TimeoutMinutes=30,[ValidateSet('claude','codex','gemini')][string]`$Provider,`n    [string]`$Model,[string]`$Effort,[switch]`$UseCliDefault,[switch]`$AllowCustomModel,[switch]`$Run)",
            "param([int]`$MaxTasks=3,[ValidateRange(1,240)][int]`$TimeoutMinutes=30,[switch]`$Run)").
        Replace("foreach(`$name in @('Provider','Model','Effort')){if(`$PSBoundParameters.ContainsKey(`$name)){`$arguments+=@('-'+`$name,[string]`$PSBoundParameters[`$name])}}`nforeach(`$name in @('UseCliDefault','AllowCustomModel','Run')){if(`$PSBoundParameters.ContainsKey(`$name) -and `$PSBoundParameters[`$name]){`$arguments+=('-'+`$name)}}",
            "if(`$Run){`$arguments+='-Run'}")
    Put-Runner $launcher2 $earlier
    $outdated=Invoke-Installer @('-Repository',$identity2)
    Assert-Runner (@($outdated.data.repositories|Where-Object {$_.state -eq 'outdated' -and !$_.written}).Count -eq 1) ('an unedited earlier launcher is reported as outdated: '+$outdated.text)
    $updated=Invoke-Installer @('-Apply','-Repository',$identity2)
    Assert-Runner (@($updated.data.repositories|Where-Object {$_.state -eq 'outdated' -and $_.written}).Count -eq 1 -and (Get-SBFileHash $launcher2) -ceq $updated.data.templateSha256) ('-Apply replaces an outdated launcher with the template: '+$updated.text)
    Close-RunnerPhase 'installer'
    # The launcher runs the runner for its own checkout only, found through SECONDBRAIN_HOME.
    $savedHome=$env:SECONDBRAIN_HOME
    try {
        $env:SECONDBRAIN_HOME=$brain
        $lines=@(& pwsh -NoProfile -File $launcher2 -MaxTasks 10 2>&1|ForEach-Object {[string]$_})
        $code=$LASTEXITCODE;$text=$lines -join "`n";$i=$text.IndexOf('{');$data=$text.Substring($i)|ConvertFrom-Json -AsHashtable
        Assert-Runner ($code -eq 0 -and !$data.run -and (@($data.tasks|ForEach-Object id) -join ',') -ceq 'S-1,S-2') ('the launcher previews only its own repository tasks: '+$text)
        Assert-Runner (@($data.tasks|Where-Object {$_.prompt -notmatch 'Strumenti SecondBrain in '}).Count -eq 0) 'prompts launched from a product checkout name the SecondBrain tools and the checkout'
        # Model choice and agent options reach the runner unchanged (a stand-in runner echoes its arguments).
        $echoHome=Join-Path $fixture 'launcher-echo-home'
        Put-Runner (Join-Path $echoHome 'scripts/run-ready-tasks.ps1') "ConvertTo-Json -Compress @(`$args)`n"
        $env:SECONDBRAIN_HOME=$echoHome
        $echo=(& pwsh -NoProfile -File $launcher2 -MaxTasks 1 -Provider codex -Model m1 -Effort low -AllowCustomModel -Run 2>&1|Out-String)|ConvertFrom-Json
        Assert-Runner ((@($echo) -join ' ') -match '-Provider codex -Model m1 -Effort low -AllowCustomModel -Run$') ('the launcher forwards provider, model, effort and -Run: '+(@($echo) -join ' '))
        $echo=@((& pwsh -NoProfile -File $launcher2 -UseCliDefault -Run 2>&1|Out-String)|ConvertFrom-Json)
        Assert-Runner ('-UseCliDefault' -in $echo -and '-Run' -in $echo -and '-Model' -notin $echo) ('the launcher forwards -UseCliDefault: '+($echo -join ' '))
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
    # Live monitoring: streamed agent steps, status.json and events.jsonl while the agent works, one runner per repository, stall notice, runner-status.ps1.
    Import-Module (Join-Path $PSScriptRoot 'SecondBrain.RunnerStatus.psm1') -Force
    $codexLine='{"type":"item.started","item":{"id":"i1","type":"command_execution","command":"npm test"}}'
    $e=ConvertTo-SBAgentEvent $codexLine
    Assert-Runner ($e.kind -eq 'tool' -and $e.summary -ceq 'shell: npm test') ('Codex JSONL command becomes a tool step: '+($e|ConvertTo-Json -Compress))
    $e=ConvertTo-SBAgentEvent '{"type":"tool_use","tool_name":"read_file","parameters":{"path":"a.md"}}'
    Assert-Runner ($e.kind -eq 'tool' -and $e.summary -ceq 'read_file: a.md') 'Gemini stream-json tool step'
    $e=ConvertTo-SBAgentEvent '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Write","input":{"file_path":"x.ts","content":"SECRET-CONTENT"}}]}}'
    Assert-Runner ($e.summary -ceq 'Write: x.ts' -and $e.summary -notmatch 'SECRET') 'a tool step names the path, never the written content'
    Assert-Runner ((ConvertTo-SBAgentEvent '{"type":"result","is_error":true,"subtype":"error_max_turns"}').kind -eq 'error' -and $null -eq (ConvertTo-SBAgentEvent '{"type":"user"}') -and (ConvertTo-SBAgentEvent 'plain text line').kind -eq 'text') 'result errors, silent events and plain text are classified'
    Assert-Runner ((Get-SBAgentFinalOutput ("{`"type`":`"system`"}`n{`"type`":`"result`",`"result`":`"r`"}`n")) -ceq '{"type":"result","result":"r"}') 'the final output of a stream is its result line'
    $nowUtc=[DateTimeOffset]::UtcNow
    $fresh=@{state='running';phase='agent';updatedAt=$nowUtc.ToString('o');stallMinutes=1;lastAgentEventAt=$nowUtc.AddSeconds(-30).ToString('o')}
    Assert-Runner ((Get-SBRunnerVerdict $fresh $nowUtc $true) -eq 'working' -and (Get-SBRunnerVerdict $fresh $nowUtc $false) -eq 'orphaned') 'verdict: alive and recent is working, dead is orphaned'
    $fresh.lastAgentEventAt=$nowUtc.AddSeconds(-90).ToString('o')
    Assert-Runner ((Get-SBRunnerVerdict $fresh $nowUtc $true) -eq 'stalled') 'verdict: silent agent past the stall threshold is stalled'
    $fresh.phase='flush';$fresh.updatedAt=$nowUtc.AddSeconds(-120).ToString('o')
    Assert-Runner ((Get-SBRunnerVerdict $fresh $nowUtc $true) -eq 'stalled' -and (Get-SBRunnerVerdict @{state='finished'} $nowUtc $true) -eq 'finished') 'verdict: a missed heartbeat is stalled, a closed run finished'
    # A live runner (this test process) blocks a second run on the same repository; a dead one is marked orphaned and the run proceeds.
    $reportRoot=Get-SBRunnerReportRoot $brain $hostId $identity2
    $ghost=Join-Path $reportRoot '20000101-runner-run-000000-1'
    Put-Runner (Join-Path $ghost 'status.json') (ConvertTo-SBJson @{schemaVersion=1;state='running';phase='agent';pid=$PID;processStartTicks=(Get-SBProcessStartTicks $PID);repository=$identity2;updatedAt=[DateTimeOffset]::UtcNow.ToString('o')})
    $runsBefore=@(Get-ChildItem -LiteralPath $reportRoot -Directory -Filter '*-runner-run-*').Count
    $busy=Invoke-Runner2 @('-Run','-AgentPath',$fake,'-AgentArguments','stream','-TaskIds','S-1')
    Assert-Runner ($busy.code -eq 2 -and $busy.err -match 'runner-status' -and @(Get-ChildItem -LiteralPath $reportRoot -Directory -Filter '*-runner-run-*').Count -eq $runsBefore) ('a second runner on the same repository is refused: '+$busy.text)
    Put-Runner (Join-Path $ghost 'status.json') (ConvertTo-SBJson @{schemaVersion=1;state='running';phase='agent';pid=2147483000;repository=$identity2;updatedAt='2000-01-01T00:00:00Z'})
    (Get-Item -LiteralPath (Join-Path $ghost 'status.json')).LastWriteTimeUtc=[DateTime]::UtcNow.AddDays(-1)
    $statusScript=Join-Path $brain 'scripts/runner-status.ps1'
    $streamOut=Join-Path $fixture 'stream.out';$streamErr=Join-Path $fixture 'stream.err'
    $streamProcess=Start-Process -FilePath (Get-Process -Id $PID).Path -ArgumentList @('-NoProfile','-File',$runner,'-CheckoutPath',$checkout2,'-ConfigPath',$configPath,'-AgentPath',$fake,'-AgentArguments','stream','-TaskIds','S-1','-Run','-Events') -RedirectStandardOutput $streamOut -RedirectStandardError $streamErr -PassThru -NoNewWindow
    $live=$null;$deadline=(Get-Date).AddSeconds(90)
    while(!$streamProcess.HasExited -and (Get-Date) -lt $deadline){
        $probeLive=(& pwsh -NoProfile -File $statusScript -CheckoutPath $checkout2 -ConfigPath $configPath -Tail 50 2>$null|Out-String)
        if($probeLive.Contains('{')){$candidate=$probeLive.Substring($probeLive.IndexOf('{'))|ConvertFrom-Json -AsHashtable;if($candidate.verdict -eq 'working' -and $candidate.status.lastAgentEvent -and $candidate.status.lastAgentEvent.kind -in @('tool','text')){$live=$candidate;break}}
        Start-Sleep -Milliseconds 500
    }
    $streamProcess.WaitForExit();$streamCode=$streamProcess.ExitCode
    Assert-Runner ($live -and $live.active -and $live.status.phase -eq 'agent' -and $live.status.task.id -eq 'S-1' -and $live.status.lastAgentEvent.summary -cin @('Read: src/app.ts','Analisi completata') -and @($live.events|Where-Object {$_.event -eq 'agent' -and $_.summary -ceq 'Read: src/app.ts'}).Count -eq 1 -and $null -ne $live.ages.agentEvent) ('runner-status sees the working agent and its last step while it runs: '+($live|ConvertTo-Json -Compress -Depth 6))
    Assert-Runner (@($live.events|Where-Object {$_.event -eq 'agent' -and $_.kind -eq 'start'}).Count -eq 1) 'the session start is an agent event in events.jsonl'
    $streamData=(Get-Content -LiteralPath $streamOut -Raw);$streamData=$streamData.Substring($streamData.IndexOf('{'))|ConvertFrom-Json -AsHashtable
    $streamEvents=@(Get-Content -LiteralPath $streamErr|Where-Object {$_.Trim().StartsWith('{')}|ForEach-Object {$_|ConvertFrom-Json -AsHashtable})
    $agentEvents=@($streamEvents|Where-Object {$_.event -eq 'agent'})
    Assert-Runner ($streamCode -eq 0 -and @($streamData.tasks)[0].state -eq 'finished' -and (@($agentEvents|ForEach-Object kind) -join ',') -ceq 'start,tool,text,result') ('-Events carries the agent steps in order: '+(@($agentEvents|ForEach-Object {$_.kind+'='+$_.summary}) -join ' | '))
    Assert-Runner (@($agentEvents|Where-Object {$_.kind -eq 'text'})[0].summary -ceq 'Analisi completata') 'a text step keeps only its first line'
    $streamFolder=@($streamData.tasks)[0].folder
    Assert-Runner (@(Get-Content -LiteralPath (Join-Path $streamFolder 'agent-output.jsonl')|Where-Object {$_}).Count -eq 4 -and (Read-SBJson (Join-Path $streamFolder 'agent-output.json') $null).result -ceq 'streamed è ok') 'agent-output.jsonl keeps the stream, agent-output.json the UTF-8 result line'
    $finalStatus=Read-SBJson ([string]$streamData.status) $null
    Assert-Runner ($finalStatus.state -eq 'finished' -and $finalStatus.phase -eq 'closed' -and $finalStatus.counts.succeeded -eq 1 -and (Read-SBJson (Join-Path (Split-Path ([string]$streamData.status)) 'MANIFEST.json') $null).status -eq 'closed') ('status.json ends finished and the run folder is closed: '+($finalStatus|ConvertTo-Json -Compress -Depth 4))
    Assert-Runner ((Read-SBJson (Join-Path $ghost 'status.json') $null).state -eq 'orphaned') 'the dead runner status is marked orphaned'
    $after=(& pwsh -NoProfile -File $statusScript -CheckoutPath $checkout2 -ConfigPath $configPath 2>$null|Out-String);$after=$after.Substring($after.IndexOf('{'))|ConvertFrom-Json -AsHashtable
    Assert-Runner ($after.verdict -eq 'finished' -and !$after.active) ('runner-status reports the finished run: '+$after.verdict)
    & pwsh -NoProfile -File $statusScript -CheckoutPath $checkout2 -ConfigPath $configPath -Stop *>$null
    Assert-Runner ($LASTEXITCODE -eq 2) 'runner-status -Stop without an active run exits 2'
    $quiet=Invoke-Runner2 @('-Run','-AgentPath',$fake,'-AgentArguments','quiet','-TaskIds','S-2','-StallMinutes','0.1','-Events')
    $quietEvents=@($quiet.err -split "`r?`n"|Where-Object {$_.Trim().StartsWith('{')}|ForEach-Object {$_|ConvertFrom-Json -AsHashtable})
    Assert-Runner ($quiet.code -eq 0 -and @($quietEvents|Where-Object {$_.event -eq 'stalled'}).Count -eq 1 -and @($quiet.data.tasks)[0].state -eq 'finished') ('a silent agent raises one stall notice and is not killed: '+$quiet.err)
    Close-RunnerPhase 'monitor'
    # runner-gui.ps1 (sb runner): binary path and rebuild decision on a fake app with a fake binary; -WhatIf/-NoLaunch, never a real build.
    $guiApp=Join-Path $fixture 'gui-app'
    $guiBin=Join-Path $guiApp ('src-tauri/target/release/secondbrain-orchestrator'+$(if($IsWindows){'.exe'}else{''}))
    foreach($f in 'src/main.ts','index.html','package.json','package-lock.json','src-tauri/src/main.rs','src-tauri/Cargo.toml','src-tauri/tauri.conf.json'){Put-Runner (Join-Path $guiApp $f) 'x'}
    $past=[DateTime]::UtcNow.AddHours(-2)
    Get-ChildItem -LiteralPath $guiApp -Recurse -File|ForEach-Object {$_.LastWriteTimeUtc=$past}
    $guiScript=Join-Path $PSScriptRoot 'runner-gui.ps1'
    function Invoke-Gui([string[]]$GuiArguments){$t=(& pwsh -NoProfile -File $guiScript -AppPath $guiApp @GuiArguments 2>&1|Out-String);$i=$t.IndexOf('{');@{code=$LASTEXITCODE;text=$t;data=$(if($i -ge 0){$t.Substring($i)|ConvertFrom-Json -AsHashtable}else{$null})}}
    $g=Invoke-Gui @('-WhatIf')
    Assert-Runner ($g.code -eq 0 -and $g.data.reason -eq 'missing' -and $g.data.build -and !$g.data.built -and !$g.data.launched -and $g.data.binary -eq $guiBin) ('runner-gui: a missing binary needs a build: '+$g.text)
    Put-Runner $guiBin 'fake binary'
    $g=Invoke-Gui @('-WhatIf')
    Assert-Runner ($g.code -eq 0 -and $g.data.reason -eq 'current' -and !$g.data.build) ('runner-gui: a binary newer than its sources is current: '+$g.text)
    $g=Invoke-Gui @('-NoLaunch')
    Assert-Runner ($g.code -eq 0 -and $g.data.reason -eq 'current' -and !$g.data.built -and !$g.data.launched) ('runner-gui -NoLaunch on a current binary does nothing: '+$g.text)
    $g=Invoke-Gui @('-WhatIf','-Rebuild')
    Assert-Runner ($g.data.reason -eq 'forced' -and $g.data.build) '-Rebuild forces the build'
    (Get-Item -LiteralPath (Join-Path $guiApp 'src-tauri/src/main.rs')).LastWriteTimeUtc=[DateTime]::UtcNow.AddHours(1)
    $g=Invoke-Gui @('-WhatIf')
    Assert-Runner ($g.data.reason -eq 'stale' -and $g.data.newestSource -eq 'src-tauri/src/main.rs') ('runner-gui: a newer Rust source makes the binary stale: '+$g.text)
    $savedPath=$env:PATH
    try{$env:PATH='';$g=(& (Get-Process -Id $PID).Path -NoProfile -File $guiScript -AppPath $guiApp -NoLaunch 2>&1|Out-String);$gcode=$LASTEXITCODE}finally{$env:PATH=$savedPath}
    Assert-Runner ($gcode -eq 2 -and $g -match 'orchestratore') ('runner-gui without npm/cargo stops with exit 2 and the guide: '+$g)
    $g=Invoke-Gui @('-WhatIf','-RepositoryPath',$checkout2)
    Assert-Runner ($g.code -eq 0 -and $g.data.repository -eq [IO.Path]::GetFullPath($checkout2)) ('runner-gui records the repository passed to the app: '+$g.text)
    if($IsWindows){
        # Outside the caller's package and job (WMI): a file that is not a program is refused by Win32_Process.Create; a real program
        # (whoami.exe standing in for the app, which exits 0 at once without arguments) starts with its own PID and is reported as
        # launched through WMI.
        (Get-Item -LiteralPath $guiBin).LastWriteTimeUtc=[DateTime]::UtcNow.AddHours(2)
        $g=Invoke-Gui @('-LaunchMethod','wmi','-RepositoryPath',$checkout2)
        Assert-Runner ($g.code -eq 5 -and $g.text -match 'Win32_Process\.Create') ('runner-gui -LaunchMethod wmi reports a binary that cannot start: '+$g.text)
        $savedBin=[IO.File]::ReadAllBytes($guiBin)
        try{
            Copy-Item -LiteralPath (Join-Path ([Environment]::SystemDirectory) 'whoami.exe') -Destination $guiBin -Force
            (Get-Item -LiteralPath $guiBin).LastWriteTimeUtc=[DateTime]::UtcNow.AddHours(2)
            $g=Invoke-Gui @('-LaunchMethod','wmi')
            Assert-Runner ($g.code -eq 0 -and $g.data.launched -and $g.data.launchMethod -eq 'wmi' -and $g.data.pid -gt 0 -and $g.data.pid -ne $PID) ('runner-gui -LaunchMethod wmi starts the app outside the caller: '+$g.text)
            # whoami rejects --repo and exits 1: the arguments reach the app and its early exit code is read across WMI.
            $g=Invoke-Gui @('-LaunchMethod','wmi','-RepositoryPath',$checkout2)
            Assert-Runner ($g.code -eq 5 -and $g.text -match 'exit 1') ('runner-gui -LaunchMethod wmi reports an app that exits with an error at once: '+$g.text)
            $g=Invoke-Gui @('-LaunchMethod','shell')
            Assert-Runner ($g.code -eq 0 -and $g.data.launched -and $g.data.launchMethod -eq 'shell' -and $g.data.Contains('inJob')) ('runner-gui -LaunchMethod shell keeps ShellExecute and reports the containment: '+$g.text)
        }finally{[IO.File]::WriteAllBytes($guiBin,$savedBin);(Get-Item -LiteralPath $guiBin).LastWriteTimeUtc=[DateTime]::UtcNow.AddHours(2)}
    }
    # sb runner (runner.ps1): desktop by default, command-line fallback with the preview when the app cannot open, explicit modes.
    (Get-Item -LiteralPath $guiBin).LastWriteTimeUtc=[DateTime]::UtcNow.AddHours(2)
    $dispatcher=Join-Path $brain 'scripts/runner.ps1'
    function Invoke-Dispatcher([string[]]$DispatchArguments){$t=(& pwsh -NoProfile -File $dispatcher -AppPath $guiApp -RepositoryPath (Join-Path $checkout2 '.') -ConfigPath $configPath @DispatchArguments 2>&1|Out-String);$i=$t.IndexOf('{');@{code=$LASTEXITCODE;text=$t;data=$(if($i -ge 0){$t.Substring($i)|ConvertFrom-Json -AsHashtable}else{$null})}}
    $cli=Invoke-Dispatcher @('-Mode','cli')
    Assert-Runner ($cli.code -eq 0 -and $cli.data.mode -eq 'cli' -and $null -eq $cli.data.gui -and $cli.data.repository -eq [IO.Path]::GetFullPath($checkout2) -and $cli.data.preview.run -eq $false -and $cli.data.next -match '-Run') ('runner.ps1 -Mode cli prints the preview of the checkout root and the next command: '+$cli.text)
    if($IsWindows){
        # The fake binary cannot start: auto falls back to the command line, gui reports the failure.
        $auto=Invoke-Dispatcher @()
        Assert-Runner ($auto.code -eq 0 -and $auto.data.mode -eq 'cli' -and $auto.data.fallbackReason -eq 'launch-failed' -and $auto.data.preview.run -eq $false -and !$auto.data.launched) ('runner.ps1 falls back to the command line when the app does not start: '+$auto.text)
        $guiOnly=Invoke-Dispatcher @('-Mode','gui')
        Assert-Runner ($guiOnly.code -eq 2 -and $guiOnly.data.mode -eq 'gui' -and $guiOnly.data.fallbackReason -eq 'launch-failed' -and $null -eq $guiOnly.data.preview) ('runner.ps1 -Mode gui reports the failure without fallback: '+$guiOnly.text)
    }
    Close-RunnerPhase 'runner-gui'
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
