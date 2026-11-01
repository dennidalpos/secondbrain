#requires -Version 7.5
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Para.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Host.psm1')

function Test-SBTrackerPolicy([string]$BrainRoot) {
    (Test-SBApproval $BrainRoot) -and (Read-SBText (Join-Path $BrainRoot 'direttive/workstation.template.md')).Contains('<!-- secondbrain:tracker-contract:1 -->')
}

function Test-SBTrackerData($Data, [string]$Identity, [string[]]$ManagedIdentities, [string]$SchemaPath, $RelatedTrackers=@{}) {
    $json=ConvertTo-SBJson $Data
    if (!(Test-Json -Json $json -SchemaFile $SchemaPath -ErrorAction SilentlyContinue)) { throw 'Tracker non conforme allo schema v1' }
    if ($Data.repository -cne $Identity) { throw 'Identita tracker divergente' }
    $date=[DateTimeOffset]::MinValue
    if (![DateTimeOffset]::TryParse($Data.updatedAt,[ref]$date)) { throw 'Data tracker non valida' }
    $nodes=@{}
    foreach($document in @($Data)+@($RelatedTrackers.Values)) {
        if(!(Test-Json -Json (ConvertTo-SBJson $document) -SchemaFile $SchemaPath -ErrorAction SilentlyContinue)){
            $identityLabel=if($document.ContainsKey('repository')){$document.repository}else{'identita assente'}
            throw ('Tracker correlato non conforme allo schema v1: '+$identityLabel)
        }
        if ($document.repository -notin $ManagedIdentities) { throw 'Tracker di identita non gestita' }
        foreach($task in $document.tasks) {
            $key=$document.repository+'#'+$task.id
            if ($nodes.ContainsKey($key)) { throw 'ID tracker duplicato: '+$key }
            $nodes[$key]=@{task=$task;repository=$document.repository}
        }
    }
    $edges=@{}
    foreach($key in @($nodes.Keys)) {
        $edges[$key]=@()
        foreach($dependency in $nodes[$key].task.dependencies) {
            $repository=if($dependency.ContainsKey('repository')){$dependency.repository}else{$nodes[$key].repository}
            if ($repository -notin $ManagedIdentities) { throw 'Dipendenza da identita non gestita: '+$repository }
            $target=$repository+'#'+$dependency.id
            if (!$nodes.ContainsKey($target)) { throw 'Dipendenza tracker inesistente o non verificabile: '+$target }
            $edges[$key]+=$target
        }
    }
    $visited=@{};$active=@{}
    function Visit-SBTrackerNode([string]$Key) {
        if($active.ContainsKey($Key)){throw 'Ciclo nelle dipendenze tracker: '+$Key}
        if($visited.ContainsKey($Key)){return}
        $active[$Key]=$true
        foreach($target in $edges[$Key]){Visit-SBTrackerNode $target}
        $active.Remove($Key);$visited[$Key]=$true
    }
    foreach($key in @($nodes.Keys)){Visit-SBTrackerNode $key}
    $true
}

function Get-SBTrackerRelatedData([string]$BrainRoot,[string]$Identity,$Entities) {
    # Read once without calling the resolver recursively; the validator visits the whole graph.
    $related=@{}
    foreach($other in $Entities|Where-Object {$_.kind -eq 'area' -and $_.repository -ne $Identity}){
        $otherDir=Resolve-SBParaPath $BrainRoot $other.path
        $record=Read-SBJson (Join-Path $otherDir 'repository.json') @{}
        if(!$record.ContainsKey('tracker')){continue}
        $declaration=$record.tracker
        if($record.identity -cne $other.repository -or $declaration -isnot [Collections.IDictionary] -or $declaration.Count -ne 3 -or
           $declaration.location -ne 'dossier' -or $declaration.path -cne 'tracker.json' -or $declaration.schemaVersion -ne 1){throw 'Dichiarazione tracker correlato non valida: '+$other.repository}
        $path=Resolve-SBParaPath $otherDir 'tracker.json'
        if(!(Test-Path -LiteralPath $path -PathType Leaf)){throw 'Tracker correlato dichiarato assente: '+$other.repository}
        $data=Read-SBJson $path $null
        if($data.repository -cne $other.repository){throw 'Identita tracker correlato divergente'}
        $related[$other.repository]=$data
    }
    $related
}

