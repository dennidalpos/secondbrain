#requires -Version 7.5
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Para.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Host.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Add-SBMessages @{
    'tracker.update.empty' = @{ it = 'Specificare almeno un campo da aggiornare: -Status, -Priority, -Execution, -DependsOn, -Stream, -Awaiting, -ReadRepositories, -Requires o -StateReason'; en = 'Specify at least one field to update: -Status, -Priority, -Execution, -DependsOn, -Stream, -Awaiting, -ReadRepositories, -Requires or -StateReason' }
    'tracker.priority.invalid' = @{it='Priorità non valida: usare P0, P1, P2, P3 o P4';en='Invalid priority: use P0, P1, P2, P3 or P4'}
    'tracker.execution.invalid' = @{ it = 'Modalità di esecuzione non valida: usare autonomous, user_required o unspecified'; en = 'Invalid execution mode: use autonomous, user_required or unspecified' }
    'tracker.readrepositories.invalid' = @{ it = 'Identità di repository non valida per la lettura: {0}; usare host/owner/repo'; en = 'Invalid repository identity for reading: {0}; use host/owner/repo' }
    'tracker.requires.invalid' = @{it='Capacità richiesta non valida: {0} (ammessi: {1})';en='Invalid required capability: {0} (allowed: {1})'}
    'tracker.closure.advice' = @{ it = 'Aggiornare memoria e contesto, proporre il riepilogo minimo (memoria, storico o salta), poi eseguire Sync e Check.'; en = 'Update memory and context, offer a minimal summary (memory, history or skip), then run Sync and Check.' }
    'tracker.closure.invalid' = @{ it = 'Metadati di chiusura del tracker non validi: correggere extensions.closure o rimuoverlo'; en = 'Invalid tracker closure metadata: fix extensions.closure or remove it' }
    'tracker.history.note' = @{ it = 'Nota originale: {0}'; en = 'Original note: {0}' }
    'tracker.history.dependencies' = @{ it = 'Esiti storici espliciti usati per risolvere le dipendenze'; en = 'Explicit historical outcomes used to resolve dependencies' }
    'tracker.history.numbered' = @{ it = 'Numerazione retroattiva: {0} task (archivio e attivi) in ordine cronologico; originali conservati per hash.'; en = 'Retroactive numbering: {0} tasks (archived and active) in chronological order; originals preserved by hash.' }
    'tracker.reason.numbered' = @{ it = 'Tracker gia numerato'; en = 'Tracker already numbered' }
    'tracker.history.snapshot' = @{ it = 'Originale storico non coerente: {0}; ripristinarlo dal backup o rigenerare lo storico'; en = 'History original does not match: {0}; restore it from the backup or regenerate the history' }
    'tracker.seq.duplicate' = @{ it = 'Numero progressivo duplicato nel tracker {0}: {1}; assegnare numeri univoci'; en = 'Duplicate sequence number in tracker {0}: {1}; assign unique numbers' }
    'tracker.title.prefix' = @{ it = 'Titolo senza prefisso #{0}: {1}; eseguire knowledge.ps1 -RenumberTasks'; en = 'Title without prefix #{0}: {1}; run knowledge.ps1 -RenumberTasks' }
    'tracker.lastseq.type' = @{ it = 'extensions.lastSeq deve essere un intero: correggere il valore nel tracker'; en = 'extensions.lastSeq must be an integer: fix the value in the tracker' }
    'tracker.seq.beyond' = @{ it = 'Numero progressivo {0} oltre extensions.lastSeq ({1}): aggiornare lastSeq'; en = 'Sequence number {0} beyond extensions.lastSeq ({1}): update lastSeq' }
    'tracker.schema.invalid' = @{ it = 'Tracker non conforme allo schema v1: confrontarlo con config/tracker.schema.json'; en = 'Tracker does not conform to schema v1: compare it with config/tracker.schema.json' }
    'tracker.identity.diverged' = @{ it = 'Identita tracker divergente: verificare repository.json del dossier'; en = 'Tracker identity mismatch: check the dossier repository.json' }
    'tracker.date.invalid' = @{ it = 'Data tracker non valida: usare il formato yyyy-MM-dd'; en = 'Invalid tracker date: use the yyyy-MM-dd format' }
    'tracker.related.schema' = @{ it = 'Tracker correlato non conforme allo schema v1: {0}'; en = 'Related tracker does not conform to schema v1: {0}' }
    'tracker.identity.unmanaged' = @{ it = 'Tracker di identita non gestita: attivare il repository con secondbrain.ps1 -Setup o -AddRepo'; en = 'Tracker of an unmanaged identity: activate the repository with secondbrain.ps1 -Setup or -AddRepo' }
    'tracker.id.duplicate' = @{ it = 'ID tracker duplicato: {0}; renderlo univoco'; en = 'Duplicate tracker ID: {0}; make it unique' }
    'tracker.dependency.unmanaged' = @{ it = 'Dipendenza da identita non gestita: {0}; rimuovere la dipendenza o attivare quel repository'; en = 'Dependency on an unmanaged identity: {0}; remove the dependency or activate that repository' }
    'tracker.dependency.missing' = @{ it = 'Dipendenza tracker inesistente o non verificabile: {0}; correggere l''ID o rimuovere la dipendenza'; en = 'Tracker dependency missing or not verifiable: {0}; fix the ID or remove the dependency' }
    'tracker.dependency.cycle' = @{ it = 'Ciclo nelle dipendenze tracker: {0}; rimuovere una delle dipendenze'; en = 'Cycle in tracker dependencies: {0}; remove one of the dependencies' }
    'tracker.related.declaration' = @{ it = 'Dichiarazione tracker correlato non valida: {0}'; en = 'Invalid related tracker declaration: {0}' }
    'tracker.related.missing' = @{ it = 'Tracker correlato dichiarato assente: {0}'; en = 'Declared related tracker missing: {0}' }
    'tracker.related.identity' = @{ it = 'Identita tracker correlato divergente'; en = 'Related tracker identity mismatch' }
    'tracker.identity.area' = @{ it = 'Identita tracker non associata a una sola Area: {0}'; en = 'Tracker identity not bound to exactly one Area: {0}' }
    'tracker.dossier.identity' = @{ it = 'Identita del dossier tracker divergente'; en = 'Tracker dossier identity mismatch' }
    'tracker.declaration.invalid' = @{ it = 'Dichiarazione tracker non valida: {0}'; en = 'Invalid tracker declaration: {0}' }
    'tracker.declared.missing' = @{ it = 'Tracker dichiarato assente: {0}'; en = 'Declared tracker missing: {0}' }
    'tracker.greenfield.declaration.required' = @{ it = 'Il dossier greenfield di {0} richiede un tracker dichiarato di schema 1'; en = 'The greenfield dossier for {0} requires a declared schema 1 tracker' }
    'tracker.policy.unapproved' = @{ it = 'Contratto tracker non approvato: {0}'; en = 'Tracker contract not approved: {0}' }
    'tracker.review.source' = @{ it = 'Review tracker di altra identita o sorgente divergente'; en = 'Tracker review of another identity or diverging source' }
    'tracker.review.tasks' = @{ it = 'Review tracker senza elenco task'; en = 'Tracker review without task list' }
    'tracker.review.id' = @{ it = 'ID review tracker mancante o duplicato'; en = 'Tracker review ID missing or duplicate' }
    'tracker.review.field' = @{ it = 'Campo review tracker non riconosciuto: {0}'; en = 'Unrecognized tracker review field: {0}' }
    'tracker.review.reason' = @{ it = 'Motivazione review tracker obbligatoria'; en = 'Tracker review reason is required' }
    'tracker.review.status' = @{ it = 'Stato review tracker non valido'; en = 'Invalid tracker review status' }
    'tracker.review.dependencies' = @{ it = 'Dipendenze review tracker non valide'; en = 'Invalid tracker review dependencies' }
    'tracker.review.prerequisites' = @{ it = 'Prerequisiti review tracker non validi'; en = 'Invalid tracker review prerequisites' }
    'tracker.original.object' = @{ it = 'Il tracker JSON originale deve essere un oggetto: correggere il file sorgente'; en = 'The original JSON tracker must be an object: fix the source file' }
    'tracker.collection.invalid' = @{ it = 'Collezione tracker non valida: {0}; usare tasks o un nome dichiarato'; en = 'Invalid tracker collection: {0}; use tasks or a declared name' }
    'tracker.markdown.format' = @{ it = 'Formato Markdown non riconosciuto alla riga {0}: conversione esplicita richiesta'; en = 'Unrecognized Markdown format at line {0}: explicit conversion required' }
    'tracker.original.format' = @{ it = 'Formato tracker originale non supportato: convertirlo in JSON o Markdown a tabella'; en = 'Unsupported original tracker format: convert it to JSON or a Markdown table' }
    'tracker.id.collision' = @{ it = 'Collisione ID: risoluzione esplicita richiesta per {0}'; en = 'ID collision: explicit resolution required for {0}' }
    'tracker.review.unknown' = @{ it = 'Task review tracker inesistente: {0}'; en = 'Tracker review task does not exist: {0}' }
    'tracker.review.reconcile' = @{ it = 'Review tracker richiede riconciliazione esplicita delle dipendenze: {0}'; en = 'Tracker review requires explicit dependency reconciliation: {0}' }
    'tracker.host.backuproot' = @{ it = 'Configurazione host senza backupRoot: {0}'; en = 'Host configuration without backupRoot: {0}' }
    'tracker.write.foreign' = @{ it = 'Scrittura rifiutata: il tracker di ''{0}'' non appartiene al repository in lavoro ''{1}'''; en = 'Write refused: the tracker of ''{0}'' does not belong to the working repository ''{1}''' }
    'tracker.file.missing' = @{ it = 'File tracker inesistente: {0}; controllare il percorso o la dichiarazione in repository.json'; en = 'Tracker file does not exist: {0}; check the path or the declaration in repository.json' }
    'tracker.identity.required' = @{ it = 'Identity o Path obbligatorio: indicare uno dei due'; en = 'Identity or Path is required: give one of them' }
    'tracker.dossier.declaration' = @{ it = 'Dossier senza dichiarazione tracker: {0}; dichiarare il tracker in repository.json'; en = 'Dossier without tracker declaration: {0}; declare the tracker in repository.json' }
    'tracker.schema.version' = @{ it = 'Schema tracker non supportato (atteso v1): impostare schemaVersion a 1'; en = 'Unsupported tracker schema (expected v1): set schemaVersion to 1' }
    'tracker.status.invalid' = @{ it = 'Stato non valido: {0}. Valori ammessi: todo, in_progress, blocked, done, cancelled, unknown'; en = 'Invalid status: {0}. Allowed values: todo, in_progress, blocked, done, cancelled, unknown' }
    'tracker.task.notfound' = @{ it = 'Task non trovato nel tracker: {0}. Elenca i task con knowledge.ps1 -Tasks'; en = 'Task not found in tracker: {0}. List tasks with knowledge.ps1 -Tasks' }
    'tracker.unnumbered' = @{ it = 'Tracker non numerato ({0} task senza seq): eseguire prima knowledge.ps1 -RenumberTasks'; en = 'Unnumbered tracker ({0} tasks without seq): run knowledge.ps1 -RenumberTasks first' }
    'tracker.acceptance.required' = @{ it = 'Almeno un criterio di accettazione obbligatorio: indicare -Acceptance'; en = 'At least one acceptance criterion is required: give -Acceptance' }
    'tracker.task.exists' = @{ it = 'ID task gia presente: {0}; scegliere un altro ID o omettere -TaskId'; en = 'Task ID already present: {0}; choose another ID or omit -TaskId' }
    'tracker.id.invalid' = @{ it = 'ID task non valido: {0}. Usare da 3 a 80 caratteri (lettere, cifre, punto, trattino, sottolineatura), iniziando con una lettera o una cifra, oppure omettere -TaskId'; en = 'Invalid task ID: {0}. Use 3 to 80 characters (letters, digits, dot, hyphen, underscore) starting with a letter or digit, or omit -TaskId' }
    'tracker.title.invalid' = @{ it = 'Titolo non valido: deve contenere almeno una lettera. Descrivere il task con una frase'; en = 'Invalid title: it must contain at least one letter. Describe the task in a sentence' }
    'tracker.provenance.missing' = @{ it = 'Provenienza inesistente: {0}. Indica un file esistente del dossier (percorso relativo)'; en = 'Provenance does not exist: {0}. Give an existing dossier file (relative path)' }
    'tracker.archive.identity' = @{ it = 'Archivio tracker di identita divergente: verificare il file di archivio del dossier'; en = 'Tracker archive of a diverging identity: check the dossier archive file' }
    'tracker.numbering.partial' = @{ it = 'Numerazione parziale ({0} su {1}): riconciliazione esplicita richiesta'; en = 'Partial numbering ({0} of {1}): explicit reconciliation required' }
}

