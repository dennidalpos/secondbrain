#requires -Version 7.5
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Portable.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Publication.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Mcp.psm1') -Force
$checks=0
function Assert-Portable($Value,[string]$Message){if(!$Value){throw 'FAIL PORTABLE: '+$Message};$script:checks++;'PASS PORTABLE: '+$Message}
function Reject-Portable([scriptblock]$Action,[string]$Message){$failed=$false;try{& $Action|Out-Null}catch{$failed=$true};Assert-Portable $failed $Message}
function Put-Portable([string]$Path,[string]$Text){[IO.Directory]::CreateDirectory((Split-Path $Path))|Out-Null;[IO.File]::WriteAllText($Path,$Text,[Text.UTF8Encoding]::new($false))}
function Git-Portable([string]$Path,[string[]]$Arguments){$result=Invoke-SBGit $Path $Arguments;if($result.code -ne 0){throw $result.error};$result.output}
$fixture=Join-Path (Get-SBTestRoot) ('portable-'+[guid]::NewGuid().ToString('N'))
$brain=Join-Path $fixture 'brain';$repos=Join-Path $fixture 'nonstandard source roots'
try{
    Assert-Portable ((ConvertTo-SBRepositoryIdentity 'git@gitlab.example:group/nested/repo.git') -eq 'gitlab.example/group/nested/repo') 'GitLab annidato senza vincolo owner'
    Assert-Portable ((ConvertTo-SBRepositoryIdentity 'https://user:private@github.com/OWNER/REPO.git') -eq 'github.com/owner/repo') 'identita normalizzata senza credenziali'
    Assert-Portable ((ConvertTo-SBRepositoryIdentity 'git@ssh.dev.azure.com:v3/org/project/repo') -eq 'dev.azure.com/org/project/_git/repo') 'alias SSH Azure DevOps'
    Assert-Portable ((ConvertTo-SBRepositoryIdentity 'file:///not-a-remote') -eq $null) 'remoto file non promosso a identita globale'
    Assert-Portable (Test-SBRepositoryIdentity ('local:'+('a'*32))) 'identita locale persistente'
    Reject-Portable {Assert-SBCentralDataPath $brain (Join-Path $fixture 'elsewhere')} 'output esterno rifiutato'
    [IO.Directory]::CreateDirectory((Join-Path $brain 'scripts'))|Out-Null
    Get-ChildItem -LiteralPath $PSScriptRoot -File|Copy-Item -Destination (Join-Path $brain 'scripts')
    [IO.Directory]::CreateDirectory((Join-Path $brain 'config'))|Out-Null
    foreach($name in @('shared.json','tracker.schema.json','prompt-catalog.schema.json')){Copy-Item -LiteralPath (Join-Path $PSScriptRoot ('../config/'+$name)) -Destination (Join-Path $brain ('config/'+$name))}
    [IO.Directory]::CreateDirectory((Join-Path $brain 'direttive'))|Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../direttive/prompts') -Destination (Join-Path $brain 'direttive/prompts') -Recurse
    Put-Portable (Join-Path $brain 'direttive/AGENTS.global_ide.md') "# Fixture`nRevisione 4.0 — 2026-10-29."
    Put-Portable (Join-Path $brain 'direttive/workstation.template.md') '<!-- secondbrain:tracker-contract:1 -->'
    $approval=@{authorization='isolated fixture';files=@{}}
    foreach($name in @('AGENTS.global_ide.md','workstation.template.md')){$approval.files['direttive/'+$name]=Get-SBFileHash (Join-Path $brain ('direttive/'+$name))}
    Put-Portable (Join-Path $brain 'direttive/approved.json') (ConvertTo-SBJson $approval)
    foreach($name in @('one','two','no-remote')){
        $path=Join-Path $repos $name;[IO.Directory]::CreateDirectory($path)|Out-Null;Git-Portable $path @('init','-q')|Out-Null
        Put-Portable (Join-Path $path 'README.md') ('# '+$name)
    }
    $repo=Join-Path $repos 'one';$other=Join-Path $repos 'two'
    Git-Portable $repo @('remote','add','origin','https://gitlab.example/team/one.git')|Out-Null
    Git-Portable $other @('remote','add','origin','https://other.example/team/two.git')|Out-Null
    foreach($excludedName in @('node_modules','.venv','bin','obj')){
        $excludedDir=Join-Path $repo $excludedName;[IO.Directory]::CreateDirectory($excludedDir)|Out-Null
        Put-Portable (Join-Path $excludedDir 'dummy.txt') 'dummy'
    }
    $checkpoint=Join-Path $brain '.runtime/discovery.json'
    $first=Invoke-SBHostDiscovery -BrainRoot $brain -Roots @($repos) -ReportPath $checkpoint -MaxDirectories 1
    Assert-Portable ($first.paused -and !$first.complete -and $first.pending.Count -gt 0) 'discovery limitata dichiara checkpoint incompleto'
    $report=Invoke-SBHostDiscovery -BrainRoot $brain -ResumePath $checkpoint -ReportPath $checkpoint
    Assert-Portable ($report.complete -and $report.repositories.Count -eq 3) 'ripresa scopre tre repo fuori dalla vecchia radice'
    Assert-Portable (@($report.excluded|Where-Object {$_.reason -eq 'known-system-or-build-tree'}).Count -ge 4) 'alberi di sistema e build registrati in excluded'
    Assert-Portable (!@($report.visited|Where-Object {$_ -match '(?:node_modules|\.venv|bin|obj)'}).Count) 'alberi noti esclusi dalla visita'
    Assert-Portable (!(Test-Path -LiteralPath (Join-Path $repo 'AGENTS.md'))) 'discovery non inizializza repository'
    Assert-Portable (@($report.repositories|Where-Object requiresIdentity).Count -eq 1) 'repo senza origin richiede identita'
    $choice=@{schemaVersion=1;confirmed=$true;confirmation='fixture user selection';reportPath=$checkpoint;reportSha256=(Get-SBFileHash $checkpoint);
        repositories=@(@{id=(@($report.repositories|Where-Object path -eq $repo)[0].id)});ides=@()}
    $selection=Join-Path $brain '.runtime/selection.json';Put-Portable $selection (ConvertTo-SBJson $choice)
    $localChoice=@{}+$choice;$localChoice.repositories=@(@{id=(@($report.repositories|Where-Object requiresIdentity)[0].id)})
    Put-Portable $selection (ConvertTo-SBJson $localChoice)
    $localFirst=Invoke-SBHostActivation $brain $selection;$localSecond=Invoke-SBHostActivation $brain $selection
    Assert-Portable ($localFirst.repositories[0].identity -eq $localSecond.repositories[0].identity -and $localFirst.repositories[0].identity -match '^local:[a-f0-9]{32}$') 'identita locale stabile fra anteprima e applicazione'
    Put-Portable $selection (ConvertTo-SBJson $choice)
    $preview=Invoke-SBHostActivation $brain $selection
    Assert-Portable (!$preview.applied -and !(Test-Path -LiteralPath $preview.configuration)) 'anteprima attivazione senza scritture'
    $unconfirmed=@{}+$choice;$unconfirmed.confirmed=$false;Put-Portable $selection (ConvertTo-SBJson $unconfirmed)
    Reject-Portable {Invoke-SBHostActivation $brain $selection -Apply} 'selezione non confermata rifiutata'
    Put-Portable $selection (ConvertTo-SBJson $choice)
    $manualAsset=@($report.ides|Where-Object mode -eq 'manual')[0]
    $multiAccount=@{}+$choice;$multiAccount.ides=@(@{id=$manualAsset.id;accountAlias='account-a'},@{id=$manualAsset.id;accountAlias='account-b'})
    Put-Portable $selection (ConvertTo-SBJson $multiAccount)
    $multiPreview=Invoke-SBHostActivation $brain $selection
    Assert-Portable (@($multiPreview.ideBindings|ForEach-Object id|Sort-Object -Unique).Count -eq 2) 'account distinti hanno associazioni IDE distinte'
    Put-Portable $selection (ConvertTo-SBJson $choice)
    $beforeEnvironment=[Environment]::GetEnvironmentVariable('SECONDBRAIN_HOME','User')
    $activation=Invoke-SBHostActivation $brain $selection -Apply
    Assert-Portable ($activation.applied -and [Environment]::GetEnvironmentVariable('SECONDBRAIN_HOME','User') -eq $beforeEnvironment) 'attivazione fixture non cambia ambiente utente'
    $cfg=Read-SBJson $activation.configuration $null
    Assert-Portable ($cfg.bindings.Count -eq 1 -and !$cfg.ContainsKey('monitorEnabled')) 'solo asset selezionato e nessun monitor'
    Assert-Portable (!(Test-Path -LiteralPath (Join-Path $other 'AGENTS.md'))) 'repository non selezionato intatto'
    $stageRoot=Join-Path $cfg.backupRoot 'stage-fixture';[IO.Directory]::CreateDirectory($stageRoot)|Out-Null
    $stageRecords=@{
        'old-completed'=@{text=(ConvertTo-SBJson @{schemaVersion=1;path='x';status='completed'});age=200}
        'old-interrupted'=@{text=(ConvertTo-SBJson @{schemaVersion=1;path='x';status='interrupted'});age=200}
        'recent-completed'=@{text=(ConvertTo-SBJson @{schemaVersion=1;path='x';status='completed'});age=1}
        'old-unreadable'=@{text='non json';age=200}}
    foreach($name in $stageRecords.Keys){$f=Join-Path $stageRoot ($name+'.stage');Put-Portable $f $stageRecords[$name].text;(Get-Item -LiteralPath $f).LastWriteTimeUtc=[DateTime]::UtcNow.AddDays(-$stageRecords[$name].age)}
    $stageFiles=@(Get-ChildItem -LiteralPath $stageRoot -File)
    $stageHashes=ConvertTo-SBJson @($stageFiles|ForEach-Object {@{n=$_.Name;h=(Get-SBFileHash $_.FullName)}}|Sort-Object n)
    $stageReport=Get-SBStageRetention $stageRoot 90
    Assert-Portable ($stageReport.candidates.Count -eq 1 -and $stageReport.candidates[0].path -like '*old-completed.stage' -and $stageReport.retained.recent -eq 1 -and $stageReport.retained.notCompleted -eq 1 -and $stageReport.retained.unreadable -eq 1) 'retention .stage: solo completati oltre soglia sono candidati'
    $stagePreview=(& pwsh -NoProfile -File (Join-Path $brain 'scripts/cleanup.ps1') -ConfigPath $activation.configuration -ListStageRecords -OlderThanDays 90 | Out-String)
    Assert-Portable ($LASTEXITCODE -eq 0 -and $stagePreview -match '"applied": false') 'retention .stage: anteprima CLI senza applicazione'
    & pwsh -NoProfile -File (Join-Path $brain 'scripts/cleanup.ps1') -ConfigPath $activation.configuration -ListStageRecords -Apply *> $null
    Assert-Portable ($LASTEXITCODE -ne 0) 'retention .stage: anteprima non combinabile con Apply'
    Assert-Portable ((ConvertTo-SBJson @(Get-ChildItem -LiteralPath $stageRoot -File|ForEach-Object {@{n=$_.Name;h=(Get-SBFileHash $_.FullName)}}|Sort-Object n)) -ceq $stageHashes -and @(Get-ChildItem -LiteralPath $stageRoot -File).Count -eq 4) 'retention .stage: nessun record modificato o eliminato'
    $cfg.brainRoot=$brain;$cfg.configPath=$activation.configuration;$cfg.allowedOwners=@();$cfg.coordinationRoot=Join-Path $brain '.runtime/access';$cfg.sessionTimeoutMinutes=30
    $firstSync=Invoke-SBPortableSync $cfg
    Assert-Portable ($firstSync.changes.Count -ge 1) 'Sync distribuisce dopo approvazione fixture'
    $agents=Join-Path $repo 'AGENTS.md';$agentsText=Read-SBText $agents
    Assert-Portable ($agentsText -match 'SECONDBRAIN_HOME' -and $agentsText -notmatch [regex]::Escape($brain)) 'blocco pubblico senza percorso privato'
    $dossier=Join-Path $brain $cfg.bindings[0].dossier
    Assert-Portable (Test-Path -LiteralPath (Join-Path $dossier 'index.md')) 'TOC presente per repo gestito'
    $stableHash=Get-SBFileHash $agents
    $secondSync=Invoke-SBPortableSync $cfg
    Assert-Portable ((Get-SBFileHash $agents) -eq $stableHash -and $secondSync.changes.Count -eq 0 -and $secondSync.filesAligned -eq $true) 'allineamento idempotente'
    $recoveryFile=Join-Path $brain '.runtime/recovery-scenario.txt';Put-Portable $recoveryFile 'before recovery scenario'
    $recoveryManifest=Invoke-SBParaTransaction @(@{path=$recoveryFile;expected=(Get-SBFileHash $recoveryFile);bytes=[Text.Encoding]::UTF8.GetBytes('after transaction')}) $cfg.backupRoot $brain
    $recoveryCLI=Join-Path $brain 'scripts/recover.ps1'
    & pwsh -NoProfile -File $recoveryCLI -ManifestPath $recoveryManifest *> $null
    Assert-Portable ($LASTEXITCODE -eq 0 -and (Read-SBText $recoveryFile) -eq 'after transaction') 'recupero CLI anteprima senza configurazione utilizzabile o scritture'
    & pwsh -NoProfile -File $recoveryCLI -ManifestPath $recoveryManifest -Apply *> $null
    Assert-Portable ($LASTEXITCODE -eq 0 -and (Read-SBText $recoveryFile) -eq 'before recovery scenario' -and (Test-Path -LiteralPath $recoveryManifest)) 'recupero CLI applica il manifest e conserva originali'
    Put-Portable $recoveryFile 'later unrelated user edit'
    & pwsh -NoProfile -File $recoveryCLI -ManifestPath $recoveryManifest -Apply *> $null
    Assert-Portable ($LASTEXITCODE -ne 0 -and (Read-SBText $recoveryFile) -eq 'later unrelated user edit') 'recupero CLI rifiuta modifiche concorrenti successive'
    $proofPath=Join-Path $brain '.runtime/output-proof.json';Put-Portable $proofPath '{"scenario":"synthetic protocol validation; not a product build"}'
    $cfg.bindings[0].outputStatus='verified';$cfg.bindings[0].outputEvidence=$proofPath;$cfg.bindings[0].outputEvidenceSha256=Get-SBFileHash $proofPath
    $verifiedOutputs=Invoke-SBPortableSync $cfg -Check
    Assert-Portable (!@($verifiedOutputs.issues|Where-Object kind -eq 'output-location-unverified').Count) 'prova output vincolata ai byte registrati'
    Put-Portable $proofPath 'changed evidence'
    $changedOutputs=Invoke-SBPortableSync $cfg -Check
    Assert-Portable (@($changedOutputs.issues|Where-Object kind -eq 'output-location-unverified').Count -eq 1) 'prova output modificata non riutilizzata'
    $cfg.bindings[0].outputStatus='unverified'
    $startup=Get-SBStartupContext $brain $dossier $repo
    Assert-Portable ($startup.withinBudget -and !$startup.originalsTruncated -and $startup.unit -eq 'characters-not-tokens') 'avvio selettivo misurato senza truncation'
    $projectionTask=@{tasks=@(@{id='ACTIVE';title='Active fixture';status='todo';priority='P2';dependencies=@();acceptance=@('full criteria preserved in source');extensions=@{stateReason='requires fixture prerequisite'}})}
    $minimal=@(Get-SBTaskProjection $projectionTask);$detail=@(Get-SBTaskProjection $projectionTask -IncludeAcceptance)
    Assert-Portable (!$minimal[0].ContainsKey('acceptance') -and $detail[0].acceptance.Count -eq 1 -and $minimal[0].blocker -eq 'requires fixture prerequisite') 'task iniziali selettivi con criteri completi disponibili su richiesta'
    # Profilo di avvio snello: sezioni storiche non caricate, indice dei livelli, task brevi, nulla eliminato.
    $baseContext=Read-SBText (Join-Path $dossier 'context.md');$baseMemory=Read-SBText (Join-Path $dossier 'memory.md')
    $historyBulk=('cronaca di lotto '*1500)
    Put-Portable (Join-Path $dossier 'memory.md') ($baseMemory.TrimEnd()+"`n`n## Decisioni durevoli`n`nESSENZIALE-MEMORIA`n`n## Cronaca lotti (storico)`n`n"+$historyBulk+"`n`n## Altro storico`n<!-- sb:tier=history -->`nSTORICO-MARCATO`n")
    Put-Portable (Join-Path $dossier 'context.md') ($baseContext.TrimEnd()+"`n`n## Stato`n`nESSENZIALE-CONTESTO`n")
    $fullStartup=Get-SBStartupContext $brain $dossier $repo -Profile Full
    $slimStartup=Get-SBStartupContext $brain $dossier $repo -Profile Slim -Budget 20000
    Assert-Portable ($fullStartup.profile -eq 'Full' -and $fullStartup.parts.memory.Contains('STORICO-MARCATO') -and $fullStartup.parts.memory.Contains($historyBulk) -and !$fullStartup.parts.ContainsKey('levels') -and @($fullStartup.omittedParts).Count -eq 0) 'profilo Full carica tutto, invariato'
    Assert-Portable ($slimStartup.profile -eq 'Slim' -and $slimStartup.parts.memory.Contains('ESSENZIALE-MEMORIA') -and $slimStartup.parts.context.Contains('ESSENZIALE-CONTESTO') -and !$slimStartup.parts.memory.Contains('STORICO-MARCATO') -and !$slimStartup.parts.memory.Contains('cronaca di lotto')) 'profilo Slim carica le sezioni essenziali e salta quelle storiche'
    $uncapped=Get-SBStartupContext $brain $dossier $repo -Profile Full -Budget 0
    Assert-Portable ($uncapped.withinBudget -and !$uncapped.needsCompaction -and $uncapped.parts.memory.Contains($historyBulk)) 'Budget 0 = nessun tetto: Full carica tutto senza segnalare compattazione'
    $manyMatches=Find-SBKnowledge -BrainRoot $brain -Search 'cronaca di lotto' -Dossier $dossier -Budget 0
    Assert-Portable ($manyMatches.count -eq $manyMatches.totalMatches -and $manyMatches.withinBudget -and $manyMatches.count -ge 1) 'ricerca senza tetto restituisce tutti i riscontri pertinenti'
    Assert-Portable ($slimStartup.characters -lt $fullStartup.characters -and $slimStartup.withinBudget -and $fullStartup.characters -gt 20000) 'profilo Slim rientra in 20.000 caratteri mentre Full no'
    Assert-Portable ($slimStartup.parts.levels -match 'Cronaca lotti' -and $slimStartup.parts.levels -match 'Altro storico' -and $slimStartup.parts.levels -match 'knowledge\.ps1' -and @($slimStartup.omittedParts|Where-Object {$_.part -like 'memory*'}).Count -eq 1) 'indice dei livelli elenca le sezioni non caricate e come richiederle'
    Assert-Portable ($slimStartup.parts.tasks -notmatch 'acceptance' -and $slimStartup.parts.tasks -notmatch '\{') 'task di avvio snelli in forma testuale breve'
    Put-Portable (Join-Path $dossier 'memory.md') $baseMemory;Put-Portable (Join-Path $dossier 'context.md') $baseContext
    $plainSlim=Get-SBStartupContext $brain $dossier $repo -Profile Slim
    $plainFull=Get-SBStartupContext $brain $dossier $repo -Profile Full
    Assert-Portable ($plainSlim.parts.memory -eq $plainFull.parts.memory -and $plainSlim.parts.context -eq $plainFull.parts.context) 'dossier senza marcatori di livello: Slim carica per intero come Full'
    $tiered=Split-SBTieredMarkdown ("# T`n`npre`n`n## A`n`na`n`n## B (Storico)`n`nb`n`n## C`n`n<!-- sb:tier=history -->`nc`n")
    Assert-Portable ($tiered.essential.Contains('pre') -and $tiered.essential.Contains('## A') -and !$tiered.essential.Contains('## B') -and !$tiered.essential.Contains('## C') -and $tiered.history.Contains('b') -and @($tiered.historyTitles).Count -eq 2) 'Split-SBTieredMarkdown separa preambolo, essenziale e storico'
    $report=Format-SBStartupReport $slimStartup @{'Direttive di prova'='123 caratteri'}
    Assert-Portable ($report -match 'RAPPORTO CONTESTO DI AVVIO' -and $report -match 'Profilo: Slim' -and $report -match 'Direttive di prova' -and $report -match 'caratteri/4') 'rapporto di avvio con parti, stima token e direttive'
    $oldContext=Read-SBText (Join-Path $dossier 'context.md');$oldMemory=Read-SBText (Join-Path $dossier 'memory.md')
    Put-Portable (Join-Path $dossier 'context.md') ($oldContext+('history '*8000))
    Assert-Portable (Get-SBStartupContext $brain $dossier $repo).needsCompaction 'budget ecceduto segnalato senza tagli'
    $candidate=@{schemaVersion=1;repository=$cfg.bindings[0].identity;reviewed=$true;reviewNote='essential facts reviewed in synthetic fixture';sources=@{};summaries=@{'context.md'=$oldContext;'memory.md'=$oldMemory};openTaskIds=@()}
    foreach($name in @('context.md','memory.md')){$candidate.sources[$name]=Get-SBFileHash (Join-Path $dossier $name)}
    $candidatePath=Join-Path $brain '.runtime/compaction.json';Put-Portable $candidatePath (ConvertTo-SBJson $candidate)
    $compaction=Invoke-SBDossierCompaction -BrainRoot $brain -Dossier $dossier -CandidatePath $candidatePath -BackupRoot $cfg.backupRoot -CheckoutPath $repo -Apply
    Assert-Portable ($compaction.applied -and $compaction.originalsPreserved) 'compattazione transazionale applicata'
    foreach($original in $compaction.archives){Assert-Portable ((Get-SBFileHash (Join-Path $dossier $original.archive)) -eq $original.sha256) ('originale preservato '+$original.source)}
    Assert-Portable (Get-SBStartupContext $brain $dossier $repo).withinBudget 'contesto rientra nel budget'
    Reject-Portable {Invoke-SBDossierCompaction -BrainRoot $brain -Dossier $dossier -CandidatePath $candidatePath -BackupRoot $cfg.backupRoot -Apply} 'candidato obsoleto rifiutato'
    $searchResults=Find-SBKnowledge -BrainRoot $brain -Search 'autorizzazioni' -Dossier $dossier
    Assert-Portable ($searchResults.count -gt 0 -and $searchResults.withinBudget) 'ricerca trasversale restituisce riscontri entro budget'
    Assert-Portable ($searchResults.extracts[0].path -and $searchResults.extracts[0].line -gt 0 -and $searchResults.extracts[0].sha256.Length -eq 64) 'estratto di ricerca contiene percorso, riga e sha256'
    $archiveMatches=Find-SBKnowledge -BrainRoot $brain -Search 'archive' -Dossier $dossier
    Assert-Portable ($archiveMatches.count -gt 0 -and @($archiveMatches.extracts|Where-Object {$_.path -match 'history/compaction'}).Count -gt 0) 'ricerca esplora history/compaction'
    $cappedSearch=Find-SBKnowledge -BrainRoot $brain -Search 'autorizzazioni' -Dossier $dossier -Budget 50
    Assert-Portable (!$cappedSearch.withinBudget -and $cappedSearch.extracts.Count -lt $searchResults.totalMatches) 'budget limitato segnalato da withinBudget'
    # Ricerca per pertinenza: termini multipli, sezioni ordinate per copertura, titolo e frase; estratti con percorso, riga e sha256 invariati.
    $relevanceMemory=Read-SBText (Join-Path $dossier 'memory.md')
    Put-Portable (Join-Path $dossier 'memory.md') ($relevanceMemory.TrimEnd()+"`n`n## Rotazione chiavi`n`nLa rotazione delle chiavi avviene ogni trimestre.`n`n## Archivio parziale`n`nSolo la parola rotazione compare qui.`n`n## Altro`n`nNessun riscontro rilevante.`n")
    $literalPhrase=Find-SBKnowledge -BrainRoot $brain -Search 'rotazione chiavi trimestre' -Dossier $dossier
    $ranked=Find-SBKnowledge -BrainRoot $brain -Search 'rotazione chiavi trimestre' -Dossier $dossier -Mode Relevance
    Assert-Portable ($literalPhrase.count -eq 0) 'ricerca letterale: la frase non esatta non produce riscontri'
    Assert-Portable ($ranked.mode -eq 'Relevance' -and $ranked.count -ge 2 -and $ranked.withinBudget -and $ranked.totalMatches -eq $ranked.count) 'ricerca per pertinenza senza tetto restituisce tutti i riscontri'
    Assert-Portable ($ranked.extracts[0].section -eq 'Rotazione chiavi' -and $ranked.extracts[0].score -gt $ranked.extracts[-1].score -and @($ranked.extracts|Where-Object {$_.section -eq 'Altro'}).Count -eq 0) 'sezione con piu termini e titolo pertinente prima, sezione senza riscontri esclusa'
    Assert-Portable ($ranked.extracts[0].path -match 'memory\.md$' -and $ranked.extracts[0].line -gt 0 -and $ranked.extracts[0].sha256 -eq (Get-SBFileHash (Join-Path $dossier 'memory.md'))) 'estratto per pertinenza con percorso, riga e sha256 invariati'
    $rankedCapped=Find-SBKnowledge -BrainRoot $brain -Search 'rotazione chiavi trimestre' -Dossier $dossier -Mode Relevance -Budget 30
    Assert-Portable (!$rankedCapped.withinBudget -and $rankedCapped.count -lt $ranked.totalMatches) 'ricerca per pertinenza: budget facoltativo segnalato da withinBudget'
    Assert-Portable ((Find-SBKnowledge -BrainRoot $brain -Search 'il di la' -Dossier $dossier -Mode Relevance).tokens.Count -eq 3 -and (Find-SBKnowledge -BrainRoot $brain -Search 'La rotazione' -Dossier $dossier -Mode Relevance).tokens.Count -eq 1) 'parole vuote ignorate, salvo query composta solo da parole vuote'
    Put-Portable (Join-Path $dossier 'memory.md') $relevanceMemory
    $readyFixtureTasks=@(
        @{id='DEP-DONE';title='Done task';status='done';priority='P2';dependencies=@();acceptance=@('criteria');extensions=@{}},
        @{id='TASK-READY';title='Ready task';status='todo';priority='P1';dependencies=@(@{id='DEP-DONE'});acceptance=@('criteria');extensions=@{}},
        @{id='TASK-BLOCKED-DEP';title='Blocked by dep';status='todo';priority='P2';dependencies=@(@{id='TASK-READY'});acceptance=@('criteria');extensions=@{}},
        @{id='TASK-BLOCKED-STAT';title='Explicitly blocked';status='blocked';priority='P2';dependencies=@();acceptance=@('criteria');extensions=@{}},
        @{id='TASK-CROSS-READY';title='Cross ready';status='todo';priority='P1';dependencies=@(@{id='EXT-DONE';repository='other.repo'});acceptance=@('criteria');extensions=@{}},
        @{id='TASK-CROSS-BLOCKED';title='Cross blocked';status='todo';priority='P2';dependencies=@(@{id='EXT-TODO';repository='other.repo'});acceptance=@('criteria');extensions=@{}}
    )
    $relatedMock=@{
        'other.repo'=@{
            repository='other.repo';
            tasks=@(
                @{id='EXT-DONE';status='done'},
                @{id='EXT-TODO';status='todo'}
            )
        }
    }
    $readyProjection=@(Get-SBTaskProjection @{repository='my.repo';tasks=$readyFixtureTasks} -ReadyOnly -RelatedTrackers $relatedMock)
    $readyIds=@($readyProjection|ForEach-Object {$_.id})
    Assert-Portable ($readyIds.Count -eq 2 -and 'TASK-READY' -in $readyIds -and 'TASK-CROSS-READY' -in $readyIds) 'proiezione -ReadyOnly filtra task con dipendenze soddisfatte incluse cross-repo'
    Assert-Portable ('DEP-DONE' -notin $readyIds -and 'TASK-BLOCKED-DEP' -notin $readyIds -and 'TASK-BLOCKED-STAT' -notin $readyIds -and 'TASK-CROSS-BLOCKED' -notin $readyIds) 'task bloccati o con dipendenze non soddisfatte esclusi'
    $trackerFilePath=Join-Path $dossier 'tracker.json'
    $trackerDoc=Read-SBJson $trackerFilePath $null
    $testTask=New-SBTrackerTask @{id='FIXTURE-TASK';title='Fixture task';status='todo'} $trackerDoc.repository 'test' 'test.md' (Get-SBTextHash 'test') 'line:1'
    $trackerDoc.tasks=@($testTask)
    Put-Portable $trackerFilePath (ConvertTo-SBJson $trackerDoc)
    $statusUpdate=Set-SBTrackerTaskStatus -BrainRoot $brain -Path $trackerFilePath -TaskId 'FIXTURE-TASK' -Status 'in_progress' -StateReason 'in-progress verification' -Evidence @(@{reference='history/test.md';outcome='passed'}) -BackupRoot $cfg.backupRoot
    Assert-Portable ($statusUpdate.applied -and (Test-Path -LiteralPath $statusUpdate.manifest)) 'aggiornamento transazionale applicato con manifest'
    $reloadedTracker=Read-SBJson $trackerFilePath $null
    $reloadedTask=@($reloadedTracker.tasks|Where-Object id -eq 'FIXTURE-TASK')[0]
    Assert-Portable ($reloadedTask.status -eq 'in_progress' -and $reloadedTask.extensions.stateReason -eq 'in-progress verification' -and $reloadedTask.evidence.Count -ge 1) 'stato e metadati task aggiornati su disco'
    Reject-Portable {Set-SBTrackerTaskStatus -BrainRoot $brain -Path $trackerFilePath -TaskId 'FIXTURE-TASK' -Status 'invalid-state' -BackupRoot $cfg.backupRoot} 'stato non ammesso rifiutato'
    Reject-Portable {Set-SBTrackerTaskStatus -BrainRoot $brain -Path $trackerFilePath -TaskId 'NONEXISTENT-ID' -Status 'done' -BackupRoot $cfg.backupRoot} 'task inesistente rifiutato'
    Assert-Portable ((Read-SBJson $trackerFilePath $null).tasks.Count -eq 1) 'rifiuti non modificano il numero di task o lo schema'
    Assert-Portable ((Resolve-SBTrackerBackupRoot $brain) -eq $cfg.backupRoot) 'backupRoot predefinito del tracker letto dalla configurazione dell host'
    $defaultBackup=Set-SBTrackerTaskStatus -BrainRoot $brain -Path $trackerFilePath -TaskId 'FIXTURE-TASK' -Status 'in_progress' -StateReason 'backupRoot predefinito'
    Assert-Portable ($defaultBackup.applied -and ([IO.Path]::GetFullPath($defaultBackup.manifest)).StartsWith($cfg.backupRoot,[StringComparison]::OrdinalIgnoreCase)) 'aggiornamento senza BackupRoot salva il manifest nel backupRoot dell host'
    Assert-Portable (!(Test-Path -LiteralPath (Join-Path $brain '.runtime/backups/transactions'))) 'nessun backup nel percorso di ripiego quando l host e configurato'
    $noHostBrain=Join-Path $fixture 'brain-no-host'
    Assert-Portable ((Resolve-SBTrackerBackupRoot $noHostBrain) -eq (Join-Path $noHostBrain '.runtime/backups/transactions')) 'senza configurazione host resta il percorso di transazione sotto .runtime'
    $badHostPath=Get-SBHostConfigPath $noHostBrain;Put-Portable $badHostPath (ConvertTo-SBJson @{schemaVersion=3;mode='portable';workstationId='bad'})
    Reject-Portable {Resolve-SBTrackerBackupRoot $noHostBrain} 'configurazione host senza backupRoot non ripiega in silenzio'
    $workA=Get-SBWorkEnvironment $brain $cfg.workstationId $cfg.bindings[0].identity 'project-a' 'runtime-a'
    $workB=Get-SBWorkEnvironment $brain $cfg.workstationId $cfg.bindings[0].identity 'project-b' 'runtime-a'
    Assert-Portable ($workA.root -ne $workB.root -and $workA.environment.TEMP.StartsWith((Join-Path $brain '.runtime'))) 'cache e build isolate nel cervello'
    Assert-Portable ($workA.status -eq 'configuration-only' -and $workA.exceptions.Count -gt 0) 'configurazione non spacciata per verifica del tool'
    $secret='gh'+'p_'+('x'*36)
    Put-Portable (Join-Path $repo 'private.txt') ('token='+$secret)
    Git-Portable $repo @('add','README.md','private.txt')|Out-Null
    Git-Portable $repo @('-c','user.name=Fixture','-c','user.email=fixture@example.invalid','-c','commit.gpgsign=false','commit','-qm','synthetic secret history')|Out-Null
    Put-Portable (Join-Path $repo 'private.txt') 'now clean'
    Git-Portable $repo @('add','private.txt')|Out-Null
    $publication=Test-SBPublication -BrainRoot $brain -RepositoryPath $repo
    Assert-Portable (!$publication.ready -and @($publication.findings|Where-Object {$_.rule -eq 'credential' -and $_.surface -eq 'history'}).Count -gt 0) 'segreto storico distinto dal working tree pulito'
    Assert-Portable ((ConvertTo-SBJson $publication) -notmatch [regex]::Escape($secret)) 'valori sensibili non presenti nel rapporto'
    Put-Portable (Join-Path $repo 'private.txt') 'person@example.test'
    $publication=Test-SBPublication -BrainRoot $brain -RepositoryPath $repo -MaxHistoryBlobs 1
    Assert-Portable (!$publication.complete -and !$publication.ready) 'copertura storica limitata non produce falso successo'
    Put-Portable (Join-Path $other ' private-note.txt') 'person@example.test'
    $spacedName=Test-SBPublication -BrainRoot $brain -RepositoryPath $other
    Assert-Portable (@($spacedName.findings|Where-Object {$_.path -ceq ' private-note.txt' -and $_.rule -eq 'personal-email'}).Count -gt 0) 'controllo privacy preserva nomi file con spazio iniziale'
    # Scansione in batch (un processo git per tipi/dimensioni, uno per i contenuti): stesso esito del confronto per oggetto.
    $batchRepo=Join-Path $fixture 'batch-scan';[IO.Directory]::CreateDirectory($batchRepo)|Out-Null;Git-Portable $batchRepo @('init','-q')|Out-Null
    Put-Portable (Join-Path $batchRepo 'secret.txt') ('token='+$secret)
    Put-Portable (Join-Path $batchRepo 'accent-è.md') ('contatto person@'+'example.test'+"`n"+'riga con C:\Us'+'ers\qualcuno\file')
    [IO.File]::WriteAllBytes((Join-Path $batchRepo 'utf16.txt'),([byte[]](0xFF,0xFE)+[Text.Encoding]::Unicode.GetBytes('token="'+('y'*20)+'"')))
    [IO.File]::WriteAllBytes((Join-Path $batchRepo 'bom8.txt'),([byte[]](0xEF,0xBB,0xBF)+[Text.Encoding]::UTF8.GetBytes('person@'+'example.test')))
    [IO.File]::WriteAllBytes((Join-Path $batchRepo 'blob.bin'),[byte[]](1,2,0,3,4))
    Put-Portable (Join-Path $batchRepo 'big.txt') ('x'*500)
    Git-Portable $batchRepo @('add','-A')|Out-Null
    Git-Portable $batchRepo @('-c','user.name=Fixture','-c','user.email=fixture@example.invalid','-c','commit.gpgsign=false','commit','-qm','batch scan fixture')|Out-Null
    Put-Portable (Join-Path $batchRepo 'secret.txt') 'clean'
    Git-Portable $batchRepo @('add','-A')|Out-Null
    Git-Portable $batchRepo @('-c','user.name=Fixture','-c','user.email=fixture@example.invalid','-c','commit.gpgsign=false','commit','-qm','clean secret')|Out-Null
    $batchPub=Test-SBPublication -BrainRoot $brain -RepositoryPath $batchRepo -MaxTextBytes 400
    $batchRoot=(Invoke-SBGit $batchRepo @('rev-parse','--show-toplevel')).output
    $reference=@()
    foreach($line in (Invoke-SBGit $batchRoot @('rev-list','--objects','--all')).output -split "`n"){
        if($line -notmatch '^([a-f0-9]{40,64}) (.+)$'){continue};$refOid=$Matches[1];$refPath=$Matches[2]
        if((Invoke-SBGit $batchRoot @('cat-file','-t',$refOid)).output -ne 'blob'){continue}
        if([long](Invoke-SBGit $batchRoot @('cat-file','-s',$refOid)).output -gt 400){continue}
        $refBlob=Invoke-SBGit $batchRoot @('cat-file','blob',$refOid) -PreserveOutput
        if(!$refBlob.output.Contains([char]0)){$reference+=@(Test-SBPublicationText $refBlob.output $refPath 'history' @())|ForEach-Object {$_.rule+'|'+$_.path+'|'+$_.line+'|'+$_.fingerprint}}
    }
    $batchHistory=@($batchPub.findings|Where-Object surface -eq 'history'|ForEach-Object {$_.rule+'|'+$_.path+'|'+$_.line+'|'+$_.fingerprint})
    Assert-Portable ($reference.Count -ge 4 -and (($reference|Sort-Object) -join "`n") -eq (($batchHistory|Sort-Object) -join "`n")) 'scansione storia in batch equivale al confronto per oggetto (UTF-8, BOM, UTF-16, nomi accentati)'
    Assert-Portable (@($batchPub.incomplete|Where-Object {$_.surface -eq 'history' -and $_.reason -eq 'binary-review-required' -and $_.path -ceq 'blob.bin'}).Count -eq 1) 'blob binario in storia segnalato come revisione richiesta'
    Assert-Portable (@($batchPub.incomplete|Where-Object {$_.surface -eq 'history' -and $_.reason -eq 'size-limit' -and $_.path -ceq 'big.txt'}).Count -eq 1) 'blob oltre il limite in storia segnalato come size-limit senza leggerne il contenuto'
    Assert-Portable (@($batchPub.findings|Where-Object {$_.surface -eq 'index' -and $_.rule -eq 'personal-email'}).Count -ge 1 -and !@($batchPub.incomplete|Where-Object reason -eq 'unreadable').Count) 'superficie indice letta in batch senza oggetti illeggibili'
    $batchLimited=Test-SBPublication -BrainRoot $brain -RepositoryPath $batchRepo -MaxTextBytes 400 -MaxHistoryBlobs 2
    Assert-Portable (@($batchLimited.incomplete|Where-Object {$_.surface -eq 'history' -and $_.reason -eq 'blob-limit'}).Count -eq 1 -and $batchLimited.historyBlobs -eq 2 -and !$batchLimited.complete) 'limite di blob in storia dichiarato come copertura incompleta'
    $basePub=Test-SBPublication -BrainRoot $brain -RepositoryPath $repo -Initial
    Assert-Portable (Test-Path -LiteralPath (Join-Path $brain '.runtime/publication/baseline.json')) 'Test-SBPublication genera baseline autorizzata con -Initial'
    $incrPub=Test-SBPublication -BrainRoot $brain -RepositoryPath $repo
    Assert-Portable ($incrPub.incremental -and $incrPub.baseline -ne $null) 'Test-SBPublication esegue scansione incrementale usando baseline'
    $syntheticPNG=Join-Path $brain '.runtime/captures/synthetic-test.png'
    [IO.Directory]::CreateDirectory((Split-Path $syntheticPNG))|Out-Null
    [IO.File]::WriteAllBytes($syntheticPNG,[Convert]::FromBase64String('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jCYQAAAAASUVORK5CYII='))
    $receipt=New-SBCaptureRecord -BrainRoot $brain -SourcePath $syntheticPNG -Repository 'other.example/team/two' -Application 'Synthetic validation fixture, not an app capture' -Version 'test' -Commit ('a'*40) -Scenario 'PNG protocol fixture only' -CaptureTool 'fixture bytes' -Reproduction 'run isolated tests'
    $receiptPath=Join-Path $brain '.runtime/capture.json';Put-Portable $receiptPath (ConvertTo-SBJson $receipt)
    Assert-Portable ($receipt.width -eq 1 -and !$receipt.realCaptureReviewed -and !$receipt.privacyReviewed) 'provenienza PNG non equivale a revisione della cattura'
    Reject-Portable {Export-SBPublicCapture -BrainRoot $brain -ManifestPath $receiptPath -RepositoryPath $other -Name 'test.png' -BackupRoot $cfg.backupRoot -Apply} 'asset non revisionato rifiutato'
    $receipt.realCaptureReviewed=$true;$receipt.privacyReviewed=$true;$receipt.reviewNote='Only validates export protocol using a synthetic PNG; no actual application attested.'
    Put-Portable $receiptPath (ConvertTo-SBJson $receipt)
    $export=Export-SBPublicCapture -BrainRoot $brain -ManifestPath $receiptPath -RepositoryPath $other -Name 'test.png' -BackupRoot $cfg.backupRoot
    Assert-Portable (!$export.applied -and !(Test-Path -LiteralPath $export.destination)) 'anteprima asset non scrive nel repo'
    $export=Export-SBPublicCapture -BrainRoot $brain -ManifestPath $receiptPath -RepositoryPath $other -Name 'test.png' -BackupRoot $cfg.backupRoot -Apply
    Assert-Portable ((Get-SBFileHash $export.destination) -eq $export.publicSha256 -and (Test-Path -LiteralPath $syntheticPNG)) 'export verificato conserva originale centrale'
    [IO.File]::AppendAllText($syntheticPNG,'tamper')
    Reject-Portable {Export-SBPublicCapture -BrainRoot $brain -ManifestPath $receiptPath -RepositoryPath $other -Name 'other.png' -BackupRoot $cfg.backupRoot -Apply} 'cattura modificata dopo revisione rifiutata'
    Reject-Portable {Export-SBPublicCapture -BrainRoot $brain -ManifestPath $receiptPath -RepositoryPath $other -Name '../escape.png' -BackupRoot $cfg.backupRoot -Apply} 'percorso asset non confinato rifiutato'
    $idePath=Join-Path $brain '.runtime/ide/AGENTS.md';$globalText="Revisione 3.3 — fixture";Put-Portable $idePath ("<!-- secondbrain:global:begin -->`n"+$globalText+"`n<!-- secondbrain:global:end -->")
    Put-Portable (Join-Path $cfg.runtimeRoot 'istruzioni-globali.md') $globalText
    $map=@{schemaVersion=2;workstationId=$cfg.workstationId;ides=@(@{name='File 3.3';mode='file';instructions=$idePath;selected=$true;loadingStatus='verified-current-session'},@{name='Account 3.1';mode='manual';selected=$true;accountAlias='fixture-account';accountStatus='unverified';observedRevision='3.1';observedHash=(Get-SBTextHash '3.1');loadingStatus='unverified'})}
    Put-Portable (Join-Path $cfg.runtimeRoot 'ide-map.json') (ConvertTo-SBJson $map)
    $ideResult=& pwsh -NoProfile -File (Join-Path $brain 'scripts/ide-map.ps1') -Verify -ConfigPath $activation.configuration 2>&1
    Assert-Portable ($LASTEXITCODE -eq 1 -and ($ideResult -join "`n") -match 'non verificati o disallineati') 'file 3.3 non nasconde account 3.1'
    $evidencePath=Join-Path $brain '.runtime/observation.txt';Put-Portable $evidencePath 'synthetic observation protocol fixture; not a real account verification'
    $observationIDE=@{id='account-fixture';name='Account Fixture';mode='manual';profile='current-user';accountAlias='account-a';environment='desktop'}
    $observation=@{ideId='account-fixture';workstationId=$cfg.workstationId;profile='current-user';accountAlias='account-a';environment='desktop';observedAt=[DateTimeOffset]::UtcNow.ToString('o');observedHash=(Get-SBTextHash $globalText);loadingVerified=$true;accountVerified=$true;sessionId='synthetic-test';evidencePath=$evidencePath;evidenceSha256=(Get-SBFileHash $evidencePath)}
    Assert-Portable (Test-SBIDEObservation $observationIDE (Get-SBTextHash $globalText) @($observation) $brain $cfg.workstationId) 'ricevuta fresca vincolata a profilo account ambiente hash e prova'
    $wrong=@{}+$observation;$wrong.accountAlias='account-b'
    Assert-Portable (!(Test-SBIDEObservation $observationIDE (Get-SBTextHash $globalText) @($wrong) $brain $cfg.workstationId)) 'riscontro altro account non riutilizzato'
    $old=@{}+$observation;$old.observedAt=[DateTimeOffset]::UtcNow.AddDays(-1).ToString('o')
    Assert-Portable (!(Test-SBIDEObservation $observationIDE (Get-SBTextHash $globalText) @($old) $brain $cfg.workstationId)) 'riscontro storico non certifica la sessione attuale'
    $globalHash=(Get-SBTextHash (Get-SBPortableGlobal $brain).Trim())
    $freshObs=@{}+$observation;$freshObs.observedHash=$globalHash
    $receiptObj=@{schemaVersion=1;observations=@($freshObs)}
    $receiptJsonPath=Join-Path $brain '.runtime/observation-receipt.json'
    Put-Portable $receiptJsonPath (ConvertTo-SBJson $receiptObj)
    $manualCfg=@{}+$cfg;$manualCfg.allowedOwners=@();$manualCfg.ides=@($observationIDE)
    [void](Invoke-SBPortableSync $manualCfg)
    $unobservedSync=Invoke-SBPortableSync $manualCfg -Check
    Assert-Portable ($unobservedSync.filesAligned -eq $true -and $unobservedSync.liveLoadingVerified -eq $false) 'filesAligned distinto da liveLoadingVerified'
    $observedSync=Invoke-SBPortableSync $manualCfg -ObservationPath $receiptJsonPath -Check
    Assert-Portable ($observedSync.filesAligned -eq $true -and $observedSync.liveLoadingVerified -eq $true) 'liveLoadingVerified confermato con osservazione valida'
    Put-Portable $agents 'manually drifted agents'
    $driftSync=Invoke-SBPortableSync $manualCfg -Check
    Assert-Portable ($driftSync.filesAligned -eq $false) 'filesAligned falso in presenza di drift'
    Put-Portable $agents $agentsText
    [void](Invoke-SBPortableSync $manualCfg)
    $originalFingerprint=$cfg.bindings[0].fingerprint
    Git-Portable $repo @('remote','set-url','origin','https://gitlab.example/team/changed.git')|Out-Null
    $changed=Invoke-SBPortableSync $cfg -Check
    Assert-Portable (@($changed.issues|Where-Object kind -eq 'repository-unverified').Count -gt 0 -and $cfg.bindings[0].fingerprint -eq $originalFingerprint) 'remoto cambiato non adottato implicitamente'
    Git-Portable $repo @('remote','set-url','origin','https://gitlab.example/team/one.git')|Out-Null
    $moved=Join-Path $repos 'renamed-one'
    [void](Assert-SBCentralDataPath ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))) $repo)
    [void](Assert-SBCentralDataPath ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))) $moved)
    Move-Item -LiteralPath $repo -Destination $moved
    $missing=Invoke-SBPortableSync $cfg -Check
    Assert-Portable (@($missing.issues|Where-Object kind -eq 'repository-unverified').Count -gt 0) 'spostamento checkout richiede riconciliazione'
    Assert-Portable (Test-Path -LiteralPath (Join-Path $dossier 'tracker.json')) 'assenza checkout non elimina dossier o task'

    # Fase 4: Hook pre-push
    $hookPreview = Install-SBPublicationHook -RepositoryPath $other
    Assert-Portable (!$hookPreview.applied -and $hookPreview.preview -and !(Test-Path -LiteralPath $hookPreview.hookPath)) 'anteprima installazione hook non scrive file'
    $hookInstall = Install-SBPublicationHook -RepositoryPath $other -Apply
    Assert-Portable ($hookInstall.applied -and (Test-Path -LiteralPath $hookInstall.hookPath)) 'installazione hook su conferma esplicita -Apply'
    $hookText = [IO.File]::ReadAllText($hookInstall.hookPath)
    Assert-Portable ($hookText -match 'SecondBrain pre-push hook' -and $hookText -notmatch '[A-Z]:\\' -and $hookText -notmatch 'ghp_') 'hook privo di percorsi host e credenziali'
    $hookStatus = Get-SBPublicationHookStatus -RepositoryPath $other
    Assert-Portable ($hookStatus.installed -and $hookStatus.isSecondBrainHook) 'stato hook riscontra hook SecondBrain attivo'
    $hookUninstall = Uninstall-SBPublicationHook -RepositoryPath $other -Apply
    Assert-Portable ($hookUninstall.applied -and $hookUninstall.removed -and !(Test-Path -LiteralPath $hookStatus.hookPath)) 'disinstallazione hook con -Apply rimuove file'
    [IO.File]::WriteAllText($hookStatus.hookPath, "#!/bin/sh`necho hook dell utente`n")
    $foreignRefused = $false
    try { Uninstall-SBPublicationHook -RepositoryPath $other -Apply | Out-Null } catch { $foreignRefused = $true }
    Assert-Portable ($foreignRefused -and (Test-Path -LiteralPath $hookStatus.hookPath) -and ([IO.File]::ReadAllText($hookStatus.hookPath) -match 'hook dell utente')) 'disinstallazione rifiuta un pre-push non creato da SecondBrain e lo conserva'
    Remove-Item -LiteralPath $hookStatus.hookPath -Force

    # Fase 4: Server MCP stdio locale in sola lettura
    $mcpInit = @{ jsonrpc = '2.0'; id = 101; method = 'initialize'; params = @{} } | ConvertTo-Json -Compress
    $mcpInitRes = Invoke-SBMcpMessage -BrainRoot $brain -Message $mcpInit | ConvertFrom-Json
    Assert-Portable ($mcpInitRes.result.serverInfo.name -eq 'secondbrain-mcp' -and $mcpInitRes.result.protocolVersion -eq '2024-11-05') 'server MCP risponde a initialize con versione e serverInfo'
    
    $mcpPing = @{ jsonrpc = '2.0'; id = 102; method = 'ping'; params = @{} } | ConvertTo-Json -Compress
    $mcpPingRes = Invoke-SBMcpMessage -BrainRoot $brain -Message $mcpPing | ConvertFrom-Json
    Assert-Portable ($null -ne $mcpPingRes.result -and $mcpPingRes.id -eq 102) 'server MCP risponde a ping'
    
    $mcpTools = @{ jsonrpc = '2.0'; id = 103; method = 'tools/list'; params = @{} } | ConvertTo-Json -Compress
    $mcpToolsRes = Invoke-SBMcpMessage -BrainRoot $brain -Message $mcpTools | ConvertFrom-Json
    Assert-Portable ($mcpToolsRes.result.tools.Count -ge 7) 'server MCP espone almeno 7 strumenti conformi'
    
    $mcpPromptCall = @{ jsonrpc = '2.0'; id = 104; method = 'tools/call'; params = @{ name = 'get_prompt'; arguments = @{ prompt = 'SYS03' } } } | ConvertTo-Json -Compress
    $mcpPromptRes = Invoke-SBMcpMessage -BrainRoot $brain -Message $mcpPromptCall | ConvertFrom-Json
    Assert-Portable (!$mcpPromptRes.result.isError -and $mcpPromptRes.result.content[0].text -match '# SYS03') 'strumento get_prompt restituisce la scheda markdown'
    
    $sys03Id = (@((Read-SBJson (Join-Path $brain 'direttive/prompts/catalog.json') $null).prompts | Where-Object code -ceq 'SYS03')[0]).id
    $mcpIdCall = @{ jsonrpc = '2.0'; id = 1041; method = 'tools/call'; params = @{ name = 'get_prompt'; arguments = @{ prompt = $sys03Id } } } | ConvertTo-Json -Compress
    $mcpIdRes = Invoke-SBMcpMessage -BrainRoot $brain -Message $mcpIdCall | ConvertFrom-Json
    Assert-Portable (!$mcpIdRes.result.isError -and $mcpIdRes.result.content[0].text -match '# SYS03' -and $mcpIdRes.result.content[0].text -match "(?m)^ID: $sys03Id \| Codice: SYS03" -and $mcpIdRes.result.content[0].text -match 'Regola vincolante: se hai dubbi') 'get_prompt risolve il prompt per ID con scheda uniforme e regola sui dubbi'
    $mcpGetById = @{ jsonrpc = '2.0'; id = 1042; method = 'prompts/get'; params = @{ name = $sys03Id } } | ConvertTo-Json -Compress
    $mcpGetByIdRes = Invoke-SBMcpMessage -BrainRoot $brain -Message $mcpGetById | ConvertFrom-Json
    Assert-Portable ($mcpGetByIdRes.result.description -and $mcpGetByIdRes.result.messages[0].content.text -match '# SYS03') 'prompts/get risolve il prompt per ID'
    $mcpPromptsList = @{ jsonrpc = '2.0'; id = 1043; method = 'prompts/list'; params = @{} } | ConvertTo-Json -Compress
    $mcpPromptsListRes = Invoke-SBMcpMessage -BrainRoot $brain -Message $mcpPromptsList | ConvertFrom-Json
    Assert-Portable (@($mcpPromptsListRes.result.prompts | Where-Object { $_.name -ceq 'SYS03' -and $_.description -match $sys03Id -and $_.title }).Count -eq 1) 'prompts/list espone nome, titolo e ID'

    $mcpListPrompts = @{ jsonrpc = '2.0'; id = 105; method = 'tools/call'; params = @{ name = 'list_prompts'; arguments = @{ category = 'sistema' } } } | ConvertTo-Json -Compress
    $mcpListRes = Invoke-SBMcpMessage -BrainRoot $brain -Message $mcpListPrompts | ConvertFrom-Json
    Assert-Portable (!$mcpListRes.result.isError -and $mcpListRes.result.content[0].text -match 'SYS03') 'strumento list_prompts filtra per categoria'
    $mcpCompact = @{ jsonrpc = '2.0'; id = 1051; method = 'tools/call'; params = @{ name = 'list_prompts'; arguments = @{ category = 'SYS'; compact = $true } } } | ConvertTo-Json -Compress -Depth 5
    $mcpCompactRes = Invoke-SBMcpMessage -BrainRoot $brain -Message $mcpCompact | ConvertFrom-Json
    Assert-Portable (!$mcpCompactRes.result.isError -and [regex]::Matches($mcpCompactRes.result.content[0].text, '(?m)^SYS\d{2} \| ').Count -eq 11 -and $mcpCompactRes.result.content[0].text -notmatch 'ID: pmt-') 'list_prompts compact filtra per prefisso con una riga per prompt'
    $mcpHome = @{ jsonrpc = '2.0'; id = 1052; method = 'tools/call'; params = @{ name = 'get_prompt_home'; arguments = @{} } } | ConvertTo-Json -Compress
    $mcpHomeRes = Invoke-SBMcpMessage -BrainRoot $brain -Message $mcpHome | ConvertFrom-Json
    Assert-Portable (!$mcpHomeRes.result.isError -and $mcpHomeRes.result.content[0].text -match 'direttive/prompts/README\.md' -and $mcpHomeRes.result.content[0].text -match 'sb attiva') 'get_prompt_home espone link al catalogo e comandi'

    $mcpNotify = @{ jsonrpc = '2.0'; method = 'notifications/initialized'; params = @{} } | ConvertTo-Json -Compress
    $mcpNotifyRes = Invoke-SBMcpMessage -BrainRoot $brain -Message $mcpNotify
    Assert-Portable ($null -eq $mcpNotifyRes) 'notifiche MCP non producono risposta JSON-RPC'

    $mcpMutate = @{ jsonrpc = '2.0'; id = 106; method = 'tools/mutate'; params = @{} } | ConvertTo-Json -Compress
    $mcpMutateRes = Invoke-SBMcpMessage -BrainRoot $brain -Message $mcpMutate | ConvertFrom-Json
    Assert-Portable ($mcpMutateRes.error.code -eq -32601) 'richiesta sconosciuta o di mutazione respinta con errore -32601'

    # Handshake stdio reale: il comando registrato per l IDE viene avviato come processo e interrogato su tutti gli strumenti (cervello fixture).
    $handshakeOut=(& pwsh -NoProfile -File (Join-Path $brain 'scripts/test-secondbrain-mcp-handshake.ps1') -BrainRoot $brain -Target 'codex,vscode' -PublicationPath $other -ReportPath (Join-Path $brain '.runtime/mcp-handshake/fixture.json') 2>&1|Out-String)
    Assert-Portable ($LASTEXITCODE -eq 0 -and $handshakeOut -match 'SUCCESS MCP-HANDSHAKE: 2 IDE' -and $handshakeOut -notmatch 'FAIL MCP') 'handshake stdio MCP: initialize, tools/list (7) e tools/call di ogni strumento per le configurazioni IDE'
    $handshakeReport=Read-SBJson (Join-Path $brain '.runtime/mcp-handshake/fixture.json') $null
    Assert-Portable ($handshakeReport.guiVerified -eq $false -and @($handshakeReport.skippedTools).Count -eq 0 -and @($handshakeReport.ides).Count -eq 2) 'rapporto handshake dichiara la prova visiva GUI non verificata e nessuno strumento saltato'

    # Accoppiamento Codex MCP e rilevamento Host
    $pairing = Get-SBMcpPairing -BrainRoot $brain -Target codex
    Assert-Portable ($pairing.Target -eq 'codex' -and $pairing.Toml -match 'mcp_servers\.secondbrain' -and $pairing.CliCommand -match 'codex mcp add secondbrain') 'pairing Codex produce TOML e comando CLI validi'
    $pairingsAll = Get-SBMcpPairing -BrainRoot $brain -Target all
    Assert-Portable ($pairingsAll.Count -eq 6) 'pairing all restituisce 6 IDE supportati'
    $claudePair = @($pairingsAll | Where-Object Target -eq 'claude')[0]
    Assert-Portable ($claudePair.ConfigFormat -eq 'json' -and $claudePair.Snippet -match '"mcpServers"') 'pairing Claude produce JSON con mcpServers'
    $vscodePair = @($pairingsAll | Where-Object Target -eq 'vscode')[0]
    Assert-Portable ($vscodePair.ConfigFormat -eq 'json' -and $vscodePair.Snippet -match '"mcp\.servers"') 'pairing VS Code produce JSON con mcp.servers'

    # Pacchetto distribuibile MCP
    $testPkgDir = Join-Path $fixture 'mcp-test-pkg'
    $pkgResult = New-SBMcpPackage -BrainRoot $brain -OutDir $testPkgDir
    Assert-Portable ($pkgResult.FileCount -ge 8 -and (Test-Path -LiteralPath (Join-Path $testPkgDir 'README.md')) -and (Test-Path -LiteralPath (Join-Path $testPkgDir 'install-all-ides.ps1'))) 'New-SBMcpPackage genera bundle con README e install script'
    Assert-Portable ((Test-Path -LiteralPath (Join-Path $testPkgDir 'claude/claude_desktop_config.json')) -and (Test-Path -LiteralPath (Join-Path $testPkgDir 'codex/config.toml'))) 'New-SBMcpPackage genera configurazioni per singoli IDE'

    # Iniezione sicura configurazione con merge e backup
    $testCfgDir = Join-Path $fixture 'mcp-test-cfg'
    [IO.Directory]::CreateDirectory($testCfgDir) | Out-Null
    $mockClaude = Join-Path $testCfgDir 'claude_desktop_config.json'
    Put-Portable $mockClaude (ConvertTo-SBJson @{ mcpServers = @{ custom = @{ command = 'node'; args = @('custom.js') } } })
    $setRes = Set-SBMcpConfiguration -BrainRoot $brain -Target claude -ConfigFile $mockClaude -BackupRoot (Join-Path $testCfgDir 'backups')
    $mergedClaude = Read-SBJson $mockClaude @{}
    Assert-Portable ($setRes.Action -eq 'updated' -and (Test-Path -LiteralPath $setRes.BackupFile)) 'Set-SBMcpConfiguration aggiorna e crea backup'
    Assert-Portable ($mergedClaude.mcpServers.ContainsKey('custom') -and $mergedClaude.mcpServers.ContainsKey('secondbrain')) 'Set-SBMcpConfiguration preserva server terzi e inietta secondbrain'
    $pairMeta = Read-SBJson ($setRes.BackupFile + '.json') $null
    Assert-Portable ($pairMeta -and $pairMeta.previousHash -and $pairMeta.deployedHash -and (Get-SBFileHash $setRes.BackupFile) -eq $pairMeta.previousHash -and ((Read-SBText $setRes.BackupFile) -notmatch 'secondbrain')) 'backup del pairing MCP con hash e metadati, contenente l originale'
    $sameRes = Set-SBMcpConfiguration -BrainRoot $brain -Target claude -ConfigFile $mockClaude -BackupRoot (Join-Path $testCfgDir 'backups')
    Assert-Portable ($sameRes.Action -eq 'unchanged' -and !$sameRes.BackupFile) 'pairing MCP ripetuto non riscrive ne crea backup'
    $brokenCfg = Join-Path $testCfgDir 'broken.json'
    [IO.File]::WriteAllText($brokenCfg, "{ // commento dell utente`n  `"mcpServers`": {} }")
    $brokenBefore = Get-SBFileHash $brokenCfg
    $brokenRefused = $false
    try { Set-SBMcpConfiguration -BrainRoot $brain -Target cursor -ConfigFile $brokenCfg -BackupRoot (Join-Path $testCfgDir 'backups') | Out-Null } catch { $brokenRefused = $true }
    Assert-Portable ($brokenRefused -and (Get-SBFileHash $brokenCfg) -eq $brokenBefore) 'pairing MCP con JSON illeggibile si ferma senza modificare il file'
    $restoreCfg = Join-Path $testCfgDir 'restore.json'
    Put-Portable $restoreCfg (ConvertTo-SBJson @{ mcpServers = @{ custom = @{ command = 'node' } } })
    $originalRestore = Read-SBText $restoreCfg
    $pairRestore = Set-SBMcpConfiguration -BrainRoot $brain -Target cursor -ConfigFile $restoreCfg
    Assert-Portable ($pairRestore.Action -eq 'updated' -and (Test-Path -LiteralPath $pairRestore.BackupFile) -and $pairRestore.BackupFile -like '*backup*mcp-pairing*') 'pairing MCP senza BackupRoot salva in .runtime/backup/mcp-pairing'
    $listText = (& pwsh -NoProfile -File (Join-Path $brain 'scripts/restore-managed.ps1') -List -Path $restoreCfg -ConfigPath $activation.configuration | Out-String)
    Assert-Portable ($LASTEXITCODE -eq 0 -and $listText.Contains([IO.Path]::GetFileName($pairRestore.BackupFile)) -and $listText -match 'HashPrecedente') 'restore-managed -List elenca il backup per percorso originale'
    $listOther = (& pwsh -NoProfile -File (Join-Path $brain 'scripts/restore-managed.ps1') -List -Path (Join-Path $testCfgDir 'altro.json') -ConfigPath $activation.configuration | Out-String)
    Assert-Portable ($LASTEXITCODE -eq 0 -and !$listOther.Contains([IO.Path]::GetFileName($pairRestore.BackupFile))) 'restore-managed -List filtra per percorso'
    $restoreOut = (& pwsh -NoProfile -File (Join-Path $brain 'scripts/restore-managed.ps1') -MetadataPath ($pairRestore.BackupFile + '.json') -ConfigPath $activation.configuration 2>&1 | Out-String)
    Assert-Portable ($LASTEXITCODE -eq 0 -and (Read-SBText $restoreCfg) -eq $originalRestore) 'restore-managed riporta il file MCP all originale'

    $hostIdes = Get-SBIDEAssets
    $codexIde = @($hostIdes | Where-Object { $_.name -eq 'Codex' })
    if ($codexIde.Count -eq 1) {
        Assert-Portable ($codexIde[0].ContainsKey('mcpConfigPath') -and $codexIde[0].ContainsKey('mcpConfigured')) 'Get-SBIDEAssets include rilevamento configurazione MCP per Codex'
    }
    $continueIde = @($hostIdes | Where-Object { $_.name -eq 'Continue' })
    if ($continueIde.Count -eq 1) {
        Assert-Portable ($continueIde[0].mode -eq 'manual' -and $continueIde[0].ContainsKey('installationEvidence')) 'Get-SBIDEAssets include rilevamento presenza per Continue'
    }
    $androidStudioIde = @($hostIdes | Where-Object { $_.name -eq 'Android Studio' })
    if ($androidStudioIde.Count -eq 1) {
        Assert-Portable ($androidStudioIde[0].mode -eq 'manual' -and $androidStudioIde[0].ContainsKey('installationEvidence')) 'Get-SBIDEAssets include rilevamento presenza per Android Studio'
    }

    # Verifica lista globale dei repository vietati (shared.json) ed esecuzione rollback-repo
    $sharedCfg = Read-SBJson (Join-Path $brain 'config/shared.json') @{}
    $sharedCfg.forbiddenRepositories = @(@{ identity = 'gitlab.example/team/one'; reason = 'test-forbidden' })
    Put-Portable (Join-Path $brain 'config/shared.json') (ConvertTo-SBJson $sharedCfg)

    $discForbidden = Invoke-SBHostDiscovery -BrainRoot $brain -Roots @($repos)
    $forbiddenExcluded = @($discForbidden.excluded | Where-Object { $_.reason -eq 'forbidden-by-user-policy' -and $_.identity -eq 'gitlab.example/team/one' })
    Assert-Portable ($forbiddenExcluded.Count -ge 1) 'Discovery esclude repo vietato da shared.json'

    Reject-Portable { Invoke-SBHostActivation $brain $selection -Apply } 'Attivazione rifiuta repo vietato da shared.json'

    Move-Item -LiteralPath $moved -Destination $repo
    $rollbackCli = Join-Path $brain 'scripts/rollback-repo.ps1'
    if (Test-Path -LiteralPath $rollbackCli) {
        # Rollback sicuro: dossier sintetici, ciascuno con il proprio checkout fittizio.
        function New-RollbackDossier([string]$Name,[string]$Identity) {
            $dir=Join-Path $brain ('02-areas/products/'+$Name)
            Put-Portable (Join-Path $dir 'repository.json') (ConvertTo-SBJson @{identity=$Identity})
            Put-Portable (Join-Path $dir 'index.md') '# indice'
            Put-Portable (Join-Path $dir 'tracker.md') 'tracker leggibile'
            Put-Portable (Join-Path $dir 'snapshots/old/snapshot.md') 'snapshot storico'
            Put-Portable (Join-Path $dir 'history/report.md') 'storico'
            $dir
        }
        function Invoke-RollbackCli([string[]]$CliArguments) { & pwsh -NoProfile -File $rollbackCli -BrainRoot $brain @CliArguments -Apply *> $null; $LASTEXITCODE }
        $checkoutA=Join-Path $repos 'rollback-a';[IO.Directory]::CreateDirectory($checkoutA)|Out-Null
        $dossierA=New-RollbackDossier 'rollback-a' 'gitlab.example/team/rollback-a'
        Assert-Portable ((Invoke-RollbackCli @('-RepositoryIdentity','gitlab.example/team/rollback-a','-DestinationPath',$brain)) -ne 0) 'rollback rifiuta il brain come checkout di destinazione'
        Assert-Portable (Test-Path -LiteralPath $dossierA) 'rollback rifiutato non elimina il dossier'
        $dossierDupe=New-RollbackDossier 'rollback-dupe' 'gitlab.example/team/rollback-a'
        Assert-Portable ((Invoke-RollbackCli @('-RepositoryIdentity','gitlab.example/team/rollback-a','-DestinationPath',$checkoutA)) -ne 0) 'rollback rifiuta identita ambigua nel fallback sulle cartelle'
        Assert-Portable ((Test-Path -LiteralPath $dossierA) -and (Test-Path -LiteralPath $dossierDupe)) 'ambiguita non elimina alcun dossier'
        Remove-Item -LiteralPath $dossierDupe -Recurse -Force
        & pwsh -NoProfile -File $rollbackCli -BrainRoot $brain -RepositoryIdentity 'gitlab.example/team/rollback-a' -DestinationPath $checkoutA -Forbid *> $null
        Assert-Portable ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $dossierA) -and !(Test-Path -LiteralPath (Join-Path $checkoutA '.secondbrain'))) 'rollback senza -Apply e solo anteprima: dossier e checkout invariati'
        Assert-Portable ((Invoke-RollbackCli @('-RepositoryIdentity','gitlab.example/team/rollback-a','-DestinationPath',$checkoutA,'-Forbid')) -eq 0) 'rollback del dossier sintetico completato'
        foreach($relative in @('tracker.md','snapshots/old/snapshot.md','history/report.md','index.md')){Assert-Portable (Test-Path -LiteralPath (Join-Path $checkoutA ('.secondbrain/'+$relative))) ('rollback restituisce '+$relative)}
        Assert-Portable (!(Test-Path -LiteralPath $dossierA)) 'rollback elimina il dossier dopo il trasferimento'
        $dossierB=New-RollbackDossier 'rollback-b' 'gitlab.example/team/rollback-b'
        $backupCountBefore=@(Get-ChildItem -LiteralPath $cfg.backupRoot -Directory -Filter 'rollback-*' -ErrorAction SilentlyContinue).Count
        Assert-Portable ((Invoke-RollbackCli @('-RepositoryIdentity','gitlab.example/team/rollback-b','-DestinationPath',(Join-Path $repos 'missing-checkout'),'-Force')) -eq 0) 'rollback -Force senza checkout completato'
        $newBackups=@(Get-ChildItem -LiteralPath $cfg.backupRoot -Directory -Filter 'rollback-*')
        Assert-Portable ($newBackups.Count -eq $backupCountBefore+1 -and (Test-Path -LiteralPath (Join-Path $newBackups[-1].FullName 'dossier/snapshots/old/snapshot.md'))) 'rollback -Force senza checkout salva il dossier completo in backupRoot'
        $dossierC=New-RollbackDossier 'rollback-c' 'gitlab.example/team/rollback-c'
        $checkoutC=Join-Path $repos 'rollback-c';[IO.Directory]::CreateDirectory($checkoutC)|Out-Null
        $hostConfigPath=Get-SBHostConfigPath $brain
        $hostFile=Get-Item -LiteralPath $hostConfigPath
        $hostFile.IsReadOnly=$true
        try{$failedExit=Invoke-RollbackCli @('-RepositoryIdentity','gitlab.example/team/rollback-c','-DestinationPath',$checkoutC,'-Forbid')}finally{$hostFile.IsReadOnly=$false}
        Assert-Portable ($failedExit -ne 0) 'rollback fallisce se workstation.json non e scrivibile'
        Assert-Portable (Test-Path -LiteralPath (Join-Path $dossierC 'tracker.md')) 'fallimento di workstation.json lascia il dossier intatto'
        & pwsh -NoProfile -File $rollbackCli -BrainRoot $brain -RepositoryIdentity 'gitlab.example/team/one' -DestinationPath $repo -Forbid -Force -Apply *> $null
        Assert-Portable ($LASTEXITCODE -eq 0) 'CLI rollback-repo eseguita con successo'
        Assert-Portable (Test-Path -LiteralPath (Join-Path $repo '.secondbrain/index.md')) 'rollback-repo copia dati in .secondbrain/'
        $repoExclude = Join-Path $repo '.git/info/exclude'
        Assert-Portable ((Test-Path -LiteralPath $repoExclude) -and ((Read-SBText $repoExclude) -match '\.secondbrain/')) 'rollback-repo protegge .secondbrain in .git/info/exclude'
        Assert-Portable (!(Test-Path -LiteralPath $dossier)) 'rollback-repo elimina dossier da SecondBrain'
    }

    # Policy di accesso: registro postazioni, shared.json fail-closed, identita del cervello con alias.
    function Invoke-FixtureCli([string]$Script,[string[]]$CliArguments) { $text=(& pwsh -NoProfile -File (Join-Path $brain ('scripts/'+$Script)) @CliArguments 2>&1|Out-String); @{exit=$LASTEXITCODE;text=$text} }
    $accessCli='access.ps1'
    Assert-Portable ((Invoke-FixtureCli $accessCli @('-Reconcile')).exit -eq 0) 'access -Reconcile registra la postazione'
    $registryFile=Join-Path $brain '.runtime/access/workstations.json'
    $stationId=(Read-SBJson (Get-SBHostConfigPath $brain) @{}).workstationId
    $registry=Read-SBJson $registryFile @{}
    $registry[$stationId].repositoryRoot='X:\spostato\altrove'
    Put-Portable $registryFile (ConvertTo-SBJson $registry)
    $moveResult=Invoke-FixtureCli 'cleanup.ps1' @('-ManifestPath',(Join-Path $brain '.runtime/inesistente.json'),'-Apply')
    Assert-Portable ($moveResult.exit -ne 0 -and $moveResult.text -match 'riconciliare') 'stesso workstationId con percorsi diversi richiede riconciliazione esplicita'
    Assert-Portable (((Read-SBJson $registryFile @{})[$stationId].repositoryRoot) -eq 'X:\spostato\altrove') 'registro non sovrascritto in silenzio'
    Assert-Portable ((Invoke-FixtureCli $accessCli @('-Reconcile')).exit -eq 0) 'riconciliazione esplicita aggiorna il registro'
    Assert-Portable (((Read-SBJson $registryFile @{})[$stationId].repositoryRoot) -ne 'X:\spostato\altrove') 'registro aggiornato dopo la riconciliazione'
    $sharedFile=Join-Path $brain 'config/shared.json';$sharedBackup=$sharedFile+'.bak'
    Move-Item -LiteralPath $sharedFile -Destination $sharedBackup
    try{
        $noShared=Invoke-FixtureCli $accessCli @('-Status')
        Assert-Portable ($noShared.exit -ne 0 -and $noShared.text -match 'shared\.json') 'shared.json assente e un errore (fail-closed)'
        Put-Portable $sharedFile '{"schemaVersion":3}'
        Assert-Portable ((Invoke-FixtureCli $accessCli @('-Status')).exit -ne 0) 'shared.json incompleto e un errore'
    }finally{Remove-Item -LiteralPath $sharedFile -Force -ErrorAction SilentlyContinue;Move-Item -LiteralPath $sharedBackup -Destination $sharedFile}
    Assert-Portable ((Invoke-FixtureCli $accessCli @('-Status')).exit -eq 0) 'shared.json ripristinato accettato'
    $identityRepo=Join-Path $fixture 'identity-repo';[IO.Directory]::CreateDirectory($identityRepo)|Out-Null
    Git-Portable $identityRepo @('init','-q')|Out-Null
    Git-Portable $identityRepo @('remote','add','origin','https://github.com/acme/identity-repo.git')|Out-Null
    $identityLink=Join-Path $fixture 'identity-link'
    New-Item -ItemType Junction -Path $identityLink -Target $identityRepo|Out-Null
    Assert-Portable ((Get-SBBrainIdentity $identityRepo) -eq 'github.com/acme/identity-repo') 'identita del cervello dal percorso reale'
    Assert-Portable ((Get-SBBrainIdentity $identityLink) -eq 'github.com/acme/identity-repo') 'identita del cervello risolta anche tramite junction'

    # Copertura onesta della Discovery: checkout con nome da build e accesso negato in cartelle dell'utente.
    $discoveryRoot=Join-Path $fixture 'discovery-coverage'
    foreach($name in @('build','dist')){
        $named=Join-Path $discoveryRoot $name;[IO.Directory]::CreateDirectory($named)|Out-Null;Git-Portable $named @('init','-q')|Out-Null
        Put-Portable (Join-Path $named 'README.md') ('# '+$name)
    }
    $plainBin=Join-Path $discoveryRoot 'plain/bin';Put-Portable (Join-Path $plainBin 'dummy.txt') 'dummy'
    $coverage=Invoke-SBHostDiscovery -BrainRoot $brain -Roots @($discoveryRoot)
    Assert-Portable (@($coverage.repositories|Where-Object {$_.path -like '*\build' -or $_.path -like '*\dist'}).Count -eq 2) 'checkout con nome da build scoperto'
    Assert-Portable (@($coverage.excluded|Where-Object {$_.path -eq $plainBin -and $_.reason -eq 'known-system-or-build-tree'}).Count -eq 1) 'cartella bin senza .git saltata con motivo visibile'
    Assert-Portable (!(Test-SBSystemAccessPath (Join-Path $env:USERPROFILE 'Documents'))) 'cartella dell utente corrente non e di sistema'
    Assert-Portable (Test-SBSystemAccessPath (Join-Path $env:SystemRoot 'System32')) 'cartella Windows e di sistema'
    Assert-Portable (Test-SBSystemAccessPath (Join-Path (Split-Path $env:USERPROFILE -Parent) 'altro-utente-fixture\Documents')) 'profilo di altro utente e di sistema'
    $locked=Join-Path $discoveryRoot 'locked';[IO.Directory]::CreateDirectory($locked)|Out-Null
    $account=[Security.Principal.WindowsIdentity]::GetCurrent().Name
    # Da Git Bash (MSYS2) i processi figli ereditano SeBackupPrivilege/SeRestorePrivilege abilitati: l'apertura di cartelle con semantica di backup aggira il deny ACL.
    # Per la sola prova i due privilegi vengono disabilitati nel processo e poi ripristinati; se il deny resta inefficace il test fallisce (nessun salto silenzioso).
    if(!('SBPortablePrivilege' -as [type])){
        Add-Type -Namespace '' -Name SBPortablePrivilege -MemberDefinition @'
[DllImport("advapi32.dll",SetLastError=true)] static extern bool OpenProcessToken(IntPtr h,uint access,out IntPtr token);
[DllImport("advapi32.dll",SetLastError=true,CharSet=CharSet.Unicode)] static extern bool LookupPrivilegeValue(string system,string name,out long luid);
[DllImport("advapi32.dll",SetLastError=true)] static extern bool AdjustTokenPrivileges(IntPtr token,bool disableAll,ref TokenPrivilege state,int length,IntPtr previous,IntPtr returned);
[DllImport("kernel32.dll")] static extern IntPtr GetCurrentProcess();
[DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
[StructLayout(LayoutKind.Sequential,Pack=1)] struct TokenPrivilege{public int Count;public long Luid;public int Attributes;}
public static bool Set(string name,bool enabled){
    IntPtr token;if(!OpenProcessToken(GetCurrentProcess(),0x20,out token))return false;
    try{
        var state=new TokenPrivilege{Count=1,Attributes=enabled?2:0};
        if(!LookupPrivilegeValue(null,name,out state.Luid))return false;
        return AdjustTokenPrivileges(token,false,ref state,0,IntPtr.Zero,IntPtr.Zero)&&System.Runtime.InteropServices.Marshal.GetLastWin32Error()==0;
    }finally{CloseHandle(token);}
}
'@
    }
    $privilegesBefore=@(& (Join-Path $env:SystemRoot 'System32\whoami.exe') /priv|Where-Object {$_ -match '^Se(Backup|Restore)Privilege\s' -and $_ -match '(Abilitato|Enabled)\s*$'}|ForEach-Object {($_ -split '\s+')[0]})
    [SBPortablePrivilege]::Set('SeBackupPrivilege',$false)|Out-Null;[SBPortablePrivilege]::Set('SeRestorePrivilege',$false)|Out-Null
    & icacls $locked /deny ($account+':(OI)(CI)(R)') *> $null
    try{
        $enforced=$false;try{[IO.Directory]::GetFileSystemEntries($locked)|Out-Null}catch [UnauthorizedAccessException]{$enforced=$true}
        Assert-Portable $enforced 'deny ACL efficace nel processo di prova (privilegi di backup disabilitati)'
        $denied=Invoke-SBHostDiscovery -BrainRoot $brain -Roots @($discoveryRoot)
        Assert-Portable (@($denied.issues|Where-Object {$_.kind -eq 'access-denied' -and $_.path -eq $locked}).Count -eq 1) 'accesso negato in cartella utente registrato come problema'
        Assert-Portable (!$denied.complete) 'accesso negato in cartella utente rende la ricognizione incompleta'
    }finally{& icacls $locked /remove:d $account *> $null;foreach($privilege in $privilegesBefore){[SBPortablePrivilege]::Set($privilege,$true)|Out-Null}}

    # Copertura dei residui minori: Assert-SBPlainPath, stato accessi, purge, cleanup con manifest, retention .stage, check-distribution.
    $realBrain=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    Assert-Portable ($null -eq (Assert-SBPlainPath $realBrain)) 'Assert-SBPlainPath accetta la radice del cervello'
    Reject-Portable {Assert-SBPlainPath $identityLink} 'Assert-SBPlainPath rifiuta un reparse point dentro i dati'
    # Cache degli antenati (ciclo REP05): stesso esito della verifica senza cache, nessun avvelenamento dopo un rifiuto, foglia sempre controllata.
    $plainCache=@{};$plainSibling=Join-Path (Split-Path $identityLink) 'plain-sibling.txt'
    Assert-Portable ($null -eq (Assert-SBPlainPath $realBrain $plainCache)) 'Assert-SBPlainPath con cache accetta la radice del cervello'
    Assert-Portable ($null -eq (Assert-SBPlainPath $plainSibling $plainCache) -and $plainCache.ContainsKey((Split-Path $identityLink))) 'Assert-SBPlainPath con cache registra gli antenati verificati'
    Reject-Portable {Assert-SBPlainPath $identityLink $plainCache} 'Assert-SBPlainPath con cache rifiuta comunque la foglia reparse point (antenato gia in cache)'
    Reject-Portable {Assert-SBPlainPath (Join-Path $identityLink 'figlio.txt') $plainCache} 'Assert-SBPlainPath con cache rifiuta un file sotto un reparse point'
    Assert-Portable (!$plainCache.ContainsKey($identityLink)) 'Assert-SBPlainPath con cache non registra antenati dopo un rifiuto'
    $coordination=Join-Path $fixture 'coordination-status';$statusSessions=Join-Path $coordination 'sessions';[IO.Directory]::CreateDirectory($statusSessions)|Out-Null
    $abandonedId=[guid]::NewGuid().ToString('N')
    $abandonedFile=Join-Path $statusSessions ($abandonedId+'.json')
    Put-Portable $abandonedFile (ConvertTo-SBJson @{sessionId=$abandonedId;status='active';mode='Write';heartbeat=[DateTimeOffset]::UtcNow.ToString('o')})
    $statusConfig=@{coordinationRoot=$coordination}
    Assert-Portable (@(Get-SBAccessStatus $statusConfig|Where-Object {$_.sessionId -eq $abandonedId -and $_.status -eq 'abandoned'}).Count -eq 1) 'Get-SBAccessStatus segnala una sessione senza lease come abbandonata'
    Assert-Portable ((Read-SBJson $abandonedFile @{}).status -eq 'active') 'Get-SBAccessStatus senza Repair e in sola lettura'
    [void](Get-SBAccessStatus $statusConfig -Repair)
    Assert-Portable ((Read-SBJson $abandonedFile @{}).status -eq 'abandoned') 'Get-SBAccessStatus -Repair persiste l abbandono'
    $brainSessions=Join-Path $brain '.runtime/access/sessions';[IO.Directory]::CreateDirectory($brainSessions)|Out-Null
    $closedId=[guid]::NewGuid().ToString('N');$closedFile=Join-Path $brainSessions ($closedId+'.json')
    Put-Portable $closedFile (ConvertTo-SBJson @{sessionId=$closedId;status='closed';heartbeat=[DateTimeOffset]::UtcNow.AddHours(-3).ToString('o')})
    Assert-Portable ((Invoke-FixtureCli $accessCli @('-Status','-Purge')).exit -eq 0 -and !(Test-Path -LiteralPath $closedFile)) 'access -Purge elimina le sessioni chiuse vecchie'
    $cleanupDir=Join-Path $brain '.runtime/cleanup-fixture';$cleanupFile=Join-Path $cleanupDir 'removable.txt'
    Put-Portable $cleanupFile 'da rimuovere'
    $manifestPath=Join-Path $cleanupDir 'manifest.json'
    Put-Portable $manifestPath (ConvertTo-SBJson @{schemaVersion=1;reviewed=$true;referencesChecked=$true;reason='fixture';files=@(@{path=$cleanupFile;sha256=(Get-SBFileHash $cleanupFile)})})
    $preview=Invoke-FixtureCli 'cleanup.ps1' @('-ManifestPath',$manifestPath)
    Assert-Portable ($preview.exit -eq 0 -and (Test-Path -LiteralPath $cleanupFile)) 'cleanup senza Apply non rimuove'
    Assert-Portable ((Invoke-FixtureCli 'cleanup.ps1' @('-ManifestPath',$manifestPath,'-Apply')).exit -ne 0) 'cleanup Apply senza Authorization rifiutato'
    $applied=Invoke-FixtureCli 'cleanup.ps1' @('-ManifestPath',$manifestPath,'-Apply','-Authorization','fixture richiesta utente')
    Assert-Portable ($applied.exit -eq 0 -and !(Test-Path -LiteralPath $cleanupFile) -and $applied.text -match '"applied": true') 'cleanup -ManifestPath -Apply rimuove il file elencato'
    $emptyManifest=Join-Path $cleanupDir 'empty.json'
    Put-Portable $emptyManifest (ConvertTo-SBJson @{schemaVersion=1;reviewed=$true;referencesChecked=$true;reason='fixture';files=@()})
    $emptyApply=Invoke-FixtureCli 'cleanup.ps1' @('-ManifestPath',$emptyManifest,'-Apply','-Authorization','fixture richiesta utente')
    Assert-Portable ($emptyApply.exit -eq 0 -and $emptyApply.text -match '"applied": false') 'cleanup Apply con manifest vuoto non dichiara applied'
    $partialA=Join-Path $cleanupDir 'partial-a.txt';$partialB=Join-Path $cleanupDir 'partial-b.txt'
    Put-Portable $partialA 'a';Put-Portable $partialB 'b'
    $partialManifest=Join-Path $cleanupDir 'partial.json'
    Put-Portable $partialManifest (ConvertTo-SBJson @{schemaVersion=1;reviewed=$true;referencesChecked=$true;reason='fixture';files=@(@{path=$partialA;sha256=(Get-SBFileHash $partialA)},@{path=$partialB;sha256=(Get-SBFileHash $partialB)})})
    $holdB=[IO.File]::Open($partialB,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
    try{$partial=Invoke-FixtureCli 'cleanup.ps1' @('-ManifestPath',$partialManifest,'-Apply','-Authorization','fixture richiesta utente')}finally{$holdB.Dispose()}
    Assert-Portable ($partial.exit -eq 1 -and $partial.text -match '"status": "partial"' -and $partial.text -match '"removed"' -and !(Test-Path -LiteralPath $partialA) -and (Test-Path -LiteralPath $partialB)) 'cleanup con errore a meta emette il riepilogo parziale ed esce con 1'
    # cleanup -Regenerable: perimetro fisso (fixture di test oltre le ultime N, ambiente Python delle fonti), junction non seguite, sola lettura rimossa, registro e guardia di eta.
    $regenTests=Join-Path $brain '.runtime/tests'
    $regenOutside=Join-Path $fixture 'regenerable-outside';Put-Portable (Join-Path $regenOutside 'sentinel.txt') 'fuori da .runtime'
    for($i=1;$i -le 5;$i++){Put-Portable (Join-Path $regenTests "fx-$i/a/b/file.txt") "fixture $i"}
    $regenOldest=Join-Path $regenTests 'fx-5'
    (Get-Item -LiteralPath (Join-Path $regenOldest 'a/b/file.txt')).Attributes='ReadOnly'
    New-Item -ItemType Junction -Path (Join-Path $regenOldest 'link') -Target $regenOutside|Out-Null
    for($i=1;$i -le 5;$i++){(Get-Item -LiteralPath (Join-Path $regenTests "fx-$i")).LastWriteTimeUtc=[DateTime]::UtcNow.AddHours(-$i)}
    $regenPython=Join-Path $brain '.runtime/hosts/regen-host/sources/python';Put-Portable (Join-Path $regenPython 'pkg/module.py') 'x=1'
    $regenDocs=Join-Path $brain '.runtime/hosts/regen-host/sources/keep.txt';Put-Portable $regenDocs 'resta'
    $regenGuard=Invoke-FixtureCli 'cleanup.ps1' @('-Regenerable','-KeepFixtures','0')
    $regenGuardPlan=$regenGuard.text|ConvertFrom-Json
    Assert-Portable ($regenGuard.exit -eq 0 -and @($regenGuardPlan.targets).Count -eq 0 -and @($regenGuardPlan.skipped|Where-Object {$_.reason -match 'ultimi 10 minuti'}).Count -ge 5) 'cleanup -Regenerable salta le cartelle scritte da poco (potrebbero essere in uso)'
    $regenPreview=Invoke-FixtureCli 'cleanup.ps1' @('-Regenerable','-KeepFixtures','2','-MinAgeMinutes','0')
    $regenPlan=$regenPreview.text|ConvertFrom-Json
    Assert-Portable ($regenPreview.exit -eq 0 -and !$regenPlan.applied -and @($regenPlan.targets|Where-Object {$_.kind -eq 'fixture-test'}).Count -eq 3 -and @($regenPlan.targets|Where-Object {$_.kind -eq 'python-sources'}).Count -eq 1 -and (Test-Path -LiteralPath $regenOldest)) 'cleanup -Regenerable senza Apply elenca 3 fixture oltre le ultime 2 e l ambiente Python, senza rimuovere'
    Assert-Portable ((Invoke-FixtureCli 'cleanup.ps1' @('-Regenerable','-Apply','-KeepFixtures','2','-MinAgeMinutes','0')).exit -ne 0 -and (Test-Path -LiteralPath $regenOldest)) 'cleanup -Regenerable -Apply senza Authorization rifiutato'
    Assert-Portable ((Invoke-FixtureCli 'cleanup.ps1' @('-Regenerable','-ManifestPath',(Join-Path $brain '.runtime/x.json'))).exit -ne 0) 'cleanup -Regenerable non combinabile con un manifest'
    $regenApplied=Invoke-FixtureCli 'cleanup.ps1' @('-Regenerable','-Apply','-Authorization','fixture richiesta utente','-KeepFixtures','2','-MinAgeMinutes','0')
    Assert-Portable ($regenApplied.exit -eq 0 -and $regenApplied.text -match '"applied": true') 'cleanup -Regenerable -Apply con Authorization rimuove il perimetro'
    Assert-Portable (!(Test-Path -LiteralPath $regenOldest) -and !(Test-Path -LiteralPath (Join-Path $regenTests 'fx-3')) -and (Test-Path -LiteralPath (Join-Path $regenTests 'fx-1')) -and (Test-Path -LiteralPath (Join-Path $regenTests 'fx-2')) -and !(Test-Path -LiteralPath $regenPython) -and (Test-Path -LiteralPath $regenDocs)) 'rimosse solo le fixture oltre le ultime 2 e sources/python; il resto di sources resta'
    Assert-Portable ((Test-Path -LiteralPath (Join-Path $regenOutside 'sentinel.txt')) -and (Test-Path -LiteralPath $regenOutside)) 'la junction e stata scollegata, non seguita: il contenuto esterno resta'
    $regenRegistry=@(Get-ChildItem -LiteralPath (Join-Path $brain '.runtime/cleanup') -Filter 'regenerable-*.json' -File)
    $regenRecord=if($regenRegistry.Count){Read-SBJson $regenRegistry[0].FullName $null}else{$null}
    Assert-Portable ($regenRegistry.Count -eq 1 -and $regenRecord.status -eq 'completed' -and $regenRecord.authorization -eq 'fixture richiesta utente' -and @($regenRecord.items).Count -eq 4 -and @($regenRecord.items|Where-Object {$_.recovery}).Count -eq 4) 'registro in .runtime/cleanup con autorizzazione, elementi rimossi e come ricrearli'
    $stageDir=Join-Path $cfg.backupRoot 'nested-stage';[IO.Directory]::CreateDirectory($stageDir)|Out-Null
    $stageFile=Join-Path $stageDir ([guid]::NewGuid().ToString('N')+'.stage')
    Put-Portable $stageFile (ConvertTo-SBJson @{schemaVersion=1;status='completed';path='fixture-target'})
    (Get-Item -LiteralPath $stageFile).LastWriteTimeUtc=[DateTime]::UtcNow.AddDays(-10)
    $retention=Get-SBStageRetention @($cfg.backupRoot) 1
    Assert-Portable (@($retention.candidates|Where-Object {$_.path -eq $stageFile}).Count -eq 1) 'retention .stage trova i record nelle sottocartelle'
    $stageList=Invoke-FixtureCli 'cleanup.ps1' @('-ListStageRecords','-OlderThanDays','1')
    Assert-Portable ($stageList.exit -eq 0 -and $stageList.text -match [regex]::Escape((Split-Path $stageFile -Leaf))) 'cleanup -ListStageRecords elenca i record vecchi'
    Assert-Portable (Test-Path -LiteralPath $stageFile) 'anteprima retention non rimuove i record'
    $oldRuntime=Join-Path $brain '.runtime/vecchia-prova';$oldRuntimeFile=Join-Path $oldRuntime 'dato.txt'
    Put-Portable $oldRuntimeFile ('x'*100)
    (Get-Item -LiteralPath $oldRuntimeFile).LastWriteTimeUtc=[DateTime]::UtcNow.AddDays(-200)
    Put-Portable (Join-Path $brain 'docs/uso.md') 'vedi .runtime/vecchia-prova/dato.txt'
    $junctionTarget=Join-Path $fixture 'junction-target';[IO.Directory]::CreateDirectory($junctionTarget)|Out-Null;Put-Portable (Join-Path $junctionTarget 'fuori.txt') 'fuori perimetro'
    New-Item -ItemType Junction -Path (Join-Path $brain '.runtime/collegamento') -Target $junctionTarget|Out-Null
    $runtimeBefore=@(Get-ChildItem -LiteralPath (Join-Path $brain '.runtime') -Recurse -Force -File).Count
    $runtimeList=Invoke-FixtureCli 'cleanup.ps1' @('-ListRuntime','-OlderThanDays','90')
    Assert-Portable ($runtimeList.exit -eq 0) 'cleanup -ListRuntime esce con 0'
    $runtimeReport=$runtimeList.text|ConvertFrom-Json -AsHashtable
    $oldEntry=@($runtimeReport.entries|Where-Object name -eq 'vecchia-prova')[0]
    Assert-Portable (!$runtimeReport.applied -and $runtimeReport.scope -eq 'runtime-retention-preview' -and $oldEntry.files -eq 1 -and $oldEntry.bytes -eq 100 -and $oldEntry.ageDays -ge 199 -and $oldEntry.olderThanThreshold) 'ListRuntime riporta file, dimensione ed eta della voce'
    Assert-Portable ($oldEntry.references.mentions -ge 1 -and 'docs/uso.md' -in @($oldEntry.references.samples) -and !$oldEntry.protected -and 'vecchia-prova' -in @($runtimeReport.reviewable)) 'ListRuntime conta i riferimenti testuali e segnala la voce da rivedere'
    Assert-Portable ((@($runtimeReport.entries|Where-Object name -eq 'hosts')[0]).protected -and (@($runtimeReport.entries|Where-Object name -eq 'access')[0]).protected -and 'hosts' -notin @($runtimeReport.reviewable)) 'ListRuntime protegge configurazione e accesso'
    $junctionEntry=@($runtimeReport.entries|Where-Object name -eq 'collegamento')[0]
    Assert-Portable ($junctionEntry.kind -eq 'reparse-point' -and $junctionEntry.protected -and $junctionEntry.bytes -eq 0 -and 'collegamento' -notin @($runtimeReport.reviewable)) 'ListRuntime non segue i reparse point'
    $runtimeApply=Invoke-FixtureCli 'cleanup.ps1' @('-ListRuntime','-Apply')
    Assert-Portable ($runtimeApply.exit -ne 0 -and (Test-Path -LiteralPath $oldRuntimeFile) -and (Test-Path -LiteralPath (Join-Path $junctionTarget 'fuori.txt')) -and @(Get-ChildItem -LiteralPath (Join-Path $brain '.runtime') -Recurse -Force -File).Count -eq $runtimeBefore) 'ListRuntime non e combinabile con Apply e non rimuove nulla'
    Assert-Portable ($oldEntry.category -eq 'working' -and $oldEntry.recovery -and (@($runtimeReport.entries|Where-Object name -eq 'hosts')[0]).category -eq 'protected' -and $runtimeReport.byCategory.ContainsKey('protected')) 'ListRuntime classifica le voci per categoria e dichiara come recuperarle'
    # Proposta di pulizia: sola lettura, non un manifest eseguibile.
    1..6|ForEach-Object {$d=Join-Path $brain ('.runtime/tests/portable-prova-'+$_);Put-Portable (Join-Path $d 'dato.txt') ('f'*50);(Get-Item -LiteralPath $d).LastWriteTimeUtc=[DateTime]::UtcNow.AddDays(-$_)}
    $proposalBefore=@(Get-ChildItem -LiteralPath (Join-Path $brain '.runtime') -Recurse -Force -File).Count
    $proposalRun=Invoke-FixtureCli 'cleanup.ps1' @('-ProposeRuntime','-KeepFixtures','2')
    $proposal=$proposalRun.text|ConvertFrom-Json -AsHashtable
    $testsCandidate=@($proposal.candidates|Where-Object path -eq 'tests/')[0]
    Assert-Portable ($proposalRun.exit -eq 0 -and !$proposal.applied -and $proposal.scope -eq 'runtime-cleanup-proposal' -and $testsCandidate.folders -ge 4 -and $testsCandidate.category -eq 'regenerable' -and $testsCandidate.recovery -match 'suite') 'ProposeRuntime propone le fixture oltre le ultime e dichiara come ricrearle'
    Assert-Portable (@(Get-ChildItem -LiteralPath (Join-Path $brain '.runtime') -Recurse -Force -File).Count -eq $proposalBefore -and $proposal.note -match 'non un manifest') 'ProposeRuntime non rimuove ne scrive nulla'
    $proposalFile=Join-Path $brain '.runtime/cleanup/proposals/prova.json'
    Assert-Portable ((Invoke-FixtureCli 'cleanup.ps1' @('-ProposeRuntime','-ProposalPath',$proposalFile)).exit -eq 0 -and (Test-Path -LiteralPath $proposalFile) -and (Read-SBJson $proposalFile @{}).scope -eq 'runtime-cleanup-proposal') 'ProposeRuntime salva la proposta in un nuovo file con -ProposalPath'
    Assert-Portable ((Invoke-FixtureCli 'cleanup.ps1' @('-ProposeRuntime','-ProposalPath',$proposalFile)).exit -ne 0) 'ProposeRuntime non sovrascrive una proposta esistente'
    Assert-Portable ((Invoke-FixtureCli 'cleanup.ps1' @('-ProposeRuntime','-ListRuntime')).exit -ne 0 -and (Invoke-FixtureCli 'cleanup.ps1' @('-ProposeRuntime','-Apply')).exit -ne 0) 'ProposeRuntime non e combinabile con ListRuntime o Apply'
    Remove-Item -LiteralPath $proposalFile -Force
    Get-ChildItem -LiteralPath (Join-Path $brain '.runtime/tests') -Directory -Filter 'portable-prova-*'|ForEach-Object {Remove-Item -LiteralPath $_.FullName -Recurse -Force}
    (Get-Item -LiteralPath (Join-Path $brain '.runtime/collegamento')).Delete()
    $distRepo=Join-Path $fixture 'distribution-repo';[IO.Directory]::CreateDirectory($distRepo)|Out-Null
    Git-Portable $distRepo @('init','-q')|Out-Null
    Put-Portable (Join-Path $distRepo 'README.md') '# ok'
    Git-Portable $distRepo @('add','README.md')|Out-Null
    $distOk=Invoke-FixtureCli 'check-distribution.ps1' @('-RepositoryPath',$distRepo)
    Assert-Portable ($distOk.exit -eq 0 -and $distOk.text -match 'DISTRIBUTION CHECK SUCCESS') 'check-distribution accetta un perimetro conforme'
    Put-Portable (Join-Path $distRepo '02-areas/privato.md') 'riservato'
    Put-Portable (Join-Path $distRepo 'fuori-perimetro.txt') 'non ammesso'
    Git-Portable $distRepo @('add','-f','02-areas/privato.md','fuori-perimetro.txt')|Out-Null
    $distBad=Invoke-FixtureCli 'check-distribution.ps1' @('-RepositoryPath',$distRepo)
    Assert-Portable ($distBad.exit -eq 1 -and $distBad.text -match 'VIOLAZIONE CRITICA' -and $distBad.text -match 'VIOLAZIONE PERIMETRO' -and $distBad.text -match 'DISTRIBUTION CHECK FAILED') 'check-distribution stampa entrambe le violazioni, il messaggio finale ed esce con 1'

    # Isolamento per repository: task, startup, MCP, Check/Sync e scritture restano nel repository in lavoro.
    $noRemote=Join-Path $repos 'no-remote'
    $isoReport=Invoke-SBHostDiscovery -BrainRoot $brain -ResumePath $checkpoint
    $isoChoice=@{}+$choice;$isoChoice.reportSha256=(Get-SBFileHash $checkpoint)
    $isoChoice.repositories=@(@($isoReport.repositories|Where-Object {$_.path -in @($other,$noRemote)})|ForEach-Object {@{id=$_.id;identity=$(if($_.requiresIdentity){'local'}else{$null})}}|ForEach-Object {@{id=$_.id}})
    Put-Portable $selection (ConvertTo-SBJson $isoChoice)
    # Le chiamate in-process usano i moduli del repository reale: il registro postazioni della fixture, scritto dalle CLI della fixture, va azzerato.
    Remove-Item -LiteralPath (Join-Path $brain '.runtime/access/workstations.json') -Force -ErrorAction SilentlyContinue
    $isoActivation=Invoke-SBHostActivation $brain $selection -Apply
    $isoCfg=Read-SBJson $isoActivation.configuration $null
    $isoCfg.brainRoot=$brain;$isoCfg.configPath=$isoActivation.configuration;$isoCfg.allowedOwners=@();$isoCfg.coordinationRoot=Join-Path $brain '.runtime/access';$isoCfg.sessionTimeoutMinutes=30
    $twoBinding=@($isoCfg.bindings|Where-Object path -eq $other)[0];$localBinding=@($isoCfg.bindings|Where-Object path -eq $noRemote)[0]
    Assert-Portable ($twoBinding -and $localBinding -and $twoBinding.identity -ne $localBinding.identity) 'fixture isolamento: due repository gestiti'
    foreach($pair in @(@($twoBinding,'ISO-TWO'),@($localBinding,'ISO-LOCAL'))){
        $isoTracker=Join-Path (Join-Path $brain $pair[0].dossier) 'tracker.json';$isoDoc=Read-SBJson $isoTracker $null
        $isoDoc.tasks=@(New-SBTrackerTask @{id=$pair[1];title=('Task '+$pair[1]);status='todo'} $isoDoc.repository 'test' 'test.md' (Get-SBTextHash 'test') 'line:1')
        Put-Portable $isoTracker (ConvertTo-SBJson $isoDoc)
    }
    Reject-Portable {Get-SBGlobalTasks -BrainRoot $brain} 'task senza repository ne -All rifiutati'
    $scopedTasks=@(Get-SBGlobalTasks -BrainRoot $brain -Repository $twoBinding.identity)
    Assert-Portable ($scopedTasks.Count -eq 1 -and $scopedTasks[0].id -eq 'ISO-TWO' -and $scopedTasks[0].scope -eq 'repository') 'task limitati al repository richiesto'
    $globalTasks=@(Get-SBGlobalTasks -BrainRoot $brain -All)
    Assert-Portable (@($globalTasks|Where-Object {$_.id -in @('ISO-TWO','ISO-LOCAL')}).Count -eq 2 -and !@($globalTasks|Where-Object {$_.scope -ne 'global'}).Count) 'vista globale solo con -All e voci etichettate'
    Reject-Portable {Get-SBGlobalTasks -BrainRoot $brain -Repository 'gitlab.example/team/inesistente'} 'repository senza dossier rifiutato'
    $knowledgeCli=Join-Path $brain 'scripts/knowledge.ps1'
    # Il registro postazioni e stato scritto dai moduli in-process: le CLI della fixture richiedono la riconciliazione esplicita.
    Assert-Portable ((Invoke-FixtureCli $accessCli @('-Reconcile','-ConfigPath',$isoActivation.configuration)).exit -eq 0) 'riconciliazione della postazione per le CLI della fixture'
    Push-Location $other
    try{
        $cliTasks=@(& pwsh -NoProfile -File $knowledgeCli -Tasks -ConfigPath $isoActivation.configuration 2>$null|ConvertFrom-Json)
        Assert-Portable ($LASTEXITCODE -eq 0 -and $cliTasks.Count -eq 1 -and $cliTasks[0].repository -eq $twoBinding.identity) 'knowledge -Tasks risolve il repository dal checkout corrente'
        $cliAll=@(& pwsh -NoProfile -File $knowledgeCli -Tasks -All -ConfigPath $isoActivation.configuration 2>$null|ConvertFrom-Json)
        Assert-Portable ($LASTEXITCODE -eq 0 -and $cliAll.Count -ge 2) 'knowledge -Tasks -All espone la vista globale su richiesta'
        & pwsh -NoProfile -File $knowledgeCli -Tasks -All -Repository $localBinding.identity -ConfigPath $isoActivation.configuration *> $null
        Assert-Portable ($LASTEXITCODE -ne 0) 'knowledge -All e -Repository incompatibili'
        & pwsh -NoProfile -File $knowledgeCli -UpdateTaskId 'ISO-LOCAL' -Status 'in_progress' -Repository $localBinding.identity -ConfigPath $isoActivation.configuration *> $null
        Assert-Portable ($LASTEXITCODE -ne 0 -and (@((Read-SBJson (Join-Path (Join-Path $brain $localBinding.dossier) 'tracker.json') $null).tasks)[0].status -eq 'todo')) 'scrittura sul tracker di un altro repository rifiutata'
        & pwsh -NoProfile -File $knowledgeCli -UpdateTaskId 'ISO-TWO' -Status 'in_progress' -ConfigPath $isoActivation.configuration *> $null
        Assert-Portable ($LASTEXITCODE -eq 0 -and (@((Read-SBJson (Join-Path (Join-Path $brain $twoBinding.dossier) 'tracker.json') $null).tasks)[0].status -eq 'in_progress')) 'scrittura sul tracker del repository in lavoro consentita'
        $startupCli=(& pwsh -NoProfile -File $knowledgeCli -Startup -ConfigPath $isoActivation.configuration 2>$null|ConvertFrom-Json)
        Assert-Portable ($startupCli.repository -eq $twoBinding.identity) 'knowledge -Startup senza dossier risolve il checkout corrente'
    }finally{Pop-Location}
    Push-Location $fixture
    try{
        & pwsh -NoProfile -File $knowledgeCli -Tasks -ConfigPath $isoActivation.configuration *> $null
        Assert-Portable ($LASTEXITCODE -ne 0) 'knowledge -Tasks fuori da un checkout non elenca altri repository'
    }finally{Pop-Location}
    Reject-Portable {Set-SBTrackerTaskStatus -BrainRoot $brain -Path (Join-Path (Join-Path $brain $localBinding.dossier) 'tracker.json') -TaskId 'ISO-LOCAL' -Status 'done' -WorkingRepository $twoBinding.identity -BackupRoot $isoCfg.backupRoot} 'Set-SBTrackerTaskStatus rifiuta un repository diverso da quello in lavoro'
    $mcpScoped=Invoke-SBMcpToolCall $brain 'get_ready_tasks' @{checkoutPath=$other}|ConvertFrom-Json
    Assert-Portable (@($mcpScoped).Count -ge 1 -and !@($mcpScoped|Where-Object {$_.repository -ne $twoBinding.identity}).Count) 'MCP get_ready_tasks risolve il checkout senza elencare altri repository'
    $mcpAll=Invoke-SBMcpToolCall $brain 'get_ready_tasks' @{all=$true}|ConvertFrom-Json
    Assert-Portable (@($mcpAll|Where-Object {$_.scope -eq 'global'}).Count -ge 2) 'MCP get_ready_tasks vista globale solo con all=true'
    Reject-Portable {Invoke-SBMcpToolCall $brain 'get_ready_tasks' @{all=$true;repository=$twoBinding.identity}} 'MCP all e repository incompatibili'
    $mcpStartup=Invoke-SBMcpToolCall $brain 'get_startup_context' @{checkoutPath=$other}|ConvertFrom-Json
    Assert-Portable ($mcpStartup.repository -eq $twoBinding.identity) 'MCP get_startup_context segue il checkout e non il dossier del cervello'
    Assert-Portable ($mcpStartup.profile -eq 'Slim' -and $mcpStartup.budget -eq 20000 -and $mcpStartup.parts.levels) 'MCP get_startup_context usa il profilo slim e il budget di 20000 per impostazione predefinita'
    $mcpStartupFull=Invoke-SBMcpToolCall $brain 'get_startup_context' @{checkoutPath=$other;profile='full'}|ConvertFrom-Json
    Assert-Portable ($mcpStartupFull.profile -eq 'Full' -and $mcpStartupFull.budget -eq 0 -and $mcpStartupFull.withinBudget -and !$mcpStartupFull.needsCompaction -and !$mcpStartupFull.parts.levels) 'MCP get_startup_context profile=full restituisce il contesto completo senza tetto'
    Reject-Portable {Invoke-SBMcpToolCall $brain 'get_startup_context' @{checkoutPath=$other;profile='enorme'}} 'MCP get_startup_context rifiuta un profilo sconosciuto'
    $scopedCheck=Invoke-SBPortableSync $isoCfg -Check -Repository $twoBinding.identity
    Assert-Portable ($scopedCheck.scope.coverage -eq 'repository-only' -and $scopedCheck.scope.repository -eq $twoBinding.identity) 'Check filtrato dichiara copertura limitata'
    Assert-Portable (!@($scopedCheck.issues|Where-Object {($_.ContainsKey('repository') -and $_.repository -cne $twoBinding.identity) -or $_.ContainsKey('ide') -or $_.kind -like 'global-*'}).Count) 'Check filtrato non riporta esiti di altri repository ne IDE'
    Assert-Portable ((Invoke-SBPortableSync $isoCfg -Check).scope.coverage -eq 'workstation') 'Check senza filtro resta a livello di postazione'
    Reject-Portable {Invoke-SBPortableSync $isoCfg -Check -Repository 'gitlab.example/team/inesistente'} 'Check filtrato su repository non gestito rifiutato'

    # Attivazione guidata -Setup: proposta, conferma, anteprima, applicazione; mai interattiva senza richiesta e senza toccare l'ambiente utente.
    $setupRepos=Join-Path $fixture 'setup-roots'
    foreach($name in @('alpha','beta')){
        $path=Join-Path $setupRepos $name;[IO.Directory]::CreateDirectory($path)|Out-Null;Git-Portable $path @('init','-q')|Out-Null
        Put-Portable (Join-Path $path 'README.md') ('# '+$name)
        Git-Portable $path @('remote','add','origin',('https://gitlab.example/team/'+$name+'.git'))|Out-Null
    }
    Assert-Portable ((Invoke-FixtureCli $accessCli @('-Reconcile','-ConfigPath',$isoActivation.configuration)).exit -eq 0) 'riconciliazione postazione prima di -Setup'
    $hostRoot=Get-SBLocalRoot $brain (Get-SBHostId);$setupSelection=Join-Path $hostRoot 'selection.json';$setupReport=Join-Path $hostRoot 'discovery.json'
    $envBefore=[Environment]::GetEnvironmentVariable('SECONDBRAIN_HOME','User')
    $setupBase=@('-Setup','-Roots',$setupRepos,'-NoRegisterEnvironment')
    $configHash=Get-SBFileHash $isoActivation.configuration
    $proposal=Invoke-FixtureCli 'secondbrain.ps1' ($setupBase+@('-Select','alpha'))
    Assert-Portable ($proposal.exit -eq 1 -and $proposal.text -match '"stage": "proposal"') '-Setup senza conferma termina come proposta (exit 1)'
    $proposalDoc=Read-SBJson $setupSelection $null
    Assert-Portable ($proposalDoc.confirmed -eq $false -and !$proposalDoc.confirmation -and (Test-Path -LiteralPath $setupReport)) '-Setup registra report e selezione per host con confirmed=false'
    Assert-Portable ((Get-SBFileHash $isoActivation.configuration) -eq $configHash) '-Setup senza conferma non modifica la configurazione'
    Assert-Portable ((Invoke-FixtureCli 'secondbrain.ps1' @('-Activate','-SelectionPath',$setupSelection)).exit -ne 0) 'selezione non confermata di -Setup rifiutata da -Activate'
    $previewRun=Invoke-FixtureCli 'secondbrain.ps1' ($setupBase+@('-Select','alpha','-Yes'))
    Assert-Portable ($previewRun.exit -eq 0 -and $previewRun.text -match '"stage": "preview"' -and $previewRun.text -match '"applied": false') '-Setup -Yes senza -Apply produce solo anteprima'
    $previewDoc=Read-SBJson $setupSelection $null
    Assert-Portable ($previewDoc.confirmed -eq $true -and $previewDoc.confirmation -match '^.+@.+ \d{4}-\d{2}-\d{2}T.* \(-Yes\)$' -and $previewDoc.reportSha256 -eq (Get-SBFileHash $setupReport)) 'selection.json generato con conferma registrata (utente, host, data) e hash del report'
    Assert-Portable ((Get-SBFileHash $isoActivation.configuration) -eq $configHash) 'anteprima -Setup non modifica la configurazione'
    $noSelection=(('' | & pwsh -NoProfile -File (Join-Path $brain 'scripts/secondbrain.ps1') -Setup -Roots $setupRepos -NoRegisterEnvironment 2>&1|Out-String))
    Assert-Portable ($LASTEXITCODE -eq 2 -and $noSelection -match 'Selezione assente') '-Setup non interattivo senza selezione e un errore'
    Assert-Portable ((Invoke-FixtureCli 'secondbrain.ps1' ($setupBase+@('-Select','inesistente','-Yes'))).exit -eq 2) '-Setup rifiuta un repository non selezionabile'
    $interactiveRun=(('CONFERMO','' | & pwsh -NoProfile -File (Join-Path $brain 'scripts/secondbrain.ps1') @setupBase -Interactive -Select beta 2>&1|Out-String))
    Assert-Portable ($LASTEXITCODE -eq 0 -and $interactiveRun -match '"stage": "preview"' -and ((Read-SBJson $setupSelection $null).confirmation -match '\(interattiva\)')) '-Setup -Interactive legge la conferma da stdin e resta in anteprima'
    $applyRun=Invoke-FixtureCli 'secondbrain.ps1' ($setupBase+@('-Select','alpha,beta','-Yes','-Apply'))
    Assert-Portable ($applyRun.exit -eq 0 -and $applyRun.text -match '"stage": "applied"' -and $applyRun.text -match '"check"') '-Setup -Yes -Apply attiva ed esegue il controllo successivo'
    $setupCfg=Read-SBJson $isoActivation.configuration $null
    Assert-Portable (@($setupCfg.bindings|Where-Object {$_.path -in @((Join-Path $setupRepos 'alpha'),(Join-Path $setupRepos 'beta'))}).Count -eq 2) '-Setup -Apply registra i binding selezionati'
    Assert-Portable ($setupCfg.selectionReceipt.confirmation -match '\(-Yes\)') 'ricevuta di selezione conserva la conferma'
    Assert-Portable ([Environment]::GetEnvironmentVariable('SECONDBRAIN_HOME','User') -eq $envBefore) '-Setup -NoRegisterEnvironment non cambia l ambiente utente'
    $discoverDefault=Invoke-FixtureCli 'secondbrain.ps1' @('-Discover','-Roots',$setupRepos)
    Assert-Portable ($discoverDefault.exit -eq 0 -and (Test-Path -LiteralPath $setupReport)) '-Discover senza -ReportPath scrive il report per host'

    # -Setup -Status (sola lettura) e -Unbind (disassociazione con proposta, conferma e anteprima).
    $alphaPath=Join-Path $setupRepos 'alpha';$betaPath=Join-Path $setupRepos 'beta'
    $betaBinding=@($setupCfg.bindings|Where-Object path -eq $betaPath)[0]
    $statusHash=Get-SBFileHash $isoActivation.configuration
    $statusRun=Invoke-FixtureCli 'secondbrain.ps1' @('-Setup','-Status')
    $statusDoc=$statusRun.text|ConvertFrom-Json
    Assert-Portable ($statusRun.exit -eq 0 -and $statusDoc.stage -eq 'status' -and @($statusDoc.bindings|Where-Object path -in @($alphaPath,$betaPath)).Count -eq 2 -and $statusDoc.selectionReceipt.confirmation -match '\(-Yes\)') '-Setup -Status mostra binding e ricevuta di selezione'
    Assert-Portable ((Get-SBFileHash $isoActivation.configuration) -eq $statusHash) '-Setup -Status non modifica la configurazione'
    Assert-Portable ((Invoke-FixtureCli 'secondbrain.ps1' @('-Setup','-Status','-Apply')).exit -eq 2 -and (Invoke-FixtureCli 'secondbrain.ps1' @('-Setup','-Status','-Select','alpha')).exit -eq 2 -and (Invoke-FixtureCli 'secondbrain.ps1' @('-Setup','-Status','-Unbind','alpha')).exit -eq 2) '-Setup -Status rifiuta opzioni di scrittura o combinazioni con -Unbind'
    Assert-Portable ((Invoke-FixtureCli 'secondbrain.ps1' @('-Setup','-Unbind','alpha','-Select','beta','-Yes')).exit -eq 2) '-Setup -Unbind rifiuta le opzioni di selezione'
    $unbindProposal=Invoke-FixtureCli 'secondbrain.ps1' @('-Setup','-Unbind',$betaBinding.identity)
    Assert-Portable ($unbindProposal.exit -eq 1 -and $unbindProposal.text -match '"stage": "unbind-proposal"' -and (Get-SBFileHash $isoActivation.configuration) -eq $statusHash) '-Setup -Unbind senza conferma e una proposta e non modifica la configurazione'
    $unbindDoc=Read-SBJson (Join-Path $hostRoot 'unbind-selection.json') $null
    Assert-Portable ($unbindDoc.confirmed -eq $false -and @($unbindDoc.retireCheckoutPaths) -contains $betaPath -and @($unbindDoc.repositories).Count -eq 0) 'selezione di -Unbind registra retireCheckoutPaths con confirmed=false'
    Assert-Portable ((Invoke-FixtureCli 'secondbrain.ps1' @('-Setup','-Unbind','github.com/inesistente/repo','-Yes')).exit -eq 2) '-Setup -Unbind rifiuta un repository non gestito'
    $unbindPreview=Invoke-FixtureCli 'secondbrain.ps1' @('-Setup','-Unbind',$betaBinding.identity,'-Yes')
    Assert-Portable ($unbindPreview.exit -eq 0 -and $unbindPreview.text -match '"stage": "preview"' -and $unbindPreview.text -match '"retiredCheckouts"' -and (Get-SBFileHash $isoActivation.configuration) -eq $statusHash) '-Setup -Unbind -Yes senza -Apply mostra i repository ritirati e non modifica la configurazione'
    $unbindApply=Invoke-FixtureCli 'secondbrain.ps1' @('-Setup','-Unbind',$betaPath,'-Yes','-Apply')
    $afterUnbind=Read-SBJson $isoActivation.configuration $null
    Assert-Portable ($unbindApply.exit -eq 0 -and $unbindApply.text -match '"stage": "applied"' -and !@($afterUnbind.bindings|Where-Object path -eq $betaPath).Count -and @($afterUnbind.bindings|Where-Object path -eq $alphaPath).Count -eq 1) '-Setup -Unbind -Yes -Apply disassocia solo il repository indicato'
    Assert-Portable ((Test-Path -LiteralPath (Join-Path $brain $betaBinding.dossier)) -and $afterUnbind.selectionReceipt.confirmation -match '\(-Yes\)' -and [Environment]::GetEnvironmentVariable('SECONDBRAIN_HOME','User') -eq $envBefore) '-Setup -Unbind conserva il dossier, aggiorna la ricevuta e non cambia l ambiente utente'
    Assert-Portable ((Invoke-FixtureCli 'secondbrain.ps1' @('-Setup','-Unbind',$betaPath,'-Yes','-Apply')).exit -eq 2) '-Setup -Unbind su repository gia disassociato e un errore'
    $statusAfter=(Invoke-FixtureCli 'secondbrain.ps1' @('-Setup','-Status')).text|ConvertFrom-Json
    Assert-Portable (!@($statusAfter.bindings|Where-Object path -eq $betaPath).Count -and @($statusAfter.bindings|Where-Object path -eq $alphaPath).Count -eq 1) '-Setup -Status riflette la disassociazione'

    # -Setup -Output: registra outputStatus/outputEvidence/outputException con proposta, conferma, anteprima e -Apply.
    $alphaBinding=@($statusAfter.bindings|Where-Object path -eq $alphaPath)[0]
    $outProof=Join-Path $brain '.runtime/output-proof-cli.json';Put-Portable $outProof '{"scenario":"synthetic output location proof"}'
    $outHash=Get-SBFileHash $outProof;$outCfgHash=Get-SBFileHash $isoActivation.configuration
    $outVerified=@('-Setup','-Output',$alphaBinding.identity,'-OutputStatus','verified','-Evidence',$outProof)
    $outProposal=Invoke-FixtureCli 'secondbrain.ps1' $outVerified
    Assert-Portable ($outProposal.exit -eq 1 -and $outProposal.text -match '"stage": "output-proposal"' -and (Get-SBFileHash $isoActivation.configuration) -eq $outCfgHash) '-Setup -Output senza conferma e una proposta e non modifica la configurazione'
    $outPreview=Invoke-FixtureCli 'secondbrain.ps1' ($outVerified+@('-Yes'))
    Assert-Portable ($outPreview.exit -eq 0 -and $outPreview.text -match '"stage": "preview"' -and $outPreview.text -match $outHash -and (Get-SBFileHash $isoActivation.configuration) -eq $outCfgHash) '-Setup -Output -Yes senza -Apply e una anteprima e non modifica la configurazione'
    Assert-Portable ((Invoke-FixtureCli 'secondbrain.ps1' @('-Setup','-Output',$alphaBinding.identity,'-OutputStatus','verified','-Yes','-Apply')).exit -eq 2) '-Setup -Output verified senza prova e un errore'
    Assert-Portable ((Invoke-FixtureCli 'secondbrain.ps1' @('-Setup','-Output',$alphaBinding.identity,'-OutputStatus','verified','-Evidence',(Join-Path $fixture 'fuori-runtime.json'),'-Yes','-Apply')).exit -eq 2) '-Setup -Output rifiuta una prova fuori da .runtime'
    Assert-Portable ((Invoke-FixtureCli 'secondbrain.ps1' @('-Setup','-Output',$alphaBinding.identity,'-OutputStatus','exception-accepted','-Yes','-Apply')).exit -eq 2 -and (Invoke-FixtureCli 'secondbrain.ps1' @('-Setup','-Output',$alphaBinding.identity,'-OutputStatus','exception-accepted','-Exception','   ','-Yes','-Apply')).exit -eq 2) '-Setup -Output exception-accepted richiede un motivo non vuoto'
    Assert-Portable ((Invoke-FixtureCli 'secondbrain.ps1' @('-Setup','-Output','github.com/inesistente/repo','-OutputStatus','unverified','-Yes','-Apply')).exit -eq 2 -and (Invoke-FixtureCli 'secondbrain.ps1' @('-Setup','-Output',$alphaBinding.identity,'-OutputStatus','boh','-Yes','-Apply')).exit -eq 2) '-Setup -Output rifiuta repository non gestito e stato non valido'
    Assert-Portable ((Invoke-FixtureCli 'secondbrain.ps1' @('-Setup','-Output',$alphaBinding.identity,'-OutputStatus','unverified','-Select','alpha','-Yes')).exit -eq 2 -and (Invoke-FixtureCli 'secondbrain.ps1' @('-Setup','-Status','-Output',$alphaBinding.identity,'-OutputStatus','unverified')).exit -eq 2 -and (Invoke-FixtureCli 'secondbrain.ps1' @('-Setup','-OutputStatus','unverified')).exit -eq 2) '-Setup -Output rifiuta combinazioni incompatibili'
    Assert-Portable ((Get-SBFileHash $isoActivation.configuration) -eq $outCfgHash) 'gli errori di -Setup -Output non modificano la configurazione'
    $outApply=Invoke-FixtureCli 'secondbrain.ps1' ($outVerified+@('-Yes','-Apply'))
    $afterOut=Read-SBJson $isoActivation.configuration $null;$afterOutBinding=@($afterOut.bindings|Where-Object path -eq $alphaPath)[0]
    Assert-Portable ($outApply.exit -eq 0 -and $outApply.text -match '"stage": "applied"' -and $afterOutBinding.outputStatus -eq 'verified' -and $afterOutBinding.outputEvidence -ieq $outProof -and $afterOutBinding.outputEvidenceSha256 -eq $outHash) '-Setup -Output -Apply registra stato, prova e hash nel binding'
    Assert-Portable ((Get-SBFileHash $afterOutBinding.outputEvidence) -eq $afterOutBinding.outputEvidenceSha256) 'l hash registrato dalla CLI coincide con i byte della prova (stesso criterio di Check)'
    $outException=Invoke-FixtureCli 'secondbrain.ps1' @('-Setup','-Output',$alphaPath,'-OutputStatus','exception-accepted','-Exception','Output in cartella prodotto approvata dall utente','-Yes','-Apply')
    $afterException=@((Read-SBJson $isoActivation.configuration $null).bindings|Where-Object path -eq $alphaPath)[0]
    Assert-Portable ($outException.exit -eq 0 -and $afterException.outputStatus -eq 'exception-accepted' -and $afterException.outputException -match 'approvata' -and !$afterException.ContainsKey('outputEvidence') -and !$afterException.ContainsKey('outputEvidenceSha256')) '-Setup -Output exception-accepted sostituisce la prova con il motivo'
    $outReset=Invoke-FixtureCli 'secondbrain.ps1' @('-Setup','-Output',$alphaPath,'-OutputStatus','unverified','-Yes','-Apply')
    $afterReset=@((Read-SBJson $isoActivation.configuration $null).bindings|Where-Object path -eq $alphaPath)[0]
    Assert-Portable ($outReset.exit -eq 0 -and $afterReset.outputStatus -eq 'unverified' -and !$afterReset.ContainsKey('outputException') -and (Test-Path -LiteralPath $outProof)) '-Setup -Output unverified azzera lo stato e conserva la prova'

    # -Setup -Unbind per integrazioni IDE: id o nome, anteprima, file IDE e dossier intatti, ambiguita rifiutate.
    $ideFile=Join-Path $fixture 'fake-ide-instructions.md';Put-Portable $ideFile "# Istruzioni IDE fittizie`n"
    $ideFileHash=Get-SBFileHash $ideFile
    $ideCfg=Read-SBJson $isoActivation.configuration $null
    $ideBase=$ideCfg.ides
    $ideCfg.ides=@(@($ideCfg.ides)+@(
        @{id='fakeide-aaaaaaaaaaaa';name='Fake IDE';mode='file';instructions=$ideFile;selected=$true;profile='default';accountAlias='uno'},
        @{id='fakeide-bbbbbbbbbbbb';name='Fake IDE';mode='file';instructions=$ideFile;selected=$true;profile='default';accountAlias='due'},
        @{id='fakeide-cccccccccccc';name='Fake IDE Solo';mode='file';instructions=$ideFile;selected=$true;profile='default';accountAlias='tre'}))
    Put-Portable $isoActivation.configuration (ConvertTo-SBJson $ideCfg)
    $ideStatusDoc=(Invoke-FixtureCli 'secondbrain.ps1' @('-Setup','-Status')).text|ConvertFrom-Json
    Assert-Portable (@($ideStatusDoc.ides|Where-Object id -like 'fakeide-*').Count -eq 3) '-Setup -Status elenca le integrazioni IDE gestite'
    Assert-Portable ((Invoke-FixtureCli 'secondbrain.ps1' @('-Setup','-Unbind','Fake IDE','-Yes')).exit -eq 2) '-Setup -Unbind rifiuta un nome IDE ambiguo'
    Assert-Portable ((Invoke-FixtureCli 'secondbrain.ps1' @('-Setup','-Unbind','ide-inesistente','-Yes')).exit -eq 2) '-Setup -Unbind rifiuta un IDE non gestito'
    $ideHashBefore=Get-SBFileHash $isoActivation.configuration
    $ideProposal=Invoke-FixtureCli 'secondbrain.ps1' @('-Setup','-Unbind','fakeide-aaaaaaaaaaaa')
    $ideUnbindDoc=Read-SBJson (Join-Path $hostRoot 'unbind-selection.json') $null
    Assert-Portable ($ideProposal.exit -eq 1 -and $ideProposal.text -match '"retireIDEIds"' -and $ideUnbindDoc.confirmed -eq $false -and @($ideUnbindDoc.retireIDEIds) -contains 'fakeide-aaaaaaaaaaaa' -and @($ideUnbindDoc.retireCheckoutPaths).Count -eq 0 -and (Get-SBFileHash $isoActivation.configuration) -eq $ideHashBefore) 'unbind IDE senza conferma registra retireIDEIds come proposta e non modifica la configurazione'
    $idePreview=Invoke-FixtureCli 'secondbrain.ps1' @('-Setup','-Unbind','fakeide-aaaaaaaaaaaa','-Yes')
    Assert-Portable ($idePreview.exit -eq 0 -and $idePreview.text -match '"stage": "preview"' -and $idePreview.text -match 'fakeide-aaaaaaaaaaaa' -and (Get-SBFileHash $isoActivation.configuration) -eq $ideHashBefore) 'unbind IDE -Yes senza -Apply mostra retiredIdes e non modifica la configurazione'
    $ideApply=Invoke-FixtureCli 'secondbrain.ps1' @('-Setup','-Unbind','fakeide-aaaaaaaaaaaa','-Yes','-Apply')
    $afterIde=Read-SBJson $isoActivation.configuration $null
    Assert-Portable ($ideApply.exit -eq 0 -and $ideApply.text -match '"stage": "applied"' -and !@($afterIde.ides|Where-Object id -eq 'fakeide-aaaaaaaaaaaa').Count -and @($afterIde.ides|Where-Object id -in @('fakeide-bbbbbbbbbbbb','fakeide-cccccccccccc')).Count -eq 2 -and @($afterIde.bindings|Where-Object path -eq $alphaPath).Count -eq 1) 'unbind IDE -Apply rimuove solo l integrazione indicata e conserva binding e altri IDE'
    Assert-Portable ((Get-SBFileHash $ideFile) -eq $ideFileHash) 'unbind IDE non modifica il file di istruzioni dell IDE'
    Assert-Portable ((Invoke-FixtureCli 'secondbrain.ps1' @('-Setup','-Unbind','fakeide-aaaaaaaaaaaa','-Yes','-Apply')).exit -eq 2) 'unbind IDE ripetuto e un errore'
    $mixed=Invoke-FixtureCli 'secondbrain.ps1' @('-Setup','-Unbind',('fakeide-bbbbbbbbbbbb,Fake IDE Solo,'+$alphaPath),'-Yes','-Apply')
    $afterMixed=Read-SBJson $isoActivation.configuration $null
    Assert-Portable ($mixed.exit -eq 0 -and !@($afterMixed.ides|Where-Object id -like 'fakeide-*').Count -and !@($afterMixed.bindings|Where-Object path -eq $alphaPath).Count -and (Test-Path -LiteralPath (Join-Path $brain $betaBinding.dossier))) 'unbind misto repository + IDE (id e nome) disassocia tutto e conserva i dossier'
    Assert-Portable (@($afterMixed.ides|Where-Object {$_}).Count -eq @($ideBase|Where-Object {$_}).Count) 'configurazione IDE ripristinata allo stato precedente alla prova'

    # Rilevamento del cambio di contesto IDE (login, profilo, radice di configurazione) senza leggere credenziali (SB-EVO-ALIGN-REPOS-IDE).
    $ctxSaved=@{USERPROFILE=$env:USERPROFILE;APPDATA=$env:APPDATA;CLAUDE_CONFIG_DIR=$env:CLAUDE_CONFIG_DIR;CODEX_HOME=$env:CODEX_HOME}
    $ctxUserClaude=[Environment]::GetEnvironmentVariable('CLAUDE_CONFIG_DIR','User');$ctxUserCodex=[Environment]::GetEnvironmentVariable('CODEX_HOME','User')
    try{
        $ctxHome=Join-Path $fixture 'ctx-home';$ctxApp=Join-Path $ctxHome 'AppData/Roaming'
        [void][IO.Directory]::CreateDirectory($ctxApp)
        $env:USERPROFILE=$ctxHome;$env:APPDATA=$ctxApp
        # Variabili User e Process non devono influenzare la prova: si lavora su una sola radice dedicata.
        if($ctxUserClaude -or $ctxUserCodex){Write-Host 'NOTA: variabili CLAUDE_CONFIG_DIR/CODEX_HOME utente presenti; prove sul fingerprint limitate a Cursor/Windsurf/JetBrains'}
        $ctxBase=(Get-SBIDEContext 'Cursor')
        Assert-Portable ($ctxBase.configDirectories.Count -eq 0 -and $ctxBase.fingerprint -match '^[0-9A-Fa-f]{64}$') 'contesto IDE: nessuna cartella di configurazione rilevata nel profilo vuoto'
        Assert-Portable ($null -eq (Get-SBIDEContext 'IDE Sconosciuto')) 'contesto IDE: nome sconosciuto non produce un fingerprint'
        Assert-Portable ((Get-SBIDEContext 'Claude Code (file CLAUDE.md)').name -eq 'Claude Code' -and (Get-SBIDEContext 'VS Code + Continue').name -eq 'Continue' -and (Get-SBIDEContext 'Claude (app: impostazioni account)').name -eq 'Claude account instructions') 'contesto IDE: i nomi descrittivi delle configurazioni migrate sono ricondotti al nome canonico'
        [void][IO.Directory]::CreateDirectory((Join-Path $ctxHome '.cursor'));[void][IO.Directory]::CreateDirectory((Join-Path $ctxApp 'Windsurf'));[void][IO.Directory]::CreateDirectory((Join-Path $ctxApp 'JetBrains/IntelliJIdea2026.1'))
        $ctxCursor=Get-SBIDEContext 'Cursor'
        Assert-Portable (@($ctxCursor.configDirectories) -contains '~/.cursor' -and $ctxCursor.fingerprint -cne $ctxBase.fingerprint) 'contesto IDE: la comparsa della cartella di configurazione cambia il fingerprint'
        $ctxAssets=@(Get-SBIDEAssets)
        $ctxCursorAsset=@($ctxAssets|Where-Object name -eq 'Cursor');$ctxWindsurfAsset=@($ctxAssets|Where-Object name -eq 'Windsurf');$ctxJetBrainsAsset=@($ctxAssets|Where-Object name -eq 'JetBrains AI')
        Assert-Portable ($ctxCursorAsset.Count -eq 1 -and $ctxCursorAsset[0].mode -eq 'manual' -and @($ctxCursorAsset[0].installationEvidence) -contains 'Directory: ~/.cursor' -and $ctxCursorAsset[0].environmentFingerprint -ceq $ctxCursor.fingerprint) 'Get-SBIDEAssets: Cursor manuale con evidenza di installazione e fingerprint'
        Assert-Portable ($ctxWindsurfAsset.Count -eq 1 -and @($ctxWindsurfAsset[0].installationEvidence) -contains 'Directory: %APPDATA%/Windsurf') 'Get-SBIDEAssets: Windsurf con evidenza di installazione'
        Assert-Portable ($ctxJetBrainsAsset.Count -eq 1 -and ((@($ctxJetBrainsAsset[0].installationEvidence)-join ' ') -match 'IntelliJIdea2026\.1')) 'Get-SBIDEAssets: JetBrains con evidenza di installazione e prodotti'
        $ctxJetFingerprint=(Get-SBIDEContext 'JetBrains AI').fingerprint
        [void][IO.Directory]::CreateDirectory((Join-Path $ctxApp 'JetBrains/PyCharm2026.1'))
        Assert-Portable ((Get-SBIDEContext 'JetBrains AI').fingerprint -ceq $ctxJetFingerprint) 'contesto IDE: un nuovo prodotto JetBrains non cambia il fingerprint'
        # Cursor registrato con il fingerprint corrente: invariato; con una base diversa: cambiato; senza base: non registrato.
        $ctxIde=@{id='manual-ctx0000000000';name='Cursor';mode='manual';environmentFingerprint=$ctxCursor.fingerprint}
        Assert-Portable ((Get-SBIDEContextState $ctxIde $null).status -eq 'unchanged') 'stato contesto IDE: invariato con base coincidente'
        Remove-Item -LiteralPath (Join-Path $ctxHome '.cursor') -Recurse -Force
        Assert-Portable ((Get-SBIDEContextState $ctxIde $null).status -eq 'changed') 'stato contesto IDE: cambiato dopo la scomparsa della cartella di configurazione'
        $ctxLegacy=@{id='manual-ctx0000000000';name='Cursor'}
        Assert-Portable ((Get-SBIDEContextState $ctxLegacy $null).status -eq 'unrecorded' -and (Get-SBIDEContextState $ctxLegacy @{ideContext=@{'manual-ctx0000000000'=(Get-SBIDEContext 'Cursor').fingerprint}}).status -eq 'unchanged') 'stato contesto IDE: base mancante non registrata, poi letta da state.json'
        Assert-Portable ((Get-SBIDEContextState @{id='x';name='IDE Sconosciuto'} $null).status -eq 'unknown') 'stato contesto IDE: IDE non riconosciuto'
        # Cambio della radice di configurazione di Claude Code (nuovo profilo/login): il fingerprint cambia solo se l override e effettivo.
        if(!$ctxUserClaude){
            $env:CLAUDE_CONFIG_DIR=$null;$claudeBefore=(Get-SBIDEContext 'Claude Code').fingerprint
            $env:CLAUDE_CONFIG_DIR=(Join-Path $ctxHome '.claude-altro-profilo');$claudeAfter=(Get-SBIDEContext 'Claude Code')
            Assert-Portable ($claudeAfter.fingerprint -cne $claudeBefore -and $claudeAfter.rootSource -eq 'process-env' -and $claudeAfter.instructions -like '*.claude-altro-profilo*CLAUDE.md') 'contesto IDE: CLAUDE_CONFIG_DIR diverso cambia fingerprint, origine e percorso istruzioni'
        }
        # Check/Sync: contesto registrato diverso -> ide-context-changed (liveLoadingVerified falso, filesAligned invariato); riattivazione = nuova base.
        $ctxIdeBase=@{}+$observationIDE;$ctxIdeBase.name='Cursor'
        $ctxChangedIde=@{}+$ctxIdeBase;$ctxChangedIde.environmentFingerprint=(Get-SBTextHash 'contesto-precedente')
        $ctxCfg=@{}+$manualCfg;$ctxCfg.ides=@($ctxChangedIde)
        $ctxChanged=Invoke-SBPortableSync $ctxCfg -ObservationPath $receiptJsonPath -Check
        Assert-Portable (@($ctxChanged.issues|Where-Object kind -eq 'ide-context-changed').Count -eq 1 -and $ctxChanged.liveLoadingVerified -eq $false -and $ctxChanged.filesAligned -eq $true) 'Check segnala ide-context-changed senza alterare filesAligned'
        $ctxSameIde=@{}+$ctxIdeBase;$ctxSameIde.environmentFingerprint=(Get-SBIDEContext 'Cursor').fingerprint
        $ctxOk=@{}+$ctxCfg;$ctxOk.ides=@($ctxSameIde)
        $ctxSame=Invoke-SBPortableSync $ctxOk -ObservationPath $receiptJsonPath -Check
        Assert-Portable (!@($ctxSame.issues|Where-Object kind -eq 'ide-context-changed').Count) 'Check non segnala ide-context-changed con base coincidente'
    }finally{
        foreach($key in $ctxSaved.Keys){[Environment]::SetEnvironmentVariable($key,$ctxSaved[$key],'Process')}
    }
    Assert-Portable ((Get-SBFileHash $ideFile) -eq $ideFileHash) 'rilevamento del contesto IDE non modifica i file di istruzioni dell IDE'

    # Cervello su share: alias di percorso, attesa del writer, letture senza lock, marker transazione, cache e ambiente di lavoro.
    Assert-Portable (Test-SBSamePath 'D:\Srv\Share\Dir' 'd:\srv\share\dir\') 'percorsi: maiuscole e separatore finale ignorati'
    Assert-Portable (Test-SBSamePath '\\SRV.corp.local\share\x' '\\srv\SHARE\X') 'percorsi: UNC con FQDN e nome breve equivalenti'
    Assert-Portable (!(Test-SBSamePath '\\srv1\share\x' '\\srv2\share\x')) 'percorsi: server diversi non equivalenti'
    Assert-Portable (Test-SBSamePath '\\10.0.0.5\share\x' '\\10.0.0.5\SHARE\x') 'percorsi: indirizzo IP non troncato al primo ottetto'
    Assert-Portable (!(Test-SBSamePath '\\10.0.0.5\share\x' '\\10.9.9.9\share\x')) 'percorsi: indirizzi IP diversi non equivalenti'
    Assert-Portable ((Test-SBSamePath ('\\localhost\'+$brain.Substring(0,1)+'$'+$brain.Substring(2)) $brain)) 'percorsi: condivisione amministrativa locale equivale al drive'
    Assert-Portable ((Convert-SBBrainAlias '\\srv\s\b\.runtime\x.json' '\\srv\s\b' 'Z:\b') -eq 'Z:\b\.runtime\x.json') 'percorsi: riscrittura di un percorso registrato da un altro host'
    $genBefore=Get-SBWriteGeneration
    Put-Portable (Join-Path $brain '.runtime/generation-probe.txt') 'a'
    Write-SBFile (Join-Path $brain '.runtime/generation-probe.txt') ([Text.Encoding]::UTF8.GetBytes('b')) (Get-SBFileHash (Join-Path $brain '.runtime/generation-probe.txt')) (Join-Path $hostRoot 'backups')|Out-Null
    Assert-Portable ((Get-SBWriteGeneration) -gt $genBefore) 'ogni scrittura incrementa la generazione per invalidare le cache'
    $env:SECONDBRAIN_PARA_CACHE='1'
    try{
        $paraA=@(Get-SBParaEntities $brain @());$paraB=@(Get-SBParaEntities $brain @())
        Assert-Portable ($paraA.Count -ge 1 -and [object]::ReferenceEquals($paraA[0],$paraB[0])) 'cache PARA: seconda lettura servita dalla memoria'
        Write-SBFile (Join-Path $brain '.runtime/generation-probe.txt') ([Text.Encoding]::UTF8.GetBytes('c')) (Get-SBFileHash (Join-Path $brain '.runtime/generation-probe.txt')) (Join-Path $hostRoot 'backups')|Out-Null
        $paraC=@(Get-SBParaEntities $brain @())
        Assert-Portable (![object]::ReferenceEquals($paraA[0],$paraC[0])) 'cache PARA: una scrittura invalida la memoria'
    }finally{Remove-Item Env:\SECONDBRAIN_PARA_CACHE -ErrorAction SilentlyContinue}
    $paraD=@(Get-SBParaEntities $brain @());$paraE=@(Get-SBParaEntities $brain @())
    Assert-Portable (![object]::ReferenceEquals($paraD[0],$paraE[0])) 'cache PARA: disattivata in locale'
    $localWork=Join-Path $fixture 'local-work'
    $defaultWork=Get-SBWorkEnvironment $brain (Get-SBHostId) 'github.com/acme/repo'
    Assert-Portable ($defaultWork.location -eq 'brain-runtime' -and $defaultWork.root.StartsWith((Join-Path $brain '.runtime'))) 'ambiente di lavoro predefinito sotto .runtime'
    $env:SECONDBRAIN_WORK_LOCAL_ROOT=$localWork
    try{
        $overrideWork=Get-SBWorkEnvironment $brain (Get-SBHostId) 'github.com/acme/repo'
        Assert-Portable ($overrideWork.location -eq 'local-override' -and $overrideWork.root.StartsWith($localWork) -and $overrideWork.environment.TEMP.StartsWith($localWork)) 'ambiente di lavoro locale per host su richiesta'
        $env:SECONDBRAIN_WORK_LOCAL_ROOT='\\server\share\work'
        Reject-Portable {Get-SBWorkEnvironment $brain (Get-SBHostId) 'github.com/acme/repo'} 'ambiente di lavoro locale rifiuta percorsi di rete'
    }finally{Remove-Item Env:\SECONDBRAIN_WORK_LOCAL_ROOT -ErrorAction SilentlyContinue}
    Assert-Portable ((Invoke-FixtureCli $accessCli @('-Reconcile','-ConfigPath',$isoActivation.configuration)).exit -eq 0) 'riconciliazione postazione prima dei test di concorrenza'
    $holder=Invoke-FixtureCli $accessCli @('-Start','-Mode','Write','-Client','test-share')
    $holderId=if($holder.text -match '"sessionId":\s*"([a-f0-9]{32})"'){$Matches[1]}else{''}
    Assert-Portable ($holder.exit -eq 0 -and $holderId) 'sessione di scrittura A aperta (tiene writer.lock)'
    try{
        $busy=Invoke-FixtureCli 'secondbrain.ps1' @('-Sync','-WaitSeconds','1')
        Assert-Portable ($busy.exit -eq 3 -and $busy.text -match 'occupato' -and $busy.text -match 'Titolare' -and $busy.text -match 'test-share') 'scrittura B concorrente: exit 3 a timeout con il titolare'
        $readCheck=Invoke-FixtureCli 'secondbrain.ps1' @('-Check')
        Assert-Portable ($readCheck.exit -in @(0,1) -and $readCheck.text -match 'concurrent-writer') 'Check durante un writer non si blocca e segnala lo snapshot potenzialmente intermedio'
        $readTasks=Invoke-FixtureCli 'knowledge.ps1' @('-Tasks','-All')
        Assert-Portable ($readTasks.exit -eq 0 -and $readTasks.text -match 'writer SecondBrain e attivo') 'knowledge in lettura non si blocca e avvisa del writer'
        $waiter=Start-Job -ScriptBlock {param($script) $out=(& pwsh -NoProfile -File $script -Sync -WaitSeconds 30 2>&1|Out-String);$out+"`nEXIT="+$LASTEXITCODE} -ArgumentList (Join-Path $brain 'scripts/secondbrain.ps1')
        Start-Sleep -Seconds 3
    }finally{
        & pwsh -NoProfile -File (Join-Path $brain 'scripts/access.ps1') -End -SessionId $holderId *> $null
    }
    $waited=Receive-Job -Job $waiter -Wait -AutoRemoveJob
    Assert-Portable ($waited -match 'attesa fino a' -and $waited -match 'EXIT=(0|1)\b') 'scrittura B attende il rilascio di A e poi procede senza exit 3'
    Assert-Portable ($waited -notmatch 'EXIT=3') 'scrittura B non termina con exit 3 se il writer viene rilasciato entro l attesa'
    $badWait=Join-Path $brain 'config/shared.json';$sharedOriginal=Read-SBText $badWait
    try{
        $sharedDoc=Read-SBJson $badWait @{};$sharedDoc.lockWaitSeconds=-5;Put-Portable $badWait (ConvertTo-SBJson $sharedDoc)
        $badResult=Invoke-FixtureCli 'secondbrain.ps1' @('-Check')
        Assert-Portable ($badResult.exit -eq 2 -and $badResult.text -match 'lockWaitSeconds') 'lockWaitSeconds non valido rifiutato'
    }finally{Put-Portable $badWait $sharedOriginal}

    # Simulazione dello scenario share senza una vera share SMB: scrittori concorrenti, attesa configurabile, processo terminato.
    $holderScript=Join-Path $hostRoot 'smb-sim-holder.ps1';$holderReady=Join-Path $hostRoot 'smb-sim-ready.txt'
    Put-Portable $holderScript @'
param($Brain,$ConfigPath,$Ready)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $Brain 'scripts/SecondBrain.Core.psm1')
Import-Module (Join-Path $Brain 'scripts/SecondBrain.Access.psm1')
$config=Read-SBConfiguration $ConfigPath
$lock=Enter-SBOperation $config $null
Set-Content -LiteralPath $Ready -Value 'ready'
Start-Sleep -Seconds 300
'@
    function Start-SmbSimHolder {
        Remove-Item -LiteralPath $holderReady -ErrorAction SilentlyContinue
        $process=Start-Process pwsh -ArgumentList @('-NoProfile','-File',$holderScript,'-Brain',$brain,'-ConfigPath',$isoActivation.configuration,'-Ready',$holderReady) -PassThru -WindowStyle Hidden
        for($i=0;$i -lt 120 -and !(Test-Path -LiteralPath $holderReady) -and !$process.HasExited;$i++){Start-Sleep -Milliseconds 250}
        $process
    }
    $simHolder=Start-SmbSimHolder
    try{
        Assert-Portable ((Test-Path -LiteralPath $holderReady) -and !$simHolder.HasExited) 'simulazione share: un writer in un altro processo tiene il lock'
        $sharedDoc=Read-SBJson $badWait @{};$sharedDoc.lockWaitSeconds=2;Put-Portable $badWait (ConvertTo-SBJson $sharedDoc)
        try{
            $configWait=Invoke-FixtureCli 'secondbrain.ps1' @('-Sync')
            Assert-Portable ($configWait.exit -eq 3 -and $configWait.text -match 'attesa fino a 2 s' -and $configWait.text -match 'Titolare') 'lockWaitSeconds di shared.json governa l attesa (exit 3 con il titolare)'
            $env:SECONDBRAIN_LOCK_WAIT_SECONDS='1'
            try{$envWait=Invoke-FixtureCli 'secondbrain.ps1' @('-Sync')}finally{Remove-Item Env:\SECONDBRAIN_LOCK_WAIT_SECONDS -ErrorAction SilentlyContinue}
            Assert-Portable ($envWait.exit -eq 3 -and $envWait.text -match 'attesa fino a 1 s') 'SECONDBRAIN_LOCK_WAIT_SECONDS prevale su shared.json'
        }finally{Put-Portable $badWait $sharedOriginal}
        $racers=@(1..2|ForEach-Object {Start-Job -ScriptBlock {param($script) $out=(& pwsh -NoProfile -File $script -Sync -WaitSeconds 1 2>&1|Out-String);$out+"`nEXIT="+$LASTEXITCODE} -ArgumentList (Join-Path $brain 'scripts/secondbrain.ps1')})
        $racerOutputs=@($racers|Receive-Job -Wait -AutoRemoveJob)
        Assert-Portable (@($racerOutputs|Where-Object {$_ -match 'EXIT=3\b' -and $_ -match 'Titolare'}).Count -eq 2) 'due writer concorrenti con il lock occupato escono entrambi con exit 3 e il titolare'
    }finally{
        if(!$simHolder.HasExited){Stop-Process -Id $simHolder.Id -Force}
        $simHolder.WaitForExit(10000)|Out-Null
    }
    $afterKill=Invoke-FixtureCli 'secondbrain.ps1' @('-Sync','-WaitSeconds','5')
    Assert-Portable ($afterKill.exit -in @(0,1) -and $afterKill.text -notmatch 'occupato') 'processo writer terminato: il sistema rilascia il lock e un nuovo writer procede senza forzature'
    Assert-Portable ($null -eq (Get-SBPendingTransaction $brain)) 'processo writer terminato: nessuna transazione pendente'
    $contenders=@(1..3|ForEach-Object {Start-Job -ScriptBlock {param($script) $out=(& pwsh -NoProfile -File $script -Sync -WaitSeconds 120 2>&1|Out-String);$out+"`nEXIT="+$LASTEXITCODE} -ArgumentList (Join-Path $brain 'scripts/secondbrain.ps1')})
    $contenderOutputs=@($contenders|Receive-Job -Wait -AutoRemoveJob)
    Assert-Portable (@($contenderOutputs|Where-Object {$_ -match 'EXIT=(0|1)\b'}).Count -eq 3) 'tre Sync simultanei si serializzano e terminano tutti senza errore ne exit 3'
    Assert-Portable ($null -eq (Get-SBPendingTransaction $brain) -and (Invoke-FixtureCli 'secondbrain.ps1' @('-Check')).exit -in @(0,1)) 'dopo la contesa il cervello e consistente (nessun marker, Check eseguibile)'
    $mixedDrive=$brain.Substring(0,1);$mixedTail=$brain.Substring(2);$otherDrive=if($mixedDrive -ieq 'Z'){'Y'}else{'Z'}
    Assert-Portable ((Test-SBSamePath ('\\127.0.0.1\'+$mixedDrive+'$'+$mixedTail) $brain) -and (Test-SBSamePath ('\\'+$env:COMPUTERNAME+'\'+$mixedDrive.ToLowerInvariant()+'$'+$mixedTail) $brain) -and (Test-SBSamePath ('\\'+$env:COMPUTERNAME+'.corp.local\'+$mixedDrive+'$'+$mixedTail) $brain)) 'alias amministrativi locali: indirizzo di loopback, nome macchina e FQDN equivalgono al drive'
    Assert-Portable (!(Test-SBSamePath ('\\localhost\'+$otherDrive+'$'+$mixedTail) $brain) -and !(Test-SBSamePath ('\\localhost\dati'+$mixedTail) $brain)) 'alias amministrativi: drive diverso o condivisione non amministrativa non equivalgono'
    $txTarget=Join-Path $brain '.runtime/tx-target.txt';Put-Portable $txTarget 'originale'
    $guardCalls=0
    Set-SBWriteGuard {$script:guardCalls++;if($script:guardCalls -ge 3){throw 'interruzione simulata'}}
    try{Invoke-SBParaTransaction @(@{path=$txTarget;expected=(Get-SBFileHash $txTarget);bytes=[Text.Encoding]::UTF8.GetBytes('nuovo')}) (Join-Path $hostRoot 'backups') $brain|Out-Null}catch{$txError=$_.Exception.Message}
    Set-SBWriteGuard $null
    $markerPath=Join-Path $brain '.runtime/para-transaction.json'
    $markerDoc=Read-SBJson $markerPath @{}
    Assert-Portable ((Test-Path -LiteralPath $markerPath) -and $txError -match 'interrotta' -and $markerDoc.computer -eq [Environment]::MachineName -and $markerDoc.user -and $markerDoc.startedAt -and $markerDoc.brainRoot) 'marker transazione registra host, utente, data e radice'
    $readPending=Invoke-FixtureCli 'secondbrain.ps1' @('-Check')
    Assert-Portable ($readPending.exit -in @(0,1) -and $readPending.text -match 'pending-transaction') 'Check con transazione pendente prosegue con un avviso'
    $writePending=Invoke-FixtureCli 'secondbrain.ps1' @('-Sync')
    Assert-Portable ($writePending.exit -eq 2 -and $writePending.text -match 'Transazione PARA incompleta' -and $writePending.text -match 'recover\.ps1' -and $writePending.text -match [regex]::Escape([Environment]::MachineName)) 'scrittura con transazione pendente rifiutata con chi, quando e come recuperare'
    $statusPending=Invoke-FixtureCli $accessCli @('-Status')
    Assert-Portable ($statusPending.exit -eq 0 -and $statusPending.text -match 'Transazione PARA incompleta') 'access -Status riepiloga la transazione pendente'
    $pendingManifest=(Get-SBPendingTransaction $brain).manifest
    $recoverPending=Invoke-FixtureCli 'recover.ps1' @('-ManifestPath',$pendingManifest,'-Apply')
    Assert-Portable ($recoverPending.exit -eq 0 -and !(Test-Path -LiteralPath $markerPath) -and (Read-SBText $txTarget) -eq 'originale') 'recupero della transazione interrotta da una postazione qualunque'
    $adminAlias='\\localhost\'+$brain.Substring(0,1)+'$'+$brain.Substring(2)
    if(Test-Path -LiteralPath $adminAlias){
        $aliasTarget=Join-Path $brain '.runtime/tx-alias.txt';Put-Portable $aliasTarget 'originale'
        $guardCalls=0
        Set-SBWriteGuard {$script:guardCalls++;if($script:guardCalls -ge 3){throw 'interruzione simulata'}}
        try{Invoke-SBParaTransaction @(@{path=$aliasTarget;expected=(Get-SBFileHash $aliasTarget);bytes=[Text.Encoding]::UTF8.GetBytes('nuovo')}) (Join-Path $hostRoot 'backups') $brain|Out-Null}catch{}
        Set-SBWriteGuard $null
        $aliasManifest=Join-Path $adminAlias (Get-SBPendingTransaction $brain).manifest.Substring($brain.Length).TrimStart('\')
        $aliasRecover=(& pwsh -NoProfile -File (Join-Path $adminAlias 'scripts/recover.ps1') -ManifestPath $aliasManifest -Apply 2>&1|Out-String)
        Assert-Portable ($LASTEXITCODE -eq 0 -and !(Test-Path -LiteralPath $markerPath)) 'recupero del marker tramite un alias UNC dello stesso cervello'
        if(Test-Path -LiteralPath (Join-Path $realBrain '.git')){
            $realAlias='\\localhost\'+$realBrain.Substring(0,1)+'$'+$realBrain.Substring(2)
            Assert-Portable ((Invoke-SBGit $realAlias @('rev-parse','--show-toplevel')).code -eq 0) 'git su alias UNC del cervello (safe.directory passato per il solo cervello)'
        }
    }else{Assert-Portable $true 'alias UNC amministrativo non raggiungibile su questa macchina: prova saltata e dichiarata'}

    # Secondo host simulato (stessa macchina fisica, NON una prova su un secondo PC): clone del cervello in un altro percorso, checkout in radici diverse con spazi,
    # profilo utente deviato. Il secondo host si associa ai dossier esistenti per identita, senza duplicarli e senza toccare il primo host.
    function New-SecondHostBrain([string]$Path){
        [IO.Directory]::CreateDirectory((Join-Path $Path 'scripts'))|Out-Null
        Get-ChildItem -LiteralPath $PSScriptRoot -File|Copy-Item -Destination (Join-Path $Path 'scripts')
        [IO.Directory]::CreateDirectory((Join-Path $Path 'config'))|Out-Null
        foreach($name in @('shared.json','tracker.schema.json','prompt-catalog.schema.json')){Copy-Item -LiteralPath (Join-Path $PSScriptRoot ('../config/'+$name)) -Destination (Join-Path $Path ('config/'+$name))}
        [IO.Directory]::CreateDirectory((Join-Path $Path 'direttive'))|Out-Null
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../direttive/prompts') -Destination (Join-Path $Path 'direttive/prompts') -Recurse
        foreach($name in @('AGENTS.global_ide.md','workstation.template.md','approved.json')){Copy-Item -LiteralPath (Join-Path $brain ('direttive/'+$name)) -Destination (Join-Path $Path ('direttive/'+$name))}
    }
    function Invoke-HostCli([string]$BrainPath,[string]$Script,[string[]]$Arguments){
        $text=(& pwsh -NoProfile -File (Join-Path $BrainPath ('scripts/'+$Script)) @Arguments 2>&1|Out-String)
        [pscustomobject]@{exit=$LASTEXITCODE;text=$text}
    }
    $hostAbrain=Join-Path $fixture 'host-a\SecondBrain';$hostBbrain=Join-Path $fixture 'secondo pc\livello uno\livello due\SecondBrain clone'
    $hostAroots=Join-Path $fixture 'host-a\src';$hostBroots=Join-Path $fixture 'secondo pc\sorgenti con spazi'
    foreach($side in @(@($hostAroots,'A'),@($hostBroots,'B'))){
        foreach($pair in @(@('one','https://gitlab.example/team/hostone.git'),@('two','https://other.example/team/hosttwo.git'))){
            $path=Join-Path $side[0] $pair[0];[IO.Directory]::CreateDirectory($path)|Out-Null;Git-Portable $path @('init','-q')|Out-Null
            Put-Portable (Join-Path $path 'README.md') ('# '+$pair[0]);Git-Portable $path @('remote','add','origin',$pair[1])|Out-Null
        }
    }
    New-SecondHostBrain $hostAbrain
    $homeBefore=[Environment]::GetEnvironmentVariable('SECONDBRAIN_HOME','User')
    $setupA=Invoke-HostCli $hostAbrain 'secondbrain.ps1' @('-Setup','-Roots',$hostAroots,'-Select','one,two','-Yes','-Apply','-NoRegisterEnvironment')
    $cfgAFile=@(Get-ChildItem -LiteralPath (Join-Path $hostAbrain '.runtime/hosts') -Recurse -Filter workstation.json)[0].FullName
    $cfgA=Read-SBJson $cfgAFile $null
    Assert-Portable ($setupA.exit -eq 0 -and @($cfgA.bindings).Count -eq 2) 'host A: -Setup applica due binding'
    $areasA=@(Get-ChildItem -LiteralPath (Join-Path $hostAbrain '02-areas/products') -Directory|ForEach-Object Name|Sort-Object)
    # Clone del cervello su un secondo percorso: solo conoscenza condivisa (dossier, indice PARA), nessuno stato di postazione.
    New-SecondHostBrain $hostBbrain
    Copy-Item -LiteralPath (Join-Path $hostAbrain '02-areas') -Destination (Join-Path $hostBbrain '02-areas') -Recurse
    foreach($shared in @('para-index.json','PARA.md')){if(Test-Path -LiteralPath (Join-Path $hostAbrain $shared)){Copy-Item -LiteralPath (Join-Path $hostAbrain $shared) -Destination (Join-Path $hostBbrain $shared)}}
    $hostAhash=Get-SBFileHash $cfgAFile
    $profileB=Join-Path $fixture 'secondo pc\profilo utente';[IO.Directory]::CreateDirectory((Join-Path $profileB 'AppData\Roaming'))|Out-Null
    $savedEnv=@{USERPROFILE=$env:USERPROFILE;APPDATA=$env:APPDATA;LOCALAPPDATA=$env:LOCALAPPDATA}
    try{
        $env:USERPROFILE=$profileB;$env:APPDATA=Join-Path $profileB 'AppData\Roaming';$env:LOCALAPPDATA=Join-Path $profileB 'AppData\Local'
        $setupB=Invoke-HostCli $hostBbrain 'secondbrain.ps1' @('-Setup','-Roots',$hostBroots,'-Select','one,two','-Yes','-Apply','-NoRegisterEnvironment')
        $setupB2=Invoke-HostCli $hostBbrain 'secondbrain.ps1' @('-Setup','-Roots',$hostBroots,'-Select','one,two','-Yes','-Apply','-NoRegisterEnvironment')
        $statusB=Invoke-HostCli $hostBbrain 'secondbrain.ps1' @('-Setup','-Status')
    }finally{foreach($key in $savedEnv.Keys){Set-Item -Path ('Env:'+$key) -Value $savedEnv[$key]}}
    $cfgBFile=@(Get-ChildItem -LiteralPath (Join-Path $hostBbrain '.runtime/hosts') -Recurse -Filter workstation.json)[0].FullName
    $cfgB=Read-SBJson $cfgBFile $null
    Assert-Portable ($setupB.exit -eq 0 -and $setupB.text -match '"stage": "applied"' -and @($cfgB.bindings).Count -eq 2) 'host B: -Setup associa i checkout del secondo percorso'
    Assert-Portable ((@($cfgB.bindings|ForEach-Object identity|Sort-Object) -join ',') -eq (@($cfgA.bindings|ForEach-Object identity|Sort-Object) -join ',')) 'host B: stesse identita repository del host A'
    Assert-Portable (!@($cfgB.bindings|Where-Object {$_.path -notlike ($hostBroots+'*')}).Count -and !@($cfgA.bindings|Where-Object {$_.path -notlike ($hostAroots+'*')}).Count) 'host B: percorsi propri (con spazi) distinti da quelli del host A'
    Assert-Portable ((@(Get-ChildItem -LiteralPath (Join-Path $hostBbrain '02-areas/products') -Directory|ForEach-Object Name|Sort-Object) -join ',') -eq ($areasA -join ',')) 'host B: i dossier esistenti vengono riusati per identita, nessun duplicato'
    Assert-Portable ((@($cfgB.bindings|ForEach-Object dossier|Sort-Object) -join ',') -eq (@($cfgA.bindings|ForEach-Object dossier|Sort-Object) -join ',')) 'host B: binding puntano agli stessi dossier'
    Assert-Portable ($setupB2.exit -eq 0 -and @((Read-SBJson $cfgBFile $null).bindings).Count -eq 2) 'host B: ripetere -Setup e idempotente (nessun binding duplicato)'
    $statusBdoc=$statusB.text|ConvertFrom-Json
    Assert-Portable ($statusB.exit -eq 0 -and !@($statusBdoc.bindings|Where-Object {$_.path -like ($hostAroots+'*')}).Count) 'host B: -Setup -Status non mostra i checkout del host A'
    Assert-Portable ((Get-SBFileHash $cfgAFile) -eq $hostAhash) 'host A: configurazione invariata dalle operazioni del host B'
    Assert-Portable ([Environment]::GetEnvironmentVariable('SECONDBRAIN_HOME','User') -eq $homeBefore) 'secondo host simulato non cambia SECONDBRAIN_HOME'
    $checkB=Invoke-HostCli $hostBbrain 'secondbrain.ps1' @('-Check')
    Assert-Portable ($checkB.exit -in 0,1 -and $checkB.text -notmatch 'Configurazione non trovata|Postazione non attivata') 'host B: -Check eseguibile sulla configurazione del secondo percorso'

    'SUCCESS PORTABLE: '+$checks+' verifiche; fixture conservata: '+$fixture
}finally{Write-Output ('Fixture portabile conservata: '+$fixture)}
