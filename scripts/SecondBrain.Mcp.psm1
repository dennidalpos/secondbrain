#requires -Version 7.5
Set-StrictMode -Version Latest
$script:SBMcpConfigPath=$null
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Para.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Prompts.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Knowledge.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Tracker.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Publication.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Pending.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.McpWrites.psm1')
Add-SBMessages @{
    'mcp.title.preview_dossier_write' = @{it='Anteprima scrittura dossier';en='Preview dossier write'}
    'mcp.title.submit_dossier_write' = @{it='Invia scrittura approvata';en='Submit approved write'}
    'mcp.write.param.requestId' = @{it='ID idempotente della richiesta: 32 cifre esadecimali minuscole';en='Idempotent request ID: 32 lowercase hexadecimal characters'}
    'mcp.write.param.operation' = @{it='Operazione ristretta da preparare';en='Restricted operation to preview'}
    'mcp.write.param.payload' = @{it='Dati dell operazione: task.status (taskId,status,reason?), task.new (title,acceptance,provenance,description?,priority?,pointer?), memory.append (content), activity.append (taskId,sessionId,when,outcome,detail), history.save (path,content)';en='Operation data: task.status (taskId,status,reason?), task.new (title,acceptance,provenance,description?,priority?,pointer?), memory.append (content), activity.append (taskId,sessionId,when,outcome,detail), history.save (path,content)'}
    'mcp.write.param.planHash' = @{it='SHA-256 del piano esatto approvato tramite CLI';en='SHA-256 of the exact plan approved through the CLI'}
    'mcp.write.preview.description' = @{it='Prepara senza scrivere un piano per stato task, nuovo task, memoria, attività o history. Richiede checkout gestito, repository e ID richiesta esadecimale di 32 caratteri. Approvare il piano con mcp-write.ps1 prima di submit_dossier_write.';en='Previews a task status, new task, memory, activity or history write without persistence. Requires a managed checkout, repository and 32-character lowercase hex request ID. Approve the returned plan with mcp-write.ps1 before submit_dossier_write.'}
    'mcp.write.submit.description' = @{it='Verifica la ricevuta CLI locale del piano e accoda una sola richiesta idempotente con precondizioni hash. Nessuna approvazione viene accettata dal payload MCP. NoRecovery vieta nuovi invii; il registro attività resta soggetto alla procedura di attivazione.';en='Verifies the local CLI approval receipt and queues one idempotent request with hash preconditions. MCP arguments cannot grant approval. NoRecovery forbids submissions; activity logging still requires its activation procedure.'}
    'mcp.package.destination' = @{it='Scegliere una cartella nuova sotto .runtime: {0}';en='Choose a new folder under .runtime: {0}'}
    'mcp.pending.disabled' = @{it='Consultazione senza recupero delle scritture pendenti per questa sessione o richiesta.';en='Consultation without pending-write recovery for this session or request.'}
    'mcp.description.noRecovery' = @{it='Non integrare scritture pendenti in questa chiamata; usare -NoRecovery all avvio del server per disabilitare anche il recupero iniziale';en='Skip pending-write recovery for this call; start the server with -NoRecovery to disable startup recovery too'}
    'mcp.title.get_startup_context' = @{ it = 'Contesto iniziale'; en = 'Startup context' }
    'mcp.title.get_ready_tasks' = @{ it = 'Attività pronte'; en = 'Ready tasks' }
    'mcp.title.get_task' = @{ it = 'Dettaglio attività'; en = 'Task details' }
    'mcp.title.search_knowledge' = @{ it = 'Cerca nella conoscenza'; en = 'Search knowledge' }
    'mcp.title.list_prompts' = @{ it = 'Elenco prompt'; en = 'List prompts' }
    'mcp.title.get_prompt_home' = @{ it = 'Menu dei prompt'; en = 'Prompt home' }
    'mcp.title.get_prompt' = @{ it = 'Scheda prompt'; en = 'Prompt card' }
    'mcp.title.check_publication' = @{ it = 'Verifica pubblicabilità'; en = 'Publication check' }
    'mcp.pending.contract' = @{it='All avvio e durante le letture integra scritture di dossier gia autorizzate e accodate, senza attendere il lock; puo quindi modificare dati locali.';en='At startup and during reads, applies previously authorized queued dossier writes without waiting for the lock; it can therefore modify local data.'}
    'mcp.json.parse' = @{ it = 'Errore di parsing: {0}'; en = 'Parse error: {0}' }
    'mcp.json.request' = @{ it = 'Richiesta non valida: jsonrpc deve essere 2.0'; en = 'Invalid Request: jsonrpc must be 2.0' }
    'mcp.json.method' = @{ it = 'Metodo non trovato: {0}'; en = 'Method not found: {0}' }
    'mcp.json.internal' = @{ it = 'Errore interno: {0}'; en = 'Internal error: {0}' }
    'mcp.description.get_startup_context' = @{ it = 'Restituisce il contesto di avvio del repository o dossier. Slim (default, 30000 caratteri): indice, contesto e memoria essenziali, soli task selezionati e riferimenti ai livelli non caricati. Full: contesto completo senza tetto. Una revisione invariata non ripete le parti.'; en = 'Return repository or dossier startup context. Slim (default, 30000 characters): index, essential context and memory, selected tasks only and omitted-layer references. Full: complete context without a limit. An unchanged revision does not repeat parts.' }
    'mcp.description.get_startup_context.repository' = @{ it = 'Identificatore del repository (es. github.com/example-user/secondbrain); default: checkout in lavoro'; en = 'Repository identity (e.g. github.com/example-user/secondbrain); defaults to the working checkout' }
    'mcp.description.get_startup_context.checkoutPath' = @{ it = 'Percorso del checkout in lavoro da cui risolvere il repository (opzionale)'; en = 'Working checkout path used to resolve the repository (optional)' }
    'mcp.description.get_startup_context.dossier' = @{ it = 'Percorso relativo del dossier (es. 02-areas/products/SecondBrain)'; en = 'Relative dossier path (e.g. 02-areas/products/SecondBrain)' }
    'mcp.description.get_startup_context.readyOnly' = @{ it = 'Se true, filtra i task selezionati per dipendenze soddisfatte; Slim senza ID non include task'; en = 'If true, filter selected tasks by satisfied dependencies; Slim without IDs includes no tasks' }
    'mcp.description.get_startup_context.previousRevision' = @{it='Revisione ricevuta in precedenza; se invariata restituisce changed=false senza ripetere le parti';en='Previously received revision; if unchanged, returns changed=false without repeating parts'}
    'mcp.description.get_startup_context.taskIds' = @{ it = 'ID dei task attivi da includere'; en = 'IDs of active tasks to include' }
    'mcp.description.get_startup_context.profile' = @{ it = 'slim (predefinito): parti essenziali entro 30000 caratteri, solo per il primo caricamento; full: contesto completo, senza tetto'; en = 'slim (default): essential parts within 30000 characters for initial loading only; full: complete context without a limit' }
    'mcp.description.get_startup_context.budget' = @{ it = 'Budget caratteri massimo (default: 30000 con slim, nessun tetto con full)'; en = 'Maximum character budget (default: 30000 for slim, unlimited for full)' }
    'mcp.description.get_ready_tasks' = @{ it = 'Restituisce i task pronti con dipendenze soddisfatte (proiezione -ReadyOnly) del repository in lavoro (risolto dal checkout corrente o da repository/checkoutPath). La vista globale richiede all=true.'; en = 'Return ready tasks with satisfied dependencies for the working repository, resolved from the current checkout or repository/checkoutPath. The global view requires all=true.' }
    'mcp.description.get_ready_tasks.repository' = @{ it = 'Identificatore del repository (opzionale; default: checkout in lavoro)'; en = 'Repository identity (optional; defaults to the working checkout)' }
    'mcp.description.get_ready_tasks.checkoutPath' = @{ it = 'Percorso del checkout in lavoro da cui risolvere il repository (opzionale)'; en = 'Working checkout path used to resolve the repository (optional)' }
    'mcp.description.get_ready_tasks.all' = @{ it = 'Se true, vista globale di tutti i repository (opt-in esplicito)'; en = 'If true, show all repositories globally (explicit opt-in)' }
    'mcp.description.get_ready_tasks.includeAcceptance' = @{ it = 'Se true, include i criteri di accettazione dei task'; en = 'If true, include task acceptance criteria' }
    'mcp.description.get_ready_tasks.offset' = @{ it = 'Solo con all=true: task da saltare (paginazione)'; en = 'Only with all=true: tasks to skip (pagination)' }
    'mcp.description.get_ready_tasks.limit' = @{ it = 'Solo con all=true: task per pagina (default 50; 0 = tutti)'; en = 'Only with all=true: tasks per page (default 50; 0 = all)' }
    'mcp.description.get_task' = @{ it = 'Restituisce il dettaglio integro di un task (descrizione, criteri di accettazione, evidenze, provenienza) per id o numero seq, dal tracker attivo o dall''archivio del dossier. Serve per i task che il profilo slim mostra solo in forma breve.'; en = 'Return complete task details (description, acceptance criteria, evidence and provenance) by ID or sequence number from the active tracker or dossier archive. Use for tasks shown briefly by the slim profile.' }
    'mcp.description.get_task.task' = @{ it = 'ID del task (es. SB-SIMP-QUEUE-20261101) oppure numero seq (es. 197 o #197)'; en = 'Task ID (e.g. SB-SIMP-QUEUE-20261101) or sequence number (e.g. 197 or #197)' }
    'mcp.description.get_task.repository' = @{ it = 'Identificatore del repository (opzionale; default: checkout in lavoro)'; en = 'Repository identity (optional; defaults to the working checkout)' }
    'mcp.description.get_task.checkoutPath' = @{ it = 'Percorso del checkout in lavoro da cui risolvere il repository (opzionale)'; en = 'Working checkout path used to resolve the repository (optional)' }
    'mcp.description.get_task.dossier' = @{ it = 'Percorso relativo del dossier (opzionale)'; en = 'Relative dossier path (optional)' }
    'mcp.description.search_knowledge' = @{ it = 'Cerca nei file di conoscenza del dossier del repository in lavoro (context.md, memory.md, tracker.json, archivio tracker, rapporti dei lotti). Predefiniti: 20 riscontri e 10000 caratteri; se hasMore=true richiamare con offset=nextOffset. limit=0 o budget=0 tolgono il tetto (sconsigliato). allDossiers=true cerca in tutte le aree; includeOriginals=true include gli originali compattati. mode=literal (predefinito): sottostringa esatta; mode=relevance: più termini ordinati per pertinenza, con score e section.'; en = 'Search knowledge files for the working repository (context, memory, tracker, tracker archive and batch reports). Defaults: 20 matches and 10000 characters; continue with nextOffset when hasMore=true. limit=0 or budget=0 removes the limit (discouraged). allDossiers=true searches all active dossiers; includeOriginals=true includes compacted originals. mode=literal (default): exact substring; mode=relevance: multiple terms ranked by relevance, with score and section.' }
    'mcp.description.search_knowledge.query' = @{ it = 'Termine o frase da cercare nei dossier'; en = 'Term or phrase to search for in dossiers' }
    'mcp.description.search_knowledge.budget' = @{ it = 'Tetto di caratteri (default 10000; 0 = nessun tetto)'; en = 'Character limit (default 10000; 0 = unlimited)' }
    'mcp.description.search_knowledge.allDossiers' = @{ it = 'Se true, cerca in tutte le aree attive invece che nel repository in lavoro'; en = 'If true, search all active areas instead of the working repository' }
    'mcp.description.search_knowledge.includeOriginals' = @{ it = 'Se true, include gli originali compattati (history/compaction)'; en = 'If true, include compacted originals (history/compaction)' }
    'mcp.description.search_knowledge.dossier' = @{ it = 'Percorso relativo di un dossier specifico (opzionale)'; en = 'Relative path of a specific dossier (optional)' }
    'mcp.description.search_knowledge.repository' = @{ it = 'Identificatore del repository per selezionare il dossier'; en = 'Repository identity used to select the dossier' }
    'mcp.description.search_knowledge.mode' = @{ it = 'literal (predefinito): sottostringa esatta; relevance: termini multipli ordinati per pertinenza'; en = 'literal (default): exact substring; relevance: multiple terms ranked by relevance' }
    'mcp.description.search_knowledge.offset' = @{ it = 'Numero di riscontri da saltare (paginazione, default 0)'; en = 'Matches to skip (pagination, default 0)' }
    'mcp.description.search_knowledge.limit' = @{ it = 'Numero massimo di riscontri (default 20; 0 = tutti)'; en = 'Maximum matches (default 20; 0 = all)' }
    'mcp.description.list_prompts' = @{ it = 'Elenca il catalogo unico dei prompt (ingegneria e manutenzione di SecondBrain), per area tematica. Ogni voce ha l''icona di modalità. Con compact=true una riga per prompt (codice, modalità, sommario): riportare l''elenco integrale, senza riassumerlo.'; en = 'List the single prompt catalog (engineering and SecondBrain maintenance) by category. Each entry has a mode icon. compact=true returns one line per prompt (code, mode, summary): report the complete list without summarizing.' }
    'mcp.description.list_prompts.category' = @{ it = 'Filtra per area: id (system, test, governance...) o prefisso dei codici (SYS, TST, GOV...), senza distinguere le maiuscole'; en = 'Filter by category ID (system, test, governance...) or code prefix (SYS, TST, GOV...), case-insensitive' }
    'mcp.description.list_prompts.compact' = @{ it = 'Se true, una riga per prompt invece della scheda sintetica'; en = 'If true, return one line per prompt instead of its summary card' }
    'mcp.description.list_prompts.language' = @{ it = 'Lingua del testo (en o it); predefinito: lingua della postazione'; en = 'Text language (en or it); defaults to the workstation language' }
    'mcp.description.get_prompt_home' = @{ it = 'Schermata iniziale di `sb prompt`: link al catalogo completo, tabella dei comandi sb (chat) con l''equivalente da script. Con repositoryPath (checkout corrente) aggiunge stato, prossimo passo e flusso per prodotto.'; en = 'Initial sb prompt screen: full catalog link and sb chat commands with script equivalents. repositoryPath (working checkout) adds current state, next step and product workflow.' }
    'mcp.description.get_prompt_home.repositoryPath' = @{ it = 'Percorso del checkout corrente; facoltativo'; en = 'Working checkout path (optional)' }
    'mcp.description.get_prompt_home.language' = @{ it = 'Lingua del testo (en o it); predefinito: lingua della postazione'; en = 'Text language (en or it); defaults to the workstation language' }
    'mcp.description.get_prompt' = @{ it = 'Restituisce il prompt composto (ruolo, procedura, vincoli, criteri di uscita, formato di output) per un codice o ID (es. SYS03, SEC07, DEV01); con objective indica l''obiettivo. Senza contesto di repository.'; en = 'Return the composed prompt (role, procedure, constraints, exit criteria, output format) for a code or ID (e.g. SYS03, SEC07, DEV01); objective sets the goal. No repository context.' }
    'mcp.description.get_prompt.prompt' = @{ it = 'Codice (SYS03, COM01...), ID immutabile (pmt-...) o alias del prompt'; en = 'Code (SYS03, COM01...), immutable ID (pmt-...) or prompt alias' }
    'mcp.description.get_prompt.language' = @{ it = 'Lingua del testo (en o it); predefinito: lingua della postazione'; en = 'Text language (en or it); defaults to the workstation language' }
    'mcp.description.check_publication' = @{ it = 'Esegue una verifica di sola lettura della pubblicabilità del working tree, indice e storia del repository specificato. Restituisce un riepilogo (conteggi per regola e primi 20 riscontri); detail=true il rapporto integro.'; en = 'Read-only publication check of the specified Git working tree, index and history. Returns a summary (counts by rule and the first 20 findings); detail=true returns the complete report.' }
    'mcp.description.check_publication.repositoryPath' = @{ it = 'Percorso della radice o checkout del repository Git da verificare'; en = 'Git repository root or checkout path to check' }
    'mcp.description.check_publication.detail' = @{ it = 'Se true, rapporto integro (tutti i riscontri e i riferimenti esclusi)'; en = 'If true, return the complete report (all findings and excluded references)' }
    'mcp.prompt.objective' = @{ it = 'Obiettivo opzionale dell''attività'; en = 'Optional task objective' }
    'mcp.resource.catalog' = @{ it = 'Catalogo Prompt e Workflow SecondBrain'; en = 'SecondBrain Prompt and Workflow Catalog' }
    'mcp.tool.failed' = @{ it = 'Errore durante l''esecuzione dello strumento {0}: {1}'; en = 'Error executing tool {0}: {1}' }
    'mcp.notice' = @{ it = 'Avviso: {0}'; en = 'Warning: {0}' }
    'mcp.package.root' = @{ it = 'Impossibile trovare scripts/mcp-server.ps1 nella radice SecondBrain: {0}'; en = 'Cannot find scripts/mcp-server.ps1 in SecondBrain root: {0}' }
    'mcp.package.applying' = @{ it = 'Applicazione configurazione MCP SecondBrain a tutti gli IDE...'; en = 'Applying SecondBrain MCP configuration to all IDEs...' }
    'mcp.repository.unresolved' = @{ it = 'Repository in lavoro non risolvibile: indicare repository o checkoutPath (oppure all=true per la vista globale)'; en = 'Working repository not resolvable: give repository or checkoutPath (or all=true for the global view)' }
    'mcp.profile.invalid' = @{ it = 'Profilo non valido: usare slim o full'; en = 'Invalid profile: use slim or full' }
    'mcp.params.conflict' = @{ it = 'Parametri incompatibili: all e repository'; en = 'Incompatible parameters: all and repository' }
    'mcp.paging.invalid' = @{ it = 'offset e limit devono essere interi non negativi'; en = 'offset and limit must be non-negative integers' }
    'mcp.task.required' = @{ it = 'Il parametro task è obbligatorio per get_task'; en = 'The task parameter is required for get_task' }
    'mcp.query.required' = @{ it = 'Il parametro query è obbligatorio per search_knowledge'; en = 'The query parameter is required for search_knowledge' }
    'mcp.mode.invalid' = @{ it = 'Modalità non valida: usare literal o relevance'; en = 'Invalid mode: use literal or relevance' }
    'mcp.search.invalid' = @{ it = 'offset, limit e budget devono essere interi non negativi'; en = 'offset, limit and budget must be non-negative integers' }
    'mcp.startup.invalid' = @{ it = 'budget deve essere un intero non negativo e taskIds un array di ID'; en = 'budget must be a non-negative integer and taskIds an array of IDs' }
    'mcp.prompt.required' = @{ it = 'Il parametro prompt è obbligatorio per get_prompt'; en = 'The prompt parameter is required for get_prompt' }
    'mcp.path.required' = @{ it = 'Il parametro repositoryPath è obbligatorio per check_publication'; en = 'The repositoryPath parameter is required for check_publication' }
    'mcp.tool.deprecated' = @{ it = 'Alias deprecato {0}: usare {1}. Lʼalias sarà rimosso in una versione futura.'; en = 'Deprecated alias {0}: use {1}. The alias will be removed in a future version.' }
    'mcp.language.invalid' = @{ it = 'Lingua non valida: usare en o it'; en = 'Invalid language: use en or it' }
    'mcp.tool.unknown' = @{ it = 'Strumento sconosciuto: {0}'; en = 'Unknown tool: {0}' }
    'mcp.resource.notfound' = @{ it = 'Risorsa non trovata: {0}'; en = 'Resource not found: {0}' }
    'mcp.pair.scope' = @{ it = 'Ambito non supportato per {0}: {1}'; en = 'Unsupported scope for {0}: {1}' }
    'mcp.pair.workspace' = @{ it = 'Il target {0} richiede -WorkspacePath (cartella del progetto): nessuna scrittura.'; en = 'Target {0} requires -WorkspacePath (project folder): nothing written.' }
}

