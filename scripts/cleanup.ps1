#requires -Version 7.5
<#
.SYNOPSIS
Mostra o applica la rimozione di file esplicitamente elencati in un manifest revisionato.
.DESCRIPTION
Senza Apply non modifica file. Richiede un manifest con reviewed, referencesChecked, reason e
i file con hash SHA-256. Ogni rimozione applicata ha un backup SHA-256 e metadati compatibili
con restore-managed. Non seleziona per eta o nome e non cancella checkout.
Con -ListStageRecords (sola lettura) elenca i record .stage completati in backupRoot piu vecchi di
-OlderThanDays (default 90) nel formato files del manifest; non elimina nulla. Per rimuoverli
si compila un manifest revisionato con quell elenco e lo si passa a -ManifestPath.
Con -ListRuntime (sola lettura) mostra le voci di primo livello sotto .runtime con ultima scrittura, dimensione, riferimenti
testuali e protezione (configurazione, registro postazioni, accesso), categoria (protected, evidence, backup, regenerable, working) e come si ricrea; non seleziona ne elimina nulla.
Con -ProposeRuntime (sola lettura) produce una proposta di pulizia: cartelle candidate con dimensione, eta, riferimenti e recupero (fixture di test oltre le ultime -KeepFixtures, rapporti handshake vecchi, ambiente Python delle fonti, zip di backup oltre i due piu recenti, lavoro di agent senza riferimenti).
Non e un manifest eseguibile e non rimuove nulla. Con -ProposalPath salva la proposta (nuovo file sotto .runtime, mai sovrascritto).
Con -Regenerable mostra (senza -Apply) o rimuove (con -Apply e -Authorization che cita la richiesta esplicita dell utente) le sole cartelle rigenerabili di .runtime:
fixture di test oltre le ultime -KeepFixtures e ambiente Python delle fonti (hosts/<id>/sources/python). Perimetro fisso, nessuna selezione per nome; salta cartelle
scritte negli ultimi -MinAgeMinutes minuti, che contengono percorsi di configurazione o reparse point; rifiuta con transazione pendente o sessioni di accesso attive; non segue
junction/symlink; nessun backup (si ricreano con le suite o con sources.ps1) ma un registro in .runtime/cleanup con elenco, dimensioni, esito e come ricrearle.
#>
[CmdletBinding()]
param([string]$ConfigPath,[string]$SessionId,[switch]$Apply,[string]$ManifestPath,[string]$Authorization,[switch]$ListStageRecords,[switch]$ListRuntime,[switch]$ProposeRuntime,[switch]$Regenerable,[ValidateRange(0,1000)][int]$KeepFixtures=5,[ValidateRange(0,10080)][int]$MinAgeMinutes=10,[string]$ProposalPath,[ValidateRange(1,3650)][int]$OlderThanDays=90)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1') -Force
$config=Read-SBConfiguration $ConfigPath
$operation=Enter-SBOperation $config $SessionId -ReadOnly:(!$Apply)
try {
    if($Regenerable){
        if($ManifestPath -or $ListStageRecords -or $ListRuntime -or $ProposeRuntime){throw 'Regenerable non e combinabile con ManifestPath, ListStageRecords, ListRuntime o ProposeRuntime'}
        $protectedRoots=@($config.configPath,$config.runtimeRoot,$config.coordinationRoot)
        $plan=Get-SBRegenerableRuntimeTargets $config.brainRoot $protectedRoots $KeepFixtures $MinAgeMinutes
        $summary=@{applied=$false;scope='runtime-regenerable-only';keepFixtures=$KeepFixtures;minAgeMinutes=$MinAgeMinutes;targets=@($plan.targets);skipped=@($plan.skipped);files=$plan.files;bytes=$plan.bytes}
        if(!$Apply){$summary.note='Anteprima: nessuna cartella rimossa. Con -Apply e -Authorization si rimuovono solo i target elencati.';ConvertTo-SBJson $summary;exit 0}
        if(!$Authorization){throw 'Apply richiede Authorization con riferimento alla richiesta esplicita dell utente'}
        if(Test-Path -LiteralPath (Join-Path $config.brainRoot '.runtime/para-transaction.json')){throw 'Transazione pendente: pulizia sospesa'}
        # Sessioni di altri processi; il proprietario dell'operazione corrente (writer lock) non e una sessione.
        $busy=@(Get-SBAccessStatus $config|Where-Object {$_ -is [Collections.IDictionary] -and $_.ContainsKey('sessionId') -and $_.sessionId -ne $operation.ownerSessionId -and $_.status -in @('active','unverified')})
        if($busy.Count){throw 'Sessioni di accesso attive o non verificabili: pulizia sospesa ('+$busy.Count+')'}
        $registryDir=Join-Path $config.brainRoot '.runtime/cleanup';[IO.Directory]::CreateDirectory($registryDir)|Out-Null
        $registryPath=Join-Path $registryDir ('regenerable-'+[DateTimeOffset]::Now.ToString('yyyyMMddTHHmmss')+'.json')
        $record=@{schemaVersion=1;executedAt=[DateTimeOffset]::Now.ToString('o');authorization=$Authorization;scope='runtime-regenerable-only';status='started';keepFixtures=$KeepFixtures;minAgeMinutes=$MinAgeMinutes;items=@();skipped=@($plan.skipped);failed=@()}
        $stream=[IO.FileStream]::new($registryPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
        try{$stream.Write([Text.UTF8Encoding]::new($false).GetBytes((ConvertTo-SBJson $record)));$stream.Flush($true)}finally{$stream.Dispose()}
        $removedItems=@();$failures=@()
        foreach($target in $plan.targets){
            try{Remove-SBRuntimeTree $target.path $config.brainRoot;$removedItems+=@{relative=$target.relative;kind=$target.kind;files=$target.files;bytes=$target.bytes;recovery=$target.recovery}}
            catch{$failures+=@{relative=$target.relative;error=$_.Exception.Message}}
        }
        # Le fixture possono avere registrato worktree Git: si potano solo quelli con cartella ormai assente.
        if(Test-Path -LiteralPath (Join-Path $config.brainRoot '.git')){Invoke-SBGit $config.brainRoot @('worktree','prune')|Out-Null}
        $record.items=@($removedItems);$record.failed=@($failures);$record.status=if($failures.Count){'partial'}else{'completed'}
        $record.removedBytes=0L;$record.removedFiles=0L;foreach($item in $removedItems){$record.removedBytes+=$item.bytes;$record.removedFiles+=$item.files}
        [IO.File]::WriteAllText($registryPath,(ConvertTo-SBJson $record),[Text.UTF8Encoding]::new($false))
        $summary.applied=[bool]($removedItems.Count -gt 0 -and !$failures.Count);$summary.removed=@($removedItems);$summary.failed=@($failures);$summary.registry=$registryPath;$summary.authorization=$Authorization
        if($failures.Count){$summary.status='partial'}
        ConvertTo-SBJson $summary
        exit $(if($failures.Count){1}else{0})
    }
    if($ListStageRecords -or $ListRuntime -or $ProposeRuntime){
        if((@($ListStageRecords,$ListRuntime,$ProposeRuntime)|Where-Object {$_}).Count -gt 1){throw 'ListStageRecords, ListRuntime e ProposeRuntime non sono combinabili'}
        if($Apply -or $ManifestPath){throw 'ListStageRecords e ListRuntime sono in sola lettura: non combinabili con Apply o ManifestPath'}
        # Tutti i backupRoot noti: quello corrente e quelli delle postazioni registrate sotto .runtime.
        $stageRoots=@($config.backupRoot)
        $registry=Read-SBJson (Join-Path $config.coordinationRoot 'workstations.json') @{}
        foreach($station in $registry.Values){if($station -is [Collections.IDictionary] -and $station.ContainsKey('backupRoot') -and $station.backupRoot){try{$stageRoots+=Assert-SBCentralDataPath $config.brainRoot $station.backupRoot}catch{}}}
        if($ProposeRuntime){
            $proposal=Get-SBRuntimeCleanupProposal $config.brainRoot (@($config.configPath,$config.runtimeRoot,$config.coordinationRoot)+$stageRoots) $OlderThanDays $KeepFixtures
            $json=ConvertTo-SBJson $proposal
            if($ProposalPath){
                $target=Assert-SBCentralDataPath $config.brainRoot $ProposalPath
                if([IO.Path]::GetExtension($target) -ne '.json'){throw 'La proposta si salva in un nuovo file .json'}
                [IO.Directory]::CreateDirectory((Split-Path $target))|Out-Null
                $stream=[IO.FileStream]::new($target,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
                try{$stream.Write([Text.UTF8Encoding]::new($false).GetBytes($json));$stream.Flush($true)}finally{$stream.Dispose()}
            }
            $json
            exit 0
        }
        if($ListRuntime){
            $runtimeReport=Get-SBRuntimeRetention $config.brainRoot (@($config.configPath,$config.runtimeRoot,$config.coordinationRoot)+$stageRoots) $OlderThanDays
            ConvertTo-SBJson @{applied=$false;scope='runtime-retention-preview';olderThanDays=$runtimeReport.olderThanDays;totalBytes=$runtimeReport.totalBytes;reviewable=$runtimeReport.reviewable;byCategory=$runtimeReport.byCategory;entries=$runtimeReport.entries;note='Sola lettura: nessuna voce e candidata alla rimozione automatica; la pulizia richiede un manifest revisionato di file con hash, riferimenti verificati e richiesta esplicita.'}
            exit 0
        }
        $report=Get-SBStageRetention $stageRoots $OlderThanDays
        ConvertTo-SBJson @{applied=$false;scope='stage-records-preview';olderThanDays=$report.olderThanDays;candidateCount=$report.candidates.Count;retained=$report.retained;files=@($report.candidates|ForEach-Object {@{path=$_.path;sha256=$_.sha256}});details=$report.candidates}
        exit 0
    }
    if(!$ManifestPath){throw 'Pulizia richiede un manifest locale esplicito; nessuna selezione per eta o nome'}
    $manifest=Read-SBJson (Assert-SBCentralDataPath $config.brainRoot $ManifestPath) $null
    if(!$manifest -or $manifest.schemaVersion -ne 1 -or !$manifest.reviewed -or !$manifest.referencesChecked -or !$manifest.reason){throw 'Manifest non revisionato o riferimenti non verificati'}
    if($Apply -and !$Authorization){throw 'Apply richiede Authorization con riferimento alla richiesta esplicita dell utente'}
    $protected=@($config.configPath,(Join-Path $config.runtimeRoot 'state.json'),(Join-Path $config.brainRoot '.runtime/para-transaction.json'))
    $files=@();$seen=@{}
    foreach($entry in $manifest.files){
        $path=Assert-SBCentralDataPath $config.brainRoot $entry.path
        if($path -in $protected -or $path -match '[\\/]access[\\/]' -or $path -eq [IO.Path]::GetFullPath($ManifestPath)){throw 'Dato operativo attivo protetto'}
        if($seen.ContainsKey($path) -or !(Test-Path -LiteralPath $path -PathType Leaf) -or (Get-SBFileHash $path) -ne $entry.sha256){throw 'Contenuto assente, duplicato o modificato nel manifest'}
        $seen[$path]=$true;$files+=@{path=$path;sha256=$entry.sha256}
    }
    if(Test-Path -LiteralPath (Join-Path $config.brainRoot '.runtime/para-transaction.json')){throw 'Transazione pendente: pulizia sospesa'}
    $backup=Join-Path $config.backupRoot ('cleanup-'+[guid]::NewGuid().ToString('N'))
    $removed=@();$failure=$null
    if($Apply){
        foreach($entry in $files){
            try{Remove-SBFile $entry.path (Split-Path $entry.path) $entry.sha256 $backup|Out-Null;$removed+=$entry}
            catch{$failure=@{path=$entry.path;error=$_.Exception.Message};break}
        }
    }
    # Con Apply senza file nel manifest nulla e stato applicato; un errore a meta lascia un riepilogo dei file gia rimossi.
    $summary=@{applied=[bool]($Apply -and !$failure -and $files.Count -gt 0);files=$files;removed=$removed;backup=$backup;authorization=$Authorization;scope='explicit-files-only'}
    if($failure){$summary.failed=$failure;$summary.status='partial'}
    ConvertTo-SBJson $summary
    exit $(if($failure){1}else{0})
}finally{Exit-SBOperation $operation}
