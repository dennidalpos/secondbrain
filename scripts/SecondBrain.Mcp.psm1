#requires -Version 7.5
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Para.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Prompts.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Knowledge.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Tracker.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Publication.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Add-SBMessages @{
    'mcp.repository.unresolved' = @{ it = 'Repository in lavoro non risolvibile: indicare repository o checkoutPath (oppure all=true per la vista globale in sola lettura)'; en = 'Working repository not resolvable: give repository or checkoutPath (or all=true for the read-only global view)' }
    'mcp.profile.invalid' = @{ it = 'Profilo non valido: usare slim o full'; en = 'Invalid profile: use slim or full' }
    'mcp.params.conflict' = @{ it = 'Parametri incompatibili: all e repository'; en = 'Incompatible parameters: all and repository' }
    'mcp.paging.invalid' = @{ it = 'offset e limit devono essere interi non negativi'; en = 'offset and limit must be non-negative integers' }
    'mcp.task.required' = @{ it = 'Il parametro task è obbligatorio per get_task'; en = 'The task parameter is required for get_task' }
    'mcp.query.required' = @{ it = 'Il parametro query è obbligatorio per search_knowledge'; en = 'The query parameter is required for search_knowledge' }
    'mcp.mode.invalid' = @{ it = 'Modalità non valida: usare literal o relevance'; en = 'Invalid mode: use literal or relevance' }
    'mcp.search.invalid' = @{ it = 'offset, limit e budget devono essere interi non negativi'; en = 'offset, limit and budget must be non-negative integers' }
    'mcp.pack.invalid' = @{ it = 'Pacchetto non valido: core, maintenance o all'; en = 'Invalid pack: core, maintenance or all' }
    'mcp.prompt.required' = @{ it = 'Il parametro prompt è obbligatorio per get_prompt'; en = 'The prompt parameter is required for get_prompt' }
    'mcp.path.required' = @{ it = 'Il parametro repositoryPath è obbligatorio per check_publication'; en = 'The repositoryPath parameter is required for check_publication' }
    'mcp.tool.unknown' = @{ it = 'Strumento sconosciuto: {0}'; en = 'Unknown tool: {0}' }
    'mcp.resource.notfound' = @{ it = 'Risorsa non trovata: {0}'; en = 'Resource not found: {0}' }
    'mcp.pair.json' = @{ it = 'Configurazione MCP non è JSON rigoroso (errori o commenti), nessuna modifica: {0}. Inserisci a mano il frammento mostrato da mcp-server.ps1 -Pair.'; en = 'MCP configuration is not strict JSON (errors or comments), no change made: {0}. Add by hand the fragment shown by mcp-server.ps1 -Pair.' }
    'mcp.pair.root' = @{ it = 'Configurazione MCP con radice non oggetto, nessuna modifica: {0}'; en = 'MCP configuration with a non-object root, no change made: {0}' }
}

function ConvertTo-SBMcpJson($Value) {
    if ($null -eq $Value) { return $null }
    ConvertTo-SBStableValue $Value | ConvertTo-Json -Depth 40 -Compress
}

