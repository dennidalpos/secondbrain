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
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.McpConfig.psm1')
$script:SBPortableMcpTargets=@{'Codex'='codex';'Claude Code'='claude-code';'Claude Desktop'='claude';'Cursor'='cursor';'VS Code'='vscode';'Antigravity'='antigravity';'Windsurf'='windsurf'}
Add-SBMessages @{
    'portable.git.required' = @{ it = 'Serve Git 2.42 o successivo, eseguibile e con versione riconoscibile: installarlo o aggiornarlo e verificare con git --version'; en = 'Git 2.42 or later is required, executable and with a recognizable version: install or update it and check with git --version' }
    'portable.mcp.targets' = @{ it = 'Selezionare target MCP validi per approvare i tool di conoscenza: scegliere almeno un IDE con configurazione MCP'; en = 'Select valid MCP targets to approve knowledge tools: choose at least one IDE with an MCP configuration' }
    'portable.mcp.preview' = @{it='Anteprima del pairing MCP a livello utente';en='User-level MCP pairing preview'}
    'portable.setup.apply' = @{it='Digita APPLICA per attivare ora (invio = solo anteprima)';en='Type APPLICA to activate now (Enter keeps the preview)'}
    'portable.setup.preview' = @{it='Anteprima di attivazione della postazione';en='Workstation activation preview'}
    'portable.setup.dossier.conflict' = @{it='Dossier personale e team presenti. Confrontarli con il checkout prima di concordare il consolidamento.';en='Personal and team dossiers both exist. Compare them with the checkout before agreeing on consolidation.'}
    'portable.setup.team.state' = @{ it = 'Il Setup team richiede SECONDBRAIN_STATE_ROOT su un disco fisso locale, fuori dalla radice condivisa: impostarla e ripetere il Setup'; en = 'Team setup requires SECONDBRAIN_STATE_ROOT on a fixed local drive outside the shared root: set it and repeat the setup' }
    'portable.issue.mcpconsent' = @{ it = 'Manca una prova valida del popup di consenso per uno strumento MCP in questa sessione: registrare l''osservazione con ide-observation.ps1'; en = 'A valid observation of the consent prompt for an MCP tool in this session is missing: record it with ide-observation.ps1' }
    'portable.unbind.summary' = @{ it = 'Disassociazione di {0} repository e {1} integrazioni IDE: dossier e file IDE restano'; en = 'Unbinding {0} repositories and {1} IDE integrations: dossiers and IDE files are kept' }
    'portable.issue.forbidden' = @{ it = 'Repository vietato presente nei binding attivi'; en = 'Forbidden repository present in the active bindings' }
    'portable.issue.compaction' = @{ it = 'Proporre SYS05 (sb compatta): nulla viene compattato senza conferma'; en = 'Propose SYS05 (sb compact): nothing is compacted without confirmation' }
    'portable.issue.decisions' = @{it='Decisioni superate o scadute conservate nello storico; la vista agente le esclude. Verificare i rimandi durante SYS05.';en='Superseded or expired decisions remain in history and are excluded from the agent view. Review their references during SYS05.'}
    'portable.issue.closure' = @{ it = 'Un task e stato chiuso dopo l ultimo aggiornamento di memory.md: aggiornare memoria e contesto con MEM03'; en = 'A task was closed after the last memory.md update: update memory and context with MEM03' }
    'portable.issue.idecontext' = @{ it = 'Contesto IDE diverso da quello registrato: riverificare login e caricamento, quindi riattivare con Setup e ritirare il vecchio accesso con Unbind'; en = 'IDE context differs from the recorded one: re-verify login and loading, then re-activate with Setup and withdraw the old access with Unbind' }
    'portable.issue.writer' = @{ it = 'Un writer e attivo: l esito puo riflettere uno stato intermedio, ripetere il controllo'; en = 'A writer is active: the result may reflect an intermediate state, repeat the check' }
    'portable.prompt.repos' = @{ it = 'Repository trovati:'; en = 'Repositories found:' }
    'portable.prompt.noremote' = @{ it = 'senza remoto: identita locale'; en = 'no remote: local identity' }
    'portable.prompt.ides' = @{ it = 'IDE trovati:'; en = 'IDEs found:' }
    'portable.directives.unapproved' = @{ it = 'Direttive non ancora approvate: distribuzione sospesa; approvare la revisione con scripts/approve-revision.ps1'; en = 'Directives not yet approved: distribution suspended; approve the revision with scripts/approve-revision.ps1' }
    'portable.directives.nonportable' = @{ it = 'Direttive globali non portabili: togliere percorsi e dati personali dal testo e riprovare'; en = 'Global directives are not portable: remove personal paths and data from the text and retry' }
    'portable.selection.unconfirmed' = @{ it = 'Selezione richiede confirmed=true e riferimento alla conferma effettiva dellʼutente'; en = 'Selection requires confirmed=true and a reference to the user''s actual confirmation' }
    'portable.discovery.modified' = @{ it = 'Rapporto discovery modificato: rieseguire -Discover e usare il nuovo rapporto'; en = 'Discovery report modified: rerun -Discover and use the new report' }
    'portable.discovery.foreign' = @{ it = 'Discovery di altro host o clone: rieseguire -Discover su questa postazione'; en = 'Discovery from another host or clone: rerun -Discover on this workstation' }
    'portable.repository.notinreport' = @{ it = 'Repository selezionato non presente nel rapporto: scegliere uno dei repository trovati dalla discovery'; en = 'Selected repository not present in the report: choose one of the repositories found by the discovery' }
    'portable.repository.forbidden' = @{ it = 'Repository vietato dalle policy di postazione: {0} ({1})'; en = 'Repository forbidden by workstation policy: {0} ({1})' }
    'portable.checkout.changed' = @{ it = 'Checkout cambiato dopo la discovery: {0}; rieseguire -Discover'; en = 'Checkout changed after discovery: {0}; rerun -Discover' }
    'portable.repository.noremote' = @{ it = 'Repo senza remoto: usare identita locale oppure associare esplicitamente un dossier esistente'; en = 'Repository without a remote: use a local identity or explicitly bind an existing dossier' }
    'portable.identity.invalid' = @{ it = 'Identita non valida: usare host/owner/repo oppure local:<32 cifre esadecimali>'; en = 'Invalid identity: use host/owner/repo or local:<32 hexadecimal digits>' }
    'portable.identity.reconcile' = @{ it = 'Cambio di identita richiede riconciliazione esplicita degli alias: rivedere gli alias e confermarli prima di riprovare'; en = 'Identity change requires explicit alias reconciliation: review the aliases and confirm them before retrying' }
    'portable.dossier.ambiguous' = @{ it = 'Dossier ambiguo, archiviato o ritirato: controllare l''indice PARA e indicare un dossier attivo'; en = 'Dossier ambiguous, archived or retired: check the PARA index and name an active dossier' }
    'portable.alias.dossier' = @{ it = 'Associazione alias richiede dossier esistente e revisione esplicita: indicare il dossier e confermare la revisione'; en = 'Alias binding requires an existing dossier and explicit review: name the dossier and confirm the review' }
    'portable.origin.bound' = @{ it = 'Origin gia associato a un altro dossier: usare quel dossier oppure disassociarlo con -Setup -Unbind'; en = 'Origin already bound to another dossier: use that dossier or unbind it with -Setup -Unbind' }
    'portable.destination.uncensused' = @{ it = 'Destinazione non censita gia presente: spostarla o rimuoverla a mano, poi ripetere'; en = 'Uncensused destination already present: move or remove it by hand, then repeat' }
    'portable.block.review' = @{ it = 'Blocco esistente richiede revisione nella selezione: rivederlo e confermarlo con -ApproveExistingBlocks'; en = 'Existing block requires review in the selection: review it and confirm with -ApproveExistingBlocks' }
    'portable.ide.notinreport' = @{ it = 'IDE selezionato non presente nel rapporto: scegliere uno degli IDE trovati dalla discovery'; en = 'Selected IDE not present in the report: choose one of the IDEs found by the discovery' }
    'portable.ide.changed' = @{ it = 'Istruzioni IDE cambiate dopo la discovery: rieseguire -Discover'; en = 'IDE instructions changed after discovery: rerun -Discover' }
    'portable.path.filetype' = @{ it = 'Percorso istruzioni alternativo ammesso solo per IDE di tipo file: {0}'; en = 'Alternative instructions path allowed only for file-type IDEs: {0}' }
    'portable.ide.duplicate' = @{ it = 'Integrazione IDE duplicata nella selezione (stesso profilo, alias, ambiente e percorso): {0}'; en = 'Duplicate IDE integration in the selection (same profile, alias, environment and path): {0}' }
    'portable.checkout.unmanaged' = @{ it = 'Checkout da disassociare non gestito: indicare un repository elencato da -Setup -Status'; en = 'Checkout to unbind is not managed: name a repository listed by -Setup -Status' }
    'portable.ide.unmanaged' = @{ it = 'Integrazione IDE da disassociare non gestita: indicare un IDE elencato da -Setup -Status'; en = 'IDE integration to unbind is not managed: name an IDE listed by -Setup -Status' }
    'portable.choice.invalid' = @{ it = 'Scelta non valida: {0}; digitare uno dei valori proposti'; en = 'Invalid choice: {0}; type one of the proposed values' }
    'portable.path.unsupported' = @{ it = 'Percorso istruzioni alternativo non supportato per {0}'; en = 'Alternative instructions path not supported for {0}' }
    'portable.path.notabsolute' = @{ it = 'Percorso istruzioni alternativo non assoluto: indicare un percorso assoluto'; en = 'Alternative instructions path is not absolute: give an absolute path' }
    'portable.path.filename' = @{ it = 'Il file delle istruzioni di {0} deve chiamarsi {1}'; en = 'The instructions file of {0} must be named {1}' }
    'portable.path.outsideprofile' = @{ it = 'Percorso istruzioni alternativo fuori dal profilo utente: indicare un percorso dentro il profilo utente'; en = 'Alternative instructions path outside the user profile: give a path inside the user profile' }
    'portable.path.credentials' = @{ it = 'Percorso istruzioni alternativo in una cartella di credenziali: scegliere un''altra cartella'; en = 'Alternative instructions path in a credentials folder: choose another folder' }
    'portable.preflight.failed' = @{ it = 'Preflight non superato: {0}'; en = 'Preflight failed: {0}' }
    'portable.selection.missing' = @{ it = 'Selezione assente: indicare -Select, -Ides, -AllIdes, -IdeAccount oppure -Interactive'; en = 'No selection: give -Select, -Ides, -AllIdes, -IdeAccount or -Interactive' }
    'portable.repository.ambiguous' = @{ it = 'Repository non selezionabile o ambiguo: {0} ({1} corrispondenze)'; en = 'Repository not selectable or ambiguous: {0} ({1} matches)' }
    'portable.ideaccount.invalid' = @{ it = 'IdeAccount non valido (atteso id-o-nome|alias[|profile=..|environment=..|path=..|revision=..|hash=..]): {0}'; en = 'Invalid IdeAccount (expected id-or-name|alias[|profile=..|environment=..|path=..|revision=..|hash=..]): {0}' }
    'portable.ide.ambiguous' = @{ it = 'IDE non selezionabile o ambiguo: {0} ({1} corrispondenze)'; en = 'IDE not selectable or ambiguous: {0} ({1} matches)' }
    'portable.ideaccount.field' = @{ it = 'Campo IdeAccount non valido (atteso chiave=valore): {0}'; en = 'Invalid IdeAccount field (expected key=value): {0}' }
    'portable.ideaccount.repeated' = @{ it = 'Campo IdeAccount non valido o ripetuto: {0}'; en = 'Invalid or repeated IdeAccount field: {0}' }
    'portable.observation.invalid' = @{ it = 'Ricevuta account non valida ({0})'; en = 'Invalid account receipt ({0})' }
    'portable.path.filetype.alt' = @{ it = 'Percorso alternativo ammesso solo per IDE di tipo file: {0}'; en = 'Alternative path allowed only for file-type IDEs: {0}' }
    'portable.observed.manual' = @{ it = 'Revisione e hash osservati si registrano solo per le superfici manuali: {0}'; en = 'Observed revision and hash are recorded only for manual surfaces: {0}' }
    'portable.observed.pair' = @{ it = 'revision (es. 1.0) e hash SHA-256 vanno indicati insieme: {0}'; en = 'revision (e.g. 1.0) and SHA-256 hash must be given together: {0}' }
    'portable.selection.empty' = @{ it = 'Nessun repository o IDE selezionato: indicare -Select, -Ides, -AllIdes o -Interactive'; en = 'No repository or IDE selected: give -Select, -Ides, -AllIdes or -Interactive' }
    'portable.prompt.files' = @{ it = 'File di istruzioni da gestire nei repository (AGENTS.md, CLAUDE.md, GEMINI.md separati da virgola, none = nessuno; invio = nessuna modifica: per impostazione predefinita non viene scritto nulla nel repository)'; en = 'Instruction files to manage in the repositories (AGENTS.md, CLAUDE.md, GEMINI.md comma-separated, none = nothing; Enter = no change: by default nothing is written into the repository)' }
    'portable.files.invalid' = @{ it = 'File di istruzioni del repository non valido: {0} (ammessi AGENTS.md, CLAUDE.md, GEMINI.md oppure none)'; en = 'Invalid repository instruction file: {0} (allowed: AGENTS.md, CLAUDE.md, GEMINI.md or none)' }
    'portable.files.pointer' = @{ it = 'CLAUDE.md e GEMINI.md importano AGENTS.md: indicarlo insieme ad essi'; en = 'CLAUDE.md and GEMINI.md import AGENTS.md: list it together with them' }
    'portable.resolve.target' = @{ it = 'Repository non gestito su questa postazione o ambiguo: {0}'; en = 'Repository not managed on this workstation or ambiguous: {0}' }
    'portable.resolve.file' = @{ it = 'File non abilitato per questo repository: {0}'; en = 'File not enabled for this repository: {0}' }
    'portable.resolve.resolution' = @{ it = 'Scegliere la risoluzione con -Resolution Generated oppure Preserve'; en = 'Choose the resolution with -Resolution Generated or Preserve' }
    'portable.resolve.generated' = @{ it = 'Il blocco torna al testo generato; il blocco precedente resta nel backup e in previousBlock'; en = 'The block returns to the generated text; the previous block stays in the backup and in previousBlock' }
    'portable.resolve.preserve' = @{ it = 'Il blocco torna al testo generato; le righe aggiunte a mano restano come testo dopo il blocco'; en = 'The block returns to the generated text; lines added by hand stay as plain text after the block' }
    'portable.resolve.global' = @{ it = 'Direttive comuni non approvate: nessuna risoluzione possibile'; en = 'Common directives not approved: nothing to resolve' }
    'portable.block.present' = @{ it = 'Blocco gestito gia presente in {0}: rivederlo e usare -ApproveExistingBlocks'; en = 'Managed block already present in {0}: review it and use -ApproveExistingBlocks' }
    'portable.block.unapproved' = @{ it = 'Blocco gestito non approvato: {0}; rivederlo e usare -ApproveExistingBlocks'; en = 'Managed block not approved: {0}; review it and use -ApproveExistingBlocks' }
    'portable.environment.alternatives' = @{ it = '-RegisterEnvironment e -NoRegisterEnvironment sono alternativi'; en = '-RegisterEnvironment and -NoRegisterEnvironment are alternatives' }
    'portable.workstation.inactive' = @{ it = 'Postazione non attivata: usare secondbrain.ps1 -Setup'; en = 'Workstation not activated: use secondbrain.ps1 -Setup' }
    'portable.unbind.target' = @{ it = 'Indicare almeno un repository (percorso o identita) o una integrazione IDE (id o nome) da disassociare'; en = 'Give at least one repository (path or identity) or IDE integration (id or name) to unbind' }
    'portable.unbind.ambiguous' = @{ it = 'Repository o integrazione IDE non gestiti o ambigui: {0} ({1} repository, {2} IDE)'; en = 'Repository or IDE integration not managed or ambiguous: {0} ({1} repositories, {2} IDEs)' }
    'portable.repository.notonhost' = @{ it = 'Repository non gestito su questa postazione: {0}'; en = 'Repository not managed on this workstation: {0}' }
    'portable.observations.invalid' = @{ it = 'Osservazioni IDE non valide: rigenerarle con ide-observation.ps1'; en = 'Invalid IDE observations: regenerate them with ide-observation.ps1' }
    'portable.identity.rebind' = @{ it = 'Identita o percorso cambiati: eseguire di nuovo -Setup per riconciliare'; en = 'Identity or path changed: run -Setup again to reconcile' }
    'portable.dossier.identity' = @{ it = 'Identita dossier divergente: verificare repository.json e l''indice PARA'; en = 'Dossier identity diverges: check repository.json and the PARA index' }
}

