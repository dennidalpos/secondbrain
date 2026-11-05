#requires -Version 7.5
<#
.SYNOPSIS
Previews or applies removal of files explicitly listed in a reviewed manifest.
.DESCRIPTION
Without Apply, no files are changed. Requires a manifest with reviewed, referencesChecked, reason and
files with SHA-256 hashes. Each applied removal has a SHA-256 backup and metadata compatible
with restore-managed. Does not select by age or name and does not delete checkouts.
-ListStageRecords (read-only) lists completed .stage records in backupRoot older than
-OlderThanDays (default 90) in the manifest files format; deletes nothing. To remove them,
create a reviewed manifest with that list and pass it to -ManifestPath.
-ListRuntime (read-only) shows top-level .runtime entries with last write time, size, textual references,
protection (configuration, workstation registry, access), category (protected, evidence, backup, regenerable, working) and recovery instructions; selects and deletes nothing.
-ProposeRuntime (read-only) produces a cleanup proposal: candidate folders with size, age, references and recovery instructions (test fixtures beyond the latest -KeepFixtures, old handshake reports, source Python environment, backup ZIPs beyond the two latest, unreferenced agent work).
It is not an executable manifest and removes nothing. -ProposalPath saves the proposal (a new file under .runtime, never overwritten).
-RuntimeReport (read-only) produces a readable Markdown index of .runtime: entries sorted by category and size, their writers, references and recovery instructions.
-ReportPath saves it to a new .md file under .runtime (never overwritten) or regenerates .runtime/INDEX.md, a derived view with no independent data. Removes nothing.
-Migrate previews (without -Apply) or applies (with -Apply and -Authorization) the move into the nested layout hosts/<id>/repos/<repo>/<category>/<yyyyMMdd>-<slug>:
flat work/evidence/report folders, host-level evidence/report folders, duplicate repository segments, non-conforming names, backup-<date>-* folders (hosts/<id>/install-backups),
backup/* into backups/*, root *.log into logs/. Rename on the same volume only (no copies, no content deletion); writes MANIFEST.json for work/evidence/report folders;
-Repository is the repository identity of the destination segment (default github.com/dennidalpos/secondbrain). Journal in .runtime/cleanup/migrate-*.json.
-Regenerable previews (without -Apply) or removes (with -Apply and -Authorization quoting the user's explicit request) only regenerable .runtime folders:
only hosts/<current-host>/repos/<repo>/fixture|tmp folders beyond the latest -KeepFixtures, with a valid schema-1 MANIFEST.json
matching path and current owner, status closed and expiry strictly before today (the expiry day is retained).
Legacy folders, missing/invalid manifests, Python, handshake reports and empty top-level folders are excluded.
Fixed scope, no name-based selection; skips folders
written within the latest -MinAgeMinutes, containing configuration paths or reparse points; refuses pending transactions or active access sessions; does not follow
junctions/symlinks; rechecks eligibility and content hashes before each removal, retaining changed targets.
No backup (recreated with the owning suite/command), but records a .runtime/cleanup journal with entries, sizes, outcomes and recovery instructions.
#>
[CmdletBinding()]
param([string]$ConfigPath,[string]$SessionId,[switch]$Apply,[string]$ManifestPath,[string]$Authorization,[switch]$ListStageRecords,[switch]$ListRuntime,[switch]$ProposeRuntime,[switch]$RuntimeReport,[string]$ReportPath,[switch]$Regenerable,[switch]$Migrate,[string]$Repository='github.com/dennidalpos/secondbrain',[ValidateRange(0,1000)][int]$KeepFixtures=5,[ValidateRange(0,10080)][int]$MinAgeMinutes=10,[string]$ProposalPath,[ValidateRange(1,3650)][int]$OlderThanDays=90)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Host.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Add-SBMessages @{
    'cleanup.regenerable.exclusive' = @{ it = 'Regenerable e Migrate non sono combinabili con ManifestPath, ListStageRecords, ListRuntime, ProposeRuntime, RuntimeReport o tra loro'; en = 'Regenerable and Migrate cannot be combined with ManifestPath, ListStageRecords, ListRuntime, ProposeRuntime, RuntimeReport or each other' }
    'cleanup.sessions.active' = @{ it = 'Sessioni di accesso attive o non verificabili: pulizia sospesa ({0})'; en = 'Access sessions active or not verifiable: cleanup suspended ({0})' }
    'cleanup.modes.exclusive' = @{ it = 'ListStageRecords, ListRuntime, ProposeRuntime e RuntimeReport non sono combinabili'; en = 'ListStageRecords, ListRuntime, ProposeRuntime and RuntimeReport cannot be combined' }
    'cleanup.readonly.modes' = @{ it = 'ListStageRecords e ListRuntime sono in sola lettura: non combinabili con Apply o ManifestPath'; en = 'ListStageRecords and ListRuntime are read-only: not combinable with Apply or ManifestPath' }
    'cleanup.report.md' = @{ it = 'Il rapporto si salva in un file .md'; en = 'The report is saved to a .md file' }
    'cleanup.proposal.json' = @{ it = 'La proposta si salva in un nuovo file .json'; en = 'The proposal is saved to a new .json file' }
    'cleanup.manifest.required' = @{ it = 'Pulizia richiede un manifest locale esplicito; nessuna selezione per eta o nome'; en = 'Cleanup requires an explicit local manifest; no selection by age or name' }
    'cleanup.manifest.unreviewed' = @{ it = 'Manifest non revisionato o riferimenti non verificati'; en = 'Manifest not reviewed or references not verified' }
    'cleanup.apply.authorization' = @{ it = 'Apply richiede Authorization con riferimento alla richiesta esplicita dell utente'; en = 'Apply requires Authorization referencing the user''s explicit request' }
    'cleanup.data.protected' = @{ it = 'Dato operativo attivo protetto'; en = 'Active operational data protected' }
    'cleanup.manifest.content' = @{ it = 'Contenuto assente, duplicato o modificato nel manifest'; en = 'Content missing, duplicated or modified in the manifest' }
    'cleanup.transaction.pending' = @{ it = 'Transazione pendente: pulizia sospesa'; en = 'Pending transaction: cleanup suspended' }
}
# Writer busy beyond the wait limit: exit 3 (the message identifies the owner).
trap { if (Test-SBWriteDeniedError $_) { Write-SBWriteDeniedDiagnostic $_ $PSCommandPath $PSBoundParameters; exit 4 }; if (Test-SBBusyError $_) { [Console]::Error.WriteLine($_.Exception.Message); exit 3 }; break }
$config=Read-SBConfiguration $ConfigPath
$operation=Enter-SBOperation $config $SessionId -ReadOnly:(!$Apply)
try {
    if($Migrate){
        if($Regenerable -or $ManifestPath -or $ListStageRecords -or $ListRuntime -or $ProposeRuntime -or $RuntimeReport){throw (New-SBError 'cleanup.regenerable.exclusive')}
        $segment=Get-SBRuntimeRepoSegment $Repository
        $plan=Get-SBRuntimeMigrationPlan $config.brainRoot $config.workstationId $segment $MinAgeMinutes
        $summary=@{applied=$false;scope='runtime-migrate';hostId=$config.workstationId;segment=$segment;moves=@($plan.moves);skipped=@($plan.skipped);files=$plan.files;bytes=$plan.bytes}
        if(!$Apply){$summary.note='Anteprima: nessuna cartella spostata. Con -Apply e -Authorization si eseguono solo gli spostamenti elencati (rename sullo stesso volume, nessuna copia, nessuna cancellazione di contenuti).';ConvertTo-SBJson $summary;exit 0}
        if(!$Authorization){throw (New-SBError 'cleanup.apply.authorization')}
        if(Test-Path -LiteralPath (Join-Path $config.brainRoot '.runtime/para-transaction.json')){throw (New-SBError 'cleanup.transaction.pending')}
        $busy=@(Get-SBAccessStatus $config|Where-Object {$_ -is [Collections.IDictionary] -and $_.ContainsKey('sessionId') -and $_.sessionId -ne $operation.ownerSessionId -and $_.status -in @('active','unverified')})
        if($busy.Count){throw (New-SBError 'cleanup.sessions.active' @($busy.Count))}
        $registryDir=Join-Path $config.brainRoot '.runtime/cleanup';[IO.Directory]::CreateDirectory($registryDir)|Out-Null
        $registryPath=Join-Path $registryDir ('migrate-'+[DateTimeOffset]::Now.ToString('yyyyMMddTHHmmss')+'.json')
        $record=@{schemaVersion=1;executedAt=[DateTimeOffset]::Now.ToString('o');authorization=$Authorization;scope='runtime-migrate';status='started';hostId=$config.workstationId;segment=$segment;planned=@($plan.moves|ForEach-Object {@{from=$_.fromRelative;to=$_.toRelative;kind=$_.kind;files=$_.files;bytes=$_.bytes}});skipped=@($plan.skipped)}
        $stream=[IO.FileStream]::new($registryPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
        try{$stream.Write([Text.UTF8Encoding]::new($false).GetBytes((ConvertTo-SBJson $record)));$stream.Flush($true)}finally{$stream.Dispose()}
        $result=Invoke-SBRuntimeMigration $config.brainRoot $plan
        $record.moved=@($result.moved);$record.failed=@($result.failed);$record.removedEmpty=@($result.removedEmpty);$record.status=if($result.failed.Count){'partial'}else{'completed'}
        [IO.File]::WriteAllText($registryPath,(ConvertTo-SBJson $record),[Text.UTF8Encoding]::new($false))
        $summary.applied=[bool]($result.moved.Count -gt 0 -and !$result.failed.Count);$summary.moved=@($result.moved);$summary.failed=@($result.failed);$summary.removedEmpty=@($result.removedEmpty);$summary.registry=$registryPath;$summary.authorization=$Authorization
        if($result.failed.Count){$summary.status='partial'}
        ConvertTo-SBJson $summary
        exit $(if($result.failed.Count){1}else{0})
    }
    if($Regenerable){
        if($ManifestPath -or $ListStageRecords -or $ListRuntime -or $ProposeRuntime -or $RuntimeReport){throw (New-SBError 'cleanup.regenerable.exclusive')}
        $protectedRoots=@($config.configPath,$config.runtimeRoot,$config.coordinationRoot)
        # Resolve from the OS, never from a manifest or an arbitrary host configuration.
        $identity=@{HostId=(Get-SBHostId);OwnerUser=([Security.Principal.WindowsIdentity]::GetCurrent().Name -split '\\')[-1];OwnerComputer=[Environment]::MachineName}
        if($config.workstationId -cne $identity.HostId){$identity.HostId=''}
        $plan=Get-SBRegenerableRuntimeTargets $config.brainRoot $protectedRoots $KeepFixtures $MinAgeMinutes @identity
        $summary=@{applied=$false;scope='runtime-regenerable-only';keepFixtures=$KeepFixtures;minAgeMinutes=$MinAgeMinutes;targets=@($plan.targets);skipped=@($plan.skipped);files=$plan.files;bytes=$plan.bytes}
        if(!$Apply){$summary.note='Anteprima: nessuna cartella rimossa. Con -Apply e -Authorization si rimuovono solo i target elencati.';ConvertTo-SBJson $summary;exit 0}
        if(!$Authorization){throw (New-SBError 'cleanup.apply.authorization')}
        if(Test-Path -LiteralPath (Join-Path $config.brainRoot '.runtime/para-transaction.json')){throw (New-SBError 'cleanup.transaction.pending')}
        # Sessions owned by other processes; the current operation's writer-lock owner is not a session.
        $busy=@(Get-SBAccessStatus $config|Where-Object {$_ -is [Collections.IDictionary] -and $_.ContainsKey('sessionId') -and $_.sessionId -ne $operation.ownerSessionId -and $_.status -in @('active','unverified')})
        if($busy.Count){throw (New-SBError 'cleanup.sessions.active' @($busy.Count))}
        $registryDir=Join-Path $config.brainRoot '.runtime/cleanup';[IO.Directory]::CreateDirectory($registryDir)|Out-Null
        $registryPath=Join-Path $registryDir ('regenerable-'+[DateTimeOffset]::Now.ToString('yyyyMMddTHHmmss')+'.json')
        $record=@{schemaVersion=1;executedAt=[DateTimeOffset]::Now.ToString('o');authorization=$Authorization;scope='runtime-regenerable-only';status='started';keepFixtures=$KeepFixtures;minAgeMinutes=$MinAgeMinutes;items=@();skipped=@($plan.skipped);failed=@()}
        $stream=[IO.FileStream]::new($registryPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
        try{$stream.Write([Text.UTF8Encoding]::new($false).GetBytes((ConvertTo-SBJson $record)));$stream.Flush($true)}finally{$stream.Dispose()}
        $removedItems=@();$failures=@();$changed=@()
        foreach($target in $plan.targets){
            try{
                $outcome=Remove-SBRegenerableRuntimeTarget $target $config.brainRoot $protectedRoots $KeepFixtures $MinAgeMinutes @identity
                if($outcome.removed){$removedItems+=$outcome}else{$changed+=$outcome}
            }
            catch{$failures+=@{relative=$target.relative;error=$_.Exception.Message}}
        }
        # Fixtures may have registered Git worktrees: prune only those whose folder is already absent.
        if(Test-Path -LiteralPath (Join-Path $config.brainRoot '.git')){Invoke-SBGit $config.brainRoot @('worktree','prune')|Out-Null}
        $record.items=@($removedItems);$record.failed=@($failures);$record.skipped+=@($changed);$record.status=if($failures.Count -or $changed.Count){'partial'}else{'completed'}
        $record.removedBytes=0L;$record.removedFiles=0L;foreach($item in $removedItems){$record.removedBytes+=$item.bytes;$record.removedFiles+=$item.files}
        [IO.File]::WriteAllText($registryPath,(ConvertTo-SBJson $record),[Text.UTF8Encoding]::new($false))
        $summary.applied=[bool]($removedItems.Count -gt 0 -and !$failures.Count -and !$changed.Count);$summary.removed=@($removedItems);$summary.failed=@($failures);$summary.skipped+=@($changed);$summary.registry=$registryPath;$summary.authorization=$Authorization
        if($failures.Count -or $changed.Count){$summary.status='partial'}
        ConvertTo-SBJson $summary
        exit $(if($failures.Count -or $changed.Count){1}else{0})
    }
    if($ListStageRecords -or $ListRuntime -or $ProposeRuntime -or $RuntimeReport){
        if((@($ListStageRecords,$ListRuntime,$ProposeRuntime,$RuntimeReport)|Where-Object {$_}).Count -gt 1){throw (New-SBError 'cleanup.modes.exclusive')}
        if($Apply -or $ManifestPath){throw (New-SBError 'cleanup.readonly.modes')}
        # All known backupRoot locations: the current one and those of workstations registered under .runtime.
        $stageRoots=@($config.backupRoot)
        $registry=Read-SBJson (Join-Path $config.coordinationRoot 'workstations.json') @{}
        foreach($station in $registry.Values){if($station -is [Collections.IDictionary] -and $station.ContainsKey('backupRoot') -and $station.backupRoot){try{$stageRoots+=Assert-SBCentralDataPath $config.brainRoot $station.backupRoot}catch{}}}
        if($RuntimeReport){
            $index=Get-SBRuntimeIndex $config.brainRoot (@($config.configPath,$config.runtimeRoot,$config.coordinationRoot)+$stageRoots) $OlderThanDays
            if($ReportPath){
                $target=Assert-SBCentralDataPath $config.brainRoot $ReportPath
                if([IO.Path]::GetExtension($target) -ne '.md'){throw (New-SBError 'cleanup.report.md')}
                $bytes=[Text.UTF8Encoding]::new($false).GetBytes($index.markdown)
                [IO.Directory]::CreateDirectory((Split-Path $target))|Out-Null
                if($target -ieq [IO.Path]::GetFullPath((Join-Path $config.brainRoot '.runtime/INDEX.md'))){
                    # Derived view: regenerate atomically without leaving a partial file.
                    $temp=$target+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
                    try{[IO.File]::WriteAllBytes($temp,$bytes);[IO.File]::Move($temp,$target,$true)}finally{if([IO.File]::Exists($temp)){[IO.File]::Delete($temp)}}
                }else{
                    $stream=[IO.FileStream]::new($target,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
                    try{$stream.Write($bytes);$stream.Flush($true)}finally{$stream.Dispose()}
                }
            }
            $index.markdown
            exit 0
        }
        if($ProposeRuntime){
            $proposal=Get-SBRuntimeCleanupProposal $config.brainRoot (@($config.configPath,$config.runtimeRoot,$config.coordinationRoot)+$stageRoots) $OlderThanDays $KeepFixtures
            $json=ConvertTo-SBJson $proposal
            if($ProposalPath){
                $target=Assert-SBCentralDataPath $config.brainRoot $ProposalPath
                if([IO.Path]::GetExtension($target) -ne '.json'){throw (New-SBError 'cleanup.proposal.json')}
                [IO.Directory]::CreateDirectory((Split-Path $target))|Out-Null
                $stream=[IO.FileStream]::new($target,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
                try{$stream.Write([Text.UTF8Encoding]::new($false).GetBytes($json));$stream.Flush($true)}finally{$stream.Dispose()}
            }
            $json
            exit 0
        }
        if($ListRuntime){
            $retentionReport=Get-SBRuntimeRetention $config.brainRoot (@($config.configPath,$config.runtimeRoot,$config.coordinationRoot)+$stageRoots) $OlderThanDays
            ConvertTo-SBJson @{applied=$false;scope='runtime-retention-preview';olderThanDays=$retentionReport.olderThanDays;totalBytes=$retentionReport.totalBytes;reviewable=$retentionReport.reviewable;byCategory=$retentionReport.byCategory;entries=$retentionReport.entries;note='Sola lettura: nessuna voce e candidata alla rimozione automatica; la pulizia richiede un manifest revisionato di file con hash, riferimenti verificati e richiesta esplicita.'}
            exit 0
        }
        $report=Get-SBStageRetention $stageRoots $OlderThanDays
        ConvertTo-SBJson @{applied=$false;scope='stage-records-preview';olderThanDays=$report.olderThanDays;candidateCount=$report.candidates.Count;retained=$report.retained;files=@($report.candidates|ForEach-Object {@{path=$_.path;sha256=$_.sha256}});details=$report.candidates}
        exit 0
    }
    if(!$ManifestPath){throw (New-SBError 'cleanup.manifest.required')}
    $manifest=Read-SBJson (Assert-SBCentralDataPath $config.brainRoot $ManifestPath) $null
    if(!$manifest -or $manifest.schemaVersion -ne 1 -or !$manifest.reviewed -or !$manifest.referencesChecked -or !$manifest.reason){throw (New-SBError 'cleanup.manifest.unreviewed')}
    if($Apply -and !$Authorization){throw (New-SBError 'cleanup.apply.authorization')}
    $protected=@($config.configPath,(Join-Path $config.runtimeRoot 'state.json'),(Join-Path $config.brainRoot '.runtime/para-transaction.json'))
    $files=@();$seen=@{}
    foreach($entry in $manifest.files){
        $path=Assert-SBCentralDataPath $config.brainRoot $entry.path
        if($path -in $protected -or $path -match '[\\/]access[\\/]' -or $path -eq [IO.Path]::GetFullPath($ManifestPath)){throw (New-SBError 'cleanup.data.protected')}
        if($seen.ContainsKey($path) -or !(Test-Path -LiteralPath $path -PathType Leaf) -or (Get-SBFileHash $path) -ne $entry.sha256){throw (New-SBError 'cleanup.manifest.content')}
        $seen[$path]=$true;$files+=@{path=$path;sha256=$entry.sha256}
    }
    if(Test-Path -LiteralPath (Join-Path $config.brainRoot '.runtime/para-transaction.json')){throw (New-SBError 'cleanup.transaction.pending')}
    $backup=Join-Path $config.backupRoot ('cleanup-'+[guid]::NewGuid().ToString('N'))
    $removed=@();$failure=$null
    if($Apply){
        foreach($entry in $files){
            try{Remove-SBFile $entry.path (Split-Path $entry.path) $entry.sha256 $backup|Out-Null;$removed+=$entry}
            catch{$failure=@{path=$entry.path;error=$_.Exception.Message};break}
        }
    }
    # Apply with no manifest files changes nothing; a mid-operation error leaves a summary of files already removed.
    $summary=@{applied=[bool]($Apply -and !$failure -and $files.Count -gt 0);files=$files;removed=$removed;backup=$backup;authorization=$Authorization;scope='explicit-files-only'}
    if($failure){$summary.failed=$failure;$summary.status='partial'}
    ConvertTo-SBJson $summary
    exit $(if($failure){1}else{0})
}finally{Exit-SBOperation $operation}