function Resolve-SBTracker {
    param([string]$BrainRoot,[string]$Identity,[string]$CheckoutPath,[string[]]$AllowedOwners,$Entities=@(),[string]$DossierPath='')
    if(!$Entities.Count){$Entities=@(Get-SBParaEntities $BrainRoot $AllowedOwners)}
    $areas=@($Entities|Where-Object {$_.kind -eq 'area' -and $_.repository -eq $Identity})
    if(!$areas.Count -and $DossierPath -and (Test-SBRepositoryIdentity $Identity $AllowedOwners)){
        $areas=@(@{path=$DossierPath;repository=$Identity})
    }
    if($areas.Count -ne 1){throw 'Identita tracker non associata a una sola Area: '+$Identity}
    $area=$areas[0];$dir=Resolve-SBParaPath $BrainRoot $area.path
    $metadata=Read-SBJson (Join-Path $dir 'repository.json') @{}
    if($metadata.ContainsKey('identity') -and $metadata.identity -ne $Identity){throw 'Identita del dossier tracker divergente'}
    if($metadata.ContainsKey('tracker')) {
        $declaration=$metadata.tracker
        if($declaration -isnot [Collections.IDictionary] -or $declaration.Count -ne 3 -or
           $declaration.location -ne 'dossier' -or $declaration.path -cne 'tracker.json' -or $declaration.schemaVersion -ne 1){throw 'Dichiarazione tracker non valida: '+$Identity}
        $path=Resolve-SBParaPath $dir $declaration.path
        if(!(Test-Path -LiteralPath $path -PathType Leaf)){throw 'Tracker dichiarato assente: '+$path}
        if(!(Test-SBTrackerPolicy $BrainRoot)){throw 'Contratto tracker non approvato: '+$Identity}
        $data=Read-SBJson $path $null
        $related=Get-SBTrackerRelatedData $BrainRoot $Identity $Entities
        [void](Test-SBTrackerData $data $Identity @($Entities|Where-Object kind -eq 'area'|ForEach-Object repository) (Join-Path $PSScriptRoot '../config/tracker.schema.json') $related)
        return @{source='dossier';path=$path;relativePath=$area.path+'/tracker.json';declared=$true;schemaVersion=1;data=$data;related=$related}
    }
    $path=if($CheckoutPath -and [IO.Path]::GetFullPath($CheckoutPath) -ne [IO.Path]::GetFullPath($dir)){
        $found=''
        foreach($name in @('tracker.json','tracker.md','tasks.json','legacy-tasks.json')){
            $candidate=Join-Path $CheckoutPath $name
            if(Test-Path -LiteralPath $candidate -PathType Leaf){$found=$candidate;break}
        }
        $found
    }else{''}
    $source='repository_legacy'
    if(!$path -or !(Test-Path -LiteralPath $path -PathType Leaf)){$path=Join-Path $dir 'tracker.md';$source='dossier_legacy'}
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
      extensions=@{legacy=$Value}}
}