function ConvertTo-SBMcpJson($Value) {
    if ($null -eq $Value) { return $null }
    ConvertTo-SBStableValue $Value | ConvertTo-Json -Depth 40 -Compress
}

function Invoke-SBMcpPendingRecovery([string]$BrainRoot,[string]$ConfigPath) {
    $summary=$null
    # Storage diagnostics must never become stray lines on the JSON-RPC stdout channel.
    foreach($record in @(Invoke-SBPendingWrites -BrainRoot $BrainRoot -ConfigPath $ConfigPath *>&1)){
        if($record -is [Collections.IDictionary] -and $record.ContainsKey('pending') -and $record.ContainsKey('applied')){$summary=$record}
        else{[Console]::Error.WriteLine([string]$record)}
    }
    if($summary){return $summary}
    @{state='unavailable';applied=@();conflicts=@();pending=$null;errors=@(@{code='pending.recovery.no-result'})}
}

function Get-SBMcpToolDefinitions {
    $definitions=@(
        @{
            name = 'get_startup_context'
            description = (Get-SBMessage 'mcp.description.get_startup_context')
            inputSchema = @{
                type = 'object'
                properties = @{
                    repository = @{ type = 'string'; description = (Get-SBMessage 'mcp.description.get_startup_context.repository') }
                    checkoutPath = @{ type = 'string'; description = (Get-SBMessage 'mcp.description.get_startup_context.checkoutPath') }
                    dossier = @{ type = 'string'; description = (Get-SBMessage 'mcp.description.get_startup_context.dossier') }
                    readyOnly = @{ type = 'boolean'; description = (Get-SBMessage 'mcp.description.get_startup_context.readyOnly') }
                    profile = @{ type = 'string'; enum = @('slim', 'full'); description = (Get-SBMessage 'mcp.description.get_startup_context.profile') }
                    budget = @{ type = 'integer'; description = (Get-SBMessage 'mcp.description.get_startup_context.budget') }
                    taskIds = @{ type = 'array'; items = @{type='string'}; description = (Get-SBMessage 'mcp.description.get_startup_context.taskIds') }
                    previousRevision = @{type='string';description=(Get-SBMessage 'mcp.description.get_startup_context.previousRevision')}
                }
            }
        },
        @{
            name = 'get_ready_tasks'
            description = (Get-SBMessage 'mcp.description.get_ready_tasks')
            inputSchema = @{
                type = 'object'
                properties = @{
                    repository = @{ type = 'string'; description = (Get-SBMessage 'mcp.description.get_ready_tasks.repository') }
                    checkoutPath = @{ type = 'string'; description = (Get-SBMessage 'mcp.description.get_ready_tasks.checkoutPath') }
                    all = @{ type = 'boolean'; description = (Get-SBMessage 'mcp.description.get_ready_tasks.all') }
                    includeAcceptance = @{ type = 'boolean'; description = (Get-SBMessage 'mcp.description.get_ready_tasks.includeAcceptance') }
                    offset = @{ type = 'integer'; description = (Get-SBMessage 'mcp.description.get_ready_tasks.offset') }
                    limit = @{ type = 'integer'; description = (Get-SBMessage 'mcp.description.get_ready_tasks.limit') }
                }
            }
        },
        @{
            name = 'get_task'
            description = (Get-SBMessage 'mcp.description.get_task')
            inputSchema = @{
                type = 'object'
                required = @('task')
                properties = @{
                    task = @{ type = 'string'; description = (Get-SBMessage 'mcp.description.get_task.task') }
                    repository = @{ type = 'string'; description = (Get-SBMessage 'mcp.description.get_task.repository') }
                    checkoutPath = @{ type = 'string'; description = (Get-SBMessage 'mcp.description.get_task.checkoutPath') }
                    dossier = @{ type = 'string'; description = (Get-SBMessage 'mcp.description.get_task.dossier') }
                }
            }
        },
        @{
            name = 'search_knowledge'
            description = (Get-SBMessage 'mcp.description.search_knowledge')
            inputSchema = @{
                type = 'object'
                required = @('query')
                properties = @{
                    query = @{ type = 'string'; description = (Get-SBMessage 'mcp.description.search_knowledge.query') }
                    budget = @{ type = 'integer'; description = (Get-SBMessage 'mcp.description.search_knowledge.budget') }
                    allDossiers = @{ type = 'boolean'; description = (Get-SBMessage 'mcp.description.search_knowledge.allDossiers') }
                    includeOriginals = @{ type = 'boolean'; description = (Get-SBMessage 'mcp.description.search_knowledge.includeOriginals') }
                    dossier = @{ type = 'string'; description = (Get-SBMessage 'mcp.description.search_knowledge.dossier') }
                    repository = @{ type = 'string'; description = (Get-SBMessage 'mcp.description.search_knowledge.repository') }
                    mode = @{ type = 'string'; enum = @('literal', 'relevance'); description = (Get-SBMessage 'mcp.description.search_knowledge.mode') }
                    offset = @{ type = 'integer'; description = (Get-SBMessage 'mcp.description.search_knowledge.offset') }
                    limit = @{ type = 'integer'; description = (Get-SBMessage 'mcp.description.search_knowledge.limit') }
                }
            }
        },
        @{
            name = 'list_prompts'
            description = (Get-SBMessage 'mcp.description.list_prompts')
            inputSchema = @{
                type = 'object'
                properties = @{
                    category = @{ type = 'string'; description = (Get-SBMessage 'mcp.description.list_prompts.category') }
                    compact = @{ type = 'boolean'; description = (Get-SBMessage 'mcp.description.list_prompts.compact') }
                    language = @{ type = 'string'; enum = @('en', 'it'); description = (Get-SBMessage 'mcp.description.list_prompts.language') }
                }
            }
        },
        @{
            name = 'get_prompt_home'
            description = (Get-SBMessage 'mcp.description.get_prompt_home')
            inputSchema = @{
                type = 'object'
                properties = @{
                    repositoryPath = @{ type = 'string'; description = (Get-SBMessage 'mcp.description.get_prompt_home.repositoryPath') }
                    language = @{ type = 'string'; enum = @('en', 'it'); description = (Get-SBMessage 'mcp.description.get_prompt_home.language') }
                }
            }
        },
        @{
            name = 'get_prompt'
            description = (Get-SBMessage 'mcp.description.get_prompt')
            inputSchema = @{
                type = 'object'
                required = @('prompt')
                properties = @{
                    prompt = @{ type = 'string'; description = (Get-SBMessage 'mcp.description.get_prompt.prompt') }
                    objective = @{ type = 'string'; description = (Get-SBMessage 'mcp.prompt.objective') }
                    language = @{ type = 'string'; enum = @('en', 'it'); description = (Get-SBMessage 'mcp.description.get_prompt.language') }
                }
            }
        },
        @{
            name = 'check_publication'
            description = (Get-SBMessage 'mcp.description.check_publication')
            inputSchema = @{
                type = 'object'
                required = @('repositoryPath')
                properties = @{
                    repositoryPath = @{ type = 'string'; description = (Get-SBMessage 'mcp.description.check_publication.repositoryPath') }
                    detail = @{ type = 'boolean'; description = (Get-SBMessage 'mcp.description.check_publication.detail') }
                }
            }
        }
    )
    $scopeProperties=@{repository=@{type='string';description=(Get-SBMessage 'mcp.description.get_task.repository')};checkoutPath=@{type='string';description=(Get-SBMessage 'mcp.description.get_startup_context.checkoutPath')};requestId=@{type='string';pattern='^[a-f0-9]{32}$';description=(Get-SBMessage 'mcp.write.param.requestId')}}
    $previewProperties=@{}+$scopeProperties
    $previewProperties.operation=@{type='string';description=(Get-SBMessage 'mcp.write.param.operation');enum=@('task.status','task.new','memory.append','activity.append','history.save')}
    $previewProperties.payload=@{type='object';description=(Get-SBMessage 'mcp.write.param.payload')}
    $submitProperties=@{}+$scopeProperties
    $submitProperties.planHash=@{type='string';pattern='^[A-F0-9]{64}$';description=(Get-SBMessage 'mcp.write.param.planHash')}
    $definitions+=@(
        @{name='preview_dossier_write';description=(Get-SBMessage 'mcp.write.preview.description');inputSchema=@{type='object';additionalProperties=$false;required=@('repository','checkoutPath','requestId','operation','payload');properties=$previewProperties}}
        @{name='submit_dossier_write';description=(Get-SBMessage 'mcp.write.submit.description');inputSchema=@{type='object';additionalProperties=$false;required=@('repository','checkoutPath','requestId','planHash');properties=$submitProperties}}
    )
    foreach($definition in $definitions){
        $definition.inputSchema.properties.noRecovery=@{type='boolean';description=(Get-SBMessage 'mcp.description.noRecovery')}
        if($definition.name -notin @('preview_dossier_write','submit_dossier_write')){$definition.description+=' '+(Get-SBMessage 'mcp.pending.contract')}
        $definition.annotations=@{title=(Get-SBMessage ('mcp.title.'+$definition.name));readOnlyHint=$false;destructiveHint=$true;idempotentHint=$false;openWorldHint=$false}
        if($definition.name -in @('preview_dossier_write','submit_dossier_write')){
            $definition.annotations.idempotentHint=$true
            if($definition.name -eq 'preview_dossier_write'){$definition.annotations.readOnlyHint=$true;$definition.annotations.destructiveHint=$false}
        }
        $definition
    }
}


