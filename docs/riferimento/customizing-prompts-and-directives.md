# Prompt e direttive: uso, personalizzazione e manutenzione

> Tool portabile: [procedura corrente](portable-brain.md). Nessun monitor; output operativi sotto .runtime e pulizia solo su richiesta.

Guida operativa per usare il catalogo dei prompt (chat e CLI), estenderlo con nuove schede workflow, aggiornare le direttive comuni e allineare le istruzioni negli IDE e nei coding agent. [Indice generato](../../direttive/prompts/README.md), [metadati autorevoli](../../direttive/prompts/catalog.json). Per l'uso dalla chat e dalla CLI vedi la sezione 7; fonti, manutenzione centrale e verifiche sono nelle sezioni 9-11.

---

## Modifica dei prompt

Percorso unico per aggiungere, modificare o ritirare un prompt (da chat: `sb prompt SYS11: …`, che guida le scelte):

1. scheda `direttive/prompts/<CODICE>.md` e voce in `direttive/prompts/catalog.json` (ID `pmt-…` immutabile, codice libero dell'area, `summary` entro 88 caratteri): sezioni 1 e 4 sotto;
2. `pwsh -NoProfile -File scripts/build-prompts.ps1` rigenera `direttive/prompts/README.md` (mai a mano); `-Check` verifica senza scrivere;
3. `pwsh -NoProfile -File scripts/test-secondbrain-workflows.ps1` controlla schede, ID, alias e conteggi.

Un prompt si ritira (con sostituto), non si cancella, salvo richiesta esplicita. Il catalogo è dati del progetto: non tocca i tuoi file fuori dal clone.

## Modifica delle direttive

Le direttive comuni (`direttive/AGENTS.global_ide.md`) e l'integrazione di postazione (`direttive/workstation.template.md`) arrivano agli IDE solo dopo approvazione e distribuzione:

1. proposta in `direttive/proposals/<data>-<nome>/` con i due testi e un `README.md` con gli hash (sezione 3);
2. `scripts/approve-revision.ps1 -Authorization <testo> -ConfigPath <config> -ProposalPath <cartella>` registra l'approvazione e copia i testi in `direttive/` (con backup);
3. `secondbrain.ps1 -Check`, poi `-Sync`: scrive solo il blocco gestito in `AGENTS.md` e nei file IDE, con backup ([cosa viene toccato](safety-backups.md)). Gli IDE manuali si aggiornano incollando il testo di `.runtime/hosts/<id>/istruzioni-globali.md`.

---

## 1. Architettura dei Workflow e Catalogo Prompts

I prompt di SecondBrain sono organizzati in formato modulare con separazione netta tra metadati (`catalog.json`), schede Markdown per area tematica e indice generato (`direttive/prompts/README.md`). Il catalogo conta 80 schede operative (COM01–GOV02, di cui 77 attive e 3 ritirate con sostituto) in 13 aree tematiche; ogni prompt è un workflow atomico delimitato da scopo, prerequisiti, modalità, vincoli e comandi di verifica. Non è imposto un numero fisso di prompt né una numerazione consecutiva.

Il caricamento è selettivo: l'elenco legge solo i metadati; `-Show` e `-Compose` caricano la sola scheda richiesta, evitando sovraccarichi di contesto nel prompt dell'agente. La build valida tutte le schede prima di generare l'indice. Una riga logica dell'elenco è lunga al massimo 88 caratteri; finestre molto strette possono applicare il wrapping dell'IDE.

Un prompt si richiama per ID (`pmt-a709a792`), codice (`COM01`) o alias, con `prompts.ps1 -Show|-Compose -Prompt <chiave>` e dagli strumenti MCP `get_prompt`/`prompts/get`: tutte le chiavi risolvono allo stesso prompt. Un alias ritirato o un prompt deprecato risolve al sostituto con un avviso.

### Struttura di una Scheda Prompt
Ogni scheda deve iniziare con `# CODICE — <Titolo>` (es. `DEV01`, `SYS03`) e contenere esattamente le **7 sezioni canoniche obbligatorie**:

```markdown
# DEV99 — Titolo del workflow

## Scopo
Sintesi dell'obiettivo operativo in 1-2 frasi.

## Quando usarlo
Casi d'uso e condizioni in cui attivare questo specifico workflow.

## Input
File, contesti, repository o argomenti necessari all'agente.

## Attività specifiche
Istruzioni operative passo-passo senza ambiguità. Nessun segnaposto {{...}} non risolto.

## Verifiche
Asserzioni e controlli per validare il completamento del task.

## Consegna
Formato e contenuto dell'output finale atteso dall'agente.

## Prompt vicini
- DEV01: Descrizione breve del workflow correlato.
- DEV02: Descrizione breve del workflow correlato.
```

### Registrazione in `catalog.json`
Ogni prompt deve essere censito in `direttive/prompts/catalog.json`:
- `id`: identificatore opaco e immutabile `pmt-` + 8 esadecimali minuscoli, generato una sola volta (`New-SBWorkflowPromptId`) e mai riusato, anche dopo rimozione. Le relazioni (`related`, `supersededBy`, `deprecations`) usano solo ID.
- `code`: alias primario conforme al pattern per area tematica (es. `COM01`, `DEV01`, `SYS01`); dà il nome alla scheda (`<CODE>.md`) e compare nell'indice.
- `aliases`: array (anche vuoto) di ulteriori codici che risolvono allo stesso prompt, per esempio il vecchio codice dopo una rinomina. ID, codici, alias e alias ritirati condividono un solo spazio di nomi: un duplicato fa fallire la validazione.
- `category`: identificativo di una delle 13 aree tematiche registrate in `categories`.
- `summary`: descrizione sintetica (massimo 82 caratteri; `code + ' | ' + summary` non deve superare 88 caratteri).
- `target`: `repository` (eseguibile nei repository prodotto) o `central` (riservato alla manutenzione di SecondBrain: si compone solo per SecondBrain; SYS03 dispone del bootstrap senza configurazione).
- `mode`: `read`, `write` o `verify`. Le modalità descrivono il workflow e non aumentano i permessi né superano la modalità Plan.
- `file`: nome del file corrispondente (es. `DEV99.md`).
- `references`: array di URL HTTPS ufficiali compatibili.
- `related`: array di ID di prompt vicini; deve contenere almeno un ID esistente e il codice di ciascun prompt vicino deve comparire nel testo della scheda (sezione *Prompt vicini*).
- Sono obbligatori anche `scope`, `requires`, `status` (`active` o `deprecated`) ed `example`; il codice segue `^[A-Z]{2,4}[0-9]{2}$` e la scheda deve iniziare con `# <CODE> — ` e contenere le sezioni *Scopo, Quando usarlo, Input, Attività specifiche, Verifiche, Consegna, Prompt vicini*. Il modo più rapido è copiare una scheda esistente e la sua voce.
- Il catalogo è `catalog.json` schema 1 (catalogo 2), con categorie ordinate, `deprecations` facoltative (alias ritirati verso l'ID sostituto) e i prompt.
- Il validatore controlla schema, unicità di ID, codici e alias in un solo spazio di nomi, categorie, percorsi confinati, sezioni e riferimenti ai prompt vicini (per ID). Titolo, intestazione (scope, modalità, «Cosa serve», esempio) e voci di «Prompt vicini» della scheda devono ripetere i valori del catalogo (`summary`, `scope`, `mode`, `requires`, `example` e `summary` dei prompt correlati): una divergenza o un testo segnaposto fa fallire la build.
- La sezione opzionale «Decisioni da raccogliere» (se presente: unica, non vuota, con rimando a Function Calling o Tool Use) elenca le scelte da sottoporre all'utente; la procedura per aggiungere, modificare o ritirare un prompt è SYS11.
- La risoluzione delle memorie con `-Context` funziona anche se il catalogo dei prompt è assente o non valido. Il resolver confronta indice PARA e metadati reali del dossier; dossier archiviati o ritirati, identità escluse, tracker dichiarati mancanti o invalidi e ambiguità non producono fallback. I riferimenti ad AGENTS, contesto, memoria e fonte tracker sono assoluti. Le istruzioni annidate del repository restano applicabili all'area su cui l'agente lavora.

### Rigenerazione e Validazione con `build-prompts.ps1`
Dopo aver modificato o aggiunto una scheda:

```powershell
# Verifica in sola lettura (exit 0 se allineato, 1 se c'è drift)
pwsh -NoProfile -File scripts/build-prompts.ps1 -Check

# Rigenera direttive/prompts/README.md aggiornando indici e collegamenti
pwsh -NoProfile -File scripts/build-prompts.ps1
```

Metadati in `catalog.json` e singole schede Markdown sono le sorgenti; `README.md` è generato. Il Check operativo (`secondbrain.ps1 -Check`) comprende l'indice e richiede il catalogo con le direttive approvate. `build-prompts.ps1 -Check` restituisce 1 per indice da rigenerare; input invalidi interrompono la generazione prima delle scritture.

---

## 2. Integrazione delle Direttive nei Diversi IDE

SecondBrain supporta un modello ibrido che distingue tra **file di configurazione su disco** e **superfici manuali/account web**.

### VS Code & Continue
- **File di Progetto**: `.vscode/settings.json` e `AGENTS.md` nella radice del checkout.
- **Configurazione Continue**: `~/.continue/config.json`.
- **Procedura di allineamento**:
  1. Includi il blocco gestito di SecondBrain in `AGENTS.md`.
  2. In Continue, aggiungi `AGENTS.md` tra i file di contesto di sistema o usa il slash command di lettura memoria.

### Cursor & Windsurf
- **File di Progetto**: `.cursorrules` / `.windsurfrules` o `AGENTS.md`.
- **Procedura di allineamento**:
  1. `scripts/secondbrain.ps1 -Sync` inietta il router comune in `AGENTS.md`.
  2. Configura le impostazioni di Cursor/Windsurf per indicizzare `AGENTS.md` e il dossier locale associato.

### Claude Code (CLI) & Claude Desktop
- **Claude Code CLI**: legge automaticamente `CLAUDE.md` o `AGENTS.md` nella directory di lavoro corrente.
- **Istruzioni Account / Web**: copia il testo approvato da `direttive/AGENTS.global_ide.md` nelle impostazioni *Custom Instructions* dell'account Anthropic.
- **Verifica**: `scripts/ide-map.ps1 -Verify` non scrive nulla: confronta i file mappati con il testo approvato. Il caricamento nell'account o nella sessione si dimostra solo con una ricevuta di osservazione locale passata con `-ObservationPath`.

### Google Antigravity & Gemini
- **File di Progetto**: `AGENTS.md` e regole `.gemini/antigravity`.
- **Istruzioni Globali**: SecondBrain allinea il blocco gestito nelle regole di workspace. Le slash command (es. `/goal`, `/plan`, `/learn`) interagiscono con i 77 workflow attivi del catalogo (COM01–GOV02).

---

## 3. Ciclo di Approvazione e Distribuzione delle Direttive

Per preservare l'integrità crittografica e prevenire allucinazioni o modifiche non tracciate, le modifiche alle direttive comuni seguono un ciclo formale in 4 fasi:

```mermaid
flowchart LR
    A["1. Proposta Concreta<br/>(direttive/proposals/...)"] --> B["2. Approvazione Esplicita<br/>(approve-revision.ps1)"]
    B --> C["3. Registro Crittografico<br/>(direttive/approved.json)"]
    C --> D["4. Distribuzione Atomica<br/>(secondbrain.ps1 -Sync)"]
```

Le regole comuni attive sono [AGENTS.global_ide.md](../../direttive/AGENTS.global_ide.md) e [workstation.template.md](../../direttive/workstation.template.md); [approved.json](../../direttive/approved.json) registra hash e autorizzazione e la [proposta iniziale](../../direttive/proposals/2026-11-01-v1.0/README.md) contiene il testo approvato. Le proposte approvate restano immutabili: non modificare hash o blocchi generati per eludere il processo. Dopo la distribuzione si esegue anche [SYS01](adapters.md).

Gli AGENTS applicativi distinguono revisione comune applicata e revisione specifica del progetto. Una marcatura allineata non prova il caricamento in sessione né la validità tecnica di tutti i contenuti applicativi: il caricamento va verificato in nuove sessioni, separatamente dall'allineamento dei file.

### 1. Creazione della Proposta
Redigi i file proposti sotto `direttive/proposals/<data>-<nome-proposta>/`:
- `AGENTS.global_ide.md`
- `workstation.template.md`
- `README.md` con motivazione e perimetro

### 2. Approvazione Formale
Registra l'autorizzazione calcolando gli hash crittografici:

```powershell
pwsh -NoProfile -File scripts/approve-revision.ps1 `
    -ConfigPath .runtime/hosts/<id>/workstation.json `
    -ProposalPath direttive/proposals/<data>-<nome> `
    -Authorization "Ricevuta approvazione esplicita utente"
```

Con `-ProposalPath` lo script copia `AGENTS.global_ide.md` e `workstation.template.md` della proposta in `direttive/` (con backup), richiede il `README.md` della proposta e registra in `direttive/approved.json` gli hash SHA-256, l'autorizzazione e l'hash del README. Senza `-ProposalPath` registra gli hash dei testi già presenti in `direttive/`. `-SessionId` riusa una sessione di scrittura aperta con `scripts/access.ps1`.

### 3. Distribuzione con `secondbrain.ps1 -Sync`
Applica la nuova revisione a tutti i checkout gestiti:

```powershell
# Esegui la sincronizzazione
pwsh -NoProfile -File scripts/secondbrain.ps1 -Sync

# Verifica che tutti i repository risultino allineati (exit 0)
pwsh -NoProfile -File scripts/secondbrain.ps1 -Check
```
Le modifiche personali fuori dal blocco gestito e le impostazioni specifiche del singolo repository rimangono integre e intoccate.


---

## 4. Gestione del Catalogo: Rimozione, Deprecazione e Nuove Aree

- **Con l'agente**: il prompt `SYS11` guida aggiunta, modifica, ritiro ed eliminazione con scelte a Function Calling / Tool Use; i passi sotto sono la procedura manuale equivalente. Le schede che chiedono scelte hanno la sezione opzionale «Decisioni da raccogliere» (unica, non vuota, con rimando a Function Calling o Tool Use).
- **Aggiungere una scheda**: genera l'ID con `Import-Module scripts/SecondBrain.Prompts.psm1; New-SBWorkflowPromptId (Read-SBWorkflowCatalog $PWD.Path)` dalla radice di SecondBrain, copia una scheda esistente e registra la voce con `id`, `code` e `aliases: []`.
- **Rinominare un codice**: cambia `code` e `file` (e l'intestazione `# <CODE> — ` della scheda), sposta il vecchio codice in `aliases`. L'ID non cambia, quindi `related`, docs e dossier che citano il vecchio codice continuano a risolvere.
- **Deprecare una scheda**: in `catalog.json` imposta `"status": "deprecated"` e `"supersededBy": "<ID sostituto>"`. La scheda resta nel file ma viene esclusa dagli elenchi; `prompts.ps1` e MCP la risolvono comunque, mostrando un avviso che indica il sostituto.
- **Alias**: gli alias sono dichiarati in `catalog.json` accanto all'ID immutabile di ogni prompt (`pmt-` e 8 esadecimali).
- **Rimuovere una scheda**: elimina la voce da `prompts` e il relativo `<CODE>.md`, togli il suo ID dai `related` delle altre schede e aggiungi in `deprecations` un elemento `{"alias": "<CODE>", "supersededBy": "<ID sostituto>"}` per ogni codice da mantenere risolvibile; poi esegui `build-prompts.ps1`. L'ID rimosso non va riutilizzato.
- **Creare una nuova area**: aggiungi `{ "id": "cloud", "title": "Cloud e infrastruttura" }` a `categories`. Un'area deve contenere almeno un prompt, altrimenti `build-prompts.ps1 -Check` fallisce ("Categoria senza prompt"). Registra quindi la prima scheda con `"category": "cloud"`.
- Dopo ogni modifica: `build-prompts.ps1` (rigenera `direttive/prompts/README.md`) e `build-prompts.ps1 -Check` (exit 0 se allineato).

## 5. Repository su Percorsi e Dischi Arbitrari

SecondBrain non vincola i repository a una cartella: la Discovery accetta radici qualsiasi.

```powershell
# Attivazione guidata (proposta, conferma, anteprima) sulle cartelle o i dischi indicati
pwsh -NoProfile -File scripts/secondbrain.ps1 -Setup -Interactive -Roots "D:\Sviluppo","E:\Clienti","C:\Progetti"

# Oppure in due passi non interattivi: report e selezione per host in .runtime/hosts/<id>/
pwsh -NoProfile -File scripts/secondbrain.ps1 -Setup -Roots "D:\Sviluppo" -Select mio-prodotto -Yes -Apply
```

`config/shared.json` regola il comportamento condiviso:

| Chiave | Effetto |
|---|---|
| `allowedOwners` | Elenco di owner GitHub ammessi, valido per Discovery e dossier (si somma a quello della postazione); `[]` (default) non pone vincoli. |
| `excludedDirectories` | Nomi di cartella ignorati dalla Discovery (`node_modules`, `dist`, `.venv`, …), oltre a quelli di sistema. Una cartella con uno di questi nomi che contiene `.git` (per esempio un checkout chiamato `build` o `dist`) è comunque scoperta; senza `.git` è saltata e riportata in `excluded` con motivo `known-system-or-build-tree`. Le cartelle di sistema o di altri profili non leggibili per permessi sono riportate in `warnings`; un accesso negato in una cartella dell'utente corrente è un problema (`issues`, `kind: access-denied`) e rende la ricognizione incompleta (exit 2). Il file è obbligatorio: se manca la configurazione non si carica. |
| `forbiddenRepositories` | Identità (`github.com/<owner>/<repo>`) mai gestite; si aggiornano con `scripts/rollback-repo.ps1 -Forbid`. |

## 6. Tracker di Progetto

Il tracker autorevole di un prodotto è `02-areas/products/<Prodotto>/tracker.json` (schema 1, validato da `config/tracker.schema.json`) oppure `tracker.md` nel dossier. Per importare un tracker esistente, JSON o Markdown, nel formato standard:

```powershell
# Anteprima (nessuna scrittura)
pwsh -NoProfile -File scripts/import-tracker.ps1 -Repository github.com/<owner>/<repo> -SourcePath <percorso\tracker.json|tracker.md>

# Applicazione con manifest e backup
pwsh -NoProfile -File scripts/import-tracker.ps1 -Repository github.com/<owner>/<repo> -SourcePath <percorso> -Apply
```

Dettagli del contratto in [trackers.md](trackers.md).

## 7. Uso dalla chat e dalla CLI

Con le direttive comuni caricate nella sessione:

```text
sb prompt
sb prompt tutti
sb prompt ambito test
sb prompt mostra TST04
sb prompt TST04: analizza e correggi il fallimento del job Windows
```

La chat è l’interfaccia comune: non è uno slash command nativo né un alias installato nella shell. `sb prompt` mostra il link al file Markdown del catalogo completo e la tabella dei comandi `sb`; `sb prompt tutti` riporta l’elenco compatto integrale (una riga per prompt, mai riassunto). L’agente esegue la CLI centrale e riporta l’output senza riassumerlo. Per applicare il modello carica solo la scheda scelta, risolve il repository corrente e svolge il task nei permessi della conversazione. In modalità Plan prepara il piano senza implementarlo. Se manca un input sostanziale, cerca prima nei file e nella conversazione, poi chiede un chiarimento mirato.

Flusso delle cinque forme (percorso verificato sui set di parametri di `scripts/prompts.ps1`):

```mermaid
flowchart TD
    A["Chat: sb prompt ..."] --> B{"Forma del comando"}
    B -->|"senza argomenti"| C["prompts.ps1 oppure MCP get_prompt_home"]
    B -->|"tutti"| D["prompts.ps1 -List -Compact"]
    B -->|"ambito AREA"| E["prompts.ps1 -List -Category AREA"]
    B -->|"mostra CHIAVE"| F["prompts.ps1 -Show -Prompt CHIAVE"]
    B -->|"CHIAVE: obiettivo"| G["prompts.ps1 -Compose -Prompt CHIAVE -Objective ..."]
    C --> H["Link a direttive/prompts/README.md e tabella dei comandi sb"]
    D --> I["77 righe: codice, modalità, sommario"]
    E --> J["Prompt dell'area con ID, scope e requisiti"]
    F --> K["Scheda uniforme e corpo del prompt"]
    G --> L["Prompt con contesto del repository, eseguito dall'agente nei permessi della sessione"]
```

### CLI centrale

PowerShell 7.5 o successivo, da qualsiasi directory:

```powershell
$brain = $env:SECONDBRAIN_HOME # es. 'C:/Progetti/SecondBrain'
$cfg = "$brain/.runtime/hosts/<id>/workstation.json"
& "$brain/scripts/prompts.ps1"                      # link al catalogo e comandi sb
& "$brain/scripts/prompts.ps1" -List -Compact        # tutti i prompt, una riga ciascuno
& "$brain/scripts/prompts.ps1" -List
& "$brain/scripts/prompts.ps1" -List -Category test   # anche TST o Test
& "$brain/scripts/prompts.ps1" -Show -Prompt TST04
& "$brain/scripts/prompts.ps1" -Context -ConfigPath $cfg
& "$brain/scripts/prompts.ps1" -Compose -Prompt TST04 -Objective 'Correggi il job Windows' -ConfigPath $cfg
& "$brain/scripts/prompts.ps1" -Compose -Prompt SEC01 -RepositoryPath 'C:/Progetti/Repo/src' -ConfigPath $cfg
```

`-List` e `-Show` non richiedono configurazione né repository associato. `-Context` e `-Compose` richiedono `-ConfigPath`; in assenza di selezione esplicita usano Git dalla directory corrente, compresi sottocartelle e worktree. Per identità esplicita usare `-Repository github.com/owner/repo`, eventualmente con `-CheckoutPath`; identità con più checkout richiede selezione. Il checkout deve esistere e avere l’origin dell’identità ammessa, senza deduzioni dal nome della cartella.

Per Progetti usare `-ProjectId`; se ci sono più checkout, `-CheckoutMapPath` contiene un oggetto JSON identità GitHub → percorso checkout. Il compositore include il brief come dato codificato JSON e riferimenti locali, non il contenuto di contesto, memoria o tracker. Non esegue il task e non trasmette dati a servizi AI.

`-OutputPath` crea solo un nuovo TXT. Non sovrascrive file e non segue reparse point. Exit code: 0 successo, 2 errore. `build-prompts.ps1 -Check` restituisce 1 per indice da rigenerare; input invalidi interrompono la generazione prima delle scritture.

Per generare e verificare l'indice e provare una composizione:

```powershell
$cfg = '.runtime/hosts/<id>/workstation.json'
./scripts/build-prompts.ps1 -Check -ConfigPath $cfg
./scripts/build-prompts.ps1 -ConfigPath $cfg
./scripts/prompts.ps1 -Compose -Prompt SEC01 -Objective 'Revisionare le modifiche locali' -ConfigPath $cfg
```

## 8. Interazione Strutturata e Tool Use (Function Calling)

I prompt e il compositore centrale integrano il supporto a **Function Calling / Tool Use** (es. strumento `ask_question`) per gestire dubbi, chiarimenti architetturali e scelte tra opzioni predefinite:
- Quando l'agente deve raccogliere una decisione sostanziale non desumibile dal codice (es. in `COM01`, `COM02`, `PRG01`, `PRG02`, `SYS03`, `SYS04`, `SYS05`, `REP05`), adotta prioritariamente il tool use (`ask_question`) per visualizzare una finestra di selezione a scelta multipla nell'interfaccia utente.
- Viene indicata la scelta raccomandata con prefisso `(Recommended)` e opzioni atomiche e non numerate.
- Si evitano domande a testo libero ripetute o continue richieste di conferma per operazioni già autorizzate nel perimetro del task.

## 9. Fonti e scelte

Consultazione online: 28 ottobre 2026. Le schede del registro comune sono riferimenti con URL e sintesi originali; nessun corpus integrale è stato acquisito. Applicabilità tecnica e revisione di una trascrizione sono distinte.

| Fonte | Uso nel catalogo |
|---|---|
| [OpenAI prompt engineering](https://developers.openai.com/api/docs/guides/prompt-engineering) | Istruzioni esplicite, delimitazione di dati, esempi e valutazioni |
| [OpenAI sviluppo per fasi](https://developers.openai.com/cookbook/examples/codex/iterating-development-workflows-with-codex) | Impatto, pianificazione, esecuzione, verifica e continuità |
| [Claude workflow](https://code.claude.com/docs/en/common-workflows) e [libreria](https://code.claude.com/docs/en/prompt-library) | Orientamento, tracciamento, bug, test e risultati osservabili |
| [GitHub Cookbook](https://docs.github.com/en/copilot/tutorials/copilot-cookbook) | CI, dipendenze, dati, prestazioni, integrazioni e test |
| [GitHub prompt files](https://docs.github.com/en/copilot/tutorials/customization-library/prompt-files) | Schede task separate da istruzioni persistenti; README, API e review |
| [Awesome Copilot](https://github.com/github/awesome-copilot) | Esempi comunitari specialistici; nessuna installazione né adozione delle regole degli esempi |
| [Google strategie](https://ai.google.dev/gemini-api/docs/prompting-strategies) | Struttura coerente e iterazione, senza presumere equivalenza fra modelli |

Schede di registro: `openai-prompt-engineering`, `openai-development-workflows`, `anthropic-code-workflows`, `github-copilot-cookbook`, `github-prompt-files`, `github-awesome-copilot`, `google-prompt-strategies`.

I workflow di repository e di sistema (REP01, REP04 e SYS01–SYS02) incorporano anche convenzioni locali SecondBrain: tracker autorevole, blocchi gestiti, migrazione con recupero, centralità delle memorie e distinzione centrale/prodotto. Queste scelte non vengono attribuite ai fornitori. Nessuna raccomandazione specifica di framework, modello o browser è resa universale.

## 10. Manutenzione centrale e prodotti

SecondBrain mantiene direttive, prompt, blocchi AGENTS gestiti e riferimenti. I task prodotto restano ai rispettivi agenti, anche se registrati qui come autonomous. REP01 seleziona solo attività del repository aperto; REP02-MEM01 coprono documentazione, memoria, pulizia e tracker; MEM02 l'importazione nel dossier; SYS01-SYS02 richiedono SecondBrain come repository operativo.

L'agente del prodotto confronta codice e stato Git con dossier corrente, fonte tracker e schede di applicabilità. Consultare un riferimento non autorizza automaticamente esecuzione o modifica delle prescrizioni comuni.

## 11. Verifiche e limiti

`scripts/test-secondbrain-workflows.ps1` verifica catalogo, caricamento selettivo, CLI, risoluzione Git/PARA, output e composizione in fixture isolate sotto SecondBrain/.runtime/tests. Sei fixture per esplorazione, CI, dipendenze, migrazione dati, accessibilità e handoff verificano tramite la CLI selezione della scheda, modalità, preservazione della richiesta e caricamento selettivo. Non sono valutazioni dell’efficacia di un LLM.

La suite principale include queste prove. Generazione: `scripts/build-prompts.ps1 -ConfigPath <config>`; verifica senza scritture con `-Check`. Il Check operativo comprende l indice e richiede il catalogo con le direttive approvate. Dopo attivazione sono necessari nuovi avvii per provare il caricamento delle direttive; file allineati e fixture superate non ne costituiscono prova.