function Read-SBTrackerReview([string]$Path,[string]$Identity,[string]$SourceHash) {
    Assert-SBPlainPath ([IO.Path]::GetFullPath($Path))
    $review=Read-SBJson $Path $null
    if(!$review -or $review.schemaVersion -ne 1 -or $review.repository -cne $Identity -or $review.sourceSha256 -cne $SourceHash){throw 'Review tracker di altra identita o sorgente divergente'}
    if($review.tasks -isnot [array]){throw 'Review tracker senza elenco task'}
    $ids=@{}
    foreach($item in $review.tasks){
        if($item -isnot [Collections.IDictionary] -or !$item.ContainsKey('id') -or !$item.id -or $ids.ContainsKey($item.id)){throw 'ID review tracker mancante o duplicato'}
        $ids[$item.id]=$true
        foreach($key in $item.Keys){if($key -notin @('id','status','dependencies','prerequisites','reason')){throw 'Campo review tracker non riconosciuto: '+$key}}
        if(!$item.ContainsKey('reason') -or $item.reason -isnot [string] -or !$item.reason.Trim()){throw 'Motivazione review tracker obbligatoria'}
        if(!$item.ContainsKey('status') -or $item.status -notin @('todo','in_progress','blocked','done','cancelled')){throw 'Stato review tracker non valido'}
        if($item.ContainsKey('dependencies') -and $item.dependencies -isnot [array]){throw 'Dipendenze review tracker non valide'}
        if($item.ContainsKey('prerequisites') -and ($item.prerequisites -isnot [array] -or @($item.prerequisites|Where-Object {$_ -isnot [string] -or !$_.Trim()}).Count)){throw 'Prerequisiti review tracker non validi'}
    }
    $review
}

function ConvertTo-SBTracker {
    param([string]$SourcePath,[string]$Identity,[string]$Reference=$SourcePath,[string]$Commit='',[string]$HistoryPath='',[string]$ReviewPath='')
    Assert-SBPlainPath $SourcePath
    $hash=Get-SBFileHash $SourcePath;$text=Read-SBText $SourcePath
    $tasks=[Collections.Generic.List[object]]::new();$history=@();$legacy=$null
    if([IO.Path]::GetExtension($SourcePath) -eq '.json'){
        $legacy=Read-SBJson $SourcePath $null
        if($legacy -isnot [Collections.IDictionary]){throw 'Il tracker JSON originale deve essere un oggetto'}
        foreach($collection in @('tasks','todos','current_tasks','next_tasks','remainingTasks','residuals','todo_autonomous','todo_user_required')){
            if(!$legacy.ContainsKey($collection)){continue}
            if($legacy[$collection] -isnot [array]){throw 'Collezione tracker non valida: '+$collection}
            $i=0
            foreach($value in $legacy[$collection]){$tasks.Add((New-SBTrackerTask $value $Identity $collection $Reference $hash ('/'+$collection+'/'+$i) $Commit));$i++}
        }
    } elseif([IO.Path]::GetExtension($SourcePath) -eq '.md') {
        $legacy=@{markdown=$text};$line=0;$inOpen=$false;$inResidual=$false;$fence=''
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
                # Le condizioni dopo il punto e virgola restano testo originale, non nuovi prerequisiti.
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
                throw ('Formato Markdown non riconosciuto alla riga '+$line+': conversione esplicita richiesta')
            }
        }
        if($HistoryPath){
            Assert-SBPlainPath $HistoryPath;$historyHash=Get-SBFileHash $HistoryPath;$historyText=Read-SBText $HistoryPath
            $history+=@{reference=$HistoryPath;sha256=$historyHash;description='Esiti storici espliciti usati per risolvere le dipendenze'}
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
    } else {throw 'Formato tracker originale non supportato'}
    $ids=@{};foreach($task in $tasks){if($ids.ContainsKey($task.id)){throw 'Collisione ID: risoluzione esplicita richiesta per '+$task.id};$ids[$task.id]=$true}
    foreach($task in $tasks){
        $raw=$task.extensions.legacy
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
            if($matches.Count -ne 1){throw 'Task review tracker inesistente: '+$item.id}
            $task=$matches[0]
            if($task.extensions.ContainsKey('unresolvedDependencies') -and !$item.ContainsKey('dependencies')){throw 'Review tracker richiede riconciliazione esplicita delle dipendenze: '+$item.id}
            $task.status=$item.status
            if($item.ContainsKey('dependencies')){$task.dependencies=$item.dependencies}
            if($item.ContainsKey('prerequisites')){$task.extensions.prerequisites=$item.prerequisites}
            $task.extensions.review=@{reason=$item.reason;sourceSha256=$hash;reviewSha256=Get-SBFileHash $ReviewPath}
        }
    }
    $result=@{schemaVersion=1;repository=$Identity;updatedAt=[DateTimeOffset]::UtcNow.ToString('o');tasks=@($tasks);history=$history;extensions=@{legacy=$legacy;source=@{reference=$Reference;sha256=$hash}}}
    if($review){$result.extensions.review=@{sha256=Get-SBFileHash $ReviewPath;decisions=$review}}
    $result
}