function Resolve-SBMcpRepository([string]$BrainRoot, $Arguments) {
    # Explicit repository, otherwise the working checkout's repository (checkoutPath argument or server current directory).
    if ($Arguments.ContainsKey('repository') -and $Arguments.repository) { return [string]$Arguments.repository }
    $checkout = if ($Arguments.ContainsKey('checkoutPath') -and $Arguments.checkoutPath) { [string]$Arguments.checkoutPath } else { '' }
    $bindings = @()
    try { $bindings = @((Read-SBConfiguration -ReadOnly).bindings) } catch { }
    $resolved = Resolve-SBWorkingRepository $checkout $bindings
    if (!$resolved) { throw (New-SBError 'mcp.repository.unresolved') }
    $resolved
}

# Historical aliases (secondbrain_ prefix) remain accepted by tools/call but are retired from tools/list: deprecated.
function Get-SBMcpDeprecatedToolAliases {
    [ordered]@{
        secondbrain_startup_context = 'get_startup_context'
        secondbrain_ready_tasks = 'get_ready_tasks'
        secondbrain_get_task = 'get_task'
        secondbrain_search = 'search_knowledge'
        secondbrain_list_prompts = 'list_prompts'
        secondbrain_prompt_home = 'get_prompt_home'
        secondbrain_get_prompt = 'get_prompt'
        secondbrain_check_publication = 'check_publication'
    }
}

function Get-SBMcpDeprecationNotice([string]$ToolName) {
    $aliases = Get-SBMcpDeprecatedToolAliases
    if ($aliases.Contains($ToolName)) { return (Get-SBMessage 'mcp.tool.deprecated' @($ToolName, $aliases[$ToolName])) }
    $null
}

function Invoke-SBMcpToolCall([string]$BrainRoot, [string]$ToolName, $Arguments) {
    if($BrainRoot.StartsWith('\\') -and ![IO.Directory]::Exists($BrainRoot)){throw (New-SBError 'access.brain.unreachable' @($BrainRoot))}
    if (!$Arguments) { $Arguments = @{} }
    $legacyAliases = Get-SBMcpDeprecatedToolAliases
    if ($legacyAliases.Contains($ToolName)) { $ToolName = $legacyAliases[$ToolName] }

    # Prompt language (en or it) applies only to prompt tools and only for the duration of the call.
    $previousLanguage = Get-SBWorkflowLanguageOverride
    if ($ToolName -in @('list_prompts', 'get_prompt_home', 'get_prompt') -and $Arguments.ContainsKey('language') -and $Arguments.language) {
        if ([string]$Arguments.language -notin @('en', 'it')) { throw (New-SBError 'mcp.language.invalid') }
        Set-SBWorkflowLanguage ([string]$Arguments.language)
    }
    try {
    switch ($ToolName) {
        'get_startup_context' {
            $startupProfile = if ($Arguments.ContainsKey('profile') -and $Arguments.profile) { [string]$Arguments.profile } else { 'slim' }
            if ($startupProfile -notin @('slim', 'full')) { throw (New-SBError 'mcp.profile.invalid') }
            $startupProfile = if ($startupProfile -eq 'full') { 'Full' } else { 'Slim' }
            # Limit only initial loading (slim); full is unlimited unless budget is explicit.
            $budgetDefault = if ($startupProfile -eq 'Slim') { Get-SBSlimStartupBudget } else { 0 }
            $budget=$budgetDefault
            if($Arguments.ContainsKey('budget') -and ![int]::TryParse([string]$Arguments.budget,[ref]$budget)){throw (New-SBError 'mcp.startup.invalid')}
            $taskIds=@()
            if($Arguments.ContainsKey('taskIds')){
                if($Arguments.taskIds -isnot [array] -or @($Arguments.taskIds|Where-Object {$_ -isnot [string] -or !$_}).Count){throw (New-SBError 'mcp.startup.invalid')}
                $taskIds=@($Arguments.taskIds)
            }
            if($budget -lt 0){throw (New-SBError 'mcp.startup.invalid')}
            $readyOnly = if ($Arguments.ContainsKey('readyOnly')) { [bool]$Arguments.readyOnly } else { $false }
            $dossier = if ($Arguments.ContainsKey('dossier')) { [string]$Arguments.dossier } else { $null }

            if (!$dossier) {
                # Never default to the brain repository: the dossier follows the explicit repository or working checkout.
                $repo = Resolve-SBMcpRepository $BrainRoot $Arguments
                $dossier = Resolve-SBWorkingDossier $BrainRoot $repo
            }
            $dossierPath = if ([IO.Path]::IsPathRooted($dossier)) { $dossier } else { Join-Path $BrainRoot $dossier }

            if($Arguments.ContainsKey('previousRevision') -and $Arguments.previousRevision -isnot [string]){throw (New-SBError 'mcp.startup.invalid')}
            $previousRevision=if($Arguments.ContainsKey('previousRevision')){$Arguments.previousRevision}else{''}
            $ctx = Get-SBStartupContext -BrainRoot $BrainRoot -Dossier $dossierPath -Budget $budget -ReadyOnly:$readyOnly -TaskIds $taskIds -Profile $startupProfile -PreviousRevision $previousRevision
            return ConvertTo-SBMcpJson $ctx
        }
        'get_ready_tasks' {
            $all = $Arguments.ContainsKey('all') -and [bool]$Arguments.all
            if ($all -and $Arguments.ContainsKey('repository') -and $Arguments.repository) { throw (New-SBError 'mcp.params.conflict') }
            if (!$all) {
                return ConvertTo-SBMcpJson @(Get-SBGlobalTasks -BrainRoot $BrainRoot -Repository (Resolve-SBMcpRepository $BrainRoot $Arguments) -ReadyOnly)
            }
            # Paginated global view (default 50 tasks per page): bounded size; nextOffset identifies the next page.
            $offset = if ($Arguments.ContainsKey('offset') -and $Arguments.offset) { [int]$Arguments.offset } else { 0 }
            $limit = if ($Arguments.ContainsKey('limit') -and $null -ne $Arguments.limit) { [int]$Arguments.limit } else { 50 }
            if ($offset -lt 0 -or $limit -lt 0) { throw (New-SBError 'mcp.paging.invalid') }
            return ConvertTo-SBMcpJson (Get-SBGlobalTaskPage -BrainRoot $BrainRoot -Offset $offset -Limit $limit -ReadyOnly)
        }
        'get_task' {
            if (!$Arguments.ContainsKey('task') -or !"$($Arguments.task)") {
                throw (New-SBError 'mcp.task.required')
            }
            $dossier = if ($Arguments.ContainsKey('dossier') -and $Arguments.dossier) { [string]$Arguments.dossier } else { Resolve-SBWorkingDossier $BrainRoot (Resolve-SBMcpRepository $BrainRoot $Arguments) }
            $dossierPath = if ([IO.Path]::IsPathRooted($dossier)) { $dossier } else { Join-Path $BrainRoot $dossier }
            return ConvertTo-SBMcpJson (Get-SBTaskDetail -BrainRoot $BrainRoot -Dossier $dossierPath -Task ([string]$Arguments.task))
        }
        'search_knowledge' {
            if (!$Arguments.ContainsKey('query') -or !$Arguments.query) {
                throw (New-SBError 'mcp.query.required')
            }
            $query = [string]$Arguments.query
            # -1 = default limit (20 matches, 10,000 characters); explicit 0 = unlimited.
            $budget = if ($Arguments.ContainsKey('budget') -and $null -ne $Arguments.budget) { [int]$Arguments.budget } else { -1 }
            $dossier = if ($Arguments.ContainsKey('dossier')) { [string]$Arguments.dossier } else { $null }
            $repo = if ($Arguments.ContainsKey('repository')) { [string]$Arguments.repository } else { $null }
            $allDossiers = $Arguments.ContainsKey('allDossiers') -and [bool]$Arguments.allDossiers
            $includeOriginals = $Arguments.ContainsKey('includeOriginals') -and [bool]$Arguments.includeOriginals
            # Default scope: working checkout's repository, if resolvable; otherwise all areas, still with the default limit.
            if (!$dossier -and !$repo -and !$allDossiers) {
                try { $repo = Resolve-SBMcpRepository $BrainRoot $Arguments } catch { $repo = $null }
            }
            
            $mode = if ($Arguments.ContainsKey('mode') -and $Arguments.mode) { [string]$Arguments.mode } else { 'literal' }
            if ($mode -notin @('literal', 'relevance')) { throw (New-SBError 'mcp.mode.invalid') }
            $mode = if ($mode -eq 'relevance') { 'Relevance' } else { 'Literal' }

            $offset = if ($Arguments.ContainsKey('offset') -and $Arguments.offset) { [int]$Arguments.offset } else { 0 }
            $limit = if ($Arguments.ContainsKey('limit') -and $null -ne $Arguments.limit) { [int]$Arguments.limit } else { -1 }
            if ($offset -lt 0 -or $limit -lt -1 -or $budget -lt -1) { throw (New-SBError 'mcp.search.invalid') }

            $res = Find-SBKnowledge -BrainRoot $BrainRoot -Search $query -Dossier $dossier -Repository $repo -Budget $budget -Mode $mode -Offset $offset -Limit $limit -IncludeOriginals:$includeOriginals
            return ConvertTo-SBMcpJson $res
        }
        'list_prompts' {
            $catalog = Read-SBWorkflowCatalog $BrainRoot
            $category = if ($Arguments.ContainsKey('category')) { [string]$Arguments.category } else { $null }
            $compact = $Arguments.ContainsKey('compact') -and [bool]$Arguments.compact
            return Format-SBWorkflowList $catalog $category -Compact:$compact
        }
        'get_prompt_home' {
            $homeState = if ($Arguments.ContainsKey('repositoryPath') -and $Arguments.repositoryPath) { Get-SBWorkflowState $BrainRoot ([string]$Arguments.repositoryPath) } else { $null }
            return Format-SBWorkflowHome $BrainRoot (Read-SBWorkflowCatalog $BrainRoot) $homeState
        }
        'get_prompt' {
            if (!$Arguments.ContainsKey('prompt') -or !$Arguments.prompt) {
                throw (New-SBError 'mcp.prompt.required')
            }
            $catalog = Read-SBWorkflowCatalog $BrainRoot
            $resolution = Resolve-SBWorkflowPrompt $catalog ([string]$Arguments.prompt)
            $objective = if ($Arguments.ContainsKey('objective')) { [string]$Arguments.objective } else { '' }
            return New-SBWorkflowComposition $BrainRoot $catalog $resolution.prompt @{repositories=@();project=$null;sourceRegistry=$null} $objective -Standalone
        }
        'preview_dossier_write' {
            Assert-SBMcpWriteFields $Arguments @('repository','checkoutPath','requestId','operation','payload','noRecovery') @('repository','checkoutPath','requestId','operation','payload')
            return ConvertTo-SBMcpJson (New-SBMcpWritePlan $BrainRoot $script:SBMcpConfigPath $Arguments.repository $Arguments.checkoutPath $Arguments.requestId $Arguments.operation $Arguments.payload)
        }
        'submit_dossier_write' {
            Assert-SBMcpWriteFields $Arguments @('repository','checkoutPath','requestId','planHash','noRecovery') @('repository','checkoutPath','requestId','planHash')
            $disabled=[bool](Get-Variable -Name SBMcpNoRecovery -Scope Script -ValueOnly -ErrorAction SilentlyContinue)
            if($disabled -or ($Arguments.ContainsKey('noRecovery') -and $Arguments.noRecovery -eq $true)){throw (New-SBError 'mcpwrite.disabled')}
            return ConvertTo-SBMcpJson (Submit-SBMcpWrite $BrainRoot $script:SBMcpConfigPath $Arguments.repository $Arguments.checkoutPath $Arguments.requestId $Arguments.planHash)
        }
        'check_publication' {
            if (!$Arguments.ContainsKey('repositoryPath') -or !$Arguments.repositoryPath) {
                throw (New-SBError 'mcp.path.required')
            }
            $repoPath = [string]$Arguments.repositoryPath
            $report = Test-SBPublication -RepositoryPath $repoPath -BrainRoot $BrainRoot -PolicyPath (Resolve-SBPublicationPolicyPath $BrainRoot $null)
            if ($Arguments.ContainsKey('detail') -and [bool]$Arguments.detail) { return ConvertTo-SBMcpJson $report }
            # Summary: counts per rule and first 20 matches; excludedRefs becomes a count. detail=true returns the complete report.
            $allFindings = @($report.findings)
            $summary = @{}
            foreach ($key in $report.Keys) { $summary[$key] = $report[$key] }
            $summary.findings = @($allFindings | Select-Object -First 20)
            $summary.findingsTotal = $allFindings.Count
            $summary.findingsByRule = @($allFindings | Group-Object { [string]$_.rule } | Sort-Object Count -Descending | ForEach-Object { @{ rule = $_.Name; count = $_.Count } })
            $summary.findingsTruncated = ($allFindings.Count -gt 20)
            if ($report.ContainsKey('excludedRefs')) { $summary.excludedRefsCount = @($report.excludedRefs).Count; $summary.Remove('excludedRefs') }
            return ConvertTo-SBMcpJson $summary
        }
        default {
            throw (New-SBError 'mcp.tool.unknown' @($ToolName))
        }
    }
    } finally {
        Set-SBWorkflowLanguage $previousLanguage
    }
}

