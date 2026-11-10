#requires -Version 7.5
# Team activity register (F6): append-only JSONL in <dossier>/history/activity/report.md,
# with derived index.json and map.md (Mermaid) that are always regenerated, never edited by hand.
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Host.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Add-SBMessages @{
    'activity.invalid' = @{it='Registro attività: dato non valido ({0})';en='Activity register: invalid data ({0})'}
    'activity.disabled' = @{it='Registro attività reale disabilitato: completare la procedura di attivazione F6/F11; nessuna scrittura';en='Real activity register disabled: complete F6/F11 activation procedure; no write'}
}
$script:SBActivityOutcomes=@('started','progress','completed','blocked','failed')
$script:SBActivityFields=@('schemaVersion','eventId','user','repository','taskId','session','when','where','computer','outcome','detail','links','source','parent','agent')
$script:SBActivityGenerated='<!-- secondbrain:generated activity-register; do not edit by hand -->'

function Get-SBActivityPaths([string]$Dossier) {
    $root=Join-Path $Dossier 'history/activity'
    @{root=$root;log=(Join-Path $root 'report.md');index=(Join-Path $root 'index.json');map=(Join-Path $root 'map.md');retention=(Join-Path $root 'retention.json')}
}

function Test-SBActivityRecord($Record) {
    $fail={param($why) throw (New-SBError 'activity.invalid' @($why))}
    if($Record -isnot [Collections.IDictionary]){& $fail 'record'}
    foreach($key in $Record.Keys){if($key -cnotin $script:SBActivityFields){& $fail ('field '+$key)}}
    foreach($key in 'schemaVersion','eventId','user','repository','taskId','session','when','where','computer','outcome','detail'){
        if(!$Record.ContainsKey($key)){& $fail ('missing '+$key)}
    }
    if($Record.schemaVersion -ne 1){& $fail 'schemaVersion'}
    if($Record.eventId -isnot [string] -or $Record.eventId -cnotmatch '^[a-f0-9]{32}$'){& $fail 'eventId'}
    foreach($key in 'user','taskId','session','where','computer','detail'){
        if($Record[$key] -isnot [string] -or [string]::IsNullOrWhiteSpace($Record[$key]) -or $Record[$key].Length -gt 8192){& $fail $key}
    }
    if($Record.repository -isnot [string] -or !(Test-SBRepositoryIdentity $Record.repository)){& $fail 'repository'}
    if($Record.outcome -cnotin $script:SBActivityOutcomes){& $fail 'outcome'}
    $when=[DateTimeOffset]::MinValue
    if($Record.when -isnot [string] -or ![DateTimeOffset]::TryParse($Record.when,[ref]$when)){& $fail 'when'}
    $source=if($Record.ContainsKey('source')){$Record.source}else{'mcp'}
    if($source -cnotin @('mcp','trace')){& $fail 'source'}
    if($Record.taskId -ceq 'untracked' -and $source -cne 'trace'){& $fail 'untracked task'}
    # Subagent jobs (F8): parent session and agent name travel together; the parent is checked against the log on append.
    if($Record.ContainsKey('parent') -ne $Record.ContainsKey('agent')){& $fail 'parent and agent go together'}
    if($Record.ContainsKey('parent')){
        if($Record.parent -isnot [string] -or $Record.parent -cnotmatch '^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$' -or $Record.parent -ceq $Record.session){& $fail 'parent'}
        if($Record.agent -isnot [string] -or $Record.agent -cnotmatch '^[a-z0-9][a-z0-9-]{0,63}$'){& $fail 'agent'}
        if($source -cne 'mcp'){& $fail 'subagent source'}
    }
    if($Record.ContainsKey('links')){
        $links=$Record.links
        if($links -isnot [Collections.IDictionary]){& $fail 'links'}
        foreach($key in $links.Keys){if($key -cnotin @('commit','pr')){& $fail ('link '+$key)}}
        if($links.Contains('commit') -and ($links.commit -isnot [string] -or $links.commit -cnotmatch '^[a-f0-9]{7,40}$')){& $fail 'link commit'}
        if($links.Contains('pr') -and ($links.pr -isnot [string] -or $links.pr -cnotmatch '^https://[^\s<>"]{1,500}$')){& $fail 'link pr'}
    }
    $true
}