function Get-SBMcpToolDefinitions {
    @(
        @{
            name = 'get_startup_context'
            description = 'Restituisce il contesto di avvio del repository o dossier. Profilo slim (predefinito, tetto 20000 caratteri): indice, sezioni essenziali di context.md e memory.md, task pronti in forma breve e l''elenco dei livelli non caricati (nulla eliminato). Profilo full: tutto, senza tetto.'
            inputSchema = @{
                type = 'object'
                properties = @{
                    repository = @{ type = 'string'; description = 'Identificatore del repository (es. github.com/example-user/secondbrain); default: checkout in lavoro' }
                    checkoutPath = @{ type = 'string'; description = 'Percorso del checkout in lavoro da cui risolvere il repository (opzionale)' }
                    dossier = @{ type = 'string'; description = 'Percorso relativo del dossier (es. 02-areas/products/SecondBrain)' }
                    readyOnly = @{ type = 'boolean'; description = 'Se true, include solo task con dipendenze soddisfatte (con slim è sempre attivo)' }
                    profile = @{ type = 'string'; enum = @('slim', 'full'); description = 'slim (predefinito): parti essenziali entro 20000 caratteri, solo per il primo caricamento; full: contesto completo, senza tetto' }
                    budget = @{ type = 'integer'; description = 'Budget caratteri massimo (default: 20000 con slim, nessun tetto con full)' }
                }
            }
        },
        @{
            name = 'get_ready_tasks'
            description = 'Restituisce i task pronti con dipendenze soddisfatte (proiezione -ReadyOnly) del repository in lavoro (risolto dal checkout corrente o da repository/checkoutPath). La vista globale e di sola lettura e richiede all=true.'
            inputSchema = @{
                type = 'object'
                properties = @{
                    repository = @{ type = 'string'; description = 'Identificatore del repository (opzionale; default: checkout in lavoro)' }
                    checkoutPath = @{ type = 'string'; description = 'Percorso del checkout in lavoro da cui risolvere il repository (opzionale)' }
                    all = @{ type = 'boolean'; description = 'Se true, vista globale di tutti i repository, in sola lettura (opt-in esplicito)' }
                    includeAcceptance = @{ type = 'boolean'; description = 'Se true, include i criteri di accettazione dei task' }
                    offset = @{ type = 'integer'; description = 'Solo con all=true: task da saltare (paginazione)' }
                    limit = @{ type = 'integer'; description = 'Solo con all=true: task per pagina (default 50; 0 = tutti)' }
                }
            }
        },
        @{
            name = 'get_task'
            description = 'Restituisce il dettaglio integro di un task (descrizione, criteri di accettazione, evidenze, provenienza) per id o numero seq, dal tracker attivo o dall''archivio del dossier. Serve per i task che il profilo slim mostra solo in forma breve.'
            inputSchema = @{
                type = 'object'
                required = @('task')
                properties = @{
                    task = @{ type = 'string'; description = 'ID del task (es. SB-SIMP-QUEUE-20261101) oppure numero seq (es. 197 o #197)' }
                    repository = @{ type = 'string'; description = 'Identificatore del repository (opzionale; default: checkout in lavoro)' }
                    checkoutPath = @{ type = 'string'; description = 'Percorso del checkout in lavoro da cui risolvere il repository (opzionale)' }
                    dossier = @{ type = 'string'; description = 'Percorso relativo del dossier (opzionale)' }
                }
            }
        },
        @{
            name = 'search_knowledge'
            description = 'Cerca nei file di conoscenza del dossier del repository in lavoro (context.md, memory.md, tracker.json, archivio tracker, rapporti dei lotti). Predefiniti: 20 riscontri e 10000 caratteri; se hasMore=true richiamare con offset=nextOffset. limit=0 o budget=0 tolgono il tetto (sconsigliato). allDossiers=true cerca in tutte le aree; includeOriginals=true include gli originali compattati. mode=literal (predefinito): sottostringa esatta; mode=relevance: più termini ordinati per pertinenza, con score e section.'
            inputSchema = @{
                type = 'object'
                required = @('query')
                properties = @{
                    query = @{ type = 'string'; description = 'Termine o frase da cercare nei dossier' }
                    budget = @{ type = 'integer'; description = 'Tetto di caratteri (default 10000; 0 = nessun tetto)' }
                    allDossiers = @{ type = 'boolean'; description = 'Se true, cerca in tutte le aree attive invece che nel repository in lavoro' }
                    includeOriginals = @{ type = 'boolean'; description = 'Se true, include gli originali compattati (history/compaction)' }
                    dossier = @{ type = 'string'; description = 'Percorso relativo di un dossier specifico (opzionale)' }
                    repository = @{ type = 'string'; description = 'Identificatore del repository per selezionare il dossier' }
                    mode = @{ type = 'string'; enum = @('literal', 'relevance'); description = 'literal (predefinito): sottostringa esatta; relevance: termini multipli ordinati per pertinenza' }
                    offset = @{ type = 'integer'; description = 'Numero di riscontri da saltare (paginazione, default 0)' }
                    limit = @{ type = 'integer'; description = 'Numero massimo di riscontri (default 20; 0 = tutti)' }
                }
            }
        },
        @{
            name = 'list_prompts'
            description = 'Elenca il catalogo dei prompt e workflow ingegneristici generici (pacchetto core), per area tematica; con pack=maintenance elenca i prompt di manutenzione di SecondBrain. Ogni voce ha l''icona di modalità. Con compact=true una riga per prompt (codice, modalità, sommario): riportare l''elenco integrale, senza riassumerlo.'
            inputSchema = @{
                type = 'object'
                properties = @{
                    category = @{ type = 'string'; description = 'Filtra per area: id (sistema, test, governance...) o prefisso dei codici (SYS, TST, GOV...), senza distinguere le maiuscole; cerca in tutti i pacchetti' }
                    pack = @{ type = 'string'; enum = @('core', 'maintenance', 'all'); description = 'Pacchetto da elencare (predefinito core)' }
                    compact = @{ type = 'boolean'; description = 'Se true, una riga per prompt invece della scheda sintetica' }
                }
            }
        },
        @{
            name = 'get_prompt_home'
            description = 'Schermata iniziale di `sb prompt`: link al catalogo completo, tabella dei comandi sb (chat) con l''equivalente da script. Con repositoryPath (checkout corrente) aggiunge stato, prossimo passo e flusso per prodotto.'
            inputSchema = @{
                type = 'object'
                properties = @{
                    repositoryPath = @{ type = 'string'; description = 'Percorso del checkout corrente; facoltativo' }
                }
            }
        },
        @{
            name = 'get_prompt'
            description = 'Restituisce la scheda completa di un prompt o workflow ingegneristico (es. SYS03, REP05, DEV01).'
            inputSchema = @{
                type = 'object'
                required = @('prompt')
                properties = @{
                    prompt = @{ type = 'string'; description = 'Codice (SYS03, COM01...), ID immutabile (pmt-...) o alias del prompt' }
                }
            }
        },
        @{
            name = 'check_publication'
            description = 'Esegue una verifica di sola lettura della pubblicabilità del working tree, indice e storia del repository specificato. Restituisce un riepilogo (conteggi per regola e primi 20 riscontri); detail=true il rapporto integro.'
            inputSchema = @{
                type = 'object'
                required = @('repositoryPath')
                properties = @{
                    repositoryPath = @{ type = 'string'; description = 'Percorso della radice o checkout del repository Git da verificare' }
                    detail = @{ type = 'boolean'; description = 'Se true, rapporto integro (tutti i riscontri e i riferimenti esclusi)' }
                }
            }
        }
    )
}

