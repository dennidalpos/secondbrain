# Architettura e Moduli di SecondBrain

Documentazione tecnica e architetturale di **SecondBrain** basata sull'implementazione reale dei moduli PowerShell 7.5+ (`scripts/SecondBrain.*.psm1`), degli schemi JSON e delle interfacce CLI.

---

## 1. Visione d'Insieme e Modello a Doppio Confine

SecondBrain adotta un modello a **doppio confine** che separa categoricamente il codice distribuibile e le direttive comuni dai dati operativi, dossier privati e cache locali della singola postazione di sviluppo.

Modalità Code-Only: Git traccia solo codice e documentazione (`scripts/`, `config/`, `direttive/`, `docs/`, `README.md`, `LICENSE`, `CHANGELOG.md`, `CREDITS.md`); dossier, archivi e `.runtime/` stanno nel clone locale, protetti da `.gitignore` (il clone può stare anche su una share di rete usata da più PC: vedere [shared-brain.md](shared-brain.md)).

```mermaid
flowchart TB
    subgraph RepoPubblico["Perimetro Tracciato da Git (Code-Only)"]
        direction TB
        SCRIPTS["scripts/<br/>Moduli PowerShell, CLI, Test Runner"]
        DIRETTIVE["direttive/<br/>Direttive Comuni Approvate e Prompt COM01-GOV02"]
        CONFIG["config/<br/>JSON Schemi (tracker, cataloghi, configurazioni)"]
        DOCS["docs/<br/>Documentazione e Contratti Tecnici"]
    end

    subgraph DatiLocali["Perimetro Privato Locale (Escluso da Git)"]
        direction TB
        PARA_P["01-projects/<br/>Brief e Piani di Lavoro Attivi"]
        PARA_A["01-projects/<br/>Dossier repository (context, memory, tracker.json, specs, material, data)"]
        PARA_R["03-resources/<br/>Registro Fonti Normative e Standard"]
        PARA_ARC["04-archives/<br/>Dossier e Storici Ritirati"]
        RUNTIME[".runtime/<br/>Configurazioni Host, Lock, Backup SHA-256, Cache"]
    end

    GITIGNORE[".gitignore<br/>(Confine Deterministico)"]

    RepoPubblico --- GITIGNORE --- DatiLocali
```

---

## 2. Decomposizione dei Moduli PowerShell

Il sistema è strutturato in una libreria di moduli PowerShell (`scripts/SecondBrain.*.psm1`), ciascuno con responsabilità rigorose e contratti verificati da test deterministici:

```mermaid
flowchart TB
    CORE["SecondBrain.Core.psm1<br/>- Crittografia SHA-256 e digest deterministici<br/>- Validazione percorsi confinati e assert<br/>- Serializzazione JSON ordinata e I/O sicuro"]

    ACCESS["SecondBrain.Access.psm1<br/>- Lettura configurazione portabile schema 1<br/>- Lock di scrittura e sessioni sotto .runtime/access<br/>- Registro postazioni e guardia di scrittura"]

    HOST["SecondBrain.Host.psm1<br/>- Identità postazione e configurazione portabile schema 1<br/>- Discovery checkout Git e mappatura IDE locali"]

    PARA["SecondBrain.Para.psm1<br/>- Risoluzione dossier PARA da Git e repository.json<br/>- Validazione integrità para-index.json<br/>- Gestione aree, progetti e archivi"]

    TRACKER["SecondBrain.Tracker.psm1<br/>- Validazione tracker.json su JSON Schema Draft 2020-12<br/>- Risoluzione dipendenze cross-repository<br/>- Rilevamento cicli e calcolo compiti -ReadyOnly"]

    KNOWLEDGE["SecondBrain.Knowledge.psm1<br/>- Composizione avvio snello <= 25.000 caratteri (livelli a richiesta)<br/>- Proiezione task attivi e memoria essenziale<br/>- Compattazione conservativa per hash (SYS05)"]

    PORTABLE["SecondBrain.Portable.psm1<br/>- Discovery e attivazione postazione (SYS03)<br/>- Check deterministico e Sync direttive (SYS04)<br/>- Mappatura configurazioni e profili IDE (SYS01)"]

    PROMPTS["SecondBrain.Prompts.psm1<br/>- Validazione e parsing catalogo (COM01-GOV02)<br/>- Composizione guidata con contesto dossier"]

    PUBLICATION["SecondBrain.Publication.psm1<br/>- Pre-push gate: scansione credenziali e host-path<br/>- Validazione link Markdown e artefatti operativi<br/>- Verifica certificata screenshot reali (DOC03)"]

    MCP["SecondBrain.Mcp.psm1<br/>- Server stdio JSON-RPC in sola lettura, tranne submit_dossier_write<br/>- Esposizione tool per IDE: contesto, task, prompt"]

    SOURCES["SecondBrain.Sources.psm1<br/>- Registro fonti autorevoli e schede di applicabilità<br/>- Check locale; Probe e Collect solo su richiesta esplicita<br/>- Versioni candidate distinte dall'adozione"]

    EXTAUDIT["SecondBrain.ExternalAudit.psm1<br/>- Audit GitHub in sola lettura (scripts/audit-github.ps1)<br/>- Paginazione, copertura e protezione dei contenuti"]

    TRACKERIMP["SecondBrain.TrackerImport.psm1<br/>- Importazione tracker con manifest, anteprima e rollback<br/>- Fonte candidata distinta dalla fonte attiva"]

    CORE --> ACCESS
    CORE --> HOST
    CORE --> PARA
    CORE --> TRACKER
    CORE --> KNOWLEDGE
    CORE --> PORTABLE
    CORE --> PROMPTS
    CORE --> PUBLICATION
    CORE --> MCP
    CORE --> SOURCES
    CORE --> EXTAUDIT
    CORE --> TRACKERIMP

    ACCESS -.-> PARA
    ACCESS -.-> TRACKER
    PARA --> KNOWLEDGE
    TRACKER --> KNOWLEDGE
    TRACKER --> TRACKERIMP
    HOST --> PORTABLE
    PARA --> PROMPTS
```

---

## 3. Sequenza di Risoluzione Contesto e Avvio Agente (Avvio Snello 25.000 Caratteri)

Quando un coding agent opera all'interno di un repository satellite, risolve il contesto storico e i task dal dossier SecondBrain corrispondente tramite `scripts/prompts.ps1 -Context` o `scripts/knowledge.ps1 -Startup`:

```mermaid
sequenceDiagram
    autonumber
    actor Developer as Agente / IDE Satellite
    participant PromptsCLI as scripts/prompts.ps1
    participant ParaMod as SecondBrain.Para.psm1
    participant KnowledgeMod as SecondBrain.Knowledge.psm1
    participant TrackerMod as SecondBrain.Tracker.psm1
    participant HostMod as SecondBrain.Host.psm1

    Developer->>PromptsCLI: -Context -RepositoryPath <checkout>
    PromptsCLI->>HostMod: Risolvi configurazione host (.runtime/hosts/...)
    HostMod-->>PromptsCLI: Configurazione host schema 1
    PromptsCLI->>ParaMod: Risolvi dossier PARA per identità Git
    ParaMod->>ParaMod: Leggi repository.json ed estrai dossier relativo
    ParaMod-->>PromptsCLI: Percorso dossier (es. 01-projects/MioRepo)
    PromptsCLI->>KnowledgeMod: Costruisci avvio dossier
    KnowledgeMod->>TrackerMod: Ottieni task pronti (-ReadyOnly)
    TrackerMod-->>KnowledgeMod: Grafo task filtrato senza blocchi
    KnowledgeMod->>KnowledgeMod: Aggrega index.md + context.md + memory.md + task
    KnowledgeMod->>KnowledgeMod: Verifica rispetto al tetto del primo caricamento (<= 25.000 caratteri)
    alt Budget rispettato
        KnowledgeMod-->>PromptsCLI: Pacchetto di avvio strutturato
    else Budget superato
        KnowledgeMod-->>PromptsCLI: Avviso di saturazione (richiede SYS05 compattazione)
    end
    PromptsCLI-->>Developer: JSON contesto pronto per la sessione
```

