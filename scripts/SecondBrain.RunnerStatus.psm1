#requires -Version 7.5
# Live status of a task-runner run: status.json and events.jsonl in the run work folder (report/<date>-runner-run-<time>-<pid>),
# written by run-ready-tasks.ps1 and read by runner-status.ps1, the MCP tool get_runner_status and the desktop orchestrator.
# The verdict (working, stalled, finished, orphaned) comes from the recorded process, the heartbeat and the last agent event.
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Host.psm1')

# Heartbeat: the runner rewrites status.json at least this often while it is alive; a status older than three beats means a stuck runner.
$script:SBRunnerHeartbeatSeconds=15
function Get-SBRunnerHeartbeatSeconds { $script:SBRunnerHeartbeatSeconds }
function Get-SBRunnerRunSlug([datetime]$Date=(Get-SBNow).LocalDateTime,[int]$ProcessId=$PID) {
    # Work-folder slug of one run: unique per second and process, within the work.ps1 slug rules.
    'runner-run-'+$Date.ToString('HHmmss')+'-'+$ProcessId
}
function Get-SBRunnerReportRoot([string]$BrainRoot,[string]$HostId,[string]$Repository) {
    (Resolve-SBWorkRoot $BrainRoot $HostId ('repos/'+(Get-SBRuntimeRepoSegment $Repository)+'/report')).root
}
function Get-SBRunnerStatusFiles([string]$BrainRoot,[string]$HostId,[string]$Repository) {
    # status.json of every run of the repository on this workstation, newest first.
    $root=Get-SBRunnerReportRoot $BrainRoot $HostId $Repository
    if(!(Test-Path -LiteralPath $root -PathType Container)){return}
    @(Get-ChildItem -LiteralPath $root -Directory -Filter '*-runner-run-*' -ErrorAction SilentlyContinue|
        ForEach-Object {Join-Path $_.FullName 'status.json'}|Where-Object {Test-Path -LiteralPath $_ -PathType Leaf}|
        Sort-Object {(Get-Item -LiteralPath $_).LastWriteTimeUtc} -Descending)
}
function Save-SBRunnerStatus([string]$Path,$Status) {
    # Whole-file replace through a temporary sibling, so readers never see a partial document. The file lives in the run's own work folder.
    $Status.updatedAt=(Get-SBNow).ToString('o')
    $temp=$Path+'.'+(New-SBId)+'.tmp'
    [IO.File]::WriteAllText($temp,(ConvertTo-SBJson $Status),[Text.UTF8Encoding]::new($false))
    [IO.File]::Move($temp,$Path,$true)
}
function Add-SBRunnerEventLine([string]$Path,$Event) {
    # One JSON object per line; the file is append-only for the life of the run.
    [IO.File]::AppendAllText($Path,(($Event|ConvertTo-Json -Compress -Depth 8)+"`n"),[Text.UTF8Encoding]::new($false))
}
function Get-SBProcessStartTicks([int]$ProcessId) {
    # Start time of a live process (UTC ticks), or $null: with the PID it tells a reused PID from the runner that wrote the status.
    try{$p=Get-Process -Id $ProcessId -ErrorAction Stop;try{$p.StartTime.ToUniversalTime().Ticks}finally{$p.Dispose()}}catch{$null}
}
function Test-SBRunnerProcessAlive($Status) {
    if(!$Status -or !$Status.ContainsKey('pid') -or !$Status.pid){return $false}
    $ticks=Get-SBProcessStartTicks ([int]$Status.pid)
    if($null -eq $ticks){return $false}
    if($Status.ContainsKey('processStartTicks') -and $Status.processStartTicks){return [math]::Abs([int64]$Status.processStartTicks-[int64]$ticks) -lt [TimeSpan]::TicksPerSecond}
    $true
}
function Get-SBRunnerAge($Value,[DateTimeOffset]$Now) {
    if(!$Value){return $null}
    try{[int][math]::Max(0,($Now-[DateTimeOffset]::Parse([string]$Value,[Globalization.CultureInfo]::InvariantCulture)).TotalSeconds)}catch{$null}
}
function Get-SBRunnerVerdict($Status,[DateTimeOffset]$Now=(Get-SBNow),[Nullable[bool]]$Alive=$null) {
    # finished: the run closed itself. orphaned: marked running but its process is gone. stalled: alive but silent past the stall
    # threshold (agent phase) or past three heartbeats (runner phases). waiting: alive and waiting for a plan limit to reset
    # (phase waiting-quota, heartbeat still beating). working: everything else.
    if(!$Status){return 'none'}
    if([string]$Status.state -ne 'running'){return 'finished'}
    $isAlive=if($null -ne $Alive){[bool]$Alive}else{Test-SBRunnerProcessAlive $Status}
    if(!$isAlive){return 'orphaned'}
    $beat=Get-SBRunnerAge $Status.updatedAt $Now
    if($null -ne $beat -and $beat -gt 3*(Get-SBRunnerHeartbeatSeconds)){return 'stalled'}
    if([string]$Status.phase -eq 'waiting-quota'){return 'waiting'}
    if([string]$Status.phase -eq 'agent'){
        $stall=if($Status.ContainsKey('stallMinutes') -and $Status.stallMinutes){[double]$Status.stallMinutes}else{5}
        $last=if($Status.ContainsKey('lastAgentEventAt') -and $Status.lastAgentEventAt){$Status.lastAgentEventAt}elseif($Status.task -is [hashtable]){$Status.task.startedAt}else{$null}
        $age=Get-SBRunnerAge $last $Now
        if($null -ne $age -and $age -gt $stall*60){return 'stalled'}
    }
    'working'
}
function Read-SBRunnerStatusFile([string]$Path) {
    try{$s=Read-SBText $Path|ConvertFrom-Json -AsHashtable -Depth 32 -DateKind String;if($s -is [hashtable]){$s}else{$null}}catch{$null}
}
function Get-SBRunnerTail([string]$Path,[int]$Count) {
    if($Count -le 0 -or !(Test-Path -LiteralPath $Path -PathType Leaf)){return}
    $lines=@()
    try{$lines=@([IO.File]::ReadAllLines($Path,[Text.UTF8Encoding]::new($false))|Where-Object {$_}|Select-Object -Last $Count)}catch{$lines=@()}
    $lines|ForEach-Object {try{$_|ConvertFrom-Json -AsHashtable}catch{@{message=$_}}}
}
function Get-SBRunnerStatus {
    # The active run of the repository (newest status marked running), else the newest run; with ages, verdict and the event tail.
    param([Parameter(Mandatory)][string]$BrainRoot,[Parameter(Mandatory)][string]$HostId,[Parameter(Mandatory)][string]$Repository,[int]$Tail=20)
    $files=@(Get-SBRunnerStatusFiles $BrainRoot $HostId $Repository)
    $now=(Get-SBNow)
    $chosen=$null;$chosenPath=$null
    foreach($f in $files){$s=Read-SBRunnerStatusFile $f;if($s -and [string]$s.state -eq 'running'){$chosen=$s;$chosenPath=$f;break}}
    if(!$chosen){foreach($f in $files){$s=Read-SBRunnerStatusFile $f;if($s){$chosen=$s;$chosenPath=$f;break}}}
    if(!$chosen){return [ordered]@{repository=$Repository;active=$false;verdict='none';status=$null;runs=$files.Count}}
    $verdict=Get-SBRunnerVerdict $chosen $now
    $folder=Split-Path $chosenPath -Parent
    [ordered]@{
        repository=$Repository;active=($verdict -in @('working','stalled','waiting'));verdict=$verdict;runs=$files.Count;folder=$folder
        ages=[ordered]@{status=(Get-SBRunnerAge $chosen.updatedAt $now);runnerEvent=(Get-SBRunnerAge $(if($chosen.ContainsKey('lastRunnerEventAt')){$chosen.lastRunnerEventAt}) $now);agentEvent=(Get-SBRunnerAge $(if($chosen.ContainsKey('lastAgentEventAt')){$chosen.lastAgentEventAt}) $now)}
        status=$chosen
        events=@(Get-SBRunnerTail (Join-Path $folder 'events.jsonl') $Tail)
    }
}
function Get-SBRunnerRunList {
    # Past and current runs of the repository on this workstation, newest first: provider, model and effort (as resolved), counts, stop
    # reason, verdict, per-task results and the run folder. -Limit 0 = all.
    param([Parameter(Mandatory)][string]$BrainRoot,[Parameter(Mandatory)][string]$HostId,[Parameter(Mandatory)][string]$Repository,[int]$Limit=50)
    $files=@(Get-SBRunnerStatusFiles $BrainRoot $HostId $Repository)
    $now=(Get-SBNow)
    $runs=@()
    foreach($f in $(if($Limit -gt 0){@($files|Select-Object -First $Limit)}else{$files})){
        $s=Read-SBRunnerStatusFile $f
        if(!$s){continue}
        $model=if($s.ContainsKey('resolvedModel') -and $s.resolvedModel){[string]$s.resolvedModel}elseif($s.ContainsKey('model')){[string]$s.model}else{$null}
        $effort=if($s.ContainsKey('resolvedEffort') -and $s.resolvedEffort){[string]$s.resolvedEffort}elseif($s.ContainsKey('effort')){[string]$s.effort}else{$null}
        $runs+=,[ordered]@{
            runId=[string]$s['runId'];state=[string]$s['state'];verdict=(Get-SBRunnerVerdict $s $now);provider=[string]$s['provider'];model=$model;effort=$effort
            startedAt=$s['startedAt'];finishedAt=$s['finishedAt'];counts=$s['counts'];stopReason=$s['stopReason'];resumedFrom=$s['resumedFrom']
            results=@($s['results']);folder=(Split-Path $f -Parent)
        }
    }
    [ordered]@{repository=$Repository;total=$files.Count;runs=$runs}
}
function Find-SBActiveRunner([string]$BrainRoot,[string]$HostId,[string]$Repository) {
    # The live runner of the repository, if any (one runner per repository); a dead one is returned with orphaned=$true so the caller can close it.
    foreach($f in @(Get-SBRunnerStatusFiles $BrainRoot $HostId $Repository)){
        $s=Read-SBRunnerStatusFile $f
        if(!$s -or [string]$s.state -ne 'running'){continue}
        if(Test-SBRunnerProcessAlive $s){return @{path=$f;status=$s;orphaned=$false}}
        $s.state='orphaned';$s.phase='closed'
        try{Save-SBRunnerStatus $f $s}catch{[void]$_}
    }
    $null
}
function Get-SBRunnerQuotaObservation([string]$BrainRoot,[string]$HostId,[string]$Provider) {
    # Newest quota observation an agent itself reported to a runner of this workstation (status.json quotaObserved: a rate_limit_event
    # or a quota stop), any repository; $null when none. The runner's own pre-reads are not observations, so they never feed themselves.
    $repos=(Resolve-SBWorkRoot $BrainRoot $HostId 'repos').root
    if(!(Test-Path -LiteralPath $repos -PathType Container)){return $null}
    $files=@(Get-ChildItem -LiteralPath $repos -Directory -ErrorAction SilentlyContinue|ForEach-Object {
            $r=Join-Path $_.FullName 'report'
            if(Test-Path -LiteralPath $r -PathType Container){Get-ChildItem -LiteralPath $r -Directory -Filter '*-runner-run-*' -ErrorAction SilentlyContinue}
        }|ForEach-Object {Join-Path $_.FullName 'status.json'}|Where-Object {Test-Path -LiteralPath $_ -PathType Leaf}|
        Sort-Object {(Get-Item -LiteralPath $_).LastWriteTimeUtc} -Descending|Select-Object -First 40)
    foreach($f in $files){
        $s=Read-SBRunnerStatusFile $f
        if($s -and $s.ContainsKey('quotaObserved') -and $s.quotaObserved -is [hashtable] -and [string]$s.quotaObserved.provider -eq $Provider -and $s.quotaObserved.observedAt){return $s.quotaObserved}
    }
    $null
}
function Get-SBRunnerResumePoint([string]$BrainRoot,[string]$HostId,[string]$Checkout,[string]$Name='latest') {
    # resume.json written by a quota stop for this checkout: the named run folder, or the newest one ('latest'); $null when there is none.
    # Looked up by checkout path, so it works before the repository identity is resolved; a resume point already used is skipped.
    $repos=(Resolve-SBWorkRoot $BrainRoot $HostId 'repos').root
    if(!(Test-Path -LiteralPath $repos -PathType Container)){return $null}
    $want=[IO.Path]::GetFullPath($Checkout).TrimEnd('\','/')
    $files=@(Get-ChildItem -LiteralPath $repos -Directory -ErrorAction SilentlyContinue|ForEach-Object {
            $r=Join-Path $_.FullName 'report'
            if(Test-Path -LiteralPath $r -PathType Container){Get-ChildItem -LiteralPath $r -Directory -Filter '*-runner-run-*' -ErrorAction SilentlyContinue}
        }|Where-Object {$Name -eq 'latest' -or $_.Name -eq $Name}|ForEach-Object {Join-Path $_.FullName 'resume.json'}|Where-Object {Test-Path -LiteralPath $_ -PathType Leaf}|
        Sort-Object {(Get-Item -LiteralPath $_).LastWriteTimeUtc} -Descending)
    foreach($path in $files){
        try{$r=Read-SBText $path|ConvertFrom-Json -AsHashtable -Depth 32 -DateKind String}catch{continue}
        if($r -isnot [hashtable] -or ![string]::Equals(([string]$r.checkout).TrimEnd('\','/'),$want,[StringComparison]::OrdinalIgnoreCase)){continue}
        if($Name -eq 'latest' -and $r.ContainsKey('resumedBy') -and $r.resumedBy){continue}
        $r.path=$path;return $r
    }
    $null
}
function Limit-SBRunnerText([string]$Text,[int]$Max=160) {
    if(!$Text){return ''}
    $line=(($Text -split "`r?`n")|Where-Object {$_.Trim()}|Select-Object -First 1)
    if(!$line){return ''}
    $line=$line.Trim() -replace '\s+',' '
    if($line.Length -gt $Max){$line.Substring(0,$Max-1)+'...'}else{$line}
}
function Get-SBAgentToolSummary([string]$Name,$ToolInput) {
    # Tool name plus the one argument that says what it touches (path, command, pattern); never file contents.
    $detail=''
    if($ToolInput -is [System.Collections.IDictionary]){
        foreach($k in @('file_path','path','command','pattern','url','description','query','skill')){if($ToolInput.Contains($k) -and $ToolInput[$k]){$detail=[string]$ToolInput[$k];break}}
    }
    if($detail){Limit-SBRunnerText ($Name+': '+$detail)}else{Limit-SBRunnerText $Name}
}
function ConvertTo-SBAgentEvent([string]$Line) {
    # One stdout line of a streaming agent CLI (Claude Code and Gemini CLI stream-json, Codex exec --json) to a compact progress record
    # @{kind=start|tool|text|result|error;summary;final}. $null means activity without anything worth showing. Plain text lines are text events.
    if([string]::IsNullOrWhiteSpace($Line)){return $null}
    $o=$null
    try{$o=$Line|ConvertFrom-Json -AsHashtable -Depth 64 -ErrorAction Stop}catch{return @{kind='text';summary=(Limit-SBRunnerText $Line);final=$false}}
    if($o -isnot [System.Collections.IDictionary]){return $null}
    $type=if($o.Contains('type')){[string]$o.type}else{''}
    switch -Regex ($type){
        '^system$' {if($o.Contains('subtype') -and $o.subtype -eq 'init'){return @{kind='start';summary=(Limit-SBRunnerText ('session '+$(if($o.Contains('model')){[string]$o.model}else{''})));final=$false}};return $null}
        '^(init|thread\.started|session\.started)$' {return @{kind='start';summary=(Limit-SBRunnerText ('session '+$(if($o.Contains('model')){[string]$o.model}else{''})));final=$false}}
        '^assistant$' {
            $content=@();if($o.Contains('message') -and $o.message -is [System.Collections.IDictionary] -and $o.message.Contains('content')){$content=@($o.message.content)}
            foreach($c in $content){
                if($c -isnot [System.Collections.IDictionary]){continue}
                if($c.type -eq 'tool_use'){return @{kind='tool';summary=(Get-SBAgentToolSummary ([string]$c.name) $(if($c.Contains('input')){$c.input}));final=$false}}
            }
            foreach($c in $content){if($c -is [System.Collections.IDictionary] -and $c.type -eq 'text' -and $c.text){return @{kind='text';summary=(Limit-SBRunnerText ([string]$c.text));final=$false}}}
            return $null
        }
        '^tool_use$' {return @{kind='tool';summary=(Get-SBAgentToolSummary $(if($o.Contains('tool_name')){[string]$o.tool_name}elseif($o.Contains('name')){[string]$o.name}else{'tool'}) $(if($o.Contains('parameters')){$o.parameters}elseif($o.Contains('input')){$o.input}));final=$false}}
        '^message$' {if($o.Contains('role') -and $o.role -eq 'assistant' -and $o.Contains('content') -and $o.content -is [string]){return @{kind='text';summary=(Limit-SBRunnerText $o.content);final=$false}};return $null}
        '^item\.(started|completed)$' {
            $item=if($o.Contains('item')){$o.item}else{$null}
            if($item -isnot [System.Collections.IDictionary]){return $null}
            $itemType=[string]$item.type
            $started=$type -eq 'item.started'
            switch($itemType){
                'command_execution' {if($started){return @{kind='tool';summary=(Limit-SBRunnerText ('shell: '+[string]$item.command));final=$false}};return $null}
                'file_change' {if(!$started){$paths=@($(if($item.Contains('changes')){@($item.changes)|ForEach-Object {if($_ -is [System.Collections.IDictionary]){[string]$_.path}}}));return @{kind='tool';summary=(Limit-SBRunnerText ('edit: '+($paths -join ', ')));final=$false}};return $null}
                'mcp_tool_call' {if($started){return @{kind='tool';summary=(Limit-SBRunnerText ('mcp: '+[string]$item.server+'.'+[string]$item.tool));final=$false}};return $null}
                'web_search' {if($started){return @{kind='tool';summary=(Limit-SBRunnerText ('web: '+[string]$item.query));final=$false}};return $null}
                'agent_message' {if(!$started -and $item.Contains('text')){return @{kind='text';summary=(Limit-SBRunnerText ([string]$item.text));final=$false}};return $null}
                'error' {return @{kind='error';summary=(Limit-SBRunnerText ([string]$item.message));final=$false}}
                default {return $null}
            }
        }
        '^(turn\.failed|error)$' {
            $msg=if($o.Contains('message')){[string]$o.message}elseif($o.Contains('error') -and $o.error -is [System.Collections.IDictionary] -and $o.error.Contains('message')){[string]$o.error.message}else{$type}
            return @{kind='error';summary=(Limit-SBRunnerText $msg);final=$false}
        }
        '^turn\.completed$' {return @{kind='result';summary='turn completed';final=$true}}
        '^result$' {
            $failed=($o.Contains('is_error') -and [bool]$o.is_error) -or ($o.Contains('status') -and [string]$o.status -notin @('','success'))
            $label=if($o.Contains('subtype') -and $o.subtype){[string]$o.subtype}elseif($o.Contains('status')){[string]$o.status}else{'result'}
            return @{kind=$(if($failed){'error'}else{'result'});summary=(Limit-SBRunnerText $label);final=$true}
        }
        default {return $null}
    }
}
function Get-SBAgentFinalOutput([string]$Text) {
    # The final answer of a streamed run: the last stream-json line of type result; otherwise the whole text (single JSON or plain output).
    if([string]::IsNullOrWhiteSpace($Text)){return $Text}
    $lines=@($Text -split "`r?`n"|Where-Object {$_.Trim()})
    if($lines.Count -le 1){return $Text}
    for($i=$lines.Count-1;$i -ge 0;$i--){
        try{$o=$lines[$i]|ConvertFrom-Json -AsHashtable -Depth 64 -ErrorAction Stop}catch{continue}
        if($o -is [System.Collections.IDictionary] -and $o.Contains('type') -and $o.type -eq 'result'){return $lines[$i]}
    }
    $Text
}
Export-ModuleMember -Function @('Get-SBRunnerRunList','Get-SBRunnerHeartbeatSeconds','Get-SBRunnerRunSlug','Get-SBRunnerReportRoot','Get-SBRunnerStatusFiles','Save-SBRunnerStatus','Add-SBRunnerEventLine','Get-SBProcessStartTicks','Test-SBRunnerProcessAlive','Get-SBRunnerVerdict','Read-SBRunnerStatusFile','Get-SBRunnerStatus','Find-SBActiveRunner','Get-SBRunnerQuotaObservation','Get-SBRunnerResumePoint','Limit-SBRunnerText','ConvertTo-SBAgentEvent','Get-SBAgentFinalOutput')