function Convert-SBTrackerLocation($Data,[hashtable]$Mapping,[string]$BrainRoot,[string]$Dossier) {
    # Only typed references move. Imported legacy values and immutable candidates stay exact.
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
    foreach($area in $Entities|Where-Object {$_.kind -eq 'area' -and !$_.archived}){
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
                # I percorsi legacy in prosa o codice inline restano riferimenti; i blocchi sono esclusi.
                foreach($match in [regex]::Matches($line,'(?<![\w:/\\.-])repos/[^/\s`<>]+/(?:context|memory|tracker)\.md')){
                    'Riferimento dossier legacy: '+$area.path+'/'+$name+':'+$lineNumber+': '+$match.Value
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
    foreach($project in $Entities|Where-Object {$_.kind -eq 'project' -and !$_.archived}){
        foreach($reference in $project.metadata.trackers){
            $area=@($Entities|Where-Object {$_.kind -eq 'area' -and $_.id -eq $reference.area})[0]
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
    # Il backupRoot predefinito e quello della configurazione dell'host corrente (workstation.json, anche migrato);
    # senza configurazione attiva resta .runtime/backups/transactions. Una configurazione presente ma non valida e un errore, non un fallback.
    $fallback=Join-Path $BrainRoot '.runtime/backups/transactions'
    $configPath=Get-SBHostConfigPath $BrainRoot
    if(!(Test-Path -LiteralPath $configPath -PathType Leaf)){return $fallback}
    $local=Read-SBJson $configPath $null
    if($local -is [Collections.IDictionary] -and $local.ContainsKey('migratedTo')){$local=Read-SBJson (Assert-SBCentralDataPath $BrainRoot $local.migratedTo) $null}
    if($local -isnot [Collections.IDictionary] -or !$local.ContainsKey('backupRoot') -or !$local.backupRoot){throw "Configurazione host senza backupRoot: $configPath"}
    $value=[string]$local.backupRoot
    if(![IO.Path]::IsPathFullyQualified($value)){$value=Join-Path $BrainRoot $value}
    Assert-SBCentralDataPath $BrainRoot $value
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
    # Perimetro cooperativo: se il chiamante dichiara il repository in lavoro, l'identita del tracker deve coincidere.
    if($WorkingRepository -and $Identity -cne $WorkingRepository){throw "Scrittura rifiutata: il tracker di '$Identity' non appartiene al repository in lavoro '$WorkingRepository'"}
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
    $trackerPath=''
    $data=$null
    if($Path){
        $trackerPath=[IO.Path]::GetFullPath($Path)
        Assert-SBPlainPath $trackerPath
        if(!(Test-Path -LiteralPath $trackerPath -PathType Leaf)){throw "File tracker inesistente: $trackerPath"}
        $data=Read-SBJson $trackerPath $null
        if(!$Identity){$Identity=[string]$data.repository}
        if($WorkingRepository -and $Identity -cne $WorkingRepository){throw "Scrittura rifiutata: il tracker di '$Identity' non appartiene al repository in lavoro '$WorkingRepository'"}
    }else{
        if(!$Identity){throw 'Identity o Path obbligatorio'}
        if(!(Test-SBTrackerPolicy $BrainRoot)){throw "Contratto tracker non approvato: $Identity"}
        $entities=@(Get-SBParaEntities $BrainRoot @())
        $areas=@($entities|Where-Object {$_.kind -eq 'area' -and $_.repository -eq $Identity})
        if($areas.Count -ne 1){throw "Identita tracker non associata a una sola Area: $Identity"}
        $dir=Resolve-SBParaPath $BrainRoot $areas[0].path
        $metadata=Read-SBJson (Join-Path $dir 'repository.json') @{}
        if(!$metadata.ContainsKey('tracker')){throw "Dossier senza dichiarazione tracker: $Identity"}
        $declaration=$metadata.tracker
        if($declaration -isnot [Collections.IDictionary] -or $declaration.location -ne 'dossier' -or $declaration.path -cne 'tracker.json' -or $declaration.schemaVersion -ne 1){throw "Dichiarazione tracker non valida: $Identity"}
        $trackerPath=Resolve-SBParaPath $dir $declaration.path
        if(!(Test-Path -LiteralPath $trackerPath -PathType Leaf)){throw "Tracker dichiarato assente: $trackerPath"}
        $data=Read-SBJson $trackerPath $null
    }
    if($data.schemaVersion -ne 1){throw 'Schema tracker non supportato (atteso v1)'}
    if($Status -notin @('todo','in_progress','blocked','done','cancelled','unknown')){
        throw "Stato non valido: $Status. Valori ammessi: todo, in_progress, blocked, done, cancelled, unknown"
    }
    $matching=@($data.tasks|Where-Object {$_.id -eq $TaskId})
    if($matching.Count -ne 1){throw "Task non trovato nel tracker: $TaskId"}
    
    $next=ConvertTo-SBJson $data|ConvertFrom-Json -AsHashtable -DateKind String
    $targetTask=@($next.tasks|Where-Object {$_.id -eq $TaskId})[0]
    $targetTask.status=$Status
    if($PSBoundParameters.ContainsKey('StateReason')){
        if(!$targetTask.ContainsKey('extensions') -or $null -eq $targetTask.extensions){$targetTask.extensions=@{}}
        if($StateReason){$targetTask.extensions.stateReason=$StateReason}
        else{$targetTask.extensions.Remove('stateReason')}
    }
    if($Evidence -and @($Evidence).Count -gt 0){
        if(!$targetTask.ContainsKey('evidence') -or $null -eq $targetTask.evidence){$targetTask.evidence=@()}
        foreach($ev in @($Evidence)){$targetTask.evidence+=,$ev}
    }
    $next.updatedAt=[DateTimeOffset]::UtcNow.ToString('o')
    
    $entities=@(Get-SBParaEntities $BrainRoot @())
    $managedIdentities=@($entities|Where-Object kind -eq 'area'|ForEach-Object repository)
    if($Identity -notin $managedIdentities){$managedIdentities+=,$Identity}
    $schemaPath=Join-Path $PSScriptRoot '../config/tracker.schema.json'
    $related=Get-SBTrackerRelatedData $BrainRoot $Identity $entities
    [void](Test-SBTrackerData $next $Identity $managedIdentities $schemaPath $related)
    
    if($WhatIf){
        return @{applied=$false;taskId=$TaskId;status=$Status;path=$trackerPath;data=$next}
    }
    if(!$BackupRoot){$BackupRoot=Resolve-SBTrackerBackupRoot $BrainRoot}
    [IO.Directory]::CreateDirectory($BackupRoot)|Out-Null
    $oldHash=Get-SBFileHash $trackerPath
    $newBytes=[Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $next))
    $ops=@(@{path=$trackerPath;expected=$oldHash;bytes=$newBytes})
    $manifest=Invoke-SBParaTransaction -Operations $ops -BackupRoot $BackupRoot -BrainRoot $BrainRoot
    @{applied=$true;taskId=$TaskId;status=$Status;manifest=$manifest;path=$trackerPath;data=$next}
}
function Update-SBTrackerTask {
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
    Set-SBTrackerTaskStatus @PSBoundParameters
}

Export-ModuleMember -Function *-SBTracker*,Get-SBCuratedReferenceIssues
