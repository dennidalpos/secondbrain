#requires -Version 7.5
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Para.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Tracker.psm1')

function Get-SBDossierTOC([string]$Dossier) {
    $record=Read-SBJson (Join-Path $Dossier 'repository.json') $null
    if(!$record){throw 'repository.json assente'}
    $lines=@('# Indice del dossier','','Repository: `'+$record.identity+'`','','## Avvio selettivo','',
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
function Format-SBSlimTasks($Projection) {
    # Una riga per task pronto: ID, priorita, stato, titolo. Descrizione e criteri di accettazione restano a get_ready_tasks / knowledge.ps1 -Tasks.
    $rows=@()
    foreach($task in @($Projection)){
        if($null -eq $task){continue}
        $blocker=if($task -is [Collections.IDictionary] -and $task.Contains('blocker')){[string]$task['blocker']}else{''}
        # Il motivo è abbreviato: il testo completo resta nel tracker (get_ready_tasks).
        if($blocker.Length -gt 90){$blocker=$blocker.Substring(0,90).TrimEnd()+'…'}
        $rows+=('- '+$task['id']+' ['+$task['priority']+'/'+$task['status']+'] '+$task['title']+$(if($blocker){' (motivo: '+$blocker+')'}else{''}))
    }
    if(!$rows.Count){return "Nessun task pronto.`n"}
    ('Task pronti ('+$rows.Count+'):',($rows -join "`n")) -join "`n"
}
function Get-SBStartupContext {
    param([string]$BrainRoot,[string]$Dossier,[string]$CheckoutPath,[string[]]$TaskIds=@(),[int]$Budget=50000,$Entities=@(),[switch]$ReadyOnly,[ValidateSet('Slim','Full')][string]$Profile='Full')
    $record=Read-SBJson (Join-Path $Dossier 'repository.json') $null
    if(!$record){throw 'Dossier non valido'}
    $slim=($Profile -eq 'Slim')
    $toc=Get-SBDossierTOC $Dossier
    $tracker=Resolve-SBTracker -BrainRoot $BrainRoot -Identity $record.identity -CheckoutPath $CheckoutPath -DossierPath $Dossier -AllowedOwners @() -Entities $Entities
    $trData=if($tracker.ContainsKey('data')){$tracker.data}else{$null}
    $trRel=if($tracker.ContainsKey('related')){$tracker.related}else{@{}}
    $projection=if($trData){@(Get-SBTaskProjection $trData $TaskIds -ReadyOnly:($ReadyOnly -or $slim) -RelatedTrackers $trRel)}else{@()}
    $contextPath=Join-Path $Dossier 'context.md';$memoryPath=Join-Path $Dossier 'memory.md'
    $contextText=Read-SBText $contextPath;$memoryText=Read-SBText $memoryPath
    if(!$slim){
        $parts=@{index=$toc;context=$contextText;memory=$memoryText;tasks=(ConvertTo-SBJson $projection)}
        $omitted=@()
    }else{
        $contextTiers=Split-SBTieredMarkdown $contextText;$memoryTiers=Split-SBTieredMarkdown $memoryText
        $omitted=@()
        foreach($entry in @(@{name='context';tiers=$contextTiers;file='context.md'},@{name='memory';tiers=$memoryTiers;file='memory.md'})){
            if($entry.tiers.history.Length){$omitted+=@{part=$entry.name+' (storico)';characters=$entry.tiers.history.Length;sections=@($entry.tiers.historyTitles);how='knowledge.ps1 -Search "<termine>" oppure -Startup -Profile Full; file '+$entry.file}}
        }
        $omitted+=@{part='task: descrizioni, criteri di accettazione, task non pronti';characters=0;sections=@();how='knowledge.ps1 -Tasks (-All per la vista globale) oppure MCP get_ready_tasks con includeAcceptance'}
        $omitted+=@{part='storico del dossier (history/, knowledge/, topics/)';characters=0;sections=@();how='history/index.md e indice del dossier; ricerca con knowledge.ps1 -Search'}
        $levelLines=@('# Livelli non caricati','','Profilo Slim: sono caricate le sole parti essenziali. Nulla è stato eliminato; richiedi il resto quando serve.','')
        foreach($item in $omitted){$levelLines+=('- '+$item.part+$(if($item.characters){' — '+$item.characters+' caratteri'}else{''})+$(if(@($item.sections).Count){' ('+(@($item.sections) -join '; ')+')'}else{''})+': '+$item.how)}
        $parts=@{index=$toc;context=$contextTiers.essential;memory=$memoryTiers.essential;tasks=(Format-SBSlimTasks $projection);levels=(($levelLines -join "`n")+"`n")}
    }
    $characters=($parts.Values|Measure-Object -Property Length -Sum).Sum
    @{repository=$record.identity;profile=$Profile;budget=$Budget;characters=$characters;withinBudget=($Budget -le 0 -or $characters -le $Budget);needsCompaction=($Budget -gt 0 -and $characters -gt $Budget);
      parts=$parts;loadedParts=@($parts.Keys|Sort-Object);omittedParts=@($omitted);taskSource=$tracker.path;originalsTruncated=$false;unit='characters-not-tokens'}
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
    $lines+=@('','Non incluso: prompt di sistema, definizioni degli strumenti MCP e skill dell''IDE; si vedono nel riepilogo del contesto dell''IDE.','Misure di caratteri, non di token (SYS08).')
    ($lines -join "`n")+"`n"
}
function Get-SBGlobalTasks([string]$BrainRoot,[string]$Repository='',[switch]$All,[switch]$ReadyOnly) {
    # Perimetro cooperativo: senza repository esplicito la vista globale richiede -All (sola lettura, ogni voce etichettata scope=global).
    if(!$Repository -and !$All){throw 'Repository non specificato: indicare il repository in lavoro oppure -All per la vista globale in sola lettura'}
    $entities=@(Get-SBParaEntities $BrainRoot @())
    $areas=@($entities|Where-Object {$_.kind -eq 'area' -and !$_.archived -and (!$Repository -or $_.repository -eq $Repository)})
    if($Repository -and !$areas.Count){throw "Nessun dossier attivo per il repository: $Repository"}
    $scope=if($Repository){'repository'}else{'global'}
    foreach($area in $areas){
        $dossier=Resolve-SBParaPath $BrainRoot $area.path
        try{
            $tr=Resolve-SBTracker -BrainRoot $BrainRoot -Identity $area.repository -AllowedOwners @() -DossierPath $dossier -Entities $entities
            $trData=if($tr.ContainsKey('data')){$tr.data}else{$null}
            if(!$trData){@{repository=$area.repository;status='unverified';reason='Tracker data non disponibile';scope=$scope};continue}
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
function Resolve-SBWorkingDossier([string]$BrainRoot,[string]$Repository) {
    # Dossier (percorso relativo al cervello) dell'unico Area attiva del repository.
    $found=@(Get-SBParaEntities $BrainRoot @()|Where-Object {$_.kind -eq 'area' -and !$_.archived -and $_.repository -ceq $Repository})
    if($found.Count -ne 1){throw "Dossier non risolto in modo univoco per il repository: $Repository"}
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
function Find-SBKnowledge {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$BrainRoot,
        [Parameter(Mandatory)][string]$Search,
        [string]$Dossier='',
        [string]$Repository='',
        [int]$Budget=0,
        $Entities=@(),
        [ValidateSet('Literal','Relevance')][string]$Mode='Literal'
    )
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
    $totalMatches=0
    $totalChars=0
    if([string]::IsNullOrWhiteSpace($Search)){
        return @{search=$Search;query=$Search;mode=$Mode;budget=$Budget;characters=0;withinBudget=$true;totalMatches=0;count=0;extracts=@();matches=@()}
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
        $compactionDir=Join-Path $dir 'history/compaction'
        if(Test-Path -LiteralPath $compactionDir -PathType Container){
            foreach($item in (Get-ChildItem -LiteralPath $compactionDir -File -Recurse|Sort-Object FullName)){
                if($item.Extension -in @('.md','.json','.txt')){$filesToSearch.Add($item.FullName)}
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
                    $totalMatches++
                    $trimmed=$line.Trim()
                    $extract=@{path=$relPath;line=$lineNum;sha256=$hash;text=$trimmed}
                    $extractSize=$relPath.Length + $trimmed.Length + $hash.Length + 20
                    if($Budget -le 0 -or $totalChars + $extractSize -le $Budget){
                        $extracts.Add($extract)
                        $totalChars += $extractSize
                    }
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
                $totalMatches++
                $trimmed=$line.Trim()
                $extract=@{path=$unit.path;line=$lineNum;sha256=$unit.sha256;text=$trimmed;score=$entry.score;section=[string]$unit.title}
                $extractSize=$unit.path.Length + $trimmed.Length + $unit.sha256.Length + 20
                if($Budget -le 0 -or $totalChars + $extractSize -le $Budget){
                    $extracts.Add($extract)
                    $totalChars += $extractSize
                }
            }
        }
    }
    $withinBudget=($totalMatches -eq $extracts.Count -and ($Budget -le 0 -or $totalChars -le $Budget))
    @{
        search=$Search
        query=$Search
        mode=$Mode
        tokens=@($tokens)
        units=@($ranked).Count
        budget=$Budget
        characters=$totalChars
        withinBudget=$withinBudget
        totalMatches=$totalMatches
        count=$extracts.Count
        extracts=@($extracts)
        matches=@($extracts)
    }
}
function Invoke-SBDossierCompaction {
    param([string]$BrainRoot,[string]$Dossier,[string]$CandidatePath,[string]$BackupRoot,[switch]$Apply,[string]$CheckoutPath,[int]$Budget=50000)
    $root=[IO.Path]::GetFullPath($BrainRoot);$dir=[IO.Path]::GetFullPath($Dossier)
    [void](Assert-SBPlainPath $dir)
    $relative=[IO.Path]::GetRelativePath($root,$dir).Replace('\','/');[void](Resolve-SBParaPath $root $relative)
    if($relative.StartsWith('04-archives/',[StringComparison]::Ordinal)){throw 'Dossier archiviato: compattazione non autorizzata implicitamente'}
    $candidate=Read-SBJson (Assert-SBCentralDataPath $root $CandidatePath) $null
    if(!$candidate -or $candidate.schemaVersion -ne 1 -or $candidate.reviewed -ne $true -or !$candidate.reviewNote){throw 'Candidato richiede revisione esplicita dellʼagente e motivazione'}
    $record=Read-SBJson (Join-Path $dir 'repository.json') $null
    if($candidate.repository -cne $record.identity){throw 'Candidato di un altro repository'}
    $ops=@();$archives=@()
    $attributesPath=Join-Path $dir 'history/compaction/.gitattributes'
    if((Get-SBFileHash $attributesPath) -eq 'absent'){$ops+=@{path=$attributesPath;expected='absent';bytes=[Text.Encoding]::UTF8.GetBytes("* -text -whitespace`n")}}
    foreach($name in @('context.md','memory.md')){
        $source=Join-Path $dir $name;$hash=Get-SBFileHash $source
        if(!$candidate.sources.ContainsKey($name) -or $candidate.sources[$name] -ne $hash){throw 'Fonte modificata dopo la preparazione: '+$name}
        if(!$candidate.summaries.ContainsKey($name) -or !$candidate.summaries[$name].Trim()){throw 'Sintesi assente: '+$name}
        $text=[string]$candidate.summaries[$name]
        if($name -eq 'context.md'){foreach($heading in @('Stato corrente','Vincoli','Problemi aperti','Prossimo passo')){if($text -notmatch ('(?m)^## '+[regex]::Escape($heading)+'\s*$')){throw 'Sezione essenziale assente: '+$heading}}}
        $archiveRelative='history/compaction/'+$hash.ToLowerInvariant()+'/'+$name
        $archive=Join-Path $dir $archiveRelative;$existing=Get-SBFileHash $archive
        if($existing -eq 'absent'){$ops+=@{path=$archive;expected='absent';bytes=[IO.File]::ReadAllBytes($source)}}elseif($existing -ne $hash){throw 'Originale archiviato divergente'}
        $text=$text.TrimEnd()+"`n`nOriginale conservato: ["+$name+']('+$archiveRelative+"). Le autorizzazioni storiche non sono autorizzazioni correnti.`n"
        $ops+=@{path=$source;expected=$hash;bytes=[Text.Encoding]::UTF8.GetBytes($text)}
        $archives+=@{source=$name;sha256=$hash;archive=$archiveRelative}
    }
    $tracker=Resolve-SBTracker -BrainRoot $root -Identity $record.identity -DossierPath $dir -CheckoutPath $CheckoutPath -AllowedOwners @()
    $openIds=@($tracker.data.tasks|Where-Object status -notin @('done','cancelled')|ForEach-Object id)
    if(@($openIds|Where-Object {$_ -notin $candidate.openTaskIds}).Count){throw 'Il candidato omette task aperti: rigenerare la proiezione'}
    $toc=Get-SBDossierTOC $dir;$index=Join-Path $dir 'index.md'
    $ops+=@{path=$index;expected=(Get-SBFileHash $index);bytes=[Text.Encoding]::UTF8.GetBytes($toc)}
    $total=($ops|Where-Object {[IO.Path]::GetFileName($_.path) -in @('context.md','memory.md') -and $_.path -notmatch '[\\/]history[\\/]'}|ForEach-Object {[Text.Encoding]::UTF8.GetString($_.bytes).Length}|Measure-Object -Sum).Sum
    $projection=ConvertTo-SBJson @(Get-SBTaskProjection $tracker.data)
    if($total+$toc.Length+$projection.Length -gt $Budget){throw 'Budget superato: approfondire la sintesi, senza troncare informazioni'}
    $manifest=@{schemaVersion=1;repository=$record.identity;archives=$archives;reviewNote=$candidate.reviewNote;openTaskIds=$openIds;candidateSha256=(Get-SBFileHash $CandidatePath)}
    $manifestPath=Join-Path $dir ('history/compaction/'+(Get-SBFileHash $CandidatePath).ToLowerInvariant()+'.json')
    $manifestText=ConvertTo-SBJson $manifest
    if((Get-SBFileHash $manifestPath) -eq 'absent'){$ops+=@{path=$manifestPath;expected='absent';bytes=[Text.Encoding]::UTF8.GetBytes($manifestText)}}
    if($Apply){[void](Assert-SBCentralDataPath $root $BackupRoot);Invoke-SBParaTransaction $ops $BackupRoot $root|Out-Null}
    @{repository=$record.identity;applied=[bool]$Apply;archives=$archives;operations=$ops.Count;originalsPreserved=$true;manifest=$manifestPath}
}
Export-ModuleMember -Function *-SB*
