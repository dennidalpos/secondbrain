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
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Host.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Pending.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.McpWrites.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.TaskRunner.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.RunnerStatus.psm1')
Add-SBMessages @{
    'mcp.title.preview_dossier_write' = @{it='Anteprima scrittura dossier';en='Preview dossier write'}
    'mcp.title.submit_dossier_write' = @{it='Invia scrittura approvata';en='Submit approved write'}
    'mcp.write.param.requestId' = @{it='ID idempotente della richiesta: 32 cifre esadecimali minuscole';en='Idempotent request ID: 32 lowercase hexadecimal characters'}
    'mcp.write.param.operation' = @{it='Operazione ristretta da preparare';en='Restricted operation to preview'}
    'mcp.write.param.payload' = @{it='Dati dell operazione: task.status (taskId,status,reason?), task.update (taskId e almeno uno fra status?,reason?,priority?,execution?,stream?,awaiting?,requires?,evidence? (array di "riferimento|esito" o {reference,outcome}, accodate); stringa o array vuoti azzerano), task.new (title,acceptance,provenance,description?,priority?,pointer?,requires?), memory.append (content), activity.append (taskId,sessionId,when,outcome,detail), history.save (path,content)';en='Operation data: task.status (taskId,status,reason?), task.update (taskId plus at least one of status?,reason?,priority?,execution?,stream?,awaiting?,requires?,evidence? (array of "reference|outcome" or {reference,outcome}, appended); an empty string or array clears the field), task.new (title,acceptance,provenance,description?,priority?,pointer?,requires?), memory.append (content), activity.append (taskId,sessionId,when,outcome,detail), history.save (path,content)'}
    'mcp.write.param.planHash' = @{it='SHA-256 del piano esatto approvato tramite CLI';en='SHA-256 of the exact plan approved through the CLI'}
    'mcp.write.preview.description' = @{it='Prepara senza scrivere il piano di una scrittura di dossier; approvarlo con mcp-write.ps1 prima di submit_dossier_write.';en='Previews a dossier write plan without writing; approve it with mcp-write.ps1 before submit_dossier_write.'}
    'mcp.write.submit.description' = @{it='Accoda una richiesta idempotente approvata dalla ricevuta CLI locale; gli argomenti MCP non concedono approvazioni.';en='Queues one idempotent request approved by the local CLI receipt; MCP arguments cannot grant approval.'}
    'mcp.pending.disabled' = @{it='Consultazione senza scritture: nuove scritture MCP disabilitate per questa sessione o richiesta.';en='Read-only consultation: new MCP writes disabled for this session or request.'}
    'mcp.description.noRecovery' = @{ it = 'Vieta scritture in questa chiamata'; en = 'Forbid writes in this call' }
    'mcp.title.get_startup_context' = @{ it = 'Contesto iniziale'; en = 'Startup context' }
    'mcp.title.get_ready_tasks' = @{ it = 'Attività pronte'; en = 'Ready tasks' }
    'mcp.title.get_task' = @{ it = 'Dettaglio attività'; en = 'Task details' }
    'mcp.title.search_knowledge' = @{ it = 'Cerca nella conoscenza'; en = 'Search knowledge' }
    'mcp.title.list_prompts' = @{ it = 'Elenco prompt'; en = 'List prompts' }
    'mcp.title.get_prompt_home' = @{ it = 'Menu dei prompt'; en = 'Prompt home' }
    'mcp.title.get_prompt' = @{ it = 'Scheda prompt'; en = 'Prompt card' }
    'mcp.title.check_publication' = @{ it = 'Verifica pubblicabilità'; en = 'Publication check' }
    'mcp.title.list_ides' = @{ it = 'IDE rilevate'; en = 'Detected IDEs' }
    'mcp.description.list_ides' = @{ it = 'IDE e client AI rilevati, con evidenze e ambiti (user, project, system).'; en = 'Detected IDEs and AI clients, with evidence and scopes (user, project, system).' }
    'mcp.description.list_ides.workspacePath' = @{ it = 'Percorso del progetto (ambito project)'; en = 'Project path (project scope)' }
    'mcp.title.get_runner_status' = @{ it = 'Stato del runner'; en = 'Runner status' }
    'mcp.description.get_runner_status' = @{ it = 'Runner dei task del repository: in lavoro, possibile stallo, concluso o orfano, con gli ultimi eventi.'; en = 'Task runner of the repository: working, possibly stalled, finished or orphaned, with the latest events.' }
    'mcp.description.get_runner_status.tail' = @{ it = 'Eventi recenti (20)'; en = 'Recent events (20)' }
    'mcp.pending.contract' = @{it='Sola lettura: non integra mai scritture accodate. Il recupero e solo esplicito (knowledge.ps1 -FlushPending, limitato al proprio dossier).';en='Read-only: never integrates queued writes. Recovery is explicit only (knowledge.ps1 -FlushPending, limited to the own dossier).'}
    'mcp.json.parse' = @{ it = 'Errore di parsing: {0}'; en = 'Parse error: {0}' }
    'mcp.json.request' = @{ it = 'Richiesta non valida: jsonrpc deve essere 2.0'; en = 'Invalid Request: jsonrpc must be 2.0' }
    'mcp.json.method' = @{ it = 'Metodo non trovato: {0}'; en = 'Method not found: {0}' }
    'mcp.json.internal' = @{ it = 'Errore interno: {0}'; en = 'Internal error: {0}' }
    'mcp.description.get_startup_context' = @{ it = 'Contesto di avvio. slim (predefinito): parti essenziali entro il tetto; full: completo. Revisione invariata: nessuna parte ripetuta.'; en = 'Startup context. slim (default): essential parts within the cap; full: complete. Unchanged revision: no parts repeated.' }
    'mcp.description.get_startup_context.repository' = @{ it = 'Identità del repository; predefinito: checkout in lavoro'; en = 'Repository identity; default: working checkout' }
    'mcp.description.get_startup_context.checkoutPath' = @{ it = 'Checkout da cui risolvere il repository'; en = 'Checkout used to resolve the repository' }
    'mcp.description.get_startup_context.dossier' = @{ it = 'Dossier relativo (es. 01-projects/X)'; en = 'Relative dossier (e.g. 01-projects/X)' }
    'mcp.description.get_startup_context.readyOnly' = @{ it = 'Solo task con dipendenze soddisfatte'; en = 'Only tasks with satisfied dependencies' }
    'mcp.description.get_startup_context.previousRevision' = @{ it = 'Revisione precedente: se invariata, changed=false'; en = 'Previous revision: if unchanged, changed=false' }
    'mcp.description.get_startup_context.taskIds' = @{ it = 'ID dei task da includere'; en = 'Task IDs to include' }
    'mcp.description.get_startup_context.profile' = @{ it = 'slim o full'; en = 'slim or full' }
    'mcp.description.get_startup_context.budget' = @{ it = 'Tetto di caratteri (0 = nessuno)'; en = 'Character cap (0 = none)' }
    'mcp.description.get_ready_tasks' = @{ it = 'Task pronti del repository in lavoro; all=true per la vista globale.'; en = 'Ready tasks of the working repository; all=true for the global view.' }
    'mcp.description.get_ready_tasks.repository' = @{ it = 'Identità del repository'; en = 'Repository identity' }
    'mcp.description.get_ready_tasks.checkoutPath' = @{ it = 'Checkout da cui risolvere il repository'; en = 'Checkout used to resolve the repository' }
    'mcp.description.get_ready_tasks.all' = @{ it = 'Vista globale'; en = 'Global view' }
    'mcp.description.get_ready_tasks.includeAcceptance' = @{ it = 'Includi i criteri di accettazione'; en = 'Include acceptance criteria' }
    'mcp.description.get_ready_tasks.offset' = @{ it = 'Con all: task da saltare'; en = 'With all: tasks to skip' }
    'mcp.description.get_ready_tasks.limit' = @{ it = 'Con all: task per pagina (50; 0 = tutti)'; en = 'With all: tasks per page (50; 0 = all)' }
    'mcp.description.get_task' = @{ it = 'Dettaglio integro di un task per ID o #seq, anche archiviato.'; en = 'Complete task details by ID or #seq, archived included.' }
    'mcp.description.get_task.task' = @{ it = 'ID o numero seq'; en = 'ID or sequence number' }
    'mcp.description.get_task.repository' = @{ it = 'Identità del repository'; en = 'Repository identity' }
    'mcp.description.get_task.checkoutPath' = @{ it = 'Checkout da cui risolvere il repository'; en = 'Checkout used to resolve the repository' }
    'mcp.description.get_task.dossier' = @{ it = 'Dossier relativo'; en = 'Relative dossier' }
    'mcp.description.search_knowledge' = @{ it = 'Cerca nel dossier del repository in lavoro (contesto, memoria, tracker, archivio, rapporti). 20 riscontri e 10000 caratteri; con hasMore usare offset=nextOffset.'; en = 'Search the working repository dossier (context, memory, tracker, archive, reports). 20 matches and 10000 characters; with hasMore use offset=nextOffset.' }
    'mcp.description.search_knowledge.query' = @{ it = 'Testo da cercare'; en = 'Text to search' }
    'mcp.description.search_knowledge.budget' = @{ it = 'Tetto di caratteri (0 = nessuno)'; en = 'Character cap (0 = none)' }
    'mcp.description.search_knowledge.allDossiers' = @{ it = 'Tutti i dossier attivi'; en = 'All active dossiers' }
    'mcp.description.search_knowledge.customer' = @{ it = 'Cliente (campo customer di repository.json): limita ai dossier del cliente'; en = 'Customer (repository.json customer field): restrict to the customer''s dossiers' }
    'mcp.description.search_knowledge.includeOriginals' = @{ it = 'Includi gli originali compattati'; en = 'Include compacted originals' }
    'mcp.description.search_knowledge.dossier' = @{ it = 'Dossier relativo'; en = 'Relative dossier' }
    'mcp.description.search_knowledge.repository' = @{ it = 'Identità del repository'; en = 'Repository identity' }
    'mcp.description.search_knowledge.mode' = @{ it = 'literal: sottostringa; relevance: termini per pertinenza'; en = 'literal: substring; relevance: ranked terms' }
    'mcp.description.search_knowledge.offset' = @{ it = 'Riscontri da saltare'; en = 'Matches to skip' }
    'mcp.description.search_knowledge.category' = @{ it = 'Categorie (predefinito: tutte tranne prompt)'; en = 'Categories (default: all but prompt)' }
    'mcp.description.search_knowledge.previousRevision' = @{ it = 'Revisione precedente: se invariata, unchanged=true'; en = 'Previous revision: if unchanged, unchanged=true' }
    'mcp.description.search_knowledge.limit' = @{ it = 'Riscontri massimi (0 = tutti)'; en = 'Maximum matches (0 = all)' }
    'mcp.description.list_prompts' = @{ it = 'Catalogo dei prompt per area; compact=true una riga per prompt, da riportare integralmente.'; en = 'Prompt catalog by category; compact=true gives one line per prompt, to report in full.' }
    'mcp.description.list_prompts.category' = @{ it = 'Area o prefisso del codice'; en = 'Category or code prefix' }
    'mcp.description.list_prompts.compact' = @{ it = 'Una riga per prompt'; en = 'One line per prompt' }
    'mcp.description.list_prompts.language' = @{ it = 'Lingua (en, it)'; en = 'Language (en, it)' }
    'mcp.description.get_prompt_home' = @{ it = 'Schermata di sb prompt: comandi sb e script; con repositoryPath stato e prossimo passo.'; en = 'sb prompt screen: sb commands and scripts; with repositoryPath, state and next step.' }
    'mcp.description.get_prompt_home.repositoryPath' = @{ it = 'Checkout corrente'; en = 'Working checkout' }
    'mcp.description.get_prompt_home.language' = @{ it = 'Lingua (en, it)'; en = 'Language (en, it)' }
    'mcp.description.get_prompt' = @{ it = 'Prompt composto per codice o ID (es. SYS03); objective imposta l''obiettivo.'; en = 'Composed prompt by code or ID (e.g. SYS03); objective sets the goal.' }
    'mcp.description.get_prompt.prompt' = @{ it = 'Codice, ID pmt-... o alias'; en = 'Code, pmt-... ID or alias' }
    'mcp.description.get_prompt.language' = @{ it = 'Lingua (en, it)'; en = 'Language (en, it)' }
    'mcp.description.check_publication' = @{ it = 'Verifica di pubblicabilità (working tree, indice, storia): riepilogo; detail=true rapporto integro.'; en = 'Publication check (working tree, index, history): summary; detail=true full report.' }
    'mcp.description.check_publication.repositoryPath' = @{ it = 'Radice o checkout Git'; en = 'Git root or checkout' }
    'mcp.description.check_publication.detail' = @{ it = 'Rapporto integro'; en = 'Full report' }
    'mcp.prompt.objective' = @{ it = 'Obiettivo'; en = 'Objective' }
    'mcp.resource.catalog' = @{ it = 'Catalogo Prompt e Workflow SecondBrain'; en = 'SecondBrain Prompt and Workflow Catalog' }
    'mcp.tool.failed' = @{ it = 'Errore durante l''esecuzione dello strumento {0}: {1}'; en = 'Error executing tool {0}: {1}' }
    'mcp.notice' = @{ it = 'Avviso: {0}'; en = 'Warning: {0}' }
    'mcp.repository.unresolved' = @{ it = 'Repository in lavoro non risolvibile: indicare repository o checkoutPath (oppure all=true per la vista globale)'; en = 'Working repository not resolvable: give repository or checkoutPath (or all=true for the global view)' }
    'mcp.profile.invalid' = @{ it = 'Profilo non valido: usare slim o full'; en = 'Invalid profile: use slim or full' }
    'mcp.params.conflict' = @{ it = 'Parametri incompatibili: all e repository. Usa solo uno dei due'; en = 'Incompatible parameters: all and repository. Use only one of them' }
    'mcp.paging.invalid' = @{ it = 'offset e limit devono essere interi non negativi'; en = 'offset and limit must be non-negative integers' }
    'mcp.task.required' = @{ it = 'Il parametro task è obbligatorio per get_task'; en = 'The task parameter is required for get_task' }
    'mcp.query.required' = @{ it = 'Il parametro query è obbligatorio per search_knowledge'; en = 'The query parameter is required for search_knowledge' }
    'mcp.mode.invalid' = @{ it = 'Modalità non valida: usare literal o relevance'; en = 'Invalid mode: use literal or relevance' }
    'mcp.search.invalid' = @{ it = 'offset, limit e budget devono essere interi non negativi'; en = 'offset, limit and budget must be non-negative integers' }
    'mcp.startup.invalid' = @{ it = 'budget deve essere un intero non negativo e taskIds un array di ID'; en = 'budget must be a non-negative integer and taskIds an array of IDs' }
    'mcp.description.get_prompt.repositoryPath' = @{ it = 'Checkout del repository corrente (facoltativo): aggiunge contesto e task pronti ai prossimi passi; senza dossier la composizione resta autonoma.'; en = 'Current repository checkout (optional): adds context and ready tasks to the next steps; without a dossier the composition stays standalone.' }
    'mcp.prompt.required' = @{ it = 'Il parametro prompt è obbligatorio per get_prompt'; en = 'The prompt parameter is required for get_prompt' }
    'mcp.path.required' = @{ it = 'Il parametro repositoryPath è obbligatorio per check_publication'; en = 'The repositoryPath parameter is required for check_publication' }
    'mcp.tool.deprecated' = @{ it = 'Alias deprecato {0}: usare {1}. Lʼalias sarà rimosso in una versione futura.'; en = 'Deprecated alias {0}: use {1}. The alias will be removed in a future version.' }
    'mcp.language.invalid' = @{ it = 'Lingua non valida: usare en o it'; en = 'Invalid language: use en or it' }
    'mcp.tool.unknown' = @{ it = 'Strumento sconosciuto: {0}'; en = 'Unknown tool: {0}' }
    'mcp.resource.notfound' = @{ it = 'Risorsa non trovata: {0}'; en = 'Resource not found: {0}' }
}

