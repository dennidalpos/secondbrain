#requires -Version 7.5
param([ValidateSet('All','Source','References','Graph','Para')][string]$Case='All')
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Para.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Tracker.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.TrackerImport.psm1') -Force
. (Join-Path $PSScriptRoot 'test-helpers.ps1')
$script:auditLabel='TRACKER AUDIT';$script:auditChecks=0
function Reject-Audit([scriptblock]$Action,[string]$Message,[string[]]$Codes=@()){$caught=$false;try{& $Action|Out-Null}catch{$ErrorRecord=$_;if($Codes.Count -and !@($Codes|Where-Object {Test-SBError $ErrorRecord $_}).Count){throw};$caught=$true};Assert-Audit $caught $Message}
function Put-Audit([string]$Path,[string]$Text){[IO.Directory]::CreateDirectory((Split-Path $Path))|Out-Null;[IO.File]::WriteAllText($Path,$Text,[Text.UTF8Encoding]::new($false))}
function New-AuditFixture([string]$Name){
    $base=Join-Path $root $Name;$brain=Join-Path $base 'brain';$checkout=Join-Path $base 'repos/Repo';$dir=Join-Path $brain '02-areas/products/Repo'
    [IO.Directory]::CreateDirectory((Join-Path $brain 'scripts'))|Out-Null
    Get-ChildItem -LiteralPath $PSScriptRoot -File|Copy-Item -Destination (Join-Path $brain 'scripts')
    Put-Audit (Join-Path $brain 'config/shared.json') (ConvertTo-SBJson @{schemaVersion=1;allowedOwners=@('test');excludedDirectories=@('.git')})
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../config/tracker.schema.json') -Destination (Join-Path $brain 'config/tracker.schema.json')
    [IO.Directory]::CreateDirectory((Join-Path $brain 'direttive'))|Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../direttive/prompts') -Destination (Join-Path $brain 'direttive/prompts') -Recurse
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../config/prompt-catalog.schema.json') -Destination (Join-Path $brain 'config/prompt-catalog.schema.json')
    Put-Audit (Join-Path $brain 'direttive/AGENTS.global_ide.md') "# Common`nRevisione 3.1 — 2026-10-25."
    Put-Audit (Join-Path $brain 'direttive/workstation.template.md') '<!-- secondbrain:tracker-contract:1 -->'
    Put-Audit (Join-Path $brain 'direttive/approved.json') (ConvertTo-SBJson @{authorization='fixture';files=@{'direttive/AGENTS.global_ide.md'=Get-SBFileHash (Join-Path $brain 'direttive/AGENTS.global_ide.md');'direttive/workstation.template.md'=Get-SBFileHash (Join-Path $brain 'direttive/workstation.template.md')}})
    Put-Audit (Join-Path $dir 'repository.json') (ConvertTo-SBJson @{schemaVersion=1;identity='github.com/test/repo'})
    Put-Audit (Join-Path $dir 'para.json') (ConvertTo-SBJson @{schemaVersion=1;id='repo-area';kind='area';title='Repo';status='active'})
    foreach($name in @('context.md','memory.md','brief.md')){Put-Audit (Join-Path $dir $name) '# Dossier'}
    Put-Audit (Join-Path $checkout 'AGENTS.md') '# Repo'
    $gitInit=Invoke-SBGit $checkout @('init','-q')
    if($gitInit.code -ne 0){throw ('Audit fixture Git init failed: '+$gitInit.error)}
    $gitTop=Invoke-SBGit $checkout @('rev-parse','--show-toplevel')
    if($gitTop.code -ne 0 -or !(Test-SBSamePath (@($gitTop.output)[0]) $checkout)){throw 'Audit fixture resolves a different repository; metadata may exceed MAX_PATH.'}
    $gitRemote=Invoke-SBGit $checkout @('remote','add','origin','https://github.com/test/repo.git')
    if($gitRemote.code -ne 0){throw ('Audit fixture Git remote failed: '+$gitRemote.error)}
    $runtime=Get-SBLocalRoot $brain 'fixture';$cfg=Join-Path $runtime 'workstation.json'
    Put-Audit $cfg (ConvertTo-SBJson @{schemaVersion=1;mode='portable';workstationId='fixture';runtimeRoot=$runtime;backupRoot=(Join-Path $runtime 'backups');ides=@();
        bindings=@(@{path=$checkout;identity='github.com/test/repo';remoteIdentity='github.com/test/repo';status='managed'})})
    $config=Read-SBJson $cfg $null
    $config.brainRoot=$brain;$config.configPath=$cfg;$config.repositoryRoot=$brain;$config.coordinationRoot=Join-Path $brain '.runtime/access';$config.allowedOwners=@('test');$config.excludedDirectories=@('.git');$config.sessionTimeoutMinutes=30
    @{config=$config;brain=$brain;dir=$dir;checkout=$checkout;identity='github.com/test/repo';source=(Join-Path $checkout 'legacy-tasks.json')}
}
# Short synthetic name keeps Git metadata discoverable at the actual runtime root; long payload tests are separate.
$root=Join-Path (Get-SBTestRoot) ('tracker-audit-'+[guid]::NewGuid().ToString('N').Substring(0,12))
$success=$false
try {
    if($Case -in @('All','Source')){
        foreach($checkpoint in @('prepared','copied','verified','references_updated')){
            # Keep Git metadata discoverable on Windows; the runtime root stays unchanged.
            $fixturePhase=if($checkpoint -eq 'references_updated'){'refs-updated'}else{$checkpoint}
            $f=New-AuditFixture ('source-'+$fixturePhase)
            Put-Audit $f.source '{"tasks":[{"id":"X","title":"Originale","status":"pending"}]}'
            $hash=Get-SBFileHash $f.source;$source=$f.source
            $edit={param($phase) if($phase -eq $checkpoint){Put-Audit $source '{"tasks":[{"id":"X","title":"Originale","status":"pending"},{"id":"NEW","title":"Concorrente","status":"pending"}]}'}}.GetNewClosure()
            Reject-Audit {Invoke-SBTrackerImport -Config $f.config -Identity $f.identity -SourcePath $source -Activate -AfterPhase $edit} ('modifica nella fase '+$checkpoint+' rifiutata')
            $m=Read-SBTrackerManifest $f.config (Read-SBJson (Get-SBTrackerImportPath $f.config $f.identity) $null).manifest
            Assert-Audit ((Read-SBJson $source $null).tasks.Count -eq 2 -and (Get-SBFileHash $m.source.backup) -eq $hash -and (Get-SBFileHash $m.source.archive) -eq $hash) ('entrambe le versioni preservate '+$checkpoint)
            Reject-Audit {Invoke-SBTrackerImport -Config $f.config -ManifestPath (Read-SBJson (Get-SBTrackerImportPath $f.config $f.identity) $null).manifest -Activate} ('ripresa con fonte mutata rifiutata '+$checkpoint)
            if(Test-Path -LiteralPath $m.candidate){Assert-Audit ((Read-SBJson $m.candidate $null).tasks.Count -eq 1) ('candidato derivato dalla copia verificata '+$checkpoint)}
        }
        $f=New-AuditFixture 'source-missing';Put-Audit $f.source '{"tasks":[]}'
        $manifest=Invoke-SBTrackerImport -Config $f.config -Identity $f.identity -SourcePath $f.source
        [IO.File]::Delete($f.source)
        Reject-Audit {Invoke-SBTrackerImport -Config $f.config -ManifestPath $manifest -Activate} 'assenza senza rimozione registrata rifiutata'
        $f=New-AuditFixture 'source-journal-removal';Put-Audit $f.source '{"tasks":[]}'
        $source=$f.source
        $interrupt={param($phase) if($phase -eq 'references_updated'){Set-SBWriteGuard {if(!(Test-Path -LiteralPath $source)){throw 'interruzione dopo rimozione'}}.GetNewClosure()}}.GetNewClosure()
        try{Reject-Audit {Invoke-SBTrackerImport -Config $f.config -Identity $f.identity -SourcePath $source -Activate -AfterPhase $interrupt} 'interruzione fra rimozione e salvataggio fase'}finally{Set-SBWriteGuard $null}
        $manifest=(Read-SBJson (Get-SBTrackerImportPath $f.config $f.identity) $null).manifest
        [void](Invoke-SBTrackerImport -Config $f.config -ManifestPath $manifest -Activate)
        Assert-Audit ((Read-SBTrackerManifest $f.config $manifest).phase -eq 'completed') 'assenza con rimozione registrata consente ripresa'
        Restore-SBTrackerImport $f.config $manifest
        Assert-Audit ((Read-SBJson $source $null).tasks.Count -eq 0) 'recupero dopo rimozione interrotta preserva originale'
    }
    if($Case -in @('All','References')){
        foreach($kind in @('json','markdown')){
            $f=New-AuditFixture ('references-'+$kind)
            if($kind -eq 'json'){Put-Audit $f.source '{"tasks":[]}';$relative=[IO.Path]::GetRelativePath($f.dir,$f.source).Replace('\','/');$reference=@{area='repo-area';path='legacy-tasks.json';repository=$true}}
            else{$f.source=Join-Path $f.dir 'tracker.md';Put-Audit $f.source "# Tracker`n## Attività aperte / Prossimi passi`n";$relative='tracker.md';$reference=@{area='repo-area';path='tracker.md'}}
            $project=Join-Path $f.brain '01-projects/project'
            $metadata=@{schemaVersion=1;id='project';kind='project';title='Project';status='active';areas=@('repo-area');trackers=@($reference);personal='preservare'}
            Put-Audit (Join-Path $project 'para.json') (ConvertTo-SBJson $metadata);Put-Audit (Join-Path $project 'brief.md') '# Project'
            $beforeMeta=Get-SBFileHash (Join-Path $project 'para.json')
            $text='[Tracker]('+ $relative +'#open "Attivita")'+"`r`n"+'Esempio: `[Tracker]('+ $relative +')`.'+"`r`n"+'~~~md'+"`r`n"+'[Tracker]('+ $relative +')'+"`r`n"+'~~~'+"`r`n"+'Personale: conserva questa frase.'+"`r`n"
            Put-Audit (Join-Path $f.dir 'context.md') $text
            Put-Audit (Join-Path $f.dir 'history/old.md') ('[Tracker]('+ $relative +')')
            $oldHash=Get-SBFileHash (Join-Path $f.dir 'history/old.md')
            $stop={param($phase) if($phase -eq 'references_updated'){throw 'checkpoint riferimenti'}}
            Reject-Audit {Invoke-SBTrackerImport -Config $f.config -Identity $f.identity -SourcePath $f.source -Activate -AfterPhase $stop} ('interruzione riferimenti '+$kind)
            $manifest=(Read-SBJson (Get-SBTrackerImportPath $f.config $f.identity) $null).manifest
            [void](Invoke-SBTrackerImport -Config $f.config -ManifestPath $manifest -Activate)
            $meta=Read-SBJson (Join-Path $project 'para.json') $null
            Assert-Audit ($meta.trackers[0].path -eq 'tracker.json' -and !$meta.trackers[0].ContainsKey('repository') -and $meta.personal -eq 'preservare') ('Progetto riconciliato '+$kind)
            $expected=$text.Replace('[Tracker]('+ $relative +'#open "Attivita")','[Tracker](tracker.json#open "Attivita")')
            Assert-Audit ((Read-SBText (Join-Path $f.dir 'context.md')) -ceq $expected -and (Get-SBFileHash (Join-Path $f.dir 'history/old.md')) -eq $oldHash) ('link corretto, esempi e byte personali preservati '+$kind)
            $entities=@(Get-SBParaEntities $f.brain @('test'))
            Assert-Audit (@(Get-SBCuratedReferenceIssues $f.brain $entities).Count -eq 0 -and @(Get-SBTrackerAuthorityIssues $f.brain $entities).Count -eq 0) ('controlli riferimenti dopo migrazione '+$kind)
            Put-Audit (Join-Path $f.brain 'para-index.json') (Get-SBParaIndex $f.brain @('test')).json
            $composed=@(& pwsh -NoProfile -File (Join-Path $f.brain 'scripts/prompts.ps1') -Compose -ConfigPath $f.config.configPath -ProjectId project -Prompt REP01 -Objective fixture) -join "`n"
            Assert-Audit ($LASTEXITCODE -eq 0 -and $composed.Contains('Tracker: '+(Join-Path $f.dir 'tracker.json'))) ('composizione reale del Progetto '+$kind)
            Restore-SBTrackerImport $f.config $manifest
            Assert-Audit ((Read-SBText (Join-Path $f.dir 'context.md')) -ceq $text -and (Get-SBFileHash (Join-Path $project 'para.json')) -eq $beforeMeta -and (Test-Path -LiteralPath $f.source)) ('rollback esatto dei riferimenti '+$kind)
            Put-Audit (Join-Path $f.brain 'para-index.json') (Get-SBParaIndex $f.brain @('test')).json
            $composed=@(& pwsh -NoProfile -File (Join-Path $f.brain 'scripts/prompts.ps1') -Compose -ConfigPath $f.config.configPath -ProjectId project -Prompt REP01 -Objective fixture) -join "`n"
            Assert-Audit ($LASTEXITCODE -eq 0 -and $composed.Contains('Tracker: '+$f.source)) ('composizione dopo rollback '+$kind)
        }
    }
    if($Case -in @('All','Graph')){
        foreach($scenario in @('valid','missing','cycle','foreign','changed')){
            $f=New-AuditFixture ('graph-'+$scenario)
            $relatedDir=Join-Path $f.brain '02-areas/products/Other';$relatedPath=Join-Path $relatedDir 'tracker.json'
            Put-Audit (Join-Path $relatedDir 'repository.json') (ConvertTo-SBJson @{schemaVersion=1;identity='github.com/test/other';tracker=@{location='dossier';path='tracker.json';schemaVersion=1}})
            Put-Audit (Join-Path $relatedDir 'para.json') (ConvertTo-SBJson @{schemaVersion=1;id='other-area';kind='area';title='Other';status='active'})
            foreach($name in @('context.md','memory.md','brief.md')){Put-Audit (Join-Path $relatedDir $name) '# Other'}
            Put-Audit $relatedPath '{"tasks":[{"id":"Y","title":"Other","status":"pending"}]}'
            $related=ConvertTo-SBTracker -SourcePath $relatedPath -Identity 'github.com/test/other'
            if($scenario -eq 'cycle'){$related.tasks[0].dependencies=@(@{repository=$f.identity;id='X'})}
            Put-Audit $relatedPath (ConvertTo-SBJson $related)
            $dependency=@{repository='github.com/test/other';id='Y'}
            if($scenario -eq 'missing'){$dependency.id='MISSING'}
            if($scenario -eq 'foreign'){$dependency.repository='github.com/foreign/other'}
            Put-Audit $f.source (ConvertTo-SBJson @{tasks=@(@{id='X';title='Task';status='pending';dependencies=@($dependency)})})
            $sourceHash=Get-SBFileHash $f.source
            $preview=@(& pwsh -NoProfile -File (Join-Path $f.brain 'scripts/import-tracker.ps1') -ConfigPath $f.config.configPath -Repository $f.identity -SourcePath $f.source 2>&1)
            $previewExit=$LASTEXITCODE
            Assert-Audit ($previewExit -eq $(if($scenario -in @('valid','changed')){0}else{1}) -and (Get-SBFileHash $f.source) -eq $sourceHash -and !(Test-Path -LiteralPath (Get-SBTrackerImportPath $f.config $f.identity))) ('anteprima grafo '+$scenario)
            if($scenario -in @('missing','cycle','foreign')){
                Reject-Audit {Invoke-SBTrackerImport -Config $f.config -Identity $f.identity -SourcePath $f.source -Activate} ('migrazione rifiuta grafo '+$scenario) @('tracker.dependency.missing','tracker.dependency.cycle','tracker.dependency.unmanaged')
                Assert-Audit ((Get-SBFileHash $f.source) -eq $sourceHash -and !(Read-SBJson (Join-Path $f.dir 'repository.json') @{}).ContainsKey('tracker')) ('rifiuto preserva fonte e dichiarazione '+$scenario)
                continue
            }
            $manifest=Invoke-SBTrackerImport -Config $f.config -Identity $f.identity -SourcePath $f.source
            Assert-Audit ((Read-SBTrackerManifest $f.config $manifest).phase -eq 'verified') ('preparazione grafo '+$scenario)
            if($scenario -eq 'changed'){
                $related.tasks=@();Put-Audit $relatedPath (ConvertTo-SBJson $related)
                Reject-Audit {Invoke-SBTrackerImport -Config $f.config -ManifestPath $manifest -Activate} 'dipendenza rimossa dopo preparazione rifiutata' @('tracker.dependency.missing')
                Assert-Audit ((Get-SBFileHash $f.source) -eq $sourceHash -and !(Test-Path -LiteralPath (Join-Path $f.dir 'tracker.json'))) 'rivalidazione precede attivazione'
                continue
            }
            & pwsh -NoProfile -File (Join-Path $f.brain 'scripts/import-tracker.ps1') -ConfigPath $f.config.configPath -ResumeManifest $manifest -Apply -Activate|Out-Null
            Assert-Audit ($LASTEXITCODE -eq 0 -and (Read-SBTrackerManifest $f.config $manifest).phase -eq 'completed') 'CLI attiva grafo cross-repository valido'
            & pwsh -NoProfile -File (Join-Path $f.brain 'scripts/import-tracker.ps1') -ConfigPath $f.config.configPath -ResumeManifest $manifest -Apply -Activate|Out-Null
            Assert-Audit ($LASTEXITCODE -eq 0 -and @(Get-SBTrackerImportIssues $f.config).Count -eq 0) 'ripresa grafo completato idempotente'
            Restore-SBTrackerImport $f.config $manifest
            Assert-Audit ((Get-SBFileHash $f.source) -eq $sourceHash) 'rollback grafo conserva originale'
        }
    }
    if($Case -in @('All','Para')){
        foreach($kind in @('json','markdown','rolled-back')){
            $f=New-AuditFixture ('para-'+$kind)
            if($kind -eq 'markdown'){$f.source=Join-Path $f.dir 'tracker.md';Put-Audit $f.source "# Tracker`n## Attività aperte / Prossimi passi`n"}else{Put-Audit $f.source '{"tasks":[]}'}
            $sourceHash=Get-SBFileHash $f.source
            $manifest=Invoke-SBTrackerImport -Config $f.config -Identity $f.identity -SourcePath $f.source -Activate
            if($kind -eq 'rolled-back'){Restore-SBTrackerImport $f.config $manifest}
            $m=Read-SBTrackerManifest $f.config $manifest;$candidateHash=$m.candidateHash
            if($kind -eq 'json'){
                $station=@{}+$f.config;$station.runtimeRoot=Join-Path (Split-Path $f.brain) 'station-runtime';$station.backupRoot=Join-Path (Split-Path $f.brain) 'station-backups'
                $journal=Join-Path $station.backupRoot ('tracker-'+$m.id);[IO.Directory]::CreateDirectory($station.backupRoot)|Out-Null
                Copy-Item -LiteralPath (Split-Path $manifest) -Destination $journal -Recurse
                $otherManifest=Join-Path $journal 'manifest.json';$other=Read-SBJson $otherManifest $null
                $other.candidate=Join-Path $journal 'candidate.json'
                foreach($payload in @(Get-SBTrackerImportPayloads $other)){$payload.backup=Join-Path $journal (Split-Path $payload.backup -Leaf)}
                foreach($op in $other.operations){$op.backup=Join-Path $journal (Split-Path $op.backup -Leaf)}
                Put-Audit $otherManifest (ConvertTo-SBJson $other)
                Put-Audit (Get-SBTrackerImportPath $station $f.identity) (ConvertTo-SBJson @{schemaVersion=1;identity=$f.identity;manifest=$otherManifest})
                Put-Audit (Join-Path $f.config.coordinationRoot 'workstations.json') (ConvertTo-SBJson @{other=@{identity='other';runtimeRoot=$station.runtimeRoot;backupRoot=$station.backupRoot;repositoryRoot=$station.repositoryRoot}})
            }
            $meta=Read-SBJson (Join-Path $f.dir 'para.json') $null;$meta.status='retired';Put-Audit (Join-Path $f.dir 'para.json') (ConvertTo-SBJson $meta)
            $para=Join-Path $f.brain 'scripts/para.ps1'
            & pwsh -NoProfile -File $para -ConfigPath $f.config.configPath -Archive -EntityId repo-area -BackupRoot $f.config.backupRoot|Out-Null
            Assert-Audit ($LASTEXITCODE -eq 0 -and !(Test-Path -LiteralPath $f.dir)) ('CLI archivia Area migrata '+$kind)
            $m=Read-SBTrackerManifest $f.config $manifest
            Assert-Audit ($m.dossier -eq '04-archives/areas/repo-area' -and $m.candidateHash -eq $candidateHash -and @(Get-SBTrackerImportIssues $f.config).Count -eq 0) ('manifest e Check coerenti in archivio '+$kind)
            if($kind -eq 'json'){Assert-Audit ((Read-SBTrackerManifest $station $otherManifest).dossier -eq $m.dossier -and @(Get-SBTrackerImportIssues $station).Count -eq 0) 'manifest della seconda postazione spostato nella stessa transazione'}
            if($kind -ne 'rolled-back'){
                [void](Invoke-SBTrackerImport -Config $f.config -ManifestPath $manifest -Activate)
                Assert-Audit ((Get-SBFileHash $m.source.archive) -eq $sourceHash) ('ripresa completed archiviata e originale esatto '+$kind)
            }
            & pwsh -NoProfile -File $para -ConfigPath $f.config.configPath -Check|Out-Null
            Assert-Audit ($LASTEXITCODE -eq 0) ('CLI Check dopo Archive '+$kind)
            & pwsh -NoProfile -File $para -ConfigPath $f.config.configPath -Restore -EntityId repo-area -BackupRoot $f.config.backupRoot|Out-Null
            Assert-Audit ($LASTEXITCODE -eq 0) ('CLI ripristina Area su percorso diverso '+$kind)
            $m=Read-SBTrackerManifest $f.config $manifest
            Assert-Audit ($m.dossier -eq '02-areas/products/repo-area' -and @(Get-SBTrackerImportIssues $f.config).Count -eq 0) ('manifest e Check coerenti dopo Restore '+$kind)
            if($kind -eq 'json'){Assert-Audit ((Read-SBTrackerManifest $station $otherManifest).dossier -eq $m.dossier -and @(Get-SBTrackerImportIssues $station).Count -eq 0) 'manifest della seconda postazione ripristinato'}
            if($kind -ne 'rolled-back'){
                [void](Invoke-SBTrackerImport -Config $f.config -ManifestPath $manifest -Activate)
                $targetText=Read-SBText $m.target;Put-Audit $m.target ($targetText+"`n")
                Reject-Audit {Restore-SBTrackerImport $f.config $manifest} ('rollback rifiuta modifiche dopo spostamento '+$kind) @('trackerimport.restore.refused')
                Put-Audit $m.target $targetText
                Restore-SBTrackerImport $f.config $manifest
            }
            $m=Read-SBTrackerManifest $f.config $manifest
            Assert-Audit ($m.phase -eq 'rolled_back' -and (Get-SBFileHash $m.source.path) -eq $sourceHash) ('rollback esatto nel percorso corrente '+$kind)
        }
        $f=New-AuditFixture 'para-pending';Put-Audit $f.source '{"tasks":[]}'
        $manifest=Invoke-SBTrackerImport -Config $f.config -Identity $f.identity -SourcePath $f.source
        $before=Get-SBFileHash $manifest
        $meta=Read-SBJson (Join-Path $f.dir 'para.json') $null;$meta.status='retired';Put-Audit (Join-Path $f.dir 'para.json') (ConvertTo-SBJson $meta)
        & pwsh -NoProfile -File (Join-Path $f.brain 'scripts/para.ps1') -ConfigPath $f.config.configPath -Archive -EntityId repo-area -BackupRoot $f.config.backupRoot *> $null
        Assert-Audit ($LASTEXITCODE -ne 0 -and (Test-Path -LiteralPath $f.dir) -and !(Test-Path -LiteralPath (Join-Path $f.brain '04-archives/areas/repo-area')) -and (Get-SBFileHash $manifest) -eq $before) 'migrazione pendente impedisce ogni spostamento'
        $f=New-AuditFixture 'para-interrupted';Put-Audit $f.source '{"tasks":[]}'
        $manifest=Invoke-SBTrackerImport -Config $f.config -Identity $f.identity -SourcePath $f.source -Activate
        $before=Get-SBFileHash $manifest;$destination='04-archives/areas/repo-area';$target=Join-Path $f.brain $destination
        $ops=@()
        foreach($file in Get-ChildItem -LiteralPath $f.dir -Recurse -File -Force){
            $relative=[IO.Path]::GetRelativePath($f.dir,$file.FullName)
            $ops+=@{path=(Join-Path $target $relative);expected='absent';bytes=[IO.File]::ReadAllBytes($file.FullName)}
            $ops+=@{path=$file.FullName;expected=(Get-SBFileHash $file.FullName);bytes=$null}
        }
        $mapping=@{'02-areas/products/Repo'=$destination}
        $ops+=@(Get-SBParaReferenceOperations $f.config $mapping)
        $ops+=@(Get-SBTrackerRelocationOperations $f.config $mapping)
        $allowed=@(Get-SBParaRuntimePaths $f.config)
        Set-SBWriteGuard {if((Get-SBFileHash $manifest) -ne $before){throw 'interruzione dopo spostamento manifest'}}.GetNewClosure()
        try{Reject-Audit {Invoke-SBParaTransaction $ops $f.config.backupRoot $f.brain $allowed} 'transazione interrotta dopo aggiornamento manifest' @('para.transaction.interrupted')}finally{Set-SBWriteGuard $null}
        $marker=Read-SBJson (Join-Path $f.brain '.runtime/para-transaction.json') $null
        Assert-Audit ($marker -and (Read-SBTrackerManifest $f.config $manifest).dossier -eq $destination) 'journal preserva lo spostamento incompleto'
        $targetContext=Join-Path $target 'context.md';$original=Read-SBText $targetContext;Put-Audit $targetContext ($original+' personale')
        Reject-Audit {Restore-SBParaTransaction $marker.manifest $f.brain $f.config.backupRoot @(Get-SBParaRuntimePaths $f.config)} 'recupero PARA rifiuta modifiche successive' @('para.restore.refused')
        Assert-Audit ((Get-SBFileHash $manifest) -ne $before -and (Read-SBText $targetContext).EndsWith('personale')) 'rifiuto del recupero non modifica manifest o dati personali'
        Put-Audit $targetContext $original
        & pwsh -NoProfile -File (Join-Path $f.brain 'scripts/recover.ps1') -ManifestPath $marker.manifest -ConfigPath $f.config.configPath -Apply|Out-Null
        Assert-Audit ($LASTEXITCODE -eq 0 -and (Get-SBFileHash $manifest) -eq $before -and (Test-Path -LiteralPath (Join-Path $f.dir 'repository.json')) -and !(Test-Path -LiteralPath (Join-Path $f.brain '.runtime/para-transaction.json'))) 'CLI recupera insieme dossier e manifest esterno'
        Assert-Audit (@(Get-SBTrackerImportIssues $f.config).Count -eq 0) 'Check coerente dopo recupero transazionale'
    }
    $success=$true
    'SUCCESS TRACKER AUDIT: '+$script:auditChecks+' verifiche; runtime='+$PSVersionTable.PSVersion
} finally {
    if($success){
        $full=[IO.Path]::GetFullPath($root);$boundary=[IO.Path]::GetFullPath((Get-SBTestRoot)).TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
        if(!$full.StartsWith($boundary,[StringComparison]::OrdinalIgnoreCase)){throw 'Pulizia audit fuori TEMP'}
        if(Test-Path -LiteralPath $full){Write-Output ('Fixture conservata: '+$full)}
    }else{'Fixture audit conservata: '+$root}
}
