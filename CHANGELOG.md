# Registro delle modifiche

Formato [Keep a Changelog](https://keepachangelog.com/it-IT/1.1.0/). La numerazione segue il file `VERSION`. Questo registro cambia solo quando accetti un cambio di versione: vedi [Cambiare versione](docs/uso-quotidiano.md).

> Versione corrente: **2.13.0**, numerazione reimpostata il 2026-11-04 con le funzionalità attuali conservate. Le sezioni seguenti mantengono la cronologia dei rilasci precedenti.

## [2.13.0] - 2026-11-14

A root launcher for the desktop app, a power request that keeps the computer awake during a run, and end-to-end coverage of interrupted run labels.

### Added
- `start.ps1` in the repository root opens the desktop app without an IDE through `scripts/runner-gui.ps1`, keeps its exit code and JSON, and after a failure prints the next step: install Node.js and Rust (exit 2), fix the build (3), use a graphical session (4) or install the WebView2 runtime (5). Opening the app never starts a task (#629).
- Runner: on Windows `run-ready-tasks.ps1 -Run` holds a system-required power request (`PowerSetRequest`) from before the first task until the run closes (end, stop, quota stop, failure); the display and the power plan are untouched. `status.json` (`powerRequest`) and the `power`, `powerfailed` or `powerunsupported` event report the result and the limits (explicit sleep, lid, battery, policies); other platforms report it as unsupported and the run goes on (#603).

### Changed
- Orchestrator end-to-end registry scenario: a run recorded as running without a live process is labelled "interrupted · finish time unknown" (verdict `orphaned`) and a finished run shows its end time (#600).

## [2.12.0] - 2026-11-14

Tracker updates in one batch, resuming a quota-stopped run from the orchestrator, and truthful labels for interrupted runs.

### Added
- `knowledge.ps1 -UpdateTasksFile <json>` applies up to 200 task updates in one process, one writer lock and one transaction (tracker, archive, ledger, one request and receipt per update); a refused item names `Update <n> (<task>)` and leaves tracker and queue unchanged; a busy writer exits 3 without queuing (#595).
- Orchestrator: the Run card shows the newest unused resume point of a run stopped by a plan limit (`runner-status.ps1` now reports `resume`) and "Resume the stopped run" starts `run-ready-tasks.ps1 -Resume <run>` (#554).

### Changed
- REP16 step 6 and REP17 step 5 cite `scripts/runner.ps1 -Mode cli`; REP17 step 1 names `knowledge.ps1 -ArchiveTasks` (preview) and `-Apply` (#596).
- Directive revision 1.3 proposal (awaiting approval, #572): the Italian `sb` verbs are no longer named; their aliases are removed in 3.0.0 (#619).

### Fixed
- A runner record closed as `orphaned` (dead runner found by the next run) now has the `orphaned` verdict instead of `finished`, and the Registry run list labels an open run by its verdict (running, waiting, possibly stalled, interrupted) and shows an unknown finish time instead of "in corso" (#600, #601).
## [2.11.1] - 2026-11-13

Tracker updates by task number.

### Changed
- `knowledge.ps1 -UpdateTaskId` accepts `#<seq>` (padded or not) for an active or archived task, like `-Task` and `-DependsOn`; a deferred write stores the resolved task ID, and an unknown number is refused naming the ID form (#593).

## [2.11.0] - 2026-11-13

Source-card corrections by command, the Gemini light role on a supported model, and workstation cleanups.

### Added
- `sources.ps1 -AddEffectiveDate ... -Correct` replaces only the reference text of an existing provision, which must keep its date and status (`sources.effective.correct` otherwise) (#558).
- `sources.ps1 -SetPublicationDate -SourceId <id> -Date yyyy-MM-dd -Reference <primary source>` records a card's publication date, cites the reference in its notes and drops a note that declared the date unqualified (#558).

### Changed
- `config/agent-models.json`: Gemini models checked against the official model list; `gemini-2.5-flash` and `gemini-2.5-pro` are labelled deprecated (requests routed to newer models on 2026-12-01), and the light role for Gemini is now `gemini-3.1-flash-lite` (#513).

### Fixed
- ARERA 135/2022 source card: reference typo, arts. 7 and 9 applying from 2023-01-01 (art. 12.2) and publication date 2022-04-01 (#558).

## [2.10.1] - 2026-11-13

Tracker dependencies by task number on archived tasks, and a faster Full test profile.

### Fixed
- `-DependsOn '#<seq>'` in `knowledge.ps1 -NewTask`, `-UpdateTaskId` and queued `task.new`/`task.update` now resolves the task with that number in the tracker or its archive and stores it by ID; an unknown number is refused with `tracker.dependency.missing`, naming the ID form (#591).
- `test-secondbrain.ps1 -Full` runs the runner suite as two parallel halves (`test-secondbrain-runner.ps1 -Part core|tools`, each on its own fixture) and finishes in about 550 s instead of 626 s, within its 600 s budget; `-Only runner` still runs the whole suite (#592).

## [2.10.0] - 2026-11-13

User decision records and private repository assets from the asset contracts, agent definition schema 2, and fixes to the write queue, the runner and the orchestrator.

### Added
- `scripts/decisions.ps1` (`-List`, `-Open`, `-Answer`, `-Withdraw`, `-WhatIf`) keeps the questions only the user can settle in the dossier's `decisions.json`, with the contract in `config/decision.schema.json`. Every write is one queued `file.save` with the expected hash, validated again when applied. Only the user answers: no default, no recommendation taken as an answer, no expiry. A durable answer appends one `Decision: … — Reason: …` line with its ID to `memory.md`. `knowledge.ps1 -UpdateTaskId <id> -Awaiting owner-consent -Decision dec-…` links a waiting task to its open decision (#588).
- MCP tool `get_decisions` (read-only, 13 tools in all).
- Private cards and workflows in a repository dossier (`prompts/catalog.json`, `prompts/<name>.md`, `workflows/<name>.json`) with `<repo-slug>/<name>` keys. `list_prompts` and `get_prompt` with `repositoryPath`, and `prompts.ps1 -List -RepositoryPath`, show them only for their repository. `build-prompts.ps1 -Check` refuses collisions with public or other-dossier assets, cross-dossier references, unsafe or too deep workflows and public files that cite a private asset; the publication scan reports `private-asset-reference`. Private workflows are validated, not run yet (#589).
- Agent definition schema 2 in `subagents.ps1`: `agt-` ID, revision, status, cards checked against the effective mode, output contract and delegation bounds (depth 1, budget); schema 1 is still read (#587).

### Fixed
- A queued `task.new` whose dependency can never resolve now gets an `invalid` receipt that `knowledge.ps1 -DiscardPending` accepts, instead of failing at every flush (#563).
- While the runner waits for a plan reset, the interrupted attempt is no longer counted as failed, and the orchestrator shows the resume time under its own label (#564).
- The orchestrator no longer lists a run result twice after reattaching to a running queue.
- The runner suite's timeout case uses a test-only override and takes about 16 s instead of 70 s (#561); interactive setup tests answer the repository-files prompt added in 2.8.0.
## [2.9.0] - 2026-11-13

Il runner riprende da solo la coda quando i limiti del piano si ripristinano, per Claude Code, Codex e Gemini CLI; i pulsanti dell'orchestratore mostrano quando stanno lavorando.

### Aggiunto
- `run-ready-tasks.ps1 -WaitForReset [-MaxWaitHours 24] [-RecheckMinutes 30] [-ResetMarginSeconds 60]`: a un arresto per quota il run resta attivo nella fase `waiting-quota`, attende il ripristino e prosegue, prima il task interrotto con la nota di ripresa. Il tentativo interrotto resta nei risultati con `retried: true` e non conta come fallimento; `resume.json` si scrive comunque e si segna come usato quando il run riprende da solo. Un ripristino oltre l'attesa massima ferma il run come prima; il file di arresto chiude subito l'attesa.
- Orario di ripristino (`Get-SBAgentLimitReset`, `Get-SBRunnerResumeTime` in `SecondBrain.AgentAdapters.psm1`): dalla lettura della quota (`rate_limit_event` di Claude Code, file di sessione di Codex), altrimenti dal testo del limite (Claude `resets 3pm (zona)` e `…|<epoch>`, Codex `try again in …`/`at …`, quota giornaliera di Gemini a mezzanotte, ora del Pacifico), altrimenti un nuovo controllo dopo `-RecheckMinutes`. Un ripristino già passato all'inizio dell'attesa fa ripartire subito. Il limite riconosciuto riporta `resetAt`, che entra anche in `quotaObserved`.
- Verdetto `waiting` in `runner-status.ps1` e nello strumento MCP `get_runner_status`, con `status.quotaWait` (orario di ripresa, fonte, tentativo, scadenza).
- Orchestratore: casella «Riprendi automaticamente al ripristino dei limiti» (attiva per impostazione predefinita) con l'attesa massima in ore; la scheda Esecuzione mostra «In attesa del ripristino» con orario di ripresa e conto alla rovescia.
- Orchestratore: ogni pulsante che avvia un lavoro mostra una rotella e ignora altri clic finché il lavoro non finisce (`busy`/`onBusyClick` in `common.ts`); lo stato attivo o disattivato resta quello deciso dalle viste.

## [2.8.0] - 2026-11-13

Raccoglie il lavoro dei task autonomi eseguiti dal runner nella notte del 13 novembre, rivisto prima del commit, e la correzione del runner desktop.

### Aggiunto
- Repository senza impronta (#484): un repository attivato da ora non riceve file nel checkout. Le istruzioni arrivano dal testo di ambito utente degli IDE e da MCP. `secondbrain.ps1 -Setup -RepositoryFiles AGENTS.md[,CLAUDE.md,GEMINI.md]` (`none` azzera) abilita i file gestiti; `-Interactive` lo chiede e un nuovo Setup mantiene la scelta. I binding creati prima della 2.8.0, senza il campo `repositoryFiles`, continuano a gestire `AGENTS.md`, `CLAUDE.md` e `GEMINI.md` come prima: l'aggiornamento non cambia nessun checkout.
- `secondbrain.ps1 -ResolveBlock <repo|percorso> [-File x]`: anteprima con differenze di un blocco gestito modificato a mano; `-Resolution Generated|Preserve -ApplyResolve` ripristina il blocco generato con backup, e `Preserve` tiene le righe aggiunte a mano dopo il blocco.
- Profili di Setup (#486): `-SetupProfile Solo` (checkout locale, nessuna radice condivisa né ACL; rifiuta `-TeamRoot` e un checkout su share) e `-SetupProfile Studio -TeamRoot <UNC>` (radice condivisa, stato della postazione locale). Il JSON riporta `profile`, `sharedRoot`, `acl` e `state`.
- Raggruppamento per cliente (#485), sul campo `customer` di `repository.json`: `knowledge.ps1 -Customer` e argomento `customer` dello strumento MCP `search_knowledge` (da solo è una lettura globale, soggetta all'isolamento come `-AllDossiers`); `backup.ps1 -Customer` archivia solo i dossier del cliente; `para.ps1 -SetCustomer (-Customer <nome> | -Clear) -Only <id|identità>[,…] [-Apply]` in anteprima per impostazione predefinita, con verifica che id PARA, identità e task restino invariati.
- Riferimenti normativi (#438): `Get-SBTextReferences` riconosce ELI, CELEX, Gazzetta Ufficiale e Gazzetta ufficiale UE oltre ai numeri ufficiali, e li risolve sulle schede registrate. `sources.ps1 -Propose [-Reference …] [-SourceId …]` propone in sola lettura, senza rete, il `metadata.json` di un riferimento in coda, sempre `reference-only`. La forma normalizzata di «n. N del <data> <anno>» diventa `anno/N`.
- Fonti applicabili nello startup (#492): l'indice del dossier elenca solo le fonti `applicable` e `conditional` di `authoritative-sources.json`, dopo averne validato schema e identità.
- Scadenza configurabile delle sessioni (#497): `sessionTimeoutSeconds` in `config/shared.json` (10-86400, predefinito 1800).
- Orologio e identificatori unici (#498): `Get-SBNow` e `New-SBId` in `SecondBrain.Core.psm1`, con `Set-SBClockSource` e `Set-SBIdSource` per i test; un controllo del gruppo `quick` impedisce nuovi usi diretti fuori da Core e dai test.
- `config/agent-models.json`: verifica dei modelli Gemini (Gemini CLI 0.68.0, 2026-11-13) e i modelli `gemini-3.5-flash` e `gemini-3.1-flash-lite`.
- `config/publication-policy.json`: `ignoredReviews` registra la revisione di cartelle ignorate da Git (`app/orchestrator/dist/`, `app/orchestrator/node_modules/`), che la scansione di pubblicazione riporta come riviste.

### Modificato
- Cartelle di lavoro (#414): `work.ps1` esporta solo `SECONDBRAIN_WORK_ROOT`; TEMP, TMP, cache degli strumenti e output di build restano nelle cartelle native del sistema e del prodotto. `evidence` e `report` hanno una scadenza di revisione di 90 giorni, senza rimozione automatica.
- `SecondBrain.Mcp.psm1` diviso (#464): il server resta in `Mcp`; configurazione dei client e funzioni native in `SecondBrain.McpConfig.psm1`, pacchetto in `SecondBrain.McpPackage.psm1`. Gli export complessivi sono invariati e `Portable` non dipende più dal server.
- `Invoke-SBPendingWrites` scomposto in funzioni di supporto con test di caratterizzazione (#466, primo passo).
- Il budget di tempo dei profili di test è un avviso: il superamento è scritto in `run.json` (`budgetExceeded`, `warnings`) e non fa fallire la suite (#498).

### Corretto
- `sb runner` su Windows (`scripts/runner-gui.ps1`): lanciato da un agente dentro un'app pacchettizzata come Claude desktop, il runner desktop restava nel pacchetto MSIX o nel job object del chiamante, e Windows lo chiudeva insieme all'app quando questa si chiudeva, andava in crash o si aggiornava. La coda si fermava al task in corso e la corsa restava `orphaned`. Ora lo script riconosce pacchetto e job e in quel caso avvia l'app tramite WMI (`Win32_Process.Create`), fuori da entrambi, con l'ambiente del chiamante e `SECONDBRAIN_HOME`. Altrimenti resta ShellExecute. Il JSON riporta `launchMethod`, `packageFullName`, `inJob` e `pid`; `-LaunchMethod auto|shell|wmi` forza il metodo. Guida in `docs/orchestratore.it.md`.

- `recover.ps1`: il ripristino di una transazione PARA rimuove le cartelle rimaste vuote dai file che aveva creato (#419).
- `resources.ps1 -Restore` usciva con codice 2 dopo aver scaricato, perché una variabile coincideva con il parametro `-Restore` (#526).
- `sources.ps1 -AddEffectiveDate` risolve sul posto una disposizione ancora `requires-verification` quando la nuova data è verificata (TASK-533). Date di efficacia verificate per L. 132/2025 (2025-10-10) e per la delibera ARERA 135/2022/R/com (2022-07-01), con `CONTROL.json` e `INDEX.md` rigenerati.

### Test
- Gruppo `runner`, fase `runner-gui` (solo Windows): un file non eseguibile è rifiutato da `Win32_Process.Create`; un programma vero avviato via WMI riceve un PID diverso da quello del chiamante; un'uscita con errore immediata viene letta anche via WMI; `-LaunchMethod shell` mantiene ShellExecute e riporta `inJob`.
- Nuovo gruppo `shared` (#487, `test-secondbrain-shared.ps1`): due identità simulate sullo stesso dossier, creazioni concorrenti senza perdite, conflitti visibili e registro delle postazioni. In `-Full` gira dopo le suite parallele, come `concurrency`.
- Nuova suite `test-secondbrain-customer.ps1` nel gruppo `trace`; controlli nuovi in `portable` (profili, file del repository, `-ResolveBlock`), `quick` (orologio, identificatori, compatibilità dei binding), `pending` (sessioni scadute, ricevute), `sources` e `resources` (riferimenti e proposte).
- `tracker-audit` importa direttamente `SecondBrain.Host.psm1`; il controllo del profilo Solo su share usa lo script della fixture tramite loopback.
- `test-secondbrain-mcp-handshake.ps1`: le annotazioni attese seguono le letture pure (#474) e `get_ready_tasks` è chiamato nell'ambito del repository, perché la lettura globale `all=true` è rifiutata dall'isolamento dei progetti.

## [2.7.2] - 2026-11-12

### Modificato
- Direttive comuni, revisione 1.2 (proposta `direttive/proposals/2026-11-12-sb-stop`, approvata e distribuita con `-Sync`): il testo di postazione elenca `sb stop` (MEM09: ferma, salva la sessione nel dossier, riprendi altrove con MEM07) tra i comandi `sb`; il testo comune cita MEM09 tra le procedure caricate da `sb prompt`. Blocco repository invariato; +100 caratteri al contesto iniziale.

### Test
- Gruppo `prompts`: `sb stop` descritto nel testo di postazione.

## [2.7.1] - 2026-11-12

### Corretto
- Analisi con modello leggero su Claude Code (`agents.ps1 -Analyze`, per esempio **Proponi struttura** delle direttive): lo schema passato in linea a `--json-schema` non contiene più la dichiarazione `$schema` della bozza 2020-12, che il validatore della CLI non carica e che faceva fallire l'analisi con «--json-schema is not a valid JSON Schema». Gli schemi di `config/analysis/` restano invariati e la verifica locale della risposta usa ancora il file intero.

### Test
- Gruppo `agents`: lo schema in linea per Claude di ogni schema di `config/analysis/` è privo di `$schema`.

## [2.7.0] - 2026-11-12

### Aggiunto
- Prompt MEM09 e comando `sb stop` (alias `sb ferma`): ferma l'agente prima di un limite d'uso orario, giornaliero o settimanale, ferma un eventuale giro del runner, chiede cosa fare del lavoro non committato (lasciarlo nel checkout, commit WIP su branch dedicato con push solo se autorizzato, nessuna azione), salva il rapporto di passaggio nel dossier in `history/<data>-stop-<slug>/report.md`, lascia il task `in_progress` con `stateReason` che lo cita e aggiorna «Prossimo passo» in `context.md`. Il dossier è condiviso tra postazioni e account, quindi la ripresa con MEM07 funziona anche da un altro IDE, account o postazione; catalogo di 121 prompt.
- Attivazione (`Invoke-SBHostActivation`): un repository con un proprio `tracker.json`, `tasks.json` o `legacy-tasks.json` (oltre a `tracker.md`) passa a `tracker-import-required` invece di ricevere un tracker vuoto; il piano indica la fonte e se è già compatibile con lo schema 1.

### Modificato
- SYS03, passo 6: per ogni repository attivato importa il tracker con `import-tracker.ps1` (anteprima, poi `-Activate -Apply` su conferma); senza tracker esegue una ricognizione (COM01, controlli REP08: TODO/FIXME, test saltati o in errore, stub, CI, dipendenze, documentazione), la salva in `history/<data>-ricognizione/report.md` e crea con `knowledge.ps1 -NewTask -Provenance` solo i task approvati.
- MEM02 cita `import-tracker.ps1` (`-ResumeManifest`, `-RollbackManifest`) e il ramo di ricognizione; MEM07 legge per primo il rapporto MEM09 e il branch WIP; MEM08 propone MEM07 quando un task in corso rimanda a un rapporto MEM09; schermata `sb prompt` con `sb stop`.
- Documentazione: conteggio a 121 schede, tabella delle aree completata (COM08, DOC05, DOC06, MEM09, REP18), `sb stop` nelle tabelle dei comandi.

### Test
- Gruppo `prompts`: `sb stop` nel registro dei comandi e composizione di MEM09.

## [2.6.1] - 2026-11-12

### Corretto
- Il lanciatore per repository `.secondbrain/run-tasks.ps1` inoltra al runner `-Provider`, `-Model`, `-Effort`, `-UseCliDefault` e `-AllowCustomModel`: prima il suo `-Run` usciva sempre con 2 quando la CLI accetta modello o impegno.
- `install-task-launcher.ps1` riconosce per hash un lanciatore installato da un modello precedente e mai modificato (stato `outdated`) e con `-Apply` lo sostituisce con backup verificato; un lanciatore modificato resta `different` e non viene toccato.
- Documentazione (DOC01, inglese e italiano): letture, Check, prompt e MCP non integrano mai le scritture accodate, lo fa solo `knowledge.ps1 -FlushPending` (#474); attesa del lock di una scrittura da CLI fino a `SECONDBRAIN_PENDING_WAIT_SECONDS` (predefinito 8 s) invece di «nessuna attesa»; esempi di `run-ready-tasks.ps1 -Run` con `-UseCliDefault` o `-Model`/`-Effort`; opzioni di `-UpdateTaskId` (`-Evidence`, `-Acceptance`, `-Description`, `-DecisionsFile`, `-Awaiting`, `-Requires`), registro `history/task-runs.jsonl`, `-Registry` e `-BackfillTaskRuns` nei tracker; `sb runner` nelle tabelle dei comandi; quota letta da ogni lanciatore nel ciclo su più repository; rimosso l'alias ritirato REP02. Nella voce 2.6.0 l'opzione indicata come `-Decisions` è `-DecisionsFile`.

### Test
- Gruppo `runner`: sostituzione di un lanciatore `outdated` e inoltro delle opzioni di modello tramite un runner sostitutivo.

## [2.6.0] - 2026-11-12

### Aggiunto
- Analisi in sola lettura con un modello leggero (`agents.ps1 -Analyze -Kind directives|task|task-resolve`, `Invoke-SBAgentOneShot`): profilo `ReadOnly` (Claude Code `plan` con Read, Grep e Glob, Codex `read-only`, Gemini `--approval-mode plan`), schema JSON nativo se la CLI lo offre (`--json-schema`, `--output-schema`) o nel prompt, quota letta prima, una nuova richiesta se la risposta non rispetta lo schema. `roles.light` in `config/agent-models.json`, sostituibile in `agent-models.local.json`; schemi in `config/analysis/`.
- Prompt DOC06 (direttive di repository proposte dal modello leggero, solo ciò che i blocchi caricati non coprono) e REP18 (analisi che rende autonomo un task, con chiamate `ask_user`, `propose_task_update`, `mark_not_automatable`); catalogo di 120 prompt.
- Registro delle esecuzioni del dossier `history/task-runs.jsonl` (schema `config/task-runs.schema.json`): un record per cambio di stato, esecuzione o evidenze nella stessa transazione del tracker, con l'esecutore (`Resolve-SBExecutor`: esplicito, `SECONDBRAIN_EXECUTOR`, ambiente della CLI, client MCP, `unknown`). `knowledge.ps1 -Registry` unisce tracker, archivio, registro e rapporti del runner; `-BackfillTaskRuns` copia i rapporti precedenti una volta sola.
- `knowledge.ps1 -UpdateTaskId` accetta `-Evidence`, `-Description`, `-Acceptance` e `-Decisions` (in `extensions.decisions[]`); MCP `task.update` accetta `evidence` (stringhe `riferimento|esito` o oggetti `{reference, outcome}`). Il prompt del runner passa all'agente il blocco «Decisioni della persona».
- Orchestratore: **Proponi struttura (modello leggero)** nelle Direttive con motivazioni, fonti e anteprima dei blocchi già caricati rispetto al budget di 25.000 caratteri; in Coda l'elenco completo dei task non avviabili con **Analizza**, domande a scelta multipla e conferma del confronto prima/dopo; passo **5 Registro** con badge per strumento, task archiviati e storico dei run (`runner-status.ps1 -List`); **Modello leggero per le analisi** nelle Impostazioni; note della finestra come eventi `ui` in `events.jsonl`.

### Modificato
- Un solo ciclo di processo per runner e analisi (`Invoke-SBAgentProcess`); cartelle per task uniche `<data>-runner-<seq>-<HHmmss>`; il runner passa `work.ps1 -Client <provider>`; chiusura dei task unificata in `Set-SBTaskClosure`.
- `orchestrator-e2e`: sei scenari, con proposta delle direttive, registro e analisi di un task.

### Corretto
- Il runner legge l'uscita 5 (scrittura accettata ma rinviata) come `deferred`, non come errore.
- `Get-SBRoadmap` conta i task completati anche nell'archivio; `archivedTasksCount` si ricalcola al salvataggio.
- L'orchestratore passa `WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS` alle finestre dopo gli argomenti di wry: il runtime WebView2 ignorava la variabile e la porta DevTools dei test restava chiusa.
- Registro: una pagina con un solo task restava un oggetto JSON invece di un elenco; una risposta lenta a un filtro precedente non sovrascrive più le righe.

## [2.5.0] - 2026-11-12

### Aggiunto
- Quota letta prima del run e prima di ogni task, mai riusata (`Get-SBAgentQuota`): Codex dai file di sessione (`rate_limits`, finestre di 5 ore e settimanale), Claude Code e Gemini CLI dall'ultimo limite segnalato da un agente sulla postazione (`rate_limit_event` o arresto per quota). `exhausted` con ripristino futuro non avvia agenti; `unknown` procede finché l'agente segnala il limite. Riga `quota` negli eventi e `quota`/`quotaObserved` in `status.json`.
- Ripresa dopo un limite: l'arresto per quota scrive `resume.json` (task interrotto, coda residua, riga del limite, ripristino, stato Git) e rimette in `todo` il task lasciato in corso; `run-ready-tasks.ps1 -Resume latest|<run>` riparte da lì con una nota di ripresa per l'agente.
- Prompt MEM07 (riprendi il lavoro fermato da un limite d'uso, importandolo da un altro account, branch o worktree) e MEM08 (avvio di sessione: posizione, stato del repository, allineamento e prossimi task); catalogo di 118 prompt.
- `sb prompt` legge la cartella corrente e ne indica la posizione (repository gestito, senza onboarding, checkout di SecondBrain, nessun progetto), separa i comandi per il repository da quelli di attivazione e manutenzione di SecondBrain e propone la catena iniziale standard.
- Modalità ridotta: in un repository senza dossier i prompt di repository si compongono senza dossier con un blocco `<degraded>` che elenca le funzioni non disponibili.
- MCP `get_prompt` accetta `repositoryPath` facoltativo: contesto e task pronti del repository nei prossimi passi.
- `sb runner` da riga di comando riporta `choices` (modelli, impegni, predefiniti e quota di ogni agente pronto, letti al momento).

### Modificato
- `run-ready-tasks.ps1 -Run` richiede `-Model` ed `-Effort` (se la CLI li accetta) oppure `-UseCliDefault`; senza scelta esce con 2 ed elenca le opzioni appena lette. REP15 chiede agente, modello e impegno in chat con una domanda a scelta multipla prima di ogni avvio.
- Orchestratore: alla pressione di Avvia rileva di nuovo gli agenti, la conferma mostra modello e impegno effettivi e passa `-UseCliDefault` per il predefinito; lo stato mostra la quota letta e la data di chiusura di un run concluso.

### Corretto
- Falsi arresti per quota: il limite si riconosce solo nell'involucro d'errore finale dell'agente con i testi di ciascun provider, mai nel testo dell'agente, nell'output degli strumenti o nello stderr di un agente interrotto; un limite di frequenza temporaneo (429, `rate_limit_error`, quota al minuto di Gemini) è `throttled` e non ferma il giro; timeout e crash conservano il proprio stato.
- `Get-SBAgentCapabilitiesAll` senza `-Provider` passava l'elenco dei provider come un solo valore.
- Fixture `orchestrator-e2e`: titoli dei task con il separatore `—` richiesto dal tracker.

## [2.4.0] - 2026-11-12

### Aggiunto
- Monitoraggio del runner: l'agente scrive a eventi (Claude Code `stream-json`, Codex `exec --json`, Gemini `stream-json` se offerto) letti riga per riga in `agent-output.jsonl`; eventi `agent` compatti (`start`, `tool`, `text`, `result`, `error`). Con `-Run` ogni giro ha una cartella `report/<data>-runner-run-<ora>-<pid>` con `status.json` (fase, PID, task, ultimo segnale, conteggi, file di arresto) aggiornato a ogni evento e almeno ogni 15 secondi, ed `events.jsonl`. `-StallMinutes` (predefinito 5) emette `stalled` senza fermare nulla; un secondo `-Run` sullo stesso repository esce con 2 finché il primo è vivo.
- `scripts/runner-status.ps1` (verdetto `working`, `stalled`, `finished`, `orphaned`, `none`; `-Follow`, `-Stop`) e lo strumento MCP in sola lettura `get_runner_status` (12 strumenti).
- `scripts/runner.ps1`: `sb runner` apre l'orchestratore desktop sul repository corrente (`-Mode auto|gui|cli`) e ripiega sull'anteprima della CLI con il motivo (`prerequisites-missing`, `build-failed`, `no-display`, `launch-failed`); REP15 chiede prima la scelta fra app desktop e riga di comando.
- Orchestratore: precaricamento del repository da `--repo`, flusso a passi con testata di riepilogo, rimozione dei repository recenti persistente, pannello di esecuzione con verdetto, passi dell'agente ed età dell'ultimo segnale, dialogo alla chiusura con coda attiva e riaggancio del run alla riapertura.
- Suite `orchestrator-e2e` (Playwright via DevTools di WebView2 sul binario di rilascio, SecondBrain sintetico di `test-orchestrator-fixture.ps1`), inclusa in `-Full`.
- Prompt DOC05 (diagrammi, locandine, infografiche e flussi per social, siti e marketing dal codice reale) e COM08 (intento del progetto, limiti, applicabilità in produzione e confronto con alternative note); catalogo a 116 prompt.

### Modificato
- Rilevamento degli agenti: oltre al `PATH` ereditato, `PATH` utente e di sistema dal registro, WinGet Links, WindowsApps, npm, pnpm, Volta, scoop, bun, Homebrew, snap, nvm, fnm e `~/.local/bin`, e Codex del Microsoft Store; probe in parallelo con `status` e `origin`; `agents.ps1 -Probe -Clients` elenca anche gli IDE non pilotabili con il motivo.
- Modelli: gli elenchi contengono solo ciò che la CLI installata e la sua configurazione espongono; la tabella di riserva serve solo a convalidare un modello scritto a mano e un agente non installato non espone modelli.
- Orchestratore: la coda parte come processo staccato con log su file; le impostazioni si leggono e si scrivono a ogni modifica invece di riscrivere una lista in memoria; «Importa testo da file» copia il testo nell'editor; il bersaglio delle direttive è sempre il blocco gestito del dossier.
- `Get-SBHostId` funziona anche fuori da Windows.

### Corretto
- I repository rimossi dall'orchestratore non ricompaiono più dopo la riapertura o il salvataggio delle impostazioni.
- Codex installato solo come pacchetto del Microsoft Store risultava non installato; Gemini non installato mostrava i modelli della tabella di riserva.
- Processo agente con codifica UTF-8 esplicita su standard input, output ed errore.
- Documentazione: il runner scrive il tracker solo per parcheggiare come `user_required` un task rimasto `todo`.

## [2.3.0] - 2026-11-12

### Aggiunto
- `sources.ps1 -Decide` (`accept`, `reject`, `known-variant`): chiude una versione di fonte senza modifiche a mano; ogni decisione si aggiunge a `entries/<id>/decisions.json` (`config/source-decisions.schema.json`) con motivo, autore, data e impronta, fuori dall'hash della scheda. Una candidata rifiutata (`reviewStatus` `rejected`) non è più pendente e lo stesso contenuto non viene ricollezionato; una variante nota di una versione verificata non è segnalata come `changed` (#490).
- `sources.ps1 -AddEffectiveDate`: aggiunge una data di efficacia a una scheda validata; Check segnala `effective-date-unverified` per normativa e legale con date `requires-verification` (#489).
- Categoria dichiarata derivata da `kind` (`Get-SBSourceCategory`: normativa, legale, prodotto, riferimento), con i nuovi tipi `dependency`, `license` e `runbook` e la colonna nel catalogo (#489).
- Test end-to-end di `mapping-outdated` sulle schede dei dossier (#439).

### Modificato
- `source.schema.json`: per `regulation` e `decision` sono obbligatori giurisdizione diversa da `Global`, identificativo ufficiale e almeno una data di efficacia (#489).
- Registro: date di efficacia per D.Lgs. 151/2015, D.Lgs. 185/2016 (verificate), L. 132/2025 e ARERA 135/2022 (da verificare); candidata nist-ssdf 20261110 rifiutata e variante nota EDPB 20261027 registrata (#448).
## [2.2.0] - 2026-11-12

### Modificato
- Direttive revisione 1.1 «contesto snello» (proposta `2026-11-12-contesto-snello`): testo comune, postazione e blocco gestito di `AGENTS.md` ridotti; la chiusura aggiunge una voce di memoria solo per una nuova decisione durevole e sostituisce lo stato di `context.md` invece di estenderlo.
- Tetto di avvio Slim da 50.000 a 25.000 caratteri (`Get-SBSlimStartupBudget`, configurazione portabile, `knowledge.ps1 -Budget`). La vista memoria per agenti ha un tetto di 5.000 caratteri, voci abbreviate senza motivi e priorità vincoli > gotcha > decisioni; le voci omesse restano in `memory.md`. Il profilo Full elenca i task in una riga ciascuno. `-Startup -Report` conta anche le definizioni degli strumenti MCP.

### Aggiunto
- `cleanup.ps1 -CheckRuntime`: motivo `foreign-content` per una cartella conforme che contiene un layout `.runtime/hosts/<id>/repos/<altro>` annidato di un altro repository (reparse point non seguiti, cartelle `fixture` escluse) (#530).
- `test-secondbrain-pending.ps1` (60 verifiche CLI della coda pendente) eseguito da `-Only pending` e da `-Full` (#521).

### Corretto
- Conteggio dei turni della traccia: `ts` letto con `-DateKind String` e cultura invariante; con cultura it-IT giorno e mese si scambiavano quando entrambi ≤ 12 (dal 12 novembre), non per la mezzanotte (#528). Stessa lettura per le righe native del ciclo memorie.
- PARA: dopo `Archive`/`Restore` l'albero vuoto rimosso viene atteso finché sparisce (cancellazione pendente su Windows con handle aperti); il test tracker-audit riporta l'output del CLI in caso di errore (#525).
## [2.1.0] - 2026-11-12

### Aggiunto
- Comando `sb runner` (`scripts/runner-gui.ps1`): apre il runner desktop `app/orchestrator` su Windows, macOS e Linux e lo compila prima con `npm run tauri build -- --no-bundle` quando il binario manca o è più vecchio dei sorgenti; `-Rebuild` forza la compilazione, `-NoLaunch` e `-WhatIf` non avviano l'app. Fase `runner-gui` in `-Only runner`.

## [2.0.0] - 2026-11-12

### Rimosso (incompatibile)
- Letture tra progetti: `crossProjectReads` in `config/shared.json`, `extensions.readRepositories` dei task e `SECONDBRAIN_RUNNER_READS` non esistono più; ogni repository legge e scrive solo il proprio dossier (#475).

### Modificato (incompatibile)
- Letture pure: `knowledge.ps1`, `prompts.ps1`, `secondbrain.ps1 -Check` e il server MCP non integrano più le scritture accodate; il recupero avviene solo con `knowledge.ps1 -FlushPending`, limitato al dossier in lavoro. Tutti gli strumenti MCP tranne `submit_dossier_write` dichiarano `readOnlyHint=true` (#474).
- `03-resources` è tracciato in Git (metadati, trascrizioni, evidenze delle fonti riusabili), esclusi gli originali scaricabili e gli screenshot QA; `resources.ps1 -Restore` e `-Sync` ripristinano gli originali con verifica SHA-256. `check-distribution` controlla originali e licenze (#478).

### Aggiunto
- Gruppo di test `cleanclone` (Full e CI): attivazione da un clone pulito (#479).
- Gruppo di test `lint` (`-Only lint`, incluso in `-Full`); rilievi ammessi documentati in `PSScriptAnalyzerSettings.psd1`.
- `cleanup.ps1 -CheckRuntime` (sola lettura): ogni cartella `hosts/<id>/repos/<repo>/<categoria>/<yyyyMMdd>-<slug>` deve avere un `MANIFEST.json` coerente con postazione, repository, categoria e nome; elenca le cartelle fuori schema con il motivo ed esce 1 se ne trova. `-RuntimeReport` aggiunge la sezione «Cartelle fuori schema» (`Get-SBRuntimeOwnership`, #477).

### Corretto
- `Invoke-SBPendingWrites -Repository` integra solo le richieste del dossier indicato; le voci differite riportano il proprio repository (#473).
- Lint: catch vuoti registrati con `Write-Verbose`, assegnazioni inutilizzate e confronti con null corretti (rilievi da 160 a 107).
- `app/orchestrator`: la coda non preseleziona alcun task (#517); vite 6.4.6 azzera il rilievo di npm audit (#518).

## [1.23.1] - 2026-11-11

### Corretto
- `app/orchestrator`: su Windows la radice di SecondBrain risolta con `canonicalize` aveva il prefisso `\\?\` e gli script segnalavano «Postazione non attivata»; il prefisso viene rimosso (`plain_path`, con test). I messaggi di errore mostrano il codice di uscita come numero invece di `Some(2)`.

### Modificato
- `app/orchestrator/src-tauri/Cargo.lock` tracciato in Git per build riproducibili.
- `docs/orchestratore.md` e `docs/orchestratore.it.md`: limiti aggiornati con le prove locali (build Rust, finestra fino all'anteprima della coda) e con GitHub Actions disabilitato sul repository.

## [1.23.0] - 2026-11-11

### Aggiunto
- `app/orchestrator`: app desktop Tauri 2 (Windows, macOS, Linux) che sceglie un checkout gestito, prepara e approva le direttive specifiche del repository, compone la coda dei task pronti con provider, modello e impegno e la esegue in sequenza con avanzamento in tempo reale. Guida in `docs/orchestratore.md`.
- `scripts/SecondBrain.AgentAdapters.psm1` e `scripts/agents.ps1`: probe delle CLI Claude Code, Codex e Gemini (`--version`, `--help`, configurazione locale, tabella di riserva `config/agent-models.json` con override per postazione), argomenti headless con profilo di permessi fisso; `-Directives` legge le direttive e prepara o applica una proposta tramite `approve-revision.ps1` e `secondbrain.ps1 -Sync`.
- `run-ready-tasks.ps1`: `-Provider claude|codex|gemini`, `-Model`, `-Effort` validati sul probe (`-AllowCustomModel`), `-TaskIds` per una coda esplicita ordinata, `-Events` (righe JSON su standard error), `-StopFile`; schema di quota esteso a Codex e Gemini.
- Gruppo di test `agents` (36 verifiche) e nuove verifiche nel gruppo `runner`; job CI `orchestrator` su Ubuntu, macOS e Windows.

### Modificato
- `check-distribution.ps1` ammette `app/` nel perimetro pubblico.

## [1.22.3] - 2026-11-11

### Aggiunto
- Test Quick: nessun ciclo nel grafo dei moduli (compresi gli `Import-Module` tardivi), con prova su un ciclo sintetico.

### Modificato
- Refactoring interno senza cambi ai contratti: `Get-SBParaRuntimePaths` passa da `SecondBrain.Para.psm1` a `SecondBrain.TrackerImport.psm1` (spezza il ciclo Tracker/Para/TrackerImport; `para.ps1` e `recover.ps1` importano TrackerImport).
- Il vocabolario dei valori di `extensions.requires` e il nome `computer-use` stanno in `SecondBrain.ComputerUse.psm1`; Tracker (`Get-SBTaskRequiresValues`, wrapper omonimo) e TaskRunner li leggono da lì.

## [1.22.2] - 2026-11-11

### Aggiunto
- Workflow GitHub Actions su `windows-latest` (Quick, indici dei prompt, distribuzione, lint, scansione di pubblicazione) e badge di stato nel README.
- Test Quick: i numeri di strumenti MCP e prompt citati nei documenti derivano dal codice; ancore e file dei link interni esistono; nessun titolo legato a una versione.
- README: destinatari (singolo utente, studio), isolamento per repository, registro delle fonti e quando non usare SecondBrain.

### Modificato
- `build-prompts.ps1 -Check` gira anche senza postazione attivata (clone pulito).
- Suite predefinita: i gruppi essential girano in tre processi paralleli con fixture proprie (circa 58 s, budget 120 s); `-Only` e `-Sequential` li eseguono in un solo processo. `test-secondbrain-essential.ps1` accetta `-Groups` separati da virgola.
- 81 messaggi di errore (`prompts.*`, `promptscli.*`, `trackerimport.*`) indicano il prossimo passo, senza punto finale per frase singola.
- `knowledge.ps1`: le scritture accettate ma non ancora applicate (differite o in conflitto) escono con 5; 0 significa applicata. Tabella dei codici 0-5 documentata e verificata da Quick.
- `secondbrain.ps1 -Check`: `aligned` dipende solo dai file (`issues`); i rilievi ambientali (caricamento IDE, account, consenso MCP, ambito di scrittura, fonti, compattazione) sono nel nuovo campo `environment` e non cambiano il codice di uscita.
- Test: `-Setup -All` è rifiutato con il prossimo passo (`-AllIdes`).
- Documenti corretti: undici strumenti MCP, 114 prompt, ancore senza versione, link italiani verso le pagine italiane.
- Baseline di lint aggiornata (161 riscontri: due nuovi file con accenti, uno risolto).

## [1.22.1] - 2026-11-11

### Aggiunto
- `knowledge.ps1 -PendingWrites`: `-PendingSummary` (totali per stato) e `-PendingState` (filtro); output predefinito invariato.
- `setup-status.ps1`: funzionalità raccomandate in testa, `summary` per funzionalità e oggetto `exit` che spiega il codice di uscita.
- Test Quick: una chiave di messaggio ha una sola definizione.

### Modificato
- `-NewTask` e `task.new` validano priorità, ID e titolo.
- `computer-use.ps1`: ID app senza spazi, hash mancante distinto, comando di applicazione in anteprima, usi senza argomenti, tabella non annidata.
- `run-ready-tasks.ps1`: agente mancante con errore pulito e uscita 2.
- Circa 70 messaggi di errore (`portable.*`, `tracker.*`, `backup.*`, `recover.*`) indicano il prossimo passo.

### Corretto
- Sei definizioni duplicate di messaggi tra script e moduli.

## [1.22.0] - 2026-11-11

### Aggiunto
- `computer-use.ps1`: `-Table` stampa la tabella delle capacità per IDE (computer use pre-approvabile o no); `-CodexApps -AppId` mostra in anteprima l'aggiunta di app a `[computer_use.windows] always_allowed_app_ids` di Codex e `-Apply -PreviewSha256` la scrive con backup verificato (solo aggiunte).
- Preflight del runner dalla tabella: i task con `requires:computer-use` girano solo se l'agente ha una pre-approvazione documentata e presente; l'anteprima riporta `computerUse`.
- `-Requires` in `knowledge.ps1` (`-UpdateTaskId`, `-NewTask`) e campo `requires` nei tool MCP di scrittura, con valori validati.
- Avviso soft di budget all'avvio: il totale conta anche `AGENTS.md` e la direttiva globale più grande (#458).

### Modificato
- 17 messaggi di errore (it/en) indicano ora il prossimo passo (sessioni di accesso, task non trovato, scritture differite, agente del runner, parametri MCP).
- La policy di pubblicazione non ha più il ripiego su `.runtime/publication/policy.json` (#435); `publication.ps1 -MigratePolicy` la copia una volta nel file tracciato.
## [1.21.0] - 2026-11-11

### Aggiunto
- Runner (`run-ready-tasks.ps1`): i task con `extensions.requires` = `computer-use` sono esclusi con motivo `requires:computer-use`, perché `claude -p` non può approvare le app.
- `Invoke-SBPendingWrites -WaitMs`: le scritture differite attendono il lock in modo limitato (`SECONDBRAIN_PENDING_WAIT_SECONDS`, predefinito 8 s); `knowledge.ps1 -FlushPending` attende la durata standard del lock e il runner integra i pendenti dopo ogni task.

### Modificato
- Tetto del primo caricamento Slim da 30.000 a 50.000 caratteri, con fonte unica `Get-SBSlimStartupBudget` (rimossi i default duplicati); direttiva globale aggiornata con la proposta `2026-11-11-startup-cap-50k`.
- `test-secondbrain.ps1 -Full`: il gruppo `concurrency` gira da solo dopo i gruppi paralleli.
- Documentato il codice di uscita di `secondbrain.ps1 -Check` e `ide-map.ps1 -Verify`.

## [1.20.0] - 2026-11-10

### Aggiunto
- `resources.ps1 -Check|-BuildIndex|-Sync [-IfStale]`: alberatura standard di `03-resources`, file di controllo `CONTROL.json` e indice `INDEX.md` per ogni risorsa, sincronizzazione del registro delle fonti con nuove versioni solo candidate, chiusura dei riferimenti normativi con limiti e coda di revisione `normative-queue.json`.
- Controllo `mapping-outdated`: una mappatura di prodotto che punta a una versione precedente a quella accettata di un regolamento o decisione.
- `resources-hook.ps1`: ponte non bloccante di avvio sessione per `-Sync -IfStale`; `-ShowConfiguration` stampa la voce senza modificare impostazioni.
- `setup-status.ps1` e prompt SYS17 (`sb setup`): prima configurazione guidata con funzioni facoltative proposte dallo stato della postazione.
- `lint.ps1` con `config/PSScriptAnalyzerSettings.psd1` e baseline `config/lint-baseline.json`.
- Gruppi di test `resources` e `setup-status`.

## [1.19.0] - 2026-11-10

### Aggiunto
- `secondbrain.ps1 -AddRepo <percorso> [-Customer] [-ApplyAdd]`: arruola un solo repository con anteprima, in `config/local/allowlist.json`; con l allowlist presente la discovery non legge né elenca i repository esterni.
- `secondbrain.ps1 -NewProject <percorso> [-Remote] [-Customer] [-ApplyNew]`: progetto da zero (cartella, git init, allowlist, dossier, tracker, greenfield, cliente).
- `knowledge.ps1 -Roadmap [-Format Markdown|Json] [-Since]`: roadmap degli interventi del solo repository in lavoro.
- `publication.ps1 -MigratePolicy -ApplyMigration` e policy tracciata `config/publication-policy.json`, letta da CLI e MCP: il reset di `.runtime` non cambia l esito.
- Test di perimetro (knowledge, MCP, work.ps1), di allowlist, new-project, roadmap e policy tracciata.

### Modificato
- `work.ps1` rifiuta in una sessione runner i repository diversi da quello del task.
- Budget di `test-secondbrain.ps1 -Full` da 300 a 600 s (run parallelo misurato 300-450 s; concurrency passa da sola).

### Rimosso
- `-All` dal Setup.
## [1.18.0] - 2026-11-10

### Aggiunto
- `para.ps1 -NewArea`: crea una PARA area in `02-areas/<id>` (responsabilità continua senza data di fine). Create le aree `governance`, `postazione` e `direttive`. Un'area senza `repository.json` non è più trattata come dossier di repository.
- Un `README.md` per ogni cartella PARA (`01-projects`, `02-areas`, `03-resources`, `04-archives`) e per `config/`, con ruolo, chi scrive e cosa non va messo; guida `docs/riferimento/struttura-cartelle.it.md` con la mappa dei permessi di scrittura.
- Test: `access.ps1 -Start` con `-SessionId` proprio e rifiuto di un identificatore già usato.

### Modificato
- `access.ps1 -Start` accetta un `-SessionId` nuovo (prima lo ignorava e ne generava uno proprio) e rimuove ad ogni avvio le sessioni chiuse, scadute o abbandonate.
- Direttive (revisione 1.0, proposta `2026-11-10-write-map`): le globali dichiarano che SecondBrain si scrive solo tramite script o tool MCP e mai a mano in PARA e `.runtime`; il blocco dei repository limita la scrittura al dossier `01-projects/<repo>/` e chiarisce l'uso del SessionId restituito da `-Start`.
- `.gitignore`: `02-areas/` ignorata, con `README.md` e `.gitkeep` tracciati nelle cartelle PARA.
## [1.17.1] - 2026-11-10

### Modificato
- `para.ps1 -NewProject`: `-Areas` è facoltativo e accetta anche gli id dei dossier dei repository; un progetto a termine può non avere collegamenti (prima richiedeva almeno un'area). Messaggi e descrizioni MCP parlano di dossier repository invece di aree; MEM05 e `tree` descrivono archiviazione e collegamenti dei dossier come progetti.

### Aggiunto
- Documentazione dell'uso stabile di `.runtime` su una postazione di prova (contenuto ammesso, nessun backup, procedura di reset e nuovo Setup) in `runtime-maintenance`.

## [1.17.0] - 2026-11-10

### Modificato
- Allowlist prima di tutto: la discovery richiede `-Roots` esplicite (nessuna scansione di tutti i volumi, anche nel Setup interattivo) e il rapporto `discovery.json` salvato contiene solo i repository scelti, con il conteggio degli altri.
- Isolamento per progetto: `-All`, `-AllDossiers`, `all=true` e le ricerche senza repository risolto sono rifiutati. `config/shared.json` ha `crossProjectReads` (predefinito `false`) per riabilitare le viste tra repository.
- I dossier dei repository sono PARA di tipo progetto in `01-projects/<nome>--<hash>/` con `repository.json`, `specs/`, `material/` e `data/`; il predicato `Test-SBRepoDossier` accetta anche le vecchie aree di `02-areas/products/`. `Setup` crea i nuovi dossier in `01-projects`.

### Aggiunto
- `para.ps1 -MigrateToProjects` (anteprima, poi `-Apply`, `-Only`): sposta i dossier da `02-areas/products/` a `01-projects/` con una transazione PARA per dossier, aggiornando binding e stato.
- Controlli nei gruppi `quick` e `runner` per radici obbligatorie, isolamento predefinito e dossier come progetto.

## [1.16.0] - 2026-11-10

### Modificato
- Catalogo prompt riorganizzato: 113 schede (erano 120) in 17 aree e due gruppi, repository corrente e SecondBrain centrale. Le aree raggruppano per attività o necessità e non più per prefisso del codice; `catalog.json` ha il campo `group` per area e `related` accetta fino a 10 voci.
- Accorpati i prompt duplicati: MEM04 in MEM06, PRG06 in PRG04, DEV08 in SEC01, DEV07 in DEV02, AUD05 in TST06, GOV01 in GOV02, REP10 in REP04. I codici eliminati non si riusano.
- MEM01, MEM06 e AUD04 non escono più dal repository corrente (niente PARA, altri dossier, `.runtime`, licenze); AUD01 è in modalità scrittura perché esporta.

### Aggiunto
- Controlli del catalogo: ogni codice citato in una scheda esiste ed è elencato tra i `related` (`build-prompts.ps1`, suite `prompts`); test su gruppi e perimetro delle schede di repository.

### Corretto
- Il server MCP (`mcp-server.ps1`) legge e scrive lo stdio in UTF-8 senza BOM con flussi espliciti, invece di `[Console]::In/Out` che seguono la code page OEM: trattino lungo e lettere accentate non arrivano più alterati (`Compatibilit├á`) né in ingresso né in uscita. Il gruppo `mcp-writes` forza la code page 850 e verifica l'andata e ritorno.

## [1.15.0] - 2026-11-09

### Aggiunto
- `ide-detect.ps1`: ogni voce della selezione (`-Ides` con `-Scope`, oppure `-Interactive`) include `pairCommand`, il comando `mcp-server.ps1 -Pair -Target <id> -Scope <user|project>` in sola anteprima, senza `-Apply`. Il rilevamento resta in sola lettura.

### Modificato
- `backup.ps1` esclude i dati rigenerabili di `.runtime/hosts`: cartelle `fixture`, `tmp`/`temp` e `fixture-*`, `tmp-*`, `tests-*` dei repository, `sources/python`, ogni `cache` e le cartelle `work` con MANIFEST `closed`. Evidenze, rapporti, work aperti, configurazione e dossier restano. Sulla postazione di sviluppo l'archivio passa da circa 64 GB a 3,18 GB.

### Corretto
- `backup.ps1` e `Get-SBFileHash` calcolano hash e copia in streaming: i file oltre 2 GB (compreso lo zip del backup) non falliscono più con il limite di `ReadAllBytes`.
- Il caso `write-denied` del gruppo `concurrency` sonda l'ACL di rifiuto e, se il processo non la applica (per esempio il tool Bash di un agente), si salta con un avviso esplicito invece di fallire.

## [1.14.0] - 2026-11-09

### Aggiunto
- Prompt WEB07 (hardening di un sito), WEB08 (verifica e aggiornamento dell'indicizzazione e degli strumenti dei motori di ricerca) e WEB09 (governo di crawler e bot IA), in inglese e italiano.
- Nuova categoria «Manutenzione SecondBrain» (prefisso MNT) con MNT01-MNT07: pianificazione del giro, controllo di salute, riordino del dossier, prova di ripristino dei backup, revisione del runtime, aggiornamento di fonti e skill, revisione delle direttive; ogni scheda rimanda ai prompt SYS, MEM e REP correlati.
- Il catalogo conta 120 prompt.
- `.github/CODEOWNERS` con il titolare del repository.

### Corretto
- Il test di handshake MCP (`test-secondbrain-mcp-handshake.ps1`) pretendeva annotazioni uguali per tutti i tool, mentre `preview_dossier_write` è di sola lettura e `submit_dossier_write` è idempotente dalla 1.3.0: l'asserzione ora segue le annotazioni reali (126 controlli su 7 client).
- Conteggi del catalogo (120 prompt in 17 aree) e tabelle delle categorie WEB, AIS e MNT allineati in README e guide.

## [1.13.0] - 2026-11-09

### Aggiunto

- Rilevamento IDE più robusto (Windows): percorsi di installazione noti, affidabilità e prove per ogni IDE, ambiti supportati (utente, progetto, sistema).
- scripts/ide-detect.ps1: elenco in sola lettura con selezione multipla e domanda sull ambito per ogni IDE, anche non interattivo (-Ides, -Scope, -Json).
- Strumento MCP `list_ides` (undici strumenti): la chat propone scelta multipla e ambito; SYS03 lo richiama.
- Prompt WEB01-WEB06 (siti e app web, dalla progettazione al rilascio), AIS01-AIS09 (AI aziendale: inferenza locale, integrazione con applicativi e produzione, chatbot per siti esistenti, RAG, operazioni, conformità, costi, agenti) e COM07 (analisi del repository e skill autorevoli proposte per progetto).
- Gruppo di test `ide` con profilo sintetico.

### Modificato

- REP16 rende i task avviabili da REP15: regole di selezione del runner e anteprima senza `-Run` che deve selezionarli.

## [1.12.1] - 2026-11-09

### Corretto

- Anteprima del runner (`run-ready-tasks.ps1`): `skipped` riporta ogni task pronto escluso con il codice del motivo (`stream:`, `execution:`, `awaiting:`, `status:`, `max-tasks`), così operatore e agente vedono perché un task non parte.
- Schede REP15-REP17 (EN e IT): lo strumento a scelta multipla è opzionale e l archiviazione è automatica.

### Modificato

- Test del runner: copre i motivi di esclusione e il ramo del lanciatore con `SECONDBRAIN_HOME` assente (uscita 2, messaggi it/en).

## [1.12.0] - 2026-11-08

### Aggiunto

- Guardiano delle letture del runner: `run-ready-tasks.ps1` passa all agente `SECONDBRAIN_RUNNER_REPOSITORY` e `SECONDBRAIN_RUNNER_READS`; `Assert-SBRunnerReadScope` (in `knowledge.ps1` e nei tool MCP) rifiuta `-All`, `-AllDossiers`, `all=true`, `allDossiers=true`, letture fuori dall allowlist e scritture fuori dal repository del task. Non è una sandbox: azzerare le variabili toglie il limite.
- Operazione MCP `task.update`: i tool di scrittura accettano `awaiting` e `readRepositories` con la validazione di `Update-SBTrackerTask`, coda con replay idempotente.
- Test del parcheggio del runner (fase `parking`, agente finto) e del guardiano (fase `guard`, CLI e MCP).

### Modificato

- Commento di intestazione di `run-ready-tasks.ps1`: il parcheggio come `user_required` è l unica scrittura del tracker.

## [1.11.0] - 2026-11-08

### Aggiunto

- Allowlist di lettura per task: `extensions.readRepositories` (identità validate), `knowledge.ps1 -ReadRepositories` e `-Awaiting`, anche dalla coda pending. Il prompt del runner elenca le sole letture consentite in sola lettura.
- Regola di perimetro nei prompt operativi (`perimeter`) e nel prompt del runner: solo il repository del checkout, nessun task di altri repository, nessun `-All`, `-AllDossiers`, `all=true`.
- Parcheggio nel runner: un task rilasciato che termina ancora `todo` passa a `user_required`, così un limite ripetuto non viene ritentato.

### Modificato

- REP16: le regole del task (allowlist, permessi, esito atteso, comportamento del runner) si definiscono prima del rilascio, in modo che il task sia autosufficiente. REP15: il runner scrive il tracker solo per parcheggiare.

## [1.10.1] - 2026-11-08

### Modificato

- 
un-ready-tasks.ps1: l agente del runner può usare anche Grep, Glob e Skill (--allowedTools), strumenti di sola lettura o consultazione; i divieti su commit, push, tag, reset, clean e rimozioni restano invariati. Documentato in operations.

## [1.10.0] - 2026-11-08

### Aggiunto

- Tre prompt per la gestione autonoma dei task: REP15 (esegui i task autonomi pronti con il runner, monitora e registra l esito), REP16 (sblocca i task bloccati verificando il motivo reale) e REP17 (riordina il tracker, archivia i completati e metti le qualifiche dopo lo sviluppo). Schede EN e IT, voci di catalogo e indici rigenerati: 94 prompt.
- `test-secondbrain-runner.ps1`: misura per fase del gruppo `runner` (riga PHASES RUNNER).

### Corretto

- `run-ready-tasks.ps1` leggeva il tracker come tabella hash, quindi la selezione passava ogni task da `knowledge.ps1 -Task` (circa 1,3 s l uno). Ora lo legge come oggetti: anteprima da 16 a 2,2 s, gruppo `runner` da 211 a 109 s da solo, Full da 329 a 253 s (budget 300 s).

## [1.9.0] - 2026-11-08

### Aggiunto

- Un lanciatore per ogni repository: `scripts/templates/run-tasks.launcher.ps1` e `scripts/install-task-launcher.ps1`. Il generatore mostra l anteprima per impostazione predefinita; con `-Apply` scrive `.secondbrain/run-tasks.ps1` solo dove manca (mai sovrascrive un file diverso, salta SecondBrain, nessun percorso personale, nulla in stage né committato). Il lanciatore trova SecondBrain con `SECONDBRAIN_HOME` ed esegue il runner solo per il proprio checkout.

### Modificato

- `run-ready-tasks.ps1` gestisce un solo repository: rimosse le opzioni `-Repository` e `-AllRepositories` della 1.8.0; per un altro repository si usa `-CheckoutPath` o il lanciatore. Con un checkout diverso da SecondBrain il prompt indica i percorsi assoluti degli strumenti. Test e documentazione aggiornati (gruppo `runner`, 63 verifiche).

## [1.8.0] - 2026-11-08

### Aggiunto

- `run-ready-tasks.ps1`: avanzamento in console su standard error (selezione, `[n/totale]`, segnale ogni minuto, riepilogo), esecuzione su uno o tutti i repository gestiti con `-Repository` e `-AllRepositories` (ogni agente parte nel checkout del repository; repository senza checkout o dossier saltati e riportati), lettura del tracker una sola volta per la selezione, classificazione `crashed` e `no-output`. Gruppo di test `runner` con agente finto (73 verifiche), incluso in Full. Documentato in `operations`.
- `activity.ps1 -Operation RetentionBackups`: anteprima e applicazione vincolata all hash per i backup del registro attività con record nominativi scaduti.
- Lock Python delle fonti con hash per ogni pacchetto, installabile con `pip --require-hashes`.

### Modificato

- Le scritture del registro attività non conservano più copie binarie nominative in `.runtime/backups`; la scadenza rigenera anche indice e mappa. Il precedente contenuto resta recuperabile dal registro.

## [1.7.0] - 2026-11-08

### Aggiunto

- `scripts/run-ready-tasks.ps1` e `SecondBrain.TaskRunner.psm1`: esecuzione dei task autonomi del tracker, uno per sessione agente nuova. Anteprima per impostazione predefinita, `-Run` su richiesta, timeout, report per esecuzione, arresto per quota o dopo tre fallimenti e divieti di commit, push e cancellazione. Verificato solo nella selezione (Quick 29); l esecuzione con agente reale non è qualificata.

## [1.6.0] - 2026-11-07

### Modificato

- Budget della suite predefinita da 90 a 120 s (misurata a ~91-93 s, nessun errore di test); misura opzionale per controllo di Essential con `SECONDBRAIN_TEST_TIMING=<file>`.

### Aggiunto

- Convenzione `topics/normative|policy/` per le categorie di ricerca, documentata in portable-brain EN/IT.
- Scadenza del registro attività (`activity.ps1 -Operation Retention`): record nominativi oltre 12 mesi sostituiti da aggregati senza utente in `retention.json`, anteprima con hash obbligatorio per `-Apply`, ripresa senza doppio conteggio.
- Definizioni dei subagenti (F8): formato JSON versionato come asset del dossier (`subagents/`), permessi risolti come intersezione con il padre (mai oltre, nessuna scrittura senza il percorso MCP rivisto), export per client in anteprima sotto `.runtime` (`scripts/subagents.ps1`) e campi `parent`/`agent` nel registro attività con verifica della sessione padre.

## [1.5.0] - 2026-11-07

### Aggiunto

- Registro attività del team (F6): schema versionato, registro append-only in `history/activity/`, indici per repository, utente e periodo, mappa Mermaid generata e importazione dei turni Trace (`scripts/activity.ps1`). L'attivazione reale resta separata e disabilitata.
- Verifica delegata di IDE e account (`scripts/ide-observation.ps1`): pacchetto di istruzioni per un agent installato, registrazione della ricevuta con anteprima e hash, potatura dopo `-Unbind`; scheda SYS01 estesa.
- Ricerca nella conoscenza per categoria (`-Category` / `category`: memoria, informazioni, normative, policy, prompt) e incrementale (`-PreviousRevision` / `previousRevision`, risposta `unchanged` senza riscontri ripetuti).
- `-IdeAccount` accetta `observation=<ricevuta>` sotto `.runtime` per leggere revisione e hash invece di digitarli; refusi, alias o id diversi e percorsi fuori perimetro sono rifiutati.

### Modificato

- Il bridge della memoria accetta solo payload nativi con evento Stop; eventi anticipati, altri nomi o payload senza tipo sono soppressi prima di cattura, promozione e sessione writer.
- Permit -Apply richiede `-PreviewSha256` e rifiuta hash mancante, alterato o diverso prima di configurazione, sessioni e ricevute.
- Guide EN/IT e README allineati; fixture positive e negative aggiunte.

## [1.4.0] - 2026-11-07

### Aggiunto

- Operazione CLI Permit con anteprima e autorizzazione esplicita del singolo turno, vincolata a repository, sessione, richiesta e revisioni del collector.
- Fixture del percorso ricevuta → Stop → cattura → promozione, con casi di riuso, divieto, privati e confini nativi dei tre client.

### Modificato

- Il bridge richiede percorso e hash della ricevuta CLI; permessi manuali precedenti e ricevute alterate o obsolete restano soppressi senza bloccare il turno.
- Guide EN/IT con fallback guidato e distinzione tra contratto su fixture e qualifiche live rinviate.

## [1.3.0] - 2026-11-07

### Aggiunto

- Anteprima e invio MCP delle operazioni dossier: stato task, nuovo task, memoria, registro attività e history.
- Ricevuta CLI locale vincolata a contenuto, destinazione, precondizioni hash e ID idempotente; scadenza e rifiuto di piani alterati o obsoleti.
- Guida e matrice dei client per le scritture approvate, con registro attività reale disabilitato fino alla procedura di attivazione.

### Modificato

- Il server espone dieci strumenti; i due nuovi strumenti sono esclusi dalle preautorizzazioni esistenti.
- Gli invii MCP integrano solo la richiesta approvata e preservano conflitti, backup, ricevute e richieste estranee in coda.

## [1.2.0] - 2026-11-07

### Aggiunto

- Export opzionale delle radici scrivibili per Codex CLI e Claude Code, con anteprima, hash del piano, applicazione esplicita e backup verificati.
- Configurazione limitata al dossier, al coordinamento, ai backup e al runtime del repository; esposizione dei dati condivisi e limiti dei client documentati.

### Modificato

- Nuovi marker di transazione in .runtime/access, mantenendo rilevamento e recupero dei precedenti marker nella radice .runtime.
- Esportazione rifiutata per radici troppo ampie, destinazioni di altre sessioni, anteprime obsolete e directory UNC non supportate da Claude Code.

## [1.1.0] - 2026-11-07

### Aggiunto

- Setup team da un checkout locale con radice UNC, anteprima delle destinazioni e attivazione nello stesso flusso interattivo.
- Segnalazione dei dossier personale e team per la stessa identità, con confronto richiesto prima del consolidamento.

### Modificato

- Configurazione, ricevute, inventario e stato IDE del Setup team conservati sul disco locale della postazione.
- Journal di recupero delle transazioni team nel coordinamento condiviso.
- Guida iniziale e SYS03 aggiornati per il flusso locale e team.

## [1.0.1] - 2026-11-06

## [1.2.0] - 2026-11-02

### Aggiunto

- `MEM05`: regola unica per creare, aggiornare, archiviare e ripristinare progetti, aree e risorse del PARA; `para.ps1 -NewResource` e `-SetStatus`.
- `cleanup.ps1 -RuntimeReport`: indice leggibile di `.runtime` (opzionale `.runtime/INDEX.md`) e convenzione `<categoria>-<yyyyMMdd>-<slug>` per le nuove cartelle degli agent.
- `trace.ps1`: traccia di fine turno (hook Stop di Claude Code, solo metadati) e avviso `compaction-advised` in `secondbrain.ps1 -Check`.

### Modificato

- Direttive comuni 1.2: rimando a MEM05, nomi in `.runtime`, proposta di SYS05 alla chiusura del task; il contesto iniziale si carica con `knowledge.ps1 -Startup`, non con `prompts.ps1 -Context`.
- Il tetto di 30.000 caratteri del primo caricamento ha una fonte unica (`Get-SBSlimStartupBudget`).

## [1.1.0] - 2026-11-01

### Modificato

- Direttive comuni 1.1: ogni decisione durevole è una riga «Decisione: … — Motivo: …» in `memory.md` (nessun file ADR separato) e il cambio di versione accettato si registra nel `CHANGELOG.md`.
- `SYS11`: il ritiro predefinito di un prompt non usa `deprecations`, riservate a eliminazione e rinomina.
- Il modello di postazione rimanda a REP02 per la preparazione del README (REP06 è fuso in REP02).

## [1.0.0] - 2026-11-01

### Aggiunto

- Memoria, contesto e task per ogni progetto, con caricamento a strati entro 30.000 caratteri al primo avvio.
- Catalogo di 80 prompt in 13 aree, composti secondo CO-STAR.
- Server MCP in sola lettura per Claude, Codex e Antigravity.
- Controllo di pubblicabilità (REP05) su file, indice e storia.
- Backup e ripristino di ogni file sostituito.
- README e guide in `docs/`, con riferimento tecnico in `docs/riferimento/`.