---

## 4. Transazioni Atomiche, Lock e Ripristino

Le scritture sono coordinate da `SecondBrain.Access.psm1` (lock) e `SecondBrain.Core.psm1` (`Write-SBFile`, `Remove-SBFile`). Lock e sessioni risiedono in `.runtime/access`; backup e record di staging in `backupRoot` della postazione (`.runtime/hosts/<id>/backups`):

```mermaid
sequenceDiagram
    autonumber
    actor Caller as Script di scrittura
    participant Access as Enter-SBOperation
    participant Lock as .runtime/access (writer.lock, operation.lock)
    participant Core as Write-SBFile
    participant Backup as backupRoot (.stage, .bin, .bin.json)
    participant Storage as File di destinazione

    Caller->>Access: Enter-SBOperation (con o senza SessionId)
    Access->>Lock: Ticket in coda FIFO, poi apertura esclusiva con attesa (predefinita 60 s)
    Access->>Access: Registro postazioni e guardia di scrittura
    alt Lock occupato
        Access-->>Caller: Errore con titolare (utente, computer, sessione)
    end
    Caller->>Core: Write-SBFile(percorso, byte, hash atteso)
    Core->>Backup: Record .stage (writing) e file temporaneo adiacente
    Core->>Storage: Verifica hash atteso e sostituzione atomica
    Core->>Backup: Copia .bin verificata + metadati .bin.json
    alt Scrittura completata
        Core->>Backup: Record .stage (completed)
    else Errore o interruzione
        Core->>Backup: Record .stage (interrupted), temporaneo conservato
    end
    Caller->>Access: Exit-SBOperation (rilascia i lock)
```

Il recupero è esplicito: `scripts/restore-managed.ps1 -MetadataPath <.bin.json>` ripristina un file solo se la destinazione coincide ancora con l'hash distribuito; `scripts/recover.ps1` risolve le transazioni PARA e tracker interrotte (marker `.runtime/para-transaction.json`, anteprima di default, `-Apply` per applicare). I record `.stage` e i backup non vengono eliminati automaticamente.

---

## 5. Ciclo di Vita dei Task nel Grafo Cross-Repository

Ogni repository tracciato dispone di un `tracker.json` (schema `config/tracker.schema.json`, Draft 2020-12) letto da `SecondBrain.Tracker.psm1`. Gli stati ammessi dallo schema sono `todo`, `in_progress`, `blocked`, `done`, `cancelled` e `unknown`; ogni task dichiara anche `execution` (`autonomous`, `user_required`, `unspecified`), priorità, dipendenze e criteri di accettazione. Un task è pronto (`-ReadyOnly`) quando le sue dipendenze sono soddisfatte. Lo schema non impone le transizioni: le regole di chiusura (verifica dei criteri, evidenze con `outcome` in `passed`, `failed`, `partial`, `unverified`) sono nelle direttive e nei workflow.

```mermaid
stateDiagram-v2
    [*] --> todo
    todo --> in_progress: Avvio lavoro
    in_progress --> blocked: Dipendenza o decisione esterna
    blocked --> todo: Blocco risolto
    in_progress --> done: Criteri di accettazione verificati
    todo --> cancelled: Attività ritirata
    blocked --> cancelled: Attività ritirata
    done --> [*]
    cancelled --> [*]
```

`unknown` marca task migrati il cui stato originale non è riconducibile con certezza.

---

## 6. Sincronizzazione Direttive Comuni nei Repository Satellite