function Test-SBTrackerPolicy([string]$BrainRoot) {
    (Test-SBApproval $BrainRoot) -and (Read-SBText (Join-Path $BrainRoot 'direttive/workstation.template.md')).Contains('<!-- secondbrain:tracker-contract:1 -->')
}

# Sequential numbering: unique seq, consistent "#NNN - " title, extensions.lastSeq never below the maximum (numbers are never reused).
$script:SBTrackerSeqSeparator=' '+[char]0x2014+' '
function Format-SBTrackerSeqTitle([int]$Seq,[string]$Title) {
    '#'+$Seq.ToString('000')+$script:SBTrackerSeqSeparator+($Title -replace ('^#\d+'+[regex]::Escape($script:SBTrackerSeqSeparator)),'')
}
function Get-SBTrackerLastSeq($Document) {
    $last=0
    if($Document['extensions'] -is [Collections.IDictionary] -and $Document.extensions.ContainsKey('lastSeq')){$last=[int]$Document.extensions.lastSeq}
    foreach($task in $Document.tasks){if($task -is [Collections.IDictionary] -and $task.ContainsKey('seq') -and [int]$task.seq -gt $last){$last=[int]$task.seq}}
    $last
}
function Assert-SBTrackerSequence($Document) {
    $seen=@{}
    foreach($task in $Document.tasks){
        if($task -isnot [Collections.IDictionary] -or !$task.ContainsKey('seq')){continue}
        $seq=[int]$task.seq
        if($seen.ContainsKey($seq)){throw (New-SBError 'tracker.seq.duplicate' @($Document.repository,$seq))}
        $seen[$seq]=$true
        if(!([string]$task.title).StartsWith('#'+$seq.ToString('000')+$script:SBTrackerSeqSeparator)){throw (New-SBError 'tracker.title.prefix' @($seq.ToString('000'),$task.id))}
    }
    if($Document.extensions -is [Collections.IDictionary] -and $Document.extensions.ContainsKey('lastSeq')){
        $last=$Document.extensions.lastSeq
        if($last -isnot [int] -and $last -isnot [long]){throw (New-SBError 'tracker.lastseq.type')}
        foreach($seq in $seen.Keys){if($seq -gt $last){throw (New-SBError 'tracker.seq.beyond' @($seq,$last))}}
    }
}

function Test-SBTrackerData($Data, [string]$Identity, [string[]]$ManagedIdentities, [string]$SchemaPath, $RelatedTrackers=@{}, [hashtable]$Archives=@{}) {
    $json=ConvertTo-SBJson $Data
    if (!(Test-Json -Json $json -SchemaFile $SchemaPath -ErrorAction SilentlyContinue)) { throw (New-SBError 'tracker.schema.invalid') }
    if ($Data.repository -cne $Identity) { throw (New-SBError 'tracker.identity.diverged') }
    $date=[DateTimeOffset]::MinValue
    if (![DateTimeOffset]::TryParse($Data.updatedAt,[ref]$date)) { throw (New-SBError 'tracker.date.invalid') }
    $nodes=@{}
    foreach($document in @($Data)+@($RelatedTrackers.Values)) {
        if(!(Test-Json -Json (ConvertTo-SBJson $document) -SchemaFile $SchemaPath -ErrorAction SilentlyContinue)){
            $identityLabel=if($document.ContainsKey('repository')){$document.repository}else{'identita assente'}
            throw (New-SBError 'tracker.related.schema' @($identityLabel))
        }
        if ($document.repository -notin $ManagedIdentities) { throw (New-SBError 'tracker.identity.unmanaged') }
        $graph=if($Archives.ContainsKey($document.repository)){Join-SBTrackerArchive $document $Archives[$document.repository]}else{$document}
        Assert-SBTrackerSequence $graph
        foreach($task in $graph.tasks) {
            $key=$document.repository+'#'+$task.id
            if ($nodes.ContainsKey($key)) { throw (New-SBError 'tracker.id.duplicate' @($key)) }
            $nodes[$key]=@{task=$task;repository=$document.repository}
        }
    }
    $edges=@{}
    foreach($key in @($nodes.Keys)) {
        $edges[$key]=@()
        foreach($dependency in $nodes[$key].task['dependencies']) {
            $repository=if($dependency.ContainsKey('repository')){$dependency.repository}else{$nodes[$key].repository}
            if ($repository -notin $ManagedIdentities) { throw (New-SBError 'tracker.dependency.unmanaged' @($repository)) }
            $target=$repository+'#'+$dependency.id
            if (!$nodes.ContainsKey($target)) { throw (New-SBError 'tracker.dependency.missing' @($target)) }
            $edges[$key]+=$target
        }
    }
    $visited=@{};$active=@{}
    function Visit-SBTrackerNode([string]$Key) {
        if($active.ContainsKey($Key)){throw (New-SBError 'tracker.dependency.cycle' @($Key))}
        if($visited.ContainsKey($Key)){return}
        $active[$Key]=$true
        foreach($target in $edges[$Key]){Visit-SBTrackerNode $target}
        $active.Remove($Key);$visited[$Key]=$true
    }
    foreach($key in @($nodes.Keys)){Visit-SBTrackerNode $key}
    $true
}

function Read-SBTrackerArchive([string]$TrackerPath,[string]$Identity) {
    $path=Resolve-SBParaPath (Split-Path $TrackerPath) 'history/tracker-archive.json'
    if(!(Test-Path -LiteralPath $path -PathType Leaf)){
        return @{path=$path;hash='absent';changed=$false;data=@{schemaVersion=1;repository=$Identity;tasks=@()}}
    }
    $bytes=[IO.File]::ReadAllBytes($path)
    $data=[Text.Encoding]::UTF8.GetString($bytes).TrimStart([char]0xFEFF)|ConvertFrom-Json -AsHashtable -DateKind String
    if($data.schemaVersion -ne 1 -or $data.repository -cne $Identity -or $data.tasks -isnot [array] -or @($data.tasks|Where-Object {$_ -isnot [Collections.IDictionary] -or !$_['id'] -or $_['status'] -notin @('done','cancelled')}).Count){throw (New-SBError 'tracker.archive.identity')}
    @{path=$path;hash=(Get-SBHash $bytes);changed=$false;data=$data}
}

