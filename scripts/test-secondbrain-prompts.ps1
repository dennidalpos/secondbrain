#requires -Version 7.5
# Prompt library: single catalog, card format (EN source + IT counterpart), composition, listing, drift. Read-only on the real catalog.
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Prompts.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Portable.psm1') -Force
. (Join-Path $PSScriptRoot 'test-helpers.ps1')
$brain=Split-Path $PSScriptRoot -Parent
$script:promptChecks=0
function Assert-Prompts($Condition,[string]$Message){if(!$Condition){throw 'FAIL PROMPTS: '+$Message};$script:promptChecks++;'PASS PROMPTS: '+$Message}
$catalog=Read-SBWorkflowCatalog $brain -ValidateBodies -ValidateReferences
$prompts=@($catalog.prompts)
Assert-Prompts ($prompts.Count -ge 80) ('catalogo unico con '+$prompts.Count+' prompt')
Assert-Prompts (@($prompts.code|Select-Object -Unique).Count -eq $prompts.Count) 'codici univoci'
Assert-Prompts (@($prompts.id|Select-Object -Unique).Count -eq $prompts.Count) 'ID univoci'
Assert-Prompts (!(@($prompts|Where-Object {$_.id -notmatch '^pmt-[0-9a-f]{8}$'}).Count)) 'ID nel formato pmt-xxxxxxxx'
$raw=Get-Content -Raw -LiteralPath (Join-Path $brain 'direttive/prompts/catalog.json')
foreach($legacy in 'pack','deprecations','aliases','supersededBy','next','references','status'){Assert-Prompts ($raw -notmatch ('"'+$legacy+'"\s*:')) "il catalogo non contiene la chiave $legacy"}
Assert-Prompts (!(Test-Path -LiteralPath (Join-Path $brain 'direttive/prompts/en'))) 'nessuna cartella en/ legacy'
Assert-Prompts (!(Get-ChildItem -LiteralPath (Join-Path $brain 'direttive/prompts') -Filter 'README.maintenance*')) 'nessun README.maintenance legacy'
foreach($p in $prompts){
    $en=Join-Path $brain ('direttive/prompts/'+$p.code+'.md');$it=Join-Path $brain ('direttive/prompts/it/'+$p.code+'.md')
    if(!(Test-Path -LiteralPath $en) -or !(Test-Path -LiteralPath $it)){Assert-Prompts $false ($p.code+': scheda EN e IT presenti')}
    $enText=Get-Content -Raw -LiteralPath $en
    foreach($tag in 'role','context','inputs','procedure','constraints','exit_criteria','output_format'){
        if($enText -notmatch "(?m)^<$tag>\s*$"){Assert-Prompts $false ($p.code+': tag '+$tag)}
    }
    if($enText.Length -gt 6500){Assert-Prompts $false ($p.code+': scheda oltre 6.500 caratteri ('+$enText.Length+')')}
    if($enText -match '\bask_question\b'){Assert-Prompts $false ($p.code+': nome di tool non standard')}
}
Assert-Prompts $true 'ogni scheda ha i tag obbligatori, dimensione contenuta e nessun nome di tool non standard'
# Every related code exists; every category is used.
$ids=@($prompts.id)
Assert-Prompts (!(@($prompts|ForEach-Object {$_.related}|Where-Object {$_ -notin $ids}).Count)) 'related punta a ID esistenti'
Assert-Prompts (!(@($prompts|Where-Object {$_.id -in $_.related}).Count)) 'nessun prompt correlato a sé stesso'
# Groups: central categories hold only central prompts and repository categories none; every category has a group.
foreach($category in $catalog.categories){
    $members=@($prompts|Where-Object category -eq $category.id)
    $expectedTarget=if($category.group -eq 'central'){'central'}else{'repository'}
    Assert-Prompts (@($members|Where-Object target -ne $expectedTarget).Count -eq 0) ('categoria '+$category.id+': gruppo '+$category.group+' coerente con la destinazione dei prompt')
}
# Perimeter: a repository prompt works on the repository it runs from; the only cross-repository reads are declared allowlists (REP16).
foreach($p in @($prompts|Where-Object {$_.target -eq 'repository' -and $_.code -ne 'REP16'})){
    foreach($relative in @($p.file,('it/'+$p.file))){
        $body=Get-Content -Raw -LiteralPath (Join-Path $brain ('direttive/prompts/'+$relative))
        Assert-Prompts ($body -notmatch '(?i)para-index|para\.ps1|-AllDossiers|\.runtime|central maintenance|manutenzione centrale') ($p.code+' ('+$relative+'): nessun riferimento oltre il repository corrente')
    }
}
# Related: a code cited in a card must be listed among its related prompts, and cited codes must exist.
$relatedRoot=Join-Path (Get-SBTestRoot) ('fixture-'+(Get-Date -Format 'yyyyMMdd')+'-related-'+[guid]::NewGuid().ToString('N').Substring(0,8))
foreach($folder in 'direttive/prompts','config'){[void][IO.Directory]::CreateDirectory((Join-Path $relatedRoot $folder))}
Copy-Item -LiteralPath (Join-Path $brain 'direttive/prompts') -Destination (Join-Path $relatedRoot 'direttive') -Recurse -Force
Copy-Item -LiteralPath (Join-Path $brain 'config/prompt-catalog.schema.json') -Destination (Join-Path $relatedRoot 'config/prompt-catalog.schema.json') -Force
Assert-Prompts ($null -ne (Read-SBWorkflowCatalog $relatedRoot -ValidateBodies -ValidateReferences)) 'related: copia di prova valida'
$relatedCatalogPath=Join-Path $relatedRoot 'direttive/prompts/catalog.json'
$relatedCatalog=Read-SBJson $relatedCatalogPath @{}
$victim=@($relatedCatalog.prompts|Where-Object {$_.code -eq 'AUD01'})[0]
$victim.related=@($victim.related|Select-Object -First 1)
[IO.File]::WriteAllText($relatedCatalogPath,(ConvertTo-SBJson $relatedCatalog),[Text.UTF8Encoding]::new($false))
$uncited=$false
try{[void](Read-SBWorkflowCatalog $relatedRoot -ValidateBodies -ValidateReferences)}catch{$uncited=Test-SBError $_ 'prompts.related.uncited'}
Assert-Prompts $uncited 'related: codice citato ma non elencato respinto'
Copy-Item -LiteralPath (Join-Path $brain 'direttive/prompts/catalog.json') -Destination $relatedCatalogPath -Force
$danglingCard=Join-Path $relatedRoot 'direttive/prompts/DEV01.md'
[IO.File]::WriteAllText($danglingCard,(([IO.File]::ReadAllText($danglingCard)).Replace("`n</context>"," See DEV99.`n</context>")),[Text.UTF8Encoding]::new($false))
$dangling=$false
try{[void](Read-SBWorkflowCatalog $relatedRoot -ValidateBodies -ValidateReferences)}catch{$dangling=Test-SBError $_ 'prompts.reference.dangling'}
Assert-Prompts $dangling 'related: codice citato inesistente respinto'
# Listing.
$list=& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'prompts.ps1') -List -Compact
Assert-Prompts ($LASTEXITCODE -eq 0 -and ($list -join "`n") -match 'SYS03' -and ($list -join "`n") -match 'MEM05') 'elenco compatto con prompt di sistema e memoria nella stessa lista'
$cat=& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'prompts.ps1') -List -Category TST
Assert-Prompts ($LASTEXITCODE -eq 0 -and ($cat -join "`n") -match 'TST04') 'elenco per categoria'
$show=& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'prompts.ps1') -Show -Prompt TST04
Assert-Prompts ($LASTEXITCODE -eq 0 -and ($show -join "`n") -match 'TST04') 'scheda mostrata per codice'
$byId=($prompts|Where-Object code -eq 'TST04').id
$showId=& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'prompts.ps1') -Show -Prompt $byId
Assert-Prompts ($LASTEXITCODE -eq 0 -and ($showId -join "`n") -eq ($show -join "`n")) 'ID e codice risolvono la stessa scheda'
# Composition: XML structure, objective honored, closing depends on mode.
$ctx=@{repositories=@();sourceRegistry=$null;project=$null}
$readPrompt=$prompts|Where-Object {$_.mode -eq 'read'}|Select-Object -First 1
$writePrompt=$prompts|Where-Object {$_.mode -eq 'write' -and $_.code -notmatch '^(MEM|SYS)'}|Select-Object -First 1
$objective='Obiettivo di prova 4242'
$readOut=New-SBWorkflowComposition $brain $catalog $readPrompt $ctx $objective -Standalone
Assert-Prompts ($readOut -match '(?s)<prompt code="'+$readPrompt.code+'".*<task>\s*'+[regex]::Escape($objective)+'\s*</task>.*<role>.*<procedure>.*<exit_criteria>.*<output_format>.*</prompt>') 'composizione XML con obiettivo, ruolo, procedura, criteri e formato'
$writeOut=New-SBWorkflowComposition $brain $catalog $writePrompt $ctx '' -Standalone
Assert-Prompts ($writeOut -ne $readOut -and $writeOut -match '<operating_rules>') 'regole operative presenti anche in scrittura'
$closingRead=([regex]::Match($readOut,'(?s)<operating_rules>(.*?)</operating_rules>')).Groups[1].Value
$closingWrite=([regex]::Match($writeOut,'(?s)<operating_rules>(.*?)</operating_rules>')).Groups[1].Value
Assert-Prompts ($closingRead -ne $closingWrite) 'la chiusura del task dipende dalla modalità'
# Language: IT counterpart.
Set-SBWorkflowLanguage 'it'
$itOut=New-SBWorkflowComposition $brain $catalog $readPrompt $ctx '' -Standalone
Set-SBWorkflowLanguage 'en'
Assert-Prompts ($itOut -match 'language="it"' -and $itOut -ne $readOut) 'controparte italiana selezionabile'
# Pointer files for agents that do not read AGENTS.md (Claude Code, Gemini CLI): created, idempotent, preserve user text, conflict on foreign edits.
$pointerRoot=Join-Path (Get-SBTestRoot) ('fixture-'+(Get-Date -Format 'yyyyMMdd')+'-pointers-'+[guid]::NewGuid().ToString('N').Substring(0,8))
[IO.Directory]::CreateDirectory($pointerRoot)|Out-Null
$pointerBackup=Join-Path $pointerRoot 'backups';$pointerState=@{}
[IO.File]::WriteAllText((Join-Path $pointerRoot 'CLAUDE.md'),"# Note utente`nIstruzioni personali.`n")
$preview=@(Set-SBRepositoryPointers $pointerRoot $pointerState $true $pointerBackup)
Assert-Prompts (@($preview|Where-Object result -eq 'pending').Count -eq 2 -and !(Test-Path -LiteralPath (Join-Path $pointerRoot 'GEMINI.md'))) 'anteprima dei puntatori senza scrivere'
$applied=@(Set-SBRepositoryPointers $pointerRoot $pointerState $false $pointerBackup)
$claude=Get-Content -Raw -LiteralPath (Join-Path $pointerRoot 'CLAUDE.md')
$gemini=Get-Content -Raw -LiteralPath (Join-Path $pointerRoot 'GEMINI.md')
Assert-Prompts (@($applied|Where-Object result -eq 'updated').Count -eq 2 -and $claude.Contains('@AGENTS.md') -and $claude.Contains('Istruzioni personali.') -and $gemini.Contains('@AGENTS.md')) 'puntatori creati e testo utente preservato'
Assert-Prompts (@(Set-SBRepositoryPointers $pointerRoot $pointerState $false $pointerBackup|Where-Object result -ne 'aligned').Count -eq 0) 'puntatori idempotenti'
$crlf=(Get-Content -Raw -LiteralPath (Join-Path $pointerRoot 'CLAUDE.md')) -replace "`r?`n","`r`n"
[IO.File]::WriteAllText((Join-Path $pointerRoot 'CLAUDE.md'),$crlf)
Assert-Prompts (@(Set-SBRepositoryPointers $pointerRoot $pointerState $true $pointerBackup|Where-Object {$_.file -eq 'CLAUDE.md'}).result -eq 'aligned') 'puntatore con terminatori CRLF (autocrlf) resta allineato'
[IO.File]::WriteAllText((Join-Path $pointerRoot 'GEMINI.md'),($gemini -replace '@AGENTS.md','@ALTRO.md'))
Assert-Prompts (@(Set-SBRepositoryPointers $pointerRoot $pointerState $true $pointerBackup|Where-Object {$_.file -eq 'GEMINI.md'}).result -eq 'conflict') 'modifica esterna del blocco segnalata come conflitto'
$pointerBinaryCount=@(Get-ChildItem -LiteralPath $pointerBackup -Filter '*.bin').Count
$geminiPath=Join-Path $pointerRoot 'GEMINI.md'
$pointerState[$geminiPath+'|pointer']=Get-SBTextHash ((Read-SBText $geminiPath).Trim())
$updatedPointer=@(Set-SBRepositoryPointers $pointerRoot $pointerState $false $pointerBackup|Where-Object file -eq 'GEMINI.md')
Assert-Prompts ($updatedPointer.result -eq 'updated' -and (Read-SBText $geminiPath) -ceq $gemini -and @(Get-ChildItem -LiteralPath $pointerBackup -Filter '*.bin').Count -eq $pointerBinaryCount) 'puntatore interamente generato aggiornato senza copia binaria'
$personalBackup=@(Get-ChildItem -LiteralPath $pointerBackup -Filter '*.bin'|Where-Object {(Read-SBText $_.FullName) -ceq "# Note utente`nIstruzioni personali.`n"})
Assert-Prompts ($personalBackup.Count -eq 1) 'puntatore misto mantiene una copia esatta delle istruzioni personali'
# Encoding guard: exercise both read boundaries, including corruption in a body beyond its title.
$encodingRoot=Join-Path $pointerRoot 'encoding'
$encodingCatalog=Join-Path $encodingRoot 'direttive/prompts/catalog.json'
$encodingCard=Join-Path $encodingRoot ('direttive/prompts/it/'+$readPrompt.file)
$encodingBackup=Join-Path $pointerRoot 'encoding-backups'
$validUnicode='Usabilità, può, receção, cessação, … — • ⚠ 🔭 ├── 中文'
& (Get-Module SecondBrain.Prompts) {param($Text) Assert-SBWorkflowEncoding $Text 'valid-unicode'} $validUnicode
Assert-Prompts $true 'codifica: accenti, portoghese, emoji, punteggiatura, cinese e alberi Unicode validi'
$badSequences=@(
    (-join ([char[]]@(0x251C,0x00E1))),
    (-join ([char[]]@(0x251C,0x2593))),
    (-join ([char[]]@(0x00E2,0x20AC,0x00A2))),
    (-join ([char[]]@(0x00E2,0x20AC,0x201D))),
    (-join ([char[]]@(0x00E2,0x20AC,0x00A6))),
    (-join ([char[]]@(0x00E2,0x0161,0x00A0))),
    ([string][char]0xFFFD)
)
foreach($bad in $badSequences){
    $badJson=ConvertTo-SBJson @{text=('Fixture '+$bad)}
    Write-SBFile $encodingCatalog ([Text.Encoding]::UTF8.GetBytes($badJson)) (Get-SBFileHash $encodingCatalog) $encodingBackup|Out-Null
    $catalogRejected=$false
    try{[void](Read-SBWorkflowCatalog $encodingRoot)}catch{$catalogRejected=Test-SBError $_ 'prompts.encoding.invalid'}
    Assert-Prompts $catalogRejected 'codifica: catalogo corrotto respinto con codice stabile'
    $badCard='# '+$readPrompt.code+' — Fixture'+[Environment]::NewLine+'<context>'+[Environment]::NewLine+$bad
    Write-SBFile $encodingCard ([Text.Encoding]::UTF8.GetBytes($badCard)) (Get-SBFileHash $encodingCard) $encodingBackup|Out-Null
    $cardRejected=$false
    try{[void](Read-SBWorkflowPrompt $encodingRoot $readPrompt $catalog 'it')}catch{$cardRejected=Test-SBError $_ 'prompts.encoding.invalid'}
    Assert-Prompts $cardRejected 'codifica: corpo scheda corrotto respinto con codice stabile'
}
# Generated indexes are in sync.
$drift=Get-SBWorkflowDrift $brain
Assert-Prompts (!@($drift).Count) 'indici generati allineati al catalogo'
# Directives: the newest proposal (candidate or active text) respects structure, size and consistency with the prompt registry.
$proposalRoot=Join-Path $brain 'direttive/proposals'
$latest=Get-ChildItem -LiteralPath $proposalRoot -Directory|Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'AGENTS.global_ide.md')}|Sort-Object Name|Select-Object -Last 1
$global=Get-Content -Raw -Encoding utf8 (Join-Path $latest.FullName 'AGENTS.global_ide.md')
$station=Get-Content -Raw -Encoding utf8 (Join-Path $latest.FullName 'workstation.template.md')
$repoBlock=Get-Content -Raw -Encoding utf8 (Join-Path $latest.FullName 'AGENTS.repo.managed.md')
Assert-Prompts ($global.Length -le 5500) ('testo comune entro 5.500 caratteri ('+$global.Length+')')
Assert-Prompts ($station.Length -le 3200) ('testo di postazione entro 3.200 caratteri ('+$station.Length+')')
Assert-Prompts ($repoBlock.Length -le 3200) ('blocco repository entro 3.200 caratteri ('+$repoBlock.Length+')')
Assert-Prompts ($global -match '(?m)^Revisi(?:on|one) \d+\.\d+ — \d{4}-\d{2}-\d{2}\.') 'riga di revisione leggibile dal registro'
$headings=[ordered]@{
    'Principi'='Principles'
    'Sicurezza e dati'='Security and data'
    'SecondBrain'='SecondBrain'
    'Verifica'='Verification'
    'Git e pubblicazione'='Git and publication'
    'Chiusura'='Closing work'
}
foreach($heading in $headings.Keys){
    $italian=[regex]::Escape($heading)
    $english=[regex]::Escape($headings[$heading])
    Assert-Prompts ($global -match "(?m)^## (?:$italian|$english)\s*$") "sezione '$heading' nel testo comune"
}
Assert-Prompts ($global -notmatch 'ask_question|Function Calling') 'nessun nome di strumento non standard nel testo comune'
foreach($text in $global,$station,$repoBlock){Assert-Prompts ($text -notmatch '(?<![A-Za-z0-9+.-])[A-Z]:[\/]|(?<![\w/])/(?:Users|home)/|\{\{') 'nessun percorso assoluto o segnaposto'}
Assert-Prompts ($station.Contains('<!-- secondbrain:tracker-contract:1 -->')) 'contratto tracker presente nel testo di postazione'
$registry=@(Get-SBWorkflowCommands|ForEach-Object {$_.command})
$english='sb activate','sb check','sb sync','sb compact','sb stop','sb prompt list','sb prompt area AREA','sb prompt show KEY'
foreach($command in $english){Assert-Prompts ($command -in $registry) "command '$command' in the registry"}
# Italian verbs of revisions up to 1.2 stay resolvable as aliases for the whole major version.
$aliases=@(Get-SBWorkflowCommands|ForEach-Object {@($_.aliases)})
foreach($alias in 'sb attiva','sb controlla','sb allinea','sb compatta','sb prompt ambito AREA','sb prompt mostra CHIAVE'){Assert-Prompts ($alias -in $aliases -and $alias -notin $registry) "alias '$alias' kept and not primary"}
Assert-Prompts ((@(Get-SBWorkflowCommands|Where-Object command -eq 'sb stop')[0].script) -match '-Prompt MEM09$') 'sb stop compone MEM09'
foreach($word in $english){Assert-Prompts ($station.Contains($word)) "command '$word' described in the workstation text"}
$referenced=@([regex]::Matches($global+$station+$repoBlock,'(?:COM|PRG|DEV|TST|SEC|AUD|INT|DAT|OPS|DOC|REP|GOV|MEM|SYS)\d{2}')|ForEach-Object {$_.Value}|Select-Object -Unique)
Assert-Prompts (!(@($referenced|Where-Object {$_ -notin @($prompts.code)}).Count)) 'ogni codice prompt citato nelle direttive esiste nel catalogo'
# #589: private repository cards and workflows in the dossier, namespaced keys, no shadowing, no public reference to them.
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.PrivateAssets.psm1') -Force
$privateRoot=Join-Path (Get-SBTestRoot) ('private-assets-'+[guid]::NewGuid().ToString('N').Substring(0,12))
function Write-PrivateFixture([string]$Relative,[string]$Text){$p=Join-Path $privateRoot $Relative;[IO.Directory]::CreateDirectory((Split-Path $p))|Out-Null;[IO.File]::WriteAllText($p,$Text,[Text.UTF8Encoding]::new($false))}
function New-PrivateCardText([string]$Key,[string]$Summary){"# $Key — $($Summary.TrimEnd('.'))`n<role>`nRelease operator.`n</role>`n<context>`nSigning of this repository.`n</context>`n<inputs>`n- the package`n</inputs>`n<procedure>`n1. Build.`n2. Sign.`n</procedure>`n<constraints>`n- No publication.`n</constraints>`n<exit_criteria>`n- Signed package.`n</exit_criteria>`n<output_format>`nReport.`n</output_format>`n"}
function New-PrivateDossier([string]$Name,[string]$Identity,$Cards,$Flows=@()){
    foreach($sub in 'prompts','workflows'){$dir=Join-Path $privateRoot "01-projects/$Name/$sub";if(Test-Path -LiteralPath $dir){Remove-Item -LiteralPath $dir -Recurse -Force}}
    Write-PrivateFixture "01-projects/$Name/repository.json" (ConvertTo-SBJson @{schemaVersion=1;identity=$Identity})
    if($null -ne $Cards){
        Write-PrivateFixture "01-projects/$Name/prompts/catalog.json" (ConvertTo-SBJson @{schemaVersion=1;repository=$Identity;prompts=@($Cards|ForEach-Object {$_.entry})})
        foreach($card in @($Cards)){if($card.text){Write-PrivateFixture ("01-projects/$Name/prompts/"+$card.entry.file) $card.text}}
    }
    foreach($flow in @($Flows)){Write-PrivateFixture ("01-projects/$Name/workflows/"+(($flow.key -split '/',2)[1])+'.json') (ConvertTo-SBJson $flow)}
}
function New-PrivateCard([string]$Id,[string]$Key,[string]$Mode='write',[bool]$Destructive=$false,[string]$Status='active',$Related=@()){
    $summary='Sign the release package of this repository.'
    $entry=[ordered]@{id=$Id;key=$Key;summary=$summary;mode=$Mode;destructive=$Destructive;target='repository';revision=1;status=$Status;file=(($Key -split '/',2)[1]+'.md')}
    if(@($Related).Count){$entry.related=@($Related)}
    @{entry=$entry;text=(New-PrivateCardText $Key $summary)}
}
function Assert-PrivateRefused([scriptblock]$Action,[string]$Code,[string]$Message){$refused=$false;try{& $Action|Out-Null}catch{$refused=(Test-SBError $_ $Code)};Assert-Prompts $refused $Message}
try{
    $publicId=[string]$prompts[0].id
    Write-PrivateFixture 'direttive/prompts/catalog.json' '{"schemaVersion":1}'
    $sign=New-PrivateCard 'pmt-a0000001' 'acme-app/pkg-sign' 'write' $false 'active' @($publicId)
    $draft=New-PrivateCard 'pmt-a0000002' 'acme-app/pkg-draft' 'read' $false 'draft'
    $wipe=New-PrivateCard 'pmt-a0000003' 'acme-app/pkg-wipe' 'write' $true
    $flow=[ordered]@{schemaVersion=1;id='wfl-a0000001';key='acme-app/release';title='Release';revision=1;status='active';steps=@(
        [ordered]@{step='check';ref=$publicId;kind='required';gate='auto'},
        [ordered]@{step='sign';ref='pmt-a0000001';kind='required';gate='confirm'},
        [ordered]@{step='clean';ref='pmt-a0000003';kind='optional';gate='confirm'})}
    New-PrivateDossier 'acme-app' 'github.com/acme/acme-app' @($sign,$draft,$wipe) @($flow)
    New-PrivateDossier 'beta' 'github.com/acme/Beta' @(New-PrivateCard 'pmt-b0000001' 'beta/notes' 'read')
    $setA=Read-SBPrivateAssets -Dossier (Join-Path $privateRoot '01-projects/acme-app') -Repository 'github.com/acme/acme-app' -PublicCatalog $catalog
    Assert-Prompts (@($setA.prompts).Count -eq 3 -and @($setA.workflows).Count -eq 1 -and $setA.slug -eq 'acme-app') '#589: private cards and workflows load from the dossier with the repository slug'
    Assert-Prompts ((Get-SBRepositorySlug 'github.com/acme/Beta') -eq 'beta') '#589: the slug is the lowercased last segment of the identity'
    $listA=Format-SBPrivatePromptList $setA
    Assert-Prompts ($listA.Contains('acme-app/pkg-sign') -and !$listA.Contains('acme-app/pkg-draft') -and !$listA.Contains('beta/notes') -and $listA.Contains('acme-app/release')) '#589: the listing shows only active private assets of its own repository'
    $composed=New-SBPrivatePromptComposition $setA (Resolve-SBPrivatePrompt $setA 'acme-app/pkg-sign') 'sign 1.2'
    Assert-Prompts ($composed.Contains('private="true"') -and $composed.Contains('Objective: sign 1.2') -and $composed.Contains('# acme-app/pkg-sign')) '#589: a private card composes by its namespaced key'
    Assert-PrivateRefused {Resolve-SBPrivatePrompt $setA 'beta/notes'} 'private.notfound' '#589: another repository private key does not resolve here'
    $summary=Test-SBPrivateAssets -BrainRoot $privateRoot -PublicCatalog $catalog
    Assert-Prompts ($summary.dossiers -eq 2 -and $summary.prompts -eq 4 -and $summary.workflows -eq 1) '#589: the workstation check validates every dossier with private assets'
    # Keys, collisions and references.
    $bad=Join-Path $privateRoot '01-projects/acme-app'
    $restore={New-PrivateDossier 'acme-app' 'github.com/acme/acme-app' @($sign,$draft,$wipe) @($flow)}
    New-PrivateDossier 'acme-app' 'github.com/acme/acme-app' @(New-PrivateCard 'pmt-a0000001' 'pkg-sign')
    Assert-PrivateRefused {Read-SBPrivateAssets -Dossier $bad -Repository 'github.com/acme/acme-app' -PublicCatalog $catalog} 'private.invalid' '#589: a key without the repository namespace is refused'
    New-PrivateDossier 'acme-app' 'github.com/acme/acme-app' @(New-PrivateCard 'pmt-a0000001' 'beta/pkg-sign')
    Assert-PrivateRefused {Read-SBPrivateAssets -Dossier $bad -Repository 'github.com/acme/acme-app' -PublicCatalog $catalog} 'private.invalid' '#589: a key in another repository namespace is refused'
    New-PrivateDossier 'acme-app' 'github.com/acme/acme-app' @(New-PrivateCard $publicId 'acme-app/pkg-sign')
    Assert-PrivateRefused {Read-SBPrivateAssets -Dossier $bad -Repository 'github.com/acme/acme-app' -PublicCatalog $catalog} 'private.collision' '#589: a private card reusing a public ID is a collision'
    New-PrivateDossier 'acme-app' 'github.com/acme/acme-app' @(New-PrivateCard 'pmt-b0000001' 'acme-app/pkg-sign')
    Assert-PrivateRefused {Test-SBPrivateAssets -BrainRoot $privateRoot -PublicCatalog $catalog} 'private.collision' '#589: two dossiers sharing a private ID are a collision'
    New-PrivateDossier 'acme-app' 'github.com/acme/acme-app' @(New-PrivateCard 'pmt-a0000001' 'acme-app/pkg-sign' 'write' $false 'active' @('pmt-b0000001'))
    Assert-PrivateRefused {Read-SBPrivateAssets -Dossier $bad -Repository 'github.com/acme/acme-app' -PublicCatalog $catalog} 'private.reference' '#589: a private card citing another dossier private card is refused'
    & $restore
    $unsafe=[ordered]@{}+$flow;$unsafe.steps=@([ordered]@{step='clean';ref='pmt-a0000003';kind='required';gate='auto'})
    New-PrivateDossier 'acme-app' 'github.com/acme/acme-app' @($sign,$draft,$wipe) @($unsafe)
    Assert-PrivateRefused {Read-SBPrivateAssets -Dossier $bad -Repository 'github.com/acme/acme-app' -PublicCatalog $catalog} 'private.invalid' '#589: a destructive workflow step without a confirm gate is refused'
    $deep1=[ordered]@{schemaVersion=1;id='wfl-a0000002';key='acme-app/outer';title='Outer';revision=1;status='active';steps=@([ordered]@{step='inner';ref='wfl-a0000003';kind='required';gate='auto'})}
    $deep2=[ordered]@{schemaVersion=1;id='wfl-a0000003';key='acme-app/inner';title='Inner';revision=1;status='active';steps=@([ordered]@{step='deepest';ref='wfl-a0000001';kind='required';gate='auto'})}
    New-PrivateDossier 'acme-app' 'github.com/acme/acme-app' @($sign,$draft,$wipe) @($flow,$deep1,$deep2)
    Assert-PrivateRefused {Read-SBPrivateAssets -Dossier $bad -Repository 'github.com/acme/acme-app' -PublicCatalog $catalog} 'private.invalid' '#589: workflow nesting deeper than 2 is refused'
    & $restore
    # Public files never cite a private asset.
    Write-PrivateFixture 'direttive/prompts/SYS99.md' 'See acme-app/pkg-sign for the signing steps.'
    Assert-PrivateRefused {Test-SBPrivateAssets -BrainRoot $privateRoot -PublicCatalog $catalog} 'private.public.reference' '#589: a public card citing a private key is refused'
    Assert-Prompts (@(Get-SBPrivateAssetTokens $privateRoot) -contains 'acme-app/pkg-sign' -and @(Find-SBPrivateReferences $privateRoot @('acme-app/pkg-sign')).Count -eq 1) '#589: the publication scan tokens include private keys and find the public reference'
    Write-PrivateFixture 'direttive/proposals/old/proposal.md' 'Historical mention of pmt-a0000001.'
    Remove-Item -LiteralPath (Join-Path $privateRoot 'direttive/prompts/SYS99.md') -Force
    Assert-Prompts ((Test-SBPrivateAssets -BrainRoot $privateRoot -PublicCatalog $catalog).publicReferences -eq 0) '#589: historical proposals are excluded from the public reference rule'
}finally{
    if($env:SECONDBRAIN_TEST_KEEP -ne '1' -and (Test-Path -LiteralPath $privateRoot)){Remove-Item -LiteralPath $privateRoot -Recurse -Force}
}
'SUCCESS PROMPTS: '+$script:promptChecks+' verifiche'