Le direttive per coding agent (`AGENTS.md`) sono distribuite tramite `scripts/secondbrain.ps1 -Sync`, garantendo che solo versioni formalmente approvate e firmate con SHA-256 vengano iniettate:

```mermaid
sequenceDiagram
    autonumber
    actor Dev as Sviluppatore / Workflow SYS04
    participant SBCLI as scripts/secondbrain.ps1
    participant PortMod as SecondBrain.Portable.psm1
    participant Approved as direttive/approved.json
    participant Satellite as Checkout Satellite (AGENTS.md)

    Dev->>SBCLI: -Sync
    SBCLI->>PortMod: Esegui sincronizzazione asset gestiti
    PortMod->>Approved: Leggi hash SHA-256 approvati per le direttive
    PortMod->>PortMod: Calcola digest reale di direttive/AGENTS.global_ide.md
    alt Digest non corrispondente
        PortMod-->>SBCLI: Errore: direttive non approvate
    else Digest verificato
        PortMod->>Satellite: Leggi file AGENTS.md esistente
        PortMod->>PortMod: Preserva blocchi personalizzati dell'utente
        PortMod->>Satellite: Inietta blocco delimitato <!-- secondbrain:repository:begin -->
        Satellite-->>PortMod: File aggiornato in sicurezza
        PortMod-->>SBCLI: Riepilogo sync completato
    end
```

---

## 7. Pre-Push Gate e Controllo di Pubblicabilità (SEC07)

Due controlli distinti, entrambi in sola lettura:

- `scripts/check-distribution.ps1` verifica che l'indice Git contenga solo il perimetro pubblico (`scripts/`, `config/`, `direttive/`, `docs/`, `app/` e i file di radice ammessi) e nessun percorso PARA o `.runtime`; exit 1 in presenza di violazioni.
- `scripts/publication.ps1` (`Test-SBPublication`, modulo `SecondBrain.Publication.psm1`) analizza working tree, indice e blob storici:

```mermaid
flowchart LR
    GIT["Working tree / indice Git / blob storici"] --> SCAN["Test-SBPublication"]

    SCAN --> R1{"credential<br/>token, chiavi private"}
    SCAN --> R2{"host-path<br/>percorsi assoluti utente"}
    SCAN --> R3{"operational-artifact<br/>.runtime, backup, bin/obj, .bak/.tmp"}
    SCAN --> R4{"broken-local-link<br/>link Markdown locali"}
    SCAN --> R5{"personal-email<br/>rilievo da rivedere"}

    R1 -->|Errore| BLOCK["ready = false"]
    R2 -->|Errore| BLOCK
    R3 -->|Errore| BLOCK
    R4 -->|Errore| BLOCK
    R5 -->|Da rivedere: allowance motivata o rilievo| BLOCK
    SCAN -->|Nessun rilievo o allowance revisionata| READY["ready = true"]
```

I binari sopra soglia o non testuali richiedono una revisione registrata nella policy tracciata (`config/publication-policy.json`; `publication.ps1 -MigratePolicy -ApplyMigration` copia la vecchia `.runtime/publication/policy.json`); la copertura incompleta è dichiarata e non equivale a esito pulito.

---

## 8. Specifiche di Sicurezza e Invarianti Ingegneristici

1. **Esecuzione disconnessa e deterministica**: nessun comando, modulo o test runner effettua chiamate di rete implicite verso servizi esterni o LLM commerciali.
2. **Nessun demone in background**: SecondBrain non installa né richiede servizi, demoni o agenti in background; ogni azione è attivata esplicitamente da comandi CLI o chiamate JSON-RPC.
3. **Isolamento dei dati personali**: tutte le note private, memorie storiche, configurazioni delle postazioni e cache risiedono sotto `.runtime/` e nelle cartelle PARA locali, categoricamente escluse da Git tramite `.gitignore`.
4. **Preservazione dei file originali**: qualsiasi trasformazione o compattazione conserva gli originali tramite digest SHA-256 in cartelle immutabili, prevenendo ogni perdita di dati accidentale.
