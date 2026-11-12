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
Assert-Prompts ($global -match '(?m)^Revisione \d+\.\d+ — \d{4}-\d{2}-\d{2}\.') 'riga di revisione leggibile dal registro'
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
foreach($command in 'sb attiva','sb controlla','sb allinea','sb compatta','sb stop','sb prompt list','sb prompt ambito AREA','sb prompt mostra CHIAVE'){Assert-Prompts ($command -in $registry) "comando '$command' nel registro"}
Assert-Prompts ((@(Get-SBWorkflowCommands|Where-Object command -eq 'sb stop')[0].script) -match '-Prompt MEM09$') 'sb stop compone MEM09'
foreach($word in 'sb attiva','sb controlla','sb allinea','sb compatta','sb prompt list','sb prompt ambito AREA','sb prompt mostra CHIAVE'){Assert-Prompts ($station.Contains($word)) "comando '$word' descritto nel testo di postazione"}
$referenced=@([regex]::Matches($global+$station+$repoBlock,'(?:COM|PRG|DEV|TST|SEC|AUD|INT|DAT|OPS|DOC|REP|GOV|MEM|SYS)\d{2}')|ForEach-Object {$_.Value}|Select-Object -Unique)
Assert-Prompts (!(@($referenced|Where-Object {$_ -notin @($prompts.code)}).Count)) 'ogni codice prompt citato nelle direttive esiste nel catalogo'
'SUCCESS PROMPTS: '+$script:promptChecks+' verifiche'
