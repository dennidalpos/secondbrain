#requires -Version 7.5
# Task ledger of a dossier: history/task-runs.jsonl, one JSON record per change of a task's status, execution or evidence, with the
# executor that made it (tool claude|codex|gemini|antigravity|human|unknown, mode runner|interactive|mcp|cli|analysis|memory-cycle,
# model, effort, run). Records are appended in the same transaction as the tracker write (Save-SBTrackerData), so every writer is
# covered at one point. The registry view joins active tasks, the archive, the ledger and the runner reports of this workstation.
# Schema: config/task-runs.schema.json. Pure functions here: the caller owns the transaction.
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
$script:SBLedgerTools=@('claude','codex','gemini','antigravity','human','unknown')
$script:SBLedgerModes=@('runner','interactive','mcp','cli','analysis','memory-cycle','backfill')
function Get-SBTaskLedgerTools { ,$script:SBLedgerTools }
function Get-SBTaskLedgerPath([string]$TrackerPath) { Join-Path (Split-Path $TrackerPath) 'history/task-runs.jsonl' }
function ConvertTo-SBLedgerTool([string]$Value) {
    # Tool names from IDE and session clients: claude-code, codex, gemini-cli, antigravity; anything else is unknown.
    $v=([string]$Value).Trim().ToLowerInvariant()
    switch -Regex ($v){
        '^claude' {'claude'}
        '^codex' {'codex'}
        '^gemini' {'gemini'}
        '^antigravity' {'antigravity'}
        '^(human|owner|person|persona)' {'human'}
        default {'unknown'}
    }
}
function Resolve-SBExecutor {
    # Who is making a tracker change, in this order: an explicit executor (hashtable or JSON), SECONDBRAIN_EXECUTOR (set by the runner for
    # its agents and by the orchestrator for analyses), the environment of the agent CLI (Claude Code, Codex, Gemini CLI), the session client,
    # else unknown. The result is a small hashtable that travels with a deferred write, so the executor is the submitter, not the flusher.
    param($Executor,[string]$Client)
    $from=$null
    if($Executor -is [Collections.IDictionary]){$from=$Executor}
    elseif($Executor -is [string] -and $Executor.Trim().StartsWith('{')){try{$from=$Executor|ConvertFrom-Json -AsHashtable}catch{$from=$null}}
    if(!$from -and $env:SECONDBRAIN_EXECUTOR){try{$from=$env:SECONDBRAIN_EXECUTOR|ConvertFrom-Json -AsHashtable}catch{$from=$null}}
    if($from){
        $tool=ConvertTo-SBLedgerTool ([string]$from['tool'])
        $mode=[string]$from['mode'];if($mode -notin $script:SBLedgerModes){$mode='cli'}
        $result=[ordered]@{tool=$tool;mode=$mode}
        foreach($k in @('model','effort','runId')){if($from.Contains($k) -and $from[$k]){$result[$k]=[string]$from[$k]}}
        return $result
    }
    $detected=if($env:CLAUDECODE -or $env:CLAUDE_CODE_ENTRYPOINT){'claude'}
        elseif($env:CODEX_THREAD_ID -or $env:CODEX_SANDBOX -or $env:CODEX_SANDBOX_NETWORK_DISABLED -or $env:CODEX_MANAGED_BY_NPM){'codex'}
        elseif($env:GEMINI_CLI -or $env:GEMINI_CLI_NO_RELAUNCH){'gemini'}
        elseif($env:ANTIGRAVITY_AGENT -or $env:ANTIGRAVITY_SESSION){'antigravity'}
        else{$null}
    if($detected){return [ordered]@{tool=$detected;mode='interactive'}}
    if($Client -and $Client -ne 'knowledge CLI/API'){return [ordered]@{tool=(ConvertTo-SBLedgerTool $Client);mode='mcp'}}
    [ordered]@{tool='unknown';mode='cli'}
}
function Get-SBTaskLedgerSnapshot($Task) {
    # The fields whose change makes a ledger record.
    if($null -eq $Task){return $null}
    @{status=[string]$Task['status'];execution=[string]$Task['execution'];evidence=@($Task['evidence']).Count}
}
function New-SBTaskRunRecord {
    # One ledger record for a task change, or $null when status, execution and evidence did not change (and the task is not new).
    param([Parameter(Mandatory)]$Task,$Before,$Executor,[string]$Reason,[switch]$Created,[hashtable]$Outcome,[string]$At)
    $after=Get-SBTaskLedgerSnapshot $Task
    if(!$Created -and $Before -and $Before.status -eq $after.status -and $Before.execution -eq $after.execution -and $Before.evidence -eq $after.evidence -and !$Outcome){return $null}
    $exec=Resolve-SBExecutor $Executor
    $record=[ordered]@{
        schemaVersion=1;recordId=[guid]::NewGuid().ToString('N');taskId=[string]$Task['id'];seq=$(if($Task.Contains('seq')){$Task['seq']}else{$null})
        at=$(if($At){$At}else{[DateTimeOffset]::UtcNow.ToString('o')})
        statusBefore=$(if($Before){$Before.status}else{$null});statusAfter=$after.status
        executionBefore=$(if($Before){$Before.execution}else{$null});executionAfter=$after.execution
        executor=$exec
    }
    if($Created){$record.event='created'}elseif($Before -and $Before.status -ne $after.status){$record.event='status'}elseif($Before -and $Before.execution -ne $after.execution){$record.event='execution'}elseif($Outcome){$record.event='run'}else{$record.event='evidence'}
    if($Before -and $after.evidence -gt $Before.evidence){$record.evidence=@(@($Task['evidence'])|Select-Object -Last ($after.evidence-$Before.evidence))}
    $reason=if($Reason){$Reason}elseif($Task['extensions'] -is [Collections.IDictionary] -and $Task.extensions['stateReason']){[string]$Task.extensions.stateReason}else{$null}
    if($reason){$record.reason=$(if($reason.Length -gt 600){$reason.Substring(0,600)}else{$reason})}
    if($Outcome){$record.outcome=$Outcome}
    $record
}
function Get-SBTaskLedgerOperation([string]$TrackerPath,[object[]]$Records) {
    # Transaction operation appending the records to the ledger (created when absent); $null with no records.
    $records=@($Records|Where-Object {$_})
    if(!$records.Count){return $null}
    $path=Get-SBTaskLedgerPath $TrackerPath
    $before=Get-SBFileHash $path
    $existing=if($before -ne 'absent'){[IO.File]::ReadAllText($path,[Text.UTF8Encoding]::new($false))}else{''}
    if($existing -and !$existing.EndsWith("`n")){$existing+="`n"}
    $lines=($records|ForEach-Object {$_|ConvertTo-Json -Compress -Depth 12}) -join "`n"
    @{path=$path;expected=$before;bytes=[Text.UTF8Encoding]::new($false).GetBytes($existing+$lines+"`n")}
}
function Read-SBTaskLedger([string]$TrackerPath) {
    # Every valid record of the dossier ledger, oldest first, emitted one by one (callers collect them with @()); malformed lines are skipped.
    $path=Get-SBTaskLedgerPath $TrackerPath
    if(!(Test-Path -LiteralPath $path -PathType Leaf)){return}
    $records=@()
    foreach($line in [IO.File]::ReadAllLines($path,[Text.UTF8Encoding]::new($false))){
        if(!$line.Trim()){continue}
        try{$r=$line|ConvertFrom-Json -AsHashtable -Depth 16 -DateKind String}catch{continue}
        if($r -is [Collections.IDictionary] -and $r['schemaVersion'] -eq 1 -and $r['taskId'] -and $r['executor'] -is [Collections.IDictionary]){$records+=,$r}
    }
    $records
}
function Get-SBRunnerReportRecords([string]$ReportRoot) {
    # Per-task runner reports of this workstation (report/<date>-runner-<seq>[-<time>]/report.json) with the provider of their run
    # (the run's status.json lists the task folder in results): the outcome data of autonomous runs, emitted one by one.
    if(!$ReportRoot -or !(Test-Path -LiteralPath $ReportRoot -PathType Container)){return}
    $runs=@{}
    foreach($dir in @(Get-ChildItem -LiteralPath $ReportRoot -Directory -Filter '*-runner-run-*' -ErrorAction SilentlyContinue)){
        $status=Join-Path $dir.FullName 'status.json'
        if(!(Test-Path -LiteralPath $status -PathType Leaf)){continue}
        try{$s=Read-SBText $status|ConvertFrom-Json -AsHashtable -Depth 32 -DateKind String}catch{continue}
        foreach($r in @($s['results'])){if($r -is [Collections.IDictionary] -and $r['folder']){$runs[[IO.Path]::GetFileName(([string]$r.folder).TrimEnd('\','/'))]=$s}}
    }
    $records=@()
    foreach($dir in @(Get-ChildItem -LiteralPath $ReportRoot -Directory -ErrorAction SilentlyContinue|Where-Object {$_.Name -match '^\d{8}-runner-\d+(-\d{6})?$'})){
        $file=Join-Path $dir.FullName 'report.json'
        if(!(Test-Path -LiteralPath $file -PathType Leaf)){continue}
        try{$rep=Read-SBText $file|ConvertFrom-Json -AsHashtable -Depth 16 -DateKind String}catch{continue}
        if($rep -isnot [Collections.IDictionary] -or !$rep['id']){continue}
        $run=if($runs.ContainsKey($dir.Name)){$runs[$dir.Name]}else{$null}
        $provider=if($rep['provider']){[string]$rep.provider}elseif($run){[string]$run['provider']}else{''}
        $model=if($rep['model']){[string]$rep.model}elseif($run -and $run['resolvedModel']){[string]$run.resolvedModel}elseif($run){[string]$run['model']}else{''}
        $effort=if($rep['effort']){[string]$rep.effort}elseif($run -and $run['resolvedEffort']){[string]$run.resolvedEffort}elseif($run){[string]$run['effort']}else{''}
        $runId=if($rep['runId']){[string]$rep.runId}elseif($run){[string]$run['runId']}else{''}
        $at=if($rep['finishedAt']){[string]$rep.finishedAt}else{([DateTimeOffset]$dir.LastWriteTimeUtc).ToString('o')}
        $exec=[ordered]@{tool=$(if($provider){ConvertTo-SBLedgerTool $provider}else{'unknown'});mode='runner'}
        if($model){$exec.model=$model};if($effort){$exec.effort=$effort};if($runId){$exec.runId=$runId}
        $records+=,[ordered]@{
            schemaVersion=1;recordId=('report-'+(Get-SBTextHash ($dir.Name+'|'+[string]$rep.id)).Substring(0,24).ToLowerInvariant());taskId=[string]$rep.id;seq=$rep['seq'];at=$at
            statusBefore=$rep['statusBefore'];statusAfter=$rep['statusAfter'];executor=$exec;event='run';source='report'
            outcome=[ordered]@{state=[string]$rep['state'];exitCode=$rep['exitCode'];seconds=$rep['seconds'];parked=$rep['parked'];folder=$dir.Name}
        }
    }
    $records
}
function Get-SBTaskRegistry {
    # Registry of every task of a repository (active and archived) with its runs: ledger records joined with the runner reports of this
    # workstation (a report already copied into the ledger by -BackfillTaskRuns is not repeated). Filters: tool, status, archived, search.
    param($ActiveTasks=@(),$ArchivedTasks=@(),$Ledger=@(),$Reports=@(),[string]$Tool,[string]$Status,[ValidateSet('include','exclude','only')][string]$Archived='include',
        [string]$Search,[int]$Offset=0,[int]$Limit=50)
    $byTask=@{}
    $seen=@{}
    foreach($r in @($Ledger)+@($Reports)){
        if(!$r){continue}
        $key=if($r['source'] -eq 'report' -or ($r['outcome'] -is [Collections.IDictionary] -and $r.outcome['folder'])){'f|'+[string]$r.taskId+'|'+[string]$(if($r['outcome'] -is [Collections.IDictionary]){$r.outcome['folder']})}else{'r|'+[string]$r.recordId}
        if($seen.ContainsKey($key)){continue};$seen[$key]=$true
        $id=[string]$r.taskId
        if(!$byTask.ContainsKey($id)){$byTask[$id]=[Collections.Generic.List[object]]::new()}
        $byTask[$id].Add($r)
    }
    $entries=@()
    foreach($pair in @(@($ActiveTasks|ForEach-Object {@{task=$_;archived=$false}})+@($ArchivedTasks|ForEach-Object {@{task=$_;archived=$true}}))){
        $t=$pair.task;$id=[string]$t['id']
        $runs=@($(if($byTask.ContainsKey($id)){$byTask[$id]|Sort-Object {[string]$_['at']}}))
        $tools=@($runs|ForEach-Object {[string]$_.executor['tool']}|Where-Object {$_}|Select-Object -Unique)
        $closed=@($runs|Where-Object {$_['statusAfter'] -in @('done','cancelled')}|Select-Object -Last 1)
        $ext=if($t['extensions'] -is [Collections.IDictionary]){$t.extensions}else{@{}}
        $entries+=,[ordered]@{
            id=$id;seq=$t['seq'];title=[string]$t['title'];status=[string]$t['status'];priority=[string]$t['priority'];execution=[string]$t['execution']
            archived=$pair.archived;closedAt=$(if($closed.Count){[string]$closed[0].at}else{$null})
            stateReason=$(if($ext['stateReason']){[string]$ext.stateReason}else{$null})
            tools=[object[]]@(if($tools.Count){$tools}else{'unknown'});lastTool=$(if($runs.Count){[string]$runs[-1].executor['tool']}else{$null})
            lastActivity=$(if($runs.Count){[string]$runs[-1].at}else{$null})
            runs=$runs;evidence=@($t['evidence'])
        }
    }
    if($Archived -eq 'exclude'){$entries=@($entries|Where-Object {!$_.archived})}elseif($Archived -eq 'only'){$entries=@($entries|Where-Object {$_.archived})}
    if($Tool){$entries=@($entries|Where-Object {$Tool -in @($_.tools)})}
    if($Status){$entries=@($entries|Where-Object {$_.status -eq $Status})}
    if($Search){$s=$Search.Trim();$entries=@($entries|Where-Object {$_.id -like "*$s*" -or $_.title -like "*$s*"})}
    $entries=@($entries|Sort-Object @{e={if($_.lastActivity){$_.lastActivity}else{''}};Descending=$true},@{e={[int]$(if($null -ne $_.seq){$_.seq}else{0})};Descending=$true})
    $counts=[ordered]@{}
    foreach($toolName in $script:SBLedgerTools){$counts[$toolName]=@($entries|Where-Object {$toolName -in @($_.tools)}).Count}
    $total=$entries.Count
    # @() outside the if: a page of one task stays an array in the JSON (an if statement unrolls a one-element array).
    $page=@(if($Limit -gt 0){$entries|Select-Object -Skip $Offset -First $Limit}else{$entries|Select-Object -Skip $Offset})
    [ordered]@{total=$total;offset=$Offset;limit=$Limit;nextOffset=$(if($Limit -gt 0 -and $Offset+$Limit -lt $total){$Offset+$Limit}else{$null});tools=$counts;tasks=[object[]]$page}
}
Export-ModuleMember -Function @('Get-SBTaskLedgerTools','Get-SBTaskLedgerPath','ConvertTo-SBLedgerTool','Resolve-SBExecutor','Get-SBTaskLedgerSnapshot','New-SBTaskRunRecord','Get-SBTaskLedgerOperation','Read-SBTaskLedger','Get-SBRunnerReportRecords','Get-SBTaskRegistry')
