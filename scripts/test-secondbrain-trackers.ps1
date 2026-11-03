#requires -Version 7.5
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Para.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Tracker.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.TrackerImport.psm1') -Force
. (Join-Path $PSScriptRoot 'test-helpers.ps1')
$script:checks=0
function Assert-Tracker($Condition,[string]$Message){if(!$Condition){throw 'FAIL TRACKER: '+$Message};$script:checks++;'PASS TRACKER: '+$Message}
function Reject-Tracker([scriptblock]$Action,[string]$Message){$caught=$false;try{& $Action|Out-Null}catch{$caught=$true};Assert-Tracker $caught $Message}
function Put-Tracker([string]$Path,[string]$Text){[IO.Directory]::CreateDirectory((Split-Path $Path))|Out-Null;[IO.File]::WriteAllText($Path,$Text,[Text.UTF8Encoding]::new($false))}
function Snapshot-Tracker([string]$Root){$state=@{};foreach($f in Get-ChildItem -LiteralPath $Root -Recurse -File -Force){$state[$f.FullName]=@{hash=Get-SBFileHash $f.FullName;time=$f.LastWriteTimeUtc.Ticks}};ConvertTo-SBJson $state}
$root=Join-Path (Get-SBTestRoot) ('secondbrain-tracker-test-'+[guid]::NewGuid().ToString('N'))
$success=$false
try {
    $brain=Join-Path $root 'brain';$dir=Join-Path $brain '02-areas/products/Repo';$checkout=Join-Path $root 'repos/Repo'
    $identity='github.com/test/repo';$schema=Join-Path $PSScriptRoot '../config/tracker.schema.json'
    [IO.Directory]::CreateDirectory($checkout)|Out-Null
    Put-Tracker (Join-Path $dir 'repository.json') (ConvertTo-SBJson @{schemaVersion=1;identity=$identity})
    Put-Tracker (Join-Path $dir 'para.json') (ConvertTo-SBJson @{schemaVersion=1;id='repo-area';kind='area';title='Repo';status='active'})
    foreach($file in @('context.md','memory.md','brief.md')){Put-Tracker (Join-Path $dir $file) '# Dossier'}
    $runtime=Get-SBLocalRoot $brain 'fixture'
    $config=@{brainRoot=$brain;backupRoot=(Join-Path $runtime 'backups');runtimeRoot=$runtime;repositoryRoot=(Join-Path $root 'repos');allowedOwners=@('test')}
    $source=Join-Path $dir 'tracker.md'
    $json=Join-Path $checkout 'legacy-tasks.json'
    $families=@('tasks','todos','current_tasks','next_tasks','remainingTasks','residuals','todo_autonomous','todo_user_required')
    foreach($family in $families){
        $value=@{id='CASE-01';title='Task';status='PARTIAL';p='critical-local';unknown=@{nested=@(1,$false,$null)};verify=@('build','test')}
        $original=@{($family)=@($value);notes=@('nota');decisions=@{a='b'}}
        Put-Tracker $json (ConvertTo-SBJson $original)
        $converted=ConvertTo-SBTracker $json $identity
        Assert-Tracker ($converted.tasks.Count -eq 1 -and $converted.tasks[0].status -eq 'in_progress') ('famiglia '+$family)
        Assert-Tracker ((ConvertTo-SBJson $original) -ceq (ConvertTo-SBJson $converted.extensions.original)) ('conservazione integrale '+$family)
        Assert-Tracker ($converted.tasks[0].priority -eq 'critical-local' -and $converted.tasks[0].acceptance.Count -eq 2 -and !$converted.tasks[0].evidence.Count) ('criteri e priorita senza prove inventate '+$family)
        [void](Test-SBTrackerData $converted $identity @($identity) $schema)
    }
    Put-Tracker $json '{"todos":["AUDIT-41 intervento", "testo senza id"],"important_notes":["non un task"]}'
    $a=ConvertTo-SBTracker $json $identity;$b=ConvertTo-SBTracker $json $identity
    Assert-Tracker ($a.tasks.Count -eq 2 -and $a.tasks[0].id -eq 'AUDIT-41' -and $a.tasks[1].id -like 'MIG-*' -and $a.tasks[1].id -eq $b.tasks[1].id) 'ID testuali stabili, note escluse'
    Put-Tracker $json '{"tasks":[],"unknown":{"empty":[]}}'
    $empty=ConvertTo-SBTracker $json $identity
    Assert-Tracker ($empty.tasks.Count -eq 0 -and $empty.extensions.original.unknown.ContainsKey('empty')) 'JSON vuoto senza task inventati'
    Put-Tracker $json '{"todos":["ripetuto","ripetuto"]}'
    Reject-Tracker {ConvertTo-SBTracker $json $identity} 'collisione stringhe identiche richiede risoluzione'
    Put-Tracker $json '{"tasks":[{"id":"X","status":"superseded_removed"},{"id":"Y","status":"nuovo"}]}'
    $states=ConvertTo-SBTracker $json $identity
    Assert-Tracker ($states.tasks[0].status -eq 'cancelled' -and $states.tasks[1].status -eq 'unknown') 'stati ritirati e sconosciuti'
    Put-Tracker $json '{"todo_user_required":[{"id":"X","status":"waiting_user_certificate","dependencies":["certificato"]}]}'
    $ambiguous=ConvertTo-SBTracker $json $identity
    Assert-Tracker ($ambiguous.tasks[0].execution -eq 'user_required' -and $ambiguous.tasks[0].status -eq 'unknown' -and $ambiguous.tasks[0].extensions.unresolvedDependencies[0] -eq 'certificato') 'prerequisito ambiguo conservato e review richiesta'
    # The batch uses the existing guarded writer for mixed documents and its own data journal.
    $mixed=Join-Path $checkout 'mixed.md';$mixedArchive=Join-Path $dir 'history/mixed.original.txt';$mixedView=Join-Path $dir 'history/mixed.md'
    Put-Tracker $mixed "# Contract`r`nCurrent`r`n## Receipt`r`nPast`r`n"
    $mixedBytes=[IO.File]::ReadAllBytes($mixed);$mixedHash=Get-SBFileHash $mixed
    $journal=Join-Path $root 'content-plan.json';$contentBackup=Join-Path $root 'content-backup'
    Put-Tracker $journal (ConvertTo-SBJson @{phase='prepared';sourceHash=$mixedHash;operations=@($mixedArchive,$mixedView,$mixed)})
    [void](Write-SBFile $mixedArchive $mixedBytes 'absent' $contentBackup)
    Assert-Tracker ((Get-SBFileHash $mixedArchive) -eq $mixedHash -and (Get-SBFileHash $mixed) -eq $mixedHash) 'documento misto: copia esatta prima di modificare la fonte'
    # Resume after copying: the same payload is a no-op, then publish a readable historical section.
    $copyTime=(Get-Item -LiteralPath $mixedArchive).LastWriteTimeUtc.Ticks
    [void](Write-SBFile $mixedArchive $mixedBytes $mixedHash $contentBackup)
    [void](Write-SBFile $mixedView ([Text.Encoding]::UTF8.GetBytes("# Receipt`nPast`n")) 'absent' $contentBackup)
    [void](Write-SBFile $mixed ([Text.Encoding]::UTF8.GetBytes("# Contract`r`nCurrent`r`n")) $mixedHash $contentBackup)
    Assert-Tracker ((Get-Item -LiteralPath $mixedArchive).LastWriteTimeUtc.Ticks -eq $copyTime -and !(Read-SBText $mixed).Contains('Past') -and (Read-SBText $mixedView).Contains('Past')) 'documento misto: ripresa senza duplicazioni e contratto corrente conservato'
    $publishedHash=Get-SBFileHash $mixed
    Put-Tracker $mixed 'concurrent edit'
    Reject-Tracker {Write-SBFile $mixed $mixedBytes $publishedHash $contentBackup} 'documento misto: recupero rifiuta la modifica concorrente'
    Assert-Tracker ((Read-SBText $mixed) -ceq 'concurrent edit' -and (Get-SBFileHash $mixedArchive) -eq $mixedHash) 'documento misto: entrambe le versioni preservate dopo il rifiuto'
    [void](Write-SBFile $mixed $mixedBytes (Get-SBFileHash $mixed) $contentBackup)
    Assert-Tracker ((Get-SBFileHash $mixed) -eq $mixedHash) 'documento misto: recupero esplicito dai byte verificati'
    $reviewPath=Join-Path $root 'review.json'
    $review=@{schemaVersion=1;repository=$identity;sourceSha256=Get-SBFileHash $json;tasks=@(@{id=$ambiguous.tasks[0].id;status='blocked';dependencies=@();prerequisites=@('certificato');reason='Prerequisito ambientale confermato nella sorgente, non un ID task'})}
    Put-Tracker $reviewPath (ConvertTo-SBJson $review)
    $reviewed=ConvertTo-SBTracker -SourcePath $json -Identity $identity -ReviewPath $reviewPath
    Assert-Tracker ($reviewed.tasks[0].status -eq 'blocked' -and !$reviewed.tasks[0].dependencies.Count -and $reviewed.tasks[0].extensions.prerequisites[0] -eq 'certificato') 'review riconcilia prerequisito senza inventare dipendenze'
    Assert-Tracker ((ConvertTo-SBJson $reviewed.extensions.original) -ceq (ConvertTo-SBJson $ambiguous.extensions.original) -and $reviewed.tasks[0].extensions.unresolvedDependencies[0] -eq 'certificato') 'review conserva dati originali e ambiguita di origine'
    $review.repository='github.com/test/other';Put-Tracker $reviewPath (ConvertTo-SBJson $review)
    Reject-Tracker {ConvertTo-SBTracker -SourcePath $json -Identity $identity -ReviewPath $reviewPath} 'review di altra identita rifiutata'
    $review.repository=$identity;$review.sourceSha256='A'*64;Put-Tracker $reviewPath (ConvertTo-SBJson $review)
    Reject-Tracker {ConvertTo-SBTracker -SourcePath $json -Identity $identity -ReviewPath $reviewPath} 'review di altra revisione sorgente rifiutata'
    $review.sourceSha256=Get-SBFileHash $json;$review.tasks[0].Remove('dependencies');Put-Tracker $reviewPath (ConvertTo-SBJson $review)
    Reject-Tracker {ConvertTo-SBTracker -SourcePath $json -Identity $identity -ReviewPath $reviewPath} 'review non puo ignorare dipendenze irrisolte'
    $review.tasks[0].dependencies=@();$review.tasks+=,$review.tasks[0];Put-Tracker $reviewPath (ConvertTo-SBJson $review)
    Reject-Tracker {ConvertTo-SBTracker -SourcePath $json -Identity $identity -ReviewPath $reviewPath} 'review con ID duplicati rifiutata'
    $review.tasks=@(@{id='inesistente';status='todo';reason='review'});Put-Tracker $reviewPath (ConvertTo-SBJson $review)
    Reject-Tracker {ConvertTo-SBTracker -SourcePath $json -Identity $identity -ReviewPath $reviewPath} 'review di task inesistente rifiutata'
    $valid=New-SBTrackerTask @{id='X';title='task';status='pending'} $identity tasks 'source' ('A'*64) '/tasks/0'
    $document=@{schemaVersion=1;repository=$identity;updatedAt=[DateTimeOffset]::UtcNow.ToString('o');tasks=@($valid);history=@();extensions=@{}}
    $document.tasks+=,$valid
    Reject-Tracker {Test-SBTrackerData $document $identity @($identity) $schema} 'ID duplicati rifiutati'
    $document.tasks=@($valid);$valid.dependencies=@(@{id='missing'})
    Reject-Tracker {Test-SBTrackerData $document $identity @($identity) $schema} 'dipendenza mancante rifiutata'
    $valid.dependencies=@(@{id='X'})
    Reject-Tracker {Test-SBTrackerData $document $identity @($identity) $schema} 'ciclo rifiutato'
    $valid.dependencies=@(@{id='X';repository='github.com/foreign/repo'})
    Reject-Tracker {Test-SBTrackerData $document $identity @($identity) $schema} 'identita esterna non gestita rifiutata'
    $other=New-SBTrackerTask @{id='Y';title='other';status='pending'} 'github.com/test/other' tasks 'source' ('B'*64) '/tasks/0'
    $otherDoc=@{schemaVersion=1;repository='github.com/test/other';updatedAt=$document.updatedAt;tasks=@($other);history=@();extensions=@{}}
    $valid.dependencies=@(@{id='Y';repository='github.com/test/other'})
    Assert-Tracker (Test-SBTrackerData $document $identity @($identity,'github.com/test/other') $schema @{'github.com/test/other'=$otherDoc}) 'dipendenza cross-repo risolta per identita'
    $other.dependencies=@(@{id='X';repository=$identity})
    Reject-Tracker {Test-SBTrackerData $document $identity @($identity,'github.com/test/other') $schema @{'github.com/test/other'=$otherDoc}} 'ciclo cross-repo rifiutato'
    $valid.dependencies=@();$document.updatedAt='not-a-date'
    Reject-Tracker {Test-SBTrackerData $document $identity @($identity) $schema} 'data invalida rifiutata'
    $document.updatedAt=[DateTimeOffset]::UtcNow.ToString('o')
    Put-Tracker $source "# Tracker`n`n## Attività aperte / Prossimi passi`n`n| SB-OPT-06 | P1 — da eseguire | SB-OPT-01..02 conclusi | Criterio completo |`n`n## Residui verificati`n`n- [ ] Residuo blocked by policy`n`n## Passaggio di sessione`n`nTesto storico da conservare senza convertirlo in task.`n"
    $history=Join-Path $brain 'docs/history/completed.md'
    Put-Tracker $history "| SB-OPT-01 | Completato | Primo esito |`n| SB-OPT-02 | Completato | Secondo esito |`n"
    $markdown=ConvertTo-SBTracker -SourcePath $source -Identity $identity -HistoryPath $history
    Assert-Tracker ($markdown.tasks.Count -eq 4 -and $markdown.tasks[0].dependencies.Count -eq 2 -and $markdown.extensions.original.markdown.Contains('Testo storico')) 'Markdown importa solo attivita, residui e completamenti espliciti'
    [void](Test-SBTrackerData $markdown $identity @($identity) $schema)
    # Rimuove solo il JSON creato da questa fixture per esercitare il fallback.
    [IO.File]::Delete($json)
    $resolved=Resolve-SBTracker $brain $identity $checkout @('test')
    Assert-Tracker ($resolved.source -eq 'dossier_undeclared') 'resolver Markdown non dichiarato'
    Put-Tracker $json '{}'
    Assert-Tracker ((Resolve-SBTracker $brain $identity $checkout @('test')).source -eq 'repository_undeclared') 'precedenza della fonte nel checkout preservata'
    $metaPath=Join-Path $dir 'repository.json'
    $declared=@{schemaVersion=1;identity=$identity;tracker=@{location='dossier';path='tracker.json';schemaVersion=1}}
    Put-Tracker $metaPath (ConvertTo-SBJson $declared)
    Reject-Tracker {Resolve-SBTracker $brain $identity $checkout @('test')} 'fonte dichiarata assente: nessun fallback'
    $declared.tracker.path='../tracker.json';Put-Tracker $metaPath (ConvertTo-SBJson $declared)
    Reject-Tracker {Resolve-SBTracker $brain $identity $checkout @('test')} 'path traversal nella dichiarazione rifiutato'
    $declared.tracker.path='tracker.json';Put-Tracker $metaPath (ConvertTo-SBJson $declared)
    Put-Tracker (Join-Path $dir 'tracker.json') (ConvertTo-SBJson $document)
    Put-Tracker (Join-Path $brain 'direttive/AGENTS.global_ide.md') "# Common`nRevisione 3.1 — 2026-10-25."
    Put-Tracker (Join-Path $brain 'direttive/workstation.template.md') 'legacy'
    function Approve-TrackerFixture {
        Put-Tracker (Join-Path $brain 'direttive/approved.json') (ConvertTo-SBJson @{authorization='fixture';files=@{'direttive/AGENTS.global_ide.md'=Get-SBFileHash (Join-Path $brain 'direttive/AGENTS.global_ide.md');'direttive/workstation.template.md'=Get-SBFileHash (Join-Path $brain 'direttive/workstation.template.md')}})
    }
    Approve-TrackerFixture
    Reject-Tracker {Resolve-SBTracker $brain $identity $checkout @('test')} 'contratto non approvato impedisce attivazione'
    Put-Tracker (Join-Path $brain 'direttive/workstation.template.md') '<!-- secondbrain:tracker-contract:1 -->'
    Approve-TrackerFixture
    Assert-Tracker ((Resolve-SBTracker $brain $identity $checkout @('test')).source -eq 'dossier') 'fonte dichiarata approvata risolta'
    Put-Tracker (Join-Path $dir 'tracker.json') '{}'
    Reject-Tracker {Resolve-SBTracker $brain $identity $checkout @('test')} 'fonte dichiarata invalida: nessun fallback'
    Put-Tracker $metaPath (ConvertTo-SBJson @{schemaVersion=1;identity=$identity})
    [IO.File]::Delete((Join-Path $dir 'tracker.json'));[IO.File]::Delete($json)
    # Prova riferimenti curati: fence storico e snapshot non devono diventare falsi positivi.
    Put-Tracker (Join-Path $dir 'context.md') ('repos/Repo/memory.md'+"`n"+'[manca](missing.md)'+"`n"+'Esempio inline: `[titolo](url)`.'+"`n"+'```powershell'+"`n"+'repos/Example/memory.md'+"`n"+'[esempio](example.md)'+"`n"+'```')
    Put-Tracker (Join-Path $dir 'history/old.md') 'repos/Repo/memory.md'
    Put-Tracker (Join-Path $dir 'snapshots/old.md') '[manca](old.md)'
    $before=Snapshot-Tracker $root
    $issues=@(Get-SBCuratedReferenceIssues $brain @(Get-SBParaEntities $brain @('test')))
    Assert-Tracker ($issues.Count -eq 2 -and $issues[0] -like '*obsoleto*' -and $issues[1] -like '*mancante*') 'riferimenti curati rilevati, codice e storico esclusi'
    Assert-Tracker ((Snapshot-Tracker $root) -ceq $before) 'controllo riferimenti non scrive file o timestamp'
    Put-Tracker (Join-Path $dir 'context.md') '# Dossier'
    # Ogni checkpoint viene interrotto e poi ripreso, compreso quello successivo alla rimozione.
    foreach($checkpoint in @('pending','prepared','copied','verified','references_updated','originals_removed','completed')){
        $hash=Get-SBFileHash $source
        $fail={param($name) if($name -eq $checkpoint){throw 'interruzione fixture'}}.GetNewClosure()
        Reject-Tracker {Invoke-SBTrackerImport -Config $config -Identity $identity -SourcePath $source -HistoryPath $history -Activate -AfterPhase $fail} ('interruzione '+$checkpoint)
        $registration=Read-SBJson (Get-SBTrackerImportPath $config $identity) $null
        $m=Read-SBTrackerManifest $config $registration.manifest
        Assert-Tracker ($m.phase -eq $checkpoint) ('manifest checkpoint '+$checkpoint)
        [void](Invoke-SBTrackerImport -Config $config -ManifestPath $registration.manifest -Activate)
        $m=Read-SBTrackerManifest $config $registration.manifest
        Assert-Tracker ($m.phase -eq 'completed' -and !(Test-Path -LiteralPath $source) -and (Get-SBFileHash $m.source.archive) -eq $hash) ('ripresa senza perdita '+$checkpoint)
        Assert-Tracker (@(Get-SBTrackerImportIssues $config).Count -eq 0) ('audit migrazione completata '+$checkpoint)
        $again=Snapshot-Tracker $dir
        [void](Invoke-SBTrackerImport -Config $config -ManifestPath $registration.manifest -Activate)
        Assert-Tracker ((Snapshot-Tracker $dir) -ceq $again) ('riesecuzione senza duplicazioni '+$checkpoint)
        if($checkpoint -eq 'completed'){
            # Layout precedente alla V1.0 (prefisso tracker-migration): registro, manifest e archivio restano leggibili e verificabili.
            $newReg=Get-SBTrackerImportPath $config $identity;$oldReg=$newReg.Replace('tracker-imports','tracker-migrations')
            $archiveDir=Split-Path (Read-SBJson $registration.manifest $null).source.archive
            [IO.Directory]::CreateDirectory((Split-Path $oldReg))|Out-Null
            Move-Item -LiteralPath $newReg -Destination $oldReg
            Move-Item -LiteralPath $archiveDir -Destination $archiveDir.Replace('tracker-import-','tracker-migration-')
            $oldText=(Read-SBText $registration.manifest).Replace('tracker-import-','tracker-migration-').Replace('"kind": "tracker-import"','"kind": "tracker-migration"')
            [IO.File]::WriteAllText($registration.manifest,$oldText,[Text.UTF8Encoding]::new($false))
            Assert-Tracker ((Read-SBTrackerManifest $config $registration.manifest).kind -eq 'tracker-migration' -and @(Get-SBTrackerImportIssues $config).Count -eq 0 -and (Test-Path -LiteralPath $oldReg)) 'layout tracker-migration precedente ancora letto e verificato'
        }
        Restore-SBTrackerImport $config $registration.manifest
        Assert-Tracker ((Get-SBFileHash $source) -eq $hash -and !(Read-SBJson $metaPath @{}).ContainsKey('tracker')) ('recupero esatto '+$checkpoint)
    }
    # La preparazione reale conserva la fonte originale finche il testo non e approvato.
    Put-Tracker (Join-Path $brain 'direttive/workstation.template.md') 'legacy';Approve-TrackerFixture
    $manifest=Invoke-SBTrackerImport -Config $config -Identity $identity -SourcePath $source -HistoryPath $history
    Assert-Tracker ((Read-SBTrackerManifest $config $manifest).phase -eq 'verified' -and (Test-Path -LiteralPath $source) -and !(Test-Path -LiteralPath (Join-Path $dir 'tracker.json'))) 'preparazione verificata senza attivazione'
    $before=Snapshot-Tracker $root;$issues=@(Get-SBTrackerImportIssues $config)
    Assert-Tracker ($issues.Count -eq 1 -and $issues[0] -match 'verified') 'Check segnala migrazione preparata'
    Assert-Tracker ((Snapshot-Tracker $root) -ceq $before) 'Check manifest non modifica file o timestamp'
    Reject-Tracker {Invoke-SBTrackerImport -Config $config -ManifestPath $manifest -Activate} 'attivazione senza approvazione rifiutata'
    $original=Read-SBText $source;Put-Tracker $source ($original+"`nModifica concorrente")
    Reject-Tracker {Invoke-SBTrackerImport -Config $config -ManifestPath $manifest} 'sorgente cambiata dopo copia rifiutata'
    Restore-SBTrackerImport $config $manifest
    Assert-Tracker ((Read-SBText $source).Contains('Modifica concorrente')) 'recupero preserva modifica concorrente estranea'
    Put-Tracker $source $original
    Put-Tracker (Join-Path $brain 'direttive/workstation.template.md') '<!-- secondbrain:tracker-contract:1 -->';Approve-TrackerFixture
    $manifest=Invoke-SBTrackerImport -Config $config -Identity $identity -SourcePath $source -HistoryPath $history -Activate
    $target=Join-Path $dir 'tracker.json';$text=Read-SBText $target
    Put-Tracker $target ($text+"`n")
    Reject-Tracker {Restore-SBTrackerImport $config $manifest} 'recupero rifiuta modifiche successive'
    Put-Tracker $target $text;Restore-SBTrackerImport $config $manifest
    # I progetti devono convergere sulla dichiarazione, anche se entrambe le copie esistono.
    $project=Join-Path $brain '01-projects/test-project'
    Put-Tracker (Join-Path $project 'brief.md') '# Brief'
    Put-Tracker (Join-Path $project 'para.json') (ConvertTo-SBJson @{schemaVersion=1;id='test-project';kind='project';title='Project';status='active';areas=@('repo-area');trackers=@(@{area='repo-area';path='tracker.md'})})
    Put-Tracker $metaPath (ConvertTo-SBJson $declared)
    Put-Tracker (Join-Path $dir 'tracker.json') (ConvertTo-SBJson $document)
    Assert-Tracker (@(Get-SBTrackerAuthorityIssues $brain @(Get-SBParaEntities $brain @('test'))).Count -eq 1) 'due fonti esistenti ma divergenti rilevate'
    Put-Tracker $metaPath (ConvertTo-SBJson @{schemaVersion=1;identity=$identity})
    [IO.File]::Delete((Join-Path $dir 'tracker.json'))
    $manifest=Invoke-SBTrackerImport -Config $config -Identity $identity -SourcePath $source -HistoryPath $history -Activate
    $projectMeta=Read-SBJson (Join-Path $project 'para.json') $null
    Assert-Tracker ($projectMeta.trackers[0].path -eq 'tracker.json' -and @(Get-SBTrackerAuthorityIssues $brain @(Get-SBParaEntities $brain @('test'))).Count -eq 0) 'migrazione riallinea tracker del Progetto'
    Restore-SBTrackerImport $config $manifest
    Put-Tracker $json '{"todo_user_required":[{"id":"ENV-01","status":"waiting_user_certificate","dependencies":["certificato"]}]}'
    $review=@{schemaVersion=1;repository=$identity;sourceSha256=Get-SBFileHash $json;tasks=@(@{id='ENV-01';status='blocked';dependencies=@();prerequisites=@('certificato');reason='Certificato esterno richiesto, conservato come prerequisito'})}
    Put-Tracker $reviewPath (ConvertTo-SBJson $review)
    & git -C $checkout init -q
    & git -C $checkout remote add origin 'https://github.com/test/repo.git'
    $reviewManifest=Invoke-SBTrackerImport -Config $config -Identity $identity -SourcePath $json -ReviewPath $reviewPath
    $reviewState=Read-SBTrackerManifest $config $reviewManifest
    Assert-Tracker ($reviewState.phase -eq 'verified' -and (Get-SBFileHash $reviewState.reviewSource.backup) -eq (Get-SBFileHash $reviewPath) -and (Get-SBFileHash $reviewState.reviewSource.archive) -eq (Get-SBFileHash $reviewPath)) 'manifest conserva backup e originale esatto della review'
    Put-Tracker $reviewPath '{}'
    Reject-Tracker {Invoke-SBTrackerImport -Config $config -ManifestPath $reviewManifest -Activate} 'ripresa rifiuta review modificata dopo preparazione'
    Put-Tracker $reviewPath (ConvertTo-SBJson $review)
    [void](Invoke-SBTrackerImport -Config $config -ManifestPath $reviewManifest -Activate)
    Assert-Tracker ((Read-SBTrackerManifest $config $reviewManifest).phase -eq 'completed' -and !(Test-Path -LiteralPath $json)) 'ripresa attiva candidato prodotto dalla review registrata'
    Assert-Tracker (@(Get-SBTrackerImportIssues $config).Count -eq 0) 'Check comprende payload della review'
    Restore-SBTrackerImport $config $reviewManifest
    Assert-Tracker ((Test-Path -LiteralPath $json) -and (Test-Path -LiteralPath $reviewPath)) 'recupero review preserva entrambe le fonti originali'
    [IO.File]::Delete($json)
    # CLI vera: anteprima in sola lettura e compositore sulla fonte dichiarata.
    [IO.Directory]::CreateDirectory((Join-Path $brain 'scripts'))|Out-Null
    Get-ChildItem -LiteralPath $PSScriptRoot -File|Copy-Item -Destination (Join-Path $brain 'scripts')
    Put-Tracker (Join-Path $brain 'config/shared.json') (ConvertTo-SBJson @{schemaVersion=1;allowedOwners=@('test');excludedDirectories=@('.git')})
    Copy-Item -LiteralPath $schema -Destination (Join-Path $brain 'config/tracker.schema.json')
    $cliConfig=Join-Path $config.runtimeRoot 'workstation.json'
    Put-Tracker $cliConfig (ConvertTo-SBJson @{schemaVersion=1;mode='portable';workstationId='fixture';runtimeRoot=$config.runtimeRoot;backupRoot=$config.backupRoot;ides=@();
        bindings=@(@{path=$checkout;identity=$identity;remoteIdentity=$identity;status='managed'})})
    $before=Snapshot-Tracker $root
    & pwsh -NoProfile -File (Join-Path $brain 'scripts/import-tracker.ps1') -Repository $identity -SourcePath $source -HistoryPath $history -ConfigPath $cliConfig|Out-Null
    Assert-Tracker ($LASTEXITCODE -eq 0 -and (Snapshot-Tracker $root) -ceq $before) 'CLI anteprima non modifica file o timestamp'
    & pwsh -NoProfile -File (Join-Path $brain 'scripts/import-tracker.ps1') -Repository $identity -SourcePath $source -HistoryPath $history -ConfigPath $cliConfig -Apply|Out-Null
    Assert-Tracker ($LASTEXITCODE -eq 1) 'CLI prepara e segnala attivazione pendente'
    $registration=Read-SBJson (Get-SBTrackerImportPath $config $identity) $null
    & pwsh -NoProfile -File (Join-Path $brain 'scripts/import-tracker.ps1') -ResumeManifest $registration.manifest -ConfigPath $cliConfig -Apply -Activate|Out-Null
    Assert-Tracker ($LASTEXITCODE -eq 0) 'CLI attiva solo con contratto approvato'
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../direttive/prompts') -Destination (Join-Path $brain 'direttive/prompts') -Recurse
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../config/prompt-catalog.schema.json') -Destination (Join-Path $brain 'config/prompt-catalog.schema.json')
    Put-Tracker (Join-Path $brain 'para-index.json') (Get-SBParaIndex $brain @('test')).json
    Put-Tracker (Join-Path $checkout 'AGENTS.md') '# Repo'
    $composed=@(& pwsh -NoProfile -File (Join-Path $brain 'scripts/prompts.ps1') -Compose -ConfigPath $cliConfig -Repository $identity -Prompt REP01 -Objective 'fixture') -join "`n"
    Assert-Tracker ($LASTEXITCODE -eq 0 -and $composed.Contains((Join-Path $dir 'tracker.json')) -and ($composed -match '(source|fonte): dossier')) 'compositore usa resolver dichiarato'
    $composed=@(& pwsh -NoProfile -File (Join-Path $brain 'scripts/prompts.ps1') -Compose -ConfigPath $cliConfig -ProjectId test-project -Prompt REP01 -Objective 'fixture') -join "`n"
    Assert-Tracker ($LASTEXITCODE -eq 0 -and $composed.Contains('Tracker: '+(Join-Path $dir 'tracker.json'))) 'compositore Progetto usa fonte dichiarata'

    $beforeMEM02=Snapshot-Tracker $root
    foreach($selection in @(@('-Repository',$identity),@('-ProjectId','test-project'))){
        $composed=@(& pwsh -NoProfile -File (Join-Path $brain 'scripts/prompts.ps1') -Compose -ConfigPath $cliConfig -Prompt MEM02 -Objective 'prepara la migrazione' @selection) -join "`n"
        Assert-Tracker ($LASTEXITCODE -eq 0 -and $composed -match '^(CATALOGO PROMPT|PROMPT CATALOG) — MEM02' -and $composed.Contains((Join-Path $dir 'tracker.json')) -and $composed -match "modalità dell|IDE mode") ('MEM02: composizione con fonte dichiarata '+$selection[0])
    }
    foreach($invalid in @('MEM00','MEM99','INV01')){
        & pwsh -NoProfile -File (Join-Path $brain 'scripts/prompts.ps1') -Compose -ConfigPath $cliConfig -Repository $identity -Prompt $invalid -Objective fixture *> $null
        Assert-Tracker ($LASTEXITCODE -ne 0) ('MEM02: codice fuori catalogo rifiutato '+$invalid)
    }
    Assert-Tracker ((Snapshot-Tracker $root) -ceq $beforeMEM02) 'MEM02: composizione e input invalidi senza scritture o migrazioni'
    $probe=Join-Path $root 'standalone-probe.ps1';$probeConfig=Join-Path $root 'standalone-config.json'
    Put-Tracker $probeConfig (ConvertTo-SBJson $config)
    Put-Tracker $probe 'param($ModulePath,$FixtureConfig,$ManifestPath) $ErrorActionPreference="Stop"; Import-Module $ModulePath; $cfg=Get-Content -LiteralPath $FixtureConfig -Raw|ConvertFrom-Json -AsHashtable; $m=Read-SBTrackerManifest $cfg $ManifestPath; if($m.phase -ne "completed"){throw "phase"}; Invoke-SBTrackerImport -Config $cfg -ManifestPath $ManifestPath -Activate|Out-Null'
    & pwsh -NoProfile -File $probe -ModulePath (Join-Path $PSScriptRoot 'SecondBrain.TrackerImport.psm1') -FixtureConfig $probeConfig -ManifestPath $registration.manifest
    Assert-Tracker ($LASTEXITCODE -eq 0) 'modulo migrazione autonomo senza import globali impliciti'
    & pwsh -NoProfile -File (Join-Path $brain 'scripts/import-tracker.ps1') -RollbackManifest $registration.manifest -ConfigPath $cliConfig -Apply|Out-Null
    Assert-Tracker ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $source)) 'CLI recupera originale e riferimenti'
    & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'test-secondbrain-tracker-audit.ps1')
    Assert-Tracker ($LASTEXITCODE -eq 0) 'regressioni audit: concorrenza, riferimenti, grafo e spostamenti PARA'
    & { . (Join-Path $PSScriptRoot 'test-secondbrain-message-contract.ps1') }
    $success=$true
    'SUCCESS TRACKER: '+$script:checks+' verifiche'
} finally {
    if($success){
        $full=[IO.Path]::GetFullPath($root);$boundary=[IO.Path]::GetFullPath((Get-SBTestRoot)).TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
        if(!$full.StartsWith($boundary,[StringComparison]::OrdinalIgnoreCase)){throw 'Cleanup tracker fuori TEMP'}
        Write-Output ('Fixture conservata: '+$full)
    }else{'Fixture tracker conservata: '+$root}
}
