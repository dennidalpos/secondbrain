# Registro delle modifiche

Formato [Keep a Changelog](https://keepachangelog.com/it-IT/1.1.0/). La numerazione segue il file `VERSION`. Questo registro cambia solo quando accetti un cambio di versione: vedi [Cambiare versione](docs/uso-quotidiano.md).

> Versione corrente: **1.22.2**, numerazione reimpostata il 2026-11-04 con le funzionalità attuali conservate. Le sezioni seguenti mantengono la cronologia dei rilasci precedenti.

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

- un-ready-tasks.ps1: l agente del runner può usare anche Grep, Glob e Skill (--allowedTools), strumenti di sola lettura o consultazione; i divieti su commit, push, tag, reset, clean e rimozioni restano invariati. Documentato in operations.

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
