#requires -Version 7.5
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Para.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Tracker.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Add-SBMessages @{
    'trackerimport.registry.invalid' = @{ it = 'Registro tracker non valido'; en = 'Invalid tracker registry' }
    'trackerimport.registry.identity' = @{ it = 'Identita registro tracker divergente'; en = 'Tracker registry identity diverges' }
    'trackerimport.registry.binding' = @{ it = 'Associazione registro e manifest tracker divergente'; en = 'Tracker registry and manifest binding diverge' }
    'trackerimport.move.pending' = @{ it = 'Spostamento PARA impedito da migrazione tracker pendente: {0}; fase={1}'; en = 'PARA move blocked by a pending tracker migration: {0}; phase={1}' }
    'trackerimport.source.changed' = @{ it = 'Sorgente modificata dopo la preparazione: {0}'; en = 'Source modified after preparation: {0}' }
    'trackerimport.manifest.outside' = @{ it = 'Manifest tracker fuori backupRoot'; en = 'Tracker manifest outside backupRoot' }
    'trackerimport.manifest.invalid' = @{ it = 'Manifest tracker non valido o di altro archivio'; en = 'Tracker manifest invalid or of another archive' }
    'trackerimport.manifest.identity' = @{ it = 'Identita manifest non ammessa'; en = 'Manifest identity not allowed' }
    'trackerimport.manifest.dossier' = @{ it = 'Associazione manifest e dossier divergente'; en = 'Manifest and dossier binding diverge' }
    'trackerimport.candidate.outside' = @{ it = 'Candidato fuori manifest'; en = 'Candidate outside the manifest' }
    'trackerimport.source.scope' = @{ it = 'Sorgente manifest fuori perimetro'; en = 'Manifest source outside scope' }
    'trackerimport.checkout.diverged' = @{ it = 'Checkout sorgente manifest divergente'; en = 'Manifest source checkout diverges' }
    'trackerimport.phase.invalid' = @{ it = 'Fase migrazione tracker non valida'; en = 'Invalid tracker migration phase' }
    'trackerimport.payload.outside' = @{ it = 'Payload tracker fuori manifest'; en = 'Tracker payload outside the manifest' }
    'trackerimport.archive.source' = @{ it = 'Archivio sorgente fuori dossier'; en = 'Source archive outside the dossier' }
    'trackerimport.archive.dependencies' = @{ it = 'Archivio dipendenze fuori dossier'; en = 'Dependencies archive outside the dossier' }
    'trackerimport.history.outside' = @{ it = 'Storico sorgente fuori archivio'; en = 'Source history outside the archive' }
    'trackerimport.archive.review' = @{ it = 'Archivio review fuori dossier'; en = 'Review archive outside the dossier' }
    'trackerimport.operation.outside' = @{ it = 'Operazione manifest fuori perimetro tracker'; en = 'Manifest operation outside the tracker scope' }
    'trackerimport.area.ambiguous' = @{ it = 'Area tracker attiva non univoca'; en = 'Active tracker Area is not unique' }
    'trackerimport.import.registered' = @{ it = 'Importazione tracker gia registrata: riprendere il manifest {0}'; en = 'Tracker import already registered: resume the manifest {0}' }
    'trackerimport.source.notundeclared' = @{ it = 'La sorgente non e il tracker non dichiarato da importare'; en = 'The source is not the undeclared tracker to import' }
    'trackerimport.checkout.identity' = @{ it = 'Identita checkout sorgente divergente'; en = 'Source checkout identity diverges' }
    'trackerimport.original.missing' = @{ it = 'Tracker originale assente'; en = 'Original tracker missing' }
    'trackerimport.dependencies.outside' = @{ it = 'Storico dipendenze fuori archivio'; en = 'Dependencies history outside the archive' }
    'trackerimport.dependencies.missing' = @{ it = 'Storico dipendenze assente'; en = 'Dependencies history missing' }
    'trackerimport.target.existing' = @{ it = 'Tracker destinazione gia presente senza manifest'; en = 'Target tracker already present without a manifest' }
    'trackerimport.dossier.moved' = @{ it = 'Dossier spostato o target manifest divergente: revisione richiesta'; en = 'Dossier moved or manifest target diverges: review required' }
    'trackerimport.operation.archive' = @{ it = 'Operazione migrazione fuori archivio'; en = 'Migration operation outside the archive' }
    'trackerimport.resume.diverged' = @{ it = 'Piano di ripresa divergente: {0}'; en = 'Resume plan diverges: {0}' }
    'trackerimport.remove.sourcechanged' = @{ it = 'Sorgente modificata prima della rimozione: {0}'; en = 'Source modified before removal: {0}' }
    'trackerimport.remove.hash' = @{ it = 'Hash di rimozione diverso dalla fonte convertita: {0}'; en = 'Removal hash differs from the converted source: {0}' }
    'trackerimport.concurrent' = @{ it = 'Modifica concorrente durante migrazione: {0}'; en = 'Concurrent modification during migration: {0}' }
    'trackerimport.original.reappeared' = @{ it = 'Originale ricomparso dopo migrazione'; en = 'Original reappeared after migration' }
    'trackerimport.manifest.restored' = @{ it = 'Manifest ripristinato: preparare una nuova migrazione'; en = 'Manifest restored: prepare a new migration' }
    'trackerimport.backup.unverified' = @{ it = 'Backup tracker non verificato'; en = 'Tracker backup not verified' }
    'trackerimport.candidate.aftercopy' = @{ it = 'Candidato tracker modificato dopo copia'; en = 'Tracker candidate modified after copy' }
    'trackerimport.compare.failed' = @{ it = 'Confronto dati originali fallito'; en = 'Original data comparison failed' }
    'trackerimport.copy.notidentical' = @{ it = 'Copia storica non identica'; en = 'Historical copy not identical' }
    'trackerimport.activation.approval' = @{ it = 'Attivazione sospesa: approvazione esplicita del testo comune tracker richiesta'; en = 'Activation suspended: explicit approval of the common tracker text required' }
    'trackerimport.activation.review' = @{ it = 'Attivazione sospesa: record da revisionare {0}'; en = 'Activation suspended: records to review {0}' }
    'trackerimport.candidate.afterverify' = @{ it = 'Candidato tracker modificato dopo verifica'; en = 'Tracker candidate modified after verification' }
    'trackerimport.dossier.identity' = @{ it = 'Identita dossier cambiata'; en = 'Dossier identity changed' }
    'trackerimport.operation.diverged' = @{ it = 'Operazione migrazione divergente: {0}'; en = 'Migration operation diverges: {0}' }
    'trackerimport.restore.outside' = @{ it = 'Ripristino fuori archivio'; en = 'Restore outside the archive' }
    'trackerimport.restore.refused' = @{ it = 'Ripristino rifiutato: modifiche successive {0}'; en = 'Restore refused: later changes {0}' }
    'trackerimport.restore.payload' = @{ it = 'Payload ripristino fuori manifest'; en = 'Restore payload outside the manifest' }
    'trackerimport.restore.unverified' = @{ it = 'Payload ripristino non verificato'; en = 'Restore payload not verified' }
    'trackerimport.migration.identity' = @{ it = 'Identita registro migrazione divergente'; en = 'Migration registry identity diverges' }
    'trackerimport.backup.diverged' = @{ it = 'Backup originale divergente'; en = 'Original backup diverges' }
    'trackerimport.archive.diverged' = @{ it = 'Archivio originale divergente'; en = 'Original archive diverges' }
    'trackerimport.candidate.diverged' = @{ it = 'Candidato divergente'; en = 'Candidate diverges' }
    'trackerimport.removal.diverged' = @{ it = 'Fonte autorevole o rimozione originale divergente'; en = 'Authoritative source or original removal diverges' }
}

