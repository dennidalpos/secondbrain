#requires -Version 7.5
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Host.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Knowledge.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Prompts.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.TrackerImport.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Sources.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Para.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Tracker.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Add-SBMessages @{
    'portable.git.required' = @{it='Serve Git 2.42 o successivo, eseguibile e con versione riconoscibile';en='Git 2.42 or later is required, executable and with a recognizable version'}
    'portable.mcp.targets' = @{it='Selezionare target MCP validi per approvare i tool di conoscenza';en='Select valid MCP targets to approve knowledge tools'}
    'portable.selection.summary' = @{ it = 'Selezione: {0} repository, {1} IDE'; en = 'Selection: {0} repositories, {1} IDEs' }
    'portable.unbind.summary' = @{ it = 'Disassociazione di {0} repository e {1} integrazioni IDE: dossier e file IDE restano.'; en = 'Unbinding {0} repositories and {1} IDE integrations: dossiers and IDE files are kept.' }
    'portable.output.summary' = @{ it = 'Output di {0}: {1} -> {2}'; en = 'Output for {0}: {1} -> {2}' }
    'portable.issue.forbidden' = @{ it = 'Repository vietato presente nei binding attivi'; en = 'Forbidden repository present in the active bindings' }
    'portable.issue.output' = @{ it = 'Configuration and proof of build/cache output locations belong to the product agent'; en = 'Configuration and proof of build/cache output locations belong to the product agent' }
    'portable.issue.compaction' = @{ it = 'Proporre SYS05 (sb compatta): nulla viene compattato senza conferma'; en = 'Propose SYS05 (sb compact): nothing is compacted without confirmation' }
    'portable.issue.closure' = @{ it = 'Un task e stato chiuso dopo l ultimo aggiornamento di memory.md: aggiornare memoria e contesto con MEM03.'; en = 'A task was closed after the last memory.md update: update memory and context with MEM03.' }
    'portable.issue.idecontext' = @{ it = 'Contesto IDE diverso da quello registrato: riverificare login e caricamento, quindi riattivare con Setup e ritirare il vecchio accesso con Unbind'; en = 'IDE context differs from the recorded one: re-verify login and loading, then re-activate with Setup and withdraw the old access with Unbind' }
    'portable.issue.writer' = @{ it = 'Un writer e attivo: l esito puo riflettere uno stato intermedio, ripetere il controllo'; en = 'A writer is active: the result may reflect an intermediate state, repeat the check' }
    'portable.prompt.repos' = @{ it = 'Repository trovati:'; en = 'Repositories found:' }
    'portable.prompt.noremote' = @{ it = 'senza remoto: identita locale'; en = 'no remote: local identity' }
    'portable.prompt.ides' = @{ it = 'IDE trovati:'; en = 'IDEs found:' }
    'portable.directives.unapproved' = @{ it = 'Direttive non ancora approvate: distribuzione sospesa'; en = 'Directives not yet approved: distribution suspended' }
    'portable.directives.nonportable' = @{ it = 'Direttive globali non portabili'; en = 'Global directives are not portable' }
    'portable.selection.unconfirmed' = @{ it = 'Selezione richiede confirmed=true e riferimento alla conferma effettiva dellʼutente'; en = 'Selection requires confirmed=true and a reference to the user''s actual confirmation' }
    'portable.discovery.modified' = @{ it = 'Rapporto discovery modificato'; en = 'Discovery report modified' }
    'portable.discovery.foreign' = @{ it = 'Discovery di altro host o clone'; en = 'Discovery from another host or clone' }
    'portable.repository.notinreport' = @{ it = 'Repository selezionato non presente nel rapporto'; en = 'Selected repository not present in the report' }
    'portable.repository.forbidden' = @{ it = 'Repository vietato dalle policy di postazione: {0} ({1})'; en = 'Repository forbidden by workstation policy: {0} ({1})' }
    'portable.checkout.changed' = @{ it = 'Checkout cambiato dopo la discovery: {0}'; en = 'Checkout changed after discovery: {0}' }
    'portable.repository.noremote' = @{ it = 'Repo senza remoto: usare identita locale oppure associare esplicitamente un dossier esistente'; en = 'Repository without a remote: use a local identity or explicitly bind an existing dossier' }
    'portable.identity.invalid' = @{ it = 'Identita non valida'; en = 'Invalid identity' }
    'portable.identity.reconcile' = @{ it = 'Cambio di identita richiede riconciliazione esplicita degli alias'; en = 'Identity change requires explicit alias reconciliation' }
    'portable.dossier.ambiguous' = @{ it = 'Dossier ambiguo, archiviato o ritirato'; en = 'Dossier ambiguous, archived or retired' }
    'portable.alias.dossier' = @{ it = 'Associazione alias richiede dossier esistente e revisione esplicita'; en = 'Alias binding requires an existing dossier and explicit review' }
    'portable.origin.bound' = @{ it = 'Origin gia associato a un altro dossier'; en = 'Origin already bound to another dossier' }
    'portable.destination.uncensused' = @{ it = 'Destinazione non censita gia presente'; en = 'Uncensused destination already present' }
    'portable.block.review' = @{ it = 'Blocco esistente richiede revisione nella selezione'; en = 'Existing block requires review in the selection' }
    'portable.ide.notinreport' = @{ it = 'IDE selezionato non presente nel rapporto'; en = 'Selected IDE not present in the report' }
    'portable.ide.changed' = @{ it = 'Istruzioni IDE cambiate dopo la discovery'; en = 'IDE instructions changed after discovery' }
    'portable.path.filetype' = @{ it = 'Percorso istruzioni alternativo ammesso solo per IDE di tipo file: {0}'; en = 'Alternative instructions path allowed only for file-type IDEs: {0}' }
    'portable.ide.duplicate' = @{ it = 'Integrazione IDE duplicata nella selezione (stesso profilo, alias, ambiente e percorso): {0}'; en = 'Duplicate IDE integration in the selection (same profile, alias, environment and path): {0}' }
    'portable.checkout.unmanaged' = @{ it = 'Checkout da disassociare non gestito'; en = 'Checkout to unbind is not managed' }
    'portable.ide.unmanaged' = @{ it = 'Integrazione IDE da disassociare non gestita'; en = 'IDE integration to unbind is not managed' }
    'portable.choice.invalid' = @{ it = 'Scelta non valida: {0}'; en = 'Invalid choice: {0}' }
    'portable.path.unsupported' = @{ it = 'Percorso istruzioni alternativo non supportato per {0}'; en = 'Alternative instructions path not supported for {0}' }
    'portable.path.notabsolute' = @{ it = 'Percorso istruzioni alternativo non assoluto'; en = 'Alternative instructions path is not absolute' }
    'portable.path.filename' = @{ it = 'Il file delle istruzioni di {0} deve chiamarsi {1}'; en = 'The instructions file of {0} must be named {1}' }
    'portable.path.outsideprofile' = @{ it = 'Percorso istruzioni alternativo fuori dal profilo utente'; en = 'Alternative instructions path outside the user profile' }
    'portable.path.credentials' = @{ it = 'Percorso istruzioni alternativo in una cartella di credenziali'; en = 'Alternative instructions path in a credentials folder' }
    'portable.preflight.failed' = @{ it = 'Preflight non superato: {0}'; en = 'Preflight failed: {0}' }
    'portable.selection.missing' = @{ it = 'Selezione assente: indicare -Select, -All, -Ides, -AllIdes, -IdeAccount oppure -Interactive'; en = 'No selection: give -Select, -All, -Ides, -AllIdes, -IdeAccount or -Interactive' }
    'portable.repository.ambiguous' = @{ it = 'Repository non selezionabile o ambiguo: {0} ({1} corrispondenze)'; en = 'Repository not selectable or ambiguous: {0} ({1} matches)' }
    'portable.ideaccount.invalid' = @{ it = 'IdeAccount non valido (atteso id-o-nome|alias[|profile=..|environment=..|path=..|revision=..|hash=..]): {0}'; en = 'Invalid IdeAccount (expected id-or-name|alias[|profile=..|environment=..|path=..|revision=..|hash=..]): {0}' }
    'portable.ide.ambiguous' = @{ it = 'IDE non selezionabile o ambiguo: {0} ({1} corrispondenze)'; en = 'IDE not selectable or ambiguous: {0} ({1} matches)' }
    'portable.ideaccount.field' = @{ it = 'Campo IdeAccount non valido (atteso chiave=valore): {0}'; en = 'Invalid IdeAccount field (expected key=value): {0}' }
    'portable.ideaccount.repeated' = @{ it = 'Campo IdeAccount non valido o ripetuto: {0}'; en = 'Invalid or repeated IdeAccount field: {0}' }
    'portable.path.filetype.alt' = @{ it = 'Percorso alternativo ammesso solo per IDE di tipo file: {0}'; en = 'Alternative path allowed only for file-type IDEs: {0}' }
    'portable.observed.manual' = @{ it = 'Revisione e hash osservati si registrano solo per le superfici manuali: {0}'; en = 'Observed revision and hash are recorded only for manual surfaces: {0}' }
    'portable.observed.pair' = @{ it = 'revision (es. 1.0) e hash SHA-256 vanno indicati insieme: {0}'; en = 'revision (e.g. 1.0) and SHA-256 hash must be given together: {0}' }
    'portable.selection.empty' = @{ it = 'Nessun repository o IDE selezionato'; en = 'No repository or IDE selected' }
    'portable.block.present' = @{ it = 'Blocco gestito gia presente in {0}: rivederlo e usare -ApproveExistingBlocks'; en = 'Managed block already present in {0}: review it and use -ApproveExistingBlocks' }
    'portable.block.unapproved' = @{ it = 'Blocco gestito non approvato: {0}'; en = 'Managed block not approved: {0}' }
    'portable.environment.alternatives' = @{ it = '-RegisterEnvironment e -NoRegisterEnvironment sono alternativi'; en = '-RegisterEnvironment and -NoRegisterEnvironment are alternatives' }
    'portable.workstation.inactive' = @{ it = 'Postazione non attivata: usare secondbrain.ps1 -Setup'; en = 'Workstation not activated: use secondbrain.ps1 -Setup' }
    'portable.unbind.target' = @{ it = 'Indicare almeno un repository (percorso o identita) o una integrazione IDE (id o nome) da disassociare'; en = 'Give at least one repository (path or identity) or IDE integration (id or name) to unbind' }
    'portable.unbind.ambiguous' = @{ it = 'Repository o integrazione IDE non gestiti o ambigui: {0} ({1} repository, {2} IDE)'; en = 'Repository or IDE integration not managed or ambiguous: {0} ({1} repositories, {2} IDEs)' }
    'portable.output.single' = @{ it = 'Indicare un solo repository (percorso o identita) per -Output'; en = 'Give exactly one repository (path or identity) for -Output' }
    'portable.output.status' = @{ it = 'OutputStatus deve essere verified, exception-accepted o unverified'; en = 'OutputStatus must be verified, exception-accepted or unverified' }
    'portable.output.evidence' = @{ it = 'verified richiede -Evidence (file di prova sotto .runtime)'; en = 'verified requires -Evidence (evidence file under .runtime)' }
    'portable.output.verified.exception' = @{ it = 'verified non accetta -Exception'; en = 'verified does not accept -Exception' }
    'portable.evidence.missing' = @{ it = 'Prova non trovata: {0}'; en = 'Evidence not found: {0}' }
    'portable.output.reason' = @{ it = 'exception-accepted richiede un motivo non vuoto in -Exception'; en = 'exception-accepted requires a non-empty reason in -Exception' }
    'portable.output.exception.evidence' = @{ it = 'exception-accepted non accetta -Evidence'; en = 'exception-accepted does not accept -Evidence' }
    'portable.output.unverified' = @{ it = 'unverified non accetta -Evidence ne -Exception'; en = 'unverified accepts neither -Evidence nor -Exception' }
    'portable.repository.unmanaged' = @{ it = 'Repository non gestito o ambiguo: {0} ({1} corrispondenze)'; en = 'Repository not managed or ambiguous: {0} ({1} matches)' }
    'portable.repository.notonhost' = @{ it = 'Repository non gestito su questa postazione: {0}'; en = 'Repository not managed on this workstation: {0}' }
    'portable.observations.invalid' = @{ it = 'Osservazioni IDE non valide'; en = 'Invalid IDE observations' }
    'portable.identity.rebind' = @{ it = 'Identita/percorso cambiati; nuova riconciliazione richiesta'; en = 'Identity/path changed; new reconciliation required' }
    'portable.dossier.identity' = @{ it = 'Identita dossier divergente'; en = 'Dossier identity diverges' }
}