function Join-SBTrackerArchive($Data,$Archive) {
    $combined=@{}+$Data
    $combined.tasks=@($Data.tasks)+@($Archive.tasks)
    $combined
}

function Get-SBTrackerRelatedData([string]$BrainRoot,[string]$Identity,$Entities,[hashtable]$Archives) {
    # Read once without calling the resolver recursively; the validator visits the whole graph.
    $related=@{}
    foreach($other in $Entities|Where-Object {(Test-SBRepoDossier $_) -and $_.repository -ne $Identity}){
        $otherDir=Resolve-SBParaPath $BrainRoot $other.path
        $record=Read-SBJson (Join-Path $otherDir 'repository.json') @{}
        if(!$record.ContainsKey('tracker')){continue}
        $declaration=$record.tracker
        if($record.identity -cne $other.repository -or $declaration -isnot [Collections.IDictionary] -or $declaration.Count -ne 3 -or
           $declaration.location -ne 'dossier' -or $declaration.path -cne 'tracker.json' -or $declaration.schemaVersion -ne 1){throw (New-SBError 'tracker.related.declaration' @($other.repository))}
        $path=Resolve-SBParaPath $otherDir 'tracker.json'
        if(!(Test-Path -LiteralPath $path -PathType Leaf)){throw (New-SBError 'tracker.related.missing' @($other.repository))}
        $data=Read-SBJson $path $null
        if($data.repository -cne $other.repository){throw (New-SBError 'tracker.related.identity')}
        if($null -ne $Archives){$Archives[$other.repository]=(Read-SBTrackerArchive $path $other.repository).data}
        $related[$other.repository]=$data
    }
    $related
}

function Resolve-SBTracker {
    param([string]$BrainRoot,[string]$Identity,[string]$CheckoutPath,[string[]]$AllowedOwners,$Entities=@(),[string]$DossierPath='',
        [switch]$AllowUndeclaredImportSource)
    if(!$Entities.Count){$Entities=@(Get-SBParaEntities $BrainRoot $AllowedOwners)}
    $areas=@($Entities|Where-Object {(Test-SBRepoDossier $_) -and $_.repository -eq $Identity})
    if(!$areas.Count -and $DossierPath -and (Test-SBRepositoryIdentity $Identity $AllowedOwners)){
        $areas=@(@{path=$DossierPath;repository=$Identity})
    }
    if($areas.Count -ne 1){throw (New-SBError 'tracker.identity.area' @($Identity))}
    $area=$areas[0];$dir=Resolve-SBParaPath $BrainRoot $area.path
    $metadata=Read-SBJson (Join-Path $dir 'repository.json') @{}
    if($metadata.ContainsKey('identity') -and $metadata.identity -ne $Identity){throw (New-SBError 'tracker.dossier.identity')}
    if($metadata.ContainsKey('tracker')) {
        $declaration=$metadata.tracker
        if($declaration -isnot [Collections.IDictionary] -or $declaration.Count -ne 3 -or
           $declaration.location -ne 'dossier' -or $declaration.path -cne 'tracker.json' -or $declaration.schemaVersion -ne 1){throw (New-SBError 'tracker.declaration.invalid' @($Identity))}
        $path=Resolve-SBParaPath $dir $declaration.path
        if(!(Test-Path -LiteralPath $path -PathType Leaf)){throw (New-SBError 'tracker.declared.missing' @($path))}
        if(!(Test-SBTrackerPolicy $BrainRoot)){throw (New-SBError 'tracker.policy.unapproved' @($Identity))}
        $data=Read-SBJson $path $null
        if($data -is [Collections.IDictionary] -and $data.Contains('schemaVersion') -and $data.schemaVersion -ne 1){
            throw (New-SBError 'tracker.schema.version')
        }
        $archives=@{}
        $related=Get-SBTrackerRelatedData $BrainRoot $Identity $Entities $archives
        $archive=Read-SBTrackerArchive $path $Identity
        $archives[$Identity]=$archive.data
        $graph=Join-SBTrackerArchive $data $archive.data
        [void](Test-SBTrackerData $data $Identity @($Entities|Where-Object {Test-SBRepoDossier $_}|ForEach-Object repository) (Join-Path $PSScriptRoot '../config/tracker.schema.json') $related $archives)
        foreach($repo in @($related.Keys)){$related[$repo]=Join-SBTrackerArchive $related[$repo] $archives[$repo]}
        return @{source='dossier';path=$path;relativePath=$area.path+'/tracker.json';declared=$true;schemaVersion=1;data=$data;related=$related;graph=$graph;archive=$archive}
    }
    # Only explicit import may discover an original source for an undeclared greenfield tracker.
    if(!$AllowUndeclaredImportSource -and $metadata.ContainsKey('lifecycle') -and $metadata.lifecycle -ceq 'greenfield'){
        throw (New-SBError 'tracker.greenfield.declaration.required' @($Identity))
    }
    $path=if($CheckoutPath -and [IO.Path]::GetFullPath($CheckoutPath) -ne [IO.Path]::GetFullPath($dir)){
        $found=''
        foreach($name in @('tracker.json','tracker.md','tasks.json','legacy-tasks.json')){
            $candidate=Join-Path $CheckoutPath $name
            if(Test-Path -LiteralPath $candidate -PathType Leaf){$found=$candidate;break}
        }
        $found
    }else{''}
    $source='repository_undeclared'
    if(!$path -or !(Test-Path -LiteralPath $path -PathType Leaf)){$path=Join-Path $dir 'tracker.md';$source='dossier_undeclared'}
    if(!(Test-Path -LiteralPath $path -PathType Leaf)){return @{source='absent';path=$null;declared=$false;schemaVersion=$null}}
    Assert-SBPlainPath $path
    @{source=$source;path=$path;declared=$false;schemaVersion=$null}
}

function New-SBTrackerTask($Value,[string]$Identity,[string]$Collection,[string]$Reference,[string]$Hash,[string]$Pointer,[string]$Commit='') {
    $record=if($Value -is [Collections.IDictionary]){$Value}else{@{description=[string]$Value}}
    $title=''
    foreach($key in @('title','task','description','summary')){if($record.ContainsKey($key) -and $record[$key] -is [string] -and $record[$key].Trim()){$title=$record[$key];break}}
    if(!$title){$title='Record da verificare: '+$Collection}
    $id=if($record.ContainsKey('id') -and [string]$record.id){[string]$record.id}else{''}
    if(!$id -and $Value -is [string]){
        $ids=@([regex]::Matches($Value,'(?<![\w-])(?:[A-Z][A-Z0-9]*-)+\d+(?![\w-])')|ForEach-Object Value|Sort-Object -Unique)
        if($ids.Count -eq 1){$id=$ids[0]}
    }
    if(!$id){$id='MIG-'+(Get-SBTextHash ($Identity+"`n"+$Collection+"`n"+(ConvertTo-SBJson $Value))).Substring(0,12)}
    $original=if($record.ContainsKey('status')){$record.status}else{$null}
    $status=if($null -eq $original -and $Collection -in @('todos','todo_autonomous','todo_user_required')){'todo'}else{'unknown'}
    $states=@{planned='todo';pending='todo';open='todo';todo='todo';partial='in_progress';in_progress='in_progress';completed='done';done='done';superseded_removed='cancelled';cancelled='cancelled';external='blocked';blocked='blocked';blocked_by_execution_policy='blocked';pending_interactive_ui='blocked';verification_required_waiting_vm='blocked';waiting_lab_and_signing='blocked';waiting_user_certificate='blocked'}
    if($null -ne $original -and $states.ContainsKey([string]$original)){$status=$states[[string]$original]}
    $acceptance=@()
    foreach($key in @('acceptance_criteria','completion_criteria','closureCriteria','verify')){
        if(!$record.ContainsKey($key)){continue}
        foreach($item in @($record[$key])){
            if($null -ne $item){$acceptance+=if($item -is [string]){$item}else{(ConvertTo-SBJson $item).TrimEnd()}}
        }
    }
    $priority=if($record.ContainsKey('priority')){[string]$record.priority}elseif($record.ContainsKey('p')){[string]$record.p}else{$null}
    @{id=$id;title=$title;description=$(if($record.ContainsKey('description')){[string]$record.description}else{$title});status=$status;
      execution=$(switch($Collection){todo_autonomous{'autonomous'};todo_user_required{'user_required'};default{'unspecified'}});
      priority=$priority;dependencies=@();acceptance=$acceptance;evidence=@();
      provenance=@(@{reference=$Reference;sha256=$Hash;pointer=$Pointer;commit=$(if($Commit){$Commit}else{$null});originalId=$(if($record.ContainsKey('id')){[string]$record.id}else{$null});originalStatus=$original;originalCollection=$Collection});
      extensions=@{original=$Value}}
}