function Get-SBTrackerImportPayloads($Manifest) {
    @($Manifest.source,$Manifest.historySource) | Where-Object {$_}
    if($Manifest.ContainsKey('reviewSource') -and $Manifest.reviewSource){$Manifest.reviewSource}
}

function Get-SBTrackerImportPath($Config,[string]$Identity) {
    Join-Path $Config.runtimeRoot ('tracker-imports/'+(Get-SBTextHash $Identity).Substring(0,24)+'.json')
}

# Registri, manifest e archivi creati prima della V1.0 usano il prefisso tracker-migration: restano leggibili, le nuove importazioni scrivono tracker-import.
$script:SBTrackerImportRootNames=@('tracker-imports','tracker-migrations')
$script:SBTrackerImportKinds=@('tracker-import','tracker-migration')
function Get-SBTrackerImportPaths($Config,[string]$Identity) {
    $name=(Get-SBTextHash $Identity).Substring(0,24)+'.json'
    foreach($root in $script:SBTrackerImportRootNames){Join-Path $Config.runtimeRoot ($root+'/'+$name)}
}
function Get-SBTrackerImportArchives([string]$Dir,[string]$Id,[string]$Leaf) {
    foreach($prefix in @('tracker-import-','tracker-migration-')){Join-Path $Dir ('history/'+$prefix+$Id+'/'+$Leaf)}
}

function Get-SBTrackerManifestRegistrations($Config) {
    $stations=@($Config)
    $registry=Read-SBJson (Join-Path $Config.coordinationRoot 'workstations.json') @{}
    $stations+=@($registry.Values)
    $seen=@{}
    foreach($station in $stations){
        $runtime=[IO.Path]::GetFullPath($station.runtimeRoot)
        if($seen.ContainsKey($runtime)){continue};$seen[$runtime]=$true
        $stationConfig=@{}+$Config
        foreach($key in @('runtimeRoot','backupRoot','repositoryRoot')){$stationConfig[$key]=[IO.Path]::GetFullPath($station[$key])}
        foreach($rootName in $script:SBTrackerImportRootNames){
        $root=Join-Path $runtime $rootName;Assert-SBPlainPath $root
        if(!(Test-Path -LiteralPath $root)){continue}
        foreach($entry in Get-ChildItem -LiteralPath $root -File -Filter '*.json'){
            Assert-SBPlainPath $entry.FullName
            $registration=Read-SBJson $entry.FullName $null
            if(!$registration -or $registration.schemaVersion -ne 1 -or !(Test-SBRepositoryIdentity $registration.identity $Config.allowedOwners)){throw (New-SBError 'trackerimport.registry.invalid')}
            if($entry.FullName -notin @(Get-SBTrackerImportPaths $stationConfig $registration.identity)){throw (New-SBError 'trackerimport.registry.identity')}
            $path=[IO.Path]::GetFullPath($registration.manifest);Assert-SBPlainPath $path
            $boundary=$stationConfig.backupRoot.TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
            if(!$path.StartsWith($boundary,[StringComparison]::OrdinalIgnoreCase)){throw (New-SBError 'trackerimport.manifest.outside')}
            $manifestBytes=[IO.File]::ReadAllBytes($path)
            $manifestHash=Get-SBHash $manifestBytes
            $m=([Text.UTF8Encoding]::new($false,$true)).GetString($manifestBytes).TrimStart([char]0xFEFF)|ConvertFrom-Json -AsHashtable -DateKind String
            # This check also works during PARA recovery, when neither dossier location is complete.
            if(!$m -or $m.schemaVersion -ne 1 -or $m.kind -notin $script:SBTrackerImportKinds -or $m.identity -cne $registration.identity -or
               $m.brainRoot -ne $Config.brainRoot -or $m.id -notmatch '^[a-f0-9]{32}$' -or
               $path -ne (Join-Path $stationConfig.backupRoot ('tracker-'+$m.id+'/manifest.json'))){throw (New-SBError 'trackerimport.registry.binding')}
            @{path=$path;config=$stationConfig;manifest=$m;hash=$manifestHash}
        }
        }
    }
}