function ConvertTo-SBMcpJson($Value) {
    if ($null -eq $Value) { return $null }
    ConvertTo-SBStableValue $Value | ConvertTo-Json -Depth 40 -Compress
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
                    customer = @{ type = 'string'; description = (Get-SBMessage 'mcp.description.search_knowledge.customer') }
                    includeOriginals = @{ type = 'boolean'; description = (Get-SBMessage 'mcp.description.search_knowledge.includeOriginals') }
                    dossier = @{ type = 'string'; description = (Get-SBMessage 'mcp.description.search_knowledge.dossier') }
                    repository = @{ type = 'string'; description = (Get-SBMessage 'mcp.description.search_knowledge.repository') }
                    mode = @{ type = 'string'; enum = @('literal', 'relevance'); description = (Get-SBMessage 'mcp.description.search_knowledge.mode') }
                    offset = @{ type = 'integer'; description = (Get-SBMessage 'mcp.description.search_knowledge.offset') }
                    limit = @{ type = 'integer'; description = (Get-SBMessage 'mcp.description.search_knowledge.limit') }
                    category = @{ type = 'array'; items = @{ type = 'string'; enum = @('memoria', 'informazioni', 'normative', 'policy', 'prompt') }; description = (Get-SBMessage 'mcp.description.search_knowledge.category') }
                    previousRevision = @{ type = 'string'; description = (Get-SBMessage 'mcp.description.search_knowledge.previousRevision') }
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
                    repositoryPath = @{ type = 'string'; description = (Get-SBMessage 'mcp.description.get_prompt.repositoryPath') }
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
        },
        @{
            name = 'list_ides'
            description = (Get-SBMessage 'mcp.description.list_ides')
            inputSchema = @{
                type = 'object'
                properties = @{
                    workspacePath = @{ type = 'string'; description = (Get-SBMessage 'mcp.description.list_ides.workspacePath') }
                }
            }
        },
        @{
            name = 'get_runner_status'
            description = (Get-SBMessage 'mcp.description.get_runner_status')
            inputSchema = @{
                type = 'object'
                properties = @{
                    repository = @{ type = 'string'; description = (Get-SBMessage 'mcp.description.get_ready_tasks.repository') }
                    checkoutPath = @{ type = 'string'; description = (Get-SBMessage 'mcp.description.get_ready_tasks.checkoutPath') }
                    tail = @{ type = 'integer'; description = (Get-SBMessage 'mcp.description.get_runner_status.tail') }
                }
            }
        }
    )
    $scopeProperties=@{repository=@{type='string';description=(Get-SBMessage 'mcp.description.get_task.repository')};checkoutPath=@{type='string';description=(Get-SBMessage 'mcp.description.get_startup_context.checkoutPath')};requestId=@{type='string';pattern='^[a-f0-9]{32}$';description=(Get-SBMessage 'mcp.write.param.requestId')}}
    $previewProperties=@{}+$scopeProperties
    $previewProperties.operation=@{type='string';description=(Get-SBMessage 'mcp.write.param.operation');enum=@('task.status','task.update','task.new','memory.append','activity.append','history.save')}
    $previewProperties.payload=@{type='object';description=(Get-SBMessage 'mcp.write.param.payload')}
    $submitProperties=@{}+$scopeProperties
    $submitProperties.planHash=@{type='string';pattern='^[A-F0-9]{64}$';description=(Get-SBMessage 'mcp.write.param.planHash')}
    $definitions+=@(
        @{name='preview_dossier_write';description=(Get-SBMessage 'mcp.write.preview.description');inputSchema=@{type='object';additionalProperties=$false;required=@('repository','checkoutPath','requestId','operation','payload');properties=$previewProperties}}
        @{name='submit_dossier_write';description=(Get-SBMessage 'mcp.write.submit.description');inputSchema=@{type='object';additionalProperties=$false;required=@('repository','checkoutPath','requestId','planHash');properties=$submitProperties}}
    )
    foreach($definition in $definitions){
        $definition.inputSchema.properties.noRecovery=@{type='boolean';description=(Get-SBMessage 'mcp.description.noRecovery')}
        # The read-only contract (mcp.pending.contract) is stated once in the initialize instructions and in readOnlyHint, not repeated per tool.
        # #474: every tool except submit_dossier_write is a pure read (readOnlyHint); submit applies one reviewed request.
        $definition.annotations=@{title=(Get-SBMessage ('mcp.title.'+$definition.name));readOnlyHint=$true;destructiveHint=$false;idempotentHint=$true;openWorldHint=$false}
        if($definition.name -eq 'submit_dossier_write'){$definition.annotations.readOnlyHint=$false;$definition.annotations.destructiveHint=$true}
        $definition
    }
}