function Invoke-SBMcpMessage([string]$BrainRoot, $Message) {
    if ($Message -is [string]) {
        try {
            $Message = ConvertFrom-Json -InputObject $Message -AsHashtable
        } catch {
            return ConvertTo-SBMcpJson @{
                jsonrpc = '2.0'
                id = $null
                error = @{
                    code = -32700
                    message = (Get-SBMessage 'mcp.json.parse' @($_.Exception.Message))
                }
            }
        }
    }
    
    if (!$Message -or !$Message.ContainsKey('jsonrpc') -or $Message.jsonrpc -ne '2.0') {
        return ConvertTo-SBMcpJson @{
            jsonrpc = '2.0'
            id = if ($Message -and $Message.ContainsKey('id')) { $Message.id } else { $null }
            error = @{
                code = -32600
                message = (Get-SBMessage 'mcp.json.request')
            }
        }
    }
    
    $id = if ($Message.ContainsKey('id')) { $Message.id } else { $null }
    $isNotification = ($null -eq $id)
    $method = if ($Message.ContainsKey('method')) { [string]$Message.method } else { '' }
    $params = if ($Message.ContainsKey('params')) { $Message.params } else { @{} }
    
    # Notifications do not return responses
    if ($method.StartsWith('notifications/',[StringComparison]::Ordinal) -or $method -eq 'initialized') {
        return $null
    }
    
    try {
        $pendingWrites=$null
        $skipRecovery=([bool](Get-Variable -Name SBMcpNoRecovery -Scope Script -ValueOnly -ErrorAction SilentlyContinue))
        if($params -is [Collections.IDictionary]){
            if($params.ContainsKey('_meta') -and $params._meta -is [Collections.IDictionary] -and $params._meta.ContainsKey('noRecovery') -and $params._meta.noRecovery -eq $true){$skipRecovery=$true}
            if($params.ContainsKey('arguments') -and $params.arguments -is [Collections.IDictionary] -and $params.arguments.ContainsKey('noRecovery') -and $params.arguments.noRecovery -eq $true){$skipRecovery=$true}
        }
        if($method -eq 'tools/call' -and $params.ContainsKey('name') -and $params.name -in @('preview_dossier_write','submit_dossier_write')){$skipRecovery=$true}
        if(!$skipRecovery -and $method -in @('initialize','tools/list','tools/call','prompts/list','prompts/get','resources/list','resources/read')){
            $pendingWrites=Invoke-SBMcpPendingRecovery $BrainRoot $script:SBMcpConfigPath
        }
        switch ($method) {
            'initialize' {
                return ConvertTo-SBMcpJson @{
                    jsonrpc = '2.0'
                    id = $id
                    result = @{
                        protocolVersion = $(if($params.ContainsKey('protocolVersion') -and $params.protocolVersion -eq '2024-11-05'){'2024-11-05'}else{'2025-03-26'})
                        instructions = $(if($skipRecovery){Get-SBMessage 'mcp.pending.disabled'}else{Get-SBMessage 'mcp.pending.contract'})
                        _meta = @{pendingWrites=$pendingWrites;noRecovery=$skipRecovery}
                        capabilities = @{
                            tools = @{ listChanged = $false }
                            prompts = @{ listChanged = $false }
                            resources = @{ subscribe = $false; listChanged = $false }
                        }
                        serverInfo = @{
                            name = 'secondbrain-mcp'
                            version = (Get-SBVersion)
                        }
                    }
                }
            }
            'ping' {
                return ConvertTo-SBMcpJson @{
                    jsonrpc = '2.0'
                    id = $id
                    result = @{}
                }
            }
            'tools/list' {
                $tools = Get-SBMcpToolDefinitions
                return ConvertTo-SBMcpJson @{
                    jsonrpc = '2.0'
                    id = $id
                    result = @{
                        tools = $tools
                    }
                }
            }
            'tools/call' {
                $toolName = if ($params.ContainsKey('name')) { [string]$params.name } else { '' }
                $args = if ($params.ContainsKey('arguments')) { $params.arguments } else { @{} }
                
                try {
                    $output = Invoke-SBMcpToolCall -BrainRoot $BrainRoot -ToolName $toolName -Arguments $args
                    $contentBlocks = @(@{ type = 'text'; text = $output })
                    if($pendingWrites -and ($pendingWrites.applied.Count -or $pendingWrites.conflicts.Count -or $pendingWrites.pending -or $pendingWrites.errors.Count)){
                        $contentBlocks+=@{type='text';text=((Format-SBPendingNotice $pendingWrites)+"`n"+(ConvertTo-SBMcpJson $pendingWrites))}
                    }
                    $notice = Get-SBMcpDeprecationNotice $toolName
                    if ($notice) { $contentBlocks += @{ type = 'text'; text = (Get-SBMessage 'mcp.notice' @($notice)) } }
                    return ConvertTo-SBMcpJson @{
                        jsonrpc = '2.0'
                        id = $id
                        result = @{
                            content = $contentBlocks
                            isError = $false
                        }
                    }
                } catch {
                    return ConvertTo-SBMcpJson @{
                        jsonrpc = '2.0'
                        id = $id
                        result = @{
                            content = @(
                                @{
                                    type = 'text'
                                    text = (Get-SBMessage 'mcp.tool.failed' @($toolName, $_.Exception.Message))
                                }
                            )
                            isError = $true
                        }
                    }
                }
            }
            'prompts/list' {
                $catalog = Read-SBWorkflowCatalog $BrainRoot
                $promptsList = @($catalog.prompts | ForEach-Object {
                    @{
                        name = $_.code
                        title = (Get-SBWorkflowField $_ 'summary')
                        description = ((Get-SBWorkflowField $_ 'summary') + " (ID $($_.id))")
                        arguments = @(
                            @{
                                name = 'objective'
                                description = (Get-SBMessage 'mcp.prompt.objective')
                                required = $false
                            }
                        )
                    }
                })
                return ConvertTo-SBMcpJson @{
                    jsonrpc = '2.0'
                    id = $id
                    result = @{
                        prompts = $promptsList
                    }
                }
            }
            'prompts/get' {
                $promptName = if ($params.ContainsKey('name')) { [string]$params.name } else { '' }
                $catalog = Read-SBWorkflowCatalog $BrainRoot
                $resolution = Resolve-SBWorkflowPrompt $catalog $promptName
                $match = @($resolution.prompt)
                $promptArguments = if ($params.ContainsKey('arguments') -and $params.arguments -is [System.Collections.IDictionary]) { $params.arguments } else { @{} }
                $objective = if ($promptArguments.ContainsKey('objective')) { [string]$promptArguments.objective } else { '' }
                $text = New-SBWorkflowComposition $BrainRoot $catalog $match[0] @{repositories=@();project=$null;sourceRegistry=$null} $objective -Standalone
                return ConvertTo-SBMcpJson @{
                    jsonrpc = '2.0'
                    id = $id
                    result = @{
                        description = (Get-SBWorkflowField $match[0] 'summary')
                        messages = @(
                            @{
                                role = 'user'
                                content = @{
                                    type = 'text'
                                    text = $text
                                }
                            }
                        )
                    }
                }
            }
            'resources/list' {
                return ConvertTo-SBMcpJson @{
                    jsonrpc = '2.0'
                    id = $id
                    result = @{
                        resources = @(
                            @{
                                uri = 'secondbrain://prompts/catalog'
                                name = (Get-SBMessage 'mcp.resource.catalog')
                                mimeType = 'application/json'
                            }
                        )
                    }
                }
            }
            'resources/read' {
                $uri = if ($params.ContainsKey('uri')) { [string]$params.uri } else { '' }
                if ($uri -eq 'secondbrain://prompts/catalog') {
                    $catalog = Read-SBWorkflowCatalog $BrainRoot
                    return ConvertTo-SBMcpJson @{
                        jsonrpc = '2.0'
                        id = $id
                        result = @{
                            contents = @(
                                @{
                                    uri = $uri
                                    mimeType = 'application/json'
                                    text = (ConvertTo-SBMcpJson $catalog)
                                }
                            )
                        }
                    }
                } else {
                    throw (New-SBError 'mcp.resource.notfound' @($uri))
                }
            }
            default {
                if ($isNotification) { return $null }
                return ConvertTo-SBMcpJson @{
                    jsonrpc = '2.0'
                    id = $id
                    error = @{
                        code = -32601
                        message = (Get-SBMessage 'mcp.json.method' @($method))
                    }
                }
            }
        }
    } catch {
        if ($isNotification) { return $null }
        return ConvertTo-SBMcpJson @{
            jsonrpc = '2.0'
            id = $id
            error = @{
                code = -32603
                message = (Get-SBMessage 'mcp.json.internal' @($_.Exception.Message))
            }
        }
    }
}