function Read-SBTrackerReview([string]$Path,[string]$Identity,[string]$SourceHash) {
    Assert-SBPlainPath ([IO.Path]::GetFullPath($Path))
    $review=Read-SBJson $Path $null
    if(!$review -or $review.schemaVersion -ne 1 -or $review.repository -cne $Identity -or $review.sourceSha256 -cne $SourceHash){throw (New-SBError 'tracker.review.source')}
    if($review.tasks -isnot [array]){throw (New-SBError 'tracker.review.tasks')}
    $ids=@{}
    foreach($item in $review.tasks){
        if($item -isnot [Collections.IDictionary] -or !$item.ContainsKey('id') -or !$item.id -or $ids.ContainsKey($item.id)){throw (New-SBError 'tracker.review.id')}
        $ids[$item.id]=$true
        foreach($key in $item.Keys){if($key -notin @('id','status','dependencies','prerequisites','reason')){throw (New-SBError 'tracker.review.field' @($key))}}
        if(!$item.ContainsKey('reason') -or $item.reason -isnot [string] -or !$item.reason.Trim()){throw (New-SBError 'tracker.review.reason')}
        if(!$item.ContainsKey('status') -or $item.status -notin @('todo','in_progress','blocked','done','cancelled')){throw (New-SBError 'tracker.review.status')}
        if($item.ContainsKey('dependencies') -and $item.dependencies -isnot [array]){throw (New-SBError 'tracker.review.dependencies')}
        if($item.ContainsKey('prerequisites') -and ($item.prerequisites -isnot [array] -or @($item.prerequisites|Where-Object {$_ -isnot [string] -or !$_.Trim()}).Count)){throw (New-SBError 'tracker.review.prerequisites')}
    }
    $review
}

function ConvertTo-SBTracker {
    param([string]$SourcePath,[string]$Identity,[string]$Reference=$SourcePath,[string]$Commit='',[string]$HistoryPath='',[string]$ReviewPath='')
    Assert-SBPlainPath $SourcePath
    $hash=Get-SBFileHash $SourcePath;$text=Read-SBText $SourcePath
    $tasks=[Collections.Generic.List[object]]::new();$history=@();$originalData=$null
    if([IO.Path]::GetExtension($SourcePath) -eq '.json'){
        $originalData=Read-SBJson $SourcePath $null
        if($originalData -isnot [Collections.IDictionary]){throw (New-SBError 'tracker.original.object')}
        foreach($collection in @('tasks','todos','current_tasks','next_tasks','remainingTasks','residuals','todo_autonomous','todo_user_required')){
            if(!$originalData.ContainsKey($collection)){continue}
            if($originalData[$collection] -isnot [array]){throw (New-SBError 'tracker.collection.invalid' @($collection))}
            $i=0
            foreach($value in $originalData[$collection]){$tasks.Add((New-SBTrackerTask $value $Identity $collection $Reference $hash ('/'+$collection+'/'+$i) $Commit));$i++}
        }
    } elseif([IO.Path]::GetExtension($SourcePath) -eq '.md') {
        $originalData=@{markdown=$text};$line=0;$inOpen=$false;$inResidual=$false;$fence=''
        foreach($row in $text -split '\r?\n'){
            $line++
            if($row -match '^\s{0,3}(`{3,}|~{3,})'){
                $mark=$Matches[1]
                if(!$fence){$fence=$mark}elseif($mark[0] -eq $fence[0] -and $mark.Length -ge $fence.Length){$fence=''}
                continue
            }
            if($fence){continue}
            if($row -match '^## '){$inOpen=$row -match '^## Attivit';$inResidual=$row -match '^## Residui'}
            $recognized=$false
            if($inOpen -and $row -match '^\| (?<id>SB-OPT-\d+) \| (?<state>[^|]+) \| (?<deps>[^|]+) \| (?<result>.+) \|$'){
                $m=@{}+$Matches;$value=@{id=$m.id;title=$m.result.Trim();status='pending';priority=($m.state.Trim() -split ' ')[0];description=$m.result.Trim();closureCriteria=$m.result.Trim();dependencies=@();originalRow=$row}
                if($m.state -match 'bloccato'){$value.status='blocked'}elseif($m.state -match 'parziale|in corso'){$value.status='PARTIAL'}
                $dependencyText=[regex]::Replace($m.deps,'SB-OPT-(\d+)\.\.(\d+)',[Text.RegularExpressions.MatchEvaluator]{param($match) (([int]$match.Groups[1].Value)..([int]$match.Groups[2].Value)|ForEach-Object {'SB-OPT-'+$_.ToString('00')}) -join ', '})
                # Conditions after a semicolon remain original text, not new prerequisites.
                if($dependencyText.TrimStart() -match '^SB-OPT-'){$value.dependencies=@([regex]::Matches(($dependencyText -split ';',2)[0],'SB-OPT-\d+')|ForEach-Object Value|Sort-Object -Unique)}
                $tasks.Add((New-SBTrackerTask $value $Identity 'markdown.open' $Reference $hash ('line:'+ $line) $Commit))
                $recognized=$true
            }
            if($inResidual -and $row -match '^- \[ \] (?<text>.+)$'){
                $value=@{description=$Matches.text;status=$(if($Matches.text -match 'rifiutat|blocked by policy'){'blocked'}else{'pending'})}
                $tasks.Add((New-SBTrackerTask $value $Identity 'markdown.residuals' $Reference $hash ('line:'+ $line) $Commit))
                $recognized=$true
            }
            $table=$row -match '^\s*\|'
            $header=$inOpen -and ($row -match '^\|\s*ID\s*\|[^|]*\|[^|]*\|[^|]*\|\s*$' -or $row -match '^\|(?:\s*:?-+:?\s*\|)+\s*$')
            $checkbox=$row -match '^\s*(?:[-*+]|\d+[.)])\s+\[[^\]]*\]'
            if(!$recognized -and (($table -and !$header) -or $checkbox)){
                throw (New-SBError 'tracker.markdown.format' @($line))
            }
        }
        if($HistoryPath){
            Assert-SBPlainPath $HistoryPath;$historyHash=Get-SBFileHash $HistoryPath;$historyText=Read-SBText $HistoryPath
            $history+=ConvertTo-SBTrackerHistoryRecord @{reference=$HistoryPath;sha256=$historyHash;description='Esiti storici espliciti usati per risolvere le dipendenze'}
            $line=0
            foreach($row in $historyText -split '\r?\n'){
                $line++
                if($row -match '^\| (?<id>SB-OPT-\d+) \| Completato[^|]* \| (?<result>.+) \|$'){
                    $v=@{id=$Matches.id;title=$Matches.result;status='completed'}
                    $task=New-SBTrackerTask $v $Identity 'markdown.completed' $HistoryPath $historyHash ('line:'+ $line) $Commit
                    $task.evidence=@(@{reference=$HistoryPath+'#chiusura-dei-task-del-lotto-1';outcome='passed'})
                    $tasks.Add($task)
                }
            }
        }
    } else {throw (New-SBError 'tracker.original.format')}
    $ids=@{};foreach($task in $tasks){if($ids.ContainsKey($task.id)){throw (New-SBError 'tracker.id.collision' @($task.id))};$ids[$task.id]=$true}
    foreach($task in $tasks){
        $raw=$task.extensions.original
        if($raw -isnot [Collections.IDictionary]){continue}
        foreach($key in @('dependencies','dependsOn')){
            if(!$raw.ContainsKey($key)){continue}
            foreach($dependency in @($raw[$key])){
                if($dependency -is [string] -and $ids.ContainsKey($dependency)){$task.dependencies+=@{id=$dependency}}
                elseif($dependency -is [Collections.IDictionary] -and $dependency.ContainsKey('id')){$task.dependencies+=@{}+$dependency}
                else{
                    if(!$task.extensions.ContainsKey('unresolvedDependencies')){$task.extensions.unresolvedDependencies=@()}
                    $task.extensions.unresolvedDependencies+=,$dependency
                    $task.status='unknown'
                }
            }
        }
    }
    $review=$null
    if($ReviewPath){
        $review=Read-SBTrackerReview $ReviewPath $Identity $hash
        foreach($item in $review.tasks){
            $matches=@($tasks|Where-Object id -CEQ $item.id)
            if($matches.Count -ne 1){throw (New-SBError 'tracker.review.unknown' @($item.id))}
            $task=$matches[0]
            if($task.extensions.ContainsKey('unresolvedDependencies') -and !$item.ContainsKey('dependencies')){throw (New-SBError 'tracker.review.reconcile' @($item.id))}
            $task.status=$item.status
            if($item.ContainsKey('dependencies')){$task.dependencies=$item.dependencies}
            if($item.ContainsKey('prerequisites')){$task.extensions.prerequisites=$item.prerequisites}
            $task.extensions.review=@{reason=$item.reason;sourceSha256=$hash;reviewSha256=Get-SBFileHash $ReviewPath}
        }
    }
    $result=@{schemaVersion=1;repository=$Identity;updatedAt=[DateTimeOffset]::UtcNow.ToString('o');tasks=@($tasks);history=$history;extensions=@{original=$originalData;source=@{reference=$Reference;sha256=$hash}}}
    if($review){$result.extensions.review=@{sha256=Get-SBFileHash $ReviewPath;decisions=$review}}
    $result
}