function Resolve-SBMcpRepository([string]$BrainRoot, $Arguments) {
    # Repository esplicito, altrimenti quello del checkout in lavoro (argomento checkoutPath o directory corrente del server).
    if ($Arguments.ContainsKey('repository') -and $Arguments.repository) { return [string]$Arguments.repository }
    $checkout = if ($Arguments.ContainsKey('checkoutPath') -and $Arguments.checkoutPath) { [string]$Arguments.checkoutPath } else { '' }
    $bindings = @()
    try { $bindings = @((Read-SBConfiguration -ReadOnly).bindings) } catch { }
    $resolved = Resolve-SBWorkingRepository $checkout $bindings
    if (!$resolved) { throw (New-SBError 'mcp.repository.unresolved') }
    $resolved
}

function Invoke-SBMcpToolCall([string]$BrainRoot, [string]$ToolName, $Arguments) {
    if (!$Arguments) { $Arguments = @{} }
    
    switch ($ToolName) {
        { $_ -in @('get_startup_context', 'secondbrain_startup_context') } {
            $startupProfile = if ($Arguments.ContainsKey('profile') -and $Arguments.profile) { [string]$Arguments.profile } else { 'slim' }
            if ($startupProfile -notin @('slim', 'full')) { throw (New-SBError 'mcp.profile.invalid') }
            $startupProfile = if ($startupProfile -eq 'full') { 'Full' } else { 'Slim' }
            # Tetto solo per il primo caricamento (slim); full non ha tetto salvo budget esplicito.
            $budgetDefault = if ($startupProfile -eq 'Slim') { Get-SBSlimStartupBudget } else { 0 }
            $budget = if ($Arguments.ContainsKey('budget') -and $Arguments.budget) { [int]$Arguments.budget } else { $budgetDefault }
            $readyOnly = if ($Arguments.ContainsKey('readyOnly')) { [bool]$Arguments.readyOnly } else { $false }
            $dossier = if ($Arguments.ContainsKey('dossier')) { [string]$Arguments.dossier } else { $null }

            if (!$dossier) {
                # Nessun default sul repository del cervello: il dossier segue il repository esplicito o il checkout in lavoro.
                $repo = Resolve-SBMcpRepository $BrainRoot $Arguments
                $dossier = Resolve-SBWorkingDossier $BrainRoot $repo
            }
            $dossierPath = if ([IO.Path]::IsPathRooted($dossier)) { $dossier } else { Join-Path $BrainRoot $dossier }

            $ctx = Get-SBStartupContext -BrainRoot $BrainRoot -Dossier $dossierPath -Budget $budget -ReadyOnly:$readyOnly -Profile $startupProfile
            return ConvertTo-SBMcpJson $ctx
        }
        { $_ -in @('get_ready_tasks', 'secondbrain_ready_tasks') } {
            $all = $Arguments.ContainsKey('all') -and [bool]$Arguments.all
            if ($all -and $Arguments.ContainsKey('repository') -and $Arguments.repository) { throw (New-SBError 'mcp.params.conflict') }
            if (!$all) {
                return ConvertTo-SBMcpJson @(Get-SBGlobalTasks -BrainRoot $BrainRoot -Repository (Resolve-SBMcpRepository $BrainRoot $Arguments) -ReadyOnly)
            }
            # Vista globale paginata (predefinito 50 task per pagina): dimensione limitata, nextOffset per la pagina successiva.
            $offset = if ($Arguments.ContainsKey('offset') -and $Arguments.offset) { [int]$Arguments.offset } else { 0 }
            $limit = if ($Arguments.ContainsKey('limit') -and $null -ne $Arguments.limit) { [int]$Arguments.limit } else { 50 }
            if ($offset -lt 0 -or $limit -lt 0) { throw (New-SBError 'mcp.paging.invalid') }
            $tasks = @(Get-SBGlobalTasks -BrainRoot $BrainRoot -All -ReadyOnly)
            $page = @($tasks | Select-Object -Skip $offset)
            if ($limit -gt 0) { $page = @($page | Select-Object -First $limit) }
            $hasMore = ($offset + $page.Count) -lt $tasks.Count
            return ConvertTo-SBMcpJson @{ total = $tasks.Count; offset = $offset; limit = $limit; count = $page.Count; hasMore = $hasMore; nextOffset = $(if ($hasMore) { $offset + $page.Count } else { $null }); tasks = $page }
        }
        { $_ -in @('get_task', 'secondbrain_get_task') } {
            if (!$Arguments.ContainsKey('task') -or !"$($Arguments.task)") {
                throw (New-SBError 'mcp.task.required')
            }
            $dossier = if ($Arguments.ContainsKey('dossier') -and $Arguments.dossier) { [string]$Arguments.dossier } else { Resolve-SBWorkingDossier $BrainRoot (Resolve-SBMcpRepository $BrainRoot $Arguments) }
            $dossierPath = if ([IO.Path]::IsPathRooted($dossier)) { $dossier } else { Join-Path $BrainRoot $dossier }
            return ConvertTo-SBMcpJson (Get-SBTaskDetail -BrainRoot $BrainRoot -Dossier $dossierPath -Task ([string]$Arguments.task))
        }
        { $_ -in @('search_knowledge', 'secondbrain_search') } {
            if (!$Arguments.ContainsKey('query') -or !$Arguments.query) {
                throw (New-SBError 'mcp.query.required')
            }
            $query = [string]$Arguments.query
            # -1 = tetto predefinito (20 riscontri, 10.000 caratteri); 0 esplicito = nessun tetto.
            $budget = if ($Arguments.ContainsKey('budget') -and $null -ne $Arguments.budget) { [int]$Arguments.budget } else { -1 }
            $dossier = if ($Arguments.ContainsKey('dossier')) { [string]$Arguments.dossier } else { $null }
            $repo = if ($Arguments.ContainsKey('repository')) { [string]$Arguments.repository } else { $null }
            $allDossiers = $Arguments.ContainsKey('allDossiers') -and [bool]$Arguments.allDossiers
            $includeOriginals = $Arguments.ContainsKey('includeOriginals') -and [bool]$Arguments.includeOriginals
            # Ambito predefinito: repository del checkout in lavoro (se risolvibile), altrimenti tutte le aree ma con il tetto predefinito.
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
        { $_ -in @('list_prompts', 'secondbrain_list_prompts') } {
            $catalog = Read-SBWorkflowCatalog $BrainRoot
            $category = if ($Arguments.ContainsKey('category')) { [string]$Arguments.category } else { $null }
            $compact = $Arguments.ContainsKey('compact') -and [bool]$Arguments.compact
            $pack = if ($Arguments.ContainsKey('pack')) { [string]$Arguments.pack } else { 'core' }
            if ($pack -notin @('core', 'maintenance', 'all')) { throw (New-SBError 'mcp.pack.invalid') }
            return Format-SBWorkflowList $catalog $category -Compact:$compact -Pack $pack
        }
        { $_ -in @('get_prompt_home', 'secondbrain_prompt_home') } {
            $homeState = if ($Arguments.ContainsKey('repositoryPath') -and $Arguments.repositoryPath) { Get-SBWorkflowState $BrainRoot ([string]$Arguments.repositoryPath) } else { $null }
            return Format-SBWorkflowHome $BrainRoot (Read-SBWorkflowCatalog $BrainRoot) $homeState
        }
        { $_ -in @('get_prompt', 'secondbrain_get_prompt') } {
            if (!$Arguments.ContainsKey('prompt') -or !$Arguments.prompt) {
                throw (New-SBError 'mcp.prompt.required')
            }
            $catalog = Read-SBWorkflowCatalog $BrainRoot
            $resolution = Resolve-SBWorkflowPrompt $catalog ([string]$Arguments.prompt)
            $body = Read-SBWorkflowPrompt $BrainRoot $resolution.prompt $catalog
            $card = (Format-SBWorkflowCard $resolution.prompt $body) + "`n" + $body
            return $(if ($resolution.warning) { "Avviso: $($resolution.warning)`n`n$card" } else { $card })
        }
        { $_ -in @('check_publication', 'secondbrain_check_publication') } {
            if (!$Arguments.ContainsKey('repositoryPath') -or !$Arguments.repositoryPath) {
                throw (New-SBError 'mcp.path.required')
            }
            $repoPath = [string]$Arguments.repositoryPath
            $report = Test-SBPublication -RepositoryPath $repoPath -BrainRoot $BrainRoot -PolicyPath (Resolve-SBPublicationPolicyPath $BrainRoot $null)
            if ($Arguments.ContainsKey('detail') -and [bool]$Arguments.detail) { return ConvertTo-SBMcpJson $report }
            # Riepilogo: conteggi per regola e primi 20 riscontri; excludedRefs ridotto a conteggio. detail=true restituisce il rapporto integro.
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
                    message = "Parse error: $($_.Exception.Message)"
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
                message = 'Invalid Request: jsonrpc must be 2.0'
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
        switch ($method) {
            'initialize' {
                return ConvertTo-SBMcpJson @{
                    jsonrpc = '2.0'
                    id = $id
                    result = @{
                        protocolVersion = '2024-11-05'
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
                    return ConvertTo-SBMcpJson @{
                        jsonrpc = '2.0'
                        id = $id
                        result = @{
                            content = @(
                                @{
                                    type = 'text'
                                    text = $output
                                }
                            )
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
                                    text = "Errore durante l'esecuzione dello strumento ${toolName}: $($_.Exception.Message)"
                                }
                            )
                            isError = $true
                        }
                    }
                }
            }
            'prompts/list' {
                $catalog = Read-SBWorkflowCatalog $BrainRoot
                $promptsList = @($catalog.prompts | Where-Object status -ne 'deprecated' | ForEach-Object {
                    @{
                        name = $_.code
                        title = $_.summary
                        description = "$($_.summary) (ID $($_.id))"
                        arguments = @(
                            @{
                                name = 'objective'
                                description = 'Obiettivo opzionale dell''attività'
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
                $text = Read-SBWorkflowPrompt $BrainRoot $match[0] $catalog
                $text = (Format-SBWorkflowCard $match[0] $text) + "`n" + $text
                if ($resolution.warning) { $text = "Avviso: $($resolution.warning)`n`n$text" }
                return ConvertTo-SBMcpJson @{
                    jsonrpc = '2.0'
                    id = $id
                    result = @{
                        description = $match[0].summary
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
                                name = 'Catalogo Prompt e Workflow SecondBrain'
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
                        message = "Method not found: $method"
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
                message = "Internal error: $($_.Exception.Message)"
            }
        }
    }
}

function Start-SBMcpServer {
    [CmdletBinding()]
    param(
        [string]$BrainRoot,
        [string]$ConfigPath
    )
    if (!$BrainRoot) {
        $BrainRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
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
    # Strumenti di sola lettura che non scrivono nel cervello ne altrove: candidati all'approvazione automatica. check_publication esclusa (analizza un percorso scelto dal chiamante).
    @('get_startup_context', 'get_ready_tasks', 'get_task', 'search_knowledge', 'list_prompts', 'get_prompt', 'get_prompt_home')
}
function Get-SBMcpPairing {
    [CmdletBinding()]
    param(
        [string]$BrainRoot,
        [Parameter()][ValidateSet('codex', 'claude', 'cursor', 'vscode', 'antigravity', 'windsurf', 'all')][string]$Target = 'all'
    )
    if (!$BrainRoot) {
        $BrainRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    }
    $BrainRoot = [IO.Path]::GetFullPath($BrainRoot)
    $serverScript = Join-Path $BrainRoot 'scripts/mcp-server.ps1'
    $serverScriptNormalized = $serverScript.Replace('\', '/')
    $escapedScript = $serverScript.Replace('\', '\\')

    [string[]]$targetsToProcess = if ($Target.ToLowerInvariant() -eq 'all') {
        @('codex', 'claude', 'cursor', 'vscode', 'antigravity', 'windsurf')
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
                $cliCommand = "codex mcp add secondbrain -- pwsh -NoProfile -File `"$serverScript`""
                
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
                $cliCommand = "claude mcp add secondbrain -- pwsh -NoProfile -File `"$serverScript`""
                if ($claudeRoot) {
                    $configFile = Join-Path $claudeRoot 'claude_desktop_config.json'
                } elseif (Test-Path -LiteralPath (Join-Path $env:APPDATA 'Claude')) {
                    $configFile = Join-Path $env:APPDATA 'Claude\claude_desktop_config.json'
                } elseif (Test-Path -LiteralPath (Join-Path $env:USERPROFILE '.claude.json')) {
                    $configFile = Join-Path $env:USERPROFILE '.claude.json'
                } else {
                    $configFile = Join-Path $env:APPDATA 'Claude\claude_desktop_config.json'
                }

                $snippetObj = [ordered]@{
                    mcpServers = [ordered]@{
                        secondbrain = [ordered]@{
                            command = 'pwsh'
                            args = @('-NoProfile', '-File', $serverScriptNormalized)
                        }
                    }
                }
                $json = ConvertTo-Json -InputObject $snippetObj -Depth 10
                # Claude Code: regole di permesso (settings.json) solo per gli strumenti di lettura, da incollare dopo approvazione dell'utente.
                $permissionsJson = ConvertTo-Json -InputObject ([ordered]@{ permissions = [ordered]@{ allow = @(Get-SBMcpReadOnlyToolNames | ForEach-Object { "mcp__secondbrain__$_" }) } }) -Depth 10

                $results += [PSCustomObject]@{
                    Target = 'claude'
                    Name = 'Claude Desktop / Claude Code'
                    ConfigFile = $configFile
                    ConfigFormat = 'json'
                    Toml = $null
                    Snippet = $json
                    PermissionsSnippet = $permissionsJson
                    CliCommand = $cliCommand
                    ServerDefinition = @{
                        command = 'pwsh'
                        args = @('-NoProfile', '-File', $serverScriptNormalized)
                    }
                    Configured = (Test-Path -LiteralPath $configFile -PathType Leaf) -and ((Get-Content -LiteralPath $configFile -Raw -ErrorAction SilentlyContinue) -match '"secondbrain"')
                }
            }
            'cursor' {
                $cursorRoot = Join-Path $env:USERPROFILE '.cursor'
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
                $vscodeRoot = Join-Path $env:APPDATA 'Code/User'
                $configFile = Join-Path $vscodeRoot 'settings.json'

                $snippetObj = [ordered]@{
                    "mcp.servers" = [ordered]@{
                        secondbrain = [ordered]@{
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
            'antigravity' {
                $agRoot = Join-Path $env:USERPROFILE '.gemini/antigravity'
                $configFile = Join-Path $agRoot 'mcp_config.json'

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

    if ($Target.ToLowerInvariant() -ne 'all' -and $results.Length -eq 1) {
        return $results[0]
    }
    return $results
}

function Set-SBMcpConfiguration {
    [CmdletBinding()]
    param(
        [string]$BrainRoot,
        [Parameter()][ValidateSet('codex', 'claude', 'cursor', 'vscode', 'antigravity', 'windsurf', 'all')][string]$Target = 'all',
        [string]$ConfigFile,
        [string]$BackupRoot
    )
    if (!$BrainRoot) {
        $BrainRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    }
    $BrainRoot = [IO.Path]::GetFullPath($BrainRoot)
    $backupDir = if ($BackupRoot) { $BackupRoot } else { Join-Path $BrainRoot '.runtime/backup/mcp-pairing' }
    [IO.Directory]::CreateDirectory($backupDir) | Out-Null

    [string[]]$targetsToProcess = if ($Target.ToLowerInvariant() -eq 'all') {
        @('codex', 'claude', 'cursor', 'vscode', 'antigravity', 'windsurf')
    } else {
        @($Target.ToLowerInvariant())
    }

    [object[]]$applied = @()
    foreach ($t in $targetsToProcess) {
        $pairing = Get-SBMcpPairing -BrainRoot $BrainRoot -Target $t
        $targetFile = if ($ConfigFile -and $targetsToProcess.Length -eq 1) { $ConfigFile } else { $pairing.ConfigFile }
        $parent = Split-Path -Parent $targetFile
        if ($parent -and !(Test-Path -LiteralPath $parent)) {
            [IO.Directory]::CreateDirectory($parent) | Out-Null
        }

        $existing = Test-Path -LiteralPath $targetFile -PathType Leaf
        $action = if ($existing) { 'updated' } else { 'created' }
        $expectedHash = Get-SBFileHash $targetFile

        if ($t -eq 'codex') {
            $escaped = $pairing.ServerDefinition.args[2].Replace('\', '\\')
            $sectionBody = @(
                '[mcp_servers.secondbrain]',
                'command = "pwsh"',
                "args = [`"-NoProfile`", `"-File`", `"$escaped`"]"
            ) -join "`n"
            if ($existing) {
                $content = Get-Content -LiteralPath $targetFile -Raw -Encoding utf8
                if ($content -match '(?ms)\[mcp_servers\.secondbrain\].*?(?=(\n\[|\Z))') {
                    $newContent = [regex]::Replace($content, '(?ms)\[mcp_servers\.secondbrain\].*?(?=(\n\[|\Z))', $sectionBody)
                } else {
                    $newContent = $content.TrimEnd() + "`n`n" + $sectionBody + "`n"
                }
            } else {
                $newContent = $sectionBody + "`n"
            }
        } else {
            $keyName = if ($t -eq 'vscode') { 'mcp.servers' } else { 'mcpServers' }
            $data = @{}
            if ($existing) {
                $raw = Get-Content -LiteralPath $targetFile -Raw -Encoding utf8
                if ($raw -and $raw.Trim()) {
                    # File dell'utente non leggibile come JSON (commenti, errori): nessuna scrittura, per non perdere le sue impostazioni.
                    # JSON rigoroso: ConvertFrom-Json accetta i commenti (JSONC, tipico di settings.json) ma poi li perderebbe nella riscrittura.
                    try { [Text.Json.JsonDocument]::Parse($raw).Dispose(); $parsed = ConvertFrom-Json -InputObject $raw -AsHashtable } catch { throw (New-SBError 'mcp.pair.json' @($targetFile)) }
                    if ($parsed -isnot [System.Collections.IDictionary]) { throw (New-SBError 'mcp.pair.root' @($targetFile)) }
                    $data = $parsed
                }
            }
            if (!$data.Contains($keyName) -or $null -eq $data[$keyName]) {
                $data[$keyName] = @{}
            }
            $data[$keyName]['secondbrain'] = [ordered]@{
                command = 'pwsh'
                args = @('-NoProfile', '-File', $pairing.ServerDefinition.args[2])
            }
            $newContent = (ConvertTo-Json -InputObject $data -Depth 20) + "`n"
        }

        # Scrittura atomica con controllo dell'hash e backup verificato (<guid>.bin + .bin.json, ripristinabile con restore-managed.ps1).
        $written = Write-SBFile $targetFile ([Text.UTF8Encoding]::new($false).GetBytes($newContent)) $expectedHash $backupDir
        if (!$written) { $action = 'unchanged' }
        $backupPath = $null
        if ($written -and $existing) {
            $resolvedTarget = [IO.Path]::GetFullPath($targetFile)
            $latest = Get-ChildItem -LiteralPath $backupDir -Filter '*.bin.json' -File | Sort-Object LastWriteTimeUtc -Descending |
                Where-Object { (Read-SBJson $_.FullName @{}).path -eq $resolvedTarget -or (Read-SBJson $_.FullName @{}).path -eq $targetFile } | Select-Object -First 1
            if ($latest) { $backupPath = $latest.FullName.Substring(0, $latest.FullName.Length - 5) }
        }

        $applied += [PSCustomObject]@{
            Target = $t
            Name = $pairing.Name
            ConfigFile = $targetFile
            Action = $action
            BackupFile = $backupPath
        }
    }

    if ($Target.ToLowerInvariant() -ne 'all' -and $applied.Length -eq 1) {
        return $applied[0]
    }
    return $applied
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
    $OutDir = [IO.Path]::GetFullPath($OutDir)
    [IO.Directory]::CreateDirectory($OutDir) | Out-Null

    $pairings = Get-SBMcpPairing -BrainRoot $BrainRoot -Target all
    $createdFiles = @()

    foreach ($p in $pairings) {
        $targetDir = Join-Path $OutDir $p.Target
        [IO.Directory]::CreateDirectory($targetDir) | Out-Null

        if ($p.Target -eq 'codex') {
            $fullToml = Join-Path $targetDir 'config.toml'
            [IO.File]::WriteAllText($fullToml, ($p.Snippet + "`n"), [Text.UTF8Encoding]::new($false))
            $createdFiles += $fullToml

            $snippetToml = Join-Path $targetDir 'snippet.toml'
            [IO.File]::WriteAllText($snippetToml, ($p.Snippet + "`n"), [Text.UTF8Encoding]::new($false))
            $createdFiles += $snippetToml
        } elseif ($p.Target -eq 'vscode') {
            $settingsJson = Join-Path $targetDir 'settings.json'
            [IO.File]::WriteAllText($settingsJson, ($p.Snippet + "`n"), [Text.UTF8Encoding]::new($false))
            $createdFiles += $settingsJson
        } elseif ($p.Target -eq 'claude') {
            $claudeJson = Join-Path $targetDir 'claude_desktop_config.json'
            [IO.File]::WriteAllText($claudeJson, ($p.Snippet + "`n"), [Text.UTF8Encoding]::new($false))
            $createdFiles += $claudeJson
        } elseif ($p.Target -eq 'cursor') {
            $cursorJson = Join-Path $targetDir 'mcp.json'
            [IO.File]::WriteAllText($cursorJson, ($p.Snippet + "`n"), [Text.UTF8Encoding]::new($false))
            $createdFiles += $cursorJson
        } else {
            $mcpJson = Join-Path $targetDir 'mcp_config.json'
            [IO.File]::WriteAllText($mcpJson, ($p.Snippet + "`n"), [Text.UTF8Encoding]::new($false))
            $createdFiles += $mcpJson
        }
    }

    # Install script one-click
    $installScript = Join-Path $OutDir 'install-all-ides.ps1'
    $installContent = @(
        '#requires -Version 7.5',
        '<#',
        '.SYNOPSIS',
        'Installa automaticamente il server MCP SecondBrain in tutti gli IDE supportati.',
        '#>',
        '[CmdletBinding()]',
        'param()',
        '$ErrorActionPreference = ''Stop''',
        "`$brain = '$($BrainRoot.Replace('\', '/'))'",
        'if (!(Test-Path -LiteralPath (Join-Path $brain ''scripts/mcp-server.ps1''))) {',
        '    if ($env:SECONDBRAIN_HOME -and (Test-Path -LiteralPath (Join-Path $env:SECONDBRAIN_HOME ''scripts/mcp-server.ps1''))) {',
        '        $brain = $env:SECONDBRAIN_HOME',
        '    } else {',
        '        throw "Impossibile trovare scripts/mcp-server.ps1 nella radice SecondBrain: $brain"',
        '    }',
        '}',
        'Write-Host "Applicazione configurazione MCP SecondBrain a tutti gli IDE..." -ForegroundColor Cyan',
        '& pwsh -NoProfile -File (Join-Path $brain ''scripts/mcp-server.ps1'') -Pair -Target all -Apply'
    ) -join "`n"
    [IO.File]::WriteAllText($installScript, ($installContent + "`n"), [Text.UTF8Encoding]::new($false))
    $createdFiles += $installScript

    # README guide
    $readmePath = Join-Path $OutDir 'README.md'
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
        '## 2. Installazione Manuale per Singolo IDE',
        '',
        '| IDE | File nel pacchetto | Destinazione nel sistema |',
        '| :--- | :--- | :--- |',
        '| **OpenAI Codex** | `codex/snippet.toml` | `%USERPROFILE%\.codex\config.toml` |',
        '| **Claude Desktop** | `claude/claude_desktop_config.json` | `%APPDATA%\Claude\claude_desktop_config.json` |',
        '| **Cursor IDE** | `cursor/mcp.json` | `%USERPROFILE%\.cursor\mcp.json` |',
        '| **VS Code** | `vscode/settings.json` | `%APPDATA%\Code\User\settings.json` |',
        '| **Google Antigravity** | `antigravity/mcp_config.json` | `%USERPROFILE%\.gemini\antigravity\mcp_config.json` |',
        '| **Windsurf** | `windsurf/mcp_config.json` | `%USERPROFILE%\.codeium\windsurf\mcp_config.json` |',
        '',
        '---',
        '',
        '## 3. Verifica Connessione JSON-RPC',
        'Invia una richiesta handshake di test al server:',
        '```powershell',
        "'{\`"jsonrpc\`":\`"2.0\`",\`"id\`":1,\`"method\`":\`"tools/list\`",\`"params\`":{}}' | pwsh -NoProfile -File `"$($BrainRoot.Replace('\', '/'))/scripts/mcp-server.ps1`"",
        '```'
    ) -join "`n"
    [IO.File]::WriteAllText($readmePath, ($readmeContent + "`n"), [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($readmePath, ($readmeContent + "`n"), [Text.UTF8Encoding]::new($false))
    $createdFiles += $readmePath

    return [PSCustomObject]@{
        PackageDir = $OutDir
        FileCount = $createdFiles.Count
        Files = $createdFiles
    }
}

Export-ModuleMember -Function @(
    'Invoke-SBMcpToolCall',
    'Invoke-SBMcpMessage',
    'Start-SBMcpServer',
    'Get-SBMcpPairing',
    'Get-SBMcpReadOnlyToolNames',
    'Set-SBMcpConfiguration',
    'New-SBMcpPackage'
)