function Start-SBMcpServer {
    [CmdletBinding()]
    param(
        [string]$BrainRoot,
        [string]$ConfigPath,
        [switch]$NoRecovery
    )
    if (!$BrainRoot) {
        $BrainRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    }
    $script:SBMcpConfigPath=$ConfigPath
    $script:SBMcpNoRecovery=[bool]$NoRecovery
    if(!$NoRecovery){
        $startupPending=Invoke-SBMcpPendingRecovery $BrainRoot $ConfigPath
        if($startupPending.applied.Count -or $startupPending.conflicts.Count -or $startupPending.pending -or $startupPending.errors.Count){[Console]::Error.WriteLine((Format-SBPendingNotice $startupPending))}
    }
    
    # Stdio loop
    $reader = [Console]::In
    $writer = [Console]::Out
    
    while ($true) {
        $line = $reader.ReadLine()
        if ($null -eq $line) { break }
        $line = $line.Trim()
        if (!$line) { continue }
        
        $response = Invoke-SBMcpMessage -BrainRoot $BrainRoot -Message $line
        if ($response) {
            # MCP stdio writes single-line or compact JSON without stray newlines
            $writer.WriteLine($response)
            $writer.Flush()
        }
    }
}

function Get-SBMcpReadOnlyToolNames {
    # Compatibility entry point: recovery-enabled tools no longer qualify as read-only.
    @()
}
function Get-SBMcpKnowledgeToolNames {
    @('get_startup_context', 'get_ready_tasks', 'get_task', 'search_knowledge', 'list_prompts', 'get_prompt', 'get_prompt_home')
}
function Test-SBClaudeCodeRegistration([string]$ConfigFile) {
    # Read-only .claude.json access: user-level server (mcpServers) or project-local server (projects.<path>.mcpServers).
    if (!$ConfigFile -or !(Test-Path -LiteralPath $ConfigFile -PathType Leaf)) { return $false }
    try {
        $document = Get-Content -LiteralPath $ConfigFile -Raw -ErrorAction Stop | ConvertFrom-Json -AsHashtable -ErrorAction Stop
        if ($document -isnot [System.Collections.IDictionary]) { return $false }
        if ($document.ContainsKey('mcpServers') -and $document.mcpServers -is [System.Collections.IDictionary] -and $document.mcpServers.ContainsKey('secondbrain')) { return $true }
        if ($document.ContainsKey('projects') -and $document.projects -is [System.Collections.IDictionary]) {
            foreach ($project in $document.projects.Values) {
                if ($project -is [System.Collections.IDictionary] -and $project.ContainsKey('mcpServers') -and $project.mcpServers -is [System.Collections.IDictionary] -and $project.mcpServers.ContainsKey('secondbrain')) { return $true }
            }
        }
    } catch { }
    $false
}
Add-SBMessages @{
    'mcp.pair.json' = @{ it = 'Configurazione MCP non è JSON rigoroso (errori o commenti), nessuna modifica: {0}. Inserisci a mano il frammento mostrato da mcp-server.ps1 -Pair.'; en = 'MCP configuration is not strict JSON (errors or comments), no change made: {0}. Add by hand the fragment shown by mcp-server.ps1 -Pair.' }
    'mcp.pair.toml' = @{ it = 'TOML ambiguo o non supportato, nessuna modifica: {0}'; en = 'Ambiguous or unsupported TOML, no change made: {0}' }
    'mcp.pair.permissions.conflict' = @{ it = 'Regola esistente concede consenso a check_publication; nessuna modifica: {0}'; en = 'Existing rule approves check_publication; no change made: {0}' }
    'mcp.pair.permissions.scope' = @{ it = 'Selezionare un solo ambito di approvazione MCP'; en = 'Select only one MCP permission scope' }
    'mcp.pair.root' = @{ it = 'Configurazione MCP con radice non oggetto, nessuna modifica: {0}'; en = 'MCP configuration with a non-object root, no change made: {0}' }
}
# Private pairing helpers.
function Read-SBMcpSettings([string]$Path) {
    if(!(Test-Path -LiteralPath $Path -PathType Leaf)){return @{}}
    $raw=Read-SBText $Path
    if(!$raw.Trim()){return @{}}
    try {
        $document=[Text.Json.JsonDocument]::Parse($raw)
        try{
            function Assert-UniqueMcpKeys($Node){
                if($Node.ValueKind -eq [Text.Json.JsonValueKind]::Object){
                    $keys=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
                    foreach($property in $Node.EnumerateObject()){
                        if(!$keys.Add($property.Name)){throw (New-SBError 'mcp.pair.json' @($Path))}
                        Assert-UniqueMcpKeys $property.Value
                    }
                }elseif($Node.ValueKind -eq [Text.Json.JsonValueKind]::Array){foreach($item in $Node.EnumerateArray()){Assert-UniqueMcpKeys $item}}
            }
            Assert-UniqueMcpKeys $document.RootElement
        }finally{$document.Dispose()}
        $data=ConvertFrom-Json -InputObject $raw -AsHashtable
        if($data -isnot [Collections.IDictionary]){throw (New-SBError 'mcp.pair.root' @($Path))}
        $data
    } catch { throw (New-SBError 'mcp.pair.json' @($Path)) }
}
function Get-SBMcpPermissionPlan($Pairing,[switch]$ApproveAllTools) {
    $names=@(Get-SBMcpKnowledgeToolNames)
    if($ApproveAllTools){$names+='check_publication'}
    $requiresConsent=@('check_publication'|Where-Object {$_ -notin $names})
    $status='manual';$path=$null;$snippet=$null;$manualStep=$null
    switch($Pairing.Target){
        'codex' {
            $status='supported';$path=$Pairing.ConfigFile
            $lines=@('[mcp_servers.secondbrain]','default_tools_approval_mode = "prompt"')
            foreach($name in $names){$lines+=@("[mcp_servers.secondbrain.tools.$name]",'approval_mode = "approve"')}
            if($requiresConsent.Count){$lines+=@('[mcp_servers.secondbrain.tools.check_publication]','approval_mode = "prompt"')}
            $snippet=$lines -join "`n"
        }
        'claude-code' {
            $status='supported'
            $path=Join-Path (Split-Path $Pairing.ConfigFile) '.claude/settings.json'
            # CLAUDE_CONFIG_DIR is itself the settings directory, unlike the default profile root.
            $claudeRoot=[Environment]::GetEnvironmentVariable('CLAUDE_CONFIG_DIR','User')
            if(!$claudeRoot){$claudeRoot=$env:CLAUDE_CONFIG_DIR}
            if($Pairing.Scope -eq 'user'){
                $directory=Split-Path $Pairing.ConfigFile
                if(($claudeRoot -and (Test-SBSamePath $directory $claudeRoot)) -or
                    ((Split-Path $Pairing.ConfigFile -Leaf) -eq '.claude.json' -and !(Test-SBSamePath $directory $env:USERPROFILE))){$path=Join-Path $directory 'settings.json'}
            }
            $snippet=ConvertTo-SBJson @{permissions=@{allow=@($names|ForEach-Object {"mcp__secondbrain__$_"});ask=@($requiresConsent|ForEach-Object {"mcp__secondbrain__$_"})}}
        }
        'cursor' {
            $status='supported';$path=Join-Path $env:USERPROFILE '.cursor/permissions.json'
            if($Pairing.Scope -eq 'user'){$path=Join-Path (Split-Path $Pairing.ConfigFile) 'permissions.json'}
            $snippet=ConvertTo-SBJson @{mcpAllowlist=@($names|ForEach-Object {"secondbrain:$_"})}
        }
        'antigravity' {$status='unverified'}
        'windsurf' {$status='unverified'}
        'vscode' {$manualStep='Chat: Manage Tool Approval → SecondBrain → select the listed tools in the intended profile.'}
        'claude' {$manualStep='Open a new Claude Desktop session and review the per-tool permissions offered by the client.'}
    }
    @{status=$status;path=$path;snippet=$snippet;tools=$names;requiresConsent=$requiresConsent;manualStep=$manualStep;approveAllTools=[bool]$ApproveAllTools;contract='knowledge-with-authorized-pending-writes';automaticDossierWrites=$true}
}
function Set-SBMcpTomlValue([string]$Text,[string]$Table,[string]$Key,[string]$Value,[switch]$KeepRestrictive) {
    # Edit only a single-line string in an exact table. Preserve all other bytes/comments;
    # reject ambiguous/dotted encodings rather than rewriting arbitrary TOML.
    $header='(?m)^\['+[regex]::Escape($Table)+'\][ \t]*(?:#[^\r\n]*)?\r?$'
    $matches=[regex]::Matches($Text,$header)
    if($matches.Count -gt 1){throw (New-SBError 'mcp.pair.toml' @($Table))}
    if(!$matches.Count){return $Text.TrimEnd("`r","`n")+"`n`n[$Table]`n$Key = `"$Value`"`n"}
    $start=$matches[0].Index+$matches[0].Length
    $next=[regex]::Match($Text.Substring($start),'(?m)^\[')
    $end=if($next.Success){$start+$next.Index}else{$Text.Length}
    $body=$Text.Substring($start,$end-$start)
    $pattern='(?m)^(?<indent>[ \t]*)'+[regex]::Escape($Key)+'[ \t]*=[ \t]*["''](?<value>[A-Za-z-]+)["''](?<suffix>[ \t]*(?:#[^\r\n]*)?\r?)$'
    $values=[regex]::Matches($body,$pattern)
    $keyLines=[regex]::Matches($body,'(?m)^[ \t]*'+[regex]::Escape($Key)+'[ \t]*=')
    if($values.Count -gt 1 -or $keyLines.Count -ne $values.Count){throw (New-SBError 'mcp.pair.toml' @($Table+'.'+$Key))}
    if($values.Count){
        $current=$values[0].Groups['value'].Value
        if($current -notin @('auto','prompt','writes','approve')){throw (New-SBError 'mcp.pair.toml' @($Table+'.'+$Key))}
        if($KeepRestrictive -and $current -ne 'approve'){return $Text}
        $replacement=$values[0].Groups['indent'].Value+$Key+' = "'+$Value+'"'+$values[0].Groups['suffix'].Value
        $body=$body.Remove($values[0].Index,$values[0].Length).Insert($values[0].Index,$replacement)
    }else{$body=$body.TrimEnd("`r","`n")+"`n$Key = `"$Value`"`n"}
    $Text.Substring(0,$start)+$body+$Text.Substring($end)
}
function Get-SBMcpPermissionContent($Pairing) {
    $plan=$Pairing.PermissionPlan
    if($plan.status -ne 'supported'){return $null}
    if($Pairing.Target -eq 'codex'){
        $text=if(Test-Path -LiteralPath $plan.path){Read-SBText $plan.path}else{''}
        # Dotted or quoted policy tables need a TOML-aware editor. Never create conflicting tables.
        if($text -match '(?m)^\s*(?:["'']?mcp_servers["'']?\s*\.|\[\s*["'']mcp_servers|\[mcp_servers\.["'']secondbrain)'){
            throw (New-SBError 'mcp.pair.toml' @($plan.path))
        }
        if($text -match '(?m)^\s*\[\[?mcp_servers\.secondbrain[^\r\n]*["'']' -or
            $text -match '(?m)^\s*(?:tools\.|secondbrain\s*=|["'']?(?:default_tools_approval_mode|approval_mode)["'']\s*=)'){
            throw (New-SBError 'mcp.pair.toml' @($plan.path))
        }
        $text=Set-SBMcpTomlValue $text 'mcp_servers.secondbrain' 'default_tools_approval_mode' 'prompt'
        foreach($name in $plan.tools){$text=Set-SBMcpTomlValue $text ('mcp_servers.secondbrain.tools.'+$name) 'approval_mode' 'approve' -KeepRestrictive:(!$plan.approveAllTools)}
        if($plan.requiresConsent.Count){$text=Set-SBMcpTomlValue $text 'mcp_servers.secondbrain.tools.check_publication' 'approval_mode' 'prompt'}
        return $text
    }
    $data=Read-SBMcpSettings $plan.path
    $requested=ConvertFrom-Json -InputObject $plan.snippet -AsHashtable
    if($Pairing.Target -eq 'cursor'){
        if($data.ContainsKey('mcpAllowlist') -and ($data.mcpAllowlist -isnot [array] -or @($data.mcpAllowlist|Where-Object {$_ -isnot [string]}).Count)){throw (New-SBError 'mcp.pair.json' @($plan.path))}
        $previous=if($data.ContainsKey('mcpAllowlist')){@($data.mcpAllowlist)}else{@()}
        foreach($entry in $previous){
            $pieces=([string]$entry) -split ':',2
            if($pieces.Count -eq 2 -and 'secondbrain' -like $pieces[0] -and
                (($plan.approveAllTools -and $pieces[1] -match '[*?\[]') -or (!$plan.approveAllTools -and 'check_publication' -like $pieces[1]))){
                throw (New-SBError 'mcp.pair.permissions.conflict' @($plan.path))
            }
        }
        $data.mcpAllowlist=@(@($previous)+@($requested.mcpAllowlist)|Select-Object -Unique)
    }else{
        if(!$data.ContainsKey('permissions')){$data.permissions=@{}}
        if($data.permissions -isnot [Collections.IDictionary]){throw (New-SBError 'mcp.pair.json' @($plan.path))}
        foreach($key in @('allow','ask')){
            if($data.permissions.ContainsKey($key) -and ($data.permissions[$key] -isnot [array] -or @($data.permissions[$key]|Where-Object {$_ -isnot [string]}).Count)){throw (New-SBError 'mcp.pair.json' @($plan.path))}
            $previous=if($data.permissions.ContainsKey($key)){@($data.permissions[$key])}else{@()}
            if($plan.approveAllTools -and $key -eq 'ask'){$previous=@($previous|Where-Object {$_ -cne 'mcp__secondbrain__check_publication'})}
            $data.permissions[$key]=@(@($previous)+@($requested.permissions[$key])|Select-Object -Unique)
        }
    }
    ConvertTo-SBJson $data
}
function Invoke-SBMcpNative([string]$Command,[string[]]$Arguments,[string]$WorkingDirectory,[hashtable]$Environment) {
    $executable=Get-Command $Command -CommandType Application -ErrorAction SilentlyContinue|Select-Object -First 1
    if(!$executable){return @{status='cli-unavailable';exitCode=$null}}
    $info=[Diagnostics.ProcessStartInfo]::new($executable.Source)
    if([IO.Path]::GetExtension($executable.Source) -in @('.cmd','.bat')){
        $quoted=@(@($executable.Source)+@($Arguments)|ForEach-Object {"'"+([string]$_).Replace("'","''")+"'"})
        $invocation='& '+($quoted -join ' ')+'; exit $LASTEXITCODE'
        $info=[Diagnostics.ProcessStartInfo]::new((Get-Command pwsh -CommandType Application|Select-Object -First 1).Source)
        foreach($item in @('-NoProfile','-NonInteractive','-EncodedCommand',[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($invocation)))){$info.ArgumentList.Add($item)}
    }else{foreach($item in $Arguments){$info.ArgumentList.Add($item)}}
    $info.UseShellExecute=$false;$info.CreateNoWindow=$true
    $info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
    if($WorkingDirectory){$info.WorkingDirectory=$WorkingDirectory}
    foreach($key in $Environment.Keys){$info.Environment[$key]=[string]$Environment[$key]}
    $process=[Diagnostics.Process]::new();$process.StartInfo=$info
    try{
        [void]$process.Start();$stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
        if(!$process.WaitForExit(30000)){$process.Kill($true);return @{status='cli-timeout';exitCode=$null}}
        # CLI output may contain personal settings. Keep only the status, never echo it.
        [void]$stdout.GetAwaiter().GetResult();[void]$stderr.GetAwaiter().GetResult()
        @{status=$(if($process.ExitCode -eq 0){'applied'}else{'cli-failed'});exitCode=$process.ExitCode}
    }finally{$process.Dispose()}
}
function Test-SBMcpNativeDefinition($Pairing) {
    $present=$false;$matches=$false
    if($Pairing.Target -eq 'claude-code'){
        $data=Read-SBMcpSettings $Pairing.ConfigFile
        $present=$data.ContainsKey('mcpServers') -and $data.mcpServers -is [Collections.IDictionary] -and $data.mcpServers.ContainsKey('secondbrain')
        if($present){
            $definition=$data.mcpServers.secondbrain
            $matches=$definition -is [Collections.IDictionary] -and $definition.ContainsKey('command') -and $definition.command -eq 'pwsh' -and $definition.ContainsKey('args') -and (ConvertTo-SBJson @($definition.args)) -ceq (ConvertTo-SBJson @($Pairing.ServerDefinition.args))
        }
    }else{
        $text=if(Test-Path -LiteralPath $Pairing.ConfigFile -PathType Leaf){Read-SBText $Pairing.ConfigFile}else{''}
        $section=[regex]::Match($text,'(?ms)^\[mcp_servers\.secondbrain\][^\r\n]*\r?\n(?<body>.*?)(?=^\[|\z)')
        $present=$section.Success
        if($present){
            $body=$section.Groups['body'].Value
            $command=[regex]::Match($body,'(?m)^command\s*=\s*"pwsh"\s*(?:#.*)?\r?$')
            $argsMatch=[regex]::Match($body,'(?m)^args\s*=\s*(\[[^\r\n]*\])\s*$')
            if($command.Success -and $argsMatch.Success){try{$nativeArgs=ConvertFrom-Json $argsMatch.Groups[1].Value;$matches=(ConvertTo-SBJson @($nativeArgs)) -ceq (ConvertTo-SBJson @($Pairing.ServerDefinition.args))}catch{}}
        }
    }
    @{present=$present;matches=$matches}
}
function Save-SBMcpNativeSnapshot([string]$Path,[string]$BackupRoot,[string]$ExpectedHash) {
    if((Get-SBFileHash $Path) -ne $ExpectedHash){throw (New-SBError 'core.concurrent.modified' @($Path))}
    if($ExpectedHash -eq 'absent'){return $null}
    $backup=Join-Path $BackupRoot ([guid]::NewGuid().ToString('N')+'.bin')
    $bytes=[IO.File]::ReadAllBytes($Path)
    if((Get-SBHash $bytes) -ne $ExpectedHash){throw (New-SBError 'core.concurrent.modified' @($Path))}
    [void](Write-SBFile $backup $bytes 'absent' $BackupRoot)
    $metadata=@{path=[IO.Path]::GetFullPath($Path);previousHash=$ExpectedHash;backup=$backup;deployedHash=$null;native=$true}
    [void](Write-SBFile ($backup+'.json') ([Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $metadata))) 'absent' $BackupRoot)
    $backup
}

function Get-SBMcpPairing {
    [CmdletBinding()]
    param(
        [string]$BrainRoot,
        [Parameter()][ValidateSet('codex', 'claude', 'claude-code', 'cursor', 'vscode', 'antigravity', 'windsurf', 'all')][string]$Target = 'all',
        [string]$WorkspacePath,
        [string]$ClaudeCodeConfigFile,[Alias('ConfigFile')][string]$OverrideConfigFile,
        [ValidateSet('user','project')][string]$Scope,[switch]$ApproveAllTools
    )
    if (!$BrainRoot) {
        $BrainRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    }
    $BrainRoot = [IO.Path]::GetFullPath($BrainRoot)
    $serverScript = Join-Path $BrainRoot 'scripts/mcp-server.ps1'
    $serverScriptNormalized = $serverScript.Replace('\', '/')
    $effectiveScope=if($Scope){$Scope}elseif($WorkspacePath){'project'}else{'user'}
    if($effectiveScope -eq 'project' -and (!$WorkspacePath -or $Target -notin @('claude-code','cursor','vscode','antigravity'))){throw (New-SBError 'mcp.pair.scope' @($Target,$effectiveScope))}
    $workspaceRoot = if ($effectiveScope -eq 'project' -and $WorkspacePath) { [IO.Path]::GetFullPath($WorkspacePath) } else { $null }
    $quotedScript="'"+$serverScript.Replace("'","''")+"'"
    $escapedScript = $serverScript.Replace('\', '\\')

    [string[]]$targetsToProcess = if ($Target.ToLowerInvariant() -eq 'all') {
        @('codex', 'claude', 'claude-code', 'cursor', 'vscode', 'antigravity', 'windsurf')
    } else {
        @($Target.ToLowerInvariant())
    }

    [object[]]$results = @()
    foreach ($t in $targetsToProcess) {
        switch ($t) {
            'codex' {
                $codexRoot = [Environment]::GetEnvironmentVariable('CODEX_HOME','User')
                if (!$codexRoot) { $codexRoot = $env:CODEX_HOME }
                if (!$codexRoot) { $codexRoot = Join-Path $env:USERPROFILE '.codex' }
                $configFile = Join-Path $codexRoot 'config.toml'
                
                $toml = @(
                    '[mcp_servers.secondbrain]',
                    'command = "pwsh"',
                    "args = [`"-NoProfile`", `"-File`", `"$escapedScript`"]"
                ) -join "`n"
                $cliCommand = "codex mcp add secondbrain -- pwsh -NoProfile -File $quotedScript"
                
                $results += [PSCustomObject]@{
                    Target = 'codex'
                    Name = 'OpenAI Codex'
                    ConfigFile = $configFile
                    ConfigFormat = 'toml'
                    Toml = $toml
                    Snippet = $toml
                    CliCommand = $cliCommand
                    ServerDefinition = @{
                        command = 'pwsh'
                        args = @('-NoProfile', '-File', $serverScriptNormalized)
                    }
                    Configured = (Test-Path -LiteralPath $configFile -PathType Leaf) -and ((Get-Content -LiteralPath $configFile -Raw -ErrorAction SilentlyContinue) -match '(?m)\[mcp_servers\.secondbrain\]')
                }
            }
            'claude' {
                $claudeRoot = [Environment]::GetEnvironmentVariable('CLAUDE_CONFIG_DIR','User')
                if (!$claudeRoot) { $claudeRoot = $env:CLAUDE_CONFIG_DIR }
                $cliCommand = $null
                # Claude Code registers servers in .claude.json (under CLAUDE_CONFIG_DIR when set, otherwise the user profile), not claude_desktop_config.json.
                $claudeCodeFile = if ($ClaudeCodeConfigFile) { $ClaudeCodeConfigFile } elseif ($claudeRoot) { Join-Path $claudeRoot '.claude.json' } else { Join-Path $env:USERPROFILE '.claude.json' }
                $configFile = Join-Path $env:APPDATA 'Claude/claude_desktop_config.json'

                $snippetObj = [ordered]@{
                    mcpServers = [ordered]@{
                        secondbrain = [ordered]@{
                            command = 'pwsh'
                            args = @('-NoProfile', '-File', $serverScriptNormalized)
                        }
                    }
                }
                $json = ConvertTo-Json -InputObject $snippetObj -Depth 10
                # Claude Code: settings.json permission rules only for knowledge tools, to paste after user approval.

                $results += [PSCustomObject]@{
                    Target = 'claude'
                    Name = 'Claude Desktop'
                    ConfigFile = $configFile
                    ConfigFormat = 'json'
                    Toml = $null
                    Snippet = $json
                    PermissionsSnippet = $null
                    CliCommand = $cliCommand
                    ServerDefinition = @{
                        command = 'pwsh'
                        args = @('-NoProfile', '-File', $serverScriptNormalized)
                    }
                    Configured = (Test-Path -LiteralPath $configFile -PathType Leaf) -and ((Get-Content -LiteralPath $configFile -Raw -ErrorAction SilentlyContinue) -match '"secondbrain"')
                    DesktopConfigFile = $configFile
                    DesktopConfigured = (Test-Path -LiteralPath $configFile -PathType Leaf) -and ((Get-Content -LiteralPath $configFile -Raw -ErrorAction SilentlyContinue) -match '"secondbrain"')
                    CodeConfigFile = $claudeCodeFile
                    CodeConfigured = Test-SBClaudeCodeRegistration $claudeCodeFile
                }
            }
            'cursor' {
                $cursorRoot = if ($workspaceRoot) { Join-Path $workspaceRoot '.cursor' } else { Join-Path $env:USERPROFILE '.cursor' }
                $configFile = Join-Path $cursorRoot 'mcp.json'

                $snippetObj = [ordered]@{
                    mcpServers = [ordered]@{
                        secondbrain = [ordered]@{
                            command = 'pwsh'
                            args = @('-NoProfile', '-File', $serverScriptNormalized)
                        }
                    }
                }
                $json = ConvertTo-Json -InputObject $snippetObj -Depth 10

                $results += [PSCustomObject]@{
                    Target = 'cursor'
                    Name = 'Cursor IDE'
                    ConfigFile = $configFile
                    ConfigFormat = 'json'
                    Toml = $null
                    Snippet = $json
                    CliCommand = $null
                    ServerDefinition = @{
                        command = 'pwsh'
                        args = @('-NoProfile', '-File', $serverScriptNormalized)
                    }
                    Configured = (Test-Path -LiteralPath $configFile -PathType Leaf) -and ((Get-Content -LiteralPath $configFile -Raw -ErrorAction SilentlyContinue) -match '"secondbrain"')
                }
            }
            'vscode' {
                # VS Code reads MCP servers from mcp.json (servers key, required type): user profile or, with -WorkspacePath, the project's .vscode/.
                $configFile = if ($workspaceRoot) { Join-Path $workspaceRoot '.vscode/mcp.json' } else { Join-Path $env:APPDATA 'Code/User/mcp.json' }

                $snippetObj = [ordered]@{
                    servers = [ordered]@{
                        secondbrain = [ordered]@{
                            type = 'stdio'
                            command = 'pwsh'
                            args = @('-NoProfile', '-File', $serverScriptNormalized)
                        }
                    }
                }
                $json = ConvertTo-Json -InputObject $snippetObj -Depth 10

                $results += [PSCustomObject]@{
                    Target = 'vscode'
                    Name = 'Visual Studio Code'
                    ConfigFile = $configFile
                    ConfigFormat = 'json'
                    Toml = $null
                    Snippet = $json
                    CliCommand = $null
                    ServerDefinition = @{
                        command = 'pwsh'
                        args = @('-NoProfile', '-File', $serverScriptNormalized)
                    }
                    Configured = (Test-Path -LiteralPath $configFile -PathType Leaf) -and ((Get-Content -LiteralPath $configFile -Raw -ErrorAction SilentlyContinue) -match '"secondbrain"')
                }
            }
            'claude-code' {
                # Claude Code: project scope = .mcp.json in the project root (mcpServers key); user scope lives in ~/.claude.json, managed by the CLI.
                $configFile = if ($workspaceRoot) { Join-Path $workspaceRoot '.mcp.json' } else { $null }
                $claudeRootCode = [Environment]::GetEnvironmentVariable('CLAUDE_CONFIG_DIR','User')
                if (!$claudeRootCode) { $claudeRootCode = $env:CLAUDE_CONFIG_DIR }
                $userFile = if ($ClaudeCodeConfigFile) { $ClaudeCodeConfigFile } elseif ($claudeRootCode) { Join-Path $claudeRootCode '.claude.json' } else { Join-Path $env:USERPROFILE '.claude.json' }
                if(!$workspaceRoot){$configFile=$userFile}

                $snippetObj = [ordered]@{
                    mcpServers = [ordered]@{
                        secondbrain = [ordered]@{
                            command = 'pwsh'
                            args = @('-NoProfile', '-File', $serverScriptNormalized)
                        }
                    }
                }
                $json = ConvertTo-Json -InputObject $snippetObj -Depth 10
                $projectConfigured = $workspaceRoot -and (Test-Path -LiteralPath $configFile -PathType Leaf) -and ((Get-Content -LiteralPath $configFile -Raw -ErrorAction SilentlyContinue) -match '"secondbrain"')

                $results += [PSCustomObject]@{
                    Target = 'claude-code'
                    Name = 'Claude Code'
                    ConfigFile = $configFile
                    ConfigFormat = 'json'
                    Toml = $null
                    Snippet = $json
                    CliCommand = "claude mcp add --transport stdio --scope $effectiveScope secondbrain -- pwsh -NoProfile -File $quotedScript"
                    CliCommandUser = "claude mcp add --transport stdio --scope user secondbrain -- pwsh -NoProfile -File $quotedScript"
                    ServerDefinition = @{
                        command = 'pwsh'
                        args = @('-NoProfile', '-File', $serverScriptNormalized)
                    }
                    Configured = if($workspaceRoot){[bool]$projectConfigured}else{Test-SBClaudeCodeRegistration $userFile}
                    ProjectConfigured = [bool]$projectConfigured
                    UserConfigFile = $userFile
                    UserConfigured = Test-SBClaudeCodeRegistration $userFile
                }
            }
            'antigravity' {
                # Antigravity 2.0 shares configuration in ~/.gemini/config/mcp_config.json; earlier versions use ~/.gemini/antigravity/mcp_config.json. Prefer the new file when present.
                $agShared = Join-Path $env:USERPROFILE '.gemini/config/mcp_config.json'
                $agLegacy = Join-Path $env:USERPROFILE '.gemini/antigravity/mcp_config.json'
                $configFile = if($workspaceRoot){Join-Path $workspaceRoot '.agents/mcp_config.json'}elseif((Test-Path -LiteralPath $agLegacy -PathType Leaf) -and !(Test-Path -LiteralPath $agShared -PathType Leaf)){$agLegacy}else{$agShared}

                $snippetObj = [ordered]@{
                    mcpServers = [ordered]@{
                        secondbrain = [ordered]@{
                            command = 'pwsh'
                            args = @('-NoProfile', '-File', $serverScriptNormalized)
                        }
                    }
                }
                $json = ConvertTo-Json -InputObject $snippetObj -Depth 10

                $results += [PSCustomObject]@{
                    Target = 'antigravity'
                    Name = 'Google Antigravity'
                    ConfigFile = $configFile
                    ConfigFormat = 'json'
                    Toml = $null
                    Snippet = $json
                    CliCommand = $null
                    ServerDefinition = @{
                        command = 'pwsh'
                        args = @('-NoProfile', '-File', $serverScriptNormalized)
                    }
                    Configured = (Test-Path -LiteralPath $configFile -PathType Leaf) -and ((Get-Content -LiteralPath $configFile -Raw -ErrorAction SilentlyContinue) -match '"secondbrain"')
                }
            }
            'windsurf' {
                $windsurfRoot = Join-Path $env:USERPROFILE '.codeium/windsurf'
                $configFile = Join-Path $windsurfRoot 'mcp_config.json'

                $snippetObj = [ordered]@{
                    mcpServers = [ordered]@{
                        secondbrain = [ordered]@{
                            command = 'pwsh'
                            args = @('-NoProfile', '-File', $serverScriptNormalized)
                        }
                    }
                }
                $json = ConvertTo-Json -InputObject $snippetObj -Depth 10

                $results += [PSCustomObject]@{
                    Target = 'windsurf'
                    Name = 'Windsurf'
                    ConfigFile = $configFile
                    ConfigFormat = 'json'
                    Toml = $null
                    Snippet = $json
                    CliCommand = $null
                    ServerDefinition = @{
                        command = 'pwsh'
                        args = @('-NoProfile', '-File', $serverScriptNormalized)
                    }
                    Configured = (Test-Path -LiteralPath $configFile -PathType Leaf) -and ((Get-Content -LiteralPath $configFile -Raw -ErrorAction SilentlyContinue) -match '"secondbrain"')
                }
            }
        }
    }

    if($OverrideConfigFile -and $results.Count -ne 1){throw (New-SBError 'mcp.pair.scope' @('ConfigFile','all'))}
    foreach($result in $results){
        if($OverrideConfigFile){$result.ConfigFile=[IO.Path]::GetFullPath($OverrideConfigFile)}
        $result | Add-Member Scope $effectiveScope
        if($OverrideConfigFile){
            $result.Configured=if($result.Target -in @('codex','claude-code')){(Test-SBMcpNativeDefinition $result).matches}
                else{[IO.File]::Exists($result.ConfigFile) -and (Read-SBText $result.ConfigFile) -match '"secondbrain"'}
        }
        $plan=Get-SBMcpPermissionPlan $result -ApproveAllTools:$ApproveAllTools
        $result | Add-Member PermissionPlan $plan
        $result | Add-Member PermissionsStatus $plan.status
        $result | Add-Member -NotePropertyName PermissionsSnippet -NotePropertyValue $plan.snippet -Force
    }

    if ($Target.ToLowerInvariant() -ne 'all' -and $results.Length -eq 1) {
        return $results[0]
    }
    return $results
}

function Set-SBMcpConfiguration {
    [CmdletBinding()]
    param(
        [string]$BrainRoot,
        [ValidateSet('codex','claude','claude-code','cursor','vscode','antigravity','windsurf','all')][string]$Target='all',
        [string]$WorkspacePath,[string]$ConfigFile,[string]$BackupRoot,
        [ValidateSet('user','project')][string]$Scope,[Alias('ApproveKnowledgeTools')][switch]$ApproveReadTools,
        [switch]$ApproveAllTools,[scriptblock]$CliInvoker
    )
    if(!$BrainRoot){$BrainRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))}
    $backupDir=if($BackupRoot){$BackupRoot}else{Join-Path $BrainRoot '.runtime/backups/mcp-pairing'}
    if($ApproveReadTools -and $ApproveAllTools){throw (New-SBError 'mcp.pair.permissions.scope')}
    $approvePermissions=$ApproveReadTools -or $ApproveAllTools
    $options=@{BrainRoot=$BrainRoot;Target=$Target;WorkspacePath=$WorkspacePath;ApproveAllTools=$ApproveAllTools;ConfigFile=$ConfigFile}
    if($Scope){$options.Scope=$Scope}
    $pairings=@(Get-SBMcpPairing @options)
    if($ConfigFile -and $pairings.Count -ne 1){throw (New-SBError 'mcp.pair.scope' @('ConfigFile','all'))}
    $applied=@()
    foreach($pairing in $pairings){
        $targetFile=$pairing.ConfigFile;$expectedHash=Get-SBFileHash $targetFile
        $backupPath=$null;$action='unchanged';$cliResult=$null;$permissionAction='not-requested'
        # Preflight all files before native registration or any write; JSONC is refused intact.
        $data=if($pairing.Target -ne 'codex'){Read-SBMcpSettings $targetFile}else{$null}
        $permissionHash=if($approvePermissions -and $pairing.PermissionPlan.path){Get-SBFileHash $pairing.PermissionPlan.path}else{$null}
        $permissionContent=if($approvePermissions){Get-SBMcpPermissionContent $pairing}else{$null}
        $native=$pairing.Target -in @('codex','claude-code')
        if($native){
            $state=Test-SBMcpNativeDefinition $pairing;$present=$state.present;$matches=$state.matches
            if($present -and !$matches){$action='conflict'}
            elseif(!$matches){
                $command=if($pairing.Target -eq 'codex'){'codex'}else{'claude'}
                if(!$CliInvoker -and !(Get-Command $command -CommandType Application -ErrorAction SilentlyContinue)){$action='cli-unavailable'}
                else{
                    $backupPath=Save-SBMcpNativeSnapshot $targetFile $backupDir $expectedHash
                    $argsList=if($command -eq 'codex'){@('mcp','add','secondbrain','--','pwsh','-NoProfile','-File',$pairing.ServerDefinition.args[2])}else{@('mcp','add','--transport','stdio','--scope',$pairing.Scope,'secondbrain','--','pwsh','-NoProfile','-File',$pairing.ServerDefinition.args[2])}
                    $cliEnvironment=@{}
                    if($command -eq 'codex'){$cliEnvironment.CODEX_HOME=Split-Path $targetFile}
                    elseif($pairing.Scope -eq 'user' -and $ConfigFile -and !(Test-SBSamePath (Split-Path $targetFile) $env:USERPROFILE)){$cliEnvironment.CLAUDE_CONFIG_DIR=Split-Path $targetFile}
                    $workingDirectory=if($pairing.Scope -eq 'project'){$WorkspacePath}else{$BrainRoot}
                    if((Get-SBFileHash $targetFile) -ne $expectedHash){throw (New-SBError 'core.concurrent.modified' @($targetFile))}
                    $cliResult=if($CliInvoker){& $CliInvoker $command $argsList $workingDirectory $cliEnvironment $targetFile $pairing.ServerDefinition}else{Invoke-SBMcpNative $command $argsList $workingDirectory $cliEnvironment}
                    $action=$cliResult.status
                    if($action -eq 'applied' -and !(Test-SBMcpNativeDefinition $pairing).matches){$action='cli-unverified'}

                }
            }
        }else{
            $key=if($pairing.Target -eq 'vscode'){'servers'}else{'mcpServers'}
            if(!$data.ContainsKey($key)){$data[$key]=@{}}
            if($data[$key] -isnot [Collections.IDictionary]){throw (New-SBError 'mcp.pair.json' @($targetFile))}
            # Preserve extension fields on an existing server entry.
            if(!$data[$key].Contains('secondbrain')){$data[$key].secondbrain=@{}}
            if($data[$key].secondbrain -isnot [Collections.IDictionary]){throw (New-SBError 'mcp.pair.json' @($targetFile))}
            $data[$key].secondbrain.command='pwsh';$data[$key].secondbrain.args=@($pairing.ServerDefinition.args)
            if($pairing.Target -eq 'vscode'){$data[$key].secondbrain.type='stdio'}
            $written=Write-SBFile $targetFile ([Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $data))) $expectedHash $backupDir
            if($written){$action=if($expectedHash -eq 'absent'){'created'}else{'updated'}}
            if($written -and $expectedHash -ne 'absent'){
                $meta=Get-ChildItem -LiteralPath $backupDir -Filter '*.bin.json' -File|Sort-Object LastWriteTimeUtc -Descending|Where-Object {(Read-SBJson $_.FullName @{}).path -eq $targetFile}|Select-Object -First 1
                if($meta){$backupPath=$meta.FullName.Substring(0,$meta.FullName.Length-5)}
            }
        }
        if($approvePermissions){
            if($pairing.PermissionPlan.status -ne 'supported'){$permissionAction=$pairing.PermissionPlan.status}
            elseif($action -in @('created','updated','applied','unchanged')){
                # Native registration changes config.toml: recompute only after checking its new hash.
                if($pairing.Target -eq 'codex'){$permissionHash=Get-SBFileHash $targetFile;$permissionContent=Get-SBMcpPermissionContent $pairing}
                $changed=Write-SBFile $pairing.PermissionPlan.path ([Text.Encoding]::UTF8.GetBytes($permissionContent)) $permissionHash $backupDir
                $permissionAction=if($changed){'applied'}else{'unchanged'}
            }else{$permissionAction='skipped'}
        }
        if($native -and $backupPath){
            $meta=Read-SBJson ($backupPath+'.json') @{};$meta.deployedHash=Get-SBFileHash $targetFile;$meta.status=$action
            [void](Write-SBFile ($backupPath+'.json') ([Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $meta))) (Get-SBFileHash ($backupPath+'.json')) $backupDir)
        }
        $applied+=[pscustomobject]@{Target=$pairing.Target;Name=$pairing.Name;Scope=$pairing.Scope;ConfigFile=$targetFile;Action=$action;BackupFile=$backupPath;PermissionAction=$permissionAction;PermissionStatus=$pairing.PermissionPlan.status;ManualStep=$pairing.PermissionPlan.manualStep;ClientSessionVerified=$false;CliResult=$cliResult}
    }
    if($Target -ne 'all'){return $applied[0]}
    $applied
}

