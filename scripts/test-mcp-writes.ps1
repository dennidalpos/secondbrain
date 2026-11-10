# Included by essential/pending. Separate synthetic brain, checkout, approvals and queue.
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.McpWrites.psm1')
$f5Root=Join-Path $fixture 'mcp-writes'
$f5Brain=Join-Path $f5Root 'brain';$f5Repo=Join-Path $f5Root 'checkout';$f5Id='github.com/test/f5'
$f5Dossier=Join-Path $f5Brain '02-areas/products/F5'
foreach($dir in @((Join-Path $f5Brain scripts),$f5Repo)){[void][IO.Directory]::CreateDirectory($dir)}
Get-ChildItem -LiteralPath (Join-Path $brain scripts) -File|Copy-Item -Destination (Join-Path $f5Brain scripts)
foreach($path in 'config/shared.json','config/tracker.schema.json','direttive/approved.json','direttive/AGENTS.global_ide.md','direttive/workstation.template.md','VERSION'){
    Put (Join-Path $f5Brain $path) (Read-SBText (Join-Path $brain $path))
}
Put (Join-Path $f5Dossier para.json) (ConvertTo-SBJson @{schemaVersion=1;id='f5-area';kind='area';title='F5';status='active'})
Put (Join-Path $f5Dossier repository.json) (ConvertTo-SBJson @{schemaVersion=1;identity=$f5Id;tracker=@{location='dossier';path='tracker.json';schemaVersion=1}})
Put (Join-Path $f5Dossier brief.md) '# Synthetic F5'
Put (Join-Path $f5Dossier memory.md) "# Memory`n"
Put (Join-Path $f5Dossier context.md) "# Context`n"
Put (Join-Path $f5Dossier 'history/seed/report.md') 'Synthetic provenance'
$f5Task=New-SBTrackerTask @{id='F5-1';title='Synthetic task';status='todo';acceptance=@('fixture')} $f5Id 'fixture' 'history/seed/report.md' (Get-SBTextHash 'Synthetic provenance') 'fixture'
$f5Task.seq=1;$f5Task.title='#001 — Synthetic task'
Put (Join-Path $f5Dossier tracker.json) (ConvertTo-SBJson @{schemaVersion=1;repository=$f5Id;updatedAt=[DateTimeOffset]::UtcNow.ToString('o');tasks=@($f5Task);history=@();extensions=@{lastSeq=1}})
[void](Invoke-SBGit $f5Repo @('init','-q'))
[void](Invoke-SBGit $f5Repo @('remote','add','origin','https://github.com/test/f5.git'))
$f5Runtime=Join-Path $f5Brain ('.runtime/hosts/'+(Get-SBHostId))
$f5ConfigPath=Join-Path $f5Runtime workstation.json
$f5Config=@{schemaVersion=1;mode='portable';brainRoot=$f5Brain;workstationId=(Get-SBHostId);runtimeRoot=$f5Runtime;backupRoot=(Join-Path $f5Runtime backups);bindings=@(@{identity=$f5Id;remoteIdentity=$f5Id;path=$f5Repo});ides=@();activityLogEnabled=$true}
Put $f5ConfigPath (ConvertTo-SBJson $f5Config)
function F5-Plan($Op,$Payload){New-SBMcpWritePlan $f5Brain $f5ConfigPath $f5Id $f5Repo ([guid]::NewGuid().ToString('N')) $Op $Payload}
function F5-Approve($Plan){Approve-SBMcpWritePlan $f5Brain $f5ConfigPath $Plan $Plan.planHash 'Synthetic per-call approval' $f5Session.sessionId}
function F5-Submit($Plan){Submit-SBMcpWrite $f5Brain $f5ConfigPath $f5Id $f5Repo $Plan.requestId $Plan.planHash}
function F5-Snapshot {
    $files=@{};foreach($file in Get-ChildItem -LiteralPath $f5Brain -Recurse -File -Force|Where-Object {$_.FullName -notmatch '[\\/]access[\\/]sessions[\\/]'}){$files[$file.FullName]=Get-SBFileHash $file.FullName}
    ConvertTo-SBJson $files
}
$f5Session=& (Join-Path $f5Brain scripts/access.ps1) -Start -Mode Write -Client Fixture -Repository $f5Id -ConfigPath $f5ConfigPath|ConvertFrom-Json
try {
    $f5Before=F5-Snapshot
    $f5Plan=F5-Plan 'task.status' @{taskId='F5-1';status='in_progress'}
    Check ($f5Before -ceq (F5-Snapshot)) 'MCP write preview has zero persistence'
    Check ($f5Plan.dossierPath -ceq $f5Dossier) 'reviewed plan names the exact dossier destination'
    Reject {F5-Plan 'memory.append' @{content=('漢'*50000)}} 'oversized UTF-8 plan is refused during preview'
    Reject {F5-Submit $f5Plan} 'MCP write without local receipt is denied'
    Reject {New-SBMcpWritePlan $f5Brain $f5ConfigPath $f5Id $repo ('a'*32) 'memory.append' @{content='outside'}} 'MCP write rejects a foreign checkout'
    Reject {F5-Plan 'history.save' @{path='../memory.md';content='outside'}} 'MCP write rejects path traversal'
    Reject {F5-Plan 'memory.append' @{content='<private>SYNTHETIC-PRIVATE-F5</private>'}} 'MCP write refuses private content before persistence'
    Reject {F5-Plan 'memory.append' @{content='x';approved=$true}} 'MCP payload cannot grant approval'
    Reject {Approve-SBMcpWritePlan $f5Brain $f5ConfigPath $f5Plan ('0'*64) 'fixture' $f5Session.sessionId} 'CLI approval rejects a different plan hash'
    $f5Altered=ConvertTo-SBJson $f5Plan|ConvertFrom-Json -AsHashtable -DateKind String
    $f5Altered.payload.status='done'
    Reject {F5-Approve $f5Altered} 'CLI approval rejects edited plan content'
    [void](F5-Approve $f5Plan)
    $f5Again=F5-Approve $f5Plan
    Check $f5Again.approved 'same local approval is idempotent without extension'
    $f5Result=F5-Submit $f5Plan
    Check ($f5Result.applied -and $f5Result.requestId -eq $f5Plan.requestId) 'approved MCP task status applies through pending queue'
    $f5Queue=Join-Path $f5Brain ('.runtime/access/pending-writes/'+$f5Plan.requestId+'.json')
    $f5QueueHash=Get-SBFileHash $f5Queue
    $f5Replay=F5-Submit $f5Plan
    Check ($f5Replay.applied -and (Get-SBFileHash $f5Queue) -ceq $f5QueueHash) 'same approved request replays its receipt without another request'
    $f5Stored=Read-SBJson $f5Queue $null
    Check ($f5Stored.expected.taskHash -and $f5Stored.id -ceq $f5Plan.requestId) 'queue preserves the approved task precondition and caller request ID'
    # task.update exposes awaiting and readRepositories with Update-SBTrackerTask validation.
    Reject {F5-Plan 'task.update' @{taskId='F5-1';readRepositories=@('not a repository identity')}} 'MCP task update rejects an invalid read-only repository identity'
    Reject {F5-Plan 'task.update' @{taskId='F5-1';readRepositories=@('github.com/Test/Upper')}} 'MCP task update rejects a non-canonical repository identity'
    Reject {F5-Plan 'task.update' @{taskId='F5-1';readRepositories='github.com/test/other'}} 'MCP task update requires readRepositories as an array'
    Reject {F5-Plan 'task.update' @{taskId='F5-1'}} 'MCP task update requires at least one field'
    Reject {F5-Plan 'task.update' @{taskId='F5-1';awaiting=1}} 'MCP task update requires awaiting as a string'
    $f5Fields=F5-Plan 'task.update' @{taskId='F5-1';execution='autonomous';awaiting='structural-completion';readRepositories=@('github.com/test/other',('local:'+('a'*32)),'github.com/test/other')}
    Check ($f5Fields.pending.operation -eq 'task.update' -and $f5Fields.pending.arguments.Awaiting -eq 'structural-completion') 'MCP task update previews a task.update pending request'
    [void](F5-Approve $f5Fields)
    Check (F5-Submit $f5Fields).applied 'approved MCP task update applies awaiting and readRepositories'
    Check (Test-Path (Join-Path $f5Brain ('.runtime/access/pending-writes/task-update/'+$f5Fields.requestId+'.json'))) 'MCP task update uses the task-update queue'
    Check (F5-Submit $f5Fields).applied 'MCP task update replays its receipt'
    $f5Ext=@((Read-SBJson (Join-Path $f5Dossier tracker.json) $null).tasks|Where-Object id -eq 'F5-1')[0].extensions
    Check ($f5Ext.awaiting -eq 'structural-completion' -and (@($f5Ext.readRepositories) -join ';') -ceq ('github.com/test/other;local:'+('a'*32))) 'MCP task update stores awaiting and the de-duplicated allowlist'
    $f5Clear=F5-Plan 'task.update' @{taskId='F5-1';awaiting='';readRepositories=@()}
    [void](F5-Approve $f5Clear)
    Check (F5-Submit $f5Clear).applied 'approved MCP task update clears both fields'
    $f5Ext=@((Read-SBJson (Join-Path $f5Dossier tracker.json) $null).tasks|Where-Object id -eq 'F5-1')[0].extensions
    Check (!$f5Ext.ContainsKey('awaiting') -and !$f5Ext.ContainsKey('readRepositories')) 'empty awaiting and readRepositories remove the fields'
    $f5Memory=F5-Plan 'memory.append' @{content="`nDecisione: synthetic — Motivo: fixture.`n"}
    [void](F5-Approve $f5Memory)
    Check (F5-Submit $f5Memory).applied 'approved MCP memory append applies'
    [void](F5-Submit $f5Memory)
    Check ([regex]::Matches((Read-SBText (Join-Path $f5Dossier memory.md)),'Decisione: synthetic').Count -eq 1 -and
        (Test-Path (Join-Path $f5Dossier memory.agent.md))) 'memory replay appends once and derives its agent view'
    $f5History=F5-Plan 'history.save' @{path='history/f5-test/report.md';content='# Synthetic history'}
    $f5PlanPath=Join-Path $f5Root reviewed-plan.json
    Put $f5PlanPath (ConvertTo-SBJson $f5History)
    $f5ApprovalOut=@(& pwsh -NoProfile -File (Join-Path $f5Brain scripts/mcp-write.ps1) -Approve -PlanPath $f5PlanPath -ExpectedPlanHash $f5History.planHash -Authorization 'Synthetic explicit CLI approval' -SessionId $f5Session.sessionId -ConfigPath $f5ConfigPath 2>&1)
    Check ($LASTEXITCODE -eq 0) ('real approval CLI accepts the reviewed fixture plan: '+($f5ApprovalOut -join ' '))
    Check (F5-Submit $f5History).applied 'approved MCP history save applies'
    $f5New=F5-Plan 'task.new' @{title='MCP synthetic';acceptance=@('synthetic accepted');provenance='history/seed/report.md'}
    [void](F5-Approve $f5New)
    Check (F5-Submit $f5New).applied 'approved MCP new task applies'
    [void](F5-Submit $f5New)
    Check (@((Read-SBJson (Join-Path $f5Dossier tracker.json) $null).tasks|Where-Object id -eq ('MCP-'+$f5New.requestId)).Count -eq 1) 'new task replay preserves one stable ID'
    $f5Activity=F5-Plan 'activity.append' @{taskId='F5-1';sessionId='synthetic-session';when='2026-11-07T10:00:00Z';outcome='progress';detail='Synthetic event'}
    [void](F5-Approve $f5Activity)
    $f5Config.activityLogEnabled=$false;Put $f5ConfigPath (ConvertTo-SBJson $f5Config)
    Reject {F5-Submit $f5Activity} 'real activity logging is disabled without its local activation policy'
    $f5Config.activityLogEnabled=$true;Put $f5ConfigPath (ConvertTo-SBJson $f5Config)
    Check (F5-Submit $f5Activity).applied 'activity transport applies in explicitly enabled synthetic fixture'
    [void](F5-Submit $f5Activity)
    $f5Event=(Read-SBText (Join-Path $f5Dossier history/activity/report.md)).Trim()|ConvertFrom-Json -AsHashtable
    Check ($f5Event.eventId -eq $f5Activity.requestId -and $f5Event.repository -eq $f5Id -and $f5Event.user -and $f5Event.where -eq $f5Repo) 'activity transport records exact scope and actor once'
    $f5Stale=F5-Plan 'memory.append' @{content='stale fixture'}
    [void](F5-Approve $f5Stale)
    Put (Join-Path $f5Dossier brief.md) '# Synthetic F5'
Put (Join-Path $f5Dossier memory.md) ((Read-SBText (Join-Path $f5Dossier memory.md))+"`nconcurrent fixture`n")
    Reject {F5-Submit $f5Stale} 'changed file invalidates approval before enqueue'
    Check (!(Test-Path (Join-Path $f5Brain ('.runtime/access/pending-writes/'+$f5Stale.requestId+'.json')))) 'stale approval creates no queue record'
    $f5Expired=F5-Plan 'memory.append' @{content='expired fixture'}
    $f5Approved=F5-Approve $f5Expired
    $f5Receipt=Read-SBJson $f5Approved.receiptPath $null
    $f5Receipt.expiresAt=[DateTimeOffset]::UtcNow.AddMinutes(-1).ToString('o')
    $f5Unsigned=@{}+$f5Receipt;[void]$f5Unsigned.Remove('receiptHash')
    $f5Receipt.receiptHash=Get-SBTextHash (ConvertTo-SBJson $f5Unsigned)
    Put $f5Approved.receiptPath (ConvertTo-SBJson $f5Receipt)
    Reject {F5-Submit $f5Expired} 'expired unconsumed approval is denied'
    $f5Tamper=F5-Plan 'memory.append' @{content='tamper fixture'}
    $f5Approved=F5-Approve $f5Tamper
    $f5Receipt=Read-SBJson $f5Approved.receiptPath $null;$f5Receipt.plan.payload.content='changed without approval'
    Put $f5Approved.receiptPath (ConvertTo-SBJson $f5Receipt)
    Reject {F5-Submit $f5Tamper} 'tampered local receipt is denied'
    $f5Conflict=F5-Plan 'memory.append' @{content='must-not-overwrite-concurrent'}
    [void](F5-Approve $f5Conflict)
    $f5RuntimeConfig=Read-SBConfiguration -BrainRoot $f5Brain -ConfigPath $f5ConfigPath -ReadOnly
    [void](New-SBPendingWrite -BrainRoot $f5Brain -Repository $f5Id -Operation $f5Conflict.pending.operation -Arguments $f5Conflict.pending.arguments -Expected $f5Conflict.pending.expected -Config $f5RuntimeConfig -RequestId $f5Conflict.requestId -PreparedHash $f5Conflict.pendingHash -StrictPreconditions)
    Put (Join-Path $f5Dossier memory.md) ((Read-SBText (Join-Path $f5Dossier memory.md))+"`nconcurrent-after-enqueue`n")
    $f5ConcurrentHash=Get-SBFileHash (Join-Path $f5Dossier memory.md)
    $f5ConflictResult=F5-Submit $f5Conflict
    Check ($f5ConflictResult.state -eq 'conflict' -and (Get-SBFileHash (Join-Path $f5Dossier memory.md)) -ceq $f5ConcurrentHash) 'queued MCP append rejects a changed precondition without overwriting'
    $f5Other=New-SBPendingWrite -BrainRoot $f5Brain -Repository $f5Id -Operation file.append -Arguments @{relativePath='memory.md';content='other-authorized-queue-entry'} -Config $f5RuntimeConfig
    $f5Own=F5-Plan 'memory.append' @{content="`nown-approved-entry`n"}
    [void](F5-Approve $f5Own)
    Check (F5-Submit $f5Own).applied 'submitted MCP request applies while another authorized entry waits'
    Check ((Get-SBPendingWrites $f5Brain|Where-Object id -eq $f5Other.id).state -eq 'deferred' -and
        !(Read-SBText (Join-Path $f5Dossier memory.md)).Contains('other-authorized-queue-entry')) 'MCP submission does not drain unrelated requests'
    [void](Invoke-SBPendingWrites -BrainRoot $f5Brain -Config $f5RuntimeConfig -RequestId $f5Other.id)
    $f5Moved=Join-Path $f5Brain '02-areas/products/F5Moved'
    [IO.Directory]::CreateDirectory((Split-Path $f5Moved))|Out-Null
    Move-Item -LiteralPath $f5Dossier -Destination $f5Moved
    try {
        Reject {F5-Submit $f5Plan} 'moved dossier invalidates even a replay approval bound to its former path'
    } finally {Move-Item -LiteralPath $f5Moved -Destination $f5Dossier}
    # Actual wire protocol: discover all tools, preview without writes, deny NoRecovery submit.
    $f5WirePlan=F5-Plan 'memory.append' @{content='wire fixture'}
    $f5WireArgs=@{repository=$f5Id;checkoutPath=$f5Repo;requestId=$f5WirePlan.requestId;operation='memory.append';payload=@{content='wire fixture'}}
    $f5Messages=@(
        @{jsonrpc='2.0';id=1;method='initialize';params=@{protocolVersion='2025-03-26'}}
        @{jsonrpc='2.0';id=2;method='tools/list';params=@{}}
        @{jsonrpc='2.0';id=3;method='tools/call';params=@{name='preview_dossier_write';arguments=$f5WireArgs}}
        @{jsonrpc='2.0';id=4;method='tools/call';params=@{name='submit_dossier_write';arguments=@{repository=$f5Id;checkoutPath=$f5Repo;requestId=$f5Plan.requestId;planHash=$f5Plan.planHash}}}
    )
    $f5Wire=($f5Messages|ForEach-Object {ConvertTo-SBJson $_|ConvertFrom-Json -AsHashtable|ConvertTo-Json -Depth 30 -Compress}) -join "`n"
    $f5BeforeWire=F5-Snapshot
    $f5WireOut=@($f5Wire|& pwsh -NoProfile -File (Join-Path $f5Brain scripts/mcp-server.ps1) -BrainRoot $f5Brain -ConfigPath $f5ConfigPath -NoRecovery)
    $f5Replies=@($f5WireOut|ForEach-Object {$_|ConvertFrom-Json -AsHashtable})
    Check ($LASTEXITCODE -eq 0 -and $f5Replies[1].result.tools.Count -eq 11 -and !$f5Replies[2].result.isError) 'stdio handshake discovers eleven tools and previews a write'
    Check ($f5Replies[3].result.isError -and $f5BeforeWire -ceq (F5-Snapshot)) 'NoRecovery wire session refuses submit and remains write-free'
    $f5Defs=$f5Replies[1].result.tools
    Check (@($f5Defs|Where-Object name -eq preview_dossier_write)[0].annotations.readOnlyHint -and
        @($f5Defs|Where-Object name -eq submit_dossier_write)[0].annotations.idempotentHint) 'MCP write annotations distinguish preview and idempotent submission'
    Check (@(Get-SBMcpKnowledgeToolNames|Where-Object {$_ -like '*dossier_write'}).Count -eq 0) 'new write tools are outside knowledge preauthorization'
    # UTF-8 on the wire: an em dash and an accent must round-trip through real stdio bytes, whatever the console code page.
    $f5Utf8Text="Test $([char]0x2014) Compatibilit$([char]0xE0)"
    $f5Utf8Args=@{repository=$f5Id;checkoutPath=$f5Repo;requestId=(F5-Plan 'memory.append' @{content=$f5Utf8Text}).requestId;operation='memory.append';payload=@{content=$f5Utf8Text}}
    $f5Utf8Msgs=@(
        @{jsonrpc='2.0';id=1;method='initialize';params=@{protocolVersion='2025-03-26'}}
        @{jsonrpc='2.0';id=2;method='tools/call';params=@{name='preview_dossier_write';arguments=$f5Utf8Args}})
    $f5Utf8In=Join-Path $f5Dossier 'utf8-wire-in.jsonl'; $f5Utf8OutFile=Join-Path $f5Dossier 'utf8-wire-out.jsonl'
    [IO.File]::WriteAllBytes($f5Utf8In,[Text.UTF8Encoding]::new($false).GetBytes((($f5Utf8Msgs|ForEach-Object {$_|ConvertTo-Json -Depth 30 -Compress}) -join "`n")+"`n"))
    $f5PwshPath=(Get-Process -Id $PID).Path
    $f5Cp=0; try {$f5Cp=[Console]::OutputEncoding.CodePage} catch {}
    try {
        # Console code page 850 emulates an OEM console: the server must still read and write UTF-8.
        & cmd.exe /d /c "chcp 850>nul & type `"$f5Utf8In`" | `"$f5PwshPath`" -NoProfile -File `"$(Join-Path $f5Brain 'scripts/mcp-server.ps1')`" -BrainRoot `"$f5Brain`" -ConfigPath `"$f5ConfigPath`" -NoRecovery > `"$f5Utf8OutFile`""
    } finally { if($f5Cp){& cmd.exe /d /c "chcp $f5Cp>nul"} }
    $f5Utf8Out=[IO.File]::ReadAllText($f5Utf8OutFile,[Text.Encoding]::UTF8)
    Remove-Item -LiteralPath $f5Utf8In,$f5Utf8OutFile -Force
    $f5Utf8Reply=@($f5Utf8Out -split "`n"|Where-Object {$_.Trim()}|ForEach-Object {$_|ConvertFrom-Json -AsHashtable})[1]
    Check (!$f5Utf8Reply.result.isError -and ([string]$f5Utf8Reply.result.content[0].text).Contains($f5Utf8Text)) 'MCP stdio keeps em dash and accents intact in UTF-8'
} finally {
    & (Join-Path $f5Brain scripts/access.ps1) -End -SessionId $f5Session.sessionId -ConfigPath $f5ConfigPath
}