function Read-SBActivityLog([string]$Dossier) {
    $paths=Get-SBActivityPaths $Dossier
    Assert-SBPlainPath $paths.log
    $hash=Get-SBFileHash $paths.log
    $records=@();$seen=@{}
    if($hash -ne 'absent'){
        $number=0
        foreach($line in (Read-SBText $paths.log) -split "`n"){
            $number++
            if([string]::IsNullOrWhiteSpace($line)){continue}
            try{$record=$line|ConvertFrom-Json -AsHashtable -DateKind String -ErrorAction Stop}catch{throw (New-SBError 'activity.invalid' @('line '+$number))}
            [void](Test-SBActivityRecord $record)
            if($seen.ContainsKey($record.eventId)){throw (New-SBError 'activity.invalid' @('duplicate eventId line '+$number))}
            $seen[$record.eventId]=$true;$records+=,$record
        }
    }
    @{path=$paths.log;hash=$hash;records=$records}
}

function New-SBActivityIndex($Log) {
    $sorted=@($Log.records|Sort-Object @{Expression={[DateTimeOffset]::Parse($_.when).UtcDateTime}},@{Expression={$_.eventId}})
    $group={param($selector)
        $result=[ordered]@{}
        foreach($name in @($sorted|ForEach-Object {& $selector $_}|Sort-Object -Unique)){
            $items=@($sorted|Where-Object {(& $selector $_) -ceq $name})
            $result[$name]=[ordered]@{count=$items.Count;lastWhen=[DateTimeOffset]::Parse($items[-1].when).ToUniversalTime().ToString('o');eventIds=@($items|ForEach-Object eventId)}
        }
        $result
    }
    [ordered]@{schemaVersion=1;generated=$true;sourceSha256=$Log.hash;records=$sorted.Count;
        byRepository=(& $group {param($r) $r.repository});byUser=(& $group {param($r) $r.user});
        byPeriod=(& $group {param($r) [DateTimeOffset]::Parse($r.when).ToUniversalTime().ToString('yyyy-MM')})}
}