function Get-SBTrackerRelocationData($Config,$Area,[hashtable]$Mapping) {
    if($Area.kind -ne 'area'){return}
    $record=Read-SBJson (Join-Path $Config.brainRoot ($Area.path+'/repository.json')) @{}
    if(!$record.ContainsKey('tracker')){return}
    $resolved=Resolve-SBTracker -BrainRoot $Config.brainRoot -Identity $Area.repository -AllowedOwners $Config.allowedOwners
    # Bind the transformed data and removal precondition to the same byte snapshot.
    $snapshot=[IO.File]::ReadAllBytes($resolved.path);$previous=Get-SBHash $snapshot
    $original=([Text.UTF8Encoding]::new($false,$true)).GetString($snapshot).TrimStart([char]0xFEFF)|ConvertFrom-Json -AsHashtable -DateKind String
    $entities=@(Get-SBParaEntities $Config.brainRoot $Config.allowedOwners)
    [void](Test-SBTrackerData $original $Area.repository @($entities|Where-Object kind -eq 'area'|ForEach-Object repository) (Join-Path $PSScriptRoot '../config/tracker.schema.json') (Get-SBTrackerRelatedData $Config.brainRoot $Area.repository $entities))
    $data=Convert-SBTrackerLocation $original $Mapping $Config.brainRoot $Area.path
    $bytes=[Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $data))
    @{path=$resolved.path;previousHash=$previous;deployedHash=Get-SBHash $bytes;bytes=$bytes}
}

function Get-SBTrackerRelocationOperations($Config,[hashtable]$Mapping,[hashtable]$TrackerChanges=@{}) {
    foreach($registration in @(Get-SBTrackerManifestRegistrations $Config)){
        $m=$registration.manifest
        $next=Convert-SBParaReferences $m $Mapping $Config.brainRoot
        if((ConvertTo-SBJson $next) -ceq (ConvertTo-SBJson $m)){continue}
        [void](Read-SBTrackerManifest $registration.config $registration.path)
        if($m.phase -notin @('completed','rolled_back')){throw (New-SBError 'trackerimport.move.pending' @($m.identity, $m.phase))}
        if($TrackerChanges.ContainsKey($m.target)){
            $change=$TrackerChanges[$m.target]
            foreach($operation in $next.operations){
                # Preserve rollback eligibility only when no subsequent user edit exists.
                if($operation.path -eq $next.target -and $operation.deployedHash -eq $change.previousHash){$operation.deployedHash=$change.deployedHash}
            }
        }
        @{path=$registration.path;expected=$registration.hash;bytes=[Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $next))}
    }
}

function Assert-SBTrackerImportSources($Manifest,[switch]$AllowRemoved) {
    foreach($payload in @(Get-SBTrackerImportPayloads $Manifest)){
        $current=Get-SBFileHash $payload.path
        if($current -eq $payload.sha256){continue}
        if($AllowRemoved -and $payload -eq $Manifest.source -and $current -eq 'absent'){
            $removal=@($Manifest.operations|Where-Object { $_.path -eq $payload.path -and $_.previousHash -eq $payload.sha256 -and $_.deployedHash -eq 'absent' })
            if($removal.Count -eq 1){continue}
        }
        throw (New-SBError 'trackerimport.source.changed' @($payload.path))
    }
}

