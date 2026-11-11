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
Progress lines (selection, start and end of every task, a heartbeat each minute, summary) go to standard error; standard output carries only the final JSON, so redirecting it to a file keeps the console readable.
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
    [string]$ConfigPath,[switch]$Run)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.TaskRunner.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.ComputerUse.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.AgentAdapters.psm1')
# -AgentPath alone keeps the provider adapter; -AgentArguments replaces the adapter arguments entirely (advanced override, no validation).
$customArguments=$PSBoundParameters.ContainsKey('AgentArguments')
if(!$AgentPath){$AgentPath=(Get-SBAgentProvider $Provider).command}
$TaskIds=@($TaskIds|ForEach-Object {[string]$_ -split '[,;]'}|ForEach-Object {$_.Trim()}|Where-Object {$_})
# Preflight from the IDE capability table: tasks that require computer use run only when this agent has a documented, present pre-approval.
$allowComputerUse=Test-SBAgentUnattendedComputerUse $AgentPath
Add-SBMessages @{
    'runner.agent.missing' = @{it='Agente non trovato: {0}. Passa -AgentPath con un percorso valido o installa l agente';en='Agent not found: {0}. Pass -AgentPath with a valid path or install the agent'}
    'runner.none' = @{it='Nessun task eseguibile in autonomia';en='No task can run autonomously'}
    'runner.progress.repo' = @{it='Repository {0} ({1}/{2}): selezione dei task';en='Repository {0} ({1}/{2}): selecting tasks'}
    'runner.progress.selected' = @{it='  {0} task eseguibili su {1} pronti';en='  {0} runnable tasks out of {1} ready'}
    'runner.progress.skip' = @{it='  Repository saltato: {0}';en='  Repository skipped: {0}'}
    'runner.progress.start' = @{it='[{0}/{1}] #{2} {3}: avvio dell agente';en='[{0}/{1}] #{2} {3}: starting the agent'}
    'runner.progress.tick' = @{it='  ... #{0} in corso da {1} s (limite {2} min)';en='  ... #{0} running for {1} s (limit {2} min)'}
    'runner.progress.done' = @{it='[{0}/{1}] #{2}: {3}, uscita {4}, stato {5} -> {6}, {7} s';en='[{0}/{1}] #{2}: {3}, exit {4}, status {5} -> {6}, {7} s'}
    'runner.progress.stop' = @{it='Arresto del giro: {0}';en='Run stopped: {0}'}
    'runner.progress.summary' = @{it='Riepilogo: {0} eseguiti, {1} riusciti, {2} non riusciti, {3} repository saltati';en='Summary: {0} run, {1} succeeded, {2} failed, {3} repositories skipped'}
    'runner.progress.preview' = @{it='Anteprima: {0} task eseguibili in {1} repository (nessuna modifica; usa -Run per eseguirli)';en='Preview: {0} runnable tasks in {1} repositories (no change; use -Run to execute them)'}
    'runner.progress.omitted' = @{it='  Opzioni non disponibili nella CLI installata e omesse: {0}';en='  Options missing from the installed CLI and left out: {0}'}
}
# Progress goes to standard error so that `> file` keeps only the final JSON while the console still shows the advance.
# With -Events each line is one JSON object (event name from the message key, the message and its data) for the desktop orchestrator.
function Show-RunnerLine([string]$Key,[object[]]$Arguments=@(),$Data){
    $text=Get-SBMessage $Key $Arguments
    if($Events){
        $event=[ordered]@{event=($Key -replace '^runner\.(progress\.)?','');message=$text;time=[DateTimeOffset]::UtcNow.ToString('o')}
        if($Data){foreach($k in $Data.Keys){$event[$k]=$Data[$k]}}
        [Console]::Error.WriteLine(($event|ConvertTo-Json -Compress -Depth 8))
    }else{[Console]::Error.WriteLine($text)}
}
# Adapter arguments from the probe of the installed CLI (validated model and effort); an unprobed custom agent keeps every flag.
$capabilities=$null;$omitted=@()
if(!$customArguments){
    $needsProbe=[bool]($Run -or $Model -or $Effort)
    if($needsProbe){
        $capabilities=Get-SBAgentCapabilities -Provider $Provider -AgentPath $AgentPath
        try{[void](Test-SBAgentSelection $capabilities $Model $Effort -AllowCustomModel:$AllowCustomModel)}catch{[Console]::Error.WriteLine($_.Exception.Message);exit 2}
    }
    $invocation=New-SBAgentInvocation -Provider $Provider -Capabilities $capabilities -Model $Model -Effort $Effort
    $AgentArguments=@($invocation.arguments);$omitted=@($invocation.omitted)
}
if($omitted.Count){Show-RunnerLine 'runner.progress.omitted' @(($omitted -join ', ')) @{omitted=$omitted}}
function Invoke-Json([string[]]$ScriptArgs){
    $out=(& pwsh -NoProfile -File @ScriptArgs 2>&1|Out-String)
    $i=$out.IndexOfAny([char[]]@('[','{'))
    if($i -lt 0 -or $LASTEXITCODE -ne 0){throw $out}
    $out.Substring($i)|ConvertFrom-Json
}
$configArgs=if($ConfigPath){@('-ConfigPath',$ConfigPath)}else{@()}
$knowledge=Join-Path $PSScriptRoot 'knowledge.ps1'
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
if(!(Get-Command $AgentPath -ErrorAction SilentlyContinue)){[Console]::Error.WriteLine((New-SBError 'runner.agent.missing' $AgentPath).Message);exit 2}
# Prefer a real executable or .cmd shim; a .ps1 shim (npm) cannot be started directly, so it is wrapped in pwsh -File.
$resolved=Resolve-SBAgentExecutable $AgentPath
$agent=$resolved.path;$agentPrefix=@($resolved.prefix)
$results=@();$consecutiveFailures=0;$stopReason=$null;$position=0
foreach($plan in $plans){
    $checkout=$plan.target.path
    foreach($task in $plan.tasks){
        if($StopFile -and (Test-Path -LiteralPath $StopFile)){$stopReason='requested';break}
        $position++
        Show-RunnerLine 'runner.progress.start' @($position,$totalSelected,$task.seq,$(if($plan.target.identity){$plan.target.identity}else{[string]$task.id})) @{position=$position;total=$totalSelected;id=[string]$task.id;seq=$task.seq;title=[string]$task.title}
        $repo=$task.PSObject.Properties['repository']
        $identity=if($plan.target.identity){$plan.target.identity}elseif($repo){$repo.Value}else{$null}
        if(!$identity){$identity=(Invoke-Json (@($knowledge,'-Task',[string]$task.seq,'-CheckoutPath',$checkout)+$configArgs)).repository}
        $slug="runner-$($task.seq)"
        $folder=Invoke-Json (@((Join-Path $PSScriptRoot 'work.ps1'),'-Repository',$identity,'-Category','report','-Slug',$slug,'-Init','-Task',"Run autonomo $($task.id)")+$configArgs)
        $root=$folder.root
        $start=[Diagnostics.ProcessStartInfo]::new($agent);$start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.WorkingDirectory=$checkout
        $start.RedirectStandardInput=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
        foreach($a in ($agentPrefix+$AgentArguments)){$start.ArgumentList.Add($a)}
        # Session perimeter enforced in code (#382): knowledge.ps1 and the MCP tools started by the agent refuse global reads and foreign repositories.
        $scopeVariables=Get-SBRunnerScopeVariables
        $start.Environment[$scopeVariables.repository]=[string]$identity
        $prompt=if($external){New-SBTaskRunPrompt $task $PSScriptRoot $checkout}else{New-SBTaskRunPrompt $task}
        $began=Get-Date;$process=[Diagnostics.Process]::Start($start);$state='finished';$code=$null
        try{
            $outTask=$process.StandardOutput.ReadToEndAsync();$errTask=$process.StandardError.ReadToEndAsync()
            $process.StandardInput.Write($prompt);$process.StandardInput.Close()
            # Wait in one-second slices so the console shows a heartbeat every minute and the timeout is exact.
            $nextTick=60
            while(!$process.WaitForExit(1000)){
                $elapsed=((Get-Date)-$began).TotalSeconds
                if($elapsed -ge $TimeoutMinutes*60){$process.Kill($true);$process.WaitForExit();$state='timeout';break}
                if($elapsed -ge $nextTick){Show-RunnerLine 'runner.progress.tick' @($task.seq,[int]$elapsed,$TimeoutMinutes) @{id=[string]$task.id;seconds=[int]$elapsed};$nextTick+=60}
            }
            $code=$process.ExitCode
            $outText=$outTask.GetAwaiter().GetResult();$errText=$errTask.GetAwaiter().GetResult()
            [IO.File]::WriteAllText((Join-Path $root 'agent-output.json'),$outText,[Text.UTF8Encoding]::new($false))
            [IO.File]::WriteAllText((Join-Path $root 'agent-error.txt'),$errText,[Text.UTF8Encoding]::new($false))
        }finally{$process.Dispose()}
        # A negative exit code is an operating-system crash of the agent (e.g. 0xC0000409) and an empty answer with exit 0 carries no result: neither counts as finished.
        if($state -eq 'finished'){
            if($code -lt 0){$state='crashed'}elseif($code -eq 0 -and [string]::IsNullOrWhiteSpace($outText)){$state='no-output'}
        }
        # Concurrent runners on other repositories can leave this task's dossier writes deferred: apply them now, waiting for the writer lock, so the status read below is current.
        try{& pwsh -NoProfile -File $knowledge -FlushPending -CheckoutPath $checkout @configArgs *>$null}catch{[void]$_}
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
        if(($code -ne 0 -or (Test-SBAgentErrorOutput $outText)) -and ($outText+$errText) -match (Get-SBAgentQuotaPattern)){$record.state='quota';$stopReason='quota'}
        elseif($state -ne 'finished' -or $code -ne 0){$consecutiveFailures++}else{$consecutiveFailures=0}
        if($consecutiveFailures -ge 3){$stopReason='failures'}
        [IO.File]::WriteAllText((Join-Path $root 'report.json'),(ConvertTo-SBJson $record),[Text.UTF8Encoding]::new($false))
        & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'work.ps1') -Repository $identity -Category report -Slug $slug -Close @configArgs|Out-Null
        $results+=$record
        Show-RunnerLine 'runner.progress.done' @($position,$totalSelected,$task.seq,$record.state,$code,$record.statusBefore,$record.statusAfter,$record.seconds) @{record=$record}
        if($stopReason){break}
    }
    if($stopReason){break}
}
$failed=@($results|Where-Object {$_.state -ne 'finished' -or $_.exitCode -ne 0}).Count
if($stopReason){Show-RunnerLine 'runner.progress.stop' @($stopReason) @{reason=$stopReason}}
Show-RunnerLine 'runner.progress.summary' @($results.Count,($results.Count-$failed),$failed,@($skipped|Where-Object {!$_.Contains('id')}).Count)
ConvertTo-SBJson @{run=$true;provider=$Provider;model=$Model;effort=$Effort;stopReason=$stopReason;tasks=$results;skipped=$skipped}
exit $(if($failed -gt 0){1}else{0})