function New-SBMcpDesktopBundle {
    $manifest = ConvertTo-SBMcpJson @{
        manifest_version='0.3';name='secondbrain';version=(Read-SBText (Join-Path $PSScriptRoot '../VERSION')).Trim()
        description='Launch the local SecondBrain MCP server';author=@{name='SecondBrain contributors'}
        compatibility=@{platforms=@('win32')}
        user_config=@{clone=@{type='directory';title='SecondBrain checkout';description='Select the local SecondBrain clone';required=$true}}
        server=@{type='node';entry_point='launcher.cjs';mcp_config=@{
            command='node';args=@('${__dirname}/launcher.cjs','${user_config.clone}')
        }}
        tools_generated=$true
    }
    $launcher = @'
const { spawn } = require('node:child_process');
const { join } = require('node:path');

const checkout = process.argv[2];
if (!checkout) {
  console.error('Select the SecondBrain checkout in the extension settings.');
  process.exitCode = 1;
} else {
  const server = spawn('pwsh', ['-NoProfile', '-File', join(checkout, 'scripts', 'mcp-server.ps1')], {
    stdio: 'inherit',
    windowsHide: true,
  });
  server.on('error', (error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
  server.on('exit', (code) => { process.exitCode = code ?? 1; });
}
'@
    $buffer = [IO.MemoryStream]::new()
    try {
        $archive = [IO.Compression.ZipArchive]::new($buffer,[IO.Compression.ZipArchiveMode]::Create,$true)
        try {
            foreach ($entry in @{ 'manifest.json'=$manifest; 'launcher.cjs'=$launcher }.GetEnumerator()) {
                $writer = [IO.StreamWriter]::new($archive.CreateEntry($entry.Key).Open(),[Text.UTF8Encoding]::new($false))
                try { $writer.Write($entry.Value) } finally { $writer.Dispose() }
            }
        } finally { $archive.Dispose() }
        return ,$buffer.ToArray()
    } finally { $buffer.Dispose() }
}

function New-SBMcpPackage {
    [CmdletBinding()]
    param(
        [string]$BrainRoot,
        [string]$OutDir
    )
    if (!$BrainRoot) {
        $BrainRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    }
    $BrainRoot = [IO.Path]::GetFullPath($BrainRoot)
    if (!$OutDir) {
        $OutDir = Join-Path $BrainRoot '.runtime/mcp-package'
    }
    $runtime = Join-Path $BrainRoot '.runtime'
    $OutDir = [IO.Path]::GetFullPath($OutDir).TrimEnd([char[]]@('/', '\'))
    $relative = [IO.Path]::GetRelativePath($runtime,$OutDir)
    if ($relative -in '.','..' -or $relative.StartsWith('..'+[IO.Path]::DirectorySeparatorChar) -or
        [IO.Path]::IsPathRooted($relative) -or $relative -match '[:]|[. ](?:[\\/]|$)') {
        throw (New-SBError 'mcp.package.destination' @($OutDir))
    }
    Assert-SBPlainPath $OutDir
    if (Test-Path -LiteralPath $OutDir) { throw (New-SBError 'mcp.package.destination' @($OutDir)) }

    $files = [ordered]@{}
    foreach ($pairing in Get-SBMcpPairing -BrainRoot $BrainRoot -Target all) {
        $name = switch ($pairing.Target) {
            'codex' { 'config.toml' }
            'claude' { 'claude_desktop_config.json' }
            'claude-code' { 'user-registration.json' }
            { $_ -in 'cursor','vscode' } { 'mcp.json' }
            default { 'mcp_config.json' }
        }
        $files["$($pairing.Target)/$name"] = $pairing.Snippet + "`n"
        if ($pairing.PermissionsSnippet) {
            $extension = if ($pairing.Target -eq 'codex') { 'toml' } else { 'json' }
            $files["$($pairing.Target)/permissions-preview.$extension"] = $pairing.PermissionsSnippet + "`n"
        }
    }
    $files['codex/snippet.toml'] = $files['codex/config.toml']
    $files['claude/secondbrain.mcpb'] = New-SBMcpDesktopBundle
    $files['SecondBrain.Messages.psm1'] = Read-SBText (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
    $server = @{command='pwsh';args=@('-NoProfile','-File',(Join-Path $BrainRoot 'scripts/mcp-server.ps1'))}
    $vsCode = ConvertTo-Json -InputObject ($server + @{name='secondbrain';type='stdio'}) -Compress
    $cursor = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes((ConvertTo-SBMcpJson $server)))

    $packageMessages = @{}
    foreach($key in @('mcp.package.root','mcp.package.applying')){
        $packageMessages[$key] = @{it=(Get-SBMessage $key @() 'it');en=(Get-SBMessage $key @() 'en')}
    }
    # Install script one-click
    $installContent = @(
        '#requires -Version 7.5',
        '<#',
        '.SYNOPSIS',
        'Installa automaticamente il server MCP SecondBrain in tutti gli IDE supportati.',
        '#>',
        '[CmdletBinding()]',
        'param([ValidateSet(''en'',''it'')][string]$Language,[switch]$ApproveKnowledgeTools)',
        'Import-Module (Join-Path $PSScriptRoot ''SecondBrain.Messages.psm1'') -Force',
        'if($Language){Set-SBUiLanguage $Language;$env:SECONDBRAIN_LANG=$Language}',
        ('Add-SBMessages (ConvertFrom-Json -AsHashtable -InputObject ''' + (ConvertTo-SBMcpJson $packageMessages).Replace("'","''") + ''')'),
        '$ErrorActionPreference = ''Stop''',
        "`$brain = '$($BrainRoot.Replace('\', '/').Replace("'", "''"))'",
        'if (!(Test-Path -LiteralPath (Join-Path $brain ''scripts/mcp-server.ps1''))) {',
        '    if ($env:SECONDBRAIN_HOME -and (Test-Path -LiteralPath (Join-Path $env:SECONDBRAIN_HOME ''scripts/mcp-server.ps1''))) {',
        '        $brain = $env:SECONDBRAIN_HOME',
        '    } else {',
        '        throw (New-SBError ''mcp.package.root'' @($brain))',
        '    }',
        '}',
        'Write-Host (Get-SBMessage ''mcp.package.applying'') -ForegroundColor Cyan',
        '$options = @{Pair=$true;Target=''all'';Apply=$true;ApproveReadTools=$ApproveKnowledgeTools}',
        '& (Join-Path $brain ''scripts/mcp-server.ps1'') @options'
    ) -join "`n"
    $files['install-all-ides.ps1'] = $installContent + "`n"
    $readmeContent = @(
        '# Pacchetto di Configurazione MCP: SecondBrain',
        '',
        'Questo pacchetto contiene le configurazioni pronte all''uso per integrare il server locale **Model Context Protocol (MCP)** di SecondBrain (`scripts/mcp-server.ps1`) negli IDE supportati.',
        '',
        '## 1. Installazione Rapida Automatica',
        'Per applicare automaticamente la configurazione a tutti gli IDE rilevati con backup preventivo del file originale:',
        '```powershell',
        'pwsh -NoProfile -File install-all-ides.ps1',
        '```',
        '',
        'Oppure direttamente dalla radice di SecondBrain:',
        '```powershell',
        'pwsh -NoProfile -File scripts/mcp-server.ps1 -Pair -Target all -Apply',
        '```',
        '',
        '---',
        '',
        'I consensi sono opzionali. Riesaminare i file permissions-preview prima di usare -ApproveKnowledgeTools. Il piano mantiene la conferma per check_publication.',
        '',
        '- Claude Desktop: aprire claude/secondbrain.mcpb e selezionare il clone locale. Richiede PowerShell 7.5+ sul PATH.',
        ('- Cursor: [Importa SecondBrain](cursor://anysphere.cursor-deeplink/mcp/install?name=secondbrain&config=' + [uri]::EscapeDataString($cursor) + ')'),
        '- VS Code, da PowerShell:',
        '',
        '```powershell',
        ("code --add-mcp '" + $vsCode.Replace("'", "''") + "'"),
        '```',
        '',
        '- Codex: usare scripts/mcp-server.ps1 -Pair -Target codex -Apply dal clone.',
        '- Claude Code: usare scripts/mcp-server.ps1 -Pair -Target claude-code -Apply dal clone.',
        '- Antigravity 2.x: per un progetto usare -Pair -Target antigravity -Scope project -WorkspacePath <progetto> -Apply (.agents/mcp_config.json).',
        '',
        'I frammenti e i link sono specifici del clone di esportazione. Il bundle Desktop chiede la radice alla persona che lo importa.',
        '',
        '## 2. Installazione Manuale per Singolo IDE',
        '',
        '| IDE | File nel pacchetto | Destinazione nel sistema |',
        '| :--- | :--- | :--- |',
        '| **OpenAI Codex** | `codex/snippet.toml` | `%USERPROFILE%\.codex\config.toml` |',
        '| **Claude Desktop** | `claude/claude_desktop_config.json` | `%APPDATA%\Claude\claude_desktop_config.json` |',
        '| **Cursor IDE** | `cursor/mcp.json` | `%USERPROFILE%\.cursor\mcp.json` |',
        '| **VS Code** | `vscode/mcp.json` | `%APPDATA%\Code\User\mcp.json` (oppure `.vscode/mcp.json` del progetto) |',
        '| **Claude Code** | `claude-code/user-registration.json` (frammento, usare la CLI) | `claude mcp add --transport stdio --scope user secondbrain -- pwsh -NoProfile -File <radice>/scripts/mcp-server.ps1`, oppure `.mcp.json` del progetto con `-Pair -Target claude-code -WorkspacePath <progetto> -Apply` |',
        '| **Google Antigravity** | `antigravity/mcp_config.json` | `%USERPROFILE%\.gemini\config\mcp_config.json` (legacy esistente riconosciuto) |',
        '| **Windsurf** | `windsurf/mcp_config.json` | `%USERPROFILE%\.codeium\windsurf\mcp_config.json` |',
        '',
        '---',
        '',
        '## 3. Verifica Connessione JSON-RPC',
        'Dal clone, inviare una richiesta di test al server:',
        '```powershell',
        '''{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'' | pwsh -NoProfile -File scripts/mcp-server.ps1 -NoRecovery',
        '```'
    ) -join "`n"
    $files['README.md'] = $readmeContent + "`n"
    $checksums = foreach ($name in @($files.Keys)) {
        if ($files[$name] -is [string]) { $files[$name] = [Text.Encoding]::UTF8.GetBytes($files[$name]) }
        "$(Get-SBHash $files[$name])  $name"
    }
    $files['SHA256SUMS'] = [Text.Encoding]::UTF8.GetBytes(($checksums -join "`n") + "`n")
    $lock = Enter-SBOperation @{coordinationRoot=(Join-Path $runtime 'access');brainRoot=$BrainRoot;workstationId='non-attivata'} -LockOnly
    try {
        Assert-SBPlainPath $OutDir
        if (Test-Path -LiteralPath $OutDir) { throw (New-SBError 'mcp.package.destination' @($OutDir)) }
        $createdFiles = foreach ($name in $files.Keys) {
            $destination = Join-Path $OutDir $name
            Write-SBFile $destination $files[$name] 'absent' (Join-Path $runtime 'backups') | Out-Null
            $destination
        }
    } finally { Exit-SBOperation $lock }

    return [PSCustomObject]@{
        PackageDir = $OutDir
        FileCount = $createdFiles.Count
        Files = $createdFiles
    }
}

Export-ModuleMember -Function @(
    'Invoke-SBMcpToolCall',
    'Get-SBMcpDeprecatedToolAliases',
    'Get-SBMcpDeprecationNotice',
    'Invoke-SBMcpMessage',
    'Start-SBMcpServer',
    'Get-SBMcpPairing',
    'Get-SBMcpReadOnlyToolNames',
    'Get-SBMcpKnowledgeToolNames',
    'Set-SBMcpConfiguration',
    'New-SBMcpPackage'
)