function Convert-SBTrackerLocation($Data,[hashtable]$Mapping,[string]$BrainRoot,[string]$Dossier) {
    # Only typed references move. Imported original values and immutable candidates stay exact.
    $next=ConvertTo-SBJson $Data|ConvertFrom-Json -AsHashtable -DateKind String
    $newDossier=Convert-SBParaReferences $Dossier $Mapping $BrainRoot
    $oldDir=Resolve-SBParaPath $BrainRoot $Dossier
    $newDir=Resolve-SBParaPath $BrainRoot $newDossier
    $records=@($next.history)
    foreach($task in $next.tasks){$records+=@($task.provenance)+@($task.evidence)}
    if($next.extensions.ContainsKey('source') -and $next.extensions.source -is [Collections.IDictionary]){$records+=,$next.extensions.source}
    foreach($record in $records){
        if(!$record.ContainsKey('reference') -or $record.reference -isnot [string]){continue}
        $reference=$record.reference
        $relocated=Convert-SBParaReferences $reference $Mapping $BrainRoot
        if($relocated -cne $reference){$record.reference=$relocated;continue}
        if([IO.Path]::IsPathFullyQualified($reference) -or $reference -match '^(?:[a-z][a-z0-9+.-]*:|#|//|(?:01-projects|02-areas|03-resources|04-archives|docs|scripts|direttive|config)/)'){continue}
        $parts=$reference -split '(?=[#?])',2
        $resolved=[IO.Path]::GetFullPath((Join-Path $oldDir ([Uri]::UnescapeDataString($parts[0]))))
        if(!(Test-Path -LiteralPath $resolved)){continue}
        $resolved=Convert-SBParaReferences $resolved $Mapping $BrainRoot
        $record.reference=[Uri]::EscapeUriString([IO.Path]::GetRelativePath($newDir,$resolved).Replace('\','/'))
        if($parts.Count -gt 1){$record.reference+=$parts[1]}
    }
    $next
}

function Get-SBCuratedReferenceIssues([string]$BrainRoot,$Entities) {
    foreach($area in $Entities|Where-Object {(Test-SBRepoDossier $_) -and !$_.archived}){
        $dir=Resolve-SBParaPath $BrainRoot $area.path
        foreach($name in @('context.md','memory.md','brief.md','tracker.md')){
            $path=Join-Path $dir $name
            if(!(Test-Path -LiteralPath $path -PathType Leaf)){continue}
            Assert-SBPlainPath $path;$fence='';$lineNumber=0
            foreach($line in (Read-SBText $path) -split '\r?\n'){
                $lineNumber++
                if($line -match '^\s{0,3}(`{3,}|~{3,})'){
                    $mark=$Matches[1]
                    if(!$fence){$fence=$mark}elseif($mark[0] -eq $fence[0] -and $mark.Length -ge $fence.Length){$fence=''}
                    continue
                }
                if($fence){continue}
                # Stale paths in prose or inline code remain references; fenced blocks are excluded.
                foreach($match in [regex]::Matches($line,'(?<![\w:/\\.-])repos/[^/\s`<>]+/(?:context|memory|tracker)\.md')){
                    'Riferimento dossier obsoleto: '+$area.path+'/'+$name+':'+$lineNumber+': '+$match.Value
                }
                $prose=[regex]::Replace($line,'(?<ticks>`+)(?!`)(?:(?!\k<ticks>).)*?\k<ticks>','')
                foreach($match in [regex]::Matches($prose,'(?<!!)\[[^\]]*\]\((?<target><[^>]+>|[^\s)]+)(?:\s+"[^"]*")?\)')){
                    $target=$match.Groups['target'].Value.Trim('<','>')
                    if($target -match '^(?:[a-z][a-z0-9+.-]*:|#|//)'){continue}
                    $target=[Uri]::UnescapeDataString(($target -split '[#?]',2)[0])
                    if(!$target){continue}
                    $resolved=[IO.Path]::GetFullPath((Join-Path $dir $target))
                    Assert-SBPlainPath $resolved
                    if(!(Test-Path -LiteralPath $resolved)){'Target dossier mancante: '+$area.path+'/'+$name+':'+$lineNumber+': '+$target}
                }
            }
        }
    }
}

function Get-SBTrackerAuthorityIssues([string]$BrainRoot,$Entities) {
    foreach($project in $Entities|Where-Object {$_.kind -eq 'project' -and !(Test-SBRepoDossier $_) -and !$_.archived}){
        foreach($reference in $project.metadata.trackers){
            $area=@($Entities|Where-Object {(Test-SBRepoDossier $_) -and $_.id -eq $reference.area})[0]
            $dir=Resolve-SBParaPath $BrainRoot $area.path
            $record=Read-SBJson (Join-Path $dir 'repository.json') @{}
            if(!$record.ContainsKey('tracker')){continue}
            if(($reference.ContainsKey('repository') -and $reference.repository) -or $reference.path -cne 'tracker.json'){
                'Fonte tracker Progetto divergente: '+$project.id+'; Area='+$area.id+'; atteso tracker.json nel dossier'
            }
        }
    }
}

function Resolve-SBTrackerBackupRoot([string]$BrainRoot) {
    # Default backupRoot comes from the current host configuration (workstation.json, including migrated configurations);
    # without active configuration, use .runtime/backups/transactions. An existing invalid configuration is an error, not a fallback.
    $fallback=Join-Path $BrainRoot '.runtime/backups/transactions'
    $configPath=Get-SBHostConfigPath $BrainRoot
    if(!(Test-Path -LiteralPath $configPath -PathType Leaf)){return $fallback}
    $local=Read-SBJson $configPath $null
    if($local -is [Collections.IDictionary] -and $local.ContainsKey('migratedTo')){$local=Read-SBJson (Assert-SBCentralDataPath $BrainRoot $local.migratedTo) $null}
    if($local -isnot [Collections.IDictionary] -or !$local.ContainsKey('backupRoot') -or !$local.backupRoot){throw (New-SBError 'tracker.host.backuproot' @($configPath))}
    $value=[string]$local.backupRoot
    if(![IO.Path]::IsPathFullyQualified($value)){$value=Join-Path $BrainRoot $value}
    Assert-SBCentralDataPath $BrainRoot $value
}
# Resolve the writable tracker (by Path or dossier-declared identity) and enforce cooperative scope.
function Resolve-SBTrackerWriteTarget([string]$BrainRoot,[string]$Identity,[string]$Path,[string]$WorkingRepository) {
    if($WorkingRepository -and $Identity -and $Identity -cne $WorkingRepository){throw (New-SBError 'tracker.write.foreign' @($Identity,$WorkingRepository))}
    if(!$BrainRoot){
        if($Path){
            $p=[IO.Path]::GetFullPath($Path)
            while($p -and !(Test-Path (Join-Path $p 'direttive/approved.json'))){
                $parent=Split-Path $p -Parent
                if($parent -eq $p){break}
                $p=$parent
            }
            if(Test-Path (Join-Path $p 'direttive/approved.json')){$BrainRoot=$p}
        }
        if(!$BrainRoot){$BrainRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))}
    }
    $BrainRoot=[IO.Path]::GetFullPath($BrainRoot)
    if($Path){
        $trackerPath=[IO.Path]::GetFullPath($Path)
        Assert-SBPlainPath $trackerPath
        if(!(Test-Path -LiteralPath $trackerPath -PathType Leaf)){throw (New-SBError 'tracker.file.missing' @($trackerPath))}
        $data=Read-SBJson $trackerPath $null
        if(!$Identity){$Identity=[string]$data.repository}
        if($WorkingRepository -and $Identity -cne $WorkingRepository){throw (New-SBError 'tracker.write.foreign' @($Identity,$WorkingRepository))}
    }else{
        if(!$Identity){throw (New-SBError 'tracker.identity.required')}
        if(!(Test-SBTrackerPolicy $BrainRoot)){throw (New-SBError 'tracker.policy.unapproved' @($Identity))}
        $entities=@(Get-SBParaEntities $BrainRoot @())
        $areas=@($entities|Where-Object {(Test-SBRepoDossier $_) -and $_.repository -eq $Identity})
        if($areas.Count -ne 1){throw (New-SBError 'tracker.identity.area' @($Identity))}
        $dir=Resolve-SBParaPath $BrainRoot $areas[0].path
        $metadata=Read-SBJson (Join-Path $dir 'repository.json') @{}
        if(!$metadata.ContainsKey('tracker')){throw (New-SBError 'tracker.dossier.declaration' @($Identity))}
        $declaration=$metadata.tracker
        if($declaration -isnot [Collections.IDictionary] -or $declaration.location -ne 'dossier' -or $declaration.path -cne 'tracker.json' -or $declaration.schemaVersion -ne 1){throw (New-SBError 'tracker.declaration.invalid' @($Identity))}
        $trackerPath=Resolve-SBParaPath $dir $declaration.path
        if(!(Test-Path -LiteralPath $trackerPath -PathType Leaf)){throw (New-SBError 'tracker.declared.missing' @($trackerPath))}
        $data=Read-SBJson $trackerPath $null
    }
    if($data.schemaVersion -ne 1){throw (New-SBError 'tracker.schema.version')}
    $next=ConvertTo-SBJson $data|ConvertFrom-Json -AsHashtable -DateKind String
    @{brainRoot=$BrainRoot;identity=$Identity;path=$trackerPath;hash=(Get-SBFileHash $trackerPath);data=$next}
}

