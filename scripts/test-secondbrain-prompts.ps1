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
$catalog=Read-SBWorkflowCatalog $brain -ValidateBodies
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
$writePrompt=$prompts|Where-Object {$_.mode -eq 'write' -and $_.category -notin @('memory','system')}|Select-Object -First 1
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
[IO.File]::WriteAllText((Join-Path $pointerRoot 'GEMINI.md'),($gemini -replace '@AGENTS.md','@ALTRO.md'))
Assert-Prompts (@(Set-SBRepositoryPointers $pointerRoot $pointerState $true $pointerBackup|Where-Object {$_.file -eq 'GEMINI.md'}).result -eq 'conflict') 'modifica esterna del blocco segnalata come conflitto'
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
foreach($heading in 'Principi','Sicurezza e dati','SecondBrain','Verifica','Git e pubblicazione','Chiusura'){Assert-Prompts ($global -match ('(?m)^## '+[regex]::Escape($heading)+'\s*$')) "sezione '$heading' nel testo comune"}
Assert-Prompts ($global -notmatch 'ask_question|Function Calling') 'nessun nome di strumento non standard nel testo comune'
foreach($text in $global,$station,$repoBlock){Assert-Prompts ($text -notmatch '(?<![A-Za-z0-9+.-])[A-Z]:[\/]|(?<![\w/])/(?:Users|home)/|\{\{') 'nessun percorso assoluto o segnaposto'}
Assert-Prompts ($station.Contains('<!-- secondbrain:tracker-contract:1 -->')) 'contratto tracker presente nel testo di postazione'
$registry=@(Get-SBWorkflowCommands|ForEach-Object {$_.command})
foreach($command in 'sb attiva','sb controlla','sb allinea','sb compatta','sb prompt list','sb prompt ambito AREA','sb prompt mostra CHIAVE'){Assert-Prompts ($command -in $registry) "comando '$command' nel registro"}
foreach($word in 'sb attiva','sb controlla','sb allinea','sb compatta','sb prompt list','sb prompt ambito AREA','sb prompt mostra CHIAVE'){Assert-Prompts ($station.Contains($word)) "comando '$word' descritto nel testo di postazione"}
$referenced=@([regex]::Matches($global+$station+$repoBlock,'(?:COM|PRG|DEV|TST|SEC|AUD|INT|DAT|OPS|DOC|REP|GOV|MEM|SYS)\d{2}')|ForEach-Object {$_.Value}|Select-Object -Unique)
Assert-Prompts (!(@($referenced|Where-Object {$_ -notin @($prompts.code)}).Count)) 'ogni codice prompt citato nelle direttive esiste nel catalogo'
'SUCCESS PROMPTS: '+$script:promptChecks+' verifiche'
