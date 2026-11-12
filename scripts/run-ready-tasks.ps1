#requires -Version 7.5
<#
.SYNOPSIS
Runs ready autonomous tracker tasks one at a time, each in a fresh agent session, for one checkout or for the managed repositories.
.DESCRIPTION
Default is a preview: it lists the tasks that would run and the prompt each session receives, and changes nothing.
-Run starts one agent process per task (prompt on stdin, so no shell quoting), sequentially, with a timeout. Output and a report go in a
work folder created with work.ps1 (category report). Only todo tasks with execution=autonomous outside the final-qualification,
on-request and product-coordination streams are selected. The prompt forbids commit, push, publication, deletion and SYS05.
The agent writes to the dossier through its own coordinated session; this script writes the tracker only to park a released task that ends still todo as user_required.
The script handles one repository only: the checkout given with -CheckoutPath (default: the current directory), whose own dossier and tracker are resolved from its Git identity.
Each repository carries its own thin launcher (.secondbrain/run-tasks.ps1, installed with scripts/install-task-launcher.ps1) that calls this script for that checkout only.
When the checkout is not the SecondBrain checkout, the agent starts inside it and its prompt names the SecondBrain tools to use. -MaxTasks 0 = no limit.
Quota exhaustion or three consecutive failures stop the run.
Progress lines (selection, start and end of every task, the agent's steps, a heartbeat each minute, summary) go to standard error; standard output carries only the final JSON, so redirecting it to a file keeps the console readable.
Live monitoring: with -Run the agent output is read line by line while it works (stream-json for Claude Code and Gemini CLI when the
installed CLI offers it, JSONL for Codex) and kept in agent-output.jsonl; each step becomes an "agent" progress line. A run work folder
(report/<date>-runner-run-<time>-<pid>) holds status.json (process, phase, current task, last runner and agent events, rewritten at least
every 15 s) and events.jsonl; scripts/runner-status.ps1 and the MCP tool get_runner_status read them. No agent output for -StallMinutes
(default 5) raises one "stalled" line; the timeout stays the only kill. One runner per repository: a second -Run on the same repository
is refused while the first is alive. The stop file (default stop.flag in the run folder) ends the run before the next task.
-Provider claude|codex|gemini picks the agent CLI (default claude) and builds its headless arguments with the fixed permission profile
(file edits in the checkout, no git history changes, no deletion); -Model and -Effort are validated against scripts/agents.ps1 -Probe
(-AllowCustomModel accepts a model the probe does not list). -AgentPath and -AgentArguments stay as an advanced override.
-TaskIds runs only the named ready tasks, in the given order, after the same selection rules. -Events writes progress as one JSON
object per line on standard error (for the desktop orchestrator). -StopFile <path> ends the run before the next task when the file exists.
#>
[CmdletBinding()]
param([string]$CheckoutPath='.',[int]$MaxTasks=3,[ValidateRange(1,240)][int]$TimeoutMinutes=30,
    [ValidateSet('claude','codex','gemini')][string]$Provider='claude',[string]$Model,[string]$Effort,[switch]$AllowCustomModel,
    [string]$AgentPath,[string[]]$AgentArguments,[string[]]$TaskIds,[switch]$Events,[string]$StopFile,
    [ValidateRange(0.05,240)][double]$StallMinutes=5,[string]$ConfigPath,[switch]$Run)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.TaskRunner.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.ComputerUse.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.AgentAdapters.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.RunnerStatus.psm1')
# -AgentPath alone keeps the provider adapter; -AgentArguments replaces the adapter arguments entirely (advanced override, no validation).
$customArguments=$PSBoundParameters.ContainsKey('AgentArguments')
if(!$AgentPath){$AgentPath=(Get-SBAgentProvider $Provider).command}
$TaskIds=@($TaskIds|ForEach-Object {[string]$_ -split '[,;]'}|ForEach-Object {$_.Trim()}|Where-Object {$_})
# Preflight from the IDE capability table: tasks that require computer use run only when this agent has a documented, present pre-approval.
$allowComputerUse=Test-SBAgentUnattendedComputerUse $AgentPath
Add-SBMessages @{
    'runner.agent.missing' = @{it='Agente non trovato: {0}. Passa -AgentPath con un percorso valido o installa l agente';en='Agent not found: {0}. Pass -AgentPath with a valid path or install the agent'}
    'runner.none' = @{it='Nessun task eseguibile in autonomia';en='No task can run autonomously'}
    'runner.busy' = @{it='Un runner e gia attivo su questo repository (PID {0}, cartella {1}). Seguilo con scripts/runner-status.ps1 -Follow o fermalo con -Stop';en='A runner is already active on this repository (PID {0}, folder {1}). Follow it with scripts/runner-status.ps1 -Follow or stop it with -Stop'}
    'runner.progress.repo' = @{it='Repository {0} ({1}/{2}): selezione dei task';en='Repository {0} ({1}/{2}): selecting tasks'}
    'runner.progress.selected' = @{it='  {0} task eseguibili su {1} pronti';en='  {0} runnable tasks out of {1} ready'}
    'runner.progress.skip' = @{it='  Repository saltato: {0}';en='  Repository skipped: {0}'}
    'runner.progress.status' = @{it='Stato del run: {0}';en='Run status: {0}'}
    'runner.progress.start' = @{it='[{0}/{1}] #{2} {3}: avvio dell agente';en='[{0}/{1}] #{2} {3}: starting the agent'}
    'runner.progress.agent' = @{it='  #{0} {1}: {2}';en='  #{0} {1}: {2}'}
    'runner.progress.stalled' = @{it='  #{0}: nessun segnale dall agente da {1} min (possibile stallo; interruzione solo al limite di {2} min)';en='  #{0}: no signal from the agent for {1} min (possible stall; it is stopped only at the {2} min limit)'}
    'runner.progress.tick' = @{it='  ... #{0} in corso da {1} s (limite {2} min)';en='  ... #{0} running for {1} s (limit {2} min)'}
    'runner.progress.done' = @{it='[{0}/{1}] #{2}: {3}, uscita {4}, stato {5} -> {6}, {7} s';en='[{0}/{1}] #{2}: {3}, exit {4}, status {5} -> {6}, {7} s'}
    'runner.progress.stop' = @{it='Arresto del giro: {0}';en='Run stopped: {0}'}
    'runner.progress.summary' = @{it='Riepilogo: {0} eseguiti, {1} riusciti, {2} non riusciti, {3} repository saltati';en='Summary: {0} run, {1} succeeded, {2} failed, {3} repositories skipped'}
    'runner.progress.preview' = @{it='Anteprima: {0} task eseguibili in {1} repository (nessuna modifica; usa -Run per eseguirli)';en='Preview: {0} runnable tasks in {1} repositories (no change; use -Run to execute them)'}
    'runner.progress.omitted' = @{it='  Opzioni non disponibili nella CLI installata e omesse: {0}';en='  Options missing from the installed CLI and left out: {0}'}
}
$utf8=[Text.UTF8Encoding]::new($false)
# Live run state (status.json and events.jsonl in the run work folder); $null until -Run creates the folder.
$script:runStatus=$null;$script:runStatusPath=$null;$script:runEventsPath=$null;$script:lastStatusSave=[datetime]::MinValue;$script:statusDirty=$false
function Save-RunnerState([switch]$Force,[int]$MinimumSeconds=0){
    # Rewrites status.json: always with -Force, otherwise when the heartbeat (or the given minimum interval) has passed.
    # A change skipped by the interval stays pending (dirty) and is written within a second by the wait loop.
    if(!$script:runStatus){return}
    $since=((Get-Date)-$script:lastStatusSave).TotalSeconds
    $limit=if($MinimumSeconds -gt 0){$MinimumSeconds}elseif($script:statusDirty){1}else{Get-SBRunnerHeartbeatSeconds}
    if(!$Force -and $since -lt $limit){if($MinimumSeconds -gt 0){$script:statusDirty=$true};return}
    try{Save-SBRunnerStatus $script:runStatusPath $script:runStatus;$script:lastStatusSave=Get-Date;$script:statusDirty=$false}catch{[void]$_}
}
function Set-RunnerPhase([string]$Phase){if($script:runStatus){$script:runStatus.phase=$Phase;Save-RunnerState -Force}}
# Progress goes to standard error so that `> file` keeps only the final JSON while the console still shows the advance.
# With -Events each line is one JSON object (event name from the message key, the message and its data) for the desktop orchestrator.
# Every event also goes to events.jsonl and refreshes status.json once the run folder exists.
function Show-RunnerLine([string]$Key,[object[]]$Arguments=@(),$Data,[switch]$Agent){
    $text=Get-SBMessage $Key $Arguments
    $now=[DateTimeOffset]::UtcNow.ToString('o')
    $event=[ordered]@{event=($Key -replace '^runner\.(progress\.)?','');message=$text;time=$now}
    if($Data){foreach($k in $Data.Keys){$event[$k]=$Data[$k]}}
    if($Events){[Console]::Error.WriteLine(($event|ConvertTo-Json -Compress -Depth 8))}else{[Console]::Error.WriteLine($text)}
    if($script:runStatus){
        try{Add-SBRunnerEventLine $script:runEventsPath $event}catch{[void]$_}
        if($Agent){
            $script:runStatus.lastAgentEventAt=$now
            $script:runStatus.lastAgentEvent=[ordered]@{kind=$Data.kind;summary=$Data.summary;time=$now}
            Save-RunnerState -MinimumSeconds 2
        }else{$script:runStatus.lastRunnerEventAt=$now;Save-RunnerState -Force}
    }
}
function Initialize-RunnerInvocation{
    # Adapter arguments from the probe of the installed CLI (validated model and effort); an unprobed custom agent keeps every flag.
    $script:capabilities=$null;$script:omitted=@()
    if($customArguments){return}
    if($Run -or $Model -or $Effort){
        $script:capabilities=Get-SBAgentCapabilities -Provider $Provider -AgentPath $AgentPath
        try{[void](Test-SBAgentSelection $script:capabilities $Model $Effort -AllowCustomModel:$AllowCustomModel)}catch{[Console]::Error.WriteLine($_.Exception.Message);Close-RunnerState 'failed';exit 2}
    }
    $invocation=New-SBAgentInvocation -Provider $Provider -Capabilities $script:capabilities -Model $Model -Effort $Effort
    $script:AgentArguments=@($invocation.arguments);$script:omitted=@($invocation.omitted)
    if($script:omitted.Count){Show-RunnerLine 'runner.progress.omitted' @(($script:omitted -join ', ')) @{omitted=$script:omitted}}
}
function Close-RunnerState([string]$State){
    # Final status of the run and closure of its work folder (the retention clock starts).
    if(!$script:runStatus){return}
    $script:runStatus.state=$State;$script:runStatus.phase='closed';$script:runStatus.finishedAt=[DateTimeOffset]::UtcNow.ToString('o')
    Save-RunnerState -Force
    try{& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'work.ps1') -Repository $script:runStatus.repository -Category report -Slug $script:runSlug -Close @configArgs|Out-Null}catch{[void]$_}
    $script:runStatus=$null
}
function Invoke-Json([string[]]$ScriptArgs){
    $out=(& pwsh -NoProfile -File @ScriptArgs 2>&1|Out-String)
    $i=$out.IndexOfAny([char[]]@('[','{'))
    if($i -lt 0 -or $LASTEXITCODE -ne 0){throw $out}
    $out.Substring($i)|ConvertFrom-Json
}
function Invoke-RunnerChild([string[]]$ScriptArgs){
    # A SecondBrain CLI that can wait (the writer lock of -FlushPending): started as a process so status.json keeps its heartbeat meanwhile.
    $start=[Diagnostics.ProcessStartInfo]::new((Get-Process -Id $PID).Path);$start.UseShellExecute=$false;$start.CreateNoWindow=$true
    $start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
    foreach($a in @('-NoProfile','-File')+$ScriptArgs){$start.ArgumentList.Add($a)}
    $p=[Diagnostics.Process]::Start($start)
    try{
        $o=$p.StandardOutput.ReadToEndAsync();$e=$p.StandardError.ReadToEndAsync()
        while(!$p.WaitForExit(1000)){Save-RunnerState}
        [void]$o.GetAwaiter().GetResult();[void]$e.GetAwaiter().GetResult()
        $p.ExitCode
    }finally{$p.Dispose()}
}
$configArgs=if($ConfigPath){@('-ConfigPath',$ConfigPath)}else{@()}
$knowledge=Join-Path $PSScriptRoot 'knowledge.ps1'
if(!$Run){Initialize-RunnerInvocation}
# One repository only: the given checkout. When it is not the SecondBrain checkout, prompts carry the absolute SecondBrain tool paths.
$targets=@(@{identity=$null;path=[IO.Path]::GetFullPath($CheckoutPath)});$skipped=@()
$sbRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')).TrimEnd('\','/')
$external=![string]::Equals($sbRoot,$targets[0].path.TrimEnd('\','/'),[StringComparison]::OrdinalIgnoreCase)
function Read-RunnerTasks($Target,$Index,$Count){
    # One CLI call lists the ready tasks and the tracker source; details come from reading that tracker once (read-only), with the CLI as fallback.
    $checkout=$Target.path
    if(!(Test-Path -LiteralPath $checkout)){return @{skip='checkout-missing'}}
    try{$list=@(Invoke-Json (@($knowledge,'-Tasks','-ReadyOnly','-CheckoutPath',$checkout)+$configArgs))}catch{return @{skip='no-active-dossier'}}
    # Unverified trackers come back as diagnostic entries without seq: they are not tasks and are skipped.
    $ready=@($list|Where-Object {$_.PSObject.Properties['seq'] -and $null -ne $_.seq})
    $byId=@{}
    $source=@($ready|Where-Object {$_.PSObject.Properties['source'] -and $_.source}|Select-Object -First 1)
    if($source.Count -eq 1){
        # Objects, not the hashtables of Read-SBJson: selection reads PSObject properties, the same shape as the CLI fallback (#376).
        $tracker=$null
        try{if(Test-Path -LiteralPath ([string]$source[0].source)){$tracker=Read-SBText ([string]$source[0].source)|ConvertFrom-Json}}catch{$tracker=$null}
        if($tracker -and $tracker.PSObject.Properties['tasks']){foreach($t in @($tracker.tasks)){$byId[[string]$t.id]=$t}}
    }
    $detail=@()
    foreach($r in $ready){
        if($byId.ContainsKey([string]$r.id)){$detail+=$byId[[string]$r.id]}
        else{$detail+=(Invoke-Json (@($knowledge,'-Task',[string]$r.seq,'-CheckoutPath',$checkout)+$configArgs)).task}
    }
    # Ready tasks left out are reported with a reason: the runner filters (status, execution, stream, awaiting) or the -MaxTasks cut.
    $excluded=@(Get-SBRunnerExclusions $detail -AllowComputerUse:$allowComputerUse)
    $all=Select-SBRunnableTasks $detail 0 -AllowComputerUse:$allowComputerUse
    $picked=Select-SBRunnableTasks $detail $MaxTasks -AllowComputerUse:$allowComputerUse
    if($TaskIds.Count){
        # Explicit queue: the named runnable tasks in the given order; the others are reported as not queued, unknown IDs as not ready.
        $byRunnable=@{};foreach($t in @($all)){$byRunnable[[string]$t.id]=$t}
        $queued=@($TaskIds|Where-Object {$byRunnable.ContainsKey($_)}|ForEach-Object {$byRunnable[$_]})
        $excluded=@($excluded|Where-Object {[string]$_.id -in $TaskIds})
        $known=@(@($detail)|ForEach-Object {[string]$_.id})
        foreach($id in $TaskIds){if($id -notin $known){$excluded+=,[ordered]@{id=$id;seq=$null;reason='not-ready'}}}
        foreach($t in @($all)){if([string]$t.id -notin $TaskIds){$excluded+=,[ordered]@{id=[string]$t.id;seq=$t.seq;reason='not-queued'}}}
        $all=$queued
        $picked=if($MaxTasks -gt 0){@($queued|Select-Object -First $MaxTasks)}else{$queued}
    }
    $pickedIds=@($picked|ForEach-Object {[string]$_.id})
    foreach($t in $all){if([string]$t.id -notin $pickedIds){$excluded+=,[ordered]@{id=[string]$t.id;seq=$t.seq;reason='max-tasks'}}}
    @{tasks=$picked;excluded=$excluded;ready=$ready.Count;source=$(if($source.Count -eq 1){[string]$source[0].source}else{$null})}
}
function Resolve-RunnerIdentity($Plan,$Task){
    $repo=$Task.PSObject.Properties['repository']
    $identity=if($Plan.target.identity){$Plan.target.identity}elseif($repo){$repo.Value}else{$null}
    if(!$identity){$identity=(Invoke-Json (@($knowledge,'-Task',[string]$Task.seq,'-CheckoutPath',$Plan.target.path)+$configArgs)).repository}
    [string]$identity
}
$plans=@();$repoIndex=0;$totalSelected=0
foreach($target in $targets){
    $repoIndex++
    $label=if($target.identity){$target.identity}else{$target.path}
    Show-RunnerLine 'runner.progress.repo' @($label,$repoIndex,$targets.Count)
    $read=Read-RunnerTasks $target $repoIndex $targets.Count
    if($read.ContainsKey('skip')){
        Show-RunnerLine 'runner.progress.skip' @("$label ($($read.skip))")
        $skipped+=,[ordered]@{repository=$label;reason=$read.skip};continue
    }
    $selected=@($read.tasks)
    foreach($x in @($read.excluded)){$skipped+=,[ordered]@{repository=$label;id=$x.id;seq=$x.seq;reason=$x.reason}}
    Show-RunnerLine 'runner.progress.selected' @($selected.Count,$read.ready)
    if($selected.Count -gt 0){$plans+=,@{target=$target;tasks=$selected;source=$read.source};$totalSelected+=$selected.Count}
}
if($totalSelected -eq 0){ConvertTo-SBJson @{run=$false;message=(Get-SBMessage 'runner.none');tasks=@();skipped=$skipped};exit 0}
if(!$Run){
    $preview=@()
    foreach($p in $plans){foreach($t in $p.tasks){
        $prompt=if($external){New-SBTaskRunPrompt $t $PSScriptRoot $p.target.path}else{New-SBTaskRunPrompt $t}
        $preview+=,[ordered]@{repository=$p.target.identity;id=$t.id;seq=$t.seq;priority=$t.priority;title=$t.title;prompt=$prompt}
    }}
    Show-RunnerLine 'runner.progress.preview' @($totalSelected,$plans.Count)
    ConvertTo-SBJson @{run=$false;agent=$AgentPath;provider=$Provider;model=$Model;effort=$Effort;arguments=@($AgentArguments);omitted=$omitted;computerUse=$allowComputerUse;timeoutMinutes=$TimeoutMinutes;tasks=$preview;skipped=$skipped};exit 0
}
# Run folder and status before the probe, so a monitor sees the run from its first second; one runner per repository.
$runIdentity=Resolve-RunnerIdentity $plans[0] $plans[0].tasks[0]
$config=Read-SBConfiguration $ConfigPath
$active=Find-SBActiveRunner $config.brainRoot $config.workstationId $runIdentity
if($active){[Console]::Error.WriteLine((Get-SBMessage 'runner.busy' @($active.status.pid,(Split-Path $active.path -Parent))));exit 2}
$script:runSlug=Get-SBRunnerRunSlug
$runFolder=(Invoke-Json (@((Join-Path $PSScriptRoot 'work.ps1'),'-Repository',$runIdentity,'-Category','report','-Slug',$script:runSlug,'-Init','-Task','Run del runner')+$configArgs)).root
if(!$StopFile){$StopFile=Join-Path $runFolder 'stop.flag'}
$script:runStatusPath=Join-Path $runFolder 'status.json';$script:runEventsPath=Join-Path $runFolder 'events.jsonl'
$script:runStatus=[ordered]@{
    schemaVersion=1;runId=(Split-Path $runFolder -Leaf);state='running';phase='probe';pid=$PID;processStartTicks=(Get-SBProcessStartTicks $PID)
    repository=$runIdentity;checkout=$targets[0].path;provider=$Provider;model=$Model;effort=$Effort
    startedAt=[DateTimeOffset]::UtcNow.ToString('o');updatedAt=$null;finishedAt=$null;lastRunnerEventAt=$null;lastAgentEventAt=$null;lastAgentEvent=$null
    timeoutMinutes=$TimeoutMinutes;stallMinutes=$StallMinutes;stopFile=$StopFile;folder=$runFolder
    task=$null;counts=[ordered]@{total=$totalSelected;done=0;succeeded=0;failed=0};stopReason=$null;results=@()
}
Show-RunnerLine 'runner.progress.status' @($script:runStatusPath) @{status=$script:runStatusPath;folder=$runFolder;stopFile=$StopFile}
$runState='failed'
try{
Initialize-RunnerInvocation
$resolved=Resolve-SBAgentExecutable $AgentPath
if(!$resolved){[Console]::Error.WriteLine((New-SBError 'runner.agent.missing' $AgentPath).Message);exit 2}
# Prefer a real executable or .cmd shim; a .ps1 shim (npm) cannot be started directly, so it is wrapped in pwsh -File.
$agent=$resolved.path;$agentPrefix=@($resolved.prefix)
$agentProcessPath=Get-SBAgentProcessPath (Split-Path -Parent $agent)
$results=@();$consecutiveFailures=0;$stopReason=$null;$position=0
foreach($plan in $plans){
    $checkout=$plan.target.path
    foreach($task in $plan.tasks){
        if($StopFile -and (Test-Path -LiteralPath $StopFile)){$stopReason='requested';break}
        $position++
        Set-RunnerPhase 'init'
        $identity=Resolve-RunnerIdentity $plan $task
        $slug="runner-$($task.seq)"
        $folder=Invoke-Json (@((Join-Path $PSScriptRoot 'work.ps1'),'-Repository',$identity,'-Category','report','-Slug',$slug,'-Init','-Task',"Run autonomo $($task.id)")+$configArgs)
        $root=$folder.root
        $began=Get-Date
        $script:runStatus.task=[ordered]@{id=[string]$task.id;seq=$task.seq;title=[string]$task.title;position=$position;total=$totalSelected;startedAt=[DateTimeOffset]::UtcNow.ToString('o');folder=$root}
        $script:runStatus.lastAgentEventAt=$null;$script:runStatus.lastAgentEvent=$null;$script:runStatus.phase='agent'
        Show-RunnerLine 'runner.progress.start' @($position,$totalSelected,$task.seq,$(if($plan.target.identity){$plan.target.identity}else{[string]$task.id})) @{position=$position;total=$totalSelected;id=[string]$task.id;seq=$task.seq;title=[string]$task.title;folder=$root}
        $start=[Diagnostics.ProcessStartInfo]::new($agent);$start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.WorkingDirectory=$checkout
        $start.RedirectStandardInput=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
        # UTF-8 both ways: the Italian prompt reaches the agent intact and its JSON comes back without code-page damage.
        $start.StandardInputEncoding=$utf8;$start.StandardOutputEncoding=$utf8;$start.StandardErrorEncoding=$utf8
        foreach($a in ($agentPrefix+$AgentArguments)){$start.ArgumentList.Add($a)}
        $start.Environment['PATH']=$agentProcessPath
        # Session perimeter enforced in code (#382): knowledge.ps1 and the MCP tools started by the agent refuse global reads and foreign repositories.
        $scopeVariables=Get-SBRunnerScopeVariables
        $start.Environment[$scopeVariables.repository]=[string]$identity
        $prompt=if($external){New-SBTaskRunPrompt $task $PSScriptRoot $checkout}else{New-SBTaskRunPrompt $task}
        $process=[Diagnostics.Process]::Start($start);$state='finished';$code=$null
        $outBuilder=[Text.StringBuilder]::new();$errBuilder=[Text.StringBuilder]::new()
        $outLog=[IO.StreamWriter]::new((Join-Path $root 'agent-output.jsonl'),$false,$utf8)
        try{
            $process.StandardInput.Write($prompt);$process.StandardInput.Close()
            # Line-by-line reading in one-second slices: every agent line is kept at once, summarized as a progress line and counted as activity.
            $outRead=$process.StandardOutput.ReadLineAsync();$errRead=$process.StandardError.ReadLineAsync()
            $outDone=$false;$errDone=$false;$lastActivity=Get-Date;$stallReported=$false;$nextTick=60;$exitedAt=$null
            while($true){
                $progress=$false
                while(!$outDone -and $outRead.IsCompleted){
                    $line=$outRead.GetAwaiter().GetResult()
                    if($null -eq $line){$outDone=$true;break}
                    [void]$outBuilder.AppendLine($line);$outLog.WriteLine($line);$outLog.Flush()
                    $lastActivity=Get-Date;$progress=$true
                    $ev=ConvertTo-SBAgentEvent $line
                    if($ev){Show-RunnerLine 'runner.progress.agent' @($task.seq,$ev.kind,$ev.summary) @{id=[string]$task.id;seq=$task.seq;kind=$ev.kind;summary=$ev.summary} -Agent}
                    $outRead=$process.StandardOutput.ReadLineAsync()
                }
                while(!$errDone -and $errRead.IsCompleted){
                    $line=$errRead.GetAwaiter().GetResult()
                    if($null -eq $line){$errDone=$true;break}
                    [void]$errBuilder.AppendLine($line);$lastActivity=Get-Date;$progress=$true
                    $errRead=$process.StandardError.ReadLineAsync()
                }
                if($progress -and $stallReported){$stallReported=$false;$script:runStatus.phase='agent'}
                if($process.HasExited){
                    if($outDone -and $errDone){break}
                    # A grandchild that inherited the pipes can keep them open after the agent exits: stop waiting after five seconds.
                    if(!$exitedAt){$exitedAt=Get-Date}elseif(((Get-Date)-$exitedAt).TotalSeconds -ge 5){break}
                }
                $elapsed=((Get-Date)-$began).TotalSeconds
                if($elapsed -ge $TimeoutMinutes*60){$process.Kill($true);$process.WaitForExit();$state='timeout';break}
                if($elapsed -ge $nextTick){Show-RunnerLine 'runner.progress.tick' @($task.seq,[int]$elapsed,$TimeoutMinutes) @{id=[string]$task.id;seconds=[int]$elapsed};$nextTick+=60}
                $silent=((Get-Date)-$lastActivity).TotalMinutes
                if(!$stallReported -and $silent -ge $StallMinutes){
                    $stallReported=$true
                    Show-RunnerLine 'runner.progress.stalled' @($task.seq,[math]::Round($silent,1),$TimeoutMinutes) @{id=[string]$task.id;minutes=[math]::Round($silent,1)}
                }
                Save-RunnerState
                if(!$progress){Start-Sleep -Milliseconds 250}
            }
            if($state -eq 'finished'){$process.WaitForExit();$code=$process.ExitCode}
            $outText=$outBuilder.ToString();$errText=$errBuilder.ToString()
            # agent-output.json keeps the final answer (the stream-json result line, or the whole output of a non-streaming CLI).
            [IO.File]::WriteAllText((Join-Path $root 'agent-output.json'),(Get-SBAgentFinalOutput $outText),$utf8)
            [IO.File]::WriteAllText((Join-Path $root 'agent-error.txt'),$errText,$utf8)
        }finally{$outLog.Dispose();$process.Dispose()}
        $finalText=Get-SBAgentFinalOutput $outText
        # A negative exit code is an operating-system crash of the agent (e.g. 0xC0000409) and an empty answer with exit 0 carries no result: neither counts as finished.
        if($state -eq 'finished'){
            if($code -lt 0){$state='crashed'}elseif($code -eq 0 -and [string]::IsNullOrWhiteSpace($outText)){$state='no-output'}
        }
        # Concurrent runners on other repositories can leave this task's dossier writes deferred: apply them now, waiting for the writer lock, so the status read below is current.
        Set-RunnerPhase 'flush'
        try{[void](Invoke-RunnerChild (@($knowledge,'-FlushPending','-CheckoutPath',$checkout)+$configArgs))}catch{[void]$_}
        $statusAfter=$null
        if($plan.source){$tr=Read-SBJson $plan.source $null;if($tr){$hit=@($tr.tasks|Where-Object {[string]$_.id -eq [string]$task.id});if($hit.Count -eq 1){$statusAfter=$hit[0].status}}}
        if(!$statusAfter){
            # An archived task is gone from the active tracker; the CLI still resolves it.
            $statusAfter=(Invoke-Json (@($knowledge,'-Task',[string]$task.seq,'-CheckoutPath',$checkout)+$configArgs)).task.status
        }
        $record=[ordered]@{repository=$identity;id=$task.id;seq=$task.seq;state=$state;exitCode=$code;statusBefore=$task.status;statusAfter=$statusAfter;seconds=[int]((Get-Date)-$began).TotalSeconds;folder=$root}
        # A run that leaves the task todo made no progress: park it as user_required (the agent's reason stays) so the same limit is not repeated.
        $record.parked=$false
        if($state -eq 'finished' -and $code -eq 0 -and $statusAfter -eq 'todo'){
            try{[void](Invoke-Json (@($knowledge,'-UpdateTaskId',[string]$task.id,'-Execution','user_required','-CheckoutPath',$checkout)+$configArgs));$record.parked=$true}catch{$record.parked=$false}
        }
        # Stop the whole run when the plan quota is exhausted, or after three consecutive failures (no retry loops).
        # Classified before report.json is written, so the report and the run summary agree.
        if(($code -ne 0 -or (Test-SBAgentErrorOutput $finalText)) -and ($finalText+$errText) -match (Get-SBAgentQuotaPattern)){$record.state='quota';$stopReason='quota'}
        elseif($state -ne 'finished' -or $code -ne 0){$consecutiveFailures++}else{$consecutiveFailures=0}
        if($consecutiveFailures -ge 3){$stopReason='failures'}
        [IO.File]::WriteAllText((Join-Path $root 'report.json'),(ConvertTo-SBJson $record),$utf8)
        Set-RunnerPhase 'close'
        & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'work.ps1') -Repository $identity -Category report -Slug $slug -Close @configArgs|Out-Null
        $results+=$record
        $ok=($record.state -eq 'finished' -and $record.exitCode -eq 0)
        $script:runStatus.counts.done++;if($ok){$script:runStatus.counts.succeeded++}else{$script:runStatus.counts.failed++}
        $script:runStatus.results=@($script:runStatus.results)+@([ordered]@{id=[string]$record.id;seq=$record.seq;state=$record.state;folder=$root})
        $script:runStatus.task=$null
        Show-RunnerLine 'runner.progress.done' @($position,$totalSelected,$task.seq,$record.state,$code,$record.statusBefore,$record.statusAfter,$record.seconds) @{record=$record}
        if($stopReason){break}
    }
    if($stopReason){break}
}
$failed=@($results|Where-Object {$_.state -ne 'finished' -or $_.exitCode -ne 0}).Count
$script:runStatus.stopReason=$stopReason
if($stopReason){Show-RunnerLine 'runner.progress.stop' @($stopReason) @{reason=$stopReason}}
Show-RunnerLine 'runner.progress.summary' @($results.Count,($results.Count-$failed),$failed,@($skipped|Where-Object {!$_.Contains('id')}).Count)
$runState=if($stopReason -eq 'requested'){'stopped'}else{'finished'}
}finally{Close-RunnerState $runState}
ConvertTo-SBJson @{run=$true;provider=$Provider;model=$Model;effort=$Effort;stopReason=$stopReason;status=$script:runStatusPath;tasks=$results;skipped=$skipped}
exit $(if($failed -gt 0){1}else{0})
