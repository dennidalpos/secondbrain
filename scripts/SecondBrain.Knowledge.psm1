#requires -Version 7.5
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Para.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Tracker.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Trace.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Add-SBMessages @{
    'knowledge.tracker.data' = @{ it = 'Tracker data non disponibile'; en = 'Tracker data not available' }
    'knowledge.paging.invalid' = @{ it = 'Offset e Limit devono essere interi non negativi'; en = 'Offset and Limit must be non-negative integers' }
    'knowledge.record.missing' = @{ it = 'repository.json assente'; en = 'repository.json missing' }
    'knowledge.dossier.invalid' = @{ it = 'Dossier non valido'; en = 'Invalid dossier' }
    'knowledge.repository.required' = @{ it = 'Repository non specificato: indicare il repository in lavoro oppure -All per la vista globale in sola lettura'; en = 'Repository not specified: give the working repository or -All for the read-only global view' }
    'knowledge.dossier.none' = @{ it = 'Nessun dossier attivo per il repository: {0}'; en = 'No active dossier for repository: {0}' }
    'knowledge.dossier.ambiguous' = @{ it = 'Dossier non risolto in modo univoco per il repository: {0}'; en = 'Dossier not uniquely resolved for repository: {0}' }
    'knowledge.lifecycle.invalid' = @{ it = 'lifecycle non valido in repository.json: ammesso soltanto greenfield'; en = 'Invalid lifecycle in repository.json: only greenfield is allowed' }
    'knowledge.tracker.unavailable' = @{ it = 'Tracker non disponibile per il dossier'; en = 'Tracker not available for the dossier' }
    'knowledge.task.ambiguous' = @{ it = 'Piu task corrispondono a: {0}'; en = 'Several tasks match: {0}' }
    'knowledge.task.notfound' = @{ it = 'Task non trovato: {0}'; en = 'Task not found: {0}' }
    'knowledge.source.invalid' = @{ it = 'Fonte non valida: usare context, memory, history oppure history/<cartella>'; en = 'Invalid source: use context, memory, history or history/<folder>' }
    'knowledge.section.notfound' = @{ it = 'Sezione non trovata: {0}'; en = 'Section not found: {0}' }
    'knowledge.dossier.unspecified' = @{ it = 'Dossier non indicato: eseguire dal checkout del repository o passare -Dossier (assoluto o relativo alla radice SecondBrain)'; en = 'Dossier not specified: run from the repository checkout or pass -Dossier (absolute or relative to the SecondBrain root)' }
    'knowledge.dossier.archived' = @{ it = 'Dossier archiviato: compattazione non autorizzata implicitamente'; en = 'Archived dossier: compaction is not implicitly authorized' }
    'knowledge.candidate.review' = @{ it = 'Candidato richiede revisione esplicita dellʼagente e motivazione'; en = 'Candidate requires explicit agent review and a reason' }
    'knowledge.candidate.repository' = @{ it = 'Candidato di un altro repository'; en = 'Candidate belongs to another repository' }
    'knowledge.source.changed' = @{ it = 'Fonte modificata dopo la preparazione: {0}'; en = 'Source changed after preparation: {0}' }
    'knowledge.summary.missing' = @{ it = 'Sintesi assente: {0}'; en = 'Summary missing: {0}' }
    'knowledge.section.essential' = @{ it = 'Sezione essenziale assente: {0}'; en = 'Essential section missing: {0}' }
    'knowledge.original.diverged' = @{ it = 'Originale archiviato divergente'; en = 'Archived original diverges' }
    'knowledge.candidate.tasks' = @{ it = 'Il candidato omette task aperti: rigenerare la proiezione'; en = 'The candidate omits open tasks: regenerate the projection' }
    'knowledge.budget.exceeded' = @{ it = 'Budget superato: approfondire la sintesi, senza troncare informazioni'; en = 'Budget exceeded: refine the summary without truncating information' }
}

