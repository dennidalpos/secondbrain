#requires -Version 7.5
# Behavioral fixtures for the team activity register (F6). Synthetic data only; no real dossier is touched.
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Activity.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Host.psm1')
. (Join-Path $PSScriptRoot 'test-helpers.ps1')
$script:actChecks=0
function Assert-Act($Condition,[string]$Message){if(!$Condition){throw ('FAIL ACTIVITY: '+$Message)};$script:actChecks++}
function Reject-Act([scriptblock]$Action,[string]$Message){$rejected=$false;try{& $Action|Out-Null}catch{$rejected=$true};Assert-Act $rejected $Message}
$root=Join-Path (Get-SBTestRoot) ('activity-'+[guid]::NewGuid().ToString('N'))
$brain=Join-Path $root 'brain';$dossier=Join-Path $brain '02-areas/one';$backups=Join-Path $brain '.runtime/backups'
[void][IO.Directory]::CreateDirectory($dossier)
$repo='github.com/acme/one'
$logPath=Join-Path $dossier 'history/activity/report.md'
function New-Rec([string]$n,[string]$user,[string]$when,[string]$task='T-1',[string]$outcome='progress'){
    @{schemaVersion=1;eventId=(Get-SBTextHash $n).Substring(0,32).ToLowerInvariant();user=$user;repository=$repo;taskId=$task;session=('s-'+$n);when=$when;where='C:\work\one';computer='PC1';outcome=$outcome;detail=('detail '+$n)}
}
$ada='SYNTH\ada';$bob='SYNTH\bob "<b>"'
$records=@((New-Rec 'a' $ada '2026-10-02T09:00:00Z'),(New-Rec 'b' $bob '2026-10-15T10:00:00Z' 'T-2' 'started'),(New-Rec 'c' $ada '2026-11-01T11:00:00Z' 'T-1' 'completed'))
$records[2].links=@{commit='abc1234';pr='https://example.test/acme/one/pull/1'}
$config=@{activityLogEnabled=$false}
Assert-Act ((Add-SBActivityRecords $dossier $records $backups $config).state -eq 'preview' -and !(Test-Path (Join-Path $dossier 'history/activity'))) 'preview appends nothing'
Reject-Act {Add-SBActivityRecords $dossier $records $backups $config -Apply} 'real append stays disabled without activation'
Assert-Act (!(Test-Path $logPath)) 'disabled activation leaves no log'
$config.activityLogEnabled=$true
Assert-Act ((Add-SBActivityRecords $dossier $records $backups $config -Apply).added -eq 3) 'activated append writes three records'
$again=Add-SBActivityRecords $dossier $records $backups $config -Apply
Assert-Act ($again.state -eq 'unchanged' -and $again.skipped -eq 3) 'repeated append is idempotent by eventId'
$log=Read-SBActivityLog $dossier
Assert-Act ($log.records.Count -eq 3 -and $log.records[2].links.commit -ceq 'abc1234') 'log reads back with links'
# Validation: negative cases never reach the log.
$logHash=Get-SBFileHash $logPath
$bad=@{}+(New-Rec 'x' $ada '2026-11-02T00:00:00Z');$bad.outcome='weird'
Reject-Act {Add-SBActivityRecords $dossier @($bad) $backups $config -Apply} 'unknown outcome rejected'
$bad=@{}+(New-Rec 'y' $ada 'not-a-date')
Reject-Act {Add-SBActivityRecords $dossier @($bad) $backups $config -Apply} 'invalid date rejected'
$bad=@{}+(New-Rec 'z' $ada '2026-11-02T00:00:00Z');$bad.extra='x'
Reject-Act {Add-SBActivityRecords $dossier @($bad) $backups $config -Apply} 'unknown field rejected'
$bad=@{}+(New-Rec 'w' $ada '2026-11-02T00:00:00Z' 'untracked')
Reject-Act {Add-SBActivityRecords $dossier @($bad) $backups $config -Apply} 'untracked task only for trace source'
$bad=@{}+(New-Rec 'v' $ada '2026-11-02T00:00:00Z');$bad.links=@{pr='javascript:alert(1)'}
Reject-Act {Add-SBActivityRecords $dossier @($bad) $backups $config -Apply} 'non-https PR link rejected'
Assert-Act ((Get-SBFileHash $logPath) -ceq $logHash) 'rejected records leave the log unchanged'
# Corrupt or duplicated log is an error, not silently skipped.
$original=Read-SBText $logPath
[IO.File]::WriteAllText($logPath,$original+"not json`n")
Reject-Act {Read-SBActivityLog $dossier} 'corrupt line is reported'
[IO.File]::WriteAllText($logPath,$original+(($original -split "`n")[0])+"`n")
Reject-Act {Read-SBActivityLog $dossier} 'duplicate eventId is reported'
[IO.File]::WriteAllText($logPath,$original)
# Derived views.
$preview=Save-SBActivityViews $dossier $backups
Assert-Act ($preview.state -eq 'preview' -and !(Test-Path (Join-Path $dossier 'history/activity/index.json'))) 'views preview writes nothing'
$applied=Save-SBActivityViews $dossier $backups -Apply
$index=Read-SBJson (Join-Path $dossier 'history/activity/index.json') $null
Assert-Act ($applied.state -eq 'applied' -and $index.records -eq 3 -and $index.sourceSha256 -ceq (Get-SBFileHash $logPath)) 'index bound to the log hash'
Assert-Act ($index.byUser[$ada].count -eq 2 -and $index.byRepository[$repo].count -eq 3 -and $index.byPeriod['2026-10'].count -eq 2 -and $index.byPeriod['2026-11'].count -eq 1) 'index by user, repository and period'
$mapPath=Join-Path $dossier 'history/activity/map.md'
$map=Read-SBText $mapPath
Assert-Act ($map.StartsWith('<!-- secondbrain:generated') -and $map.Contains('```mermaid') -and !$map.Contains('SYNTH\ada') -and !$map.Contains('<b>') -and $map.Contains('#92;')) 'Mermaid map is generated with escaped labels'
Assert-Act ((Save-SBActivityViews $dossier $backups -Apply).state -eq 'unchanged') 'regeneration is deterministic and idempotent'
[IO.File]::WriteAllText($mapPath,"# manual`n")
Reject-Act {Save-SBActivityViews $dossier $backups -Apply} 'manual map is not overwritten'
[IO.File]::WriteAllText($mapPath,$map)
# Trace import: metadata only, idempotent, task untracked.
$trace=Join-Path $brain ('.runtime/trace/'+(Get-SBHostId));[void][IO.Directory]::CreateDirectory($trace)
$line=@{schemaVersion=1;ts='2026-11-03T08:00:00+00:00';ide='claude-code';sessionId='trace-s1';event='stop';repository=$repo;cwdHash='0123456789abcdef'}|ConvertTo-Json -Compress
$other=@{schemaVersion=1;ts='2026-11-03T08:05:00+00:00';ide='claude-code';sessionId='trace-s2';event='stop';repository='github.com/acme/two';cwdHash='fedcba9876543210'}|ConvertTo-Json -Compress
[IO.File]::WriteAllText((Join-Path $trace '2026-11-03.jsonl'),$line+"`n"+$other+"`nnot json`n")
$fromTrace=@(Get-SBActivityFromTrace $brain $repo $ada 'PC1')
Assert-Act ($fromTrace.Count -eq 1 -and $fromTrace[0].taskId -ceq 'untracked' -and $fromTrace[0].source -ceq 'trace') 'trace turn becomes one metadata-only record for its repository'
$config.activityLogEnabled=$false
Reject-Act {Add-SBActivityRecords $dossier $fromTrace $backups $config -Apply} 'trace import needs activation'
$config.activityLogEnabled=$true
$imported=Add-SBActivityRecords $dossier $fromTrace $backups $config -Apply
$repeat=Add-SBActivityRecords $dossier @(Get-SBActivityFromTrace $brain $repo $ada 'PC1') $backups $config -Apply
Assert-Act ($imported.added -eq 1 -and $repeat.state -eq 'unchanged') 'trace import appends once'
Assert-Act (@(Get-SBActivityFromTrace $brain $repo $ada 'PC1' ([DateTimeOffset]::Parse('2026-11-04T00:00:00Z'))).Count -eq 0) 'Since excludes earlier turns'
# Retention: named records older than 12 months become user-free aggregates, bound to the preview hash.
$asOf=[DateTimeOffset]::Parse('2027-11-15T10:00:00Z')
$beforeHash=Get-SBFileHash $logPath
$plan=Invoke-SBActivityRetention $dossier $asOf $backups
Assert-Act ($plan.state -eq 'preview' -and $plan.expired -eq 4 -and $plan.kept -eq 0 -and (Get-SBFileHash $logPath) -ceq $beforeHash -and !(Test-Path (Join-Path $dossier 'history/activity/retention.json'))) 'retention preview changes nothing'
$asOfPartial=[DateTimeOffset]::Parse('2027-10-20T10:00:00Z')
$partial=Invoke-SBActivityRetention $dossier $asOfPartial $backups
Assert-Act ($partial.expired -eq 2 -and $partial.kept -eq 2) 'cutoff splits records by age'
Reject-Act {Invoke-SBActivityRetention $dossier $asOfPartial $backups -Apply} 'apply without preview hash rejected'
Reject-Act {Invoke-SBActivityRetention $dossier $asOfPartial $backups -Apply -PreviewSha256 $plan.previewSha256} 'apply with the hash of another preview rejected'
Assert-Act ((Get-SBFileHash $logPath) -ceq $beforeHash) 'rejected apply leaves the log unchanged'
$done=Invoke-SBActivityRetention $dossier $asOfPartial $backups -Apply -PreviewSha256 $partial.previewSha256
$after=Read-SBActivityLog $dossier
Assert-Act ($done.state -eq 'applied' -and $after.records.Count -eq 2) 'apply keeps only recent named records'
$aggPath=Join-Path $dossier 'history/activity/retention.json'
$aggText=Read-SBText $aggPath
$agg=Read-SBJson $aggPath $null
Assert-Act ($agg.periods['2026-10'].records -eq 2 -and $agg.periods['2026-10'].byRepository[$repo].progress -eq 1 -and $agg.periods['2026-10'].byRepository[$repo].started -eq 1 -and !$aggText.Contains('SYNTH') -and !$aggText.Contains('ada') -and !$aggText.Contains('detail')) 'aggregate holds counts by period, repository and outcome without user or detail'
Assert-Act ((Invoke-SBActivityRetention $dossier $asOfPartial $backups).state -eq 'unchanged') 'retention is idempotent'
$later=Invoke-SBActivityRetention $dossier $asOf $backups
[void](Invoke-SBActivityRetention $dossier $asOf $backups -Apply -PreviewSha256 $later.previewSha256)
$agg=Read-SBJson $aggPath $null
Assert-Act ($agg.periods['2026-10'].records -eq 2 -and $agg.periods['2026-11'].records -eq 2 -and @($agg.periods.Keys).Count -eq 2) 'later runs merge into the existing aggregate'
Assert-Act ((Save-SBActivityViews $dossier $backups -Apply).records -eq 0) 'derived views still regenerate after retention'
# Crash between the two writes: the aggregate already covers this input log, so a re-run must not count twice.
[IO.File]::WriteAllText($logPath,(($records|ForEach-Object {ConvertTo-SBStableValue $_|ConvertTo-Json -Depth 8 -Compress}) -join "`n")+"`n")
Remove-Item $aggPath
$crash=Invoke-SBActivityRetention $dossier $asOf $backups
$crashLogHash=Get-SBFileHash $logPath
$pending=[ordered]@{schemaVersion=1;generated=$true;retentionMonths=12;inputLogSha256=$crashLogHash;periods=[ordered]@{'2026-10'=[ordered]@{records=2;byRepository=[ordered]@{$repo=[ordered]@{progress=1;started=1}}};'2026-11'=[ordered]@{records=1;byRepository=[ordered]@{$repo=[ordered]@{completed=1}}}}}
[IO.File]::WriteAllText($aggPath,(ConvertTo-SBJson $pending))
$resumed=Invoke-SBActivityRetention $dossier $asOf $backups -Apply -PreviewSha256 $crash.previewSha256
$agg=Read-SBJson $aggPath $null
Assert-Act ($resumed.resumed -and $agg.periods['2026-10'].records -eq 2 -and (Read-SBActivityLog $dossier).records.Count -eq 0) 'resume after a partial run does not double count'
# #367: register writes keep no binary copy of named records; legacy backups are reviewed and removed only when recoverable.
$activityRoot=Join-Path $dossier 'history/activity'
$registerFiles=@('report.md','index.json','map.md'|ForEach-Object {[IO.Path]::GetFullPath((Join-Path $activityRoot $_))})
$registerBackups={@(Get-ChildItem -LiteralPath $backups -File -Filter '*.bin.json' -ErrorAction SilentlyContinue|Where-Object {[IO.Path]::GetFullPath([string](Read-SBJson $_.FullName $null).path) -in $registerFiles})}
Assert-Act ((& $registerBackups).Count -eq 0) 'append, views and retention take no binary backup of the register'
$oldRec=New-Rec 'old' $ada '2026-10-05T09:00:00Z';$newRec=New-Rec 'new' $bob '2027-10-10T09:00:00Z' 'T-3' 'completed';$lost=New-Rec 'lost' $ada '2027-09-01T09:00:00Z'
$line={param($r) (ConvertTo-SBStableValue $r|ConvertTo-Json -Depth 8 -Compress)+"`n"}
[IO.File]::WriteAllText($logPath,(& $line $oldRec)+(& $line $newRec))
[void](Save-SBActivityViews $dossier $backups -Apply)
$legacy={param([string]$target,[string]$text,[string]$previous)
    $bin=Join-Path $backups ([guid]::NewGuid().ToString('N')+'.bin');[IO.File]::WriteAllText($bin,$text,[Text.UTF8Encoding]::new($false))
    $hash=if($previous){$previous}else{Get-SBFileHash $bin}
    [IO.File]::WriteAllText($bin+'.json',(ConvertTo-SBJson @{path=$target;previousHash=$hash;deployedHash=('0'*64);backup=$bin}),[Text.UTF8Encoding]::new($false));$bin}