# Validate the updated tracker across the entire graph, then write transactionally, with optional additional files in the same journal.
function Assert-SBTrackerWriteData([string]$BrainRoot,[string]$Identity,$Data,[string]$TrackerPath,$Archive) {
    $entities=@(Get-SBParaEntities $BrainRoot @())
    $managedIdentities=@($entities|Where-Object {Test-SBRepoDossier $_}|ForEach-Object repository)
    if($Identity -notin $managedIdentities){$managedIdentities+=,$Identity}
    $schemaPath=Join-Path $PSScriptRoot '../config/tracker.schema.json'
    $archives=@{}
    $related=Get-SBTrackerRelatedData $BrainRoot $Identity $entities $archives
    if(!$TrackerPath){
        $area=@($entities|Where-Object {(Test-SBRepoDossier $_) -and $_.repository -ceq $Identity})
        if($area.Count -eq 1){$TrackerPath=Resolve-SBParaPath $BrainRoot ($area[0].path+'/tracker.json')}
    }
    if(!$Archive -and $TrackerPath){$Archive=(Read-SBTrackerArchive $TrackerPath $Identity).data}
    if($Archive){$archives[$Identity]=$Archive}
    [void](Test-SBTrackerData $Data $Identity $managedIdentities $schemaPath $related $archives)
}
function Save-SBTrackerData($Target,$Data,[string]$BackupRoot,[switch]$WhatIf,[object[]]$ExtraOperations=@(),$Archive,$ArchiveForValidation) {
    $Data.updatedAt=[DateTimeOffset]::UtcNow.ToString('o')
    if($Archive){$ArchiveForValidation=$Archive.data}
    Assert-SBTrackerWriteData $Target.brainRoot $Target.identity $Data $Target.path $ArchiveForValidation
    if($Archive){
        $terminal=@($Data.tasks|Where-Object {$_.status -in @('done','cancelled')})
        $Data.tasks=@($Data.tasks|Where-Object {$_.status -notin @('done','cancelled')})
        if($terminal.Count -or $Archive.changed){
            if(!$Data.extensions){$Data.extensions=@{}}
            $Data.extensions.lastSeq=[Math]::Max((Get-SBTrackerLastSeq $Data),(Get-SBTrackerLastSeq @{tasks=@($Archive.data.tasks)+$terminal}))
            $Archive.data.tasks+=@($terminal)
            $Archive.data.archivedAt=$Data.updatedAt
            $Archive.data.tasksCount=$Archive.data.tasks.Count
            $ExtraOperations+=@{path=$Archive.path;expected=$Archive.hash;bytes=[Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $Archive.data))}
        }
    }
    if($WhatIf){return @{applied=$false;path=$Target.path;data=$Data;extraOperations=$ExtraOperations}}
    if(!$BackupRoot){$BackupRoot=Resolve-SBTrackerBackupRoot $Target.brainRoot}
    [IO.Directory]::CreateDirectory($BackupRoot)|Out-Null
    $ops=@(@{path=$Target.path;expected=$Target.hash;bytes=[Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $Data))})+@($ExtraOperations)
    foreach($op in @($ExtraOperations)){if($op.expected -eq 'absent'){[IO.Directory]::CreateDirectory((Split-Path $op.path))|Out-Null}}
    $manifest=Invoke-SBParaTransaction -Operations $ops -BackupRoot $BackupRoot -BrainRoot $Target.brainRoot
    @{applied=$true;manifest=$manifest;path=$Target.path;data=$Data}
}

function Get-SBTrackerTaskForUpdate($Target,$Archive,[string]$TaskId) {
    $matching=@($Target.data.tasks|Where-Object id -eq $TaskId)
    if(!$matching.Count){
        $matching=@($Archive.data.tasks|Where-Object id -eq $TaskId)
        if($matching.Count -eq 1){
            $Archive.data.tasks=@($Archive.data.tasks|Where-Object id -ne $TaskId)
            $Target.data.tasks+=,$matching[0]
            $Archive.changed=$true
        }
    }
    if($matching.Count -ne 1){throw (New-SBError 'tracker.task.notfound' @($TaskId))}
    $matching[0]
}