function ConvertTo-SBMermaidLabel([string]$Text) {
    # Mermaid labels sit in quotes: neutralize quotes, brackets, markup and backslashes with entity codes.
    $out=[Text.StringBuilder]::new()
    foreach($ch in $Text.ToCharArray()){
        if($ch -in '"','<','>','[',']','{','}','(',')','|','\','`','#',';','&'){[void]$out.Append('#'+[int][char]$ch+';')}else{[void]$out.Append($ch)}
    }
    $out.ToString()
}
function Get-SBMermaidId([string]$Prefix,[string]$Text) { $Prefix+(Get-SBTextHash $Text).Substring(0,8).ToLowerInvariant() }

function New-SBActivityMap($Log,$Index,[int]$MaxEdges=40) {
    $sb=[Text.StringBuilder]::new()
    [void]$sb.AppendLine($script:SBActivityGenerated)
    [void]$sb.AppendLine('# Activity map')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('Source: `report.md` (sha256 `'+$Index.sourceSha256+'`), '+$Index.records+' records. Regenerate with `scripts/activity.ps1 -Operation Index -Apply`.')
    [void]$sb.AppendLine()
    $edges=[ordered]@{}
    foreach($record in $Log.records){
        $key=$record.user+"`n"+$record.repository+"`n"+$record.taskId
        if(!$edges.Contains($key)){$edges[$key]=@{user=$record.user;repository=$record.repository;task=$record.taskId;count=0;last='';outcome=''}}
        $edges[$key].count++
        $when=[DateTimeOffset]::Parse($record.when).UtcDateTime
        if(!$edges[$key].last -or $when -ge [DateTimeOffset]::Parse($edges[$key].last).UtcDateTime){$edges[$key].last=$record.when;$edges[$key].outcome=$record.outcome}
    }
    $ordered=@($edges.Values|Sort-Object @{Expression={$_.count};Descending=$true},@{Expression={$_.user}},@{Expression={$_.repository}},@{Expression={$_.task}})
    $shown=@($ordered|Select-Object -First $MaxEdges)
    [void]$sb.AppendLine('```mermaid')
    [void]$sb.AppendLine('flowchart LR')
    $declared=@{}
    foreach($edge in $shown){
        $u=Get-SBMermaidId 'u' $edge.user;$r=Get-SBMermaidId 'r' $edge.repository;$t=Get-SBMermaidId 't' ($edge.repository+"`n"+$edge.task)
        if(!$declared.ContainsKey($u)){[void]$sb.AppendLine('    '+$u+'["'+(ConvertTo-SBMermaidLabel $edge.user)+'"]');$declared[$u]=1}
        if(!$declared.ContainsKey($r)){[void]$sb.AppendLine('    '+$r+'[["'+(ConvertTo-SBMermaidLabel $edge.repository)+'"]]');$declared[$r]=1}
        if(!$declared.ContainsKey($t)){[void]$sb.AppendLine('    '+$t+'("'+(ConvertTo-SBMermaidLabel $edge.task)+'")');$declared[$t]=1}
        [void]$sb.AppendLine('    '+$u+' -->|"'+$edge.count+' ('+(ConvertTo-SBMermaidLabel $edge.outcome)+')"| '+$t)
        [void]$sb.AppendLine('    '+$r+' --- '+$t)
    }
    [void]$sb.AppendLine('```')
    if($ordered.Count -gt $shown.Count){[void]$sb.AppendLine();[void]$sb.AppendLine('Showing '+$shown.Count+' of '+$ordered.Count+' user/task links; the full list is in `index.json`.')}
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('| Period | Records |')
    [void]$sb.AppendLine('|---|---|')
    foreach($period in $Index.byPeriod.Keys){[void]$sb.AppendLine('| '+$period+' | '+$Index.byPeriod[$period].count+' |')}
    $sb.ToString().Replace("`r`n","`n")
}

# Derived files only: the log itself is never rewritten here.
function Save-SBActivityViews([string]$Dossier,[string]$BackupRoot,[switch]$Apply) {
    $paths=Get-SBActivityPaths $Dossier
    $log=Read-SBActivityLog $Dossier
    if($log.hash -eq 'absent'){throw (New-SBError 'activity.invalid' @('log absent'))}
    $index=New-SBActivityIndex $log
    $files=@(@{path=$paths.index;bytes=[Text.UTF8Encoding]::new($false).GetBytes((ConvertTo-SBJson $index))},
             @{path=$paths.map;bytes=[Text.UTF8Encoding]::new($false).GetBytes((New-SBActivityMap $log $index))})
    $changed=@()
    foreach($file in $files){
        Assert-SBPlainPath $file.path
        $current=Get-SBFileHash $file.path
        if($current -ne 'absent' -and $file.path -ceq $paths.map -and !(Read-SBText $file.path).StartsWith($script:SBActivityGenerated)){throw (New-SBError 'activity.invalid' @('map not generated'))}
        if($current -ne (Get-SBHash $file.bytes)){$changed+=,$file}
    }
    if($Apply -and $changed.Count){
        [void][IO.Directory]::CreateDirectory($paths.root)
        # #367: views are regenerable from the log, so no binary copy of named data is kept in backups.
        foreach($file in $changed){[void](Write-SBFile $file.path $file.bytes (Get-SBFileHash $file.path) $BackupRoot -Recoverable)}
    }
    @{state=$(if(!$changed.Count){'unchanged'}elseif($Apply){'applied'}else{'preview'});records=$index.records;changed=@($changed|ForEach-Object {Split-Path $_.path -Leaf});sourceSha256=$log.hash}
}

# Append new records (idempotent by eventId). Real writes stay behind the explicit activation flag of the configuration.
function Add-SBActivityRecords([string]$Dossier,$Records,[string]$BackupRoot,$Config,[switch]$Apply) {
    $paths=Get-SBActivityPaths $Dossier
    $log=Read-SBActivityLog $Dossier
    $known=@{};$sessions=@{}
    foreach($record in $log.records){$known[$record.eventId]=$true;$sessions[$record.repository+"`n"+$record.session]=$true}
    $new=@()
    foreach($record in @($Records)){
        [void](Test-SBActivityRecord $record)
        if($known.ContainsKey($record.eventId)){continue}
        if($record.ContainsKey('parent') -and !$sessions.ContainsKey($record.repository+"`n"+$record.parent)){throw (New-SBError 'activity.invalid' @('unknown parent session'))}
        $known[$record.eventId]=$true;$sessions[$record.repository+"`n"+$record.session]=$true;$new+=,$record
    }
    if($Apply -and $new.Count){
        if($null -eq $Config -or $Config -isnot [Collections.IDictionary] -or !$Config.ContainsKey('activityLogEnabled') -or $Config.activityLogEnabled -ne $true){throw (New-SBError 'activity.disabled')}
        $existing=if($log.hash -eq 'absent'){''}else{Read-SBText $paths.log}
        if($existing -and !$existing.EndsWith("`n")){$existing+="`n"}
        $added=($new|ForEach-Object {(ConvertTo-SBStableValue $_|ConvertTo-Json -Depth 8 -Compress)+"`n"}) -join ''
        $bytes=[Text.UTF8Encoding]::new($false).GetBytes($existing+$added)
        # #367: an append keeps the previous log as an exact prefix (plus at most a final newline), so the
        # previous content stays recoverable from the log itself and no binary backup with named records is taken.
        $previous=if($log.hash -eq 'absent'){''}else{Read-SBText $paths.log}
        if(!($existing+$added).StartsWith($previous,[StringComparison]::Ordinal)){throw (New-SBError 'activity.invalid' @('append prefix'))}
        [void][IO.Directory]::CreateDirectory($paths.root)
        [void](Write-SBFile $paths.log $bytes $log.hash $BackupRoot -Recoverable)
    }
    @{state=$(if(!$new.Count){'unchanged'}elseif($Apply){'appended'}else{'preview'});added=$new.Count;skipped=@($Records).Count-$new.Count}
}

# Trace -> register: metadata-only Stop lines (already written only with per-turn persistence) become 'progress' records
# without task. The deterministic eventId makes repeated imports idempotent.
function Get-SBActivityFromTrace([string]$BrainRoot,[string]$Repository,[string]$User,[string]$Computer,[DateTimeOffset]$Since=[DateTimeOffset]::MinValue) {
    $root=Join-Path ([IO.Path]::GetFullPath($BrainRoot)) '.runtime/trace'
    $records=@()
    if(!(Test-SBRepositoryIdentity $Repository) -or !(Test-Path -LiteralPath $root -PathType Container)){return $records}
    foreach($file in Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.jsonl' -Force|Sort-Object FullName){
        foreach($line in [IO.File]::ReadLines($file.FullName)){
            if(!$line.Contains($Repository)){continue}
            try{$entry=$line|ConvertFrom-Json -AsHashtable -DateKind String -ErrorAction Stop}catch{continue}
            if($entry -isnot [Collections.IDictionary] -or $entry.event -cne 'stop' -or $entry.repository -cne $Repository){continue}
            $when=[DateTimeOffset]::MinValue
            if(![DateTimeOffset]::TryParse([string]$entry.ts,[ref]$when) -or $when -le $Since){continue}
            $session=[string]$entry.sessionId;if([string]::IsNullOrWhiteSpace($session)){$session='unknown'}
            $cwdHash=[string]$entry.cwdHash;if([string]::IsNullOrWhiteSpace($cwdHash)){$cwdHash='unknown'}
            $key=(Get-SBHostId)+"`n"+$Repository+"`n"+$session+"`n"+$when.ToUniversalTime().ToString('o')
            $records+=,@{schemaVersion=1;eventId=(Get-SBTextHash $key).Substring(0,32).ToLowerInvariant();user=$User;repository=$Repository;taskId='untracked';session=$session;
                when=$when.ToUniversalTime().ToString('o');where=('trace:'+$cwdHash);computer=$Computer;outcome='progress';detail='turn ended (trace)';source='trace'}
        }
    }
    $records
}
# Retention (#361/#363): named records older than the window are replaced by aggregates without user.
# Aggregates (retention.json) hold counts by period, repository and outcome only. The log is rewritten once, bound to a preview hash.
function Get-SBActivityRetentionPlan([string]$Dossier,[DateTimeOffset]$AsOf,[int]$Months=12) {
    if($Months -lt 1){throw (New-SBError 'activity.invalid' @('months'))}
    $paths=Get-SBActivityPaths $Dossier
    $log=Read-SBActivityLog $Dossier
    $cutoff=[DateTimeOffset]::new($AsOf.UtcDateTime.Date,[TimeSpan]::Zero).AddMonths(-$Months)
    $expired=@($log.records|Where-Object {[DateTimeOffset]::Parse($_.when) -lt $cutoff})
    $kept=@($log.records|Where-Object {[DateTimeOffset]::Parse($_.when) -ge $cutoff})
    $previewHash=Get-SBTextHash ($log.hash+'|'+$cutoff.ToString('o')+'|'+$expired.Count)
    @{paths=$paths;log=$log;cutoff=$cutoff;expired=$expired;kept=$kept;months=$Months;previewSha256=$previewHash}
}

function Invoke-SBActivityRetention([string]$Dossier,[DateTimeOffset]$AsOf,[string]$BackupRoot,[int]$Months=12,[switch]$Apply,[string]$PreviewSha256) {
    $plan=Get-SBActivityRetentionPlan $Dossier $AsOf $Months
    $paths=$plan.paths
    $aggregate=[ordered]@{schemaVersion=1;generated=$true;retentionMonths=$Months;inputLogSha256='';periods=[ordered]@{}}
    $existingHash=Get-SBFileHash $paths.retention
    if($existingHash -ne 'absent'){
        $current=Read-SBJson $paths.retention $null
        if($current -isnot [Collections.IDictionary] -or $current.schemaVersion -ne 1 -or !$current.generated){throw (New-SBError 'activity.invalid' @('retention file'))}
        $aggregate=[ordered]@{schemaVersion=1;generated=$true;retentionMonths=$Months;inputLogSha256=[string]$current.inputLogSha256;periods=$current.periods}
    }
    # Resume after a crash between the two writes: the aggregate already covers this exact input log.
    $resume=$aggregate.inputLogSha256 -ceq $plan.log.hash -and $plan.log.hash -ne 'absent'
    $state='unchanged'
    if($plan.expired.Count){
        $state=if($Apply){'applied'}else{'preview'}
    }
    $result=@{state=$state;expired=$plan.expired.Count;kept=$plan.kept.Count;cutoff=$plan.cutoff.ToString('o');previewSha256=$plan.previewSha256;resumed=$false}
    if(!$Apply -or !$plan.expired.Count){return $result}
    if([string]::IsNullOrEmpty($PreviewSha256) -or $PreviewSha256 -cne $plan.previewSha256){throw (New-SBError 'activity.invalid' @('preview hash'))}
    if(!$resume){
        $periods=[ordered]@{}
        foreach($key in $aggregate.periods.Keys){$periods[$key]=$aggregate.periods[$key]}
        foreach($record in $plan.expired){
            $period=[DateTimeOffset]::Parse($record.when).ToUniversalTime().ToString('yyyy-MM')
            if(!$periods.Contains($period)){$periods[$period]=[ordered]@{records=0;byRepository=[ordered]@{}}}
            $entry=$periods[$period];$entry.records=[int]$entry.records+1
            if(!$entry.byRepository.Contains($record.repository)){$entry.byRepository[$record.repository]=[ordered]@{}}
            $outcomes=$entry.byRepository[$record.repository]
            $outcomes[$record.outcome]=$(if($outcomes.Contains($record.outcome)){[int]$outcomes[$record.outcome]+1}else{1})
        }
        $aggregate.periods=$periods;$aggregate.inputLogSha256=$plan.log.hash
        [void][IO.Directory]::CreateDirectory($paths.root)
        [void](Write-SBFile $paths.retention ([Text.UTF8Encoding]::new($false).GetBytes((ConvertTo-SBJson $aggregate))) $existingHash $BackupRoot)
    }
    $text=($plan.kept|ForEach-Object {(ConvertTo-SBStableValue $_|ConvertTo-Json -Depth 8 -Compress)+"`n"}) -join ''
    # #367: the expired named records must not survive in a new binary backup; the preview hash binds the rewrite.
    [void](Write-SBFile $paths.log ([Text.UTF8Encoding]::new($false).GetBytes($text)) $plan.log.hash $BackupRoot -Recoverable)
    # Derived views still list users and eventIds of expired records: regenerate them when they exist.
    $result.views=$null
    if((Get-SBFileHash $paths.index) -ne 'absent' -or (Get-SBFileHash $paths.map) -ne 'absent'){$result.views=(Save-SBActivityViews $Dossier $BackupRoot -Apply).state}
    $result.resumed=$resume
    $result
}

# Backups taken before #367 (or by other writers) may still hold named records past the window.
# Review lists register backups (.bin with .bin.json metadata in backupRoot) whose content is recoverable without them:
# index/map copies are regenerable; a log copy qualifies only if each record is expired or present unchanged in the current log.
# Anything else, and leftover .recovery files of an interrupted write, is kept and reported as blocked.
function Get-SBActivityBackupPlan([string]$Dossier,[DateTimeOffset]$AsOf,[string]$BackupRoot,[int]$Months=12) {
    $plan=Get-SBActivityRetentionPlan $Dossier $AsOf $Months
    $paths=$plan.paths
    $targets=@{}
    foreach($key in 'log','index','map'){$targets[[IO.Path]::GetFullPath($paths[$key])]=$key}
    $current=@{}
    foreach($record in $plan.log.records){$current[$record.eventId]=(ConvertTo-SBStableValue $record|ConvertTo-Json -Depth 8 -Compress)}
    $candidates=@();$blocked=@()
    $root=if($BackupRoot){[IO.Path]::GetFullPath($BackupRoot)}else{''}
    if($root -and (Test-Path -LiteralPath $root -PathType Container)){
        foreach($meta in @(Get-ChildItem -LiteralPath $root -File -Filter '*.bin.json'|Sort-Object Name)){
            if($meta.Name -cnotmatch '^[0-9a-f]{32}\.bin\.json$' -or ($meta.Attributes -band [IO.FileAttributes]::ReparsePoint)){continue}
            $info=$null
            try{$info=Read-SBJson $meta.FullName $null}catch{}
            if($info -isnot [Collections.IDictionary] -or $info.path -isnot [string] -or [string]::IsNullOrWhiteSpace($info.path)){continue}
            $target=$null
            try{$target=$targets[[IO.Path]::GetFullPath($info.path)]}catch{}
            if(!$target){continue}
            $bin=$meta.FullName.Substring(0,$meta.FullName.Length-5)
            $entry=[ordered]@{backup=$bin;metadata=$meta.FullName;target=$target;sha256=(Get-SBFileHash $bin);metadataSha256=(Get-SBFileHash $meta.FullName)}
            if($entry.sha256 -eq 'absent' -or $entry.sha256 -cne [string]$info.previousHash){$entry.reason='hash';$blocked+=,$entry;continue}
            if($target -ne 'log'){$entry.reason='regenerable';$candidates+=,$entry;continue}
            $reason='expired-or-in-log'
            foreach($line in ([IO.File]::ReadAllText($bin,[Text.UTF8Encoding]::new($false)) -split "`n")){
                if([string]::IsNullOrWhiteSpace($line)){continue}
                $record=$null
                try{$record=$line|ConvertFrom-Json -AsHashtable -DateKind String -ErrorAction Stop;[void](Test-SBActivityRecord $record)}catch{$reason='unreadable';break}
                if([DateTimeOffset]::Parse($record.when) -lt $plan.cutoff){continue}
                if(!$current.ContainsKey($record.eventId) -or $current[$record.eventId] -cne (ConvertTo-SBStableValue $record|ConvertTo-Json -Depth 8 -Compress)){$reason='record-not-in-log';break}
            }
            $entry.reason=$reason
            if($reason -eq 'expired-or-in-log'){$candidates+=,$entry}else{$blocked+=,$entry}
        }
    }
    if(Test-Path -LiteralPath $paths.root -PathType Container){
        foreach($file in @(Get-ChildItem -LiteralPath $paths.root -File -Force -Filter '.secondbrain-*.recovery'|Sort-Object Name)){
            $blocked+=,[ordered]@{backup=$file.FullName;target='recovery';sha256=(Get-SBFileHash $file.FullName);reason='incomplete-transaction'}
        }
    }
    $binding=($candidates|ForEach-Object {$_.backup+'|'+$_.sha256+'|'+$_.metadataSha256}) -join "`n"
    $previewHash=Get-SBTextHash ($plan.log.hash+'|'+$plan.cutoff.ToString('o')+'|'+$binding)
    @{cutoff=$plan.cutoff;expiredInLog=$plan.expired.Count;candidates=$candidates;blocked=$blocked;previewSha256=$previewHash}
}

function Invoke-SBActivityBackupRetention([string]$Dossier,[DateTimeOffset]$AsOf,[string]$BackupRoot,[int]$Months=12,[switch]$Apply,[string]$PreviewSha256) {
    $plan=Get-SBActivityBackupPlan $Dossier $AsOf $BackupRoot $Months
    $state=if(!$plan.candidates.Count){'unchanged'}elseif($Apply){'applied'}else{'preview'}
    $result=@{state=$state;cutoff=$plan.cutoff.ToString('o');expiredInLog=$plan.expiredInLog;candidates=@($plan.candidates);blocked=@($plan.blocked);previewSha256=$plan.previewSha256;removed=0}
    if(!$Apply -or !$plan.candidates.Count){return $result}
    if([string]::IsNullOrEmpty($PreviewSha256) -or $PreviewSha256 -cne $plan.previewSha256){throw (New-SBError 'activity.invalid' @('preview hash'))}
    # Expired records still in the log would make removal pointless: run Retention first.
    if($plan.expiredInLog){throw (New-SBError 'activity.invalid' @('retention pending'))}
    foreach($entry in $plan.candidates){
        Assert-SBWriteGuard
        if((Get-SBFileHash $entry.backup) -cne $entry.sha256 -or (Get-SBFileHash $entry.metadata) -cne $entry.metadataSha256){throw (New-SBError 'activity.invalid' @('backup changed'))}
        [IO.File]::Delete($entry.backup);[IO.File]::Delete($entry.metadata)
        $result.removed++
    }
    $result
}
Export-ModuleMember -Function @('Get-SBActivityRetentionPlan','Invoke-SBActivityRetention','Get-SBActivityBackupPlan','Invoke-SBActivityBackupRetention','Get-SBActivityPaths','Test-SBActivityRecord','Read-SBActivityLog','New-SBActivityIndex','New-SBActivityMap','Save-SBActivityViews','Add-SBActivityRecords','Get-SBActivityFromTrace')