function Get-SBDossierTOC([string]$Dossier) {
    $record=Read-SBJson (Join-Path $Dossier 'repository.json') $null
    if(!$record){throw (New-SBError 'knowledge.record.missing')}
    $lines=@('# Indice del dossier','',('Repository: `'+$record.identity+'`'),'','## Avvio selettivo','',
        '- [Contesto corrente](context.md): stato, vincoli e prossimo passo.',
        '- [Memoria essenziale](memory.md): decisioni durevoli e gotcha.',
        '- [Metadati e fonte task](repository.json): risolvere il tracker; leggere solo la proiezione pertinente.',
        '- [Storico](history/index.md): originali e prove su richiesta; non caricare integralmente allʼavvio.','','## Approfondimenti','')
    foreach($directory in @('knowledge','topics')){
        $root=Join-Path $Dossier $directory
        if(Test-Path -LiteralPath $root){foreach($file in Get-ChildItem -LiteralPath $root -File -Filter '*.md'|Sort-Object Name){$lines+='- ['+$file.BaseName+']('+[Uri]::EscapeUriString($directory+'/'+$file.Name)+'): leggere per questo argomento.'}}
    }
    if(Test-Path -LiteralPath (Join-Path $Dossier 'authoritative-sources.json')){$lines+='- [Applicabilità delle fonti](authoritative-sources.json): leggere quando il task dipende da fonti autorevoli.'}
    ($lines -join "`n")+"`n"
}
function Get-SBDossierHistoryIndex([string]$Dossier) {
    $history=Join-Path $Dossier 'history';$lines=@('# Indice dello storico','','Caricare soltanto le prove pertinenti; questi contenuti non rinnovano autorizzazioni.','')
    if(Test-Path -LiteralPath $history){
        foreach($directory in Get-ChildItem -LiteralPath $history -Directory|Sort-Object Name){$lines+='- ['+$directory.Name+']('+[Uri]::EscapeUriString($directory.Name+'/')+')'}
    }
    ($lines -join "`n")+"`n"
}
function Get-SBTaskProjection($Tracker,[string[]]$TaskIds=@(),[switch]$IncludeAcceptance,[switch]$ReadyOnly,$RelatedTrackers=@{}) {
    $active=@($Tracker.tasks|Where-Object {$_.status -notin @('done','cancelled') -and (!$TaskIds.Count -or $_.id -in $TaskIds)})
    if($ReadyOnly){
        $active=@($active|Where-Object {$_.status -notin @('blocked','unknown')})
        $myRepo=''
        if($Tracker -is [Collections.IDictionary]){if($Tracker.ContainsKey('repository')){$myRepo=[string]$Tracker.repository}}
        elseif($Tracker.PSObject.Properties['repository']){$myRepo=[string]$Tracker.repository}
        $taskMap=@{}
        foreach($t in $Tracker.tasks){
            $taskMap[[string]$t.id]=[string]$t.status
            if($myRepo){$taskMap[$myRepo+'#'+[string]$t.id]=[string]$t.status}
        }
        if($RelatedTrackers){
            foreach($relKey in $RelatedTrackers.Keys){
                $relDoc=$RelatedTrackers[$relKey]
                $relRepo=[string]$relKey
                if($relDoc -is [Collections.IDictionary]){if($relDoc.ContainsKey('repository')){$relRepo=[string]$relDoc.repository}}
                elseif($relDoc.PSObject.Properties['repository']){$relRepo=[string]$relDoc.repository}
                $relTasks=@()
                if($relDoc -is [Collections.IDictionary]){if($relDoc.ContainsKey('tasks')){$relTasks=@($relDoc.tasks)}}
                elseif($relDoc.PSObject.Properties['tasks']){$relTasks=@($relDoc.tasks)}
                foreach($t in $relTasks){$taskMap[$relRepo+'#'+[string]$t.id]=[string]$t.status}
            }
        }
        $filtered=@()
        foreach($candidate in $active){
            $ready=$true
            if($candidate.dependencies){
                foreach($dep in @($candidate.dependencies)){
                    $depId=''
                    $depRepo=$myRepo
                    if($dep -is [string]){$depId=$dep}
                    elseif($dep -is [Collections.IDictionary]){
                        if($dep.ContainsKey('id')){$depId=[string]$dep.id}
                        if($dep.ContainsKey('repository') -and $dep.repository){$depRepo=[string]$dep.repository}
                    }else{
                        if($dep.PSObject.Properties['id']){$depId=[string]$dep.id}
                        if($dep.PSObject.Properties['repository'] -and $dep.repository){$depRepo=[string]$dep.repository}
                    }
                    $status=$null
                    if($depRepo -and $taskMap.ContainsKey($depRepo+'#'+$depId)){$status=$taskMap[$depRepo+'#'+$depId]}
                    elseif($taskMap.ContainsKey($depId)){$status=$taskMap[$depId]}
                    if(!$status -or $status -notin @('done','completed')){$ready=$false;break}
                }
            }
            if($ready){$filtered+=$candidate}
        }
        $active=$filtered
    }
    @($active|ForEach-Object {
        $task=@{id=$_.id;title=$_.title;status=$_.status;priority=$_.priority;dependencies=$_.dependencies;blocker=$(if($_.extensions.ContainsKey('stateReason')){$_.extensions.stateReason}else{''})}
        if($_.ContainsKey('seq')){$task.seq=$_.seq}
        if($IncludeAcceptance){$task.acceptance=$_.acceptance}
        $task
    })
}
# Livelli di un file Markdown di dossier: una sezione `## ` e storica se il titolo finisce con (storico) o se la sua prima riga non vuota e <!-- sb:tier=history -->.
# Il testo prima della prima sezione e le sezioni senza marcatore sono essenziali. Senza marcatori il file e interamente essenziale.
function Split-SBTieredMarkdown([string]$Text) {
    $normalized=$Text.Replace("`r`n","`n")
    $chunks=[regex]::Split($normalized,'(?m)^(?=## )')
    $essential=[Text.StringBuilder]::new();$history=[Text.StringBuilder]::new();$titles=@()
    foreach($chunk in $chunks){
        if(!$chunk){continue}
        $isHistory=$false;$title=''
        if($chunk.StartsWith('## ')){
            $lines=$chunk -split "`n"
            $title=$lines[0].Substring(3).Trim()
            $firstBody=@($lines|Select-Object -Skip 1|Where-Object {$_.Trim()}|Select-Object -First 1)
            $isHistory=($title -match '(?i)\(storico\)\s*$') -or ($firstBody.Count -eq 1 -and $firstBody[0].Trim() -match '^<!--\s*sb:tier=history\s*-->$')
        }
        if($isHistory){[void]$history.Append($chunk);$titles+=$title}else{[void]$essential.Append($chunk)}
    }
    @{essential=$essential.ToString();history=$history.ToString();historyTitles=$titles}
}
# Vista per agenti di memory.md (memory.agent.md): file derivato, mai modificato a mano. Una voce per riga, `- [T#id] data · scope · testo`,
# con T = D decisione, G gotcha, A architettura, C vincolo. Contiene le sole parti essenziali; le voci in forma libera (storiche) sono classificate
# dal titolo di sezione o dal prefisso (Decisione:/Gotcha:) con data `s.d.`. L'intestazione riporta l'hash della fonte: allineamento verificato da -Check.
function Get-SBAgentViewType([string]$Heading,[string]$Text) {
    if($Text -match '^(?i)decisione\s*:'){return 'D'}
    if($Text -match '^(?i)gotcha\s*:'){return 'G'}
    if($Heading -match '(?i)decision'){return 'D'}
    if($Heading -match '(?i)lesson|gotcha'){return 'G'}
    if($Heading -match '(?i)vincol|constraint|identit|font[ei]'){return 'C'}
    'A'
}
function ConvertTo-SBAgentMemoryView([string]$MemoryText) {
    $normalized=$MemoryText.Replace("`r`n","`n")
    $sourceHash=Get-SBTextHash $normalized
    $essential=(Split-SBTieredMarkdown $normalized).essential
    $entries=[Collections.Generic.List[object]]::new();$seen=@{};$heading='';$fence=$false
    $schema='^\[(?<t>[DGAC])\]\s+(?<d>\d{4}-\d{2}-\d{2}|s\.d\.)\s+·\s+(?<s>[^·]+?)\s+·\s+(?<x>.+)$'
    $add={
        param([string]$Raw)
        $text=([regex]::Replace(($Raw -replace '\*\*',''),'\s+',' ')).Trim()
        if(!$text -or $text -match '^Originale conservato:'){return}
        if($text -match $schema){$type=$Matches.t;$date=$Matches.d;$scope=$Matches.s.Trim();$body=$Matches.x.Trim()}
        else{$type=Get-SBAgentViewType $heading $text;$date='';$scope='';$body=$text}
        $id=(Get-SBTextHash $body).Substring(0,6).ToLowerInvariant()
        if($seen.ContainsKey($id)){return}
        $seen[$id]=$true
        $entries.Add(@{type=$type;id=$id;date=$date;scope=$scope;text=$body})
    }
    $pending=$null
    foreach($line in ($essential -split "`n")){
        if($line -match '^\s*(```|~~~)'){$fence=!$fence;continue}
        if($fence){continue}
        if($line -match '^#{1,6}\s+(?<h>.+?)\s*$'){if($null -ne $pending){& $add $pending;$pending=$null};$heading=$Matches.h;continue}
        if($line -match '^[-*]\s+(?<x>.*)$'){if($null -ne $pending){& $add $pending};$pending=$Matches.x;continue}
        if(!$line.Trim()){if($null -ne $pending){& $add $pending;$pending=$null};continue}
        if($null -ne $pending){$pending+=' '+$line.Trim()}else{$pending=$line.Trim()}
    }
    if($null -ne $pending){& $add $pending}
    $out=[Collections.Generic.List[string]]::new()
    $out.Add('<!-- sb:agent-view v1 source='+$sourceHash+' -->')
    $out.Add('# Memoria (vista per agenti)')
    $out.Add('')
    $out.Add('Derivata da memory.md, non modificare. Voce: `[T#id] [data · scope ·] testo`; T = D decisione, G gotcha, A architettura, C vincolo.')
    $out.Add('')
    foreach($entry in $entries){$out.Add('- ['+$entry.type+'#'+$entry.id+'] '+$(if($entry.date){$entry.date+' · '+$entry.scope+' · '}else{''})+$entry.text)}
    ($out -join "`n")+"`n"
}
function Format-SBSlimTasks($Projection) {
    # Una riga per task pronto: ID, priorita, stato, titolo. Descrizione, criteri ed evidenze restano a get_task / knowledge.ps1 -Task.
    $rows=@()
    foreach($task in @($Projection)){
        if($null -eq $task){continue}
        $blocker=if($task -is [Collections.IDictionary] -and $task.Contains('blocker')){[string]$task['blocker']}else{''}
        # Il motivo è abbreviato: il testo completo resta nel tracker (get_task).
        if($blocker.Length -gt 90){$blocker=$blocker.Substring(0,90).TrimEnd()+'…'}
        $rows+=('- '+$task['id']+' ['+$task['priority']+'/'+$task['status']+'] '+$task['title']+$(if($blocker){' (motivo: '+$blocker+')'}else{''}))
    }
    if(!$rows.Count){return "Nessun task pronto.`n"}
    ('Task pronti ('+$rows.Count+'):',($rows -join "`n")) -join "`n"
}
function Get-SBStartupContext {
    param([string]$BrainRoot,[string]$Dossier,[string]$CheckoutPath,[string[]]$TaskIds=@(),[int]$Budget=50000,$Entities=@(),[switch]$ReadyOnly,[ValidateSet('Slim','Full')][string]$Profile='Full')
    $record=Read-SBJson (Join-Path $Dossier 'repository.json') $null
    if(!$record){throw (New-SBError 'knowledge.dossier.invalid')}
    $slim=($Profile -eq 'Slim')
    $toc=Get-SBDossierTOC $Dossier
    $tracker=Resolve-SBTracker -BrainRoot $BrainRoot -Identity $record.identity -CheckoutPath $CheckoutPath -DossierPath $Dossier -AllowedOwners @() -Entities $Entities
    $contextText=Read-SBText (Join-Path $Dossier 'context.md');$memoryText=Read-SBText (Join-Path $Dossier 'memory.md')
    $viewPath=Join-Path $Dossier 'memory.agent.md'
    $viewHash=if($slim -and [IO.File]::Exists($viewPath)){Get-SBFileHash $viewPath}else{''}
    New-SBStartupPackage -Record $record -Tracker $tracker -TOC $toc -ContextText $contextText -MemoryText $memoryText -AgentViewHash $viewHash -TaskIds $TaskIds -Budget $Budget -ReadyOnly:$ReadyOnly -Profile $Profile
}
# Compose the startup package from a resolved snapshot, without reading or writing files.
# Compaction supplies the final planned texts and agent view, before its transaction.
function New-SBStartupPackage {
    param($Record,$Tracker,[string]$TOC,[string]$ContextText,[string]$MemoryText,[string]$AgentViewHash,
        [string[]]$TaskIds=@(),[int]$Budget=50000,[switch]$ReadyOnly,[ValidateSet('Slim','Full')][string]$Profile='Full')
    $slim=($Profile -eq 'Slim')
    $trData=if($tracker.ContainsKey('data')){$tracker.data}else{$null}
    $trRel=if($tracker.ContainsKey('related')){$tracker.related}else{@{}}
    $projection=if($trData){@(Get-SBTaskProjection $trData $TaskIds -ReadyOnly:($ReadyOnly -or $slim) -RelatedTrackers $trRel)}else{@()}
    if(!$slim){
        $parts=@{index=$toc;context=$contextText;memory=$memoryText;tasks=(ConvertTo-SBJson $projection)}
        $omitted=@()
    }else{
        $contextTiers=Split-SBTieredMarkdown $contextText;$memoryTiers=Split-SBTieredMarkdown $memoryText
        $omitted=@()
        foreach($entry in @(@{name='context';tiers=$contextTiers;file='context.md'},@{name='memory';tiers=$memoryTiers;file='memory.md'})){
            if($entry.tiers.history.Length){$omitted+=@{part=$entry.name+' (storico)';characters=$entry.tiers.history.Length;sections=@($entry.tiers.historyTitles);how='knowledge.ps1 -Section "<titolo>", -Search "<termine>" oppure -Startup -Profile Full; file '+$entry.file}}
        }
        $omitted+=@{part='task: descrizioni, criteri di accettazione, task non pronti';characters=0;sections=@();how='knowledge.ps1 -Task <id|#seq> (dettaglio integro, anche archiviati), -Tasks (-All per la vista globale), oppure MCP get_task e get_ready_tasks'}
        $omitted+=@{part='storico del dossier (history/, knowledge/, topics/)';characters=0;sections=@();how='history/index.md e indice del dossier; knowledge.ps1 -Section <titolo> per una sezione intera, -Search per cercare anche in archivio tracker e rapporti (-Offset/-Limit)'}
        $levelLines=@('# Livelli non caricati','','Profilo Slim: sono caricate le sole parti essenziali. Nulla è stato eliminato; richiedi il resto quando serve.','')
        foreach($item in $omitted){$levelLines+=('- '+$item.part+$(if($item.characters){' — '+$item.characters+' caratteri'}else{''})+$(if(@($item.sections).Count){' ('+(@($item.sections) -join '; ')+')'}else{''})+': '+$item.how)}
        # Memoria: la vista per agenti, se allineata alla fonte (stesso hash), sostituisce le parti essenziali di memory.md.
        $memorySlim=$memoryTiers.essential
        if($AgentViewHash){
            $viewExpected=ConvertTo-SBAgentMemoryView $memoryText
            if($AgentViewHash -eq (Get-SBTextHash $viewExpected)){$memorySlim=$viewExpected}
        }
        $parts=@{index=$toc;context=$contextTiers.essential;memory=$memorySlim;tasks=(Format-SBSlimTasks $projection);levels=(($levelLines -join "`n")+"`n")}
    }
    $characters=($parts.Values|Measure-Object -Property Length -Sum).Sum
    @{repository=$record.identity;profile=$Profile;budget=$Budget;characters=$characters;withinBudget=($Budget -le 0 -or $characters -le $Budget);needsCompaction=($Budget -gt 0 -and $characters -gt $Budget);
      parts=$parts;loadedParts=@($parts.Keys|Sort-Object);omittedParts=@($omitted);taskSource=$tracker.path;originalsTruncated=$false;unit='characters-not-tokens'}
}
# Tetto del primo caricamento (profilo Slim): fonte unica per knowledge.ps1 -Startup e per secondbrain.ps1 -Check.
function Get-SBSlimStartupBudget { 20000 }
# Avviso di compattazione (sola lettura): hard se il pacchetto Slim supera il tetto, soft se e vicino al tetto o se i turni tracciati
# dall'ultima compattazione sono molti. Non compatta mai: l'applicazione resta su richiesta (SYS05).
function Get-SBCompactionAdvice($Startup,[string]$BrainRoot,[string]$Dossier,[int]$SoftPercent=80,[int]$SoftTurns=50,[int]$SoftTurnsPercent=60) {
    $percent=if($Startup.budget -gt 0){[int][Math]::Floor(100.0*$Startup.characters/$Startup.budget)}else{0}
    $last=[DateTimeOffset]::MinValue
    $manifests=Join-Path $Dossier 'history/compaction'
    if(Test-Path -LiteralPath $manifests -PathType Container){
        foreach($file in Get-ChildItem -LiteralPath $manifests -File -Filter '*.json' -Force){if([DateTimeOffset]$file.LastWriteTimeUtc -gt $last){$last=[DateTimeOffset]$file.LastWriteTimeUtc}}
    }
    $turns=Get-SBTraceTurns $BrainRoot $Startup.repository $last
    $level='none'
    if($Startup.budget -gt 0 -and $Startup.characters -gt $Startup.budget){$level='hard'}
    elseif($Startup.budget -gt 0 -and ($percent -ge $SoftPercent -or ($turns -ge $SoftTurns -and $percent -ge $SoftTurnsPercent))){$level='soft'}
    @{level=$level;characters=$Startup.characters;budget=$Startup.budget;percent=$percent;turnsSinceCompaction=$turns;lastCompactionUtc=$(if($last -eq [DateTimeOffset]::MinValue){$null}else{$last.UtcDateTime.ToString('o')})}
}
# Rapporto di sola lettura: caratteri per parte, stima token (caratteri/4, non esatta), parti omesse e peso delle direttive caricate.
function Format-SBStartupReport($Startup,[hashtable]$Directives=@{}) {
    $lines=@('RAPPORTO CONTESTO DI AVVIO','',('Repository: '+$Startup.repository),('Profilo: '+$Startup.profile+' | budget '+$(if($Startup.budget -gt 0){[string]$Startup.budget+' caratteri'}else{'nessun tetto'})+' | usati '+$Startup.characters+' (stima ~'+[int][Math]::Ceiling($Startup.characters/4)+' token, caratteri/4)'),'')
    $lines+='Parti caricate:'
    foreach($name in ($Startup.parts.Keys|Sort-Object)){$lines+=('- {0,-8} {1,7} caratteri' -f $name,$Startup.parts[$name].Length)}
    if(@($Startup.omittedParts).Count){
        $lines+=@('','Parti non caricate (a richiesta):')
        foreach($item in $Startup.omittedParts){$lines+=('- '+$item.part+$(if($item.characters){': '+$item.characters+' caratteri'}else{''}))}
    }
    if($Directives.Count){
        $lines+=@('','Direttive sempre in contesto (fuori dal pacchetto di avvio):')
        foreach($key in ($Directives.Keys|Sort-Object)){$lines+=('- {0}: {1}' -f $key,$Directives[$key])}
    }
    $lines+=@('','Non incluso: prompt di sistema, definizioni degli strumenti MCP e skill dell''IDE; si vedono nel riepilogo del contesto dell''IDE.','Misure di caratteri, non di token (SYS06).')
    ($lines -join "`n")+"`n"
}
function Get-SBGlobalTasks([string]$BrainRoot,[string]$Repository='',[switch]$All,[switch]$ReadyOnly) {
    # Perimetro cooperativo: senza repository esplicito la vista globale richiede -All (sola lettura, ogni voce etichettata scope=global).
    if(!$Repository -and !$All){throw (New-SBError 'knowledge.repository.required')}
    $entities=@(Get-SBParaEntities $BrainRoot @())
    $areas=@($entities|Where-Object {$_.kind -eq 'area' -and !$_.archived -and (!$Repository -or $_.repository -eq $Repository)})
    if($Repository -and !$areas.Count){throw (New-SBError 'knowledge.dossier.none' @($Repository))}
    $scope=if($Repository){'repository'}else{'global'}
    foreach($area in $areas){
        $dossier=Resolve-SBParaPath $BrainRoot $area.path
        try{
            $tr=Resolve-SBTracker -BrainRoot $BrainRoot -Identity $area.repository -AllowedOwners @() -DossierPath $dossier -Entities $entities
            $trData=if($tr.ContainsKey('data')){$tr.data}else{$null}
            if(!$trData){@{repository=$area.repository;status='unverified';reasonCode='tracker-unavailable';reason=(Get-SBMessage 'knowledge.tracker.data');scope=$scope};continue}
            $rel=if($tr.ContainsKey('related') -and $tr.related){$tr.related}else{@{}}
            foreach($task in @(Get-SBTaskProjection $trData -ReadyOnly:$ReadyOnly -RelatedTrackers $rel)){
                $task.repository=$area.repository
                $task.source=$tr.path
                $task.scope=$scope
                $task
            }
        }catch{@{repository=$area.repository;status='unverified';reason=$_.Exception.Message;scope=$scope}}
    }
}
function Get-SBGlobalTaskPage([string]$BrainRoot,[int]$Offset=0,[int]$Limit=50,[switch]$ReadyOnly) {
    # Vista globale paginata (stessa forma per CLI e MCP): Limit 0 = tutte le voci; nextOffset per la pagina successiva.
    if($Offset -lt 0 -or $Limit -lt 0){throw (New-SBError 'knowledge.paging.invalid')}
    $tasks=@(Get-SBGlobalTasks -BrainRoot $BrainRoot -All -ReadyOnly:$ReadyOnly)
    $page=@($tasks|Select-Object -Skip $Offset)
    if($Limit -gt 0){$page=@($page|Select-Object -First $Limit)}
    $hasMore=($Offset+$page.Count) -lt $tasks.Count
    @{total=$tasks.Count;offset=$Offset;limit=$Limit;count=$page.Count;hasMore=$hasMore;nextOffset=$(if($hasMore){$Offset+$page.Count}else{$null});tasks=$page}
}
function Resolve-SBWorkingDossier([string]$BrainRoot,[string]$Repository) {
    # Dossier (percorso relativo al cervello) dell'unico Area attiva del repository.
    $found=@(Get-SBParaEntities $BrainRoot @()|Where-Object {$_.kind -eq 'area' -and !$_.archived -and $_.repository -ceq $Repository})
    if($found.Count -ne 1){throw (New-SBError 'knowledge.dossier.ambiguous' @($Repository))}
    $found[0].path
}
function Get-SBSearchTokens([string]$Query) {
    # Termini distinti della richiesta, senza maiuscole e senza parole vuote; se restano solo parole vuote si usano tutti i termini.
    $stop=@('il','lo','la','le','gli','un','una','uno','di','del','della','dei','delle','da','dal','in','nel','nella','con','su','per','tra','fra','che','the','and','for','with','from','into','of','to','an')
    $all=@([regex]::Split($Query.ToLowerInvariant(),'[^\p{L}\p{N}_-]+')|Where-Object {$_.Length -ge 2}|Select-Object -Unique)
    $kept=@($all|Where-Object {$_ -notin $stop})
    if($kept.Count){$kept}else{$all}
}
function Split-SBSearchUnits([string[]]$Lines,[bool]$Markdown) {
    # Unita di ricerca: sezioni (titolo # fino al successivo) per Markdown, blocchi separati da righe vuote (max 40 righe) per gli altri file.
    $units=[Collections.Generic.List[object]]::new()
    $current=@{title='';start=1;lines=[Collections.Generic.List[string]]::new()}
    $fence=$false;$number=0
    foreach($line in $Lines){
        $number++
        if($Markdown){
            if($line -match '^\s*(```|~~~)'){$fence=!$fence}
            if(!$fence -and $line -match '^#{1,6}\s+(?<title>.+?)\s*$'){
                if($current.lines.Count){$units.Add($current)}
                $current=@{title=$Matches.title;start=$number;lines=[Collections.Generic.List[string]]::new()}
            }
        }elseif(($current.lines.Count -ge 40) -or ([string]::IsNullOrWhiteSpace($line) -and $current.lines.Count)){
            $units.Add($current)
            $current=@{title='';start=$number;lines=[Collections.Generic.List[string]]::new()}
        }
        $current.lines.Add($line)
    }
    if($current.lines.Count){$units.Add($current)}
    $units
}
function Get-SBSearchDefaultLimit { 20 }
function Get-SBSearchDefaultBudget { 10000 }
function Limit-SBSearchLine([string]$Text,[int]$Max=600) {
    # Riga lunga troncata con marcatore (la riga intera si legge con -Section o aprendo il file).
    if($Text.Length -le $Max){return $Text}
    $Text.Substring(0,$Max)+' [...+'+($Text.Length-$Max)+' car]'
}
function Find-SBKnowledge {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$BrainRoot,
        [Parameter(Mandatory)][string]$Search,
        [string]$Dossier='',
        [string]$Repository='',
        # -1 = valore predefinito (Get-SBSearchDefaultLimit / Get-SBSearchDefaultBudget); 0 = nessun tetto esplicito.
        [ValidateRange(-1,[int]::MaxValue)][int]$Budget=-1,
        $Entities=@(),
        [ValidateSet('Literal','Relevance')][string]$Mode='Literal',
        [ValidateRange(0,[int]::MaxValue)][int]$Offset=0,
        [ValidateRange(-1,[int]::MaxValue)][int]$Limit=-1,
        [switch]$IncludeOriginals
    )
    if($Budget -lt 0){$Budget=Get-SBSearchDefaultBudget}
    if($Limit -lt 0){$Limit=Get-SBSearchDefaultLimit}
    $root=[IO.Path]::GetFullPath($BrainRoot)
    $targetDirs=@()
    if($Dossier){
        $resolved=[IO.Path]::GetFullPath($Dossier)
        if(!(Test-Path -LiteralPath $resolved)){$resolved=Resolve-SBParaPath $root $Dossier}
        $targetDirs=@($resolved)
    }elseif($Repository){
        if(!$Entities.Count){$Entities=@(Get-SBParaEntities $root @())}
        $targetDirs=@($Entities|Where-Object {$_.kind -eq 'area' -and !$_.archived -and $_.repository -eq $Repository}|ForEach-Object {Resolve-SBParaPath $root $_.path})
    }else{
        if(!$Entities.Count){$Entities=@(Get-SBParaEntities $root @())}
        $targetDirs=@($Entities|Where-Object {$_.kind -eq 'area' -and !$_.archived}|ForEach-Object {Resolve-SBParaPath $root $_.path})
    }
    $extracts=[Collections.Generic.List[object]]::new()
    $candidates=[Collections.Generic.List[object]]::new()
    $totalChars=0
    if([string]::IsNullOrWhiteSpace($Search)){
        return @{search=$Search;query=$Search;mode=$Mode;budget=$Budget;offset=$Offset;limit=$Limit;hasMore=$false;nextOffset=$null;characters=0;withinBudget=$true;totalMatches=0;count=0;extracts=@()}
    }
    $tokens=@();$rankUnits=[Collections.Generic.List[object]]::new()
    if($Mode -eq 'Relevance'){$tokens=@(Get-SBSearchTokens $Search)}
    foreach($dir in $targetDirs){
        if(!(Test-Path -LiteralPath $dir -PathType Container)){continue}
        $filesToSearch=[Collections.Generic.List[string]]::new()
        foreach($name in @('context.md','memory.md','tracker.json')){
            $candidate=Join-Path $dir $name
            if(Test-Path -LiteralPath $candidate -PathType Leaf){$filesToSearch.Add($candidate)}
        }
        # Gli originali compattati sono copie quasi identiche dei file correnti: cercati solo con -IncludeOriginals.
        $compactionDir=Join-Path $dir 'history/compaction'
        if($IncludeOriginals -and (Test-Path -LiteralPath $compactionDir -PathType Container)){
            foreach($item in (Get-ChildItem -LiteralPath $compactionDir -File -Recurse|Sort-Object FullName)){
                if($item.Extension -in @('.md','.json','.txt')){$filesToSearch.Add($item.FullName)}
            }
        }
        # Strato di approfondimento: task archiviati e rapporti dei lotti (sempre cercabili, a richiesta con Offset/Limit).
        $archiveFile=Join-Path $dir 'history/tracker-archive.json'
        if(Test-Path -LiteralPath $archiveFile -PathType Leaf){$filesToSearch.Add($archiveFile)}
        $historyDir=Join-Path $dir 'history'
        if(Test-Path -LiteralPath $historyDir -PathType Container){
            foreach($folder in (Get-ChildItem -LiteralPath $historyDir -Directory|Sort-Object Name)){
                $reportFile=Join-Path $folder.FullName 'report.md'
                if(Test-Path -LiteralPath $reportFile -PathType Leaf){$filesToSearch.Add($reportFile)}
            }
        }
        foreach($filePath in $filesToSearch){
            $hash=Get-SBFileHash $filePath
            $relPath=[IO.Path]::GetRelativePath($root,$filePath).Replace('\','/')
            $lines=(Read-SBText $filePath) -split '\r?\n'
            if($Mode -eq 'Relevance'){
                foreach($unit in @(Split-SBSearchUnits $lines ($filePath -like '*.md'))){$unit.path=$relPath;$unit.sha256=$hash;$rankUnits.Add($unit)}
                continue
            }
            $lineNum=0
            foreach($line in $lines){
                $lineNum++
                if($line.Contains($Search,[StringComparison]::OrdinalIgnoreCase)){
                    $trimmed=Limit-SBSearchLine $line.Trim()
                    $candidates.Add(@{extract=@{path=$relPath;line=$lineNum;sha256=$hash;text=$trimmed};size=($relPath.Length + $trimmed.Length + $hash.Length + 20)})
                }
            }
        }
    }
    $ranked=@()
    if($Mode -eq 'Relevance'){
        $phrase=$Search.Trim().ToLowerInvariant()
        foreach($unit in $rankUnits){
            $text=($unit.lines -join "`n").ToLowerInvariant();$heading=([string]$unit.title).ToLowerInvariant()
            $distinct=0;$headingHits=0;$occurrences=0
            foreach($token in $tokens){
                $count=([regex]::Matches($text,[regex]::Escape($token))).Count
                if($count){$distinct++;$occurrences+=$count}
                if($heading.Contains($token)){$headingHits++}
            }
            if(!$distinct){continue}
            # Copertura dei termini prima di tutto, poi titolo, frase esatta e frequenza (limitata).
            $score=$distinct*100+$headingHits*25+$(if($text.Contains($phrase)){50}else{0})+[Math]::Min($occurrences,20)
            $ranked+=@{unit=$unit;score=$score}
        }
        $ranked=@($ranked|Sort-Object @{Expression={$_.score};Descending=$true},@{Expression={$_.unit.path}},@{Expression={$_.unit.start}})
        foreach($entry in $ranked){
            $unit=$entry.unit;$lineNum=$unit.start-1
            foreach($line in $unit.lines){
                $lineNum++
                $lower=$line.ToLowerInvariant()
                if(!@($tokens|Where-Object {$lower.Contains($_)}).Count){continue}
                $trimmed=Limit-SBSearchLine $line.Trim()
                $candidates.Add(@{extract=@{path=$unit.path;line=$lineNum;sha256=$unit.sha256;text=$trimmed;score=$entry.score;section=[string]$unit.title};size=($unit.path.Length + $trimmed.Length + $unit.sha256.Length + 20)})
            }
        }
    }
    # Paginazione sull'elenco ordinato dei riscontri, poi tetto facoltativo di caratteri sulla pagina.
    $totalMatches=$candidates.Count
    $page=@($candidates|Select-Object -Skip $Offset)
    if($Limit -gt 0){$page=@($page|Select-Object -First $Limit)}
    # Il tetto di caratteri taglia la pagina al primo riscontro che lo supera (almeno uno e sempre incluso): la pagina resta contigua e nextOffset riprende da li.
    foreach($candidate in $page){
        if($Budget -gt 0 -and $extracts.Count -gt 0 -and $totalChars + $candidate.size -gt $Budget){break}
        $extracts.Add($candidate.extract)
        $totalChars += $candidate.size
    }
    $withinBudget=($page.Count -eq $extracts.Count)
    $hasMore=(($Offset + $extracts.Count) -lt $totalMatches)
    @{
        search=$Search
        query=$Search
        mode=$Mode
        tokens=@($tokens)
        units=@($ranked).Count
        budget=$Budget
        characters=$totalChars
        withinBudget=$withinBudget
        offset=$Offset
        limit=$Limit
        hasMore=$hasMore
        nextOffset=$(if($hasMore){$Offset + $extracts.Count}else{$null})
        totalMatches=$totalMatches
        count=$extracts.Count
        extracts=@($extracts)
    }
}
# Ciclo di vita del repository nel repository.json del dossier: assente (normale) oppure greenfield (blocco di versioni, changelog, migrazioni, alias e deprecations).
function Get-SBRepositoryLifecycle([string]$Dossier) {
    $record=Read-SBJson (Join-Path $Dossier 'repository.json') $null
    if(!$record -or !$record.ContainsKey('lifecycle')){return ''}
    if([string]$record.lifecycle -cne 'greenfield'){throw (New-SBError 'knowledge.lifecycle.invalid')}
    'greenfield'
}
function Set-SBRepositoryLifecycle {
    param([Parameter(Mandatory)][string]$Dossier,[Parameter(Mandatory)][ValidateSet('greenfield','none')][string]$Lifecycle,[Parameter(Mandatory)][string]$BackupRoot)
    $path=Join-Path $Dossier 'repository.json'
    $record=Read-SBJson $path $null
    if(!$record){throw (New-SBError 'knowledge.record.missing')}
    $before=$(if($record.ContainsKey('lifecycle')){[string]$record.lifecycle}else{''})
    if($Lifecycle -eq 'greenfield'){$record.lifecycle='greenfield'}else{[void]$record.Remove('lifecycle')}
    $changed=($before -ne $(if($Lifecycle -eq 'greenfield'){'greenfield'}else{''}))
    if($changed){[void](Write-SBFile $path ([Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $record))) (Get-SBFileHash $path) $BackupRoot)}
    @{repository=$record.identity;lifecycle=$(if($Lifecycle -eq 'greenfield'){'greenfield'}else{''});changed=$changed}
}
function Get-SBTaskDetail {
    # Dettaglio integro di un task per id o seq (anche "#203"), dal tracker attivo o dall'archivio del dossier.
    param([Parameter(Mandatory)][string]$BrainRoot,[Parameter(Mandatory)][string]$Dossier,[Parameter(Mandatory)][string]$Task,[string]$CheckoutPath)
    $record=Read-SBJson (Join-Path $Dossier 'repository.json') $null
    if(!$record){throw (New-SBError 'knowledge.dossier.invalid')}
    $tracker=Resolve-SBTracker -BrainRoot $BrainRoot -Identity $record.identity -CheckoutPath $CheckoutPath -DossierPath $Dossier -AllowedOwners @()
    if(!$tracker.ContainsKey('data') -or !$tracker.data){throw (New-SBError 'knowledge.tracker.unavailable')}
    $key=$Task.Trim();$seq=0
    $bySeq=($key -match '^#?\d+$') -and [int]::TryParse($key.TrimStart('#'),[ref]$seq)
    $sources=@(@{name='tracker';tasks=@($tracker.data.tasks);path=[string]$tracker.path})
    $archivePath=Join-Path $Dossier 'history/tracker-archive.json'
    $archive=Read-SBJson $archivePath $null
    if($archive -and $archive.ContainsKey('tasks')){$sources+=@{name='archive';tasks=@($archive.tasks);path=$archivePath}}
    foreach($source in $sources){
        $found=@($source.tasks|Where-Object {if($bySeq){$_.ContainsKey('seq') -and [int]$_.seq -eq $seq}else{[string]$_.id -ieq $key}})
        if($found.Count -gt 1){throw (New-SBError 'knowledge.task.ambiguous' @($Task))}
        if($found.Count){return @{repository=$record.identity;source=$source.name;path=[IO.Path]::GetRelativePath([IO.Path]::GetFullPath($BrainRoot),$source.path).Replace('\','/');task=$found[0]}}
    }
    throw (New-SBError 'knowledge.task.notfound' @($Task))
}
function Get-SBMarkdownSections([string[]]$Lines) {
    # Sezioni di un Markdown: intestazione di qualunque livello fino alla successiva dello stesso livello o superiore (sottosezioni incluse); i blocchi di codice non contano.
    $headings=@();$fence=$false;$number=0
    foreach($line in $Lines){
        $number++
        if($line -match '^\s*(```|~~~)'){$fence=!$fence;continue}
        if(!$fence -and $line -match '^(?<marks>#{1,6})\s+(?<title>.+?)\s*$'){$headings+=@{title=$Matches.title;level=$Matches.marks.Length;start=$number;end=$Lines.Count}}
    }
    for($i=0;$i -lt $headings.Count;$i++){
        for($j=$i+1;$j -lt $headings.Count;$j++){if($headings[$j].level -le $headings[$i].level){$headings[$i].end=$headings[$j].start-1;break}}
    }
    $headings
}
function Get-SBSection {
    # Sezione intera per titolo da context.md, memory.md e history/*/report.md (Source: context, memory, history, history/<cartella>).
    param([Parameter(Mandatory)][string]$BrainRoot,[Parameter(Mandatory)][string]$Dossier,[Parameter(Mandatory)][string]$Title,[string]$Source='')
    $root=[IO.Path]::GetFullPath($BrainRoot)
    $record=Read-SBJson (Join-Path $Dossier 'repository.json') $null
    if(!$record){throw (New-SBError 'knowledge.dossier.invalid')}
    $files=@()
    $wanted=$Source.Trim().Trim('/').ToLowerInvariant()
    if($wanted -and $wanted -notmatch '^(context|memory|history(/[^/\\]+)?)$'){throw (New-SBError 'knowledge.source.invalid')}
    if(!$wanted -or $wanted -eq 'context'){$files+=Join-Path $Dossier 'context.md'}
    if(!$wanted -or $wanted -eq 'memory'){$files+=Join-Path $Dossier 'memory.md'}
    if(!$wanted -or $wanted -eq 'history'){
        $historyDir=Join-Path $Dossier 'history'
        if(Test-Path -LiteralPath $historyDir -PathType Container){foreach($folder in Get-ChildItem -LiteralPath $historyDir -Directory|Sort-Object Name){$files+=Join-Path $folder.FullName 'report.md'}}
    }elseif($wanted -like 'history/*'){$files+=Join-Path $Dossier ($wanted+'/report.md')}
    $wantedTitle=$Title.Trim()
    $exact=@();$partial=@()
    foreach($file in $files){
        if(!(Test-Path -LiteralPath $file -PathType Leaf)){continue}
        $lines=(Read-SBText $file) -split '\r?\n'
        $hash=Get-SBFileHash $file
        foreach($section in @(Get-SBMarkdownSections $lines)){
            $hit=@{path=[IO.Path]::GetRelativePath($root,$file).Replace('\','/');sha256=$hash;title=$section.title;level=$section.level;line=$section.start;endLine=$section.end;lines=$lines}
            if($section.title -ieq $wantedTitle){$exact+=$hit}elseif($section.title.Contains($wantedTitle,[StringComparison]::OrdinalIgnoreCase)){$partial+=$hit}
        }
    }
    $hits=if($exact.Count){$exact}else{$partial}
    if(!$hits.Count){throw (New-SBError 'knowledge.section.notfound' @($Title))}
    $found=@($hits|ForEach-Object {
        $text=(($_.lines[($_.line-1)..($_.endLine-1)]) -join "`n").TrimEnd()
        @{path=$_.path;sha256=$_.sha256;title=$_.title;level=$_.level;line=$_.line;endLine=$_.endLine;characters=$text.Length;text=$text}
    })
    @{repository=$record.identity;section=$Title;matchKind=$(if($exact.Count){'exact'}else{'partial'});count=$found.Count;matches=$found}
}
function Invoke-SBDossierCompaction {
    param([string]$BrainRoot,[string]$Dossier,[string]$CandidatePath,[string]$BackupRoot,[switch]$Apply,[string]$CheckoutPath,[int]$Budget=50000)
    if([string]::IsNullOrWhiteSpace($Dossier)){throw (New-SBError 'knowledge.dossier.unspecified')}
    $root=[IO.Path]::GetFullPath($BrainRoot);$dir=[IO.Path]::GetFullPath($Dossier)
    [void](Assert-SBPlainPath $dir)
    $relative=[IO.Path]::GetRelativePath($root,$dir).Replace('\','/');[void](Resolve-SBParaPath $root $relative)
    if($relative.StartsWith('04-archives/',[StringComparison]::Ordinal)){throw (New-SBError 'knowledge.dossier.archived')}
    $candidate=Read-SBJson (Assert-SBCentralDataPath $root $CandidatePath) $null
    if(!$candidate -or $candidate.schemaVersion -ne 1 -or $candidate.reviewed -ne $true -or !$candidate.reviewNote){throw (New-SBError 'knowledge.candidate.review')}
    $record=Read-SBJson (Join-Path $dir 'repository.json') $null
    if($candidate.repository -cne $record.identity){throw (New-SBError 'knowledge.candidate.repository')}
    $ops=@();$archives=@();$planned=@{}
    $attributesPath=Join-Path $dir 'history/compaction/.gitattributes'
    if((Get-SBFileHash $attributesPath) -eq 'absent'){$ops+=@{path=$attributesPath;expected='absent';bytes=[Text.Encoding]::UTF8.GetBytes("* -text -whitespace`n")}}
    foreach($name in @('context.md','memory.md')){
        $source=Join-Path $dir $name;$hash=Get-SBFileHash $source
        if(!$candidate.sources.ContainsKey($name) -or $candidate.sources[$name] -ne $hash){throw (New-SBError 'knowledge.source.changed' @($name))}
        if(!$candidate.summaries.ContainsKey($name) -or !$candidate.summaries[$name].Trim()){throw (New-SBError 'knowledge.summary.missing' @($name))}
        $text=[string]$candidate.summaries[$name]
        if($name -eq 'context.md'){foreach($heading in @('Stato corrente','Vincoli','Problemi aperti','Prossimo passo')){if($text -notmatch ('(?m)^## '+[regex]::Escape($heading)+'\s*$')){throw (New-SBError 'knowledge.section.essential' @($heading))}}}
        $archiveRelative='history/compaction/'+$hash.ToLowerInvariant()+'/'+$name
        $archive=Join-Path $dir $archiveRelative;$existing=Get-SBFileHash $archive
        if($existing -eq 'absent'){$ops+=@{path=$archive;expected='absent';bytes=[IO.File]::ReadAllBytes($source)}}elseif($existing -ne $hash){throw (New-SBError 'knowledge.original.diverged')}
        $text=$text.TrimEnd()+"`n`nOriginale conservato: ["+$name+']('+$archiveRelative+"). Le autorizzazioni storiche non sono autorizzazioni correnti.`n"
        $planned[$name]=$text
        $ops+=@{path=$source;expected=$hash;bytes=[Text.Encoding]::UTF8.GetBytes($text)}
        if($name -eq 'memory.md'){
            # La vista per agenti segue la nuova memoria nella stessa transazione.
            $viewPath=Join-Path $dir 'memory.agent.md'
            $planned['memory.agent.md']=ConvertTo-SBAgentMemoryView $text
            $ops+=@{path=$viewPath;expected=(Get-SBFileHash $viewPath);bytes=[Text.Encoding]::UTF8.GetBytes($planned['memory.agent.md'])}
        }
        $archives+=@{source=$name;sha256=$hash;archive=$archiveRelative}
    }
    $tracker=Resolve-SBTracker -BrainRoot $root -Identity $record.identity -DossierPath $dir -CheckoutPath $CheckoutPath -AllowedOwners @()
    $openIds=@($tracker.data.tasks|Where-Object status -notin @('done','cancelled')|ForEach-Object id)
    if(@($openIds|Where-Object {$_ -notin $candidate.openTaskIds}).Count){throw (New-SBError 'knowledge.candidate.tasks')}
    $toc=Get-SBDossierTOC $dir;$index=Join-Path $dir 'index.md'
    $ops+=@{path=$index;expected=(Get-SBFileHash $index);bytes=[Text.Encoding]::UTF8.GetBytes($toc)}
    # Measure exactly the Slim package that startup will load after this transaction.
    $startup=New-SBStartupPackage -Record $record -Tracker $tracker -TOC $toc -ContextText $planned['context.md'] -MemoryText $planned['memory.md'] -AgentViewHash (Get-SBTextHash $planned['memory.agent.md']) -Profile Slim -Budget $Budget
    if($startup.characters -gt $Budget){throw (New-SBError 'knowledge.budget.exceeded')}
    $manifest=@{schemaVersion=1;repository=$record.identity;archives=$archives;reviewNote=$candidate.reviewNote;openTaskIds=$openIds;candidateSha256=(Get-SBFileHash $CandidatePath)}
    $manifestPath=Join-Path $dir ('history/compaction/'+(Get-SBFileHash $CandidatePath).ToLowerInvariant()+'.json')
    $manifestText=ConvertTo-SBJson $manifest
    if((Get-SBFileHash $manifestPath) -eq 'absent'){$ops+=@{path=$manifestPath;expected='absent';bytes=[Text.Encoding]::UTF8.GetBytes($manifestText)}}
    if($Apply){[void](Assert-SBCentralDataPath $root $BackupRoot);Invoke-SBParaTransaction $ops $BackupRoot $root|Out-Null}
    @{repository=$record.identity;applied=[bool]$Apply;archives=$archives;operations=$ops.Count;originalsPreserved=$true;manifest=$manifestPath}
}
Export-ModuleMember -Function @(
    'Get-SBDossierTOC',
    'Get-SBDossierHistoryIndex',
    'Get-SBTaskProjection',
    'Split-SBTieredMarkdown',
    'ConvertTo-SBAgentMemoryView',
    'Get-SBStartupContext',
    'Get-SBSlimStartupBudget',
    'Get-SBCompactionAdvice',
    'Format-SBStartupReport',
    'Get-SBGlobalTasks',
    'Get-SBGlobalTaskPage',
    'Resolve-SBWorkingDossier',
    'Find-SBKnowledge',
    'Get-SBSearchDefaultLimit',
    'Get-SBSearchDefaultBudget',
    'Get-SBRepositoryLifecycle',
    'Set-SBRepositoryLifecycle',
    'Get-SBTaskDetail',
    'Get-SBSection',
    'Invoke-SBDossierCompaction'
)