# SECONDBRAIN_HOME target: 'User' in production; tests redirect it to 'Process' to preserve the user's environment.
$script:SBEnvironmentScope='User'
# Thin pointer files for agents that do not read AGENTS.md (Claude Code, Gemini CLI); the managed block only imports AGENTS.md.
$script:SBRepositoryPointerFiles=@('CLAUDE.md','GEMINI.md')

function New-SBPortableConfiguration([string]$BrainRoot,[string]$WorkstationId=(Get-SBHostId)) {
    $root=Get-SBLocalRoot $BrainRoot $WorkstationId
    @{schemaVersion=1;mode='portable';workstationId=$WorkstationId;runtimeRoot=$root;backupRoot=(Join-Path $root 'backups');repositoryRoot=[IO.Path]::GetFullPath($BrainRoot);
      bindings=@();ides=@();startupBudget=25000}
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
    $stamp=if($Revision){@('Common directives applied: revision **'+$Revision.version+'** — '+$Revision.date+'.','<!-- secondbrain:source global='+$Revision.globalHash+' workstation='+$Revision.workstationHash+' -->')}else{@()}
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
# Zero footprint (#484): a repository activated from now on gets nothing written into its checkout by default. Instructions reach the
# agents through the user-scope IDE text and MCP; a binding lists the repository files it may manage (repositoryFiles) only after an
# explicit choice. Bindings created before the field existed keep their files (see Get-SBBindingRepositoryFiles).
$script:SBRepositoryFileNames=@('AGENTS.md')+$script:SBRepositoryPointerFiles
function ConvertTo-SBRepositoryFiles([string[]]$Values) {
    $names=@($Values|ForEach-Object {([string]$_) -split ','}|ForEach-Object {$_.Trim()}|Where-Object {$_})
    if($names.Count -eq 1 -and $names[0] -ieq 'none'){return @()}
    $result=@()
    foreach($name in $names){
        $match=@($script:SBRepositoryFileNames|Where-Object {$_ -ieq $name})
        if(!$match.Count){throw (New-SBError 'portable.files.invalid' @($name))}
        $result+=$match[0]
    }
    $result=@($result|Select-Object -Unique)
    if($result.Count -and 'AGENTS.md' -notin $result){throw (New-SBError 'portable.files.pointer')}
    $result
}
# No binding (a repository not yet activated) manages nothing. A binding written before repositoryFiles existed keeps managing every
# repository file as it always did, so an upgrade changes no checkout; activations from now on always record an explicit list.
function Get-SBBindingRepositoryFiles($Binding) {
    if($null -eq $Binding){return @()}
    $declared=$false;$value=$null
    if($Binding -is [Collections.IDictionary]){if($Binding.Contains('repositoryFiles')){$declared=$true;$value=$Binding['repositoryFiles']}}
    elseif($Binding.PSObject.Properties['repositoryFiles']){$declared=$true;$value=$Binding.repositoryFiles}
    if(!$declared -or $null -eq $value){return @($script:SBRepositoryFileNames)}
    @($value|Where-Object {$_ -in $script:SBRepositoryFileNames})
}
# AGENTS.md is the single source. Claude Code reads CLAUDE.md and Gemini CLI GEMINI.md, not AGENTS.md: thin managed pointers import it.
function Set-SBRepositoryPointers([string]$Checkout,[hashtable]$State,[bool]$Check,[string]$BackupRoot,[string[]]$Files=$script:SBRepositoryPointerFiles) {
    foreach($pointer in @($script:SBRepositoryPointerFiles|Where-Object {$_ -in $Files})){
        @{file=$pointer;result=(Set-SBManagedContent (Join-Path $Checkout $pointer) '@AGENTS.md' 'pointer' $State $Check $BackupRoot)}
    }
}
function Get-SBSetupDossierConflicts([string]$BrainRoot,[string]$PersonalRoot,$Repositories,[switch]$Refresh) {
    if(!$PersonalRoot -or !$Repositories.Count -or (Test-SBSamePath $PersonalRoot $BrainRoot)){return}
    $personalAreas=@(Get-SBParaEntities $PersonalRoot @() -Refresh:$Refresh|Where-Object {(Test-SBRepoDossier $_) -and !$_.archived -and $_.status -eq 'active'})
    $teamAreas=@(Get-SBParaEntities $BrainRoot @() -Refresh:$Refresh|Where-Object {(Test-SBRepoDossier $_) -and !$_.archived -and $_.status -eq 'active'})
    foreach($plan in $Repositories){
        $personal=$personalAreas|Where-Object repository -eq $plan.identity
        $team=$teamAreas|Where-Object repository -eq $plan.identity
        if($personal -and $team){
            @{identity=$plan.identity;checkout=$plan.path;personalDossier=(Resolve-SBParaPath $PersonalRoot $personal.path)
                teamDossier=(Resolve-SBParaPath $BrainRoot $team.path);message=(Get-SBMessage 'portable.setup.dossier.conflict')}
        }
    }
}
# The checkout's own tracker, in the order Resolve-SBTracker uses: tracker.md is enough by itself; JSON
# candidates count only when they parse as an object. compatible = valid schema-1 tracker once its
# repository is realigned to the target identity (the import keeps ids, seq, evidence and provenance).
function Get-SBCheckoutTrackerSource([string]$CheckoutPath,[string]$Identity) {
    foreach($name in @('tracker.json','tracker.md','tasks.json','legacy-tasks.json')){
        $path=Join-Path $CheckoutPath $name
        if(!(Test-Path -LiteralPath $path -PathType Leaf)){continue}
        if($name -eq 'tracker.md'){return @{path=$name;compatible=$false}}
        $data=try{Read-SBJson $path $null}catch{$null}
        if($data -isnot [Collections.IDictionary]){continue}
        $compatible=$false
        if($data.Contains('schemaVersion') -and $data.schemaVersion -eq 1){
            $copy=ConvertTo-SBJson $data|ConvertFrom-Json -AsHashtable -DateKind String
            $original=if($copy.Contains('repository')){[string]$copy.repository}else{''}
            Remove-SBOriginDependencyRepository @($copy['tasks']) $original
            $copy.repository=$Identity
            $compatible=try{[bool](Test-SBTrackerData $copy $Identity @($Identity) (Join-Path $PSScriptRoot '../config/tracker.schema.json'))}catch{$false}
        }
        return @{path=$name;compatible=$compatible}
    }
    $null
}
function Invoke-SBHostActivation {
    param([string]$BrainRoot,[string]$SelectionPath,[string]$SessionId,[switch]$Apply,[switch]$RegisterEnvironment,
          [hashtable]$PreviewSelection,[hashtable]$PreviewReport,[string]$TeamPersonalRoot,[switch]$PlanSync)
    $paths=Get-SBSetupPaths $BrainRoot
    if($PreviewSelection -and $PreviewReport -and !$Apply){
        $selection=$PreviewSelection
        $report=$PreviewReport
    }else{
        $SelectionPath=Assert-SBSetupStatePath $BrainRoot $paths.hostRoot $SelectionPath @('selection.json','unbind-selection.json')
        $selection=Read-SBJson $SelectionPath $null
        if(!$selection -or $selection.schemaVersion -ne 1 -or $selection.confirmed -ne $true -or !$selection.confirmation){throw (New-SBError 'portable.selection.unconfirmed')}
        $reportPath=Assert-SBSetupStatePath $BrainRoot $paths.hostRoot $selection.reportPath @('discovery.json','unbind-report.json')
        if((Get-SBFileHash $reportPath) -ne $selection.reportSha256){throw (New-SBError 'portable.discovery.modified')}
        $report=Read-SBJson $reportPath $null
    }
    if($report.hostId -ne (Get-SBHostId) -or !(Test-SBSamePath $report.brainRoot $BrainRoot)){throw (New-SBError 'portable.discovery.foreign')}
    $configPath=Get-SBHostConfigPath $BrainRoot
    $configurationHash=Get-SBFileHash $configPath
    $configuration=Read-SBJson $configPath (New-SBPortableConfiguration $BrainRoot)
    $configuration.runtimeRoot=Get-SBLocalRoot $BrainRoot $configuration.workstationId
    $teamBackupRoot=Join-Path $BrainRoot ('.runtime/access/recovery/'+$configuration.workstationId)
    $configuration.backupRoot=if($TeamPersonalRoot -or (Test-SBSamePath $configuration.backupRoot $teamBackupRoot)){
        $teamBackupRoot
    }else{Join-Path $configuration.runtimeRoot 'backups'}
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
        $existing=@($entities|Where-Object {(Test-SBRepoDossier $_) -and $_.repository -ceq $identity})
        if($existing.Count -gt 1 -or ($existing.Count -and ($existing[0].archived -or $existing[0].status -ne 'active'))){throw (New-SBError 'portable.dossier.ambiguous')}
        $dossierRelative=if($existing.Count){$existing[0].path}else{'01-projects/'+($asset.name -replace '[^A-Za-z0-9_.-]','-')+'--'+(Get-SBTextHash $identity).Substring(0,8).ToLowerInvariant()}
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
        $trackerSource=if(!$existing.Count){Get-SBCheckoutTrackerSource $asset.path $identity}else{$null}
        $requiresImport=($null -ne $trackerSource)
        if(!$existing.Count){
            $metadata=New-SBParaMetadata ('project-'+(Get-SBTextHash $identity).Substring(0,20).ToLowerInvariant()) 'project' $asset.name
            $repo=@{schemaVersion=1;identity=$identity}
            if(!$requiresImport){$repo.tracker=@{location='dossier';path='tracker.json';schemaVersion=1}}
            $seed=@{'para.json'=(ConvertTo-SBJson $metadata);'repository.json'=(ConvertTo-SBJson $repo);'brief.md'=("# "+$asset.name+"`n`nRepository selezionato per la gestione della conoscenza. Perimetro e stato nel contesto corrente.`n");
              'context.md'=(Read-SBText (Join-Path $PSScriptRoot 'SecondBrain.context.template.md'));
              'memory.md'="# Memoria essenziale`n`nNessuna decisione tecnica ancora qualificata.`n"
              'specs/README.md'="# Specifiche`n`nSpecifiche e requisiti da implementare nel repository.`n";'material/README.md'="# Materiale`n`nMateriale di riferimento del progetto (non nel repository).`n";'data/README.md'="# Dati`n`nDati iniziali o di lavoro da implementare nel repository.`n"}
            if(!$requiresImport){$seed['tracker.json']=ConvertTo-SBJson @{schemaVersion=1;repository=$identity;updatedAt=(Get-SBNow).ToString('o');tasks=@();history=@();extensions=@{}}}
            foreach($name in $seed.Keys){$path=Join-Path $dossier $name;if(Test-Path -LiteralPath $path){throw (New-SBError 'portable.destination.uncensused')};$operations+=@{path=$path;expected='absent';bytes=[Text.Encoding]::UTF8.GetBytes($seed[$name])}}
        }
        $managedHash='absent'
        # Files SecondBrain may manage in the checkout: only an explicit choice; a repeated activation keeps the earlier one.
        $previousBinding=@($configuration.bindings|Where-Object {$_.path -ieq $asset.path})|Select-Object -First 1
        $repositoryFiles=if($choice.ContainsKey('repositoryFiles')){@(ConvertTo-SBRepositoryFiles @($choice.repositoryFiles))}else{@(Get-SBBindingRepositoryFiles $previousBinding)}
        $existingBlock=if('AGENTS.md' -in $repositoryFiles -and $asset.agentsHash -ne 'absent'){Get-SBManagedContent ((Read-SBText (Join-Path $asset.path 'AGENTS.md')) -replace "`r`n","`n") 'repository'}else{$null}
        if($null -ne $existingBlock){
            if(!$choice.ContainsKey('approveExistingBlock') -or !$choice.approveExistingBlock){throw (New-SBError 'portable.block.review')}
            $managedHash=Get-SBTextHash $existingBlock
        }
        $newBindings+=@{path=$asset.path;identity=$identity;remoteIdentity=$current.remoteIdentity;fingerprint=$current.fingerprint;dossier=$dossierRelative;managedHash=$managedHash;repositoryFiles=@($repositoryFiles);status=$(if($requiresImport){'tracker-import-required'}else{'managed'})}
        $plans+=@{identity=$identity;path=$asset.path;dossier=$dossierRelative;trackerImportRequired=$requiresImport;trackerSource=$trackerSource;repositoryFiles=@($repositoryFiles)}
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
    if($SelectionPath){$configuration.selectionReceipt=@{sha256=(Get-SBFileHash $SelectionPath);confirmation=$selection.confirmation;reportSha256=$selection.reportSha256}}
    $configOperation=@{path=$configPath;expected=$configurationHash;bytes=[Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $configuration))}
    $externalState=$paths.hostRoot -ine (Get-SBLocalRoot $BrainRoot (Get-SBHostId))
    if(!$externalState){$operations+=$configOperation}
    $plannedFiles=@($operations|ForEach-Object path)
    if($externalState){$plannedFiles+=$configPath}
    if($Apply){
        $lockConfig=if(Test-Path -LiteralPath $configPath){Read-SBConfiguration $configPath -BrainRoot $BrainRoot}else{$configuration.brainRoot=$BrainRoot;$configuration.configPath=$configPath;$configuration.allowedOwners=@();$configuration.coordinationRoot=Join-Path $BrainRoot '.runtime/access';$configuration}
        $lockConfig.brainRoot=$BrainRoot;$lockConfig.coordinationRoot=Join-Path $BrainRoot '.runtime/access'
        $lockConfig.backupRoot=$configuration.backupRoot
        $lock=Enter-SBOperation $lockConfig $SessionId
        try{
            if(@(Get-SBSetupDossierConflicts $BrainRoot $TeamPersonalRoot $plans -Refresh).Count){
                throw (New-SBError 'portable.setup.dossier.conflict')
            }
            if($operations.Count){Invoke-SBParaTransaction $operations $configuration.backupRoot $BrainRoot|Out-Null}
            # External workstation bytes never enter the shared dossier transaction or its rollback payload.
            if($externalState){Write-SBFile $configPath $configOperation.bytes $configurationHash $paths.backupRoot|Out-Null}
            if($RegisterEnvironment){[Environment]::SetEnvironmentVariable('SECONDBRAIN_HOME',[IO.Path]::GetFullPath($BrainRoot),$script:SBEnvironmentScope)}
            Update-SBParaIndex (Read-SBConfiguration $configPath -BrainRoot $BrainRoot)|Out-Null
        }finally{Exit-SBOperation $lock}
    }
    $activation=@{applied=[bool]$Apply;configuration=$configPath;repositories=$plans;retiredCheckouts=$retirePaths;retiredIdes=$retireIDEIds;ides=@($selectedIDEs|ForEach-Object name);ideBindings=@($selectedIDEs|ForEach-Object {$binding=@{id=$_.id;assetId=$_.assetId;profile=$_.profile;accountAlias=$_.accountAlias};if($_.ContainsKey('observedRevision') -and $_.observedRevision){$binding.observedRevision=$_.observedRevision;$binding.observedHash=$_.observedHash};$binding});directivesDeployed=$false;activation='metadata-only; run Sync after approval of portable directives';plannedFiles=$plannedFiles}
    if($PlanSync){
        $revision=Get-SBApprovedDirectiveRevision $BrainRoot
        $targets=@(foreach($binding in $configuration.bindings){
            foreach($name in @(Get-SBBindingRepositoryFiles $binding)){Join-Path $binding.path $name}
        })
        $targets+=@($configuration.ides|Where-Object mode -eq 'file'|ForEach-Object instructions)
        $activation.directiveSync=@{approvedRevision=$(if($revision){$revision.version});targets=@($targets|Sort-Object -Unique)}
    }
    $activation
}
function Get-SBSetupPaths([string]$BrainRoot) {
    $root=Get-SBWorkstationStateRoot $BrainRoot (Get-SBHostId)
    @{hostRoot=$root;backupRoot=(Join-Path $root 'backups');report=(Join-Path $root 'discovery.json');selection=(Join-Path $root 'selection.json');setupResult=(Join-Path $root 'setup-result.json')}
}
function Test-SBGitRequirement([string]$VersionText,[int]$ExitCode=0) {
    $match=[regex]::Match($VersionText,'^git version (\d+)\.(\d+)\.(\d+)(?:[.\s-].*)?$')
    $ok=$ExitCode -eq 0 -and $match.Success
    if($ok){$ok=([version]($match.Groups[1].Value+'.'+$match.Groups[2].Value+'.'+$match.Groups[3].Value) -ge [version]'2.42.0')}
    @{name='git';ok=[bool]$ok;blocking=$true;detail=$(if($ok){$VersionText}else{(Get-SBMessage 'portable.git.required')+' ('+$VersionText+')'})}
}
function Test-SBSetupPreflight([string]$BrainRoot,[switch]$ReadOnly) {
    $checks=@()
    $checks+=@{name='powershell';ok=($PSVersionTable.PSVersion -ge [version]'7.5');blocking=$true;detail=$PSVersionTable.PSVersion.ToString()}
    $git=Get-Command git -CommandType Application -ErrorAction SilentlyContinue|Select-Object -First 1
    $gitExit=1
    $gitDetail=if($git){try{$value=(& $git.Source --version 2>&1|Out-String).Trim();$gitExit=$LASTEXITCODE;$value}catch{''}}else{''}
    $checks+=Test-SBGitRequirement $gitDetail $gitExit
    $writable=@{name='runtime-scrivibile';ok=$false;blocking=$true;detail='.runtime/hosts/'+(Get-SBHostId)}
    if(!$ReadOnly){
        try{
            $hostRoot=Get-SBWorkstationStateRoot $BrainRoot (Get-SBHostId);[void][IO.Directory]::CreateDirectory($hostRoot)
            $probe=[IO.FileStream]::new((Join-Path $hostRoot ('.setup-probe-'+(New-SBId))),[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None,1,[IO.FileOptions]::DeleteOnClose)
            $probe.Dispose();$writable.ok=$true
        }catch{$writable.detail=$_.Exception.Message}
        $checks+=$writable
    }
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
# Account text observed in the settings, read from a receipt under .runtime instead of typed values (typos produce wrong findings).
function Read-SBAccountObservationReceipt([string]$BrainRoot,[string]$Path,[string]$IdeId,[string]$Alias) {
    $full=Assert-SBCentralDataPath $BrainRoot $Path
    if(![IO.File]::Exists($full) -or ([IO.FileInfo]::new($full)).Length -gt 1MB){throw (New-SBError 'portable.observation.invalid' @('file'))}
    try{$receipt=(Read-SBText $full)|ConvertFrom-Json -AsHashtable -DateKind String -ErrorAction Stop}catch{throw (New-SBError 'portable.observation.invalid' @('json'))}
    if($receipt -isnot [System.Collections.IDictionary]){throw (New-SBError 'portable.observation.invalid' @('shape'))}
    foreach($key in $receipt.Keys){if($key -cnotin @('schemaVersion','ideId','accountAlias','observedRevision','observedHash')){throw (New-SBError 'portable.observation.invalid' @('field '+$key))}}
    foreach($key in 'schemaVersion','observedRevision','observedHash'){if(!$receipt.ContainsKey($key)){throw (New-SBError 'portable.observation.invalid' @('missing '+$key))}}
    if($receipt.schemaVersion -ne 1 -or $receipt.observedRevision -isnot [string] -or $receipt.observedRevision -notmatch '^\d+(\.\d+)+$' -or
       $receipt.observedHash -isnot [string] -or $receipt.observedHash -notmatch '^[0-9A-Fa-f]{64}$'){throw (New-SBError 'portable.observation.invalid' @('revision/hash'))}
    if($receipt.ContainsKey('ideId') -and $receipt.ideId -cne $IdeId){throw (New-SBError 'portable.observation.invalid' @('ideId'))}
    if($receipt.ContainsKey('accountAlias') -and $receipt.accountAlias -cne $Alias){throw (New-SBError 'portable.observation.invalid' @('accountAlias'))}
    @{observedRevision=$receipt.observedRevision;observedHash=$receipt.observedHash.ToUpperInvariant();receiptPath=$full;receiptSha256=(Get-SBFileHash $full)}
}
function Invoke-SBSetup {
    param([string]$BrainRoot,[string[]]$Roots=@(),[int]$MaxDirectories=0,[string[]]$Select=@(),[string[]]$Ides=@(),[switch]$AllIdes,[string[]]$IdeAccount=@(),
          [switch]$ApproveExistingBlocks,[switch]$Interactive,[switch]$Yes,[switch]$Apply,[switch]$RegisterEnvironment,[switch]$NoRegisterEnvironment,[switch]$AndSync=$true,[string]$SessionId,
          [string[]]$McpTargets=@(),[switch]$ApproveMcpReadTools,[switch]$PreviewOnly,[string]$PersonalRoot,[string[]]$RepositoryFiles=@())
    $brain=[IO.Path]::GetFullPath($BrainRoot);$paths=Get-SBSetupPaths $brain;$hostId=Get-SBHostId
    $teamSetup=[bool]($PersonalRoot -and !$PreviewOnly)
    $McpTargets=@($McpTargets|ForEach-Object {$_ -split ','}|ForEach-Object {$_.Trim()}|Where-Object {$_}|Select-Object -Unique)
    # Empty = not specified (nothing is written into checkouts; an earlier choice is kept); 'none' = explicit empty choice.
    $requestedFiles=@($RepositoryFiles|ForEach-Object {([string]$_) -split ','}|ForEach-Object {$_.Trim()}|Where-Object {$_})
    $filesSpecified=[bool]$requestedFiles.Count
    $repositoryFilesChosen=if($filesSpecified){@(ConvertTo-SBRepositoryFiles $requestedFiles)}else{@()}
    foreach($target in $McpTargets){if($target -notin @('codex','claude','claude-code','cursor','vscode','antigravity','windsurf','all')){throw (New-SBError 'portable.mcp.targets')}}
    if($RegisterEnvironment -and $NoRegisterEnvironment){throw (New-SBError 'portable.environment.alternatives')}
    # With -File, a list arrives as a single comma-separated string.
    $Select=@($Select|ForEach-Object {$_ -split ','}|ForEach-Object {$_.Trim()}|Where-Object {$_})
    $Ides=@($Ides|ForEach-Object {$_ -split ','}|ForEach-Object {$_.Trim()}|Where-Object {$_})
    $result=[ordered]@{stage='preflight';hostId=$hostId;confirmed=$false;applied=$false}
    $needSelection=(!$Select.Count -and !$Ides.Count -and !$AllIdes -and !@($IdeAccount|Where-Object {$_}).Count)
    $prompting=($Interactive -or ($needSelection -and !$PreviewOnly))
    $readOnlyDiscovery=($PreviewOnly -or $prompting -or $teamSetup)
    $preflight=@(Test-SBSetupPreflight $brain -ReadOnly:$readOnlyDiscovery);$result.preflight=$preflight
    $failed=@($preflight|Where-Object {$_.blocking -and !$_.ok})
    if($failed.Count){throw (New-SBError 'portable.preflight.failed' @((($failed|ForEach-Object {$_.name+' ('+$_.detail+')'}) -join '; ')))}
    if($needSelection -and !$Interactive -and !$PreviewOnly -and [Console]::IsInputRedirected){throw (New-SBError 'portable.selection.missing')}
    if($PreviewOnly -and !$Roots.Count){$Roots=@($brain)}
    if($prompting -and !$Roots.Count){
        $answer=([string](Read-Host 'Cartelle da analizzare separate da ; (obbligatorio)')).Trim()
        if($answer){$Roots=@($answer -split ';'|ForEach-Object {$_.Trim()}|Where-Object {$_})}
    }
    $configPath=Get-SBHostConfigPath $brain;$bindings=@()
    if(Test-Path -LiteralPath $configPath){$existingConfig=Read-SBJson $configPath @{};if($existingConfig.ContainsKey('bindings')){$bindings=@($existingConfig.bindings)}}
    $result.stage='discovery'
    # The full discovery is never persisted: only a pause checkpoint (-MaxDirectories) is written; the final record keeps the selected repositories only.
    $reportPath=if(!$readOnlyDiscovery -and $MaxDirectories -gt 0){$paths.report}
    $report=Invoke-SBHostDiscovery -BrainRoot $brain -Roots $Roots -Bindings $bindings -ReportPath $reportPath -MaxDirectories $MaxDirectories
    $repos=@($report.repositories|Where-Object {$_.kind -in @('repository','worktree','submodule') -and $_.status -eq 'discovered'})
    $result.discovery=[ordered]@{complete=[bool]$report.complete;paused=[bool]$report.paused;repositories=$repos.Count;ides=@($report.ides).Count;issues=@($report.issues).Count;warnings=@($report.warnings).Count;report=$reportPath}
    if($report.paused){$result.stage='discovery-paused';return $result}
    $result.stage='proposal'
    $boundPaths=@($bindings|ForEach-Object {$_.path})
    $result.proposal=[ordered]@{
        repositories=@($repos|ForEach-Object {[ordered]@{id=$_.id;name=$_.name;path=$_.path;identity=$(if($_.identity){$_.identity}else{'local'});bound=($_.path -in $boundPaths)}})
        ides=@($report.ides|ForEach-Object {[ordered]@{id=$_.id;name=$_.name;mode=$_.mode}})}
    if($PreviewOnly -and $needSelection -and !$Interactive){$result.stage='preview';return $result}
    # Repository selection.
    $chosen=@()
    if($Select.Count){
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
    if($prompting -and !$filesSpecified -and $chosen.Count){
        $answer=([string](Read-Host (Get-SBMessage 'portable.prompt.files'))).Trim()
        if($answer){$requestedFiles=@($answer -split '[,\s]+'|Where-Object {$_});$repositoryFilesChosen=@(ConvertTo-SBRepositoryFiles $requestedFiles);$filesSpecified=$true}
    }
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
            if($key -notin @('profile','environment','path','revision','hash','observation') -or !$value -or $fields.ContainsKey($key)){throw (New-SBError 'portable.ideaccount.repeated' @($key))}
            $fields[$key]=$value
        }
        if($fields.ContainsKey('profile')){$entry.profile=$fields.profile}
        if($fields.ContainsKey('environment')){$entry.environment=$fields.environment}
        if($fields.ContainsKey('path')){
            if($found[0].mode -ne 'file'){throw (New-SBError 'portable.path.filetype.alt' @($found[0].name))}
            $entry.instructionsPath=Assert-SBIDEInstructionsPath $found[0].name $fields.path
        }
        if($fields.ContainsKey('observation')){
            if($found[0].mode -ne 'manual'){throw (New-SBError 'portable.observed.manual' @($found[0].name))}
            if($fields.ContainsKey('revision') -or $fields.ContainsKey('hash')){throw (New-SBError 'portable.observed.pair' @($spec))}
            $receiptValues=Read-SBAccountObservationReceipt $brain $fields.observation $found[0].id $parts[1]
            $entry.observedRevision=$receiptValues.observedRevision;$entry.observedHash=$receiptValues.observedHash
            $entry.accountObservation='Testo account letto da una ricevuta sotto .runtime (hash '+$receiptValues.receiptSha256+'); il caricamento in una chat resta non verificato.'
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
    if(!$chosen.Count -and !$chosenIdes.Count){
        if($PreviewOnly){$result.stage='preview';$result.selectionEmpty=$true;return $result}
        throw (New-SBError 'portable.selection.empty')
    }
    # Minimal record: repositories, paths and issues of everything not selected are neither kept nor persisted (counts only).
    $fullReport=$report
    $report=@{schemaVersion=1;hostId=$fullReport.hostId;brainRoot=$fullReport.brainRoot;observedAt=$fullReport.observedAt;roots=@($fullReport.roots);visited=@();pending=@()
        complete=[bool]$fullReport.complete;paused=$false;repositories=@($chosen);ides=@($chosenIdes);issues=@();warnings=@();excluded=@();extensions=@()
        scope=@{minimal=$true;discoveredRepositories=$repos.Count;selectedRepositories=$chosen.Count}}
    # An IDE with a declared alias is one integration: do not add the unaliased entry for the same IDE selected by name.
    $accountIdeIds=@($accountEntries|ForEach-Object {$_.id})
    $plainIdes=@($plainIdes|Where-Object {$_.id -notin $accountIdeIds})
    # Existing managed blocks require explicit review, except a block identical to what Sync would write using the approved revision (same markers and source hashes).
    $approvals=@{}
    $approvedRevision=Get-SBApprovedDirectiveRevision $brain
    $directiveAreas=if($approvedRevision){@(Get-SBParaEntities $brain @()|Where-Object {(Test-SBRepoDossier $_) -and !$_.archived})}else{@()}
    foreach($asset in $chosen){
        # A checkout whose AGENTS.md SecondBrain does not manage is never read for blocks or approvals.
        $effectiveFiles=if($filesSpecified){$repositoryFilesChosen}else{@(Get-SBBindingRepositoryFiles (@($bindings|Where-Object {$_.path -ieq $asset.path})|Select-Object -First 1))}
        if('AGENTS.md' -notin $effectiveFiles){continue}
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
    $targetsByName=$script:SBPortableMcpTargets
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
    $selection=@{schemaVersion=1;confirmed=$false;confirmation='';reportPath=$paths.report;reportSha256='absent'
        repositories=@($chosen|ForEach-Object {$entry=@{id=$_.id};if($approvals.ContainsKey($_.id)){$entry.approveExistingBlock=$true};if($filesSpecified){$entry.repositoryFiles=@($repositoryFilesChosen)};$entry})
        ides=@(@($plainIdes|ForEach-Object {@{id=$_.id}})+$accountEntries)}
    $result.stage='preview'
    $preview=Invoke-SBHostActivation -BrainRoot $brain -PreviewSelection $selection -PreviewReport $report -PlanSync:$AndSync
    $preview.setupRecords=@($paths.report,$paths.selection,$paths.setupResult)
    if($PersonalRoot){
        $result.dossierConflicts=@(Get-SBSetupDossierConflicts $brain $PersonalRoot $preview.repositories)
        if($teamSetup -and $result.dossierConflicts.Count){
            $result.stage='dossier-conflict'
            $result.activation=$preview
            return $result
        }
    }
    if($teamSetup -and (Test-SBSamePath $paths.hostRoot (Get-SBLocalRoot $brain $hostId))){
        throw (New-SBError 'portable.setup.team.state')
    }
    if($McpTargets.Count){
        $result.mcp=[ordered]@{preview=$true;approveReadTools=[bool]$ApproveMcpReadTools;targets=@(foreach($job in $mcpJobs){
            if($job.status -ne 'supported'){$job;continue}
            Get-SBMcpPairing -BrainRoot $brain -Target $job.target -ConfigFile $job.configFile -Scope user -ApproveAllTools:(!$ApproveMcpReadTools)
        })}
    }
    if($PreviewOnly){$result.activation=$preview;return $result}
    $confirmed=[bool]$Yes
    $doApply=[bool]$Apply
    $how='-Yes'
    $reportBytes=[Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $report))
    if($prompting){
        Write-Host (Get-SBMessage 'portable.setup.preview')
        Write-Host (ConvertTo-SBJson $preview)
        if($McpTargets.Count){
            Write-Host (Get-SBMessage 'portable.mcp.preview')
            Write-Host (ConvertTo-SBJson $result.mcp)
        }
        if(([string](Read-Host (Get-SBMessage 'portable.setup.apply'))).Trim() -cne 'APPLICA'){
            $result.activation=$preview
            return $result
        }
        $confirmed=$true
        $doApply=$true
        $how='interattiva'
    }
    if($readOnlyDiscovery -and $confirmed -and $doApply){
        $writeCheck=@(Test-SBSetupPreflight $brain | Where-Object name -eq 'runtime-scrivibile')[0]
        $result.preflight+=@($writeCheck)
        if(!$writeCheck.ok){throw (New-SBError 'portable.preflight.failed' @($writeCheck.detail))}
        Write-SBFile $paths.report $reportBytes (Get-SBFileHash $paths.report) $paths.backupRoot -Recoverable|Out-Null
        $result.discovery.report=$paths.report
    }
    elseif(!$readOnlyDiscovery){
        Write-SBFile $paths.report $reportBytes (Get-SBFileHash $paths.report) $paths.backupRoot -Recoverable|Out-Null
        $result.discovery.report=$paths.report
    }
    $selection.confirmed=$confirmed
    if($confirmed){$selection.confirmation=[Environment]::UserName+'@'+[Environment]::MachineName+' '+(Get-SBNow).ToString('o')+' ('+$how+')'}
    $selection.reportSha256=Get-SBHash $reportBytes
    $selectionPath=$paths.selection
    Write-SBFile $selectionPath ([Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $selection))) (Get-SBFileHash $selectionPath) $paths.backupRoot|Out-Null
    $result.selection=$selectionPath;$result.confirmed=$confirmed
    if(!$confirmed){$result.stage='proposal';$result.note='Conferma mancante: selezione registrata come proposta (confirmed=false). Rilanciare con -Yes oppure -Interactive.';return $result}
    if(!$doApply){$result.activation=$preview;return $result}
    $doRegister=!$NoRegisterEnvironment
    $applied=Invoke-SBHostActivation -BrainRoot $brain -SelectionPath $selectionPath -SessionId $SessionId -Apply -RegisterEnvironment:$doRegister -TeamPersonalRoot $PersonalRoot
    if($McpTargets.Count){
        $mcpLock=Enter-SBOperation (Read-SBConfiguration $configPath -BrainRoot $brain) $SessionId
        try{
            $mcpItems=@(foreach($job in $mcpJobs){
                if($job.status -ne 'supported'){@{Target=$job.target;Profile=$job.profile;Action=$job.status;PermissionAction='skipped';ClientSessionVerified=$false};continue}
                try{Set-SBMcpConfiguration -BrainRoot $brain -Target $job.target -ConfigFile $job.configFile -Scope user -BackupRoot $paths.backupRoot -ApproveReadTools:$ApproveMcpReadTools -ApproveAllTools:(!$ApproveMcpReadTools)}
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
        $config=Read-SBConfiguration $configPath -BrainRoot $brain
        $sync=Invoke-SBPortableSync -Config $config -Check:(!$AndSync) -SessionId $SessionId
        $result.check=[ordered]@{mode=$(if($AndSync){'sync'}else{'check'});aligned=[bool]$sync.aligned;filesAligned=[bool]$sync.filesAligned;repositories=$sync.repositories;issues=@($sync.issues|ForEach-Object {$_.kind}|Sort-Object -Unique)}
    }catch{if(Test-SBWriteDeniedError $_){throw};$result.check=[ordered]@{mode='check';error=$_.Exception.Message}}
    $result.next=if($AndSync){'Verificare caricamento IDE e account (manuale).'}else{'Distribuire le direttive con secondbrain.ps1 -Sync dopo aver riletto il -Check.'}
    $result.setupReport=$paths.setupResult
    $reportLock=Enter-SBOperation (Read-SBConfiguration $configPath -BrainRoot $brain) $SessionId
    try{
        [void](Write-SBFile $paths.setupResult ([Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $result))) (Get-SBFileHash $paths.setupResult) $paths.backupRoot)
    }finally{Exit-SBOperation $reportLock}
    $result
}
function Get-SBIDEStaleObservation($Ide,[string]$GlobalText) {
    # Manual entry with observed text (observedHash) differing from approval: return observed and expected revisions; otherwise $null.
    if(!$Ide.ContainsKey('observedHash') -or !$Ide.observedHash){return $null}
    $text=$GlobalText.Trim()
    if([string]$Ide.observedHash -ceq (Get-SBTextHash $text)){return $null}
    $expected=if($text -match 'Revisi(?:on|one) (\d+(?:\.\d+)+)'){$Matches[1]}else{'sconosciuta'}
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
    $statePath=Join-Path (Get-SBWorkstationStateRoot $brain (Get-SBHostId)) 'state.json'
    if(!(Test-Path -LiteralPath $statePath) -and $config.ContainsKey('runtimeRoot') -and $config.runtimeRoot){
        $statePath=Join-Path $config.runtimeRoot 'state.json'
    }
    $state=if($statePath -and (Test-Path -LiteralPath $statePath -PathType Leaf)){Read-SBJson $statePath @{}}else{$null}
    [ordered]@{stage='status';hostId=(Get-SBHostId);configuration=$configPath
        bindings=@($bindings|ForEach-Object {[ordered]@{path=(& $value $_ 'path');identity=(& $value $_ 'identity');dossier=(& $value $_ 'dossier');status=(& $value $_ 'status')}})
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
    $reportPath=Join-Path $paths.hostRoot 'unbind-report.json'
    $report=@{schemaVersion=1;kind='unbind';hostId=(Get-SBHostId);brainRoot=$brain;repositories=@();ides=@()}
    Write-SBFile $reportPath ([Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $report))) (Get-SBFileHash $reportPath) $paths.backupRoot|Out-Null
    $prompting=[bool]$Interactive
    $confirmed=$false;$how=''
    if($Yes){$confirmed=$true;$how='-Yes'}
    elseif($prompting){
        Write-Host (Get-SBMessage 'portable.unbind.summary' @($retire.Count,$retireIdes.Count));$retire|ForEach-Object {Write-Host ('  '+$_)};$retireIdes|ForEach-Object {Write-Host ('  IDE '+$_)}
        if(([string](Read-Host 'Digita CONFERMO per registrare la scelta')).Trim() -ceq 'CONFERMO'){$confirmed=$true;$how='interattiva'}
    }
    $confirmation=if($confirmed){[Environment]::UserName+'@'+[Environment]::MachineName+' '+(Get-SBNow).ToString('o')+' ('+$how+')'}else{''}
    $selection=@{schemaVersion=1;confirmed=$confirmed;confirmation=$confirmation;reportPath=$reportPath;reportSha256=(Get-SBFileHash $reportPath);repositories=@();ides=@();retireCheckoutPaths=$retire;retireIDEIds=$retireIdes}
    $selectionPath=Join-Path $paths.hostRoot 'unbind-selection.json'
    Write-SBFile $selectionPath ([Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $selection))) (Get-SBFileHash $selectionPath) $paths.backupRoot|Out-Null
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
# Line diff of a managed block (LCS): '- ' only in the file now, '+ ' only in the generated text, '  ' common.
function Get-SBLineDiff([string[]]$Current,[string[]]$Generated) {
    $n=$Current.Count;$m=$Generated.Count
    $table=New-Object 'int[,]' ($n+1),($m+1)
    for($i=$n-1;$i -ge 0;$i--){for($j=$m-1;$j -ge 0;$j--){
        $table[$i,$j]=if($Current[$i] -ceq $Generated[$j]){$table[($i+1),($j+1)]+1}else{[Math]::Max($table[($i+1),$j],$table[$i,($j+1)])}
    }}
    $i=0;$j=0;$lines=@()
    while($i -lt $n -and $j -lt $m){
        if($Current[$i] -ceq $Generated[$j]){$lines+='  '+$Current[$i];$i++;$j++}
        elseif($table[($i+1),$j] -ge $table[$i,($j+1)]){$lines+='- '+$Current[$i];$i++}
        else{$lines+='+ '+$Generated[$j];$j++}
    }
    while($i -lt $n){$lines+='- '+$Current[$i];$i++}
    while($j -lt $m){$lines+='+ '+$Generated[$j];$j++}
    $lines
}
# Guided resolution of a managed block edited by hand in an opted-in repository file (#484). Preview by default: shows the diff and what each
# resolution would do. -Apply with -Resolution: Generated restores the generated block; Preserve restores it and keeps the lines added by hand
# as ordinary text after it. In both cases the previous file is backed up (also when the tracked file has uncommitted changes) and the previous block is returned.
function Invoke-SBRepositoryBlockResolve {
    param($Config,[string]$Repository,[string]$File,[ValidateSet('','Generated','Preserve')][string]$Resolution='',[switch]$Apply,[string]$SessionId)
    if($Apply -and !$Resolution){throw (New-SBError 'portable.resolve.resolution')}
    $lock=Enter-SBOperation $Config $SessionId -ReadOnly:(!$Apply)
    try{
        $full=try{[IO.Path]::GetFullPath($Repository)}catch{''}
        $scoped=@($Config.bindings|Where-Object {$_.identity -ceq $Repository -or ($full -and $_.path -ieq $full)})
        if($scoped.Count -ne 1){throw (New-SBError 'portable.resolve.target' @($Repository))}
        $binding=$scoped[0]
        $files=@(Get-SBBindingRepositoryFiles $binding)
        if($File){
            $files=@($files|Where-Object {$_ -ieq $File})
            if(!$files.Count){throw (New-SBError 'portable.resolve.file' @($File))}
        }
        $revision=Get-SBApprovedDirectiveRevision $Config.brainRoot
        if(!$revision){throw (New-SBError 'portable.resolve.global')}
        $stateRoot=if($Config.ContainsKey('localStateRoot')){$Config.localStateRoot}else{$Config.runtimeRoot}
        $stateBackups=if($Config.ContainsKey('localStateBackupRoot')){$Config.localStateBackupRoot}else{$Config.backupRoot}
        $statePath=Join-Path $stateRoot 'state.json'
        $state=Read-SBJson $statePath $null
        if($null -eq $state -and $stateRoot -ine $Config.runtimeRoot){$state=Read-SBJson (Join-Path $Config.runtimeRoot 'state.json') $null}
        if($null -eq $state){$state=@{schemaVersion=1;managed=@{};dossierMap=@{}}}
        $dossier=$binding.dossier
        if($stateRoot -ine $Config.runtimeRoot){
            $areas=@(Get-SBParaEntities $Config.brainRoot @()|Where-Object {(Test-SBRepoDossier $_) -and !$_.archived -and $_.status -eq 'active' -and $_.repository -ceq $binding.identity})
            if($areas.Count -ne 1){throw (New-SBError 'portable.dossier.identity')}
            $dossier=$areas[0].path
        }
        $dir=Resolve-SBParaPath $Config.brainRoot $dossier
        $items=@();$changed=$false
        foreach($name in $files){
            $path=Join-Path $binding.path $name
            $id=if($name -ceq 'AGENTS.md'){'repository'}else{'pointer'}
            $body=if($id -ceq 'repository'){New-SBPortableRepositoryBody $revision $Config.brainRoot $dir}else{'@AGENTS.md'}
            $wanted="<!-- secondbrain:${id}:begin -->`n"+$body.Trim()+"`n<!-- secondbrain:${id}:end -->"
            $key=[IO.Path]::GetFullPath($path)+'|'+$id
            if((Get-SBFileHash $path) -eq 'absent'){$items+=@{file=$name;status='absent'};continue}
            $text=Read-SBText $path
            $raw=Get-SBManagedContent $text $id
            if($null -eq $raw){$items+=@{file=$name;status='no-block'};continue}
            if($id -ceq 'repository' -and !$state.managed.ContainsKey($key) -and $binding.managedHash -ne 'absent'){$state.managed[$key]=$binding.managedHash}
            $probe=@{}+$state.managed
            $status=Set-SBManagedContent $path $body $id $probe $true $stateBackups -AfterTitle:($id -ceq 'repository')
            if($status -ne 'conflict'){$items+=@{file=$name;status=$status};continue}
            $current=$raw.Replace("`r`n","`n")
            $diff=@(Get-SBLineDiff @($current -split "`n") @($wanted -split "`n"))
            $item=@{file=$name;status='conflict';diff=$diff;previousBlock=$current;generatedBlock=$wanted
                resolutions=@{Generated=(Get-SBMessage 'portable.resolve.generated');Preserve=(Get-SBMessage 'portable.resolve.preserve')}}
            if($Apply){
                $kept=@($diff|Where-Object {$_.StartsWith('- ') -and $_ -notmatch '^- <!-- secondbrain:'}|ForEach-Object {$_.Substring(2)})
                $replacement=$wanted
                if($Resolution -ceq 'Preserve' -and ($kept -join '').Trim()){$replacement=$wanted+"`n`n"+($kept -join "`n").TrimEnd()}
                $updated=$text.Replace($raw,$replacement)
                [void](Write-SBFile $path ([Text.Encoding]::UTF8.GetBytes($updated)) (Get-SBFileHash $path) $stateBackups -BackupDirty)
                $state.managed[$key]=Get-SBTextHash $wanted
                $item.status='resolved';$item.resolution=$Resolution;$changed=$true
            }
            $items+=$item
        }
        if($changed){Write-SBFile $statePath ([Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $state))) (Get-SBFileHash $statePath) $stateBackups|Out-Null}
        @{schemaVersion=1;repository=[string]$binding.identity;path=[string]$binding.path;applied=$changed;resolution=$Resolution;files=$items;conflicts=@($items|Where-Object {$_.status -in @('conflict')}).Count}
    }finally{Exit-SBOperation $lock}
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
        $stateRoot=if($Config.ContainsKey('localStateRoot')){$Config.localStateRoot}else{$Config.runtimeRoot}
        $stateBackups=if($Config.ContainsKey('localStateBackupRoot')){$Config.localStateBackupRoot}else{$Config.backupRoot}
        $externalState=$stateRoot -ine $Config.runtimeRoot
        $issues=@();$changes=@();$statePath=Join-Path $stateRoot 'state.json'
        $state=Read-SBJson $statePath $null
        if($null -eq $state -and $externalState){$state=Read-SBJson (Join-Path $Config.runtimeRoot 'state.json') $null}
        if($null -eq $state){$state=@{schemaVersion=1;managed=@{};dossierMap=@{}}}
        $entities=@(Get-SBParaEntities $Config.brainRoot @())
        $observations=@()
        if($ObservationPath){$receipt=Read-SBJson (Assert-SBCentralDataPath $Config.brainRoot $ObservationPath) $null;if(!$receipt -or $receipt.schemaVersion -ne 1){throw (New-SBError 'portable.observations.invalid')};$observations=@($receipt.observations)}
        $mcpToolNames=@()
        if($Check -and !$Repository -and $ObservationPath){
            $mcpToolNames=@(Get-SBMcpKnowledgeToolNames)+@('check_publication')
        }
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
                $dossier=$binding.dossier
                if($externalState){
                    $areas=@($entities|Where-Object {(Test-SBRepoDossier $_) -and !$_.archived -and $_.status -eq 'active' -and $_.repository -ceq $binding.identity})
                    if($areas.Count -ne 1){throw (New-SBError 'portable.dossier.identity')}
                    $dossier=$areas[0].path
                }
                $dir=Resolve-SBParaPath $Config.brainRoot $dossier
                $record=Read-SBJson (Join-Path $dir 'repository.json') $null
                if(!$record -or $record.identity -cne $binding.identity){throw (New-SBError 'portable.dossier.identity')}
                if((Get-SBRepositoryLifecycle $dir) -eq 'greenfield'){foreach($reason in @(Get-SBGreenfieldViolations $Config $binding $dir)){$issues+=@{kind='greenfield-violation';repository=$binding.identity;reason=$reason}}}
                $toc=Get-SBDossierTOC $dir $Config.brainRoot;$path=Join-Path $dir 'index.md'
                $tocHash=Get-SBFileHash $path
                if($tocHash -ne (Get-SBTextHash $toc)){
                    if($Check){$issues+=@{kind='toc-pending';repository=$binding.identity}}
                    else{Write-SBFile $path ([Text.Encoding]::UTF8.GetBytes($toc)) $tocHash $Config.backupRoot -Recoverable|Out-Null;$changes+='toc:'+ $binding.identity}
                }
                $historyIndex=Get-SBDossierHistoryIndex $dir;$historyPath=Join-Path $dir 'history/index.md'
                $historyHash=Get-SBFileHash $historyPath
                if($historyHash -ne (Get-SBTextHash $historyIndex)){
                    if($Check){$issues+=@{kind='history-index-pending';repository=$binding.identity}}
                    else{Write-SBFile $historyPath ([Text.Encoding]::UTF8.GetBytes($historyIndex)) $historyHash $Config.backupRoot -Recoverable|Out-Null}
                }
                # Agent view of memory.md (derived file): generated by Sync and verified by Check, like the index.
                $memorySource=Join-Path $dir 'memory.md'
                if([IO.File]::Exists($memorySource)){
                    if($Check){
                        $inactive=@([regex]::Matches((Remove-SBPrivateText (Read-SBText $memorySource)),'<!-- sb:decision id=([^ ]+) state=(?:superseded|expired)(?: [^>]+)? -->')|ForEach-Object {$_.Groups[1].Value})
                        if($inactive.Count){$compactionAdvice+=@{kind='decisions-inactive';repository=$binding.identity;decisionIds=$inactive;reason=(Get-SBMessage 'portable.issue.decisions')}}
                    }
                    $agentView=ConvertTo-SBAgentMemoryView (Read-SBText $memorySource);$viewFile=Join-Path $dir 'memory.agent.md'
                    $viewHash=Get-SBFileHash $viewFile
                    if($viewHash -ne (Get-SBTextHash $agentView)){
                        if($Check){$issues+=@{kind='agent-view-pending';repository=$binding.identity}}
                        else{Write-SBFile $viewFile ([Text.Encoding]::UTF8.GetBytes($agentView)) $viewHash $Config.backupRoot -Recoverable|Out-Null;$changes+='agent-view:'+$binding.identity}
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
                $startup=Get-SBStartupContext -BrainRoot $Config.brainRoot -Dossier $dir -CheckoutPath $binding.path -Entities $entities -Budget $budget -Profile Slim -DirectiveCheckout $binding.path
                if(!$startup.withinBudget){$issues+=@{kind='compaction-required';repository=$binding.identity;characters=$startup.characters;budget=$budget}}
                elseif($startup.compacted){$compactionAdvice+=@{kind='startup-compacted';repository=$binding.identity;characters=$startup.characters;uncompactedCharacters=$startup.uncompactedCharacters;budget=$budget}}
                else{
                    # Soft threshold (near the limit or many turns since compaction): warning only; does not make the check unaligned.
                    $advice=Get-SBCompactionAdvice $startup $Config.brainRoot $dir
                    if($advice.level -eq 'soft'){$compactionAdvice+=@{kind='compaction-advised';repository=$binding.identity;characters=$advice.characters;budget=$advice.budget;percent=$advice.percent;turnsSinceCompaction=$advice.turnsSinceCompaction;reason=(Get-SBMessage 'portable.issue.compaction')}}
                }
                # Zero footprint (#484): only the files the binding explicitly lists are written; no other file of the checkout is touched.
                $repositoryFiles=@(Get-SBBindingRepositoryFiles $binding)
                if($global -and 'AGENTS.md' -in $repositoryFiles){
                    $agents=Join-Path $binding.path 'AGENTS.md';$key=[IO.Path]::GetFullPath($agents)+'|repository'
                    if(!$state.managed.ContainsKey($key) -and $binding.managedHash -ne 'absent'){$state.managed[$key]=$binding.managedHash}
                    $result=Set-SBManagedContent $agents (New-SBPortableRepositoryBody (Get-SBApprovedDirectiveRevision $Config.brainRoot) $Config.brainRoot $dir) 'repository' $state.managed $Check $stateBackups -AfterTitle
                    if($result -eq 'conflict'){$issues+=@{kind='directive-conflict';repository=$binding.identity}}
                    elseif($result -eq 'pending'){$issues+=@{kind='directive-pending';repository=$binding.identity}}
                    elseif($result -eq 'updated'){$changes+='directive:'+ $binding.identity}
                    foreach($pointer in @(Set-SBRepositoryPointers $binding.path $state.managed $Check $stateBackups -Files $repositoryFiles)){
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
            $globalPath=Join-Path $stateRoot 'istruzioni-globali.md'
            $globalHash=Get-SBFileHash $globalPath
            if($globalHash -ne (Get-SBTextHash $global)){
                if($Check){$issues+=@{kind='global-text-pending'}}else{Write-SBFile $globalPath ([Text.Encoding]::UTF8.GetBytes($global)) $globalHash $stateBackups -Recoverable|Out-Null}
            }
            if(!$state.ContainsKey('ideContext')){$state.ideContext=@{}}
            foreach($ide in $Config.ides){
                # Profile, configuration root or configuration folders changed since activation: instructions may no longer be loaded.
                $contextState=Get-SBIDEContextState $ide $state
                if($contextState.status -eq 'unrecorded' -and !$Check -and $contextState.current){$state.ideContext[[string]$ide.id]=$contextState.current}
                elseif($contextState.status -eq 'changed'){$issues+=@{kind='ide-context-changed';ide=$ide.name;reason=(Get-SBMessage 'portable.issue.idecontext')}}
                $observed=Test-SBIDEObservation $ide (Get-SBTextHash $global.Trim()) $observations $Config.brainRoot $Config.workstationId
                if($mcpToolNames.Count -and $script:SBPortableMcpTargets.ContainsKey($ide.name)){
                    $mcpObservations=@($observations|Where-Object {$_ -is [System.Collections.IDictionary] -and $_['ideId'] -ceq $ide.id})
                    if($mcpObservations.Count){
                        $consent=$mcpObservations[0]['mcpConsent']
                        if(!$observed -or $contextState.status -eq 'changed' -or $mcpObservations[0]['evidenceSha256'] -notmatch '^[0-9a-fA-F]{64}$' -or
                           $consent -isnot [System.Collections.IDictionary] -or $consent['tool'] -cnotin $mcpToolNames -or
                           $consent['outcome'] -cnotin @('popup-shown','no-popup')){
                            $issues+=@{kind='mcp-consent-unverified';ide=$ide.name;id=$ide.id;reason=(Get-SBMessage 'portable.issue.mcpconsent')}
                        }
                    }
                }
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
                $result=Set-SBManagedContent $ide.instructions $global.Trim() 'global' $state.managed $Check $stateBackups -InstallBackupRoot (Join-Path $stateRoot 'install-backups')
                if($result -in @('conflict','pending')){$issues+=@{kind=('ide-'+$result);ide=$ide.name}}
                # File deployment never certifies the identity of an account or loaded session.
                if(!$observed){$issues+=@{kind='ide-loading-unverified';ide=$ide.name}}
            }
        }
        if(!$Check -and $Repository){
            Write-SBFile $statePath ([Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $state))) (Get-SBFileHash $statePath) $stateBackups|Out-Null
        }
        if(!$Check -and !$Repository){
            $inventory=@{schemaVersion=1;workstationId=$Config.workstationId;repositories=$Config.bindings;ides=$Config.ides;coverage='approved-associations; use Check for current verification'}
            $inventoryPath=Join-Path $stateRoot 'inventory.json'
            Write-SBFile $inventoryPath ([Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $inventory))) (Get-SBFileHash $inventoryPath) $stateBackups|Out-Null
            Write-SBFile $statePath ([Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $state))) (Get-SBFileHash $statePath) $stateBackups|Out-Null
            $map=@{schemaVersion=1;workstationId=$Config.workstationId;ides=@($Config.ides|ForEach-Object {$entry=@{};foreach($key in $_.Keys){$entry[$key]=$_[$key]};$entry.writeScope=Get-SBIDEWriteScope $_;$entry})}
            $mapPath=Join-Path $stateRoot 'ide-map.json';Write-SBFile $mapPath ([Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $map))) (Get-SBFileHash $mapPath) $stateBackups -Recoverable|Out-Null
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
        # Environmental findings (live loading, account, consent, write scope, source freshness, compaction) cannot be fixed by editing files: they are reported apart and never make `aligned` false (#496).
        $environmentKinds=@('ide-loading-unverified','account-unverified','ide-context-changed','ide-directive-stale','mcp-consent-unverified','authoritative-source','compaction-required')
        $environment=@($issues|Where-Object {$_.kind -in $environmentKinds -or $_.kind -like 'ide-write-scope-*'})
        $issues=@($issues|Where-Object {$_.kind -notin $environmentKinds -and $_.kind -notlike 'ide-write-scope-*'})
        # Reads do not block writers: an active writer or pending transaction makes the snapshot potentially intermediate.
        $warnings=@($compactionAdvice)+@($closureWarnings)
        if($lock.concurrentWriter){$warnings+=@{kind='concurrent-writer';reason=(Get-SBMessage 'portable.issue.writer')}}
        $pendingTransaction=if($lock.pendingTransaction){$lock.pendingTransaction}elseif($Config.ContainsKey('pendingTransaction')){$Config.pendingTransaction}else{$null}
        if($pendingTransaction){$warnings+=@{kind='pending-transaction';reason=(Format-SBPendingTransaction $pendingTransaction)}}
        @{schemaVersion=1;workstationId=$Config.workstationId;repositories=$Config.bindings.Count;changes=$changes;issues=$issues;environment=$environment;warnings=$warnings;aligned=(!$issues.Count);filesAligned=$filesAligned;liveLoadingVerified=$liveLoadingVerified;writesApplied=(!$Check);inventoryIsLocal=$true;scope=$(if($Repository){@{repository=$Repository;coverage='repository-only';notCovered=@('global-instructions','ides','curated-references','tracker-authority','tracker-imports','authoritative-sources','prompt-index','inventory','para-index')}}else{@{coverage='workstation'}})}
    }finally{Exit-SBOperation $lock}
}
Export-ModuleMember -Function @(
    'New-SBPortableConfiguration',
    'Get-SBPortableGlobal',
    'Read-SBAccountObservationReceipt',
    'Set-SBRepositoryPointers',
    'Invoke-SBHostActivation',
    'Get-SBSetupPaths',
    'Assert-SBIDEInstructionsPath',
    'Invoke-SBSetup',
    'Get-SBIDEContextState',
    'Get-SBSetupStatus',
    'Invoke-SBSetupUnbind',
    'ConvertTo-SBRepositoryFiles',
    'Get-SBBindingRepositoryFiles',
    'Invoke-SBRepositoryBlockResolve',
    'Invoke-SBPortableSync'
)
