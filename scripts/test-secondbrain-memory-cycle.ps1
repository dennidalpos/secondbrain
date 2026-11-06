#requires -Version 7.5
# Behavioral fixtures only. All evidence is retained; no real dossier or IDE is changed.
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.MemoryCycle.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Host.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Knowledge.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Tracker.psm1')
. (Join-Path $PSScriptRoot 'test-helpers.ps1')
$script:cycleChecks=0
function Assert-Cycle($Condition,[string]$Message){if(!$Condition){throw ('FAIL MEMORY CYCLE: '+$Message)};$script:cycleChecks++}
function Reject-Cycle([scriptblock]$Action,[string]$Message){$rejected=$false;try{& $Action|Out-Null}catch{$rejected=$true};Assert-Cycle $rejected $Message}
$root=Join-Path (Get-SBTestRoot) ('memcycle-'+[guid]::NewGuid().ToString('N'))
$brain=Join-Path $root 'brain';$repo='github.com/acme/one';$d=Join-Path $brain '02-areas/one';$backups=Join-Path $brain '.runtime/backups'
foreach($folder in @($d,(Join-Path $brain '02-areas/two'),(Join-Path $brain 'direttive'),(Join-Path $brain 'config'))){[void][IO.Directory]::CreateDirectory($folder)}
foreach($name in @('one','two')){
    $dir=Join-Path $brain ('02-areas/'+$name)
    [IO.File]::WriteAllText((Join-Path $dir 'brief.md'),('# '+$name))
    [IO.File]::WriteAllText((Join-Path $dir 'para.json'),(ConvertTo-SBJson @{schemaVersion=1;id=('area-'+$name);kind='area';title=$name;status='active'}))
    [IO.File]::WriteAllText((Join-Path $dir 'repository.json'),(ConvertTo-SBJson @{schemaVersion=1;identity=('github.com/acme/'+$name);tracker=@{location='dossier';path='tracker.json';schemaVersion=1}}))
    [IO.File]::WriteAllText((Join-Path $dir 'context.md'),"# Contesto`n## Stato corrente`nOriginale`n## Vincoli`nVincolo importante`n## Problemi aperti`nErrore 401`n## Prossimo passo`nVerificare`n")
    [IO.File]::WriteAllText((Join-Path $dir 'memory.md'),"# Memoria`n## Decisioni`n- Decisione: mantenere tutti i dati — Motivo: recupero.`n")
    [IO.File]::WriteAllText((Join-Path $dir 'tracker.json'),(ConvertTo-SBJson @{schemaVersion=1;repository=('github.com/acme/'+$name);updatedAt='2026-11-05T00:00:00Z';tasks=@();history=@();extensions=@{}}))
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../direttive/approved.json') -Destination (Join-Path $brain 'direttive/approved.json')
foreach($name in @('AGENTS.global_ide.md','workstation.template.md','AGENTS.repo.managed.md')){
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot ('../direttive/'+$name)) -Destination (Join-Path $brain ('direttive/'+$name))
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../config/tracker.schema.json') -Destination (Join-Path $brain 'config/tracker.schema.json')
[IO.File]::WriteAllText((Join-Path $brain 'config/shared.json'),(ConvertTo-SBJson @{schemaVersion=1;allowedOwners=@('acme');excludedDirectories=@('.git')}))
[IO.File]::WriteAllText((Join-Path $brain 'VERSION'),'1.0.0')
$workspace=Join-Path $brain ('.runtime/hosts/'+(Get-SBHostId)+'/repos/'+(Get-SBRuntimeRepoSegment $repo)+'/evidence/20261105-cycle')
[void][IO.Directory]::CreateDirectory($workspace)
[IO.File]::WriteAllText((Join-Path $workspace 'MANIFEST.json'),(ConvertTo-SBJson @{category='evidence';repository=(Get-SBRuntimeRepoSegment $repo);owner=@{computer=[Environment]::MachineName;user=$env:USERNAME};sessionId='fixture';status='open'}))
$envelope=@{schemaVersion=1;repository=$repo;client='codex';clientVersion='fixture';sessionId='session-1';turnId='turn-1';persistence='disabled';policyEvidence='fixture caller permits this turn';termination='completed';events=@(@{id='u1';kind='user';content='Richiesta'},@{id='a1';kind='assistant';content='Risposta'})}
$before=@(Get-ChildItem -LiteralPath $brain -Recurse -File).Count
$s=Save-SBCycleTurn $brain $envelope $workspace $backups -Apply
Assert-Cycle ($s.state -eq 'suppressed' -and @(Get-ChildItem -LiteralPath $brain -Recurse -File).Count -eq $before) 'disabled makes no files'
$envelope.persistence='unknown';Assert-Cycle ((Save-SBCycleTurn $brain $envelope $workspace $backups -Apply).state -eq 'suppressed') 'unknown fails closed'
$envelope.persistence='allowed'
$envelope.events+=@(@{id='p1';kind='user';content='<private>private-one'},@{id='p2';kind='assistant';content='private-two'},@{id='p3';kind='user';content='private-three</private>'},@{id='private-reply';kind='assistant';content='Echo of private content'},@{id='u2';kind='user';content='Public request'},@{id='a2';kind='assistant';content='Verified output';hidden_reasoning='must not persist'})
$asset=Join-Path $root 'attachment.txt';[IO.File]::WriteAllText($asset,'original bytes')
$envelope.attachments=@(@{eventId='u1';path=$asset},@{eventId='p1';path=$asset})
$preview=Save-SBCycleTurn $brain $envelope $workspace $backups -AllowedAttachmentPaths @($asset)
Assert-Cycle ($preview.state -eq 'preview' -and !(Test-Path -LiteralPath $preview.path)) 'preview does not write'
$saved=Save-SBCycleTurn $brain $envelope $workspace $backups -AllowedAttachmentPaths @($asset) -Apply
$record=Read-SBJson $saved.path $null;$text=Read-SBText $saved.path
Assert-Cycle ($record.turn.events.Count -eq 4 -and $record.turn.omittedPrivateEvents -eq 4 -and $text -notmatch 'private-one|private-two|private-three|Echo of private|must not persist') 'privacy before persistence including replies to private requests, and no hidden reasoning'
Assert-Cycle ($record.turn.attachments.Count -eq 1 -and $record.turn.attachments[0].state -eq 'extracted') 'private attachments excluded'
$original=Join-Path $brain $record.assetLocations[$record.turn.attachments[0].sha256]
Assert-Cycle ((Get-SBFileHash $asset) -ceq (Get-SBFileHash $original)) 'original bytes preserved'
Assert-Cycle ((Get-SBCompactionAdvice @{repository=$repo;characters=18000;budget=30000} $brain $d).capturedTurns -eq 1) 'compaction advice counts captured turn metadata without loading raw logs'
Assert-Cycle ((Save-SBCycleTurn $brain $envelope $workspace $backups -AllowedAttachmentPaths @($asset) -Apply).state -eq 'duplicate') 'retry idempotent'
$envelope.events[0].content='Changed';Assert-Cycle ((Save-SBCycleTurn $brain $envelope $workspace $backups -AllowedAttachmentPaths @($asset) -Apply).state -eq 'conflict') 'same turn different payload conflicts'
$envelope.events[0].content='Richiesta';$envelope.repository='github.com/acme/two'
Reject-Cycle {Save-SBCycleTurn $brain $envelope $workspace $backups -Apply} 'repository workspace isolation'
$envelope.repository=$repo
$candidate=@{schemaVersion=1;repository=$repo;persistence='allowed';policyEvidence='fixture permits derivatives';capturePath=$saved.path;captureSha256=(Get-SBFileHash $saved.path);sources=@{'memory.md'=(Get-SBFileHash (Join-Path $d 'memory.md'))};changes=@(@{kind='decision';id='decision-1';text='Usare hash';reason='Rilevare conflitti';verified=$true;eventIds=@('a2')})}
$p=Invoke-SBCyclePromotion $brain $candidate $workspace $backups -Apply
Assert-Cycle ($p.state -eq 'applied' -and (Read-SBText (Join-Path $d 'memory.md')).Contains('decision-1')) 'verified decision promoted'
Assert-Cycle ((Invoke-SBCyclePromotion $brain $candidate $workspace $backups -Apply).state -eq 'duplicate') 'promotion replay idempotent'
$candidate.changes[0].id='decision-2'
Assert-Cycle ((Invoke-SBCyclePromotion $brain $candidate $workspace $backups -Apply).state -eq 'proposal') 'stale source becomes proposal'
$candidate.sources['memory.md']=Get-SBFileHash (Join-Path $d 'memory.md');$candidate.changes[0].supersedes='decision-1'
Assert-Cycle ((Invoke-SBCyclePromotion $brain $candidate $workspace $backups -Apply).state -eq 'applied') 'decision supersession'
$candidate.sources['memory.md']=Get-SBFileHash (Join-Path $d 'memory.md');$candidate.changes[0].id='decision-3';$candidate.changes[0].supersedes='decision-2'
$third=Invoke-SBCyclePromotion $brain $candidate $workspace $backups -Apply
$decisionSource=Read-SBText (Join-Path $d 'memory.md')
Assert-Cycle ($third.state -eq 'applied' -and $decisionSource.Contains('id=decision-2 state=superseded supersededBy=decision-3 supersedes=decision-1')) 'successive decision replacements preserve both directions of provenance'
$thirdReceipt=Read-SBJson $third.receipt $null
Assert-Cycle ((Get-SBTextHash (ConvertTo-SBJson $thirdReceipt.candidate)).ToLowerInvariant() -ceq $thirdReceipt.candidateSha256) 'promotion receipt preserves the reviewed candidate and its source revisions'
$derived=$candidate.Clone();$derived.sources=@{'context.md'=(Get-SBFileHash (Join-Path $d 'context.md'));'topics/fixture.md'='absent'}
$englishContext=(Read-SBText (Join-Path $d 'context.md')).Replace('Stato corrente','Current state').Replace('Vincoli','Constraints').Replace('Problemi aperti','Open issues').Replace('Prossimo passo','Next step')
$derived.changes=@(@{kind='context';text=$englishContext;verified=$true;eventIds=@('a2')},@{kind='topic';path='topics/fixture.md';text='# Verified topic';verified=$true;eventIds=@('a2')})
$derivedResult=Invoke-SBCyclePromotion $brain $derived $workspace $backups -Apply
$topicText=Read-SBText (Join-Path $d 'topics/fixture.md')
$topicLink=[regex]::Match($topicText,'\[registro del turno\]\(([^)]+)\)').Groups[1].Value
Assert-Cycle ($derivedResult.state -eq 'applied' -and (Read-SBText (Join-Path $d 'context.md')).Contains('eventi a2') -and (Test-SBSamePath ([IO.Path]::GetFullPath((Join-Path (Join-Path $d 'topics') $topicLink))) $saved.path)) 'context and topic derivatives retain resolvable turn and event references'
$view=Read-SBText (Join-Path $d 'memory.agent.md')
Assert-Cycle ($view -notmatch 'Decisione decision-1' -and $view -notmatch '<!-- sb:decision') 'agent view excludes superseded blocks and markers'
$index=Save-SBCycleKnowledgeIndex $brain $repo $backups -Apply
$again=Save-SBCycleKnowledgeIndex $brain $repo $backups -Apply
Assert-Cycle ($index.entries -ge 3 -and $again.operations -eq 0) 'index reconstructible and unchanged sources not rewritten'
$context=Get-SBCycleContext $brain $repo
Assert-Cycle (!(Get-SBCycleContext $brain $repo -PreviousRevision $context.revision).changed) 'unchanged revision sends no package'
Assert-Cycle ((Get-SBCycleContext $brain $repo -PreviousRevision $context.revision -Budget 29999).changed) 'budget changes invalidate context revision even with unchanged sources'
$small=Get-SBCycleContext $brain $repo -Budget 50
Assert-Cycle (!$small.startup.withinBudget -and $small.startup.minimumCharacters -gt 50 -and $small.startup.parts.context.Contains('Vincolo importante')) 'mandatory context never silently dropped'
Assert-Cycle ((Remove-SBPrivateText "visible`n<private>hidden`nsecret</private>`nend") -notmatch 'hidden|secret') 'private text excluded from legacy knowledge reads'
$task=New-SBTrackerTaskEntry -BrainRoot $brain -Identity $repo -Id 'CYCLE-TASK' -Title 'Synthetic verified task' -Acceptance @('Synthetic criterion') -ProvenanceReference 'context.md' -BackupRoot $backups
$candidate.sources['memory.md']=Get-SBFileHash (Join-Path $d 'memory.md');$candidate.sources['tracker.json']=Get-SBFileHash (Join-Path $d 'tracker.json')
$candidate.changes=@(@{kind='decision';id='decision-atomic';text='Memoria e tracker insieme';reason='Coerenza';verified=$true;eventIds=@('a2')},@{kind='task';id='CYCLE-TASK';status='done';verified=$true;eventIds=@('a2');verifiedAcceptance=@('Wrong criterion');evidenceReference='synthetic-capture'})
$before=Get-SBFileHash (Join-Path $d 'memory.md')
Reject-Cycle {Invoke-SBCyclePromotion $brain $candidate $workspace $backups -Apply} 'task closure rejects missing acceptance evidence'
Assert-Cycle ((Get-SBFileHash (Join-Path $d 'memory.md')) -ceq $before) 'rejected task leaves planned memory unchanged'
$candidate.changes[1].verifiedAcceptance=@('Synthetic criterion')
Assert-Cycle ((Invoke-SBCyclePromotion $brain $candidate $workspace $backups -Apply).state -eq 'applied') 'task and memory commit together'
$active=Read-SBJson (Join-Path $d 'tracker.json') $null;$archived=Read-SBJson (Join-Path $d 'history/tracker-archive.json') $null
Assert-Cycle (!@($active.tasks|Where-Object id -eq 'CYCLE-TASK').Count -and @($archived.tasks|Where-Object id -eq 'CYCLE-TASK').Count -eq 1) 'completed task archived in promotion transaction'
$candidate.changes=@(@{kind='decision';id='private-candidate';text='<private>must not persist</private>';reason='fixture';verified=$true;eventIds=@('a2')})
$before=@(Get-ChildItem -LiteralPath $brain -File -Recurse).Count
Assert-Cycle ((Invoke-SBCyclePromotion $brain $candidate $workspace $backups -Apply).state -eq 'suppressed' -and @(Get-ChildItem -LiteralPath $brain -File -Recurse).Count -eq $before) 'private candidate cannot create even a proposal'
foreach($client in @('codex','claude-code','antigravity','vscode','android-studio','claude','cursor','windsurf','continue','jetbrains')){
    Assert-Cycle (!(Get-SBCycleAdapter $client).liveVerified) ('adapter fixture is not live qualification: '+$client)
}
$nativeFile=Join-Path $root 'native.jsonl'
$current=@(@{type='input_text';text='Current request'})
$nativeRows=@(@{type='response_item';payload=@{type='message';role='user';content=@(@{type='input_text';text='Old turn must not be imported'})}},@{type='response_item';payload=@{type='message';role='user';content=$current}},@{type='response_item';payload=@{type='reasoning';text='Hidden reasoning must not be imported'}},@{type='response_item';payload=@{type='function_call_output';call_id='call-1';output='Observed current output'}})
$nativeRows+=@{type='response_item';payload=@{type='message';role='assistant';channel='analysis';content=@(@{type='output_text';text='Hidden analysis channel'})}}
[IO.File]::WriteAllLines($nativeFile,@($nativeRows|ForEach-Object {$_|ConvertTo-Json -Compress -Depth 20}))
$permit=@{schemaVersion=1;repository=$repo;client='codex';clientVersion='fixture';sessionId='native-session';turnId='native-turn';transcriptPath=$nativeFile;lastUserSha256=(Get-SBTextHash (ConvertTo-SBJson $current));persistence='allowed';policyEvidence='single current turn fixture'}
$native=@{session_id='native-session';turn_id='native-turn';transcript_path=$nativeFile;last_assistant_message='Final response'}
$normalized=ConvertFrom-SBCycleNativeTurn codex $native $permit
Assert-Cycle ($normalized.state -eq 'prepared' -and (ConvertTo-SBJson $normalized.envelope) -notmatch 'Old turn|Hidden reasoning|Hidden analysis' -and $normalized.envelope.events[-1].content -eq 'Final response') 'native Codex selects current turn, final response and exposed events only'
$transcriptWriter=[IO.File]::Open($nativeFile,[IO.FileMode]::Open,[IO.FileAccess]::Write,[IO.FileShare]::Read)
try {
    Assert-Cycle ((ConvertFrom-SBCycleNativeTurn codex $native $permit).state -eq 'prepared') 'native Codex reads a transcript still open by the writer'
} finally {
    $transcriptWriter.Dispose()
}
$permit.turnId='previous-turn'
Assert-Cycle ((ConvertFrom-SBCycleNativeTurn codex $native $permit).state -eq 'suppressed') 'stale native permit cannot authorize another turn'
$permit.turnId='native-turn';$permit.lastUserSha256='0'*64
Assert-Cycle ((ConvertFrom-SBCycleNativeTurn codex $native $permit).state -eq 'suppressed') 'changed user request invalidates native permit'
$permit.client='claude-code';$permit.turnId='user-uuid';$permit.lastUserSha256=Get-SBTextHash (ConvertTo-SBJson 'Current request')
[IO.File]::WriteAllLines($nativeFile,@((@{type='user';uuid='user-uuid';message=@{role='user';content='Current request'}}|ConvertTo-Json -Compress -Depth 20),(@{type='assistant';message=@{role='assistant';content=@(@{type='thinking';thinking='Hidden Claude reasoning'},@{type='text';text='Visible output'})}}|ConvertTo-Json -Compress -Depth 20)))
$normalized=ConvertFrom-SBCycleNativeTurn claude-code @{session_id='native-session';transcript_path=$nativeFile} $permit
Assert-Cycle ($normalized.state -eq 'prepared' -and (ConvertTo-SBJson $normalized.envelope) -notmatch 'Hidden Claude reasoning') 'Claude UUID boundary and hidden-block filtering'
$permit.client='antigravity';$permit.turnId='2'
[IO.File]::WriteAllLines($nativeFile,@((@{userMessage='Current request'}|ConvertTo-Json -Compress),(@{assistantMessage='Visible answer'}|ConvertTo-Json -Compress)))
$normalized=ConvertFrom-SBCycleNativeTurn antigravity @{conversationId='native-session';executionNum=2;transcriptPath=$nativeFile;terminationReason='model_stop'} $permit
Assert-Cycle ($normalized.state -eq 'prepared' -and $normalized.envelope.termination -eq 'completed') 'Antigravity declared execution boundary fixture (not live qualification)'
$workspace2=Join-Path (Split-Path $workspace) '20261105-cycle-two'
[void][IO.Directory]::CreateDirectory($workspace2)
[IO.File]::WriteAllText((Join-Path $workspace2 'MANIFEST.json'),(Read-SBText (Join-Path $workspace 'MANIFEST.json')))
$secondEnvelope=(ConvertTo-SBJson $envelope)|ConvertFrom-Json -AsHashtable
$secondEnvelope.turnId='turn-2'
$second=Save-SBCycleTurn $brain $secondEnvelope $workspace2 $backups -AllowedAttachmentPaths @($asset) -Apply
$secondRecord=Read-SBJson $second.path $null
Assert-Cycle ($secondRecord.assetLocations.Values -contains [IO.Path]::GetRelativePath($brain,$original).Replace('\','/') -and @(Get-ChildItem -LiteralPath (Split-Path $workspace) -Recurse -File -Filter '*.bin').Count -eq 1) 'original deduplication across workspaces in one repository'
Assert-Cycle ((Save-SBCycleTurn $brain $envelope $workspace2 $backups -AllowedAttachmentPaths @($asset) -Apply).state -eq 'duplicate') 'turn replay across workspaces remains idempotent'
[IO.File]::WriteAllText($original,'corrupted fixture copy')
Assert-Cycle ((Save-SBCycleTurn $brain $envelope $workspace $backups -AllowedAttachmentPaths @($asset) -Apply).state -eq 'conflict') 'damaged stored original cannot be reported as a valid duplicate'
$scripts=Join-Path $brain 'scripts';[void][IO.Directory]::CreateDirectory($scripts)
Get-ChildItem -LiteralPath $PSScriptRoot -File|Where-Object {$_.Name -notlike 'test-*'}|Copy-Item -Destination $scripts
$hostId=Get-SBHostId;$runtime=Join-Path $brain ('.runtime/hosts/'+$hostId);$configPath=Join-Path $runtime 'workstation.json'
$cfg=@{schemaVersion=1;mode='portable';brainRoot=$brain;workstationId=$hostId;runtimeRoot=$runtime;backupRoot=$backups;repositoryRoot=$brain;coordinationRoot=(Join-Path $brain '.runtime/access');bindings=@(@{identity=$repo;path=$root;remoteIdentity=$repo});ides=@();sessionTimeoutMinutes=30;lockWaitMs=1000;configPath=$configPath}
[IO.File]::WriteAllText($configPath,(ConvertTo-SBJson $cfg))
$permit.client='codex';$permit.turnId='native-turn';$permit.lastUserSha256=Get-SBTextHash (ConvertTo-SBJson $current);$permit.workspace=$workspace
[IO.File]::WriteAllLines($nativeFile,@($nativeRows|ForEach-Object {$_|ConvertTo-Json -Compress -Depth 20}))
$permitPath=Join-Path $workspace 'permit.json';[IO.File]::WriteAllText($permitPath,(ConvertTo-SBJson $permit))
$native.cwd=$root
$bridge=@($native|ConvertTo-Json -Compress|& pwsh -NoProfile -File (Join-Path $scripts 'memory-cycle-hook.ps1') -Client codex -PermitPath $permitPath -ConfigPath $configPath -Diagnostics 2>&1)
$nativeKey=(Get-SBTextHash ($repo+"`n"+'codex'+"`n"+'native-session'+"`n"+'native-turn')).ToLowerInvariant()
Assert-Cycle ($LASTEXITCODE -eq 0 -and [IO.File]::Exists((Join-Path $workspace ('turns/'+$nativeKey+'.json')))) ('native bridge subprocess captures current fixture turn: '+($bridge -join ' '))
$receipt=[string]$bridge[0]|ConvertFrom-Json -AsHashtable
Assert-Cycle ($bridge.Count -eq 1 -and $receipt.Count -eq 3 -and $receipt.schemaVersion -eq 1 -and $receipt.phase -ceq 'capture' -and $receipt.outcome -ceq 'captured') 'capture diagnostic contains only phase and outcome metadata'
$permit.turnId='wrong-root';$native.turn_id='wrong-root';$native.cwd=Join-Path (Split-Path $root) 'unbound-repository'
[IO.File]::WriteAllText($permitPath,(ConvertTo-SBJson $permit))
$before=@(Get-ChildItem -LiteralPath $brain -Recurse -File).Count
$ignored=@($native|ConvertTo-Json -Compress|& pwsh -NoProfile -File (Join-Path $scripts 'memory-cycle-hook.ps1') -Client codex -PermitPath $permitPath -ConfigPath $configPath 2>&1)
Assert-Cycle ($LASTEXITCODE -eq 0 -and @(Get-ChildItem -LiteralPath $brain -Recurse -File).Count -eq $before) 'native repository mismatch cannot start a write session or capture'
Assert-Cycle ($ignored.Count -eq 0) 'suppressed native hook is silent by default'
$diagnosed=@($native|ConvertTo-Json -Compress|& pwsh -NoProfile -File (Join-Path $scripts 'memory-cycle-hook.ps1') -Client codex -PermitPath $permitPath -ConfigPath $configPath -Diagnostics 2>&1)
$receipt=[string]$diagnosed[0]|ConvertFrom-Json -AsHashtable
Assert-Cycle ($LASTEXITCODE -eq 0 -and $diagnosed.Count -eq 1 -and $receipt.Count -eq 3 -and $receipt.schemaVersion -eq 1 -and $receipt.phase -ceq 'binding' -and $receipt.outcome -ceq 'suppressed') 'diagnostic reports suppression at the repository binding'
Assert-Cycle (@(Get-ChildItem -LiteralPath $brain -Recurse -File).Count -eq $before) 'diagnostic suppression does not start a write session or create files'
$observation=@{schemaVersion=1;repository=$repo;client='codex';clientVersion='fixture';workspace=$workspace;observedAt=[DateTimeOffset]::UtcNow.ToString('o');coverage='partial';evidenceKind='fixture';evidencePath=$saved.path;evidenceSha256=(Get-SBFileHash $saved.path);moduleSha256=(Get-SBFileHash (Join-Path $PSScriptRoot 'SecondBrain.MemoryCycle.psm1'))}
$observationPath=Join-Path $workspace 'observation.json';[IO.File]::WriteAllText($observationPath,(ConvertTo-SBJson $observation))
Assert-Cycle (!(Get-SBCycleAdapter codex $brain $repo $observationPath).liveVerified) 'valid fixture receipt never becomes live qualification'
$observation.moduleSha256='0'*64;[IO.File]::WriteAllText($observationPath,(ConvertTo-SBJson $observation))
Reject-Cycle {Get-SBCycleAdapter codex $brain $repo $observationPath} 'qualification invalidated by module revision'
'SUCCESS MEMORY CYCLE: '+$script:cycleChecks+' checks; retained fixture '+$root
