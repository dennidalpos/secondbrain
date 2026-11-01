#requires -Version 7.5
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Para.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Prompts.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Knowledge.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Tracker.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Publication.psm1')

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
                }
            }
        },
        @{
            name = 'search_knowledge'
            description = 'Esegue una ricerca trasversale nei file di conoscenza (context.md, memory.md, tracker.json, history/compaction/). Nessun tetto per impostazione predefinita: restituisce tutti i riscontri pertinenti; budget è un limite facoltativo. mode=literal (predefinito) cerca la sottostringa esatta; mode=relevance cerca più termini e ordina sezioni e blocchi per pertinenza (copertura dei termini, titolo, frase esatta), con score e section in ogni estratto.'
            inputSchema = @{
                type = 'object'
                required = @('query')
                properties = @{
                    query = @{ type = 'string'; description = 'Termine o frase da cercare nei dossier' }
                    budget = @{ type = 'integer'; description = 'Limite facoltativo di caratteri (default: nessun tetto)' }
                    dossier = @{ type = 'string'; description = 'Percorso relativo di un dossier specifico (opzionale)' }
                    repository = @{ type = 'string'; description = 'Identificatore del repository per selezionare il dossier' }
                    mode = @{ type = 'string'; enum = @('literal', 'relevance'); description = 'literal (predefinito): sottostringa esatta; relevance: termini multipli ordinati per pertinenza' }
                }
            }
        },
        @{
            name = 'list_prompts'
            description = 'Elenca il catalogo dei prompt e workflow ingegneristici (77 workflow attivi) nelle 13 aree tematiche. Con compact=true una riga per prompt (codice, modalità, sommario): riportare l''elenco integrale, senza riassumerlo.'
            inputSchema = @{
                type = 'object'
                properties = @{
                    category = @{ type = 'string'; description = 'Filtra per area: id (sistema, test, governance...) o prefisso dei codici (SYS, TST, GOV...), senza distinguere le maiuscole' }
                    compact = @{ type = 'boolean'; description = 'Se true, una riga per prompt invece della scheda sintetica' }
                }
            }
        },
        @{
            name = 'get_prompt_home'
            description = 'Schermata iniziale di `sb prompt`: link al file Markdown del catalogo completo e tabella dei comandi sb con descrizione.'
            inputSchema = @{
                type = 'object'
                properties = @{}
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
            description = 'Esegue una verifica di sola lettura della pubblicabilità (REP05) del working tree, indice e storia del repository specificato.'
            inputSchema = @{
                type = 'object'
                required = @('repositoryPath')
                properties = @{
                    repositoryPath = @{ type = 'string'; description = 'Percorso della radice o checkout del repository Git da verificare' }
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
    if (!$resolved) { throw 'Repository in lavoro non risolvibile: indicare repository o checkoutPath (oppure all=true per la vista globale in sola lettura)' }
    $resolved
}

function Invoke-SBMcpToolCall([string]$BrainRoot, [string]$ToolName, $Arguments) {
    if (!$Arguments) { $Arguments = @{} }
    
    switch ($ToolName) {
        { $_ -in @('get_startup_context', 'secondbrain_startup_context') } {
            $startupProfile = if ($Arguments.ContainsKey('profile') -and $Arguments.profile) { [string]$Arguments.profile } else { 'slim' }
            if ($startupProfile -notin @('slim', 'full')) { throw 'Profilo non valido: usare slim o full' }
            $startupProfile = if ($startupProfile -eq 'full') { 'Full' } else { 'Slim' }
            # Tetto solo per il primo caricamento (slim); full non ha tetto salvo budget esplicito.
            $budgetDefault = if ($startupProfile -eq 'Slim') { 20000 } else { 0 }
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
            if ($all -and $Arguments.ContainsKey('repository') -and $Arguments.repository) { throw 'Parametri incompatibili: all e repository' }
            $tasks = if ($all) { @(Get-SBGlobalTasks -BrainRoot $BrainRoot -All -ReadyOnly) }
                     else { @(Get-SBGlobalTasks -BrainRoot $BrainRoot -Repository (Resolve-SBMcpRepository $BrainRoot $Arguments) -ReadyOnly) }
            return ConvertTo-SBMcpJson $tasks
        }
        { $_ -in @('search_knowledge', 'secondbrain_search') } {
            if (!$Arguments.ContainsKey('query') -or !$Arguments.query) {
                throw 'Il parametro query è obbligatorio per search_knowledge'
            }
            $query = [string]$Arguments.query
            $budget = if ($Arguments.ContainsKey('budget') -and $Arguments.budget) { [int]$Arguments.budget } else { 0 }
            $dossier = if ($Arguments.ContainsKey('dossier')) { [string]$Arguments.dossier } else { $null }
            $repo = if ($Arguments.ContainsKey('repository')) { [string]$Arguments.repository } else { $null }
            
            $mode = if ($Arguments.ContainsKey('mode') -and $Arguments.mode) { [string]$Arguments.mode } else { 'literal' }
            if ($mode -notin @('literal', 'relevance')) { throw 'Modalità non valida: usare literal o relevance' }
            $mode = if ($mode -eq 'relevance') { 'Relevance' } else { 'Literal' }

            $res = Find-SBKnowledge -BrainRoot $BrainRoot -Search $query -Dossier $dossier -Repository $repo -Budget $budget -Mode $mode
            return ConvertTo-SBMcpJson $res
        }
        { $_ -in @('list_prompts', 'secondbrain_list_prompts') } {
            $catalog = Read-SBWorkflowCatalog $BrainRoot
            $category = if ($Arguments.ContainsKey('category')) { [string]$Arguments.category } else { $null }
            $compact = $Arguments.ContainsKey('compact') -and [bool]$Arguments.compact
            return Format-SBWorkflowList $catalog $category -Compact:$compact
        }
        { $_ -in @('get_prompt_home', 'secondbrain_prompt_home') } {
            return Format-SBWorkflowHome $BrainRoot (Read-SBWorkflowCatalog $BrainRoot)
        }
        { $_ -in @('get_prompt', 'secondbrain_get_prompt') } {
            if (!$Arguments.ContainsKey('prompt') -or !$Arguments.prompt) {
                throw 'Il parametro prompt è obbligatorio per get_prompt'
            }
            $catalog = Read-SBWorkflowCatalog $BrainRoot
            $resolution = Resolve-SBWorkflowPrompt $catalog ([string]$Arguments.prompt)
            $body = Read-SBWorkflowPrompt $BrainRoot $resolution.prompt $catalog
            $card = (Format-SBWorkflowCard $resolution.prompt $body) + "`n" + $body
            return $(if ($resolution.warning) { "Avviso: $($resolution.warning)`n`n$card" } else { $card })
        }
        { $_ -in @('check_publication', 'secondbrain_check_publication') } {
            if (!$Arguments.ContainsKey('repositoryPath') -or !$Arguments.repositoryPath) {
                throw 'Il parametro repositoryPath è obbligatorio per check_publication'
            }
            $repoPath = [string]$Arguments.repositoryPath
            $report = Test-SBPublication -RepositoryPath $repoPath -BrainRoot $BrainRoot -PolicyPath (Resolve-SBPublicationPolicyPath $BrainRoot $null)
            return ConvertTo-SBMcpJson $report
        }
        default {
            throw "Strumento sconosciuto: $ToolName"
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
                    throw "Risorsa non trovata: $uri"
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

                $results += [PSCustomObject]@{
                    Target = 'claude'
                    Name = 'Claude Desktop / Claude Code'
                    ConfigFile = $configFile
                    ConfigFormat = 'json'
                    Toml = $null
                    Snippet = $json
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
                    try { [Text.Json.JsonDocument]::Parse($raw).Dispose(); $parsed = ConvertFrom-Json -InputObject $raw -AsHashtable } catch { throw "Configurazione MCP non è JSON rigoroso (errori o commenti), nessuna modifica: $targetFile. Inserisci a mano il frammento mostrato da mcp-server.ps1 -Pair." }
                    if ($parsed -isnot [System.Collections.IDictionary]) { throw "Configurazione MCP con radice non oggetto, nessuna modifica: $targetFile" }
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

Export-ModuleMember -Function *-SB*
