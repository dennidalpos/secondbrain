#requires -Version 7.5
$ErrorActionPreference='Stop'
try {
    if ([Console]::OutputEncoding.CodePage -ne 65001) {
        [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
    }
} catch { }
$OutputEncoding = [Text.UTF8Encoding]::new($false)
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Para.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Prompts.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Publication.psm1') -Force
. (Join-Path $PSScriptRoot 'test-helpers.ps1')
$script:workflowChecks=0
function Assert-Workflow($Condition,[string]$Message){if(!$Condition){throw 'FAIL WORKFLOW: '+$Message};$script:workflowChecks++;'PASS WORKFLOW: '+$Message}
function Reject-Workflow([scriptblock]$Action,[string]$Message){$caught=$false;try{& $Action|Out-Null}catch{$caught=$true};Assert-Workflow $caught $Message}
function Put-Workflow([string]$Path,[string]$Text){[IO.Directory]::CreateDirectory((Split-Path $Path))|Out-Null;[IO.File]::WriteAllText($Path,$Text,[Text.UTF8Encoding]::new($false))}
function Snapshot-Workflow([string]$Path){$state=@{};foreach($f in Get-ChildItem -LiteralPath $Path -File -Recurse -Force){$state[$f.FullName]=@{hash=Get-SBFileHash $f.FullName;time=$f.LastWriteTimeUtc.Ticks}};ConvertTo-SBJson $state}
# Git worktree subprocesses bound GIT_DIR to PATH_MAX-40 on Windows.
# Keep only this synthetic label compact; do not change the runtime root.
$temp=Join-Path (Get-SBTestRoot) ('wf-'+[guid]::NewGuid().ToString('N').Substring(0,20))
try {
    $brain=Join-Path $temp 'brain';$repo=Join-Path $temp 'repos/Repo';$dir=Join-Path $brain '02-areas/products/Repo'
    [IO.Directory]::CreateDirectory((Join-Path $brain 'scripts'))|Out-Null
    Get-ChildItem -LiteralPath $PSScriptRoot -File|Copy-Item -Destination (Join-Path $brain 'scripts')
    [IO.Directory]::CreateDirectory((Join-Path $brain 'direttive'))|Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../direttive/prompts') -Destination (Join-Path $brain 'direttive/prompts') -Recurse
    [IO.Directory]::CreateDirectory((Join-Path $brain 'config'))|Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../config/prompt-catalog.schema.json') -Destination (Join-Path $brain 'config/prompt-catalog.schema.json')
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../config/tracker.schema.json') -Destination (Join-Path $brain 'config/tracker.schema.json')
    [IO.Directory]::CreateDirectory($repo)|Out-Null
    [void](Invoke-SBGit $repo @('init','-q'));[void](Invoke-SBGit $repo @('remote','add','origin','https://github.com/test/repo.git'))
    Put-Workflow (Join-Path $repo 'AGENTS.md') '# Repo'
    Put-Workflow (Join-Path $dir 'para.json') (ConvertTo-SBJson @{schemaVersion=1;id='repo-area';kind='area';title='Repo';status='active'})
    Put-Workflow (Join-Path $dir 'repository.json') (ConvertTo-SBJson @{schemaVersion=1;identity='github.com/test/repo'})
    foreach($name in @('context.md','memory.md','brief.md','tracker.md')){Put-Workflow (Join-Path $dir $name) 'PRIVATE_DOSSIER_CONTENT'}
    Put-Workflow (Join-Path $brain 'config/shared.json') (ConvertTo-SBJson @{schemaVersion=1;allowedOwners=@('test','example-user');excludedDirectories=@('.git')})
    $runtime=Get-SBLocalRoot $brain 'fixture';$configPath=Join-Path $runtime 'workstation.json'
    Put-Workflow $configPath (ConvertTo-SBJson @{schemaVersion=1;mode='portable';workstationId='fixture';runtimeRoot=$runtime;backupRoot=(Join-Path $runtime 'backups');ides=@();
        bindings=@(@{path=$repo;identity='github.com/test/repo';remoteIdentity='github.com/test/repo';status='managed'})})
    $index=Get-SBParaIndex $brain @('test','example-user');Put-Workflow (Join-Path $brain 'para-index.json') $index.json
    $config=@{brainRoot=$brain;allowedOwners=@('test','example-user');workstationId='fixture'}
    $cli=Join-Path $brain 'scripts/prompts.ps1';$build=Join-Path $brain 'scripts/build-prompts.ps1'
    $catalog=Read-SBWorkflowCatalog $brain -ValidateBodies
    Assert-Workflow ($catalog.prompts.Count -eq 81 -and $catalog.categories.Count -eq 14 -and @($catalog.prompts|Where-Object pack -eq 'core').Count -eq 65) '81 workflow (65 core, 16 maintenance) in 14 ambiti'
    $listing=Format-SBWorkflowList $catalog
    Assert-Workflow (@($listing -split "`n"|Where-Object Length -gt 92).Count -eq 0 -and [regex]::Matches($listing,'(?m)^\S+ [A-Z]{2,4}\d{2} \| ').Count -eq 65 -and $listing -notmatch 'MEM0|SYS0') 'elenco core: una riga per prompt entro 88 caratteri più icona, senza prompt di manutenzione'
    Assert-Workflow ($listing -notmatch 'P01.P14' -and $listing -notmatch 'vecchi codici') 'Format-SBWorkflowList privo di nomenclature storiche'
    $testList=Format-SBWorkflowList $catalog 'test'
    Assert-Workflow ($testList -match 'TST04 \|' -and $testList -notmatch 'SYS01 \|') 'filtro ambito'
    Reject-Workflow {Format-SBWorkflowList $catalog 'inesistente'} 'ambito sconosciuto rifiutato'
    $compact=Format-SBWorkflowList $catalog -Compact
    Assert-Workflow (@($compact -split "`n"|Where-Object Length -gt 106).Count -eq 0 -and [regex]::Matches($compact,'(?m)^\S+ [A-Z]{2,4}\d{2} \| (read|write|verify|lettura|scrittura|verifica) +\| ').Count -eq 65 -and $compact -notmatch 'ID: pmt-') 'elenco compatto: 64 righe entro 106 caratteri'
    $prefixList=Format-SBWorkflowList $catalog 'TST' -Compact
    Assert-Workflow ($prefixList -match 'TST04 \|' -and $prefixList -notmatch 'SYS01 \|' -and (Format-SBWorkflowList $catalog 'Test') -match 'TST04 \|' -and (Format-SBWorkflowList $catalog 'sys') -match 'SYS13 \|' -and (Format-SBWorkflowList $catalog 'SYS') -match 'SYS11 \|' -and (Format-SBWorkflowList $catalog 'MEM') -match 'MEM06 \|' -and (Format-SBWorkflowList $catalog 'MEM') -notmatch 'SYS11 \|') 'filtro ambito per id o prefisso senza distinguere le maiuscole; ambito cerca anche nella manutenzione'
    $homeText=Format-SBWorkflowHome $brain $catalog
    $homePath=Join-Path $brain $(if((Get-SBUiLanguage) -eq 'it'){'direttive/prompts/README.it.md'}else{'direttive/prompts/README.md'})
    Assert-Workflow ($homeText.Contains(($homePath -replace '\\','/')) -and (Test-Path -LiteralPath $homePath -PathType Leaf) -and $homeText -match '65 prompt(?: in 12 aree|s in 12 areas)' -and $homeText.Contains((Get-SBMessage 'home.maintenance' @(16)))) 'schermata iniziale: link al catalogo esistente e conteggio'
    Set-SBWorkflowLanguage 'en'
    try{$homeEn=Format-SBWorkflowHome $brain $catalog;Assert-Workflow ($homeEn.Contains(((Join-Path $brain 'direttive/prompts/README.md') -replace '\\','/')) -and $homeEn -match '65 prompts in 12 areas' -and $homeEn -match 'SECONDBRAIN — PROMPTS AND COMMANDS' -and $homeEn -notmatch 'Cosa fa') 'schermata iniziale in inglese: indice, conteggi e testi tradotti'}finally{Set-SBWorkflowLanguage $null}
    $template=Read-SBText (Join-Path $PSScriptRoot '../direttive/workstation.template.md')
    $commands=@(Get-SBWorkflowCommands)
    Assert-Workflow ($commands.Count -ge 9 -and @($commands|Where-Object {!$homeText.Contains('`'+$_.command+'`') -or !$_.does -or !$_.mode}).Count -eq 0) 'schermata iniziale: ogni comando con descrizione e modalità'
    Assert-Workflow (@($commands|Where-Object {$_.command -match '^sb (attiva|controlla|allinea|compatta)$' -and $template -notmatch [regex]::Escape($_.command)}).Count -eq 0) 'comandi sb del registro presenti nella direttiva di postazione'
    $homeProposal=Read-SBText (Join-Path $PSScriptRoot '../direttive/workstation.template.md')
    Assert-Workflow ($homeProposal -match 'sb prompt list \(alias tutti\)' -and $homeProposal -match 'sb prompt maintenance' -and $homeProposal -notmatch 'REP0[257]' -and $homeProposal -match 'get_prompt_home' -and $homeProposal -match 'senza riassumerli') 'proposta direttive: schermata iniziale e elenco integrale'
    $repoRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    Assert-Workflow ($homeText.Contains((Get-SBMessage 'home.first.title')) -and $homeText.Contains((Get-SBMessage 'home.guides.title'))) 'schermata iniziale: primi passi e guide'
    $guides=@(Get-SBWorkflowGuides)
    $readmeRoot=Read-SBText (Join-Path $repoRoot 'README.md')
    Assert-Workflow ($guides.Count -ge 8 -and @($guides|Where-Object {!(Test-Path -LiteralPath (Join-Path $repoRoot (($_.path -split '#')[0])) -PathType Leaf) -or !$homeText.Contains($_.path)}).Count -eq 0) 'guide della schermata iniziale: file esistenti e linkati'
    $customHeadings=Read-SBText (Join-Path $repoRoot 'docs/riferimento/customizing-prompts-and-directives.md')
    $anchorTitles=@{'modifica-dei-prompt'='Modifica dei prompt';'modifica-delle-direttive'='Modifica delle direttive'}
    Assert-Workflow (@($guides|Where-Object {$_.path -match '#'}|Where-Object {$customHeadings -notmatch ('(?m)^## '+[regex]::Escape($anchorTitles[($_.path -split '#')[1]])+'\r?$')}).Count -eq 0) 'ancore delle guide presenti come titoli'
    function Test-CommandLines([string]$Text) {
        $bad=@()
        foreach($line in ($Text -split "`n")){
            if($line -notmatch '(?<![\w-])pwsh -NoProfile -File (scripts/[\w.-]+\.ps1)((?: -[A-Za-z]+(?: (?!-)[^\s`]+)?)*)'){continue}
            $script=Join-Path $repoRoot $Matches[1]
            if(!(Test-Path -LiteralPath $script)){$bad+=$Matches[1];continue}
            $known=(Get-Command $script).Parameters.Keys
            foreach($param in [regex]::Matches($Matches[2],' -([A-Za-z]+)')){if($param.Groups[1].Value -notin $known -and $param.Groups[1].Value -notin @('NoProfile','File')){$bad+=($Matches[1]+' -'+$param.Groups[1].Value)}}
        }
        $bad
    }
    $stepText=(@(Get-SBWorkflowFirstSteps|ForEach-Object command|Where-Object {$_}) -join "`n")
    Assert-Workflow (@(Test-CommandLines $stepText).Count -eq 0 -and @(Get-SBWorkflowFirstSteps).Count -ge 5) 'primi passi: script e parametri esistono'
    $flow=@(Get-SBWorkflowProductFlow)
    $flowScripts=(@($flow|ForEach-Object script|Where-Object {$_ -ne '—'}) + @($commands|ForEach-Object {'pwsh -NoProfile -File '+$_.script})) -join "`n"
    Assert-Workflow ($flow.Count -ge 8 -and @(Test-CommandLines $flowScripts).Count -eq 0 -and @($commands|Where-Object {!$_.script}).Count -eq 0) 'flusso per prodotto e registro: ogni comando da script usa script e parametri reali'
    $flowGuide=Read-SBText (Join-Path $repoRoot 'docs/flusso-prodotto.md')
    Assert-Workflow (@($flow|Where-Object {($_.chat -ne '—' -and !$flowGuide.Contains($_.chat)) -or ($_.script -ne '—' -and !$flowGuide.Contains($_.script))}).Count -eq 0 -and @($guides|Where-Object path -eq 'docs/flusso-prodotto.md').Count -eq 1 -and $readmeRoot.Contains('docs/flusso-prodotto.md')) 'guida flusso per prodotto: stessi passi del menu, registrata e linkata'
    Assert-Workflow (!$homeText.Contains((Get-SBMessage 'home.where')) -and $homeText.Contains((Get-SBMessage 'home.table.commands')) -and $homeText -match 'sb activate') 'schermata iniziale senza percorso: generica, con colonna da script e alias inglesi'
    $stateNone=[ordered]@{activated=$false;hostId='ws-test';repositories=0;ides=0;repository=$null}
    $stateIdle=[ordered]@{activated=$true;hostId='ws-test';repositories=3;ides=2;repository=$null}
    $stateManaged=[ordered]@{activated=$true;hostId='ws-test';repositories=3;ides=2;repository=[ordered]@{path='C:\work\prod';identity='github.com/x/prod';managed=$true}}
    $stateUnmanaged=[ordered]@{activated=$true;hostId='ws-test';repositories=3;ides=2;repository=[ordered]@{path='C:\work\other';identity='github.com/x/other';managed=$false}}
    $stateNoGit=[ordered]@{activated=$true;hostId='ws-test';repositories=3;ides=2;repository=[ordered]@{path='C:\work\plain';identity=$null;managed=$false}}
    $homeNone=Format-SBWorkflowHome $brain $catalog $stateNone
    $homeIdle=Format-SBWorkflowHome $brain $catalog $stateIdle
    $homeManaged=Format-SBWorkflowHome $brain $catalog $stateManaged
    Assert-Workflow ($homeNone.Contains((Get-SBMessage 'home.station.inactive' @('ws-test'))) -and $homeNone.Contains((Get-SBMessage 'home.first.title')) -and !$homeNone.Contains((Get-SBMessage 'home.flow.title')) -and $homeNone.Contains((Get-SBMessage 'home.step.inactive'))) 'menu contestuale: postazione non attivata propone sb attiva e i primi passi'
    Assert-Workflow ($homeIdle.Contains((Get-SBMessage 'home.station.active' @('ws-test',3,2))) -and $homeIdle.Contains((Get-SBMessage 'home.flow.title')) -and !$homeIdle.Contains((Get-SBMessage 'home.first.title')) -and $homeIdle.Contains('repositoryPath')) 'menu contestuale: postazione attivata senza repository mostra il flusso e chiede il percorso'
    Assert-Workflow ($homeManaged.Contains('github.com/x/prod'+(Get-SBMessage 'home.repo.managed')) -and $homeManaged.Contains('sb prompt MEM06') -and (Format-SBWorkflowHome $brain $catalog $stateUnmanaged).Contains((Get-SBMessage 'home.step.unmanaged')) -and (Format-SBWorkflowHome $brain $catalog $stateNoGit).Contains((Get-SBMessage 'home.step.noidentity'))) 'menu contestuale: repository gestito, non gestito e senza Git'
    $stateReal=Get-SBWorkflowState $brain $env:TEMP
    Assert-Workflow ($stateReal.repository -and $null -eq $stateReal.repository.identity -and !$stateReal.repository.managed -and $stateReal.Keys -contains 'activated') 'stato reale: cartella senza Git non ha identità né gestione'
    $startSection=([regex]::Match($readmeRoot,'(?ms)^## Get started\b.*?(?=^## |\z)')).Value
    $italianStart=([regex]::Match($readmeRoot,'(?ms)^### Inizia\b.*?(?=^#{2,3} |\z)')).Value
    Assert-Workflow ($startSection.Contains('docs/sicurezza.md') -and $startSection -match '-Setup' -and $startSection -match '-Pair' -and $startSection -match '-Sync' -and $italianStart.Contains('docs/sicurezza.md') -and $italianStart.Contains('#get-started')) 'README: English setup with safety, MCP and directives; Italian section links to the same commands'
    Assert-Workflow (@(Test-CommandLines $startSection).Count -eq 0 -and @(Test-CommandLines (Read-SBText (Join-Path $repoRoot 'docs/inizia.md'))).Count -eq 0) 'README e setup: comandi con script e parametri esistenti'
    $unifiedGuide=Read-SBText (Join-Path $repoRoot 'docs/guida.md')
    $guideCommands=@([regex]::Matches($unifiedGuide,'`((?:scripts/)?([\w.-]+\.ps1)((?: -[A-Za-z]+(?: (?![-.])[\w<>#:/\\.-]+)?)*))')|ForEach-Object {@{script=$_.Groups[2].Value;parameters=$_.Groups[3].Value}})
    $guideBad=@()
    foreach($command in $guideCommands){
        $scriptPath=Join-Path $repoRoot ('scripts/'+$command.script)
        if(!(Test-Path -LiteralPath $scriptPath)){$guideBad+=$command.script;continue}
        $known=(Get-Command $scriptPath).Parameters.Keys
        foreach($param in [regex]::Matches($command.parameters,' -([A-Za-z]+)')){if($param.Groups[1].Value -notin $known){$guideBad+=($command.script+' -'+$param.Groups[1].Value)}}
    }
    Assert-Workflow ($guideCommands.Count -ge 20 -and $guideBad.Count -eq 0 -and $readmeRoot.Contains('docs/guida.md') -and @(Test-CommandLines $unifiedGuide).Count -eq 0 -and $unifiedGuide -notmatch '(?i)\b[A-Z]:[\\/]Users\b') ('guida unica: comandi e parametri reali, linkata dal README, senza percorsi host'+$(if($guideBad.Count){': '+($guideBad -join ', ')}))
    $runtimeGuide=Read-SBText (Join-Path $repoRoot 'docs/riferimento/runtime-maintenance.md')
    Assert-Workflow (@($guides|Where-Object {$_.path -eq 'docs/riferimento/runtime-maintenance.md'}).Count -eq 1 -and $readmeRoot.Contains('docs/riferimento/runtime-maintenance.md') -and (Read-SBText (Join-Path $repoRoot 'docs/riferimento/operations.md')).Contains('runtime-maintenance.md') -and @(Test-CommandLines $runtimeGuide).Count -eq 0) 'guida runtime-maintenance: nel registro, linkata, con comandi e parametri reali'
    Assert-Workflow ($runtimeGuide -match 'ProposeRuntime' -and $runtimeGuide -match 'Profile Full' -and $runtimeGuide -match 'sb:tier=history' -and $runtimeGuide -match 'non è un manifest eseguibile') 'guida runtime-maintenance: proposta di pulizia, profili di avvio e livelli'
    $contextProposal=Read-SBText (Join-Path $PSScriptRoot '../direttive/workstation.template.md')
    $contextProposalCommon=Read-SBText (Join-Path $PSScriptRoot '../direttive/AGENTS.global_ide.md')
    Assert-Workflow ($contextProposal -match 'profilo snello entro 20\.000' -and $contextProposalCommon -match '20\.000 caratteri' -and $contextProposalCommon -match 'solo per il primo caricamento') 'proposta direttive: contesto iniziale snello a 20.000, tetto solo al primo caricamento'
    Assert-Workflow ($readmeRoot.Contains('docs/sicurezza.md') -and (Read-SBText (Join-Path $repoRoot 'docs/riferimento/operations.md')).Contains('safety-backups.md')) 'guida sicurezza linkata da README e operations'
    $guideProposal=Read-SBText (Join-Path $PSScriptRoot '../direttive/workstation.template.md')
    Assert-Workflow ($guideProposal -match 'primi passi' -and $guideProposal -match 'guide per il primo avvio' -and $guideProposal -match 'get_prompt_home') 'proposta direttive: primi passi e guide'
    Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Publication.psm1') -Force
    $policyBrain=Join-Path $temp 'policy-brain'
    Assert-Workflow ($null -eq (Resolve-SBPublicationPolicyPath $policyBrain $null)) 'policy pubblicazione: assente senza file di default'
    Put-Workflow (Join-Path $policyBrain '.runtime/publication/policy.json') '{"schemaVersion":1,"allowances":[]}'
    Assert-Workflow ((Resolve-SBPublicationPolicyPath $policyBrain $null) -eq '.runtime/publication/policy.json' -and (Resolve-SBPublicationPolicyPath $policyBrain 'altra.json') -eq 'altra.json') 'policy pubblicazione: default se presente, override esplicito prevalente'
    Assert-Workflow ((Read-SBText (Join-Path $PSScriptRoot 'SecondBrain.Mcp.psm1')).Contains('Resolve-SBPublicationPolicyPath') -and (Read-SBText (Join-Path $PSScriptRoot 'publication.ps1')).Contains('Resolve-SBPublicationPolicyPath')) 'policy pubblicazione: MCP e CLI usano la stessa risoluzione'
    Assert-Workflow ((Read-SBText (Join-Path $PSScriptRoot 'SecondBrain.Knowledge.psm1')) -match 'function Get-SBSlimStartupBudget \{ 20000 \}' -and (Read-SBText (Join-Path $PSScriptRoot 'SecondBrain.Portable.psm1')) -match '(?s)\$budget = Get-SBSlimStartupBudget.{0,400}-Profile Slim' -and (Read-SBText (Join-Path $PSScriptRoot 'knowledge.ps1')).Contains('Get-SBSlimStartupBudget')) 'Check e knowledge.ps1 misurano il profilo Slim con la stessa fonte unica (20.000 caratteri)'
    $cliHome=& pwsh -NoProfile -File $cli
    Assert-Workflow ($LASTEXITCODE -eq 0 -and ($cliHome -join "`n") -match 'sb prompt tutti' -and ($cliHome -join "`n") -notmatch 'TST04 \|') 'CLI senza argomenti mostra la schermata iniziale e non l''elenco'
    $cliCompact=& pwsh -NoProfile -File $cli -List -Compact
    Assert-Workflow ($LASTEXITCODE -eq 0 -and [regex]::Matches(($cliCompact -join "`n"),'(?m)^\S+ [A-Z]{2,4}\d{2} \| ').Count -eq 65) 'CLI -List -Compact elenca i 65 prompt core attivi'
    # Localized residual messages (SB-EVO-20261103-13): -Pair and Bootstrap line follow -Language; snippet contents stay unchanged.
    $mcpCli=Join-Path $PSScriptRoot 'mcp-server.ps1'
    $pairEn=(& pwsh -NoProfile -File $mcpCli -Pair -Target codex -Language en 2>&1|Out-String);$pairIt=(& pwsh -NoProfile -File $mcpCli -Pair -Target codex -Language it 2>&1|Out-String)
    Assert-Workflow ($pairEn -match 'SecondBrain MCP pairing for' -and $pairEn -match 'Equivalent CLI command' -and $pairEn -notmatch 'Accoppiamento' -and $pairIt -match 'Accoppiamento MCP SecondBrain per' -and $pairIt -match 'Comando CLI equivalente' -and $pairIt -notmatch 'pairing for') '-Pair: intestazioni e sezioni seguono -Language en/it'
    Assert-Workflow (($pairEn -replace '(?s)^.*?(\[mcp_servers)','$1' -replace '(?s)---.*$','') -ceq ($pairIt -replace '(?s)^.*?(\[mcp_servers)','$1' -replace '(?s)---.*$','')) '-Pair: lo snippet di configurazione e identico nelle due lingue'
    $promptsCliText=Read-SBText (Join-Path $PSScriptRoot 'prompts.ps1')
    Assert-Workflow ($promptsCliText.Contains("Get-SBMessage 'promptscli.bootstrap'") -and $promptsCliText.Contains("Get-SBMessage 'promptscli.output.created'") -and $promptsCliText -notmatch '(?m)^\s*''Bootstrap: usa' -and $promptsCliText -notmatch '(?m)^\s*''Creato: ''\+') 'prompts.ps1: Bootstrap e Creato passano dal catalogo messaggi'
    $catalogPath=Join-Path $brain 'direttive/prompts/catalog.json';$original=Read-SBText $catalogPath
    foreach($case in @('duplicate','category','path','mode','newline','related','relatedCode','duplicateId','aliasOfCode','aliasTwice','aliasSelfId','missingAliases','retiredUnknown','retiredConflict','deprecatedNoSuccessor','successorUnknown','nextUnknown','nextSelf','nextTooMany','i18nMissing')){
        $bad=$original|ConvertFrom-Json -AsHashtable
        switch($case){
            duplicate {$bad.prompts[1].code='COM01'}
            category {$bad.prompts[0].category='unknown'}
            path {$bad.prompts[0].file='../secret.md'}
            mode {$bad.prompts[0].mode='execute'}
            newline {$bad.prompts[0].summary="one`ntwo"}
            related {$bad.prompts[0].related=@('pmt-00000000')}
            relatedCode {$bad.prompts[0].related=@('COM02')}
            duplicateId {$bad.prompts[1].id=$bad.prompts[0].id}
            aliasOfCode {$bad.prompts[0].aliases=@($bad.prompts[1].code)}
            aliasTwice {$bad.prompts[0].aliases=@('ZZZ01');$bad.prompts[1].aliases=@('ZZZ01')}
            aliasSelfId {$bad.prompts[0].aliases=@($bad.prompts[0].code)}
            missingAliases {$bad.prompts[0].Remove('aliases')}
            retiredUnknown {$bad.deprecations=@(@{alias='OLD01';supersededBy='pmt-00000000'})}
            retiredConflict {$bad.deprecations=@(@{alias=$bad.prompts[1].code;supersededBy=$bad.prompts[0].id})}
            deprecatedNoSuccessor {$bad.prompts[0].status='deprecated'}
            successorUnknown {$bad.prompts[0].status='deprecated';$bad.prompts[0].supersededBy='pmt-00000000'}
            nextUnknown {$bad.prompts[0].next=@('pmt-00000000')}
            nextSelf {$bad.prompts[0].next=@($bad.prompts[0].id)}
            nextTooMany {$bad.prompts[0].next=@($bad.prompts[1].id,$bad.prompts[2].id,$bad.prompts[3].id,$bad.prompts[4].id,$bad.prompts[5].id)}
            i18nMissing {$bad.prompts[0].Remove('i18n')}
        }
        Put-Workflow $catalogPath (ConvertTo-SBJson $bad)
        Reject-Workflow {Read-SBWorkflowCatalog $brain -ValidateBodies} ('validazione '+$case)
    }
    Assert-Workflow (@($catalog.prompts.id|Select-Object -Unique).Count -eq 81 -and @($catalog.prompts|Where-Object {$_.id -cnotmatch '^pmt-[0-9a-f]{8}$'}).Count -eq 0) 'ogni prompt ha un ID univoco pmt-esadecimale'
    # REP11/REP12 (SB-EVO-20261103-08): issue-reporting and branch-consolidation prompts, with GitHub forms in the distribution.
    $repNew=@($catalog.prompts|Where-Object code -in 'REP11','REP12','REP13')
    Assert-Workflow ($repNew.Count -eq 3 -and @($repNew|Where-Object {$_.category -ceq 'repository' -and $_.pack -ceq 'core' -and $_.mode -ceq 'write' -and $_.status -ceq 'active' -and $_.ContainsKey('i18n') -and $_.i18n.ContainsKey('it')}).Count -eq 3) 'REP11, REP12 e REP13: prompt core attivi in scrittura con traduzione it'
    Assert-Workflow ((Read-SBText (Join-Path $repoRoot 'direttive/prompts/REP13.md')) -match 'never made public' -and (Read-SBText (Join-Path $repoRoot 'direttive/prompts/it/REP13.md')) -match 'mai reso pubblico') 'REP13: la scheda vieta di rendere pubblico un repository privato'
    $issueForms=@('bug.yml','feature.yml','config.yml')|ForEach-Object {Join-Path $repoRoot (Join-Path '.github/ISSUE_TEMPLATE' $_)}
    Assert-Workflow (@($issueForms|Where-Object {Test-Path -LiteralPath $_ -PathType Leaf}).Count -eq 3 -and (Read-SBText $issueForms[2]) -match 'blank_issues_enabled: false' -and (Read-SBText $issueForms[0]) -match 'type: textarea' -and (Read-SBText (Join-Path $PSScriptRoot 'check-distribution.ps1')).Contains("'.github/'")) 'form issue .github/ISSUE_TEMPLATE presenti e ammessi dal controllo di distribuzione'
    $nextBad=@($catalog.prompts|Where-Object {$_.status -ne 'deprecated' -and (!$_.ContainsKey('next') -or @($_.next).Count -lt 1 -or @($_.next).Count -gt 4)})
    Assert-Workflow ($nextBad.Count -eq 0) 'ogni scheda attiva ha da 1 a 4 candidati next validi (esistenti, diversi da se)'
    # Catalog refinement (SB-EVO-PROMPT-CATALOG-REFINE): PRG05 scaffolding (write) and PRG06 plan (read), SYS06 in memory, TST07 write, new cards.
    $byCode=@{};foreach($entry in $catalog.prompts){$byCode[$entry.code]=$entry}
    $refined=@{PRG05=@('progettazione','write');PRG06=@('progettazione','read');MEM06=@('memoria','read');TST07=@('test','write');OPS05=@('operativita','write');DEV07=@('sviluppo','read');DEV08=@('sviluppo','read');INT04=@('interfaccia','verify')}
    $refinedIssues=@(foreach($code in $refined.Keys){if(!$byCode.ContainsKey($code) -or $byCode[$code].category -cne $refined[$code][0] -or $byCode[$code].mode -cne $refined[$code][1]){$code}})
    Assert-Workflow ($refinedIssues.Count -eq 0 -and $byCode['PRG05'].id -ceq 'pmt-884419a5' -and $byCode['MEM06'].id -ceq 'pmt-821f7dec' -and $byCode['PRG06'].related -contains $byCode['PRG05'].id) ('categorie, modalità e ID del raffinamento'+$(if($refinedIssues.Count){': '+($refinedIssues -join ', ')}))
    $first=$catalog.prompts[0];$second=$catalog.prompts[1]
    $renamed=$original|ConvertFrom-Json -AsHashtable
    $renamed.prompts[0].aliases=@('ZZZ01','ZZZ02');$renamed.deprecations=@(@{alias='OLD01';supersededBy=$second.id})
    Put-Workflow $catalogPath (ConvertTo-SBJson $renamed)
    $aliased=Read-SBWorkflowCatalog $brain -ValidateBodies
    Assert-Workflow ((Resolve-SBWorkflowPrompt $aliased $first.id).prompt.code -ceq $first.code -and (Resolve-SBWorkflowPrompt $aliased $first.code).via -eq 'code' -and (Resolve-SBWorkflowPrompt $aliased 'ZZZ02').prompt.id -ceq $first.id -and (Resolve-SBWorkflowPrompt $aliased 'ZZZ02').via -eq 'alias') 'ID, codice e alias multipli risolvono allo stesso prompt'
    $retired=Resolve-SBWorkflowPrompt $aliased 'OLD01'
    Assert-Workflow ($retired.prompt.id -ceq $second.id -and $retired.via -eq 'deprecated-alias' -and $retired.warning -match $second.code) 'alias ritirato risolve al sostituto con avviso'
    Reject-Workflow {Resolve-SBWorkflowPrompt $aliased 'zzz01'} 'alias sensibile alle maiuscole'
    $withoutRetired=@{prompts=$catalog.prompts}
    $noRetired=New-SBWorkflowPromptId $withoutRetired
    Assert-Workflow ($noRetired -cmatch '^pmt-[0-9a-f]{8}$' -and !$withoutRetired.ContainsKey('deprecations')) 'nuovo ID generato anche senza chiave deprecations nel catalogo'
    $freshId=New-SBWorkflowPromptId $aliased
    Assert-Workflow ($freshId -cmatch '^pmt-[0-9a-f]{8}$' -and $freshId -cnotin @($aliased.prompts.id)) 'nuovo ID libero e ben formato'
    $retiredCli=& pwsh -NoProfile -File $cli -Show -Prompt OLD01 2>&1|Out-String
    Assert-Workflow ($LASTEXITCODE -eq 0 -and $retiredCli.Contains('# '+$second.code+' — ') -and $retiredCli -match 'ritirato') 'CLI mostra il sostituto con avviso per alias ritirato'
    $viaAlias=& pwsh -NoProfile -File $cli -Show -Prompt ZZZ02|Out-String
    Assert-Workflow ($LASTEXITCODE -eq 0 -and $viaAlias.Contains('# '+$first.code+' — ') -and $viaAlias.Contains('ID '+$first.id)) 'CLI risolve alias aggiunto'
    $deprecated=$original|ConvertFrom-Json -AsHashtable
    $deprecated.prompts[0].status='deprecated';$deprecated.prompts[0].supersededBy=$second.id
    Put-Workflow $catalogPath (ConvertTo-SBJson $deprecated)
    $withDeprecated=Read-SBWorkflowCatalog $brain -ValidateBodies
    Assert-Workflow ((Format-SBWorkflowList $withDeprecated) -notmatch ($first.code+' \|') -and (Resolve-SBWorkflowPrompt $withDeprecated $first.code).warning -match $second.code) 'prompt ritirato nascosto dall elenco e risolvibile con avviso'
    Put-Workflow $catalogPath $original
    $card=Join-Path $brain 'direttive/prompts/TST04.md';$cardText=Read-SBText $card
    Put-Workflow $card ($cardText.Replace('## Checks','## Altro'))
    Reject-Workflow {Read-SBWorkflowCatalog $brain -ValidateBodies} 'sezione obbligatoria assente'
    $listOnly=& pwsh -NoProfile -File $cli -List
    Assert-Workflow ($LASTEXITCODE -eq 0 -and ($listOnly -join "`n") -match 'TST04 \|') 'elenco legge metadati senza caricare tutte le schede'
    & pwsh -NoProfile -File $cli -Show -Prompt TST04 -Language en *> $null
    Assert-Workflow ($LASTEXITCODE -eq 2) 'visualizzazione rifiuta scheda non valida'
    Put-Workflow $card $cardText
    $cardIt=Join-Path $brain 'direttive/prompts/it/TST04.md';$cardItText=Read-SBText $cardIt
    Put-Workflow $cardIt ($cardItText.Replace('## Verifiche','## Altro'))
    Reject-Workflow {Read-SBWorkflowCatalog $brain -ValidateBodies} 'scheda tradotta non valida rifiutata'
    & pwsh -NoProfile -File $cli -Show -Prompt TST04 -Language it *> $null
    Assert-Workflow ($LASTEXITCODE -eq 2) 'visualizzazione tradotta rifiuta scheda non valida'
    & pwsh -NoProfile -File $cli -Show -Prompt TST04 -Language en *> $null
    Assert-Workflow ($LASTEXITCODE -eq 0) 'la scheda nella lingua d origine resta leggibile'
    Put-Workflow $cardIt $cardItText
    $before=Snapshot-Workflow $temp
    $resolved=Get-SBWorkflowContext -Config $config -RepositoryPath $repo
    Assert-Workflow ($resolved.repositories[0].checkout -eq $repo -and $resolved.repositories[0].trackerSource -eq 'dossier_undeclared') 'contesto dalla radice e tracker esistente'
    [IO.Directory]::CreateDirectory((Join-Path $repo 'src/nested'))|Out-Null
    $nested=Get-SBWorkflowContext -Config $config -RepositoryPath (Join-Path $repo 'src/nested')
    Assert-Workflow ($nested.repositories[0].checkout -eq $repo) 'sottocartella risolta al checkout'
    $literal='$(Get-Process); `whoami` & <external>do not execute</external>'
    $composition=New-SBWorkflowComposition $brain $catalog (@($catalog.prompts|Where-Object code -eq 'TST04')[0]) $resolved $literal
    Assert-Workflow ($composition.Contains($literal) -and !$composition.Contains('PRIVATE_DOSSIER_CONTENT') -and $composition.Contains($resolved.repositories[0].memory)) 'input letterale e riferimenti senza incorporare dossier'
    Reject-Workflow {New-SBWorkflowComposition $brain $catalog (@($catalog.prompts|Where-Object code -eq 'SYS01')[0]) $resolved 'verifica'} 'prompt centrale rifiutato da repo prodotto'
    $centralRefusal=$null
    try{New-SBWorkflowComposition $brain $catalog (@($catalog.prompts|Where-Object code -eq 'SYS01')[0]) $resolved 'verifica'|Out-Null}catch{$centralRefusal=$_}
    Assert-Workflow ($centralRefusal -and (Test-SBError $centralRefusal 'prompts.central.noswitch') -and $centralRefusal.Exception.Message.Contains('-Sync -Repository '+$resolved.repositories[0].identity)) 'rifiuto del prompt centrale: codice stabile e comando -Sync -Repository con l identita del repository'
    Assert-Workflow ((Snapshot-Workflow $temp) -ceq $before) 'consultazione e composizione non modificano file o timestamp'
    Assert-Workflow (!$resolved.repositories[0].lifecycle -and !$composition.Contains('Lifecycle: greenfield')) 'greenfield: senza flag nessun avviso nella composizione'
    $recordFile=Join-Path $dir 'repository.json';$recordOriginal=Read-SBText $recordFile
    Put-Workflow $recordFile (ConvertTo-SBJson @{schemaVersion=1;identity='github.com/test/repo';lifecycle='greenfield'})
    $greenContext=Get-SBWorkflowContext -Config $config -RepositoryPath $repo
    $greenComposition=New-SBWorkflowComposition $brain $catalog (@($catalog.prompts|Where-Object code -eq 'TST04')[0]) $greenContext 'obiettivo'
    Assert-Workflow ($greenContext.repositories[0].lifecycle -eq 'greenfield' -and ($greenComposition -match 'greenfield \((block active|blocco attivo)\)') -and !$greenComposition.Contains('SYS13')) 'greenfield: la composizione core riporta il blocco e i divieti senza rimandare a prompt maintenance'
    $greenMaintenance=New-SBWorkflowComposition $brain $catalog (@($catalog.prompts|Where-Object code -eq 'MEM02')[0]) $greenContext 'obiettivo'
    Assert-Workflow ($greenMaintenance -match 'greenfield \((block active|blocco attivo)\)' -and $greenMaintenance.Contains('SYS13')) 'greenfield: la composizione maintenance rimanda a SYS13'
    Put-Workflow $recordFile (ConvertTo-SBJson @{schemaVersion=1;identity='github.com/test/repo';lifecycle='altro'})
    Reject-Workflow {Get-SBWorkflowContext -Config $config -RepositoryPath $repo} 'greenfield: valore di lifecycle sconosciuto rifiutato'
    Put-Workflow $recordFile $recordOriginal
    foreach($greenCode in @('SYS13')){
        $greenCard=@($catalog.prompts|Where-Object code -eq $greenCode)[0]
        Assert-Workflow ($greenCard -and $greenCard.target -eq 'repository' -and $greenCard.mode -eq 'write' -and (Test-Path -LiteralPath (Join-Path $brain ('direttive/prompts/'+$greenCode+'.md')))) ('greenfield: scheda '+$greenCode+' presente (repository, scrittura)')
    }
    Push-Location (Join-Path $repo 'src/nested')
    try{$cwd=& pwsh -NoProfile -File $cli -Context -ConfigPath $configPath|Out-String}finally{Pop-Location}
    Assert-Workflow ($LASTEXITCODE -eq 0 -and ($cwd|ConvertFrom-Json).repositories[0].checkout -eq $repo) 'CLI usa cwd e non la directory dello script'
    Put-Workflow $catalogPath '{"invalid":true}'
    $independent=& pwsh -NoProfile -File $cli -Context -RepositoryPath $repo -ConfigPath $configPath|Out-String
    Assert-Workflow ($LASTEXITCODE -eq 0 -and ($independent|ConvertFrom-Json).repositories[0].memory -eq (Join-Path $dir 'memory.md')) 'memorie risolvibili anche con catalogo prompt non valido'
    Put-Workflow $catalogPath $original
    $out=Join-Path $brain '.runtime/output.txt'
    & pwsh -NoProfile -File $cli -Compose -Prompt TST04 -Objective $literal -RepositoryPath $repo -ConfigPath $configPath -OutputPath $out|Out-Null
    Assert-Workflow ($LASTEXITCODE -eq 0 -and (Read-SBText $out).Contains($literal)) 'CLI output nuovo e input letterale'
    $outHash=Get-SBFileHash $out
    & pwsh -NoProfile -File $cli -Compose -Prompt TST04 -Objective 'altro' -RepositoryPath $repo -ConfigPath $configPath -OutputPath $out *> $null
    Assert-Workflow ($LASTEXITCODE -eq 2 -and (Get-SBFileHash $out) -eq $outHash) 'output esistente preservato'
    & pwsh -NoProfile -File $cli -Show -Prompt TST99 *> $null
    Assert-Workflow ($LASTEXITCODE -eq 2) 'codice sconosciuto rifiutato'
    & pwsh -NoProfile -File $build -ConfigPath $configPath|Out-Null
    Assert-Workflow ($LASTEXITCODE -eq 0) 'indice generato dalla CLI'
    $indexPath=Join-Path $brain 'direttive/prompts/README.md';$stamp=(Get-Item $indexPath).LastWriteTimeUtc.Ticks
    & pwsh -NoProfile -File $build -ConfigPath $configPath|Out-Null
    Assert-Workflow ($LASTEXITCODE -eq 0 -and (Get-Item $indexPath).LastWriteTimeUtc.Ticks -eq $stamp) 'generazione idempotente'
    $indexText=Read-SBText $indexPath;Put-Workflow $indexPath ($indexText+'manuale')
    & pwsh -NoProfile -File $build -Check -ConfigPath $configPath *> $null
    Assert-Workflow ($LASTEXITCODE -eq 1 -and (Read-SBText $indexPath).EndsWith('manuale')) 'Check rileva drift senza correggerlo'
    Put-Workflow $card ($cardText.Replace('## Input','## Altro'))
    & pwsh -NoProfile -File $build -ConfigPath $configPath *> $null
    Assert-Workflow ($LASTEXITCODE -ne 0 -and (Read-SBText $indexPath).EndsWith('manuale')) 'scheda invalida protegge indice esistente'
    Put-Workflow $card $cardText;Put-Workflow $indexPath $indexText
    $paraPath=Join-Path $brain 'para-index.json';$paraOriginal=Read-SBText $paraPath
    Put-Workflow $paraPath ($paraOriginal.Replace('02-areas/products/Repo','02-areas/products/Elsewhere'))
    Reject-Workflow {Get-SBWorkflowContext -Config $config -RepositoryPath $repo} 'indice PARA divergente rifiutato'
    Put-Workflow $paraPath $paraOriginal
    $meta=Read-SBJson (Join-Path $dir 'para.json') $null;$meta.status='retired'
    Put-Workflow (Join-Path $dir 'para.json') (ConvertTo-SBJson $meta)
    Reject-Workflow {Get-SBWorkflowContext -Config $config -RepositoryPath $repo} 'dossier ritirato non riattivato'
    $meta.status='active';Put-Workflow (Join-Path $dir 'para.json') (ConvertTo-SBJson $meta)
    $declaration=@{schemaVersion=1;identity='github.com/test/repo';tracker=@{location='dossier';path='tracker.json';schemaVersion=1}}
    Put-Workflow (Join-Path $dir 'repository.json') (ConvertTo-SBJson $declaration)
    Reject-Workflow {Get-SBWorkflowContext -Config $config -RepositoryPath $repo} 'tracker dichiarato assente senza fallback'
    Put-Workflow (Join-Path $dir 'repository.json') (ConvertTo-SBJson @{schemaVersion=1;identity='github.com/test/repo'})
    [void](Invoke-SBGit $repo @('remote','set-url','origin','https://github.com/excluded/repo.git'))
    Reject-Workflow {Get-SBWorkflowContext -Config $config -RepositoryPath $repo} 'owner escluso rifiutato'
    [void](Invoke-SBGit $repo @('remote','set-url','origin','https://github.com/test/repo.git'))
    [void](Invoke-SBGit $repo @('add','AGENTS.md'))
    $commit=Invoke-SBGit $repo @('-c','user.name=Fixture','-c','user.email=fixture@example.invalid','commit','-qm','fixture')
    if($commit.code -ne 0){throw $commit.error}
    $worktree=Join-Path $temp 'worktree'
    $created=Invoke-SBGit $repo @('worktree','add','--detach',$worktree)
    if($created.code -ne 0){throw $created.error}
    $wt=Get-SBWorkflowContext -Config $config -RepositoryPath $worktree
    Assert-Workflow ($wt.repositories[0].checkout -eq $worktree -and $wt.repositories[0].memory -eq $resolved.repositories[0].memory) 'worktree usa checkout effettivo e dossier della stessa identita'
    $project=Join-Path $brain '01-projects/fixture'
    Put-Workflow (Join-Path $project 'para.json') (ConvertTo-SBJson @{schemaVersion=1;id='fixture-project';kind='project';title='Fixture';status='active';areas=@('repo-area');trackers=@(@{area='repo-area';path='tracker.md'})})
    Put-Workflow (Join-Path $project 'brief.md') 'BRIEF_MARKER $(Get-Process)'
    $newIndex=Get-SBParaIndex $brain @('test','example-user');Put-Workflow $paraPath $newIndex.json
    Put-Workflow (Join-Path $brain 'inventory.json') (ConvertTo-SBJson @{schemaVersion=1;repositories=@(@{identities=@('github.com/test/repo');path=$repo;status='active';workstationId='fixture'},@{identities=@('github.com/test/repo');path=$worktree;status='active';workstationId='fixture'})})
    Reject-Workflow {Get-SBWorkflowContext -Config $config -Repository 'github.com/test/repo'} 'selezione per identita ambigua rifiutata'
    $map=Join-Path $temp 'map.json';Put-Workflow $map (ConvertTo-SBJson @{'github.com/test/repo'=$worktree})
    $projectContext=Get-SBWorkflowContext -Config $config -ProjectId 'fixture-project' -CheckoutMapPath $map
    $projectText=New-SBWorkflowComposition $brain $catalog (@($catalog.prompts|Where-Object code -eq 'PRG04')[0]) $projectContext 'piano'
    Assert-Workflow ($projectText.Contains('BRIEF_MARKER') -and $projectText.Contains($worktree) -and !$projectText.Contains('PRIVATE_DOSSIER_CONTENT')) 'Progetto con mappa checkout e brief separato dai dossier'
    # A real central checkout exercises the target gate and multi-Area composition.
    [void](Invoke-SBGit $brain @('init','-q'));[void](Invoke-SBGit $brain @('remote','add','origin','https://github.com/example-user/secondbrain.git'))
    Put-Workflow (Join-Path $brain 'AGENTS.md') '# Central'
    $centralDir=Join-Path $brain '02-areas/products/SecondBrain'
    Put-Workflow (Join-Path $centralDir 'para.json') (ConvertTo-SBJson @{schemaVersion=1;id='central-area';kind='area';title='SecondBrain';status='active'})
    Put-Workflow (Join-Path $centralDir 'repository.json') (ConvertTo-SBJson @{schemaVersion=1;identity='github.com/example-user/secondbrain'})
    foreach($name in @('context.md','memory.md','brief.md')){Put-Workflow (Join-Path $centralDir $name) '# Central dossier'}
    $projectMeta=Read-SBJson (Join-Path $project 'para.json') $null;$projectMeta.areas+=@('central-area')
    Put-Workflow (Join-Path $project 'para.json') (ConvertTo-SBJson $projectMeta)
    $newIndex=Get-SBParaIndex $brain @('test','example-user');Put-Workflow $paraPath $newIndex.json
    Put-Workflow $map (ConvertTo-SBJson @{'github.com/test/repo'=$worktree;'github.com/example-user/secondbrain'=$brain})
    $multi=Get-SBWorkflowContext -Config $config -ProjectId 'fixture-project' -CheckoutMapPath $map
    Assert-Workflow ($multi.repositories.Count -eq 2 -and @($multi.repositories|Where-Object checkout -eq $brain).Count -eq 1) 'Progetto multi-Area con checkout verificati'
    $central=Get-SBWorkflowContext -Config $config -RepositoryPath $brain
    $centralText=New-SBWorkflowComposition $brain $catalog (@($catalog.prompts|Where-Object code -eq 'SYS01')[0]) $central 'verifica'
    Assert-Workflow ($centralText -match 'SYS01' -and $centralText.Contains($brain)) 'prompt centrale composto solo per SecondBrain'
    Reject-Workflow {New-SBWorkflowComposition $brain $catalog (@($catalog.prompts|Where-Object code -eq 'SYS02')[0]) $multi 'verifica'} 'prompt centrale rifiuta Progetto comprendente prodotti'
    Put-Workflow (Join-Path $brain 'direttive/AGENTS.global_ide.md') "# Common`nRevisione 1.0 — 2026-10-28."
    Put-Workflow (Join-Path $brain 'direttive/workstation.template.md') '<!-- secondbrain:tracker-contract:1 -->'
    Put-Workflow (Join-Path $brain 'direttive/approved.json') (ConvertTo-SBJson @{authorization='fixture';files=@{'direttive/AGENTS.global_ide.md'=Get-SBFileHash (Join-Path $brain 'direttive/AGENTS.global_ide.md');'direttive/workstation.template.md'=Get-SBFileHash (Join-Path $brain 'direttive/workstation.template.md')}})
    Put-Workflow (Join-Path $dir 'repository.json') (ConvertTo-SBJson $declaration)
    Put-Workflow (Join-Path $dir 'tracker.json') (ConvertTo-SBJson @{schemaVersion=1;repository='github.com/test/repo';updatedAt=[DateTimeOffset]::UtcNow.ToString('o');tasks=@();history=@();extensions=@{}})
    $declared=Get-SBWorkflowContext -Config $config -RepositoryPath $repo
    Assert-Workflow ($declared.repositories[0].trackerSource -eq 'dossier' -and $declared.repositories[0].tracker.EndsWith('tracker.json')) 'fonte dichiarata valida prevale sul legacy'
    Put-Workflow (Join-Path $dir 'tracker.json') '{"schemaVersion":1,"tasks":"invalid"}'
    Reject-Workflow {Get-SBWorkflowContext -Config $config -RepositoryPath $repo} 'tracker dichiarato invalido senza fallback'
    Put-Workflow (Join-Path $dir 'repository.json') (ConvertTo-SBJson @{schemaVersion=1;identity='github.com/test/repo'})
    $archive=Join-Path $brain '04-archives/areas/Archived'
    Put-Workflow (Join-Path $archive 'para.json') (ConvertTo-SBJson @{schemaVersion=1;id='archived-area';kind='area';title='Archived';status='retired'})
    Put-Workflow (Join-Path $archive 'repository.json') (ConvertTo-SBJson @{schemaVersion=1;identity='github.com/test/archived'})
    foreach($name in @('context.md','memory.md','brief.md')){Put-Workflow (Join-Path $archive $name) '# Archived'}
    $newIndex=Get-SBParaIndex $brain @('test','example-user');Put-Workflow $paraPath $newIndex.json
    Reject-Workflow {Get-SBWorkflowContext -Config $config -Repository 'github.com/test/archived'} 'dossier archiviato non riattivato'
    $cases=Read-SBJson (Join-Path $PSScriptRoot 'fixtures/prompts.json') $null
    foreach($case in $cases.cases){
        $rendered=(& pwsh -NoProfile -File $cli -Compose -Prompt $case.code -Objective $case.objective -RepositoryPath $repo -ConfigPath $configPath|Out-String)
        $caseEntry=@($catalog.prompts|Where-Object code -ceq $case.code)[0];$caseText=Get-SBWorkflowText $caseEntry
        Assert-Workflow ($LASTEXITCODE -eq 0 -and $rendered.StartsWith($caseText.catalog+' — '+$case.code+' | ')) ('fixture workflow '+$case.code+': selezione CLI')
        Assert-Workflow ($rendered.Contains($case.objective) -and $rendered.Contains(($caseText.cardMode -f $case.mode,$caseEntry.target))) ('fixture workflow '+$case.code+': richiesta e modalita')
        Assert-Workflow ([regex]::Matches($rendered,'(?m)^'+$caseText.title+': [A-Z]{2,4}[0-9]{2} — ').Count -eq 1 -and !$rendered.Contains('PRIVATE_DOSSIER_CONTENT')) ('fixture workflow '+$case.code+': una sola scheda, dossier per riferimento')
    }
    # Card labels by pack: core in English, maintenance in Italian.
    function Get-CardLabels($Text){@($Text.card,($Text.id+': pmt-'),($Text.title+': '),($Text.does+': '),($Text.example+': '),($Text.mode+': '),($Text.scope+': '),($Text.needs+': '),($Text.rule.Substring(0,$Text.rule.IndexOf(':')+2)))}
    $cardLabels=Get-CardLabels (Get-SBWorkflowText @{pack='maintenance'})
    $incomplete=@()
    foreach($entry in $catalog.prompts){
        $entryText=Get-SBWorkflowText $entry
        $cardBody=Read-SBWorkflowPrompt $brain $entry $catalog
        $cardText=Format-SBWorkflowCard $entry $cardBody
        foreach($label in (Get-CardLabels $entryText)){if(!$cardText.Contains($label)){$incomplete+=$entry.code+':'+$label}}
        $toolUse='Function Calling (o Tool Use a scelta multipla|or Tool Use as multiple choice)'
        if($cardText -notmatch $toolUse -or $cardText -match ([regex]::Escape($entryText.does)+': \s*$')){$incomplete+=$entry.code+':contenuto'}
    }
    Assert-Workflow ($incomplete.Count -eq 0) ('scheda uniforme completa per tutti i 81 prompt'+$(if($incomplete.Count){': '+(($incomplete|Select-Object -First 3) -join ', ')}))
    $sample=@($catalog.prompts|Where-Object code -ceq 'DEV02')[0]
    Set-SBWorkflowLanguage 'en'
    try{$sampleCard=Format-SBWorkflowCard $sample (Read-SBWorkflowPrompt $brain $sample $catalog)}finally{Set-SBWorkflowLanguage $null}
    $shown=(& pwsh -NoProfile -File $cli -Show -Prompt DEV02 -Language en|Out-String).Replace("`r`n","`n")
    $composed=(& pwsh -NoProfile -File $cli -Compose -Prompt $sample.id -Objective 'x' -RepositoryPath $repo -ConfigPath $configPath -Language en|Out-String).Replace("`r`n","`n")
    Assert-Workflow ($shown.Contains($sampleCard) -and $composed.Contains($sampleCard)) 'stessa scheda in -Show e -Compose (anche per ID)'
    Assert-Workflow ([regex]::Matches($composed,'Binding rule: if in doubt').Count -eq 2 -and $composed.Contains('stop and do not proceed on assumptions') -and $composed -notmatch 'tracker del dossier|Decisione:|secondbrain\.ps1|Registro Azioni|Set-SBTrackerTaskStatus') 'composizione core in inglese: impone Function Calling o Tool Use per i dubbi, chiusura neutra'
    $maintenanceSample=@($catalog.prompts|Where-Object code -ceq 'MEM02')[0]
    $maintenanceComposed=(& pwsh -NoProfile -File $cli -Compose -Prompt MEM02 -Objective 'x' -RepositoryPath $repo -ConfigPath $configPath -Language it|Out-String).Replace("`r`n","`n")
    $coreIt=(& pwsh -NoProfile -File $cli -Compose -Prompt DEV02 -Objective 'x' -RepositoryPath $repo -ConfigPath $configPath -Language it|Out-String).Replace("`r`n","`n")
    Assert-Workflow ($coreIt.Contains('Regola vincolante: se hai dubbi') -and $coreIt.Contains('SCHEDA PROMPT') -and $coreIt -notmatch 'tracker del dossier|Decisione:|secondbrain\.ps1|Set-SBTrackerTaskStatus|SYS13' -and $coreIt -notmatch 'Binding rule') 'composizione core in italiano: scheda tradotta e chiusura neutra'
    $maintenanceEn=(& pwsh -NoProfile -File $cli -Compose -Prompt MEM02 -Objective 'x' -RepositoryPath $repo -ConfigPath $configPath -Language en|Out-String).Replace("`r`n","`n")
    Assert-Workflow ($maintenanceEn.Contains('Binding rule: if in doubt') -and $maintenanceEn.Contains('Closing the task and updating SecondBrain') -and $maintenanceEn.Contains('memory.md') -and $maintenanceEn -notmatch 'Regola vincolante') 'composizione maintenance in inglese: scheda tradotta e chiusura SecondBrain'
    Assert-Workflow ([regex]::Matches($maintenanceComposed,'Regola vincolante: se hai dubbi').Count -eq 2 -and $maintenanceComposed.Contains('fermati e non procedere per ipotesi') -and $maintenanceComposed.Contains('Chiusura del task e aggiornamento SecondBrain') -and $maintenanceComposed.Contains('memory.md')) 'composizione maintenance in italiano con chiusura SecondBrain'
    # "Decisioni da raccogliere": optional section, required in prompts requesting choices, with Function Calling / Tool Use.
    $decisionCodes=@('SYS11','SYS01','MEM03','COM01','COM02','PRG01','PRG02','SYS03','SYS04','SYS05','SEC07','MEM01','PRG06','DEV07','OPS05')
    $decisionIssues=@()
    foreach($code in $decisionCodes){
        $entry=@($catalog.prompts|Where-Object code -ceq $code)[0]
        $text=(Read-SBWorkflowPrompt $brain $entry $catalog $(if($entry.pack -eq 'maintenance'){'it'}else{'en'}))
        $decisionTitle=if($entry.pack -eq 'maintenance'){'Decisioni da raccogliere'}else{'Decisions to collect'}
        $section=if([regex]::Matches($text,'(?m)^## '+$decisionTitle+'\n').Count -eq 1){([regex]::Split($text,'(?m)^## '+$decisionTitle+'\n')[1] -split '(?m)^## ',2)[0]}else{''}
        if(!$section -or $section -notmatch '(?m)^- '){$decisionIssues+=$code}
    }
    Assert-Workflow ($decisionIssues.Count -eq 0) ('sezione Decisioni da raccogliere con elenco di decisioni nei prompt con scelte (la regola Function Calling / Tool Use è nel compositore)'+$(if($decisionIssues.Count){': '+($decisionIssues -join ', ')}))
    $handoff=Read-SBWorkflowPrompt $brain (@($catalog.prompts|Where-Object code -ceq 'MEM03')[0]) $catalog 'it'
    Assert-Workflow ($handoff -match 'context\.md' -and $handoff -match 'memory\.md' -and $handoff -match 'tracker' -and $handoff -match 'Sync e Check' -and $handoff -match 'commit e push' -and $handoff -match 'niente force push' -and $handoff -match 'sessione') 'MEM03 copre memorie, tracker, handoff, Sync/Check e richiesta esplicita di commit e push'
    $sys11=Read-SBWorkflowPrompt $brain (@($catalog.prompts|Where-Object code -ceq 'SYS11')[0]) $catalog 'it'
    Assert-Workflow ($sys11 -match '\*\*Aggiungi\.\*\*' -and $sys11 -match '\*\*Modifica\.\*\*' -and $sys11 -match '\*\*Rimuovi\.\*\*' -and $sys11 -match 'build-prompts\.ps1' -and $sys11 -match 'supersededBy' -and $sys11 -match 'deprecations') 'SYS11 descrive aggiunta, modifica e ritiro con indice generato e sostituto'
    $decisionCard=Join-Path $brain 'direttive/prompts/SYS11.md';$decisionOriginal=Read-SBText $decisionCard
    Put-Workflow $decisionCard ($decisionOriginal+"`n## Decisioni da raccogliere`n`nduplicata`n")
    Reject-Workflow {Read-SBWorkflowCatalog $brain -ValidateBodies} 'sezione Decisioni da raccogliere duplicata rifiutata'
    Put-Workflow $decisionCard ($decisionOriginal -replace '(?s)(## Decisioni da raccogliere\n).*?(?=\n## Verifiche)','$1')
    Reject-Workflow {Read-SBWorkflowCatalog $brain -ValidateBodies} 'sezione Decisioni da raccogliere vuota rifiutata'
    Put-Workflow $decisionCard $decisionOriginal
    # Title, header and "Prompt vicini" must repeat the catalog; no placeholders among related prompts.
    $driftCard=Join-Path $brain 'direttive/prompts/COM01.md';$driftOriginal=Read-SBText $driftCard
    Put-Workflow $driftCard ($driftOriginal -replace '\*\*Needs\*\*: ','**Needs**: other ')
    Reject-Workflow {Read-SBWorkflowCatalog $brain -ValidateBodies} 'scheda: intestazione diversa dal catalogo rifiutata'
    Put-Workflow $driftCard ($driftOriginal -replace '(?m)^# COM01 — .+$','# COM01 — Altro titolo')
    Reject-Workflow {Read-SBWorkflowCatalog $brain -ValidateBodies} 'scheda: titolo diverso dal catalogo rifiutato'
    Put-Workflow $driftCard ($driftOriginal -replace '(?m)^- COM02: .+$','- COM02: descrizione diversa dal catalogo.')
    Reject-Workflow {Read-SBWorkflowCatalog $brain -ValidateBodies} 'scheda: Prompt vicini con descrizione diversa dal catalogo rifiutati'
    Put-Workflow $driftCard ($driftOriginal -replace '(?m)^- COM02: .+$','- COM02: consultare la scheda soltanto quando pertinente.')
    Reject-Workflow {Read-SBWorkflowCatalog $brain -ValidateBodies} 'scheda: Prompt vicini segnaposto rifiutati'
    Put-Workflow $driftCard $driftOriginal
    # SYS11 use cases on a fixture brain: add, edit, remove and reject.
    $uc=Read-SBWorkflowCatalog $brain -ValidateBodies;$sys04=@($uc.prompts|Where-Object code -ceq 'SYS04')[0];$sys11e=@($uc.prompts|Where-Object code -ceq 'SYS11')[0]
    $newId=New-SBWorkflowPromptId $uc
    $newCard=Join-Path $brain 'direttive/prompts/SYS98.md'
    # The card repeats catalog title, header and related prompts: the fixture aligns them with the test entry.
    function Get-FixtureCard([string]$Body,[string]$Summary,$Neighbor){
        $lines=$Body.Split("`n")
        $lines[0]='# SYS98 — '+$Summary.TrimEnd('.')
        $lines[2]='> **Scope**: central | **Modalità**: scrittura | **Cosa serve**: prova caso d uso | **Esempio d''uso**: `sb prompt SYS98: prova`'
        $text=$lines -join "`n"
        [regex]::Replace($text,"(?s)(## Prompt vicini`n`n).*?(`n`n## |\z)",{param($m) $m.Groups[1].Value+'- '+$Neighbor.code+': '+$Neighbor.summary+$m.Groups[2].Value})
    }
    $newBody=Get-FixtureCard ($decisionOriginal.Replace('SYS11','SYS98')) 'Prova uso aggiunta prompt.' $sys04
    Put-Workflow $newCard $newBody
    # Required translation (SB-EVO-20261103-14): en card and i18n entry for the other language.
    $newCardEn=Join-Path $brain 'direttive/prompts/en/SYS98.md';$decisionOriginalEn=Read-SBText (Join-Path $brain 'direttive/prompts/en/SYS11.md')
    function Get-FixtureCardEn([string]$Summary,$Neighbor){
        $lines=$decisionOriginalEn.Replace('SYS11','SYS98').Split("`n")
        $lines[0]='# SYS98 — '+$Summary.TrimEnd('.')
        $lines[2]='> **Scope**: central | **Mode**: write | **Needs**: use case test | **Example**: `sb prompt SYS98: test`'
        $text=$lines -join "`n"
        [regex]::Replace($text,"(?s)(## Related prompts`n`n).*?(`n`n## |\z)",{param($m) $m.Groups[1].Value+'- '+$Neighbor.code+': '+$Neighbor.i18n.en.summary+$m.Groups[2].Value})
    }
    Put-Workflow $newCardEn (Get-FixtureCardEn 'Test adding a prompt.' $sys04)
    $added=$original|ConvertFrom-Json -AsHashtable
    $entryNew=@{aliases=@();category='sistema';pack='maintenance';code='SYS98';example='sb prompt SYS98: prova';file='SYS98.md';id=$newId;mode='write';references=@('https://code.claude.com/docs/en/prompt-library');related=@($sys04.id);requires='prova caso d uso';scope='central';status='active';summary='Prova uso aggiunta prompt.';target='central';i18n=@{en=@{summary='Test adding a prompt.';requires='use case test';example='sb prompt SYS98: test'}}}
    $added.prompts=@($added.prompts)+@($entryNew)
    Put-Workflow $catalogPath (ConvertTo-SBJson $added)
    $afterAdd=Read-SBWorkflowCatalog $brain -ValidateBodies
    Assert-Workflow ($afterAdd.prompts.Count -eq 82 -and (Resolve-SBWorkflowPrompt $afterAdd 'SYS98').prompt.id -ceq $newId -and (Resolve-SBWorkflowPrompt $afterAdd $newId).via -eq 'id') 'caso d uso: aggiunta di un prompt con ID nuovo risolvibile per codice e ID'
    $driftAdd=@(Get-SBWorkflowDrift $brain)
    Assert-Workflow ($driftAdd.Count -eq 2 -and @($driftAdd|Where-Object {$_.path -notmatch 'README\.maintenance(\.it)?\.md$'}).Count -eq 0 -and (Format-SBWorkflowList $afterAdd -Pack maintenance) -match 'SYS98 \| (Prova uso aggiunta prompt|Test adding a prompt)\.' -and (Format-SBWorkflowList $afterAdd) -notmatch 'SYS98') 'caso d uso: un prompt di manutenzione compare nell elenco maintenance e non altera l indice core'
    $dupId=(ConvertTo-SBJson $added)|ConvertFrom-Json -AsHashtable;$dupId.prompts[-1].id=$sys11e.id
    Put-Workflow $catalogPath (ConvertTo-SBJson $dupId)
    Reject-Workflow {Read-SBWorkflowCatalog $brain -ValidateBodies} 'caso d uso: aggiunta con ID duplicato rifiutata'
    $wrongFile=(ConvertTo-SBJson $added)|ConvertFrom-Json -AsHashtable;$wrongFile.prompts[-1].file='SYS99.md'
    Put-Workflow $catalogPath (ConvertTo-SBJson $wrongFile)
    Reject-Workflow {Read-SBWorkflowCatalog $brain -ValidateBodies} 'caso d uso: aggiunta con file diverso dal codice rifiutata'
    Put-Workflow $newCard ($newBody.Replace('SYS04','SYS03'))
    Put-Workflow $catalogPath (ConvertTo-SBJson $added)
    Reject-Workflow {Read-SBWorkflowCatalog $brain -ValidateBodies} 'caso d uso: related non documentato nella scheda rifiutato'
    $modifiedBody=Get-FixtureCard ($decisionOriginal.Replace('SYS11','SYS98')) 'Prova uso modifica prompt.' $sys04
    Put-Workflow $newCard $modifiedBody
    Put-Workflow $newCardEn (Get-FixtureCardEn 'Test changing a prompt.' $sys04)
    $modified=(ConvertTo-SBJson $added)|ConvertFrom-Json -AsHashtable
    $modified.prompts[-1].summary='Prova uso modifica prompt.';$modified.prompts[-1].i18n.en.summary='Test changing a prompt.';$modified.prompts[-1].aliases=@('ZZZ12')
    Put-Workflow $catalogPath (ConvertTo-SBJson $modified)
    $afterModify=Read-SBWorkflowCatalog $brain -ValidateBodies
    Assert-Workflow ((Resolve-SBWorkflowPrompt $afterModify 'ZZZ12').prompt.id -ceq $newId -and (Resolve-SBWorkflowPrompt $afterModify 'SYS98').prompt.id -ceq $newId -and (Format-SBWorkflowList $afterModify -Pack maintenance) -match 'SYS98 \| (Prova uso modifica prompt|Test changing a prompt)\.') 'caso d uso: modifica mantiene l ID e aggiunge un alias risolvibile'
    $removed=(ConvertTo-SBJson $modified)|ConvertFrom-Json -AsHashtable
    $removed.prompts[-1].status='deprecated'
    Put-Workflow $catalogPath (ConvertTo-SBJson $removed)
    Reject-Workflow {Read-SBWorkflowCatalog $brain -ValidateBodies} 'caso d uso: ritiro senza sostituto rifiutato'
    $removed.prompts[-1].supersededBy=$sys11e.id;$removed.deprecations=@(@{alias='OLD12';supersededBy=$sys11e.id})
    Put-Workflow $catalogPath (ConvertTo-SBJson $removed)
    $afterRemove=Read-SBWorkflowCatalog $brain -ValidateBodies
    Assert-Workflow ((Format-SBWorkflowList $afterRemove -Pack all) -notmatch 'SYS98 \|' -and (Resolve-SBWorkflowPrompt $afterRemove 'SYS98').warning -match 'SYS11' -and (Resolve-SBWorkflowPrompt $afterRemove 'OLD12').prompt.id -ceq $sys11e.id -and (Test-Path -LiteralPath $newCard)) 'caso d uso: ritiro con sostituto nasconde il prompt, risolve con avviso e conserva la scheda'
    Put-Workflow $catalogPath $original
    Remove-Item -LiteralPath $newCard -Force;Remove-Item -LiteralPath $newCardEn -Force
    Assert-Workflow ((Read-SBWorkflowCatalog $brain -ValidateBodies).prompts.Count -eq 81 -and @(Get-SBWorkflowDrift $brain).Count -eq 0) 'caso d uso: catalogo fixture ripristinato e allineato'
    $proposalText=Read-SBText (Join-Path $PSScriptRoot '../direttive/workstation.template.md')
    $previousWorkflowLanguage=Get-SBWorkflowLanguageOverride
    try { Set-SBWorkflowLanguage 'it'; $directiveCardLabels=Get-CardLabels (Get-SBWorkflowText @{pack='maintenance'}) } finally { Set-SBWorkflowLanguage $previousWorkflowLanguage }
    Assert-Workflow (($directiveCardLabels|Where-Object {$_ -notin @('SCHEDA PROMPT','ID: pmt-')}|Where-Object {!$proposalText.Contains($_.TrimEnd(' ',':'))}).Count -eq 0 -and $proposalText.Contains('ID') -and $proposalText -match 'Function Calling / Tool Use a scelta multipla' -and $proposalText -match 'fermati') 'direttive: elencano i campi della scheda e la regola tool-use'
    $costarCatalog=Read-SBWorkflowCatalog $brain -ValidateBodies
    $costarContext=@{repositories=@(@{identity='github.com/test/repo';checkout=$brain;agents='AGENTS.md';context='context.md';memory='memory.md';tracker=$null;trackerSource=$null;sourceApplicability=$null});sourceRegistry=$null;project=$null}
    $costarBad=@($costarCatalog.prompts|Where-Object {
        $composed=New-SBWorkflowComposition $brain $costarCatalog $_ $costarContext 'obiettivo di prova'
        $last=-1;$ordered=$true
        foreach($part in 'Context','Objective','Style','Tone','Audience','Response'){$at=$composed.IndexOf("`n## $part`n");if($at -le $last){$ordered=$false};$last=$at}
        !$ordered -or !$composed.Contains('obiettivo di prova')
    })
    Assert-Workflow ($costarBad.Count -eq 0) 'CO-STAR: tutti i prompt composti hanno le 6 sezioni in ordine'
    $dodBad=@($costarCatalog.prompts|Where-Object {
        $composed=New-SBWorkflowComposition $brain $costarCatalog $_ $costarContext 'obiettivo di prova'
        $dodText=Get-SBWorkflowText $_
        $response=$composed.IndexOf("`n## Response`n");$dod=$composed.IndexOf("`n### $($dodText.dod)`n");$near=$composed.IndexOf("`n### $($dodText.related)`n")
        $dod -le $response -or $dod -ge $near -or $composed.IndexOf("`n## Response`n",$response+1) -ge 0
    })
    Assert-Workflow ($dodBad.Count -eq 0) 'DoD: ogni prompt composto ha la definizione di completamento dentro Response'
    $proposalBad=@($costarCatalog.prompts|Where-Object {
        $composed=New-SBWorkflowComposition $brain $costarCatalog $_ $costarContext 'obiettivo di prova'
        $nextText=Get-SBWorkflowText $_
        $at=$composed.IndexOf("`n### $($nextText.next)`n");$near=$composed.IndexOf("`n### $($nextText.related)`n");$dod=$composed.IndexOf("`n### $($nextText.dod)`n")
        $expected=if($_.ContainsKey('next')){@($_.next|ForEach-Object {$id=$_;($costarCatalog.prompts|Where-Object id -eq $id).code})}else{@()}
        $block=if($at -ge 0 -and $near -gt $at){$composed.Substring($at,$near-$at)}else{''}
        $choice,$noStart='scelta multipla|multiple choice','non avviare altri prompt|do not start other prompts'
        $at -le $dod -or $near -le $at -or $block -notmatch $choice -or $block -notmatch $noStart -or @($expected|Where-Object {$block -notmatch ('(?m)^- '+$_+': ')}).Count
    })
    Assert-Workflow ($proposalBad.Count -eq 0) 'prompt successivo: ogni composizione chiude con la proposta a scelta multipla dopo la DoD e con i candidati della scheda'
    $repoPrompt=@($costarCatalog.prompts|Where-Object {$_.target -eq 'repository' -and $_.status -ne 'deprecated'})[0]
    $centralCandidate=@($costarCatalog.prompts|Where-Object {$_.target -eq 'central' -and $_.status -ne 'deprecated'})[0]
    $repoCandidate=@($costarCatalog.prompts|Where-Object {$_.target -eq 'repository' -and $_.status -ne 'deprecated' -and $_.id -ne $repoPrompt.id})[0]
    $probePrompt=@{}+$repoPrompt;$probePrompt.next=@($centralCandidate.id,$repoCandidate.id)
    $productContext=@{repositories=@(@{identity='github.com/test/repo';checkout=(Join-Path $temp 'repos/Repo');agents='AGENTS.md';context='context.md';memory='memory.md';tracker=$null;trackerSource=$null;sourceApplicability=$null});sourceRegistry=$null;project=$null}
    $productComposed=New-SBWorkflowComposition $brain $costarCatalog $probePrompt $productContext 'obiettivo di prova'
    $productText=Get-SBWorkflowText $probePrompt
    $productBlock=$productComposed.Substring($productComposed.IndexOf("`n### $($productText.next)`n"),$productComposed.IndexOf("`n### $($productText.related)`n")-$productComposed.IndexOf("`n### $($productText.next)`n"))
    Assert-Workflow ($productBlock -match ('(?m)^- '+$repoCandidate.code+': ') -and $productBlock -notmatch ('(?m)^- '+$centralCandidate.code+': ')) 'prompt successivo: fuori da SecondBrain i prompt centrali non sono proposti'
    $productVersion=(Read-SBText (Join-Path $PSScriptRoot '../VERSION')).Trim()
    $revisionLine=[regex]::Match((Read-SBText (Join-Path $PSScriptRoot '../direttive/AGENTS.global_ide.md')),'(?m)^Revisione (\d+\.\d+) ').Groups[1].Value
    Assert-Workflow ($productVersion -match '^\d+\.\d+\.\d+$' -and $productVersion.StartsWith($revisionLine+'.')) 'VERSION coerente con la revisione delle direttive'
    Assert-Workflow (@(Get-SBWorkflowDrift ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')))).Count -eq 0) 'catalogo reale allineato'
    # Message language: override, SECONDBRAIN_LANG, culture precedence; stable code does not change with language.
    $savedLang=$env:SECONDBRAIN_LANG
    try {
        $env:SECONDBRAIN_LANG='en';Set-SBUiLanguage ''
        Assert-Workflow ((Get-SBUiLanguage) -ceq 'en' -and (Get-SBMessage 'core.block.duplicate' @('x')) -ceq 'Duplicate block: x') 'lingua en da SECONDBRAIN_LANG'
        $env:SECONDBRAIN_LANG='it'
        Assert-Workflow ((Get-SBUiLanguage) -ceq 'it' -and (Get-SBMessage 'core.block.duplicate' @('x')) -ceq 'Blocco duplicato: x') 'lingua it da SECONDBRAIN_LANG'
        Set-SBUiLanguage 'en'
        Assert-Workflow ((Get-SBUiLanguage) -ceq 'en') 'override esplicito prevale sulla variabile'
        Reject-Workflow { Set-SBUiLanguage 'fr' } 'lingua non supportata rifiutata'
        Set-SBUiLanguage ''
        Assert-Workflow ((Get-SBMessage 'chiave.inesistente') -ceq 'chiave.inesistente') 'chiave sconosciuta restituisce la chiave'
        $codes=@{}
        foreach($lang in 'it','en'){
            $env:SECONDBRAIN_LANG=$lang
            try { Read-SBConfiguration (Join-Path $temp 'config-inesistente.json') | Out-Null } catch { $codes[$lang]=@{code=$_.Exception.Data['code'];text=$_.Exception.Message} }
        }
        Assert-Workflow ($codes.it.code -ceq 'access.config.missing' -and $codes.en.code -ceq 'access.config.missing') 'stesso codice stabile in it e en'
        Assert-Workflow ($codes.it.text -like 'Configurazione non trovata:*' -and $codes.en.text -like 'Configuration not found:*') 'testo localizzato per lingua'
        $messageGaps=@()
        foreach($file in Get-ChildItem -LiteralPath $PSScriptRoot -Filter 'SecondBrain.*.psm1'|Where-Object Name -ne 'SecondBrain.Messages.psm1'){Import-Module $file.FullName -Force}
        foreach($file in Get-ChildItem -LiteralPath $PSScriptRoot -Filter 'SecondBrain.*.psm1'){
            foreach($m in [regex]::Matches((Read-SBText $file.FullName),"New-SBError '([a-z0-9.]+)'|Get-SBMessage '([a-z0-9.]+)'")){
                $key=if($m.Groups[1].Success){$m.Groups[1].Value}else{$m.Groups[2].Value}
                if((Get-SBMessage $key @() 'en') -ceq $key -or (Get-SBMessage $key @() 'it') -ceq $key){$messageGaps+=$key}
            }
        }
        Assert-Workflow (!$messageGaps.Count) ('ogni chiave usata ha testo it e en'+$(if($messageGaps.Count){': '+(($messageGaps|Select-Object -Unique) -join ', ')}))
        # Every module/script throw carries a key: only network machine codes (Sources) and the standalone distribution script remain.
        $literalThrows=@()
        $scriptGaps=@()
        foreach($file in Get-ChildItem -LiteralPath $PSScriptRoot -Include '*.ps1','*.psm1' -File|Where-Object {$_.Name -notlike 'test-*' -and $_.Name -ne 'check-distribution.ps1'}){
            $source=Read-SBText $file.FullName
            foreach($m in [regex]::Matches($source,"throw\s+['""]([^'""]*)['""]")){
                # Exceptions: network machine codes and the standalone launcher generated inside an MCP package (imports no modules).
                if($m.Groups[1].Value -notmatch '^(redirect-limit|http-\$code|download-too-large|access-challenge|Impossibile trovare scripts/mcp-server\.ps1 .*)$'){$literalThrows+=($file.Name+': '+$m.Groups[1].Value)}
            }
            if($file.Extension -eq '.ps1'){
                foreach($m in [regex]::Matches($source,"New-SBError '([a-z0-9.]+)'")){
                    $escaped=[regex]::Escape($m.Groups[1].Value)
                    if($source -notmatch ("'"+$escaped+"'\s*=\s*@\{\s*it\s*=.*en\s*=")){$scriptGaps+=($file.Name+': '+$m.Groups[1].Value)}
                }
            }
        }
        Assert-Workflow (!$literalThrows.Count) ('nessun throw con testo letterale nei moduli e negli script'+$(if($literalThrows.Count){': '+(($literalThrows|Select-Object -First 5) -join '; ')}))
        Assert-Workflow (!$scriptGaps.Count) ('ogni chiave usata dagli script ha testo it e en nello script'+$(if($scriptGaps.Count){': '+(($scriptGaps|Select-Object -Unique -First 5) -join '; ')}))
        # Same code in it and en for the last converted modules; text changes with language.
        $env:SECONDBRAIN_LANG='it'; $itPara=Get-SBMessage 'para.status.invalid'
        $env:SECONDBRAIN_LANG='en'; $enPara=Get-SBMessage 'para.status.invalid'
        Assert-Workflow ($itPara -ceq 'Stato PARA non valido' -and $enPara -ceq 'Invalid PARA status') 'catalogo messaggi: Para in it e en'
        $env:SECONDBRAIN_LANG='it'
    } finally { $env:SECONDBRAIN_LANG=$savedLang; Set-SBUiLanguage '' }
    'SUCCESS WORKFLOWS: '+$script:workflowChecks+' verifiche; nessuna valutazione di comportamento LLM implicita.'
} finally {
    $resolvedTemp=[IO.Path]::GetFullPath($temp)
    $boundary=[IO.Path]::GetFullPath((Get-SBTestRoot)).TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar

    if(Test-Path -LiteralPath $resolvedTemp){Write-Output ('Fixture conservata: '+$resolvedTemp)}
}