function Resolve-SBMcpRepository([string]$BrainRoot, $Arguments) {
    # Explicit repository, otherwise the working checkout's repository (checkoutPath argument or server current directory).
    if ($Arguments.ContainsKey('repository') -and $Arguments.repository) { Assert-SBRunnerReadScope -Repository ([string]$Arguments.repository); return [string]$Arguments.repository }
    $checkout = if ($Arguments.ContainsKey('checkoutPath') -and $Arguments.checkoutPath) { [string]$Arguments.checkoutPath } else { '' }
    $bindings = @()
    try { $bindings = @((Read-SBConfiguration -ReadOnly).bindings) } catch { Write-Verbose $_.Exception.Message }
    $resolved = Resolve-SBWorkingRepository $checkout $bindings
    if (!$resolved) { throw (New-SBError 'mcp.repository.unresolved') }
    # Runner sessions (#382): only the task repository or its read allowlist; no effect outside a runner session.
    Assert-SBRunnerReadScope -Repository $resolved
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
            if ($dossier) { Assert-SBRunnerReadScope -Dossier $dossier -BrainRoot $BrainRoot }

            if (!$dossier) {
                # Never default to the brain repository: the dossier follows the explicit repository or working checkout.
                $repo = Resolve-SBMcpRepository $BrainRoot $Arguments
                $dossier = Resolve-SBWorkingDossier $BrainRoot $repo
            }
            $dossierPath = if ([IO.Path]::IsPathRooted($dossier)) { $dossier } else { Join-Path $BrainRoot $dossier }

            if($Arguments.ContainsKey('previousRevision') -and $Arguments.previousRevision -isnot [string]){throw (New-SBError 'mcp.startup.invalid')}
            $previousRevision=if($Arguments.ContainsKey('previousRevision')){$Arguments.previousRevision}else{''}
            $ctx = Get-SBStartupContext -BrainRoot $BrainRoot -Dossier $dossierPath -Budget $budget -ReadyOnly:$readyOnly -TaskIds $taskIds -Profile $startupProfile -PreviousRevision $previousRevision -DirectiveCheckout $(if($Arguments.ContainsKey('checkoutPath') -and $Arguments.checkoutPath -is [string]){$Arguments.checkoutPath})
            return ConvertTo-SBMcpJson $ctx
        }
        'get_ready_tasks' {
            $all = $Arguments.ContainsKey('all') -and [bool]$Arguments.all
            if ($all -and $Arguments.ContainsKey('repository') -and $Arguments.repository) { throw (New-SBError 'mcp.params.conflict') }
            if ($all) { Assert-SBRunnerReadScope -Global; Assert-SBProjectIsolation $BrainRoot }
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
            $dossier = if ($Arguments.ContainsKey('dossier') -and $Arguments.dossier) { Assert-SBRunnerReadScope -Dossier ([string]$Arguments.dossier) -BrainRoot $BrainRoot; [string]$Arguments.dossier } else { Resolve-SBWorkingDossier $BrainRoot (Resolve-SBMcpRepository $BrainRoot $Arguments) }
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
            $customer = if ($Arguments.ContainsKey('customer') -and $Arguments.customer) { ([string]$Arguments.customer).Trim() } else { '' }
            # A customer without dossier/repository selects all of its dossiers: same global scope as allDossiers.
            if ($customer -and !$dossier -and !$repo) { $allDossiers = $true }
            $includeOriginals = $Arguments.ContainsKey('includeOriginals') -and [bool]$Arguments.includeOriginals
            # Default scope: working checkout's repository, if resolvable; otherwise refused by project isolation.
            if (!$dossier -and !$repo -and !$allDossiers) {
                try { $repo = Resolve-SBMcpRepository $BrainRoot $Arguments } catch { $repo = $null }
            }
            # Runner sessions: no global search, explicit scopes checked, an unresolvable scope falls back to the task repository instead of all dossiers.
            if ($allDossiers) { Assert-SBRunnerReadScope -Global; Assert-SBProjectIsolation $BrainRoot }
            if ($dossier) { Assert-SBRunnerReadScope -Dossier $dossier -BrainRoot $BrainRoot }
            if ($repo) { Assert-SBRunnerReadScope -Repository $repo }
            $runnerScope = Get-SBRunnerReadScope
            if ($runnerScope -and !$dossier -and !$repo) { $repo = $runnerScope.repository }
            if (!$dossier -and !$repo -and !$allDossiers) { Assert-SBProjectIsolation $BrainRoot }

            $mode = if ($Arguments.ContainsKey('mode') -and $Arguments.mode) { [string]$Arguments.mode } else { 'literal' }
            if ($mode -notin @('literal', 'relevance')) { throw (New-SBError 'mcp.mode.invalid') }
            $mode = if ($mode -eq 'relevance') { 'Relevance' } else { 'Literal' }

            $offset = if ($Arguments.ContainsKey('offset') -and $Arguments.offset) { [int]$Arguments.offset } else { 0 }
            $limit = if ($Arguments.ContainsKey('limit') -and $null -ne $Arguments.limit) { [int]$Arguments.limit } else { -1 }
            if ($offset -lt 0 -or $limit -lt -1 -or $budget -lt -1) { throw (New-SBError 'mcp.search.invalid') }

            $searchCategory = @()
            if ($Arguments.ContainsKey('category') -and $null -ne $Arguments.category) {
                $searchCategory = @($Arguments.category | ForEach-Object { [string]$_ })
                if (@($searchCategory | Where-Object { $_ -cnotin @('memoria', 'informazioni', 'normative', 'policy', 'prompt') }).Count) { throw (New-SBError 'mcp.search.invalid') }
            }
            $previousRevision = if ($Arguments.ContainsKey('previousRevision') -and $Arguments.previousRevision) { [string]$Arguments.previousRevision } else { '' }
            $res = Find-SBKnowledge -BrainRoot $BrainRoot -Search $query -Dossier $dossier -Repository $repo -Customer $customer -Budget $budget -Mode $mode -Offset $offset -Limit $limit -IncludeOriginals:$includeOriginals -Category $searchCategory -PreviousRevision $previousRevision
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
            # With repositoryPath the composition carries that repository's context and ready tasks in next_steps; a checkout without
            # a dossier (or any context error) falls back to the standalone composition.
            $context = @{repositories=@();project=$null;sourceRegistry=$null}
            if ($Arguments.ContainsKey('repositoryPath') -and $Arguments.repositoryPath) {
                try { $context = Get-SBWorkflowContext -Config (Read-SBConfiguration -ReadOnly) -RepositoryPath ([string]$Arguments.repositoryPath) } catch { Write-Verbose $_.Exception.Message }
            }
            if (@($context.repositories).Count) {
                # A central prompt outside the SecondBrain checkout keeps the standalone composition it always had.
                try { return New-SBWorkflowComposition $BrainRoot $catalog $resolution.prompt $context $objective } catch { Write-Verbose $_.Exception.Message }
                $context = @{repositories=@();project=$null;sourceRegistry=$null}
            }
            return New-SBWorkflowComposition $BrainRoot $catalog $resolution.prompt $context $objective -Standalone
        }
        'preview_dossier_write' {
            Assert-SBMcpWriteFields $Arguments @('repository','checkoutPath','requestId','operation','payload','noRecovery') @('repository','checkoutPath','requestId','operation','payload')
            Assert-SBRunnerReadScope -Repository ([string]$Arguments.repository) -Write
            return ConvertTo-SBMcpJson (New-SBMcpWritePlan $BrainRoot $script:SBMcpConfigPath $Arguments.repository $Arguments.checkoutPath $Arguments.requestId $Arguments.operation $Arguments.payload)
        }
        'submit_dossier_write' {
            Assert-SBMcpWriteFields $Arguments @('repository','checkoutPath','requestId','planHash','noRecovery') @('repository','checkoutPath','requestId','planHash')
            Assert-SBRunnerReadScope -Repository ([string]$Arguments.repository) -Write
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
        'get_runner_status' {
            # Read-only: status.json and events.jsonl of the repository's runs on this workstation (the same view as runner-status.ps1).
            $repo = Resolve-SBMcpRepository $BrainRoot $Arguments
            $tail = if ($Arguments.ContainsKey('tail') -and $null -ne $Arguments.tail) { [int]$Arguments.tail } else { 20 }
            if ($tail -lt 0) { throw (New-SBError 'mcp.paging.invalid') }
            $config = Read-SBConfiguration -ReadOnly
            return ConvertTo-SBMcpJson (Get-SBRunnerStatus -BrainRoot $config.brainRoot -HostId $config.workstationId -Repository $repo -Tail $tail)
        }
        'list_ides' {
            $workspace = ''
            if ($Arguments.ContainsKey('workspacePath') -and $Arguments.workspacePath) {
                $workspace = [string]$Arguments.workspacePath
                if (![IO.Path]::IsPathFullyQualified($workspace) -or !(Test-Path -LiteralPath $workspace -PathType Container)) { throw (New-SBError 'mcp.path.required') }
            }
            return ConvertTo-SBMcpJson @{ ides = @(Get-SBIDEDetection $workspace) }
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
        # #474: no method integrates pending writes; the server only reads. noRecovery now only forbids new writes.
        $skipRecovery=([bool](Get-Variable -Name SBMcpNoRecovery -Scope Script -ValueOnly -ErrorAction SilentlyContinue))
        if($params -is [Collections.IDictionary]){
            if($params.ContainsKey('_meta') -and $params._meta -is [Collections.IDictionary] -and $params._meta.ContainsKey('noRecovery') -and $params._meta.noRecovery -eq $true){$skipRecovery=$true}
            if($params.ContainsKey('arguments') -and $params.arguments -is [Collections.IDictionary] -and $params.arguments.ContainsKey('noRecovery') -and $params.arguments.noRecovery -eq $true){$skipRecovery=$true}
        }
        switch ($method) {
            'initialize' {
                return ConvertTo-SBMcpJson @{
                    jsonrpc = '2.0'
                    id = $id
                    result = @{
                        protocolVersion = $(if($params.ContainsKey('protocolVersion') -and $params.protocolVersion -eq '2024-11-05'){'2024-11-05'}else{'2025-03-26'})
                        instructions = $(if($skipRecovery){Get-SBMessage 'mcp.pending.disabled'}else{Get-SBMessage 'mcp.pending.contract'})
                        _meta = @{noRecovery=$skipRecovery}
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
    
    # Stdio loop
    # MCP stdio is UTF-8 (no BOM); [Console]::In/Out follow the OEM code page on Windows and corrupt non-ASCII text.
    $utf8 = [Text.UTF8Encoding]::new($false)
    $reader = [IO.StreamReader]::new([Console]::OpenStandardInput(), $utf8, $false)
    $writer = [IO.StreamWriter]::new([Console]::OpenStandardOutput(), $utf8)
    $writer.NewLine = "`n"

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

Export-ModuleMember -Function @(
    'Invoke-SBMcpToolCall',
    'Get-SBMcpDeprecatedToolAliases',
    'Get-SBMcpDeprecationNotice',
    'Invoke-SBMcpMessage',
    'Start-SBMcpServer'
)
