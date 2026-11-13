#requires -Version 7.5
# Synthetic SecondBrain for the desktop orchestrator end-to-end tests: a copy of scripts/ and the approved directives, one dossier
# with a tracker of three ready autonomous tasks, a Git checkout bound to it, the workstation configuration at its default place and
# a fake Claude Code CLI (claude.cmd or claude) that streams stream-json steps and updates the task through knowledge.ps1.
# Prints the fixture as JSON: brain, checkout, identity, tracker, config, bin (folder of the fake CLI), configDir (app settings).
# Only synthetic data; the real trackers are never read or written.
param([Parameter(Mandatory)][string]$Root)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Host.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Tracker.psm1')
function Put([string]$Path,[string]$Text){[IO.Directory]::CreateDirectory((Split-Path $Path))|Out-Null;[IO.File]::WriteAllText($Path,$Text,[Text.UTF8Encoding]::new($false))}
$real=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$brain=Join-Path $Root 'brain'
$checkout=Join-Path $Root 'checkout'
$identity='github.com/test/orchestrator-e2e'
$dossier=Join-Path $brain '01-projects/OrchestratorE2E'
$hostId=Get-SBHostId
$runtime=Join-Path $brain ('.runtime/hosts/'+$hostId)
$configPath=Join-Path $runtime 'workstation.json'
[IO.Directory]::CreateDirectory((Join-Path $brain 'scripts'))|Out-Null
Get-ChildItem -LiteralPath $PSScriptRoot -File|Copy-Item -Destination (Join-Path $brain 'scripts')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'templates') -Destination (Join-Path $brain 'scripts') -Recurse
Put (Join-Path $brain 'VERSION') (Read-SBText (Join-Path $real 'VERSION'))
foreach($f in @('config/tracker.schema.json','config/agent-models.json','config/task-runs.schema.json','config/analysis/directives.schema.json','config/analysis/task.schema.json')){Put (Join-Path $brain $f) (Read-SBText (Join-Path $real $f))}
Put (Join-Path $brain 'config/shared.json') (ConvertTo-SBJson @{schemaVersion=1;allowedOwners=@('test');excludedDirectories=@('.git')})
# Approved directives exactly as in this checkout (their hashes stay valid); proposals are not needed.
[IO.Directory]::CreateDirectory((Join-Path $brain 'direttive'))|Out-Null
foreach($f in @(Get-ChildItem -LiteralPath (Join-Path $real 'direttive') -File)){Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $brain ('direttive/'+$f.Name)) -Force}
Copy-Item -LiteralPath (Join-Path $real 'direttive/prompts') -Destination (Join-Path $brain 'direttive') -Recurse -Force
Put (Join-Path $dossier 'para.json') (ConvertTo-SBJson @{schemaVersion=1;id='orchestrator-e2e';kind='project';title='Orchestrator E2E';status='active'})
Put (Join-Path $dossier 'repository.json') (ConvertTo-SBJson @{schemaVersion=1;identity=$identity;tracker=@{location='dossier';path='tracker.json';schemaVersion=1}})
Put (Join-Path $dossier 'context.md') "# Context`n"
Put (Join-Path $dossier 'brief.md') '# Synthetic orchestrator fixture'
Put (Join-Path $dossier 'memory.md') "# Memory`n"
Put (Join-Path $dossier 'history/seed/report.md') 'Synthetic provenance'
$tasks=@();$n=0
foreach($spec in @(@{id='E2E-1';priority='P1'},@{id='E2E-2';priority='P2'},@{id='E2E-3';priority='P3'})){
    $n++
    $task=New-SBTrackerTask @{id=$spec.id;title=('Task '+$spec.id);status='todo'} $identity 'fixture' 'history/seed/report.md' (Get-SBTextHash 'Synthetic provenance') 'fixture'
    $task.seq=$n;$task.title='#'+$n.ToString('000')+' '+[char]0x2014+' Task sintetico '+$spec.id;$task.priority=$spec.priority;$task.execution='autonomous';$task.extensions=@{stream='evoluzione-team'}
    $tasks+=,$task
}
# A task the runner skips (user_required), for the analysis that makes it autonomous.
$n++
$manual=New-SBTrackerTask @{id='E2E-4';title='Task E2E-4';status='todo'} $identity 'fixture' 'history/seed/report.md' (Get-SBTextHash 'Synthetic provenance') 'fixture'
$manual.seq=$n;$manual.title='#'+$n.ToString('000')+' '+[char]0x2014+' Task sintetico da rendere autonomo';$manual.priority='P2';$manual.execution='user_required';$manual.extensions=@{stream='evoluzione-team';stateReason='Serve una scelta della persona'}
$tasks+=,$manual
# An archived task closed before the ledger existed (the registry shows it with the unknown tool).
$n++
$closed=New-SBTrackerTask @{id='E2E-0';title='Task E2E-0';status='done'} $identity 'fixture' 'history/seed/report.md' (Get-SBTextHash 'Synthetic provenance') 'fixture'
$closed.seq=$n;$closed.title='#'+$n.ToString('000')+' '+[char]0x2014+' Task sintetico archiviato';$closed.priority='P3';$closed.execution='autonomous';$closed.extensions=@{stream='evoluzione-team';lastClosure=@{at='2026-01-15T10:00:00Z';status='done';reason='Chiuso nella fixture'}}
Put (Join-Path $dossier 'history/tracker-archive.json') (ConvertTo-SBJson @{schemaVersion=1;repository=$identity;tasks=@($closed)})
Put (Join-Path $dossier 'tracker.json') (ConvertTo-SBJson @{schemaVersion=1;repository=$identity;updatedAt=[DateTimeOffset]::UtcNow.ToString('o');tasks=$tasks;history=@();extensions=@{lastSeq=$n;archive=@{path='history/tracker-archive.json';archivedTasksCount=1}}})
[IO.Directory]::CreateDirectory($checkout)|Out-Null
& git -c core.longpaths=true -C $checkout init -q
& git -c core.longpaths=true -C $checkout remote add origin ('https://'+$identity+'.git')
Put (Join-Path $checkout 'AGENTS.md') "# Synthetic product`n"
Put (Join-Path $checkout 'README.md') "# Synthetic product`n"
$cfg=@{schemaVersion=1;mode='portable';workstationId=$hostId;runtimeRoot=$runtime;backupRoot=(Join-Path $runtime 'backups');bindings=@(@{identity=$identity;path=$checkout;remoteIdentity=$identity;dossier='01-projects/OrchestratorE2E';status='managed';managedHash='absent';fingerprint=(Get-SBCheckoutAsset $checkout).fingerprint});ides=@()}
Put $configPath (ConvertTo-SBJson $cfg)
# PARA index of the synthetic brain (prompts.ps1 -Context resolves the dossier through it).
$indexOut=(& pwsh -NoProfile -File (Join-Path $brain 'scripts/para.ps1') -BuildIndex 2>&1|Out-String);if($LASTEXITCODE){throw ('PARA index of the fixture failed: '+$indexOut)}
# Fake Claude Code: --version, a --help that offers stream-json and model aliases, and a streamed run that marks the task in progress.
$bin=Join-Path $Root 'bin'
$fake=Join-Path $bin 'fake-claude.ps1'
Put $fake @'
[Console]::InputEncoding=[Text.UTF8Encoding]::new($false);[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
if($args -contains '--version'){'9.9.9 (Claude Code)';exit 0}
if($args -contains '--help'){
@"
Usage: claude [options]
  --allowedTools <tools...>  Allowed tools
  --disallowedTools <tools...>  Denied tools
  --effort <level>  Effort level (low, medium, high)
  --model <model>  Model: an alias ('opus' or 'sonnet') or a full name
  --output-format <format>  Output format: "text", "json" or "stream-json"
  --permission-mode <mode>  Permission mode
  --verbose  Verbose
  -p, --print  Print response and exit
"@;exit 0}
$prompt=[Console]::In.ReadToEnd()
# One-shot read-only analyses (agents.ps1 -Analyze): a claude -p --output-format json envelope with the structured answer as text.
if($prompt -match '# Output'){
    $answer=if($prompt -match 'DOC06'){
        @{sections=@(@{title='Verifiche';body='- Esegui npm test prima di chiudere un task.';rationale='Script di test del prodotto.';sources=@('README.md')});coveredElsewhere=@(@{topic='Commit e push';where='global'});warnings=@()}
    }elseif($prompt -notmatch 'Answers of the owner so far\s*\r?\n\(none yet\)'){
        @{taskId='E2E-4';verdict='autonomous-now';summary='Con la scelta fatta il task è autonomo.';blockersRemaining=@();calls=@(@{name='propose_task_update';arguments=@{questionId=$null;header=$null;question=$null;options=$null;multiSelect=$null;recommended=$null;description='Aggiorna il README con la sezione scelta.';acceptance=@('README.md contiene la sezione Installazione','npm test passa');execution='autonomous';awaiting='';requires=@();dependencies=$null;stateReason='Scelta della persona registrata: sezione Installazione.';reason=$null}})}
    }else{
        @{taskId='E2E-4';verdict='needs-answers';summary='Serve sapere quale sezione aggiungere.';blockersRemaining=@();calls=@(@{name='ask_user';arguments=@{questionId='section';header='Sezione';question='Quale sezione aggiungere al README?';options=@(@{id='install';label='Installazione';description='Passi di installazione'},@{id='usage';label='Uso';description='Esempi d''uso'});multiSelect=$false;recommended='install';description=$null;acceptance=$null;execution=$null;awaiting=$null;requires=$null;dependencies=$null;stateReason=$null;reason=$null}})}
    }
    [Console]::Out.WriteLine((@{type='result';subtype='success';is_error=$false;result=($answer|ConvertTo-Json -Depth 12 -Compress)}|ConvertTo-Json -Compress -Depth 4))
    exit 0
}
$id=if($prompt -match 'SOLO il task (\S+)'){$Matches[1]}else{''}
$pause=if($env:SB_E2E_AGENT_SECONDS){[int]$env:SB_E2E_AGENT_SECONDS}else{3}
function Emit($o){[Console]::Out.WriteLine(($o|ConvertTo-Json -Compress -Depth 8));[Console]::Out.Flush()}
# SB_E2E_AGENT_LIMIT_SECONDS: the first run hits a plan limit that resets after that many seconds (marker file beside the brain),
# in the shape of a real Claude Code limit (rejected rate_limit_event, then an error result); the next runs work.
$limitMark=Join-Path (Split-Path $env:SB_E2E_BRAIN) 'agent-limit.mark'
if($env:SB_E2E_AGENT_LIMIT_SECONDS -and !(Test-Path -LiteralPath $limitMark)){
    [IO.File]::WriteAllText($limitMark,'1')
    Emit @{type='system';subtype='init';model='fake-opus'}
    Emit @{type='rate_limit_event';rate_limit_info=@{status='rejected';resetsAt=[DateTimeOffset]::UtcNow.AddSeconds([int]$env:SB_E2E_AGENT_LIMIT_SECONDS).ToUnixTimeSeconds();rateLimitType='five_hour'}}
    [Console]::Out.Write((@{type='result';is_error=$true;result='You have hit your limit'}|ConvertTo-Json -Compress));exit 1
}
Emit @{type='system';subtype='init';model='fake-opus'}
Emit @{type='assistant';message=@{content=@(@{type='tool_use';name='Read';input=@{file_path='README.md'}})}}
Start-Sleep -Seconds $pause
Emit @{type='assistant';message=@{content=@(@{type='tool_use';name='Bash';input=@{command='npm test'}})}}
Start-Sleep -Seconds $pause
& pwsh -NoProfile -File (Join-Path $env:SB_E2E_BRAIN 'scripts/knowledge.ps1') -CheckoutPath (Get-Location).Path -UpdateTaskId $id -Status in_progress -StateReason 'Fake agent e2e'|Out-Null
Emit @{type='assistant';message=@{content=@(@{type='text';text='Task sintetico completato'})}}
Emit @{type='result';subtype='success';is_error=$false;result='ok'}
exit 0
'@
if($IsWindows){Put (Join-Path $bin 'claude.cmd') "@pwsh -NoProfile -File `"%~dp0fake-claude.ps1`" %*`r`n"}
else{Put (Join-Path $bin 'claude') "#!/bin/sh`nexec pwsh -NoProfile -File `"`$(dirname `"`$0`")/fake-claude.ps1`" `"`$@`"`n";& chmod +x (Join-Path $bin 'claude')}
$configDir=Join-Path $Root 'app-config'
[IO.Directory]::CreateDirectory($configDir)|Out-Null
ConvertTo-SBJson ([ordered]@{brain=$brain;checkout=$checkout;identity=$identity;tracker=(Join-Path $dossier 'tracker.json');dossier=$dossier;config=$configPath;bin=$bin;configDir=$configDir;hostId=$hostId})