function Read-SBTrackerManifest($Config,[string]$Path) {
    $boundary=[IO.Path]::GetFullPath($Config.backupRoot).TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
    $full=[IO.Path]::GetFullPath($Path);Assert-SBPlainPath $full
    if(!$full.StartsWith($boundary,[StringComparison]::OrdinalIgnoreCase)){throw (New-SBError 'trackerimport.manifest.outside')}
    $m=Read-SBJson $full $null
    if(!$m -or $m.schemaVersion -ne 1 -or $m.kind -notin $script:SBTrackerImportKinds -or $m.brainRoot -ne $Config.brainRoot){throw (New-SBError 'trackerimport.manifest.invalid')}
    if($m.id -notmatch '^[a-f0-9]{32}$' -or !(Test-SBRepositoryIdentity $m.identity $Config.allowedOwners)){throw (New-SBError 'trackerimport.manifest.identity')}
    $dir=Resolve-SBParaPath $Config.brainRoot $m.dossier
    $record=Read-SBJson (Join-Path $dir 'repository.json') @{}
    if(!$record.ContainsKey('identity') -or $record.identity -ne $m.identity -or $m.target -ne (Join-Path $dir 'tracker.json')){throw (New-SBError 'trackerimport.manifest.dossier')}
    if($m.candidate -ne (Join-Path (Split-Path $full) 'candidate.json')){throw (New-SBError 'trackerimport.candidate.outside')}
    if($m.source.path -ne (Join-Path $dir 'tracker.md')){
        if(!(Test-SBCheckoutScope $Config (Split-Path $m.source.path))){throw (New-SBError 'trackerimport.source.scope')}
        $bindings=if($Config.ContainsKey('bindings')){$Config.bindings}else{@()}
        if((Resolve-SBBoundIdentity (Split-Path $m.source.path) $bindings) -cne $m.identity){throw (New-SBError 'trackerimport.checkout.diverged')}
    }
    if($m.phase -notin @('pending','prepared','copied','verified','references_updated','originals_removed','completed','rolled_back')){throw (New-SBError 'trackerimport.phase.invalid')}
    foreach($payload in @(Get-SBTrackerImportPayloads $m)){
        $payloadPath=[IO.Path]::GetFullPath($payload.backup)
        if(!$payloadPath.StartsWith((Split-Path $full)+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw (New-SBError 'trackerimport.payload.outside')}
        Assert-SBPlainPath $payloadPath
    }
    if($m.source.archive -notin @(Get-SBTrackerImportArchives $dir $m.id (Split-Path $m.source.path -Leaf))){throw (New-SBError 'trackerimport.archive.source')}
    if($m.historySource -and $m.historySource.archive -notin @(Get-SBTrackerImportArchives $dir $m.id 'dependency-history.md')){throw (New-SBError 'trackerimport.archive.dependencies')}
    if($m.historySource -and !([IO.Path]::GetFullPath($m.historySource.path)).StartsWith($Config.brainRoot.TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw (New-SBError 'trackerimport.history.outside')}
    if($m.ContainsKey('reviewSource') -and $m.reviewSource -and $m.reviewSource.archive -notin @(Get-SBTrackerImportArchives $dir $m.id 'review.json')){throw (New-SBError 'trackerimport.archive.review')}
    foreach($path in @($m.source.path,$m.source.archive,$m.target,$m.candidate)){Assert-SBPlainPath $path}
    foreach($operation in $m.operations){
        $relative=[IO.Path]::GetRelativePath($Config.brainRoot,$operation.path).Replace('\','/')
        $explicit=@($m.source.path,$m.source.archive,$m.target,(Join-Path $dir 'repository.json'),(Join-Path (Split-Path $m.source.archive) '.gitattributes'))
        if($m.historySource){$explicit+=$m.historySource.archive}
        if($m.ContainsKey('reviewSource') -and $m.reviewSource){$explicit+=$m.reviewSource.archive}
        $dossierRelative=[IO.Path]::GetRelativePath($dir,$operation.path).Replace('\','/')
        $dossierBoundary=$dir.TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
        $inDossier=([IO.Path]::GetFullPath($operation.path)).StartsWith($dossierBoundary,[StringComparison]::OrdinalIgnoreCase) -and $dossierRelative -notmatch '(?:^|/)(?:history|snapshots)/' -and [IO.Path]::GetExtension($operation.path) -eq '.md'
        $curated=$inDossier -or $relative -match '^(?:README\.md|docs/(?!.*(?:^|/)(?:history|snapshots)/).+\.md|02-areas/products/SecondBrain/(?:context|memory|brief)\.md|(?:01-projects|04-archives/projects)/[^/]+/para\.json)$'
        if($operation.path -notin $explicit -and !$curated){throw (New-SBError 'trackerimport.operation.outside')}
        Assert-SBPlainPath $operation.path
    }
    $m
}

function Get-SBTrackerReferenceChanges($Config,$Area,[string]$Original,[string]$Target) {
    $paths=@((Join-Path $Config.brainRoot 'README.md'))
    foreach($root in @('docs','02-areas/products/SecondBrain',$Area.path)|Sort-Object -Unique){
        $dir=Join-Path $Config.brainRoot $root
        if(Test-Path -LiteralPath $dir){$paths+=@(Get-ChildItem -LiteralPath $dir -Recurse -File -Filter '*.md'|Where-Object {$_.FullName -notmatch '[\\/](history|snapshots)[\\/]'}|ForEach-Object FullName)}
    }
    foreach($path in $paths|Sort-Object -Unique){
        if(!(Test-Path -LiteralPath $path -PathType Leaf) -or $path -eq $Original){continue}
        Assert-SBPlainPath $path;$text=Read-SBText $path;$parent=Split-Path $path
        $rewrite=[Text.RegularExpressions.MatchEvaluator]{
            param($m)
            $link=$m.Groups['target'].Value.Trim('<','>')
            if($link -match '^(?:[a-z][a-z0-9+.-]*:|#|//)'){return $m.Value}
            $parts=$link -split '(?=[#?])',2
            $resolved=[IO.Path]::GetFullPath((Join-Path $parent ([Uri]::UnescapeDataString($parts[0]))))
            if($resolved -ne $Original){return $m.Value}
            $replacement=[Uri]::EscapeUriString([IO.Path]::GetRelativePath($parent,$Target).Replace('\','/'))
            if($parts.Count -gt 1){$replacement+=$parts[1]}
            if($m.Groups['target'].Value.StartsWith('<',[StringComparison]::Ordinal)){$replacement='<'+$replacement+'>'}
            $m.Groups['prefix'].Value+$replacement+$m.Groups['suffix'].Value
        }
        # Preserve fences, inline examples and original line endings byte-for-byte.
        $fence=''
        $next=foreach($line in [regex]::Split($text,'(?<=\n)')){
            if($line -match '^\s{0,3}(`{3,}|~{3,})'){
                $mark=$Matches[1]
                if(!$fence){$fence=$mark}elseif($mark[0] -eq $fence[0] -and $mark.Length -ge $fence.Length){$fence=''}
                $line;continue
            }
            if($fence){$line;continue}
            $inline=[regex]::Matches($line,'(?<ticks>`+)(?!`)(?:(?!\k<ticks>).)*?\k<ticks>')
            $cursor=0;$result=[Text.StringBuilder]::new()
            foreach($span in $inline){
                [void]$result.Append([regex]::Replace($line.Substring($cursor,$span.Index-$cursor),'(?<prefix>!?\[[^\]]*\]\()(?<target><[^>]+>|[^\s)]+)(?<suffix>(?:\s+"[^"]*")?\))',$rewrite))
                [void]$result.Append($span.Value);$cursor=$span.Index+$span.Length
            }
            [void]$result.Append([regex]::Replace($line.Substring($cursor),'(?<prefix>!?\[[^\]]*\]\()(?<target><[^>]+>|[^\s)]+)(?<suffix>(?:\s+"[^"]*")?\))',$rewrite))
            $result.ToString()
        }
        $next=$next -join ''
        if($next -cne $text){@{path=$path;bytes=[Text.Encoding]::UTF8.GetBytes($next)}}
    }
    foreach($project in @(Get-SBParaEntities $Config.brainRoot $Config.allowedOwners)|Where-Object kind -eq 'project'){
        $changed=$false;$metadata=$project.metadata
        foreach($reference in $metadata.trackers){
            if($reference.area -ne $Area.id){continue}
            $repositoryReference=$reference.ContainsKey('repository') -and $reference.repository
            if(($repositoryReference -and $reference.path -eq (Split-Path $Original -Leaf)) -or
               (!$repositoryReference -and $reference.path -in @('tracker.md','tracker.json'))){
                $reference.path='tracker.json';[void]$reference.Remove('repository');$changed=$true
            }
        }
        if($changed){@{path=(Join-Path $Config.brainRoot ($project.path+'/para.json'));bytes=[Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $metadata))}}
    }
}

function Invoke-SBTrackerImport {
    param($Config,[string]$Identity,[string]$SourcePath,[string]$HistoryPath='',[string]$ReviewPath='',[string]$ManifestPath='',[switch]$Activate,[scriptblock]$AfterPhase)
    $entities=@(Get-SBParaEntities $Config.brainRoot $Config.allowedOwners)
    if($ManifestPath){$m=Read-SBTrackerManifest $Config $ManifestPath;$Identity=$m.identity}
    $completed=$ManifestPath -and $m.phase -eq 'completed'
    $areas=@($entities|Where-Object {$_.kind -eq 'area' -and $_.repository -eq $Identity -and ($completed -or (!$_.archived -and $_.status -eq 'active'))})
    if($areas.Count -ne 1){throw (New-SBError 'trackerimport.area.ambiguous')}
    $area=$areas[0];$dir=Resolve-SBParaPath $Config.brainRoot $area.path
    $registryPath=Get-SBTrackerImportPath $Config $Identity
    if(!$ManifestPath){
        foreach($priorPath in @(Get-SBTrackerImportPaths $Config $Identity)){
            if(!(Test-Path -LiteralPath $priorPath)){continue}
            $registration=Read-SBJson $priorPath $null
            $prior=Read-SBTrackerManifest $Config $registration.manifest
            if($prior.phase -ne 'rolled_back'){throw (New-SBError 'trackerimport.import.registered' @($registration.manifest))}
        }
        $SourcePath=[IO.Path]::GetFullPath($SourcePath);Assert-SBPlainPath $SourcePath
        $checkout=Split-Path $SourcePath
        $source=Resolve-SBTracker -BrainRoot $Config.brainRoot -Identity $Identity -CheckoutPath $checkout -AllowedOwners $Config.allowedOwners -Entities $entities
        if(!$source.path -or [IO.Path]::GetFullPath($source.path) -ne $SourcePath -or $source.declared){throw (New-SBError 'trackerimport.source.notundeclared')}
        if($source.source -eq 'repository_undeclared'){
            $bindings=if($Config.ContainsKey('bindings')){$Config.bindings}else{@()}
            if((Resolve-SBBoundIdentity $checkout $bindings) -cne $Identity){throw (New-SBError 'trackerimport.checkout.identity')}
        }
        $id=[guid]::NewGuid().ToString('N');$journal=Join-Path $Config.backupRoot ('tracker-'+$id)
        $ManifestPath=Join-Path $journal 'manifest.json'
        $archive=Join-Path $dir ('history/tracker-import-'+$id)
        $m=@{schemaVersion=1;kind='tracker-import';id=$id;identity=$Identity;brainRoot=$Config.brainRoot;dossier=$area.path;phase='pending';lastError=$null;
            source=@{path=$SourcePath;sha256=Get-SBFileHash $SourcePath;backup=(Join-Path $journal 'source.bin');archive=(Join-Path $archive ([IO.Path]::GetFileName($SourcePath)))};
            historySource=$null;candidate=(Join-Path $journal 'candidate.json');candidateHash=$null;target=(Join-Path $dir 'tracker.json');operations=@();review=@();createdAt=[DateTimeOffset]::UtcNow.ToString('o')}
        if($m.source.sha256 -eq 'absent'){throw (New-SBError 'trackerimport.original.missing')}
        if($HistoryPath){
            $HistoryPath=[IO.Path]::GetFullPath($HistoryPath);Assert-SBPlainPath $HistoryPath
            if(!$HistoryPath.StartsWith($Config.brainRoot.TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw (New-SBError 'trackerimport.dependencies.outside')}
            if(!(Test-Path -LiteralPath $HistoryPath -PathType Leaf)){throw (New-SBError 'trackerimport.dependencies.missing')}
            $m.historySource=@{path=$HistoryPath;sha256=Get-SBFileHash $HistoryPath;backup=(Join-Path $journal 'history.bin');archive=(Join-Path $archive 'dependency-history.md')}
        }
        if($ReviewPath){
            $ReviewPath=[IO.Path]::GetFullPath($ReviewPath);Assert-SBPlainPath $ReviewPath
            [void](Read-SBTrackerReview $ReviewPath $Identity $m.source.sha256)
            $m.reviewSource=@{path=$ReviewPath;sha256=Get-SBFileHash $ReviewPath;backup=(Join-Path $journal 'review.bin');archive=(Join-Path $archive 'review.json')}
        }
        if(Test-Path -LiteralPath $m.target){throw (New-SBError 'trackerimport.target.existing')}
    }
    # Tutti i percorsi riscritti restano nel checkout di SecondBrain o nel backupRoot.
    $expectedTarget=Resolve-SBParaPath $dir 'tracker.json'
    if($m.dossier -ne $area.path -or $m.target -ne $expectedTarget){throw (New-SBError 'trackerimport.dossier.moved')}
    $manifestHash=Get-SBFileHash $ManifestPath
    $save={
        $m.updatedAt=[DateTimeOffset]::UtcNow.ToString('o')
        [void](Write-SBFile $ManifestPath ([Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $m))) $manifestHash $Config.backupRoot)
        $manifestHash=Get-SBFileHash $ManifestPath
    }
    $phase={param($Name) $m.phase=$Name;. $save;if($AfterPhase){& $AfterPhase $Name}}
    # Registra prima l'operazione, cosi anche una scrittura interrotta resta recuperabile.
    $write={param([string]$Path,[byte[]]$Bytes,[switch]$Remove)
        $full=[IO.Path]::GetFullPath($Path)
        if($full -ne $m.source.path -and !$full.StartsWith($Config.brainRoot.TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw (New-SBError 'trackerimport.operation.archive')}
        Assert-SBPlainPath $full
        $op=@($m.operations|Where-Object path -eq $full)
        $deployed=if($Remove){'absent'}else{Get-SBHash $Bytes}
        if($op.Count){
            if($op.Count -ne 1 -or $op[0].deployedHash -ne $deployed){throw (New-SBError 'trackerimport.resume.diverged' @($full))}
            $op=$op[0]
        }else{
            $previous=Get-SBFileHash $full
            if($Remove -and $previous -ne $m.source.sha256){throw (New-SBError 'trackerimport.remove.sourcechanged' @($full))}
            $operationPayload=Join-Path (Split-Path $ManifestPath) ('operation-'+$m.operations.Count+'.bin')
            if($previous -ne 'absent'){[void](Write-SBFile $operationPayload ([IO.File]::ReadAllBytes($full)) 'absent' $Config.backupRoot)}
            $op=@{path=$full;previousHash=$previous;deployedHash=$deployed;backup=$operationPayload}
            $m.operations+=,$op;. $save
        }
        if($Remove -and $op.previousHash -ne $m.source.sha256){throw (New-SBError 'trackerimport.remove.hash' @($full))}
        $current=Get-SBFileHash $full
        if($current -eq $deployed){return}
        if($current -ne $op.previousHash){throw (New-SBError 'trackerimport.concurrent' @($full))}
        if($Remove){[void](Remove-SBFile $full (Split-Path $full) $current $Config.backupRoot)}
        else{[void](Write-SBFile $full $Bytes $current $Config.backupRoot)}
    }
    try {
        if($m.phase -eq 'completed'){
            [void](Resolve-SBTracker -BrainRoot $Config.brainRoot -Identity $Identity -CheckoutPath (Split-Path $m.source.path) -AllowedOwners $Config.allowedOwners)
            if(Test-Path -LiteralPath $m.source.path){throw (New-SBError 'trackerimport.original.reappeared')}
            if($m.lastError){$m.lastError=$null;. $save}
            return $ManifestPath
        }
        $m.lastError=$null
        . $save
        [void](Write-SBFile $registryPath ([Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson @{schemaVersion=1;identity=$Identity;manifest=$ManifestPath}))) (Get-SBFileHash $registryPath) $Config.backupRoot)
        if($m.phase -eq 'rolled_back'){throw (New-SBError 'trackerimport.manifest.restored')}
        if($m.phase -in @('pending','prepared','copied','verified','references_updated')){
            Assert-SBTrackerImportSources $m -AllowRemoved:($m.phase -eq 'references_updated')
        }
        if($m.phase -eq 'pending'){
            if($AfterPhase){& $AfterPhase 'pending'}
            foreach($payload in @(Get-SBTrackerImportPayloads $m)){
                if((Get-SBFileHash $payload.backup) -eq 'absent'){[void](Write-SBFile $payload.backup ([IO.File]::ReadAllBytes($payload.path)) 'absent' $Config.backupRoot)}
                if((Get-SBFileHash $payload.backup) -ne $payload.sha256){throw (New-SBError 'trackerimport.backup.unverified')}
            }
            . $phase 'prepared'
        }
        if($m.phase -eq 'prepared'){
            . $write (Join-Path (Split-Path $m.source.archive) '.gitattributes') ([Text.Encoding]::UTF8.GetBytes("* -text`n"))
            foreach($payload in @(Get-SBTrackerImportPayloads $m)){
                if((Get-SBFileHash $payload.backup) -ne $payload.sha256){throw (New-SBError 'trackerimport.backup.unverified')}
                . $write $payload.archive ([IO.File]::ReadAllBytes($payload.backup))
                if((Get-SBFileHash $payload.archive) -ne $payload.sha256){throw (New-SBError 'trackerimport.copy.notidentical')}
            }
            $commit=(Invoke-SBGit (Split-Path $m.source.path) @('rev-parse','HEAD')).output
            $arguments=@{SourcePath=$m.source.archive;Identity=$Identity;Reference=[IO.Path]::GetRelativePath($Config.brainRoot,$m.source.archive).Replace('\','/');Commit=$commit}
            if($m.historySource){$arguments.HistoryPath=$m.historySource.archive}
            if($m.ContainsKey('reviewSource') -and $m.reviewSource){$arguments.ReviewPath=$m.reviewSource.archive}
            $data=ConvertTo-SBTracker @arguments
            if($m.historySource){
                $historyRef=[IO.Path]::GetRelativePath($Config.brainRoot,$m.historySource.archive).Replace('\','/')
                foreach($task in $data.tasks){
                    foreach($p in $task.provenance){if($p.reference -in @($m.historySource.path,$m.historySource.archive)){$p.reference=$historyRef}}
                    foreach($e in $task.evidence){$e.reference=$e.reference.Replace($m.historySource.path,$historyRef).Replace($m.historySource.archive,$historyRef)}
                }
                foreach($h in $data.history){$h.reference=$historyRef}
            }
            $bytes=[Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $data))
            [void](Write-SBFile $m.candidate $bytes (Get-SBFileHash $m.candidate) $Config.backupRoot)
            $m.candidateHash=Get-SBHash $bytes
            . $phase 'copied'
        }
        if($m.phase -eq 'copied'){
            Assert-SBTrackerImportSources $m
            if((Get-SBFileHash $m.candidate) -ne $m.candidateHash){throw (New-SBError 'trackerimport.candidate.aftercopy')}
            $data=Read-SBJson $m.candidate $null
            [void](Test-SBTrackerData $data $Identity @($entities|Where-Object kind -eq 'area'|ForEach-Object repository) (Join-Path $PSScriptRoot '../config/tracker.schema.json') (Get-SBTrackerRelatedData $Config.brainRoot $Identity $entities))
            $original=if([IO.Path]::GetExtension($m.source.path) -eq '.json'){Read-SBJson $m.source.backup $null}else{@{markdown=Read-SBText $m.source.backup}}
            if((ConvertTo-SBJson $data.extensions.original) -cne (ConvertTo-SBJson $original)){throw (New-SBError 'trackerimport.compare.failed')}
            foreach($payload in @(Get-SBTrackerImportPayloads $m)){if((Get-SBFileHash $payload.archive) -ne $payload.sha256){throw (New-SBError 'trackerimport.copy.notidentical')}}
            $m.review=@($data.tasks|Where-Object status -eq 'unknown'|ForEach-Object id)
            Assert-SBTrackerImportSources $m
            . $phase 'verified'
        }
        if($m.phase -in @('verified','references_updated')){
            if((Get-SBFileHash $m.candidate) -ne $m.candidateHash){throw (New-SBError 'trackerimport.candidate.afterverify')}
            $entities=@(Get-SBParaEntities $Config.brainRoot $Config.allowedOwners)
            [void](Test-SBTrackerData (Read-SBJson $m.candidate $null) $Identity @($entities|Where-Object kind -eq 'area'|ForEach-Object repository) (Join-Path $PSScriptRoot '../config/tracker.schema.json') (Get-SBTrackerRelatedData $Config.brainRoot $Identity $entities))
        }
        if(!$Activate){return $ManifestPath}
        if(!(Test-SBTrackerPolicy $Config.brainRoot)){throw (New-SBError 'trackerimport.activation.approval')}
        if($m.review.Count){throw (New-SBError 'trackerimport.activation.review' @($m.review -join ', '))}
        if((Get-SBFileHash $m.candidate) -ne $m.candidateHash){throw (New-SBError 'trackerimport.candidate.afterverify')}
        if($m.phase -eq 'verified'){
            Assert-SBTrackerImportSources $m
            . $write $m.target ([IO.File]::ReadAllBytes($m.candidate))
            $metaPath=Join-Path $dir 'repository.json';$meta=Read-SBJson $metaPath $null
            if($meta.identity -ne $Identity){throw (New-SBError 'trackerimport.dossier.identity')}
            $meta.tracker=@{location='dossier';path='tracker.json';schemaVersion=1}
            . $write $metaPath ([Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $meta)))
            foreach($change in @(Get-SBTrackerReferenceChanges $Config $area $m.source.path $m.target)){. $write $change.path $change.bytes}
            . $phase 'references_updated'
        }
        if($m.phase -eq 'references_updated'){
            Assert-SBTrackerImportSources $m -AllowRemoved
            . $write $m.source.path @() -Remove
            . $phase 'originals_removed'
        }
        if($m.phase -eq 'originals_removed'){
            [void](Resolve-SBTracker -BrainRoot $Config.brainRoot -Identity $Identity -CheckoutPath (Split-Path $m.source.path) -AllowedOwners $Config.allowedOwners)
            foreach($op in $m.operations){if((Get-SBFileHash $op.path) -ne $op.deployedHash){throw (New-SBError 'trackerimport.operation.diverged' @($op.path))}}
            . $phase 'completed'
        }
        $ManifestPath
    } catch {$m.lastError=$_.Exception.Message;. $save;throw}
}

function Restore-SBTrackerImport($Config,[string]$ManifestPath) {
    $m=Read-SBTrackerManifest $Config $ManifestPath
    if($m.phase -eq 'rolled_back'){return}
    foreach($op in $m.operations){
        $boundary=$Config.brainRoot.TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
        if($op.path -ne $m.source.path -and !([IO.Path]::GetFullPath($op.path)).StartsWith($boundary,[StringComparison]::OrdinalIgnoreCase)){throw (New-SBError 'trackerimport.restore.outside')}
        Assert-SBPlainPath $op.path
        if((Get-SBFileHash $op.path) -notin @($op.previousHash,$op.deployedHash)){throw (New-SBError 'trackerimport.restore.refused' @($op.path))}
        if($op.previousHash -ne 'absent'){
            if(!([IO.Path]::GetFullPath($op.backup)).StartsWith((Split-Path $ManifestPath)+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw (New-SBError 'trackerimport.restore.payload')}
            Assert-SBPlainPath $op.backup
            if((Get-SBFileHash $op.backup) -ne $op.previousHash){throw (New-SBError 'trackerimport.restore.unverified')}
        }
    }
    for($i=$m.operations.Count-1;$i -ge 0;$i--){
        $op=$m.operations[$i];$current=Get-SBFileHash $op.path
        if($current -eq $op.previousHash){continue}
        if($op.previousHash -eq 'absent'){[void](Remove-SBFile $op.path $Config.brainRoot $current $Config.backupRoot)}
        else{[void](Write-SBFile $op.path ([IO.File]::ReadAllBytes($op.backup)) $current $Config.backupRoot)}
    }
    $m.phase='rolled_back';$m.lastError=$null
    [void](Write-SBFile $ManifestPath ([Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $m))) (Get-SBFileHash $ManifestPath) $Config.backupRoot)
}

function Get-SBTrackerImportIssues($Config) {
    $entries=foreach($rootName in $script:SBTrackerImportRootNames){
        $root=Join-Path $Config.runtimeRoot $rootName
        if(!(Test-Path -LiteralPath $root)){continue}
        Assert-SBPlainPath $root
        Get-ChildItem -LiteralPath $root -File -Filter '*.json'
    }
    foreach($entry in @($entries)){
        try{
            $registration=Read-SBJson $entry.FullName $null
            $m=Read-SBTrackerManifest $Config $registration.manifest
            if($registration.identity -ne $m.identity){throw (New-SBError 'trackerimport.migration.identity')}
            if($m.phase -eq 'rolled_back'){continue}
            foreach($payload in @(Get-SBTrackerImportPayloads $m)){
                if((Get-SBFileHash $payload.backup) -ne $payload.sha256){throw (New-SBError 'trackerimport.backup.diverged')}
                if($m.phase -notin @('pending','prepared') -and (Get-SBFileHash $payload.archive) -ne $payload.sha256){throw (New-SBError 'trackerimport.archive.diverged')}
            }
            if($m.candidateHash -and (Get-SBFileHash $m.candidate) -ne $m.candidateHash){throw (New-SBError 'trackerimport.candidate.diverged')}
            if($m.phase -ne 'completed'){
                'Migrazione tracker incompleta: '+$m.identity+'; fase='+$m.phase+'; manifest='+$registration.manifest+$(if($m.lastError){'; '+$m.lastError})
            }else{
                $metadata=Read-SBJson (Join-Path $Config.brainRoot ($m.dossier+'/repository.json')) @{}
                if(!$metadata.ContainsKey('tracker') -or !(Test-Path -LiteralPath $m.target -PathType Leaf) -or (Test-Path -LiteralPath $m.source.path)){throw (New-SBError 'trackerimport.removal.diverged')}
            }
        }catch{'Stato migrazione tracker non valido: '+$entry.FullName+'; '+$_.Exception.Message}
    }
}

Export-ModuleMember -Function @(
    'Get-SBTrackerImportPayloads',
    'Get-SBTrackerImportPath',
    'Get-SBTrackerImportPaths',
    'Get-SBTrackerManifestRegistrations',
    'Get-SBTrackerRelocationData',
    'Get-SBTrackerRelocationOperations',
    'Read-SBTrackerManifest',
    'Invoke-SBTrackerImport',
    'Restore-SBTrackerImport',
    'Get-SBTrackerImportIssues'
)
