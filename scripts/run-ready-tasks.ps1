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
Quota exhaustion or three consecutive failures stop the run. The quota is read before the run and before every task (Get-SBAgentQuota:
Codex session files, else the last observation of this workstation): exhausted with a future reset stops before starting, unknown proceeds
until the agent reports the limit. The limit is recognized only in the agent's final error envelope with per-provider texts; a transient
rate limit is "throttled" and does not stop the run. A quota stop writes resume.json in the run folder (interrupted task, remaining queue),
puts the interrupted task back to todo when the agent left it in_progress, and -Resume <run folder name|latest> continues from there.
-Run needs an explicit choice read from the probe at that moment: -Model and -Effort (when the CLI accepts them), or -UseCliDefault.
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
    [ValidateRange(0.05,240)][double]$StallMinutes=5,[string]$ConfigPath,[switch]$UseCliDefault,[string]$Resume,[switch]$Run)
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
    'runner.selection.required' = @{it='Scegli modello e impegno prima di avviare: -Model <id> e -Effort <livello> (letti ora dalla CLI: modelli {0}; impegni {1}; predefiniti della CLI {2}/{3}), oppure -UseCliDefault per usare i predefiniti della CLI';en='Choose model and effort before starting: -Model <id> and -Effort <level> (read now from the CLI: models {0}; efforts {1}; CLI defaults {2}/{3}), or -UseCliDefault to use the CLI defaults'}
    'runner.resume.missing' = @{it='Nessun resume.json da riprendere per {0} in questo repository. Elenca i run con scripts/runner-status.ps1';en='No resume.json to resume for {0} in this repository. List the runs with scripts/runner-status.ps1'}
    'runner.progress.quota' = @{it='Quota {0}: {1} (fonte {2}{3})';en='Quota {0}: {1} (source {2}{3})'}
    'runner.progress.quotaexhausted' = @{it='Quota {0} esaurita fino a {1}: il run non parte. Riprendi dopo il ripristino con -Resume latest o da un altro account';en='Quota {0} exhausted until {1}: the run does not start. Resume after the reset with -Resume latest or from another account'}
    'runner.progress.limit' = @{it='  #{0}: limite rilevato ({1}): {2}';en='  #{0}: limit detected ({1}): {2}'}
    'runner.progress.resume' = @{it='Ripresa del run {0}: {1} task in coda, interrotto {2}';en='Resuming run {0}: {1} queued tasks, interrupted {2}'}
    'runner.progress.resumefile' = @{it='Punto di ripresa: {0} (riprendi con -Resume {1})';en='Resume point: {0} (resume with -Resume {1})'}
    'runner.progress.omitted' = @{it='  Opzioni non disponibili nella CLI installata e omesse: {0}';en='  Options missing from the installed CLI and left out: {0}'}
}
$utf8=[Text.UTF8Encoding]::new($false)
# Live run state (status.json and events.jsonl in the run work folder); $null until -Run creates the folder.
$script:runStatus=$null;$script:runStatusPath=$null;$script:runEventsPath=$null;$script:lastStatusSave=[datetime]::MinValue;$script:statusDirty=$false
function Save-RunnerState([switch]$Force,[int]$MinimumSeconds=0){
    # Rewrites status.json: always with -Force, otherwise when the heartbeat (or the given minimum interval) has passed.
    # A change skipped by the interval stays pending (dirty) and is written within a second by the wait loop.
    if(!$script:runStatus){return}
    $since=((Get-SBNow).LocalDateTime-$script:lastStatusSave).TotalSeconds
    $limit=if($MinimumSeconds -gt 0){$MinimumSeconds}elseif($script:statusDirty){1}else{Get-SBRunnerHeartbeatSeconds}
    if(!$Force -and $since -lt $limit){if($MinimumSeconds -gt 0){$script:statusDirty=$true};return}
    try{Save-SBRunnerStatus $script:runStatusPath $script:runStatus;$script:lastStatusSave=(Get-SBNow).LocalDateTime;$script:statusDirty=$false}catch{[void]$_}
}
function Set-RunnerPhase([string]$Phase){if($script:runStatus){$script:runStatus.phase=$Phase;Save-RunnerState -Force}}
# Progress goes to standard error so that `> file` keeps only the final JSON while the console still shows the advance.
# With -Events each line is one JSON object (event name from the message key, the message and its data) for the desktop orchestrator.
# Every event also goes to events.jsonl and refreshes status.json once the run folder exists.
function Show-RunnerLine([string]$Key,[object[]]$Arguments=@(),$Data,[switch]$Agent){
    $text=Get-SBMessage $Key $Arguments
    $now=(Get-SBNow).ToString('o')
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
        # Unattended runs start only on an explicit choice made now, from this probe: model and effort, or the CLI defaults on purpose.
        $c=$script:capabilities
        $needModel=[bool]($c.supports.model -and !$Model);$needEffort=[bool]($c.supports.effort -and !$Effort)
        if($Run -and !$UseCliDefault -and ($needModel -or $needEffort)){
            $models=@($c.models|ForEach-Object {$_.id});$efforts=@($c.efforts|ForEach-Object {$_.id})
            [Console]::Error.WriteLine((Get-SBMessage 'runner.selection.required' @($(if($models.Count){$models -join ', '}else{'-'}),$(if($efforts.Count){$efforts -join ', '}else{'-'}),$(if($c.configured.model){$c.configured.model}else{'-'}),$(if($c.configured.effort){$c.configured.effort}else{'-'}))))
            Close-RunnerState 'failed';exit 2
        }
        if($script:runStatus){$script:runStatus.resolvedModel=$(if($Model){$Model}else{$c.configured.model});$script:runStatus.resolvedEffort=$(if($Effort){$Effort}else{$c.configured.effort})}
    }
    $invocation=New-SBAgentInvocation -Provider $Provider -Capabilities $script:capabilities -Model $Model -Effort $Effort
    $script:AgentArguments=@($invocation.arguments);$script:omitted=@($invocation.omitted)
    if($script:omitted.Count){Show-RunnerLine 'runner.progress.omitted' @(($script:omitted -join ', ')) @{omitted=$script:omitted}}
}
function Close-RunnerState([string]$State){
    # Final status of the run and closure of its work folder (the retention clock starts).
    if(!$script:runStatus){return}
    $script:runStatus.state=$State;$script:runStatus.phase='closed';$script:runStatus.finishedAt=(Get-SBNow).ToString('o')
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
function Invoke-RunnerTaskUpdate([string[]]$UpdateArgs){
    # A tracker update by the runner through knowledge.ps1: $true applied, 'deferred' accepted but queued behind another writer (exit 5,
    # applied by the next -FlushPending), $false refused. The runner records itself as the executor of its own updates.
    $previous=$env:SECONDBRAIN_EXECUTOR
    try{
        $env:SECONDBRAIN_EXECUTOR=(ConvertTo-Json ([ordered]@{tool=$Provider;mode='runner';model=$(if($script:runStatus){$script:runStatus.resolvedModel});effort=$(if($script:runStatus){$script:runStatus.resolvedEffort});runId=$(if($script:runStatus){$script:runStatus.runId})}) -Compress)
        $null=(& pwsh -NoProfile -File $knowledge @UpdateArgs @configArgs 2>&1|Out-String)
        switch($LASTEXITCODE){0{$true}5{'deferred'}default{$false}}
    }catch{$false}finally{$env:SECONDBRAIN_EXECUTOR=$previous}
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
# -Resume: the queue left by a quota stop (interrupted task first, then the tasks not reached), with the same selection rules.
$script:resumeFrom=$null
if($Resume){
    $early=Read-SBConfiguration $ConfigPath
    $script:resumeFrom=Get-SBRunnerResumePoint $early.brainRoot $early.workstationId $targets[0].path $Resume
    if(!$script:resumeFrom){[Console]::Error.WriteLine((Get-SBMessage 'runner.resume.missing' @($Resume)));exit 2}
    $TaskIds=@($script:resumeFrom.remaining|ForEach-Object {[string]$_}|Where-Object {$_})
    $interruptedId=if($script:resumeFrom.interrupted -is [hashtable]){[string]$script:resumeFrom.interrupted.id}else{'-'}
    Show-RunnerLine 'runner.progress.resume' @($script:resumeFrom.runId,$TaskIds.Count,$interruptedId) @{resume=$script:resumeFrom.path;taskIds=$TaskIds}
}
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
    $tracker=$null
    $source=@($ready|Where-Object {$_.PSObject.Properties['source'] -and $_.source}|Select-Object -First 1)
    if($source.Count -ne 1 -and !$Run){
        # No ready task: the preview still needs the tracker to list the open tasks for analysis.
        try{$source=@(@(Invoke-Json (@($knowledge,'-Tasks','-CheckoutPath',$checkout)+$configArgs))|Where-Object {$_.PSObject.Properties['source'] -and $_.source}|Select-Object -First 1)}catch{$source=@()}
    }
    if($source.Count -eq 1){
        # Objects, not the hashtables of Read-SBJson: selection reads PSObject properties, the same shape as the CLI fallback (#376).
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
    # Preview only: the open tasks that are not ready at all (blocked, unknown, waiting on dependencies) are listed too, so the queue can
    # offer them for analysis; every excluded entry carries title, status, execution and state reason.
    $info=@{};foreach($t in @($detail)){$info[[string]$t.id]=$t}
    if(!$Run -and $tracker -and $tracker.PSObject.Properties['tasks'] -and !$TaskIds.Count){
        $readyIds=@($ready|ForEach-Object {[string]$_.id})
        $statusById=@{};foreach($t in @($tracker.tasks)){$statusById[[string]$t.id]=[string]$t.status}
        foreach($t in @($tracker.tasks)){
            $id=[string]$t.id
            if([string]$t.status -in @('done','cancelled') -or $id -in $readyIds){continue}
            $reason=if([string]$t.status -in @('blocked','unknown')){"status:$($t.status)"}else{
                # A dependency missing from the active tracker is archived (done or cancelled); another repository's is named as repo#id.
                $open=@(@($t.dependencies)|Where-Object {$_}|ForEach-Object {
                    $depId=[string]$_.id;$depRepo=if($_.PSObject.Properties['repository']){[string]$_.repository}else{''}
                    if($depRepo){"$depRepo#$depId"}elseif($statusById.ContainsKey($depId) -and $statusById[$depId] -ne 'done'){$depId}
                })
                if($open.Count){'dependency:'+($open -join ',')}else{'not-ready'}
            }
            $excluded+=,[ordered]@{id=$id;seq=$t.seq;reason=$reason}
            $info[$id]=$t
        }
    }
    $excluded=@($excluded|ForEach-Object {
        $t=$info[[string]$_.id]
        if($t){
            $ext=Get-SBRunnerValue $t 'extensions'
            $_.title=[string](Get-SBRunnerValue $t 'title');$_.status=[string](Get-SBRunnerValue $t 'status');$_.execution=[string](Get-SBRunnerValue $t 'execution')
            $_.priority=[string](Get-SBRunnerValue $t 'priority');$_.stateReason=[string](Get-SBRunnerValue $ext 'stateReason');$_.awaiting=[string](Get-SBRunnerValue $ext 'awaiting')
        }
        $_
    })
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
    foreach($x in @($read.excluded)){$entry=[ordered]@{repository=$label};foreach($k in @($x.Keys)){$entry[$k]=$x[$k]};$skipped+=,$entry}
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
$runFolder=(Invoke-Json (@((Join-Path $PSScriptRoot 'work.ps1'),'-Repository',$runIdentity,'-Category','report','-Slug',$script:runSlug,'-Init','-Task','Run del runner','-Client',$Provider)+$configArgs)).root
if(!$StopFile){$StopFile=Join-Path $runFolder 'stop.flag'}
$script:runStatusPath=Join-Path $runFolder 'status.json';$script:runEventsPath=Join-Path $runFolder 'events.jsonl'
$script:runStatus=[ordered]@{
    schemaVersion=1;runId=(Split-Path $runFolder -Leaf);state='running';phase='probe';pid=$PID;processStartTicks=(Get-SBProcessStartTicks $PID)
    repository=$runIdentity;checkout=$targets[0].path;provider=$Provider;model=$Model;effort=$Effort
    startedAt=(Get-SBNow).ToString('o');updatedAt=$null;finishedAt=$null;lastRunnerEventAt=$null;lastAgentEventAt=$null;lastAgentEvent=$null
    timeoutMinutes=$TimeoutMinutes;stallMinutes=$StallMinutes;stopFile=$StopFile;folder=$runFolder
    task=$null;counts=[ordered]@{total=$totalSelected;done=0;succeeded=0;failed=0};stopReason=$null;results=@()
    resolvedModel=$null;resolvedEffort=$null;quota=$null;quotaObserved=$null;resumedFrom=$(if($script:resumeFrom){$script:resumeFrom.path}else{$null})
}
function Read-RunnerQuota{
    # Quota read now (never reused from an earlier read): Codex session files, else the newest observation an agent reported on this workstation.
    $observation=Get-SBRunnerQuotaObservation $config.brainRoot $config.workstationId $Provider
    $q=Get-SBAgentQuota -Provider $Provider -Observation $observation
    $q.readAt=(Get-SBNow).ToString('o')
    $script:runStatus.quota=$q
    Show-RunnerLine 'runner.progress.quota' @($Provider,$q.state,$q.source,$(if($q.resetAt){', reset '+$q.resetAt}else{''})) @{quota=$q}
    $q
}
function Save-RunnerResumePoint($Interrupted,[string]$Reason,$Limit){
    # resume.json in the run folder: what stopped, the interrupted task and the queue not run yet, the checkout's Git state.
    $doneIds=@($results|Where-Object {$_.state -notin @('quota')}|ForEach-Object {[string]$_.id})
    $remaining=@($plans|ForEach-Object {$_.tasks}|ForEach-Object {[string]$_.id}|Where-Object {$_ -notin $doneIds})
    $git=$null;try{$git=(& git -C $targets[0].path status --porcelain=v1 --branch 2>$null|Out-String).Trim()}catch{$git=$null}
    $point=[ordered]@{
        schemaVersion=1;runId=$script:runStatus.runId;repository=$script:runStatus.repository;checkout=$targets[0].path;reason=$Reason
        stoppedAt=(Get-SBNow).ToString('o');provider=$Provider;model=$script:runStatus.resolvedModel;effort=$script:runStatus.resolvedEffort
        limit=$Limit;quota=$(if($script:runStatus.quotaObserved){$script:runStatus.quotaObserved}else{$script:runStatus.quota})
        interrupted=$Interrupted;remaining=$remaining;git=$git;resumedBy=$null
    }
    $path=Join-Path $runFolder 'resume.json'
    [IO.File]::WriteAllText($path,(ConvertTo-SBJson $point),$utf8)
    Show-RunnerLine 'runner.progress.resumefile' @($path,$script:runStatus.runId) @{resume=$path;remaining=$remaining}
}
Show-RunnerLine 'runner.progress.status' @($script:runStatusPath) @{status=$script:runStatusPath;folder=$runFolder;stopFile=$StopFile}
$runState='failed'
try{
Initialize-RunnerInvocation
$resolved=Resolve-SBAgentExecutable $AgentPath
if(!$resolved){[Console]::Error.WriteLine((New-SBError 'runner.agent.missing' $AgentPath).Message);exit 2}
# Prefer a real executable or .cmd shim; a .ps1 shim (npm) cannot be started directly, so it is wrapped in pwsh -File.
$results=@();$consecutiveFailures=0;$stopReason=$null;$position=0
if($script:resumeFrom){
    # The resume point is consumed by this run: mark it so 'latest' does not pick it again.
    try{$used=Read-SBText $script:resumeFrom.path|ConvertFrom-Json -AsHashtable -Depth 32 -DateKind String;$used.resumedBy=$script:runStatus.runId;[IO.File]::WriteAllText($script:resumeFrom.path,(ConvertTo-SBJson $used),$utf8)}catch{[void]$_}
}
foreach($plan in $plans){
    $checkout=$plan.target.path
    foreach($task in $plan.tasks){
        if($StopFile -and (Test-Path -LiteralPath $StopFile)){$stopReason='requested';break}
        # Quota read before every task: exhausted with a future reset stops here (nothing started); unknown and available proceed.
        $quotaNow=Read-RunnerQuota
        if($quotaNow.state -eq 'exhausted'){
            Show-RunnerLine 'runner.progress.quotaexhausted' @($Provider,$quotaNow.resetAt) @{quota=$quotaNow}
            $stopReason='quota';Save-RunnerResumePoint $null 'quota-before-start' $null;break
        }
        $position++
        Set-RunnerPhase 'init'
        $identity=Resolve-RunnerIdentity $plan $task
        # Unique per run of the task: a same-day rerun keeps its own output and report.
        $slug="runner-$($task.seq)-"+(Get-SBNow).LocalDateTime.ToString('HHmmss')
        $folder=Invoke-Json (@((Join-Path $PSScriptRoot 'work.ps1'),'-Repository',$identity,'-Category','report','-Slug',$slug,'-Init','-Task',"Run autonomo $($task.id)",'-Client',$Provider)+$configArgs)
        $root=$folder.root
        $began=(Get-SBNow).LocalDateTime
        $script:runStatus.task=[ordered]@{id=[string]$task.id;seq=$task.seq;title=[string]$task.title;position=$position;total=$totalSelected;startedAt=(Get-SBNow).ToString('o');folder=$root}
        $script:runStatus.lastAgentEventAt=$null;$script:runStatus.lastAgentEvent=$null;$script:runStatus.phase='agent'
        Show-RunnerLine 'runner.progress.start' @($position,$totalSelected,$task.seq,$(if($plan.target.identity){$plan.target.identity}else{[string]$task.id})) @{position=$position;total=$totalSelected;id=[string]$task.id;seq=$task.seq;title=[string]$task.title;folder=$root}
        # Session perimeter enforced in code (#382): knowledge.ps1 and the MCP tools started by the agent refuse global reads and foreign repositories.
        # UTF-8 both ways (Invoke-SBAgentProcess): the Italian prompt reaches the agent intact and its JSON comes back without code-page damage.
        $scopeVariables=Get-SBRunnerScopeVariables
        $agentEnv=@{}
        $agentEnv[$scopeVariables.repository]=[string]$identity
        # The executor of this session (tool, mode, model, effort, run): the agent's tracker writes record it in the dossier ledger.
        $agentEnv['SECONDBRAIN_EXECUTOR']=(ConvertTo-Json ([ordered]@{tool=$Provider;mode='runner';model=$script:runStatus.resolvedModel;effort=$script:runStatus.resolvedEffort;runId=$script:runStatus.runId}) -Compress)
        $prompt=if($external){New-SBTaskRunPrompt $task $PSScriptRoot $checkout}else{New-SBTaskRunPrompt $task}
        if($script:resumeFrom -and $script:resumeFrom.interrupted -is [hashtable] -and [string]$script:resumeFrom.interrupted.id -eq [string]$task.id){
            $prompt+="`nRipresa: una sessione precedente su questo task si e fermata per limite di quota. Prima di tutto leggi $($script:resumeFrom.interrupted.folder) (agent-output.jsonl, report.json) e lo stato Git del checkout, conserva il lavoro gia fatto e prosegui dal punto interrotto senza ripeterlo."
        }
        # One process through the shared loop: every agent line is kept at once, summarized as a progress line and counted as activity.
        $agentRun=Invoke-SBAgentProcess -Executable $resolved -Arguments $AgentArguments -Prompt $prompt -WorkingDirectory $checkout -Environment $agentEnv `
            -TimeoutSeconds ($TimeoutMinutes*60) -StallMinutes $StallMinutes -OutputLog (Join-Path $root 'agent-output.jsonl') `
            -OnOutputLine {param($line)
                $rateLimit=ConvertFrom-SBAgentRateLimitEvent $line
                if($rateLimit){$script:runStatus.quotaObserved=[ordered]@{provider=$Provider;state=$rateLimit.state;status=$rateLimit.status;kind=$rateLimit.kind;resetAt=$rateLimit.resetAt;observedAt=(Get-SBNow).ToString('o');source='agent'}}
                $ev=ConvertTo-SBAgentEvent $line
                if($ev){Show-RunnerLine 'runner.progress.agent' @($task.seq,$ev.kind,$ev.summary) @{id=[string]$task.id;seq=$task.seq;kind=$ev.kind;summary=$ev.summary} -Agent}
            } `
            -OnTick {param($elapsed) Show-RunnerLine 'runner.progress.tick' @($task.seq,$elapsed,$TimeoutMinutes) @{id=[string]$task.id;seconds=$elapsed}} `
            -OnStall {param($silent) Show-RunnerLine 'runner.progress.stalled' @($task.seq,$silent,$TimeoutMinutes) @{id=[string]$task.id;minutes=$silent}} `
            -OnResume {$script:runStatus.phase='agent'} `
            -OnIdle {Save-RunnerState}
        $state=$agentRun.state;$code=$agentRun.exitCode;$outText=$agentRun.output;$errText=$agentRun.error
        # agent-output.json keeps the final answer (the stream-json result line, or the whole output of a non-streaming CLI).
        [IO.File]::WriteAllText((Join-Path $root 'agent-output.json'),(Get-SBAgentFinalOutput $outText),$utf8)
        [IO.File]::WriteAllText((Join-Path $root 'agent-error.txt'),$errText,$utf8)
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
        $record=[ordered]@{repository=$identity;id=$task.id;seq=$task.seq;state=$state;exitCode=$code;statusBefore=$task.status;statusAfter=$statusAfter;seconds=[int]((Get-SBNow).LocalDateTime-$began).TotalSeconds;folder=$root;provider=$Provider;model=$script:runStatus.resolvedModel;effort=$script:runStatus.resolvedEffort;runId=$script:runStatus.runId;finishedAt=(Get-SBNow).ToString('o')}
        # Limits only from the agent's final error envelope with the provider's own texts (a timed-out agent keeps its timeout state).
        # quota stops the run and leaves a resume point; throttled (transient rate limit) waits briefly and the run goes on.
        $limit=if($state -ne 'timeout'){Get-SBAgentLimitState -Provider $Provider -Output $outText -ErrorOutput $errText -ExitCode $code}else{$null}
        if($limit){$record.limit=$limit;Show-RunnerLine 'runner.progress.limit' @($task.seq,$limit.state,$limit.message) @{id=[string]$task.id;limit=$limit}}
        # A run that leaves the task todo made no progress: park it as user_required (the agent's reason stays) so the same limit is not repeated.
        $record.parked=$false
        if(!$limit -and $state -eq 'finished' -and $code -eq 0 -and $statusAfter -eq 'todo'){
            $record.parked=Invoke-RunnerTaskUpdate @('-UpdateTaskId',[string]$task.id,'-Execution','user_required','-CheckoutPath',$checkout)
        }
        # Stop the whole run when the plan quota is exhausted, or after three consecutive failures (no retry loops).
        # Classified before report.json is written, so the report and the run summary agree.
        if($limit -and $limit.state -eq 'quota'){
            $record.state='quota';$stopReason='quota'
            $prior=$script:runStatus.quotaObserved
            $script:runStatus.quotaObserved=[ordered]@{provider=$Provider;state='exhausted';status='limit';kind=$(if($prior){$prior.kind}else{$null});resetAt=$(if($prior -and $prior.resetAt){$prior.resetAt}else{$null});observedAt=(Get-SBNow).ToString('o');source='agent';message=$limit.message}
            # The interrupted task goes back to todo when the agent left it in progress, so -Resume selects it again.
            if($statusAfter -eq 'in_progress'){
                $record.requeued=Invoke-RunnerTaskUpdate @('-UpdateTaskId',[string]$task.id,'-Status','todo','-StateReason','Interrotto dal limite di quota del runner: riprendere con run-ready-tasks.ps1 -Resume latest','-CheckoutPath',$checkout)
                if($record.requeued -ne $false){$record.statusAfter='todo'}
            }
            Save-RunnerResumePoint ([ordered]@{id=[string]$task.id;seq=$task.seq;folder=$root;statusAfter=$record.statusAfter}) 'quota' $limit
        }
        elseif($limit -and $limit.state -eq 'throttled'){$record.state='throttled';Start-Sleep -Seconds 30}
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