$b1=& $legacy $logPath ((& $line $oldRec)+(& $line $newRec))
$b2=& $legacy $logPath (& $line $lost)
$b3=& $legacy (Join-Path $activityRoot 'index.json') (Read-SBText (Join-Path $activityRoot 'index.json'))
$b4=& $legacy $logPath (& $line $oldRec) ('f'*64)
$other=& $legacy (Join-Path $dossier 'tracker.json') '{}'
$stale=Join-Path $activityRoot ('.secondbrain-'+[guid]::NewGuid().ToString('N')+'.recovery');[IO.File]::WriteAllText($stale,(& $line $oldRec))
$asOf367=[DateTimeOffset]::Parse('2027-11-15T10:00:00Z')
$early=Invoke-SBActivityBackupRetention $dossier $asOf367 $backups
Reject-Act {Invoke-SBActivityBackupRetention $dossier $asOf367 $backups -Apply -PreviewSha256 $early.previewSha256} 'backup removal refused while expired records are still in the log'
$ret=Invoke-SBActivityRetention $dossier $asOf367 $backups
$applied367=Invoke-SBActivityRetention $dossier $asOf367 $backups -Apply -PreviewSha256 $ret.previewSha256
$indexText=Read-SBText (Join-Path $activityRoot 'index.json')
Assert-Act ($applied367.expired -eq 1 -and $applied367.views -eq 'applied' -and !$indexText.Contains('ada') -and !$indexText.Contains($oldRec.eventId)) 'retention regenerates views without expired users or events'
Assert-Act ((& $registerBackups).Count -eq 4) 'retention adds no backup with expired records'
$review=Invoke-SBActivityBackupRetention $dossier $asOf367 $backups
$byPath={param([object[]]$list,[string]$file) $wanted=[IO.Path]::GetFullPath($file);$found=@();foreach($item in $list){if([IO.Path]::GetFullPath([string]$item['backup']) -ceq $wanted){$found+=,$item}};,$found}
Assert-Act ($review.state -eq 'preview' -and $review.candidates.Count -eq 2 -and (& $byPath $review.candidates $b1).Count -eq 1 -and (& $byPath $review.candidates $b3)[0].reason -eq 'regenerable') 'review selects only recoverable register backups'
Assert-Act ($review.blocked.Count -eq 3 -and (& $byPath $review.blocked $b2)[0].reason -eq 'record-not-in-log' -and (& $byPath $review.blocked $b4)[0].reason -eq 'hash' -and (& $byPath $review.blocked $stale)[0].reason -eq 'incomplete-transaction') 'unrecoverable, unverified and interrupted items are blocked'
Assert-Act ((Test-Path $b1) -and (Test-Path $b3)) 'review deletes nothing'
Reject-Act {Invoke-SBActivityBackupRetention $dossier $asOf367 $backups -Apply} 'backup removal without preview hash rejected'
Reject-Act {Invoke-SBActivityBackupRetention $dossier $asOf367 $backups -Apply -PreviewSha256 $early.previewSha256} 'backup removal with a stale preview hash rejected'
[IO.File]::AppendAllText($b3,' ')
Reject-Act {Invoke-SBActivityBackupRetention $dossier $asOf367 $backups -Apply -PreviewSha256 $review.previewSha256} 'backup changed after the preview is not removed'
[IO.File]::WriteAllText($b3,(Read-SBText $b3).TrimEnd(' '))
$removed=Invoke-SBActivityBackupRetention $dossier $asOf367 $backups -Apply -PreviewSha256 $review.previewSha256
Assert-Act ($removed.removed -eq 2 -and !(Test-Path $b1) -and !(Test-Path ($b1+'.json')) -and !(Test-Path $b3) -and (Test-Path $b2) -and (Test-Path $b4) -and (Test-Path $other) -and (Test-Path $stale)) 'apply removes exactly the reviewed pairs and keeps the rest'
Assert-Act ((Invoke-SBActivityBackupRetention $dossier $asOf367 $backups).state -eq 'unchanged' -and (Read-SBActivityLog $dossier).records.Count -eq 1) 'backup review is idempotent and the log is intact'
'SUCCESS ACTIVITY: '+$script:actChecks+' checks; retained fixture '+$root