function Move-SBTerminalTrackerTasks([string]$BrainRoot,[string]$Identity,[switch]$Apply,[string]$BackupRoot) {
    $target=Resolve-SBTrackerWriteTarget $BrainRoot $Identity
    if([IO.Path]::GetRelativePath($target.brainRoot,$target.path).Replace('\','/').StartsWith('04-archives/')){throw (New-SBError 'tracker.archive.identity')}
    $archive=Read-SBTrackerArchive $target.path $target.identity
    $ids=@($target.data.tasks|Where-Object {$_.status -in @('done','cancelled')}|ForEach-Object id)
    if(!$ids.Count){return @{repository=$Identity;taskIds=$ids;applied=$false}}
    $saved=Save-SBTrackerData $target $target.data $BackupRoot -WhatIf:(!$Apply) -Archive $archive
    @{repository=$Identity;taskIds=$ids;applied=$saved.applied;manifest=$saved['manifest']}
}

# A timestamp is a reminder signal, not proof that a summary was reviewed.
function Get-SBClosureMemoryPending([string]$Dossier,$Tracker) {
    if(!$Tracker.extensions.ContainsKey('lastClosure')){return}
    $closure=$Tracker.extensions.lastClosure
    $closedAt=[DateTimeOffset]::MinValue
    if($closure -isnot [Collections.IDictionary] -or !$closure.ContainsKey('taskId') -or
       !$closure.taskId -or !$closure.ContainsKey('closedAt') -or
       ![DateTimeOffset]::TryParse([string]$closure.closedAt,[ref]$closedAt)){
        throw (New-SBError 'tracker.closure.invalid')
    }
    $memoryPath=Join-Path $Dossier 'memory.md'
    Assert-SBPlainPath $memoryPath
    $memoryUpdatedAt=if([IO.File]::Exists($memoryPath)){[DateTimeOffset][IO.File]::GetLastWriteTimeUtc($memoryPath)}else{$null}
    if(!$memoryUpdatedAt -or $closedAt -gt $memoryUpdatedAt){
        @{taskId=$closure.taskId;closedAt=$closure.closedAt;memoryUpdatedAt=$(if($memoryUpdatedAt){$memoryUpdatedAt.ToString('o')}else{$null})}
    }
}

function Set-SBTrackerTaskStatus {
    [CmdletBinding()]
    param(
        [string]$BrainRoot,
        [string]$Identity,
        [string]$Path,
        [Parameter(Mandatory)][string]$TaskId,
        [Parameter(Mandatory)][string]$Status,
        [string]$StateReason,
        $Evidence=@(),
        [string]$BackupRoot,
        [switch]$WhatIf,
        [string]$WorkingRepository
    )
    $target=Resolve-SBTrackerWriteTarget $BrainRoot $Identity $Path $WorkingRepository
    if($Status -notin @('todo','in_progress','blocked','done','cancelled','unknown')){
        throw (New-SBError 'tracker.status.invalid' @($Status))
    }
    $next=$target.data
    $archive=Read-SBTrackerArchive $target.path $target.identity
    $targetTask=Get-SBTrackerTaskForUpdate $target $archive $TaskId
    if($Status -eq 'done' -and $targetTask.status -ne 'done'){
        # Keep the latest closure on the tracker so archiving tasks preserves the signal.
        $next.extensions.lastClosure=@{taskId=$TaskId;closedAt=[DateTimeOffset]::UtcNow.ToString('o')}
    }
    $targetTask.status=$Status
    if($PSBoundParameters.ContainsKey('StateReason')){
        if(!$targetTask.ContainsKey('extensions') -or $null -eq $targetTask.extensions){$targetTask.extensions=@{}}
        if($StateReason){$targetTask.extensions.stateReason=$StateReason}
        else{[void]$targetTask.extensions.Remove('stateReason')}
    }
    if($Evidence -and @($Evidence).Count -gt 0){
        if(!$targetTask.ContainsKey('evidence') -or $null -eq $targetTask.evidence){$targetTask.evidence=@()}
        foreach($ev in @($Evidence)){$targetTask.evidence+=,$ev}
    }
    $saved=Save-SBTrackerData $target $next $BackupRoot -WhatIf:$WhatIf -Archive $archive
    $result=$saved+@{taskId=$TaskId;status=$Status}
    if($Status -eq 'done'){
        $result.closureAdvice=@{code='tracker.closure.advice';message=(Get-SBMessage 'tracker.closure.advice');dossier=(Split-Path $target.path);steps=@('memory','context','summary','sync','check');summaryOptions=@('memory','history','skip')}
    }
    $result
}

# Create a task with the next sequential number (never reused) and a "#NNN - " title.
# Requires an already numbered tracker: run Invoke-SBTrackerRenumber first for historical trackers.
function New-SBTrackerTaskEntry {
    [CmdletBinding()]
    param(
        [string]$BrainRoot,
        [string]$Identity,
        [string]$Path,
        [string]$WorkingRepository,
        [Parameter(Mandatory)][string]$Title,
        [string]$Id,
        [string]$Description,
        [string]$Priority='P2',
        [ValidateSet('autonomous','user_required','unspecified')][string]$Execution='autonomous',
        [string[]]$DependsOn=@(),
        [Parameter(Mandatory)][string[]]$Acceptance,
        [Parameter(Mandatory)][string]$ProvenanceReference,
        [string]$ProvenancePointer,
        [hashtable]$Extensions=@{},
        [AllowEmptyCollection()][AllowEmptyString()][string[]]$Requires=@(),
        [string]$BackupRoot,
        [switch]$WhatIf
    )
    if($Priority -cnotin @('P0','P1','P2','P3','P4')){throw (New-SBError 'tracker.priority.invalid')}
    if($Id -and $Id -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._-]{2,79}$'){throw (New-SBError 'tracker.id.invalid' @($Id))}
    if($Title -notmatch '\p{L}'){throw (New-SBError 'tracker.title.invalid')}
    $requiresList=ConvertTo-SBTaskRequires $Requires
    if($requiresList.Count){$Extensions=$Extensions+@{requires=@($requiresList)}}
    $target=Resolve-SBTrackerWriteTarget $BrainRoot $Identity $Path $WorkingRepository
    $next=$target.data
    $unnumbered=@($next.tasks|Where-Object {!$_.ContainsKey('seq')})
    if($unnumbered.Count){throw (New-SBError 'tracker.unnumbered' @($unnumbered.Count))}
    if(!@($Acceptance|Where-Object {$_ -and $_.Trim()}).Count){throw (New-SBError 'tracker.acceptance.required')}
    $archive=Read-SBTrackerArchive $target.path $target.identity
    $seq=(Get-SBTrackerLastSeq (Join-SBTrackerArchive $next $archive.data))+1
    if(!$Id){$Id='TASK-'+$seq.ToString('000')}
    if(@(@($next.tasks)+@($archive.data.tasks)|Where-Object {$_.id -ieq $Id}).Count){throw (New-SBError 'tracker.task.exists' @($Id))}
    # Provenance is a real file: dossier-relative or absolute reference; compute its hash here.
    $dossierDir=Split-Path $target.path
    $sourcePath=if([IO.Path]::IsPathFullyQualified($ProvenanceReference)){$ProvenanceReference}else{Join-Path $dossierDir (($ProvenanceReference -split '#',2)[0])}
    if(!(Test-Path -LiteralPath $sourcePath -PathType Leaf)){throw (New-SBError 'tracker.provenance.missing' @($ProvenanceReference))}
    Assert-SBPlainPath $sourcePath
    $dependencies=@($DependsOn|Where-Object {$_}|ForEach-Object {
        $parts=$_ -split '#',2
        if($parts.Count -eq 2){@{repository=$parts[0];id=$parts[1]}}else{@{id=$_}}
    })
    $task=@{
        id=$Id;seq=$seq;title=(Format-SBTrackerSeqTitle $seq $Title);status='todo';execution=$Execution;priority=$Priority
        dependencies=$dependencies;acceptance=@($Acceptance);evidence=@()
        provenance=@(@{reference=$ProvenanceReference;sha256=(Get-SBFileHash $sourcePath);pointer=$(if($ProvenancePointer){$ProvenancePointer}else{$Title})})
        extensions=$Extensions
    }
    if($Description){$task.description=$Description}
    $next.tasks+=,$task
    if($null -eq $next.extensions){$next.extensions=@{}}
    $next.extensions.lastSeq=$seq
    $saved=Save-SBTrackerData $target $next $BackupRoot -WhatIf:$WhatIf
    $saved+@{taskId=$Id;seq=$seq;title=$task.title}
}

# Retrospective chronological numbering: archive and active tracker; date from the ID (yyyyMMdd) or inherited from the previous task.
# Stable ordering; preserve originals by hash in history/tracker-seq/<sha256>/ within the same transaction. Without -Apply, preview only.
function Invoke-SBTrackerRenumber {
    [CmdletBinding()]
    param(
        [string]$BrainRoot,
        [string]$Identity,
        [string]$Path,
        [string]$WorkingRepository,
        [string]$ArchivePath,
        [string]$BackupRoot,
        [switch]$Apply
    )
    $target=Resolve-SBTrackerWriteTarget $BrainRoot $Identity $Path $WorkingRepository
    $next=$target.data
    $dossierDir=Split-Path $target.path
    if(!$ArchivePath){$ArchivePath=Join-Path $dossierDir 'history/tracker-archive.json'}
    $archive=$null;$archiveHash='absent'
    if(Test-Path -LiteralPath $ArchivePath -PathType Leaf){
        Assert-SBPlainPath $ArchivePath
        $archiveHash=Get-SBFileHash $ArchivePath
        $archive=ConvertTo-SBJson (Read-SBJson $ArchivePath $null)|ConvertFrom-Json -AsHashtable -DateKind String
        if($archive -isnot [Collections.IDictionary] -or $archive.repository -cne $target.identity){throw (New-SBError 'tracker.archive.identity')}
    }
    $items=@()
    if($archive){foreach($t in $archive.tasks){$items+=,@{task=$t;source='archive'}}}
    foreach($t in $next.tasks){$items+=,@{task=$t;source='tracker'}}
    $numbered=@($items|Where-Object {$_.task.ContainsKey('seq')})
    if($items.Count -and $numbered.Count -eq $items.Count){return @{applied=$false;changed=$false;reason='Tracker gia numerato';code='tracker.reason.numbered';message=(Get-SBMessage 'tracker.reason.numbered');count=$items.Count;lastSeq=(Get-SBTrackerLastSeq $next)}}
    if($numbered.Count){throw (New-SBError 'tracker.numbering.partial' @($numbered.Count,$items.Count))}
    $current='00000000';$index=0
    foreach($item in $items){
        $match=[regex]::Match([string]$item.task.id,'(?<!\d)(20\d{6})(?!\d)')
        if($match.Success){$current=$match.Groups[1].Value}
        $item.date=$current;$item.index=$index;$index++
    }
    $ordered=@($items|Sort-Object @{Expression={$_.date}},@{Expression={$_.index}})
    $mapping=@();$seq=0
    foreach($item in $ordered){
        $seq++
        $item.task.seq=$seq
        $item.task.title=Format-SBTrackerSeqTitle $seq ([string]$item.task.title)
        $mapping+=,@{seq=$seq;id=$item.task.id;source=$item.source}
    }
    if($null -eq $next.extensions){$next.extensions=@{}}
    $next.extensions.lastSeq=$seq
    $originalRel='history/tracker-seq/'+$target.hash.ToLowerInvariant()
    $originalRoot=Join-Path $dossierDir $originalRel
    $extra=@(@{path=(Join-Path $originalRoot 'tracker.json');expected='absent';bytes=[IO.File]::ReadAllBytes($target.path)})
    if($archive){
        $extra+=@{path=(Join-Path $originalRoot 'tracker-archive.json');expected='absent';bytes=[IO.File]::ReadAllBytes($ArchivePath)}
        $extra+=@{path=[IO.Path]::GetFullPath($ArchivePath);expected=$archiveHash;bytes=[Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $archive))}
    }
    $next.history+=,(ConvertTo-SBTrackerHistoryRecord @{reference=$originalRel+'/tracker.json';sha256=$target.hash;description="Numerazione retroattiva: $seq task (archivio e attivi) in ordine cronologico; originali conservati per hash."})
    $saved=Save-SBTrackerData $target $next $BackupRoot -WhatIf:(!$Apply) -ExtraOperations $extra -ArchiveForValidation $archive
    $saved.Remove('data')
    $saved+@{changed=$true;count=$seq;lastSeq=$seq;originals=$originalRel;mapping=$mapping}
}

function ConvertTo-SBTrackerHistoryRecord([System.Collections.IDictionary]$Record) {
    $next = @{} + $Record
    if ($next.ContainsKey('code')) { return $next }
    $description = [string]$next.description
    $next.code = 'tracker.history.note'; $next.messageArgs = @()
    if ($description -ceq 'Esiti storici espliciti usati per risolvere le dipendenze') {
        $next.code = 'tracker.history.dependencies'; $next.messageArgs = @()
    } elseif ($description -cmatch '^Numerazione retroattiva: (\d+) task \(archivio e attivi\) in ordine cronologico; originali conservati per hash\.$') {
        $next.code = 'tracker.history.numbered'; $next.messageArgs = @([int]$Matches[1])
    }
    $next
}

function Get-SBTrackerHistoryMessages($Data) {
    # Derived view only: persisted descriptions and free notes remain unchanged.
    $records = @()
    if ($Data.ContainsKey('history')) { $records += @($Data.history) }
    if ($Data.ContainsKey('description')) {
        $metadata = @{}
        foreach ($key in @('description','code','messageArgs','reference','sha256','archivedAt')) {
            if ($Data.ContainsKey($key)) { $metadata[$key] = $Data[$key] }
        }
        $records += ,$metadata
    }
    foreach ($record in $records) {
        $view = ConvertTo-SBTrackerHistoryRecord $record
        $arguments = @()
        if ($view.ContainsKey('messageArgs')) { $arguments = @($view.messageArgs) }
        if ($view.code -eq 'tracker.history.note') { $arguments = @($view.description) }
        $view.message = Get-SBMessage $view.code $arguments
        $view
    }
}

function Invoke-SBTrackerHistoryMigration {
    [CmdletBinding()]
    param([string]$BrainRoot, [string]$Identity, [string]$Path, [string]$WorkingRepository,
        [string]$BackupRoot, [switch]$Apply)
    $target = Resolve-SBTrackerWriteTarget $BrainRoot $Identity $Path $WorkingRepository
    Assert-SBTrackerWriteData $target.brainRoot $target.identity $target.data $target.path
    $dir = Split-Path $target.path
    $archivePath = Join-Path $dir 'history/tracker-archive.json'
    $inputs = @(@{path=$target.path;data=$target.data;hash=$target.hash;name='tracker.json'})
    if (Test-Path -LiteralPath $archivePath -PathType Leaf) {
        Assert-SBPlainPath $archivePath
        $bytes = [IO.File]::ReadAllBytes($archivePath)
        $archive = [Text.Encoding]::UTF8.GetString($bytes).TrimStart([char]0xFEFF) | ConvertFrom-Json -AsHashtable -DateKind String
        if ($archive.repository -cne $target.identity -or $archive.schemaVersion -ne 1 -or !$archive.ContainsKey('tasks')) { throw (New-SBError 'tracker.archive.identity') }
        $inputs += @{path=$archivePath;data=$archive;hash=(Get-SBHash $bytes);name='tracker-archive.json'}
    }
    $operations = @(); $changes = @(); $originals = @()
    foreach ($inputFile in $inputs) {
        $bytes = [IO.File]::ReadAllBytes($inputFile.path)
        if ((Get-SBHash $bytes) -cne $inputFile.hash -or (ConvertTo-SBJson (Read-SBJson $inputFile.path $null)) -cne (ConvertTo-SBJson $inputFile.data)) {
            throw (New-SBError 'tracker.history.snapshot' @($inputFile.name))
        }
        $before = ConvertTo-SBJson $inputFile.data
        $next = ConvertTo-SBJson $inputFile.data | ConvertFrom-Json -AsHashtable -DateKind String
        if ($next.ContainsKey('history')) { $next.history = @($next.history | ForEach-Object { ConvertTo-SBTrackerHistoryRecord $_ }) }
        if ($next.ContainsKey('description')) { $next = ConvertTo-SBTrackerHistoryRecord $next }
        if ((ConvertTo-SBJson $next) -ceq $before) { continue }
        $snapshot = Join-Path $dir ('history/tracker-messages/' + $inputFile.hash.ToLowerInvariant() + '/' + $inputFile.name)
        if (Test-Path -LiteralPath $snapshot) {
            if ((Get-SBFileHash $snapshot) -cne $inputFile.hash) { throw (New-SBError 'tracker.history.snapshot' @($snapshot)) }
        } else { $operations += @{path=$snapshot;expected='absent';bytes=$bytes} }
        $originals += @{path=[IO.Path]::GetRelativePath($dir,$snapshot).Replace('\','/');sha256=$inputFile.hash}
        $changes += $inputFile.name
        if ($inputFile.name -eq 'tracker.json') { $target.data = $next }
        else { $operations += @{path=$inputFile.path;expected=$inputFile.hash;bytes=[Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $next))} }
    }
    if (!$changes.Count) { return @{applied=$false;changed=$false;files=@();originals=@()} }
    $saved = Save-SBTrackerData $target $target.data $BackupRoot -WhatIf:(!$Apply) -ExtraOperations $operations
    $saved.Remove('data')
    $saved + @{changed=$true;files=$changes;originals=$originals}
}

# Capabilities a task may require; the runner leaves such tasks to an attended session (extensions.requires).
$script:SBTaskRequiresValues=@('computer-use')
function Get-SBTaskRequiresValues { ,@($script:SBTaskRequiresValues) }
function ConvertTo-SBTaskRequires([string[]]$Value) {
    # Lists arrive as one ';'-separated string with pwsh -File; unknown values are rejected, duplicates dropped, empty clears.
    $items=@($Value|ForEach-Object {$_ -split ';'}|ForEach-Object {$_.Trim()}|Where-Object {$_}|Select-Object -Unique)
    foreach($item in $items){if($item -cnotin $script:SBTaskRequiresValues){throw (New-SBError 'tracker.requires.invalid' @($item,($script:SBTaskRequiresValues -join ', ')))}}
    ,$items
}
function Update-SBTrackerTask {
    [CmdletBinding()]
    param(
        [string]$BrainRoot,
        [string]$Identity,
        [string]$Path,
        [Parameter(Mandatory)][string]$TaskId,
        [string]$Status,
        [string]$StateReason,
        [string]$Priority,
        [string]$Execution,
        [AllowEmptyCollection()][AllowEmptyString()][string[]]$DependsOn,
        [AllowEmptyString()][string]$Stream,
        [AllowEmptyString()][string]$Awaiting,
        [AllowEmptyCollection()][AllowEmptyString()][string[]]$ReadRepositories,
        [AllowEmptyCollection()][AllowEmptyString()][string[]]$Requires,
        $Evidence=@(),
        [string]$BackupRoot,
        [switch]$WhatIf,
        [string]$WorkingRepository
    )
    $fields=@('Status','StateReason','Priority','Execution','DependsOn','Stream','Awaiting','ReadRepositories','Requires','Evidence')
    if(!@($fields|Where-Object {$PSBoundParameters.ContainsKey($_)}).Count){throw (New-SBError 'tracker.update.empty')}
    if($PSBoundParameters.ContainsKey('Status') -and $Status -notin @('todo','in_progress','blocked','done','cancelled','unknown')){throw (New-SBError 'tracker.status.invalid' @($Status))}
    if($PSBoundParameters.ContainsKey('Priority') -and $Priority -cnotin @('P0','P1','P2','P3','P4')){throw (New-SBError 'tracker.priority.invalid')}
    if($PSBoundParameters.ContainsKey('Execution') -and $Execution -cnotin @('autonomous','user_required','unspecified')){throw (New-SBError 'tracker.execution.invalid')}
    $requiresList=$null
    if($PSBoundParameters.ContainsKey('Requires')){$requiresList=ConvertTo-SBTaskRequires $Requires}
    $target=Resolve-SBTrackerWriteTarget $BrainRoot $Identity $Path $WorkingRepository
    $next=$target.data
    $archive=Read-SBTrackerArchive $target.path $target.identity
    $task=Get-SBTrackerTaskForUpdate $target $archive $TaskId
    $wasDone=$task.status -eq 'done'
    if(!$task.ContainsKey('extensions') -or $null -eq $task.extensions){$task.extensions=@{}}
    foreach($field in @('Status','Priority','Execution')){
        if($PSBoundParameters.ContainsKey($field)){$task[$field.ToLowerInvariant()]=$PSBoundParameters[$field]}
    }
    foreach($field in @('StateReason','Stream','Awaiting')){
        if($PSBoundParameters.ContainsKey($field)){
            $key=switch($field){'StateReason'{'stateReason'}'Stream'{'stream'}default{'awaiting'}}
            $value=$PSBoundParameters[$field].Trim()
            if($value){$task.extensions[$key]=$value}else{[void]$task.extensions.Remove($key)}
        }
    }
    if($PSBoundParameters.ContainsKey('ReadRepositories')){
        # Read-only allowlist of other repositories a task may read; writes and tasks of other repositories stay forbidden.
        $reads=@($ReadRepositories|ForEach-Object {$_ -split ';'}|ForEach-Object {$_.Trim()}|Where-Object {$_}|Select-Object -Unique)
        foreach($r in $reads){if($r -cnotmatch '^(github\.com/[a-z0-9._-]+/[a-z0-9._-]+|local:[0-9a-f]{32})$'){throw (New-SBError 'tracker.readrepositories.invalid' @($r))}}
        if($reads.Count){$task.extensions.readRepositories=@($reads)}else{[void]$task.extensions.Remove('readRepositories')}
    }
    if($PSBoundParameters.ContainsKey('Requires')){
        if($requiresList.Count){$task.extensions.requires=@($requiresList)}else{[void]$task.extensions.Remove('requires')}
    }
    if($PSBoundParameters.ContainsKey('DependsOn')){
        $task.dependencies=@($DependsOn|ForEach-Object {$_ -split ';'}|ForEach-Object {$_.Trim()}|Where-Object {$_}|Select-Object -Unique|ForEach-Object {
            $parts=$_ -split '#',2
            if($parts.Count -eq 2){@{repository=$parts[0];id=$parts[1]}}else{@{id=$_}}
        })
    }
    if($Evidence){if(!$task.ContainsKey('evidence')){$task.evidence=@()};$task.evidence+=@($Evidence)}
    $closing=$PSBoundParameters.ContainsKey('Status') -and $Status -eq 'done'
    if($closing -and !$wasDone){
        $next.extensions.lastClosure=@{taskId=$TaskId;closedAt=[DateTimeOffset]::UtcNow.ToString('o')}
    }
    $saved=Save-SBTrackerData $target $next $BackupRoot -WhatIf:$WhatIf -Archive $archive
    $result=$saved+@{taskId=$TaskId;status=$task.status}
    if($closing){$result.closureAdvice=@{code='tracker.closure.advice';message=(Get-SBMessage 'tracker.closure.advice');dossier=(Split-Path $target.path);steps=@('memory','context','summary','sync','check');summaryOptions=@('memory','history','skip')}}
    $result
}

Export-ModuleMember -Function @(
    'Test-SBTrackerPolicy',
    'Test-SBTrackerData',
    'Assert-SBTrackerWriteData',
    'Read-SBTrackerArchive',
    'Move-SBTerminalTrackerTasks',
    'Get-SBTrackerRelatedData',
    'Resolve-SBTracker',
    'New-SBTrackerTask',
    'Read-SBTrackerReview',
    'ConvertTo-SBTracker',
    'Convert-SBTrackerLocation',
    'Get-SBCuratedReferenceIssues',
    'Get-SBTrackerAuthorityIssues',
    'Resolve-SBTrackerBackupRoot',
    'Set-SBTrackerTaskStatus',
    'Get-SBClosureMemoryPending',
    'New-SBTrackerTaskEntry',
    'Invoke-SBTrackerRenumber',
    'Get-SBTrackerHistoryMessages',
    'Invoke-SBTrackerHistoryMigration',
    'Update-SBTrackerTask',
    'Get-SBTaskRequiresValues',
    'ConvertTo-SBTaskRequires'
)