# SECONDBRAIN_HOME target: 'User' in production; tests redirect it to 'Process' to preserve the user's environment.
$script:SBEnvironmentScope='User'
# Thin pointer files for agents that do not read AGENTS.md (Claude Code, Gemini CLI); the managed block only imports AGENTS.md.
$script:SBRepositoryPointerFiles=@('CLAUDE.md','GEMINI.md')

function New-SBPortableConfiguration([string]$BrainRoot,[string]$WorkstationId=(Get-SBHostId)) {
    $root=Get-SBLocalRoot $BrainRoot $WorkstationId
    @{schemaVersion=1;mode='portable';workstationId=$WorkstationId;runtimeRoot=$root;backupRoot=(Join-Path $root 'backups');repositoryRoot=[IO.Path]::GetFullPath($BrainRoot);
      bindings=@();ides=@();startupBudget=50000}
}
function Get-SBPortableGlobal([string]$BrainRoot) {
    $revision=Get-SBApprovedDirectiveRevision $BrainRoot
    if(!$revision -or [version]$revision.version -lt [version]'1.0'){throw (New-SBError 'portable.directives.unapproved')}
    $common=Read-SBText (Join-Path $BrainRoot 'direttive/AGENTS.global_ide.md')
    $integration=Read-SBText (Join-Path $BrainRoot 'direttive/workstation.template.md')
    $text=$common.Trim()+"`n`n"+$integration.Trim()+"`n"
    if($text -match '(?i)(?<![A-Za-z0-9+.-])[A-Z]:[\\/]|(?<![\w/])/(?:Users|home)/|\{\{'){throw (New-SBError 'portable.directives.nonportable')}
    $text
}
function New-SBPortableRepositoryBody($Revision,[string]$BrainRoot,[string]$Dossier='') {
    $stamp=if($Revision){@('Direttive comuni applicate: revisione **'+$Revision.version+'** — '+$Revision.date+'.','<!-- secondbrain:source global='+$Revision.globalHash+' workstation='+$Revision.workstationHash+' -->')}else{@()}
    $fallback=@('SecondBrain: integrazione opzionale della conoscenza e delle direttive comuni.',
      'Risolvi SECONDBRAIN_HOME dallʼambiente utente della postazione; nessun percorso personale è conservato in questo repository.',
      'Se il clone privato non è disponibile, prosegui con le istruzioni tecniche locali e segnala lʼintegrazione non configurata; non creare memorie o stub sostitutivi.',
      'Dal clone SecondBrain usa scripts/prompts.ps1 -Context -RepositoryPath <checkout-corrente> per risolvere i percorsi del dossier e il suo index.md.',
      'Carica il contesto iniziale con scripts/knowledge.ps1 -Startup (o lo strumento MCP get_startup_context): indice, contesto sintetico, memoria essenziale e proiezione task pertinente; approfondimenti e storico soltanto quando servono.',
      'Memorie private, tracker interni, backup e output operativi risiedono in SecondBrain. Conserva qui codice, guide e asset pubblicabili.',
      'Le direttive non autorizzano commit, push, cancellazioni di artefatti o task applicativi impliciti.') -join "`n"
    $source=Join-Path $BrainRoot 'direttive/AGENTS.repo.managed.md'
    $body=if([IO.File]::Exists($source)){Read-SBText $source}else{$fallback}
    if($Dossier){
        $extra=Join-Path $Dossier 'AGENTS.managed.md'
        $relative=[IO.Path]::GetRelativePath($BrainRoot,$extra).Replace('\','/')
        $private=Read-SBJson (Resolve-SBParaPath $BrainRoot '.runtime/directive-approvals.json') @{files=@{}}
        $approved=$private.files
        if([IO.File]::Exists($extra) -or $approved.ContainsKey($relative)){
            Assert-SBPlainPath $extra
            if(!$approved.ContainsKey($relative) -or $approved[$relative] -cne (Get-SBFileHash $extra)){throw (New-SBError 'portable.directives.unapproved')}
            $text=(Read-SBText $extra).Trim()
            if($text){$body=$body.TrimEnd()+"`n`n"+$text}
        }
    }
    if($body -match '(?im)<!--\s*secondbrain:|(?<![A-Za-z0-9+.-])[A-Z]:[\\/]|(?<![\w/])/(?:Users|home)/|\{\{'){throw (New-SBError 'portable.directives.nonportable')}
    @($stamp)+@($body.Trim()) -join "`n"
}
# AGENTS.md is the single source. Claude Code reads CLAUDE.md and Gemini CLI GEMINI.md, not AGENTS.md: thin managed pointers import it.
function Set-SBRepositoryPointers([string]$Checkout,[hashtable]$State,[bool]$Check,[string]$BackupRoot) {
    foreach($pointer in $script:SBRepositoryPointerFiles){
        @{file=$pointer;result=(Set-SBManagedContent (Join-Path $Checkout $pointer) '@AGENTS.md' 'pointer' $State $Check $BackupRoot)}
    }
}
function Invoke-SBHostActivation {
    param([string]$BrainRoot,[string]$SelectionPath,[string]$SessionId,[switch]$Apply,[switch]$RegisterEnvironment)
    $selection=Read-SBJson (Assert-SBCentralDataPath $BrainRoot $SelectionPath) $null
    if(!$selection -or $selection.schemaVersion -ne 1 -or $selection.confirmed -ne $true -or !$selection.confirmation){throw (New-SBError 'portable.selection.unconfirmed')}
    $reportPath=Assert-SBCentralDataPath $BrainRoot $selection.reportPath
    if((Get-SBFileHash $reportPath) -ne $selection.reportSha256){throw (New-SBError 'portable.discovery.modified')}
    $report=Read-SBJson $reportPath $null
    if($report.hostId -ne (Get-SBHostId) -or !(Test-SBSamePath $report.brainRoot $BrainRoot)){throw (New-SBError 'portable.discovery.foreign')}
    $configPath=Get-SBHostConfigPath $BrainRoot
    $configurationHash=Get-SBFileHash $configPath
    $configuration=Read-SBJson $configPath (New-SBPortableConfiguration $BrainRoot)
    $configuration.runtimeRoot=Get-SBLocalRoot $BrainRoot $configuration.workstationId
    $configuration.backupRoot=Join-Path $configuration.runtimeRoot 'backups'
    $entities=@(Get-SBParaEntities $BrainRoot @());$operations=@();$newBindings=@();$plans=@()
    $forbiddenList=@(Get-SBForbiddenRepositories $BrainRoot $configuration)
    foreach($choice in $selection.repositories){
        $assets=@($report.repositories|Where-Object {$_.id -eq $choice.id -and $_.kind -ne 'bare'})
        if($assets.Count -ne 1){throw (New-SBError 'portable.repository.notinreport')};$asset=$assets[0]
        if(Test-SBForbiddenRepository $forbiddenList $asset.path ([string]$asset.identity)){throw (New-SBError 'portable.repository.forbidden' @($asset.identity, $asset.path))}
        $current=Get-SBCheckoutAsset $asset.path $configuration.bindings
        if($current.fingerprint -ne $asset.fingerprint -or $current.agentsHash -ne $asset.agentsHash){throw (New-SBError 'portable.checkout.changed' @($asset.path))}
        $identity=if($choice.ContainsKey('associateIdentity')){$choice.associateIdentity}elseif($asset.identity){$asset.identity}elseif($choice.ContainsKey('identity')){$choice.identity}else{'local:'+(Get-SBTextHash ('local|'+$report.hostId+'|'+$asset.commonGitDir.ToLowerInvariant())).Substring(0,32).ToLowerInvariant()}
        if(!$asset.identity -and !$choice.ContainsKey('associateIdentity') -and $identity -notmatch '^local:[a-f0-9]{32}$'){throw (New-SBError 'portable.repository.noremote')}
        if(!(Test-SBRepositoryIdentity $identity)){throw (New-SBError 'portable.identity.invalid')}
        if($asset.identity -and $choice.ContainsKey('identity') -and $choice.identity -cne $asset.identity){throw (New-SBError 'portable.identity.reconcile')}
        $existing=@($entities|Where-Object {$_.kind -eq 'area' -and $_.repository -ceq $identity})
        if($existing.Count -gt 1 -or ($existing.Count -and ($existing[0].archived -or $existing[0].status -ne 'active'))){throw (New-SBError 'portable.dossier.ambiguous')}
        $dossierRelative=if($existing.Count){$existing[0].path}else{'02-areas/products/'+($asset.name -replace '[^A-Za-z0-9_.-]','-')+'--'+(Get-SBTextHash $identity).Substring(0,8).ToLowerInvariant()}
        $dossier=Resolve-SBParaPath $BrainRoot $dossierRelative
        if($choice.ContainsKey('associateIdentity')){
            if(!$existing.Count -or !$choice.ContainsKey('aliasesReviewed') -or !$choice.aliasesReviewed){throw (New-SBError 'portable.alias.dossier')}
            if(@($entities|Where-Object {$_.repository -ceq $current.remoteIdentity -and $_.repository -cne $identity}).Count){throw (New-SBError 'portable.origin.bound')}
            if($current.remoteIdentity){
                $metadataPath=Join-Path $dossier 'repository.json';$metadata=Read-SBJson $metadataPath $null
                $aliases=if($metadata.ContainsKey('aliases')){@($metadata.aliases)}else{@()}
                $metadata.aliases=@($aliases+@($current.remoteIdentity)|Sort-Object -Unique)
                $operations+=@{path=$metadataPath;expected=(Get-SBFileHash $metadataPath);bytes=[Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $metadata))}
            }
        }
        $requiresImport=(!$existing.Count -and (Test-Path -LiteralPath (Join-Path $asset.path 'tracker.md')))
        if(!$existing.Count){
            $metadata=New-SBParaMetadata ('area-'+(Get-SBTextHash $identity).Substring(0,20).ToLowerInvariant()) 'area' $asset.name
            $repo=@{schemaVersion=1;identity=$identity}
            if(!$requiresImport){$repo.tracker=@{location='dossier';path='tracker.json';schemaVersion=1}}
            $seed=@{'para.json'=(ConvertTo-SBJson $metadata);'repository.json'=(ConvertTo-SBJson $repo);'brief.md'=("# "+$asset.name+"`n`nRepository selezionato per la gestione della conoscenza. Perimetro e stato nel contesto corrente.`n");
              'context.md'=("# Contesto`n`n## Stato corrente`n`nRepository selezionato; architettura e comandi da verificare dallʼagente del prodotto.`n`n## Vincoli`n`nNessun task applicativo eseguito dal bootstrap.`n`n## Problemi aperti`n`nQualificare fonti informative e configurazione degli output.`n`n## Prossimo passo`n`nEsaminare codice e documenti del repository.`n");
              'memory.md'="# Memoria essenziale`n`nNessuna decisione tecnica ancora qualificata.`n"}
            if(!$requiresImport){$seed['tracker.json']=ConvertTo-SBJson @{schemaVersion=1;repository=$identity;updatedAt=[DateTimeOffset]::UtcNow.ToString('o');tasks=@();history=@();extensions=@{}}}
            foreach($name in $seed.Keys){$path=Join-Path $dossier $name;if(Test-Path -LiteralPath $path){throw (New-SBError 'portable.destination.uncensused')};$operations+=@{path=$path;expected='absent';bytes=[Text.Encoding]::UTF8.GetBytes($seed[$name])}}
        }
        $managedHash='absent'
        $existingBlock=if($asset.agentsHash -ne 'absent'){Get-SBManagedContent ((Read-SBText (Join-Path $asset.path 'AGENTS.md')) -replace "`r`n","`n") 'repository'}else{$null}
        if($null -ne $existingBlock){
            if(!$choice.ContainsKey('approveExistingBlock') -or !$choice.approveExistingBlock){throw (New-SBError 'portable.block.review')}
            $managedHash=Get-SBTextHash $existingBlock
        }
        $newBindings+=@{path=$asset.path;identity=$identity;remoteIdentity=$current.remoteIdentity;fingerprint=$current.fingerprint;dossier=$dossierRelative;managedHash=$managedHash;status=$(if($requiresImport){'tracker-import-required'}else{'managed'});outputStatus='unverified'}
        $plans+=@{identity=$identity;path=$asset.path;dossier=$dossierRelative;trackerImportRequired=$requiresImport}
    }
    $selectedIDEs=@()
    foreach($choice in $selection.ides){
        $assets=@($report.ides|Where-Object id -eq $choice.id);if($assets.Count -ne 1){throw (New-SBError 'portable.ide.notinreport')}
        $ide=@{}+$assets[0]
        if($ide.mode -eq 'file' -and (Get-SBFileHash $ide.instructions) -ne $ide.sha256){throw (New-SBError 'portable.ide.changed')}
        foreach($key in @('accountAlias','profile','environment','accountObservation','observedRevision','observedHash')){if($choice.ContainsKey($key)){$ide[$key]=$choice[$key]}}
        # Alternative configuration root (e.g. another CLAUDE_CONFIG_DIR): file-based IDEs only; the entry has its own path, hash and fingerprint.
        if($choice.ContainsKey('instructionsPath') -and $choice.instructionsPath){
            if($ide.mode -ne 'file'){throw (New-SBError 'portable.path.filetype' @($ide.name))}
            $custom=Assert-SBIDEInstructionsPath $ide.name ([string]$choice.instructionsPath)
            if($custom -ine [IO.Path]::GetFullPath($ide.instructions)){
                $ide.instructions=$custom;$ide.sha256=Get-SBFileHash $custom;$ide.customInstructionsPath=$true
                $ide.environmentFingerprint=Get-SBTextHash (([string]$ide.environmentFingerprint)+'|'+$custom.ToLowerInvariant())
            }
        }
        $ide.assetId=$ide.id
        $customKey=if($ide.ContainsKey('customInstructionsPath') -and $ide.customInstructionsPath){'|'+([string]$ide.instructions).ToLowerInvariant()}else{''}
        $ide.id=$ide.assetId+'-'+(Get-SBTextHash ($ide.profile+'|'+$ide.accountAlias+'|'+$(if($ide.ContainsKey('environment')){$ide.environment}else{''})+$customKey)).Substring(0,12).ToLowerInvariant()
        if($ide.id -in @($selectedIDEs|ForEach-Object {$_.id})){throw (New-SBError 'portable.ide.duplicate' @($ide.name))}
        $ide.selected=$true;$selectedIDEs+=$ide
    }
    $retirePaths=if($selection.ContainsKey('retireCheckoutPaths')){@($selection.retireCheckoutPaths)}else{@()}
    foreach($retired in $retirePaths){if(!@($configuration.bindings|Where-Object path -eq $retired).Count){throw (New-SBError 'portable.checkout.unmanaged')}}
    $newPaths=@($newBindings|ForEach-Object {$_.path})
    $configuration.bindings=@(@($configuration.bindings|Where-Object {$_.path -notin $newPaths -and $_.path -notin $retirePaths})+$newBindings)
    $retireIDEIds=if($selection.ContainsKey('retireIDEIds')){@($selection.retireIDEIds)}else{@()}
    foreach($id in $retireIDEIds){if(!@($configuration.ides|Where-Object id -eq $id).Count){throw (New-SBError 'portable.ide.unmanaged')}}
    $newIdeIds=@($selectedIDEs|ForEach-Object {$_.id})
    $configuration.ides=@(@($configuration.ides|Where-Object {$_.id -notin $newIdeIds -and $_.id -notin $retireIDEIds})+$selectedIDEs)
    $configuration.selectionReceipt=@{sha256=(Get-SBFileHash $SelectionPath);confirmation=$selection.confirmation;reportSha256=$selection.reportSha256}
    $operations+=@{path=$configPath;expected=$configurationHash;bytes=[Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $configuration))}
    if($Apply){
        $lockConfig=if(Test-Path -LiteralPath $configPath){Read-SBConfiguration $configPath}else{$configuration.brainRoot=$BrainRoot;$configuration.configPath=$configPath;$configuration.allowedOwners=@();$configuration.coordinationRoot=Join-Path $BrainRoot '.runtime/access';$configuration}
        $lockConfig.brainRoot=$BrainRoot;$lockConfig.coordinationRoot=Join-Path $BrainRoot '.runtime/access'
        $lock=Enter-SBOperation $lockConfig $SessionId
        try{
            Invoke-SBParaTransaction $operations $configuration.backupRoot $BrainRoot|Out-Null
            if($RegisterEnvironment){[Environment]::SetEnvironmentVariable('SECONDBRAIN_HOME',[IO.Path]::GetFullPath($BrainRoot),$script:SBEnvironmentScope)}
            Update-SBParaIndex (Read-SBConfiguration $configPath)|Out-Null
        }finally{Exit-SBOperation $lock}
    }
    @{applied=[bool]$Apply;configuration=$configPath;repositories=$plans;retiredCheckouts=$retirePaths;retiredIdes=$retireIDEIds;ides=@($selectedIDEs|ForEach-Object name);ideBindings=@($selectedIDEs|ForEach-Object {@{id=$_.id;assetId=$_.assetId;profile=$_.profile;accountAlias=$_.accountAlias}});directivesDeployed=$false;activation='metadata-only; run Sync after approval of portable directives'}
}
function Get-SBSetupPaths([string]$BrainRoot) {
    $root=Get-SBLocalRoot $BrainRoot (Get-SBHostId)
    @{hostRoot=$root;report=(Join-Path $root 'discovery.json');selection=(Join-Path $root 'selection.json');setupResult=(Join-Path $root 'setup-result.json')}
}
function Test-SBGitRequirement([string]$VersionText,[int]$ExitCode=0) {
    $match=[regex]::Match($VersionText,'^git version (\d+)\.(\d+)\.(\d+)(?:[.\s-].*)?$')
    $ok=$ExitCode -eq 0 -and $match.Success
    if($ok){$ok=([version]($match.Groups[1].Value+'.'+$match.Groups[2].Value+'.'+$match.Groups[3].Value) -ge [version]'2.42.0')}
    @{name='git';ok=[bool]$ok;blocking=$true;detail=$(if($ok){$VersionText}else{(Get-SBMessage 'portable.git.required')+' ('+$VersionText+')'})}
}
function Test-SBSetupPreflight([string]$BrainRoot) {
    $checks=@()
    $checks+=@{name='powershell';ok=($PSVersionTable.PSVersion -ge [version]'7.5');blocking=$true;detail=$PSVersionTable.PSVersion.ToString()}
    $git=Get-Command git -CommandType Application -ErrorAction SilentlyContinue|Select-Object -First 1
    $gitExit=1
    $gitDetail=if($git){try{$value=(& $git.Source --version 2>&1|Out-String).Trim();$gitExit=$LASTEXITCODE;$value}catch{''}}else{''}
    $checks+=Test-SBGitRequirement $gitDetail $gitExit
    $writable=@{name='runtime-scrivibile';ok=$false;blocking=$true;detail='.runtime/hosts/'+(Get-SBHostId)}
    try{
        $hostRoot=Get-SBLocalRoot $BrainRoot (Get-SBHostId);[void][IO.Directory]::CreateDirectory($hostRoot)
        $probe=[IO.FileStream]::new((Join-Path $hostRoot ('.setup-probe-'+[guid]::NewGuid().ToString('N'))),[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None,1,[IO.FileOptions]::DeleteOnClose)
        $probe.Dispose();$writable.ok=$true
    }catch{$writable.detail=$_.Exception.Message}
    $checks+=$writable
    $shared=@{name='policy-condivisa';ok=$false;blocking=$true;detail='config/shared.json'}
    try{[void](Get-SBSharedPolicy $BrainRoot);$shared.ok=$true}catch{$shared.detail=$_.Exception.Message}
    $checks+=$shared
    $revision=Get-SBApprovedDirectiveRevision $BrainRoot
    $checks+=@{name='direttive-approvate';ok=[bool]$revision;blocking=$false;detail=$(if($revision){'revisione '+$revision.version}else{'direttive non approvate: la distribuzione (Sync) resta sospesa'})}
    $driveLetter=if($BrainRoot -match '^(?<d>[A-Za-z]):'){$Matches.d}else{$null}
    $mapped=if($driveLetter){Get-PSDrive -Name $driveLetter -PSProvider FileSystem -ErrorAction SilentlyContinue}else{$null}
    if($mapped -and $mapped.DisplayRoot){
        $checks+=@{name='drive-mappato';ok=$false;blocking=$false;detail="Cervello su drive mappato ${driveLetter}: ($($mapped.DisplayRoot)). Il mapping e per utente e sessione: altri utenti, servizi e agent non lo vedono. Preferire il percorso UNC."}
    }
    if($git){
        $top=try{Invoke-SBGit $BrainRoot @('rev-parse','--show-toplevel')}catch{@{code=-1;error=$_.Exception.Message}}
        if($top.code -ne 0 -and $top.error -match 'dubious ownership'){
            $checks+=@{name='git-proprietario';ok=$false;blocking=$false;detail="git rifiuta il cervello (proprietario diverso dall'utente corrente). Eseguire: git config --global --add safe.directory '$($BrainRoot -replace '\\','/')'"}
        }
    }
    if($BrainRoot.StartsWith('\\')){
        $policy=try{(Get-ExecutionPolicy).ToString()}catch{'sconosciuta'}
        $checks+=@{name='percorso-unc';ok=$false;blocking=$false;detail="Cervello su percorso di rete: se git segnala 'dubious ownership' aggiungere il percorso a safe.directory; ExecutionPolicy corrente $policy (RemoteSigned o Unblock-File per gli script)."}
    }
    $checks
}
function Read-SBSetupNumbers([string]$Prompt,[int]$Count) {
    if($Count -lt 1){return @()}
    $answer=([string](Read-Host $Prompt)).Trim()
    if(!$answer){return @()}
    if($answer -ieq 'tutti'){return @(1..$Count)}
    $indexes=@()
    foreach($part in @($answer -split '[,\s]+'|Where-Object {$_})){
        if($part -notmatch '^\d+$' -or [int]$part -lt 1 -or [int]$part -gt $Count){throw (New-SBError 'portable.choice.invalid' @($part))}
        $indexes+=[int]$part
    }
    @($indexes|Sort-Object -Unique)
}
function Assert-SBIDEInstructionsPath([string]$Name,[string]$Path) {
    # Alternative instruction path (another configuration root) for a file-based IDE: absolute, expected filename, under the user profile, outside credential folders.
    $expected=switch -Regex ($Name){'^Claude Code'{'CLAUDE.md'}'^Codex'{'AGENTS.md'}'^Antigravity'{'GEMINI.md'}default{''}}
    if(!$expected){throw (New-SBError 'portable.path.unsupported' @($Name))}
    if(!$Path -or ![IO.Path]::IsPathFullyQualified($Path)){throw (New-SBError 'portable.path.notabsolute')}
    $full=[IO.Path]::GetFullPath($Path)
    if([IO.Path]::GetFileName($full) -cne $expected){throw (New-SBError 'portable.path.filename' @($Name, $expected))}
    $profileRoot=[IO.Path]::GetFullPath($env:USERPROFILE).TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
    if(!$full.StartsWith($profileRoot,[StringComparison]::OrdinalIgnoreCase)){throw (New-SBError 'portable.path.outsideprofile')}
    if(@($full.Substring($profileRoot.Length) -split '[\\/]'|Where-Object {$_ -match '(?i)^(\.ssh|\.gnupg|\.aws|\.azure|credentials?|auth|tokens?|secrets?)$'}).Count){throw (New-SBError 'portable.path.credentials')}
    $full
}
function Invoke-SBSetup {
    param([string]$BrainRoot,[string[]]$Roots=@(),[int]$MaxDirectories=0,[string[]]$Select=@(),[switch]$All,[string[]]$Ides=@(),[switch]$AllIdes,[string[]]$IdeAccount=@(),
          [switch]$ApproveExistingBlocks,[switch]$Interactive,[switch]$Yes,[switch]$Apply,[switch]$RegisterEnvironment,[switch]$NoRegisterEnvironment,[switch]$AndSync=$true,[string]$SessionId,
          [string[]]$McpTargets=@(),[switch]$ApproveMcpReadTools)
    $brain=[IO.Path]::GetFullPath($BrainRoot);$paths=Get-SBSetupPaths $brain;$hostId=Get-SBHostId
    $McpTargets=@($McpTargets|ForEach-Object {$_ -split ','}|ForEach-Object {$_.Trim()}|Where-Object {$_}|Select-Object -Unique)
    foreach($target in $McpTargets){if($target -notin @('codex','claude','claude-code','cursor','vscode','antigravity','windsurf','all')){throw (New-SBError 'portable.mcp.targets')}}
    # With -File, a list arrives as a single comma-separated string.
    $Select=@($Select|ForEach-Object {$_ -split ','}|ForEach-Object {$_.Trim()}|Where-Object {$_})
    $Ides=@($Ides|ForEach-Object {$_ -split ','}|ForEach-Object {$_.Trim()}|Where-Object {$_})
    $result=[ordered]@{stage='preflight';hostId=$hostId;confirmed=$false;applied=$false}
    $preflight=@(Test-SBSetupPreflight $brain);$result.preflight=$preflight
    $failed=@($preflight|Where-Object {$_.blocking -and !$_.ok})
    if($failed.Count){throw (New-SBError 'portable.preflight.failed' @((($failed|ForEach-Object {$_.name+' ('+$_.detail+')'}) -join '; ')))}
    $needSelection=(!$Select.Count -and !$All -and !$Ides.Count -and !$AllIdes -and !@($IdeAccount|Where-Object {$_}).Count)
    if($needSelection -and !$Interactive -and [Console]::IsInputRedirected){throw (New-SBError 'portable.selection.missing')}
    $prompting=($Interactive -or $needSelection)
    if($prompting -and !$Roots.Count){
        $answer=([string](Read-Host 'Radici da analizzare separate da ; (invio = tutti i volumi fissi)')).Trim()
        if($answer){$Roots=@($answer -split ';'|ForEach-Object {$_.Trim()}|Where-Object {$_})}
    }
    $configPath=Get-SBHostConfigPath $brain;$bindings=@()
    if(Test-Path -LiteralPath $configPath){$existingConfig=Read-SBJson $configPath @{};if($existingConfig.ContainsKey('bindings')){$bindings=@($existingConfig.bindings)}}
    $result.stage='discovery'
    $report=Invoke-SBHostDiscovery -BrainRoot $brain -Roots $Roots -Bindings $bindings -ReportPath $paths.report -MaxDirectories $MaxDirectories
    $repos=@($report.repositories|Where-Object {$_.kind -in @('repository','worktree','submodule') -and $_.status -eq 'discovered'})
    $result.discovery=[ordered]@{complete=[bool]$report.complete;paused=[bool]$report.paused;repositories=$repos.Count;ides=@($report.ides).Count;issues=@($report.issues).Count;warnings=@($report.warnings).Count;report=$paths.report}
    if($report.paused){$result.stage='discovery-paused';return $result}
    $result.stage='proposal'
    $boundPaths=@($bindings|ForEach-Object {$_.path})
    $result.proposal=[ordered]@{
        repositories=@($repos|ForEach-Object {[ordered]@{id=$_.id;name=$_.name;path=$_.path;identity=$(if($_.identity){$_.identity}else{'local'});bound=($_.path -in $boundPaths)}})
        ides=@($report.ides|ForEach-Object {[ordered]@{id=$_.id;name=$_.name;mode=$_.mode}})}
    # Repository selection.
    $chosen=@()
    if($All){$chosen=$repos}
    elseif($Select.Count){
        foreach($token in $Select){
            $full=try{[IO.Path]::GetFullPath($token)}catch{''}
            $found=@($repos|Where-Object {$_.id -ceq $token -or $_.name -ieq $token -or ($full -and $_.path -ieq $full)})
            if($found.Count -ne 1){throw (New-SBError 'portable.repository.ambiguous' @($token, $found.Count))}
            $chosen+=$found[0]
        }
    }
    elseif($prompting -and $repos.Count){
        Write-Host (Get-SBMessage 'portable.prompt.repos');for($i=0;$i -lt $repos.Count;$i++){Write-Host ('  {0}) {1}  [{2}]  {3}' -f ($i+1),$repos[$i].name,$(if($repos[$i].identity){$repos[$i].identity}else{Get-SBMessage 'portable.prompt.noremote'}),$repos[$i].path)}
        foreach($n in @(Read-SBSetupNumbers 'Numeri da gestire separati da virgola, tutti, invio = nessuno' $repos.Count)){$chosen+=$repos[$n-1]}
    }
    $chosen=@($chosen|Sort-Object id -Unique)
    # IDE selection.
    $ideReport=@($report.ides);$chosenIdes=@()
    if($AllIdes){$chosenIdes=$ideReport}
    elseif($Ides.Count){
        foreach($token in $Ides){
            $found=@($ideReport|Where-Object {$_.id -ceq $token -or $_.name -ieq $token})
            if($found.Count -ne 1){throw (New-SBError 'portable.ide.ambiguous' @($token, $found.Count))}
            $chosenIdes+=$found[0]
        }
    }
    elseif($needSelection -and $ideReport.Count){
        Write-Host (Get-SBMessage 'portable.prompt.ides');for($i=0;$i -lt $ideReport.Count;$i++){Write-Host ('  {0}) {1}  [{2}]' -f ($i+1),$ideReport[$i].name,$ideReport[$i].mode)}
        foreach($n in @(Read-SBSetupNumbers 'Numeri da gestire separati da virgola, tutti, invio = nessuno' $ideReport.Count)){$chosenIdes+=$ideReport[$n-1]}
    }
    $chosenIdes=@($chosenIdes|Sort-Object id -Unique)
    # Multiple accounts or roots for the same IDE: each "id-or-name|alias[|key=value...]" entry becomes a separate integration (';' separates entries, '|' separates fields).
    # Keys: profile, environment, path (file-based IDEs only), revision and hash (observed account text, declared by the user).
    $accountEntries=@();$plainIdes=$chosenIdes
    foreach($spec in @($IdeAccount|ForEach-Object {$_ -split ';'}|ForEach-Object {$_.Trim()}|Where-Object {$_})){
        $parts=@($spec -split '\|'|ForEach-Object {$_.Trim()})
        if($parts.Count -lt 2 -or !$parts[0] -or !$parts[1] -or $parts[1].Contains('=')){throw (New-SBError 'portable.ideaccount.invalid' @($spec))}
        $found=@($ideReport|Where-Object {$_.id -ceq $parts[0] -or $_.name -ieq $parts[0]})
        if($found.Count -ne 1){throw (New-SBError 'portable.ide.ambiguous' @($parts[0], $found.Count))}
        $entry=@{id=$found[0].id;accountAlias=$parts[1]};$fields=@{}
        foreach($token in @($parts|Select-Object -Skip 2)){
            $eq=$token.IndexOf('=')
            if($eq -lt 1){throw (New-SBError 'portable.ideaccount.field' @($token))}
            $key=$token.Substring(0,$eq).ToLowerInvariant();$value=$token.Substring($eq+1).Trim()
            if($key -notin @('profile','environment','path','revision','hash') -or !$value -or $fields.ContainsKey($key)){throw (New-SBError 'portable.ideaccount.repeated' @($key))}
            $fields[$key]=$value
        }
        if($fields.ContainsKey('profile')){$entry.profile=$fields.profile}
        if($fields.ContainsKey('environment')){$entry.environment=$fields.environment}
        if($fields.ContainsKey('path')){
            if($found[0].mode -ne 'file'){throw (New-SBError 'portable.path.filetype.alt' @($found[0].name))}
            $entry.instructionsPath=Assert-SBIDEInstructionsPath $found[0].name $fields.path
        }
        if($fields.ContainsKey('revision') -or $fields.ContainsKey('hash')){
            if($found[0].mode -ne 'manual'){throw (New-SBError 'portable.observed.manual' @($found[0].name))}
            if(!$fields.ContainsKey('revision') -or !$fields.ContainsKey('hash') -or $fields.revision -notmatch '^\d+(\.\d+)+$' -or $fields.hash -notmatch '^[0-9A-Fa-f]{64}$'){throw (New-SBError 'portable.observed.pair' @($spec))}
            $entry.observedRevision=$fields.revision;$entry.observedHash=$fields.hash.ToUpperInvariant()
            $entry.accountObservation='Testo account dichiarato dall utente come osservato nelle impostazioni; il caricamento in una chat resta non verificato.'
        }
        $accountEntries+=$entry
        if($found[0].id -notin @($chosenIdes|ForEach-Object {$_.id})){$chosenIdes+=$found[0]}
    }
    if(!$chosen.Count -and !$chosenIdes.Count){throw (New-SBError 'portable.selection.empty')}
    # An IDE with a declared alias is one integration: do not add the unaliased entry for the same IDE selected by name.
    $accountIdeIds=@($accountEntries|ForEach-Object {$_.id})
    $plainIdes=@($plainIdes|Where-Object {$_.id -notin $accountIdeIds})
    # Existing managed blocks require explicit review, except a block identical to what Sync would write using the approved revision (same markers and source hashes).
    $approvals=@{}
    $approvedRevision=Get-SBApprovedDirectiveRevision $brain
    $directiveAreas=if($approvedRevision){@(Get-SBParaEntities $brain @()|Where-Object {$_.kind -eq 'area' -and !$_.archived})}else{@()}
    foreach($asset in $chosen){
        $existingBlock=if($asset.agentsHash -ne 'absent'){Get-SBManagedContent ((Read-SBText (Join-Path $asset.path 'AGENTS.md')) -replace "`r`n","`n") 'repository'}else{$null}
        if($null -eq $existingBlock){continue}
        $area=$directiveAreas|Where-Object {$_.repository -eq $asset.identity}|Select-Object -First 1
        $directiveDossier=if($area){Resolve-SBParaPath $brain $area.path}else{''}
        $approvedBlock=if($approvedRevision){"<!-- secondbrain:repository:begin -->`n"+(New-SBPortableRepositoryBody $approvedRevision $brain $directiveDossier).Trim()+"`n<!-- secondbrain:repository:end -->"}else{$null}
        if($approvedBlock -and $existingBlock -ceq $approvedBlock){$approvals[$asset.id]=$true;continue}
        if($ApproveExistingBlocks){$approvals[$asset.id]=$true}
        elseif($prompting){$approvals[$asset.id]=(([string](Read-Host ('AGENTS.md di '+$asset.name+' contiene gia un blocco gestito: approvare la revisione? (si/no)'))).Trim() -ieq 'si')}
        else{throw (New-SBError 'portable.block.present' @($asset.path))}
        if(!$approvals[$asset.id]){throw (New-SBError 'portable.block.unapproved' @($asset.path))}
    }
    $result.selected=[ordered]@{repositories=@($chosen|ForEach-Object {$_.name});ides=@($chosenIdes|ForEach-Object {$_.name})}
    $targetsByName=@{'Codex'='codex';'Claude Code'='claude-code';'Claude Desktop'='claude';'Cursor'='cursor';'VS Code'='vscode';'Antigravity'='antigravity';'Windsurf'='windsurf'}
    if(!$McpTargets.Count){
        $McpTargets=@($chosenIdes|ForEach-Object {$targetsByName[$_.name]}|Where-Object {$_}|Sort-Object -Unique)
    }
    if('all' -in $McpTargets){$McpTargets=@($targetsByName.Values|Sort-Object -Unique)}
    $mcpJobs=@(foreach($target in $McpTargets){
        $assetIds=@($chosenIdes|Where-Object {$targetsByName[$_.name] -eq $target}|ForEach-Object id)
        $profiles=@($accountEntries|Where-Object {$_.id -in $assetIds})
        if(!$profiles.Count -or @($plainIdes|Where-Object {$_.id -in $assetIds}).Count){@{target=$target;profile='current-user';configFile=$null;status='supported'}}
        foreach($profile in $profiles){
            $path=$null;$status='profile-unverified'
            if($profile.ContainsKey('instructionsPath') -and $target -in @('codex','claude-code')){
                $directory=Split-Path $profile.instructionsPath
                if($target -eq 'claude-code' -and (Split-Path $directory -Leaf) -eq '.claude'){$directory=Split-Path $directory}
                $path=Join-Path $directory $(if($target -eq 'codex'){'config.toml'}else{'.claude.json'})
                $status='supported'
            }
            if($profile.ContainsKey('environment') -and $profile.environment -notin @('local','windows')){$status='environment-unverified'}
            @{target=$target;profile=$(if($profile.ContainsKey('profile')){$profile.profile}else{$profile.accountAlias});configFile=$path;status=$status}
        }
    })
    # Actual user confirmation.
    $confirmed=$false;$how=''
    if($Yes){$confirmed=$true;$how='-Yes'}
    elseif($prompting){
        Write-Host (Get-SBMessage 'portable.selection.summary' @($chosen.Count,$chosenIdes.Count))
        if(([string](Read-Host 'Digita CONFERMO per registrare la scelta')).Trim() -ceq 'CONFERMO'){$confirmed=$true;$how='interattiva'}
    }
    $confirmation=if($confirmed){[Environment]::UserName+'@'+[Environment]::MachineName+' '+[DateTimeOffset]::UtcNow.ToString('o')+' ('+$how+')'}else{''}
    $selection=@{schemaVersion=1;confirmed=$confirmed;confirmation=$confirmation;reportPath=$paths.report;reportSha256=(Get-SBFileHash $paths.report)
        repositories=@($chosen|ForEach-Object {$entry=@{id=$_.id};if($approvals.ContainsKey($_.id)){$entry.approveExistingBlock=$true};$entry})
        ides=@(@($plainIdes|ForEach-Object {@{id=$_.id}})+$accountEntries)}
    $selectionPath=Assert-SBCentralDataPath $brain $paths.selection
    Write-SBFile $selectionPath ([Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $selection))) (Get-SBFileHash $selectionPath) (Join-Path $paths.hostRoot 'backups')|Out-Null
    $result.selection=$selectionPath;$result.confirmed=$confirmed
    if(!$confirmed){$result.note='Conferma mancante: selezione registrata come proposta (confirmed=false). Rilanciare con -Yes oppure -Interactive.';return $result}
    # Preview, then apply.
    $result.stage='preview'
    $preview=Invoke-SBHostActivation -BrainRoot $brain -SelectionPath $selectionPath -SessionId $SessionId
    if($McpTargets.Count){
        Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Mcp.psm1')
        $result.mcp=[ordered]@{preview=$true;approveReadTools=[bool]$ApproveMcpReadTools;targets=@(foreach($job in $mcpJobs){
            if($job.status -ne 'supported'){$job;continue}
            Get-SBMcpPairing -BrainRoot $brain -Target $job.target -ConfigFile $job.configFile -Scope user -ApproveAllTools:(!$ApproveMcpReadTools)
        })}
    }
    $doApply=[bool]$Apply
    if(!$doApply -and $prompting){$doApply=(([string](Read-Host 'Digita APPLICA per attivare ora (invio = solo anteprima)')).Trim() -ceq 'APPLICA')}
    if(!$doApply){$result.activation=$preview;return $result}
    if($RegisterEnvironment -and $NoRegisterEnvironment){throw (New-SBError 'portable.environment.alternatives')}
    $doRegister=!$NoRegisterEnvironment
    $applied=Invoke-SBHostActivation -BrainRoot $brain -SelectionPath $selectionPath -SessionId $SessionId -Apply -RegisterEnvironment:$doRegister
    if($McpTargets.Count){
        Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Mcp.psm1')
        $mcpLock=Enter-SBOperation (Read-SBConfiguration $configPath) $SessionId
        try{
            $mcpItems=@(foreach($job in $mcpJobs){
                if($job.status -ne 'supported'){@{Target=$job.target;Profile=$job.profile;Action=$job.status;PermissionAction='skipped';ClientSessionVerified=$false};continue}
                try{Set-SBMcpConfiguration -BrainRoot $brain -Target $job.target -ConfigFile $job.configFile -Scope user -ApproveReadTools:$ApproveMcpReadTools -ApproveAllTools:(!$ApproveMcpReadTools)}
                catch{if(Test-SBWriteDeniedError $_){throw};@{Target=$job.target;Action='failed';PermissionAction='skipped';ClientSessionVerified=$false;Error=$_.Exception.Message}}
            })
        }finally{Exit-SBOperation $mcpLock}
        $result.mcp=[ordered]@{preview=$false;items=$mcpItems;complete=(@($mcpItems|Where-Object {$_.Action -notin @('created','updated','applied','unchanged')}).Count -eq 0);
            permissionConfigurationComplete=(@($mcpItems|Where-Object {$_.PermissionAction -notin @('applied','unchanged')}).Count -eq 0);clientSessionVerified=$false}
    }
    $env:SECONDBRAIN_HOME=$brain
    $result.environment=if($doRegister){'registrata (variabile utente SECONDBRAIN_HOME)'}else{'non registrata: il percorso vale solo per questo processo'}
    $result.stage='applied';$result.applied=$true;$result.activation=$applied
    try{
        $config=Read-SBConfiguration $configPath
        $sync=Invoke-SBPortableSync -Config $config -Check:(!$AndSync) -SessionId $SessionId
        $result.check=[ordered]@{mode=$(if($AndSync){'sync'}else{'check'});aligned=[bool]$sync.aligned;filesAligned=[bool]$sync.filesAligned;repositories=$sync.repositories;issues=@($sync.issues|ForEach-Object {$_.kind}|Sort-Object -Unique)}
    }catch{if(Test-SBWriteDeniedError $_){throw};$result.check=[ordered]@{mode='check';error=$_.Exception.Message}}
    $result.next=if($AndSync){'Verificare caricamento IDE e account (manuale).'}else{'Distribuire le direttive con secondbrain.ps1 -Sync dopo aver riletto il -Check.'}
    $result.setupReport=$paths.setupResult
    $reportLock=Enter-SBOperation (Read-SBConfiguration $configPath) $SessionId
    try{
        [void](Write-SBFile $paths.setupResult ([Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $result))) (Get-SBFileHash $paths.setupResult) (Join-Path $paths.hostRoot 'backups'))
    }finally{Exit-SBOperation $reportLock}
    $result
}
function Get-SBIDEStaleObservation($Ide,[string]$GlobalText) {
    # Manual entry with observed text (observedHash) differing from approval: return observed and expected revisions; otherwise $null.
    if(!$Ide.ContainsKey('observedHash') -or !$Ide.observedHash){return $null}
    $text=$GlobalText.Trim()
    if([string]$Ide.observedHash -ceq (Get-SBTextHash $text)){return $null}
    $expected=if($text -match 'Revisione (\d+(?:\.\d+)+)'){$Matches[1]}else{'sconosciuta'}
    $observed=if($Ide.ContainsKey('observedRevision') -and $Ide.observedRevision){[string]$Ide.observedRevision}else{'sconosciuta'}
    @{observedRevision=$observed;expectedRevision=$expected}
}
function Get-SBIDEContextState($Ide,$State) {
    # Compare current context against the registered baseline (configuration, otherwise state.json): unrecorded, unchanged, changed or unknown.
    $name=[string]$Ide.name;$context=Get-SBIDEContext $name
    if(!$context){return @{status='unknown';current='';recorded=''}}
    # Entry with an alternative root: its current fingerprint includes its path, as at registration.
    if($Ide.ContainsKey('customInstructionsPath') -and $Ide.customInstructionsPath){$context.fingerprint=Get-SBTextHash ($context.fingerprint+'|'+([string]$Ide.instructions).ToLowerInvariant())}
    $recorded=if($Ide.ContainsKey('environmentFingerprint') -and $Ide.environmentFingerprint){[string]$Ide.environmentFingerprint}
        elseif($State -and $State.ContainsKey('ideContext') -and $State.ideContext.ContainsKey([string]$Ide.id)){[string]$State.ideContext[[string]$Ide.id]}else{''}
    $status=if(!$recorded){'unrecorded'}elseif($recorded -ceq $context.fingerprint){'unchanged'}else{'changed'}
    @{status=$status;current=$context.fingerprint;recorded=$recorded}
}
function Get-SBSetupStatus([string]$BrainRoot) {
    # Read-only: no locks, discovery or writes.
    $brain=[IO.Path]::GetFullPath($BrainRoot);$configPath=Get-SBHostConfigPath $brain
    if(!(Test-Path -LiteralPath $configPath -PathType Leaf)){throw (New-SBError 'portable.workstation.inactive')}
    $config=Read-SBJson $configPath @{}
    $value={param($item,[string]$key) if($item.ContainsKey($key)){$item[$key]}else{$null}}
    $bindings=if($config.ContainsKey('bindings')){@($config.bindings)}else{@()}
    $ides=if($config.ContainsKey('ides')){@($config.ides)}else{@()}
    $statePath=if($config.ContainsKey('runtimeRoot') -and $config.runtimeRoot){Join-Path $config.runtimeRoot 'state.json'}else{''}
    $state=if($statePath -and (Test-Path -LiteralPath $statePath -PathType Leaf)){Read-SBJson $statePath @{}}else{$null}
    [ordered]@{stage='status';hostId=(Get-SBHostId);configuration=$configPath
        bindings=@($bindings|ForEach-Object {[ordered]@{path=(& $value $_ 'path');identity=(& $value $_ 'identity');dossier=(& $value $_ 'dossier');status=(& $value $_ 'status');outputStatus=(& $value $_ 'outputStatus')}})
        ides=@($ides|ForEach-Object {[ordered]@{id=(& $value $_ 'id');name=(& $value $_ 'name');mode=(& $value $_ 'mode');selected=(& $value $_ 'selected');profile=(& $value $_ 'profile');accountAlias=(& $value $_ 'accountAlias')
            sha256=(& $value $_ 'sha256');installationEvidence=@((& $value $_ 'installationEvidence')|Where-Object {$_});environmentFingerprint=(& $value $_ 'environmentFingerprint');contextStatus=(Get-SBIDEContextState $_ $state).status}})
        selectionReceipt=$(if($config.ContainsKey('selectionReceipt')){$config.selectionReceipt}else{$null});latestSetup=(Read-SBJson (Get-SBSetupPaths $brain).setupResult $null)}
}
function Invoke-SBSetupUnbind {
    param([string]$BrainRoot,[string[]]$Targets=@(),[switch]$Interactive,[switch]$Yes,[switch]$Apply,[string]$SessionId)
    $brain=[IO.Path]::GetFullPath($BrainRoot);$paths=Get-SBSetupPaths $brain
    $Targets=@($Targets|ForEach-Object {$_ -split ','}|ForEach-Object {$_.Trim()}|Where-Object {$_})
    if(!$Targets.Count){throw (New-SBError 'portable.unbind.target')}
    $status=Get-SBSetupStatus $brain
    $retire=@();$retireIdes=@()
    foreach($token in $Targets){
        $full=try{[IO.Path]::GetFullPath($token)}catch{''}
        $found=@($status.bindings|Where-Object {($full -and $_.path -ieq $full) -or $_.identity -ieq $token})
        $ideFound=@($status.ides|Where-Object {$_.id -ieq $token})
        if(!$ideFound.Count){$ideFound=@($status.ides|Where-Object {$_.name -ieq $token})}
        if($found.Count+$ideFound.Count -ne 1){throw (New-SBError 'portable.unbind.ambiguous' @($token, $found.Count, $ideFound.Count))}
        if($found.Count){$retire+=[string]$found[0].path}else{$retireIdes+=[string]$ideFound[0].id}
    }
    $retire=@($retire|Select-Object -Unique);$retireIdes=@($retireIdes|Select-Object -Unique)
    $result=[ordered]@{stage='unbind-proposal';hostId=(Get-SBHostId);confirmed=$false;applied=$false;retireCheckoutPaths=$retire;retireIDEIds=$retireIdes}
    $reportPath=Assert-SBCentralDataPath $brain (Join-Path $paths.hostRoot 'unbind-report.json')
    $report=@{schemaVersion=1;kind='unbind';hostId=(Get-SBHostId);brainRoot=$brain;repositories=@();ides=@()}
    Write-SBFile $reportPath ([Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $report))) (Get-SBFileHash $reportPath) (Join-Path $paths.hostRoot 'backups')|Out-Null
    $prompting=[bool]$Interactive
    $confirmed=$false;$how=''
    if($Yes){$confirmed=$true;$how='-Yes'}
    elseif($prompting){
        Write-Host (Get-SBMessage 'portable.unbind.summary' @($retire.Count,$retireIdes.Count));$retire|ForEach-Object {Write-Host ('  '+$_)};$retireIdes|ForEach-Object {Write-Host ('  IDE '+$_)}
        if(([string](Read-Host 'Digita CONFERMO per registrare la scelta')).Trim() -ceq 'CONFERMO'){$confirmed=$true;$how='interattiva'}
    }
    $confirmation=if($confirmed){[Environment]::UserName+'@'+[Environment]::MachineName+' '+[DateTimeOffset]::UtcNow.ToString('o')+' ('+$how+')'}else{''}
    $selection=@{schemaVersion=1;confirmed=$confirmed;confirmation=$confirmation;reportPath=$reportPath;reportSha256=(Get-SBFileHash $reportPath);repositories=@();ides=@();retireCheckoutPaths=$retire;retireIDEIds=$retireIdes}
    $selectionPath=Assert-SBCentralDataPath $brain (Join-Path $paths.hostRoot 'unbind-selection.json')
    Write-SBFile $selectionPath ([Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $selection))) (Get-SBFileHash $selectionPath) (Join-Path $paths.hostRoot 'backups')|Out-Null
    $result.selection=$selectionPath;$result.confirmed=$confirmed
    if(!$confirmed){$result.note='Conferma mancante: selezione registrata come proposta (confirmed=false). Rilanciare con -Yes oppure -Interactive.';return $result}
    $result.stage='preview'
    $preview=Invoke-SBHostActivation -BrainRoot $brain -SelectionPath $selectionPath -SessionId $SessionId
    $doApply=[bool]$Apply
    if(!$doApply -and $prompting){$doApply=(([string](Read-Host 'Digita APPLICA per disassociare ora (invio = solo anteprima)')).Trim() -ceq 'APPLICA')}
    if(!$doApply){$result.activation=$preview;$result.note='Anteprima: nessuna modifica. Aggiungere -Apply per disassociare; i dossier non vengono eliminati.';return $result}
    $applied=Invoke-SBHostActivation -BrainRoot $brain -SelectionPath $selectionPath -SessionId $SessionId -Apply
    $result.stage='applied';$result.applied=$true;$result.activation=$applied
    $result
}
function Invoke-SBSetupOutput {
    # Register a binding's outputStatus/outputEvidence/outputException after product-agent testing: proposal, confirmation, preview, -Apply.
    param([string]$BrainRoot,[string]$Target,[string]$OutputStatus,[string]$Evidence,[string]$Exception,[switch]$Interactive,[switch]$Yes,[switch]$Apply,[string]$SessionId)
    $brain=[IO.Path]::GetFullPath($BrainRoot)
    if(!$Target -or $Target.Contains(',')){throw (New-SBError 'portable.output.single')}
    if($OutputStatus -cnotin @('verified','exception-accepted','unverified')){throw (New-SBError 'portable.output.status')}
    $Exception=([string]$Exception).Trim()
    $evidencePath=$null;$evidenceHash=$null
    switch($OutputStatus){
        'verified'{
            if(!$Evidence){throw (New-SBError 'portable.output.evidence')}
            if($Exception){throw (New-SBError 'portable.output.verified.exception')}
            $evidencePath=Assert-SBCentralDataPath $brain $Evidence
            if(!(Test-Path -LiteralPath $evidencePath -PathType Leaf)){throw (New-SBError 'portable.evidence.missing' @($evidencePath))}
            $evidenceHash=Get-SBFileHash $evidencePath
        }
        'exception-accepted'{
            if(!$Exception){throw (New-SBError 'portable.output.reason')}
            if($Evidence){throw (New-SBError 'portable.output.exception.evidence')}
        }
        'unverified'{if($Evidence -or $Exception){throw (New-SBError 'portable.output.unverified')}}
    }
    $status=Get-SBSetupStatus $brain
    $full=try{[IO.Path]::GetFullPath($Target)}catch{''}
    $found=@($status.bindings|Where-Object {($full -and $_.path -ieq $full) -or $_.identity -ieq $Target})
    if($found.Count -ne 1){throw (New-SBError 'portable.repository.unmanaged' @($Target, $found.Count))}
    $bindingPath=[string]$found[0].path
    $configPath=Get-SBHostConfigPath $brain
    $configurationHash=Get-SBFileHash $configPath
    $configuration=Read-SBJson $configPath @{}
    $binding=@($configuration.bindings|Where-Object {$_.path -ieq $bindingPath})[0]
    $previous=if($binding.ContainsKey('outputStatus')){[string]$binding.outputStatus}else{'unverified'}
    foreach($key in @('outputEvidence','outputEvidenceSha256','outputException')){if($binding.ContainsKey($key)){$binding.Remove($key)}}
    $binding.outputStatus=$OutputStatus
    if($OutputStatus -eq 'verified'){$binding.outputEvidence=$evidencePath;$binding.outputEvidenceSha256=$evidenceHash}
    if($OutputStatus -eq 'exception-accepted'){$binding.outputException=$Exception}
    $result=[ordered]@{stage='output-proposal';hostId=(Get-SBHostId);confirmed=$false;applied=$false;repository=[string]$found[0].identity;checkout=$bindingPath;previousOutputStatus=$previous;outputStatus=$OutputStatus}
    if($evidencePath){$result.outputEvidenceSha256=$evidenceHash}
    $confirmed=$false;$how=''
    if($Yes){$confirmed=$true;$how='-Yes'}
    elseif($Interactive){
        Write-Host (Get-SBMessage 'portable.output.summary' @($found[0].identity,$previous,$OutputStatus))
        if(([string](Read-Host 'Digita CONFERMO per registrare lo stato output')).Trim() -ceq 'CONFERMO'){$confirmed=$true;$how='interattiva'}
    }
    $result.confirmed=$confirmed
    if(!$confirmed){$result.note='Conferma mancante: nessuna modifica. Rilanciare con -Yes oppure -Interactive.';return $result}
    $doApply=[bool]$Apply
    if(!$doApply -and $Interactive){$doApply=(([string](Read-Host 'Digita APPLICA per registrare ora (invio = solo anteprima)')).Trim() -ceq 'APPLICA')}
    $result.stage='preview'
    if(!$doApply){$result.note='Anteprima: nessuna modifica. Aggiungere -Apply per registrare lo stato output; la prova resta sotto .runtime.';return $result}
    $lockConfig=Read-SBConfiguration $configPath
    $lock=Enter-SBOperation $lockConfig $SessionId
    try{
        Invoke-SBParaTransaction @(@{path=$configPath;expected=$configurationHash;bytes=[Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $configuration))}) $lockConfig.backupRoot $brain|Out-Null
    }finally{Exit-SBOperation $lock}
    $result.stage='applied';$result.applied=$true;$result.confirmation=[Environment]::UserName+'@'+[Environment]::MachineName+' '+[DateTimeOffset]::UtcNow.ToString('o')+' ('+$how+')'
    $result
}
# Greenfield guard: changes relative to HEAD for versions, changelog, migrations, compatibility aliases and deprecations. Already committed changes are not reported.
function Get-SBGreenfieldViolations($Config,$Binding,[string]$Dossier) {
    $found=@()
    $version=Invoke-SBGit $Binding.path @('status','--porcelain=v1','--','VERSION')
    if($version.code -eq 0 -and $version.output){$found+='VERSION modificato rispetto a HEAD'}
    $changelog=Invoke-SBGit $Binding.path @('status','--porcelain=v1','--','CHANGELOG.md')
    if($changelog.code -eq 0 -and $changelog.output){
        if($changelog.output.StartsWith('??')){$found+='CHANGELOG.md nuovo'}
        else{
            $stat=Invoke-SBGit $Binding.path @('diff','HEAD','--numstat','--','CHANGELOG.md')
            if($stat.code -eq 0 -and $stat.output -match '^(\d+)\s' -and [int]$Matches[1] -gt 0){$found+='CHANGELOG.md con nuove voci rispetto a HEAD'}
        }
    }
    $record=Read-SBJson (Join-Path $Dossier 'repository.json') @{}
    if($record.ContainsKey('aliases') -and @($record.aliases).Count){$found+='alias di compatibilita in repository.json'}
    foreach($registry in @(Get-SBTrackerImportPaths $Config ([string]$Binding.identity))){if(Test-Path -LiteralPath $registry -PathType Leaf){$found+='importazione o migrazione di schema del tracker registrata';break}}
    if(Test-SBSamePath $Binding.path $Config.brainRoot){
        $catalog=Read-SBJson (Join-Path $Config.brainRoot 'direttive/prompts/catalog.json') @{}
        if($catalog.ContainsKey('deprecations')){$found+='deprecations nel catalogo prompt'}
    }
    $found
}
function Invoke-SBPortableSync {
    param($Config,[switch]$Check,[string]$SessionId,[string]$ObservationPath,[string]$Repository)
    $lock=Enter-SBOperation $Config $SessionId -ReadOnly:$Check
    try{
        # -Repository limits checks to that repository: no other repositories' data or results; the result declares coverage.
        $scoped=@($Config.bindings)
        if($Repository){
            $scoped=@($Config.bindings|Where-Object {$_.identity -ceq $Repository})
            if($scoped.Count -ne 1){throw (New-SBError 'portable.repository.notonhost' @($Repository))}
        }
        $compactionAdvice=@()
        $closureWarnings=@()
        $issues=@();$changes=@();$statePath=Join-Path $Config.runtimeRoot 'state.json';$state=Read-SBJson $statePath @{schemaVersion=1;managed=@{};dossierMap=@{}}
        $entities=@(Get-SBParaEntities $Config.brainRoot @())
        $observations=@()
        if($ObservationPath){$receipt=Read-SBJson (Assert-SBCentralDataPath $Config.brainRoot $ObservationPath) $null;if(!$receipt -or $receipt.schemaVersion -ne 1){throw (New-SBError 'portable.observations.invalid')};$observations=@($receipt.observations)}
        $global=$null
        try{$global=Get-SBPortableGlobal $Config.brainRoot}catch{$issues+=@{kind='unapproved-portable-directives';reason=$_.Exception.Message}}
        $forbiddenList=@(Get-SBForbiddenRepositories $Config.brainRoot $Config)
        foreach($binding in $scoped){
            try{
                if(Test-SBForbiddenRepository $forbiddenList $binding.path ([string]$binding.identity)){
                    $issues+=@{kind='forbidden-repository-in-bindings';repository=$binding.identity;reason=(Get-SBMessage 'portable.issue.forbidden')}
                    continue
                }
                if($binding.status -ne 'managed'){$issues+=@{kind='tracker-import-required';repository=$binding.identity};continue}
                $current=Get-SBCheckoutAsset $binding.path $Config.bindings
                if($current.fingerprint -ne $binding.fingerprint -or $current.remoteIdentity -cne $binding.remoteIdentity){throw (New-SBError 'portable.identity.rebind')}
                $dir=Resolve-SBParaPath $Config.brainRoot $binding.dossier
                $record=Read-SBJson (Join-Path $dir 'repository.json') $null
                if(!$record -or $record.identity -cne $binding.identity){throw (New-SBError 'portable.dossier.identity')}
                if((Get-SBRepositoryLifecycle $dir) -eq 'greenfield'){foreach($reason in @(Get-SBGreenfieldViolations $Config $binding $dir)){$issues+=@{kind='greenfield-violation';repository=$binding.identity;reason=$reason}}}
                $outputVerified=$false
                if($binding.ContainsKey('outputStatus') -and $binding.outputStatus -eq 'exception-accepted' -and $binding.ContainsKey('outputException') -and $binding.outputException){$outputVerified=$true}
                if($binding.ContainsKey('outputStatus') -and $binding.outputStatus -eq 'verified' -and $binding.ContainsKey('outputEvidence') -and $binding.ContainsKey('outputEvidenceSha256')){
                    $proof=Assert-SBCentralDataPath $Config.brainRoot $binding.outputEvidence
                    $outputVerified=(Get-SBFileHash $proof) -eq $binding.outputEvidenceSha256
                }
                if(!$outputVerified){$issues+=@{kind='output-location-unverified';repository=$binding.identity;reason=(Get-SBMessage 'portable.issue.output')}}
                $toc=Get-SBDossierTOC $dir;$path=Join-Path $dir 'index.md'
                if((Get-SBFileHash $path) -ne (Get-SBTextHash $toc)){
                    if($Check){$issues+=@{kind='toc-pending';repository=$binding.identity}}
                    else{Write-SBFile $path ([Text.Encoding]::UTF8.GetBytes($toc)) (Get-SBFileHash $path) $Config.backupRoot|Out-Null;$changes+='toc:'+ $binding.identity}
                }
                $historyIndex=Get-SBDossierHistoryIndex $dir;$historyPath=Join-Path $dir 'history/index.md'
                if((Get-SBFileHash $historyPath) -ne (Get-SBTextHash $historyIndex)){
                    if($Check){$issues+=@{kind='history-index-pending';repository=$binding.identity}}
                    else{Write-SBFile $historyPath ([Text.Encoding]::UTF8.GetBytes($historyIndex)) (Get-SBFileHash $historyPath) $Config.backupRoot|Out-Null}
                }
                # Agent view of memory.md (derived file): generated by Sync and verified by Check, like the index.
                $memorySource=Join-Path $dir 'memory.md'
                if([IO.File]::Exists($memorySource)){
                    $agentView=ConvertTo-SBAgentMemoryView (Read-SBText $memorySource);$viewFile=Join-Path $dir 'memory.agent.md'
                    if((Get-SBFileHash $viewFile) -ne (Get-SBTextHash $agentView)){
                        if($Check){$issues+=@{kind='agent-view-pending';repository=$binding.identity}}
                        else{Write-SBFile $viewFile ([Text.Encoding]::UTF8.GetBytes($agentView)) (Get-SBFileHash $viewFile) $Config.backupRoot|Out-Null;$changes+='agent-view:'+$binding.identity}
                    }
                }
                if($Check){
                    $closureTracker=Resolve-SBTracker -BrainRoot $Config.brainRoot -Identity $binding.identity -DossierPath $dir -CheckoutPath $binding.path -AllowedOwners @() -Entities $entities
                    if($closureTracker.source -eq 'dossier'){
                        foreach($pending in @(Get-SBClosureMemoryPending $dir $closureTracker.data)){
                            $closureWarnings+=@{kind='closure-memory-pending';repository=$binding.identity;taskId=$pending.taskId;closedAt=$pending.closedAt;memoryUpdatedAt=$pending.memoryUpdatedAt;reason=(Get-SBMessage 'portable.issue.closure')}
                        }
                    }
                }
                # Match the CLI/MCP initial projection.
                $budget = Get-SBSlimStartupBudget
                $startup=Get-SBStartupContext -BrainRoot $Config.brainRoot -Dossier $dir -CheckoutPath $binding.path -Entities $entities -Budget $budget -Profile Slim
                if(!$startup.withinBudget){$issues+=@{kind='compaction-required';repository=$binding.identity;characters=$startup.characters;budget=$budget}}
                elseif($startup.compacted){$compactionAdvice+=@{kind='startup-compacted';repository=$binding.identity;characters=$startup.characters;uncompactedCharacters=$startup.uncompactedCharacters;budget=$budget}}
                else{
                    # Soft threshold (near the limit or many turns since compaction): warning only; does not make the check unaligned.
                    $advice=Get-SBCompactionAdvice $startup $Config.brainRoot $dir
                    if($advice.level -eq 'soft'){$compactionAdvice+=@{kind='compaction-advised';repository=$binding.identity;characters=$advice.characters;budget=$advice.budget;percent=$advice.percent;turnsSinceCompaction=$advice.turnsSinceCompaction;reason=(Get-SBMessage 'portable.issue.compaction')}}
                }
                if($global){
                    $agents=Join-Path $binding.path 'AGENTS.md';$key=[IO.Path]::GetFullPath($agents)+'|repository'
                    if(!$state.managed.ContainsKey($key) -and $binding.managedHash -ne 'absent'){$state.managed[$key]=$binding.managedHash}
                    $result=Set-SBManagedContent $agents (New-SBPortableRepositoryBody (Get-SBApprovedDirectiveRevision $Config.brainRoot) $Config.brainRoot $dir) 'repository' $state.managed $Check $Config.backupRoot -AfterTitle
                    if($result -eq 'conflict'){$issues+=@{kind='directive-conflict';repository=$binding.identity}}
                    elseif($result -eq 'pending'){$issues+=@{kind='directive-pending';repository=$binding.identity}}
                    elseif($result -eq 'updated'){$changes+='directive:'+ $binding.identity}
                    foreach($pointer in @(Set-SBRepositoryPointers $binding.path $state.managed $Check $Config.backupRoot)){
                        if($pointer.result -eq 'conflict'){$issues+=@{kind='pointer-conflict';repository=$binding.identity;file=$pointer.file}}
                        elseif($pointer.result -eq 'pending'){$issues+=@{kind='pointer-pending';repository=$binding.identity;file=$pointer.file}}
                        elseif($pointer.result -eq 'updated'){$changes+='pointer:'+$pointer.file+':'+$binding.identity}
                    }
                }
            }catch{if(!$Check -and (Test-SBWriteDeniedError $_)){throw};$issues+=@{kind='repository-unverified';repository=$binding.identity;reason=$_.Exception.Message}}
        }
        if(!$Repository){foreach($ide in $Config.ides){
            $writeScope=Get-SBIDEWriteScope $ide
            if($writeScope.status -ne 'verified'){$issues+=@{kind=('ide-write-scope-'+$writeScope.status);ide=$ide.name;writeScope=$writeScope}}
        }}
        if($global -and !$Repository){
            $globalPath=Join-Path $Config.runtimeRoot 'istruzioni-globali.md'
            if((Get-SBFileHash $globalPath) -ne (Get-SBTextHash $global)){
                if($Check){$issues+=@{kind='global-text-pending'}}else{Write-SBFile $globalPath ([Text.Encoding]::UTF8.GetBytes($global)) (Get-SBFileHash $globalPath) $Config.backupRoot|Out-Null}
            }
            if(!$state.ContainsKey('ideContext')){$state.ideContext=@{}}
            foreach($ide in $Config.ides){
                # Profile, configuration root or configuration folders changed since activation: instructions may no longer be loaded.
                $contextState=Get-SBIDEContextState $ide $state
                if($contextState.status -eq 'unrecorded' -and !$Check -and $contextState.current){$state.ideContext[[string]$ide.id]=$contextState.current}
                elseif($contextState.status -eq 'changed'){$issues+=@{kind='ide-context-changed';ide=$ide.name;reason=(Get-SBMessage 'portable.issue.idecontext')}}
                $observed=Test-SBIDEObservation $ide (Get-SBTextHash $global.Trim()) $observations $Config.brainRoot $Config.workstationId
                if($ide.mode -eq 'manual'){
                    $alias=if($ide.ContainsKey('accountAlias')){[string]$ide.accountAlias}else{''}
                    if(!$observed){$issues+=@{kind='account-unverified';ide=$ide.name;id=$ide.id;accountAlias=$alias}}
                    # Observed account text differs from approval: realignment needed (new revision or stale account).
                    $stale=Get-SBIDEStaleObservation $ide $global
                    if($stale){$issues+=@{kind='ide-directive-stale';ide=$ide.name;id=$ide.id;accountAlias=$alias;observedRevision=$stale.observedRevision;expectedRevision=$stale.expectedRevision}}
                    continue
                }
                $key=[IO.Path]::GetFullPath($ide.instructions)+'|global'
                if(!$state.managed.ContainsKey($key) -and (Get-SBFileHash $ide.instructions) -ne 'absent'){
                    if((Get-SBFileHash $ide.instructions) -ne $ide.sha256){$issues+=@{kind='ide-conflict';ide=$ide.name};continue}
                    $block=Get-SBManagedContent ((Read-SBText $ide.instructions) -replace "`r`n","`n") 'global'
                    if($null -eq $block){$issues+=@{kind='ide-adoption-required';ide=$ide.name};continue};$state.managed[$key]=Get-SBTextHash $block
                }
                $result=Set-SBManagedContent $ide.instructions $global.Trim() 'global' $state.managed $Check $Config.backupRoot
                if($result -in @('conflict','pending')){$issues+=@{kind=('ide-'+$result);ide=$ide.name}}
                # File deployment never certifies the identity of an account or loaded session.
                if(!$observed){$issues+=@{kind='ide-loading-unverified';ide=$ide.name}}
            }
        }
        if(!$Check -and $Repository){
            Write-SBFile $statePath ([Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $state))) (Get-SBFileHash $statePath) $Config.backupRoot|Out-Null
        }
        if(!$Check -and !$Repository){
            $inventory=@{schemaVersion=1;workstationId=$Config.workstationId;repositories=$Config.bindings;ides=$Config.ides;coverage='approved-associations; use Check for current verification'}
            $inventoryPath=Join-Path $Config.runtimeRoot 'inventory.json'
            Write-SBFile $inventoryPath ([Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $inventory))) (Get-SBFileHash $inventoryPath) $Config.backupRoot|Out-Null
            Write-SBFile $statePath ([Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $state))) (Get-SBFileHash $statePath) $Config.backupRoot|Out-Null
            $map=@{schemaVersion=1;workstationId=$Config.workstationId;ides=@($Config.ides|ForEach-Object {$entry=@{};foreach($key in $_.Keys){$entry[$key]=$_[$key]};$entry.writeScope=Get-SBIDEWriteScope $_;$entry})}
            $mapPath=Join-Path $Config.runtimeRoot 'ide-map.json';Write-SBFile $mapPath ([Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $map))) (Get-SBFileHash $mapPath) $Config.backupRoot|Out-Null
            Update-SBParaIndex $Config|Out-Null
        }
        $entities=@(Get-SBParaEntities $Config.brainRoot @())
        if(!$Repository){
        foreach($issue in @(Get-SBCuratedReferenceIssues $Config.brainRoot $entities)){$issues+=@{kind='curated-reference';detail=$issue}}
        foreach($issue in @(Get-SBTrackerAuthorityIssues $Config.brainRoot $entities)){$issues+=@{kind='tracker-authority';detail=$issue}}
        foreach($issue in @(Get-SBTrackerImportIssues $Config)){$issues+=@{kind='tracker-import';detail=$issue}}
        if(@($entities|Where-Object id -eq 'resource-authoritative-sources').Count){
            foreach($issue in @(Get-SBSourceChecks (Read-SBSourceRegistry $Config.brainRoot) $Config -IncludeDossiers)){$issues+=@{kind='authoritative-source';detail=$issue}}
        }
        foreach($drift in @(Get-SBWorkflowDrift $Config.brainRoot)){$issues+=@{kind='prompt-index-drift';path=$drift.path}}
        }
        $fileIssueKinds=@('directive-pending','directive-conflict','pointer-pending','pointer-conflict','global-text-pending','ide-pending','ide-conflict','ide-adoption-required','toc-pending','history-index-pending','agent-view-pending','prompt-index-drift','unapproved-portable-directives','repository-unverified')
        $filesAligned=!@($issues|Where-Object {$_.kind -in $fileIssueKinds}).Count
        $liveLoadingVerified=!@($issues|Where-Object {$_.kind -in @('ide-loading-unverified','account-unverified','ide-context-changed','ide-directive-stale')}).Count
        # Reads do not block writers: an active writer or pending transaction makes the snapshot potentially intermediate.
        $warnings=@($compactionAdvice)+@($closureWarnings)
        if($lock.concurrentWriter){$warnings+=@{kind='concurrent-writer';reason=(Get-SBMessage 'portable.issue.writer')}}
        $pendingTransaction=if($lock.pendingTransaction){$lock.pendingTransaction}elseif($Config.ContainsKey('pendingTransaction')){$Config.pendingTransaction}else{$null}
        if($pendingTransaction){$warnings+=@{kind='pending-transaction';reason=(Format-SBPendingTransaction $pendingTransaction)}}
        @{schemaVersion=1;workstationId=$Config.workstationId;repositories=$Config.bindings.Count;changes=$changes;issues=$issues;warnings=$warnings;aligned=(!$issues.Count);filesAligned=$filesAligned;liveLoadingVerified=$liveLoadingVerified;writesApplied=(!$Check);inventoryIsLocal=$true;scope=$(if($Repository){@{repository=$Repository;coverage='repository-only';notCovered=@('global-instructions','ides','curated-references','tracker-authority','tracker-imports','authoritative-sources','prompt-index','inventory','para-index')}}else{@{coverage='workstation'}})}
    }finally{Exit-SBOperation $lock}
}
Export-ModuleMember -Function @(
    'New-SBPortableConfiguration',
    'Get-SBPortableGlobal',
    'Set-SBRepositoryPointers',
    'Invoke-SBHostActivation',
    'Get-SBSetupPaths',
    'Assert-SBIDEInstructionsPath',
    'Invoke-SBSetup',
    'Get-SBIDEContextState',
    'Get-SBSetupStatus',
    'Invoke-SBSetupUnbind',
    'Invoke-SBSetupOutput',
    'Invoke-SBPortableSync'
)
