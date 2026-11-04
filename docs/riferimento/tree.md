# Alberatura di SecondBrain

> Tool portabile: [procedura corrente](portable-brain.md). Nessun monitor; output operativi sotto `.runtime` e pulizia solo su richiesta.

Mappa di ogni cartella del clone, di chi la scrive e di cosa si può cancellare a mano. Nessun percorso della postazione compare qui: `<id>` è l'identificativo dell'host (`ws-` più 16 cifre esadecimali) e `<repo>` il nome di un dossier prodotto.

**Legenda «Cancellabile»**

| Valore | Significato |
| --- | --- |
| **Sì** | Si rigenera con un comando indicato o non ha riferimenti: si può rimuovere senza conseguenze. |
| **Con cautela** | Contiene prove, copie di recupero o stato referenziato: rimuovere solo dopo aver verificato i riferimenti e, per i backup, con `scripts/cleanup.ps1` e un manifest. |
| **No** | È codice, contratto, dossier o stato attivo: la rimozione rompe la postazione o fa perdere conoscenza. |

Regola generale: nulla viene cancellato dagli strumenti, salvo la fixture di `test-secondbrain.ps1` a esito verde. Backup, build, cache, altre fixture e catture restano finché qualcuno non le toglie con richiesta, perimetro e verifica (vedi [recupero](recovery.md)).

## Radice del clone

| Percorso | Contenuto | Versionato | Cancellabile |
| --- | --- | --- | --- |
| `AGENTS.md` | Istruzioni del repository: blocco gestito (generato da `-Sync`, non modificare a mano) e regole specifiche. | Sì | No |
| `README.md`, `CHANGELOG.md`, `CREDITS.md`, `LICENSE` | Presentazione pubblica, registro delle versioni, crediti e licenza. | Sì | No |
| `PARA.md` | Indice PARA generato da `para.ps1`; ignorato da Git. | No | Sì (si rigenera con `para.ps1`) |
| `para-index.json` | Indice PARA leggibile da macchina (identificativi → percorsi); ignorato da Git. | No | Sì (si rigenera con `para.ps1`) |
| `scripts/` | Moduli `SecondBrain.*.psm1`, comandi `*.ps1`, test `test-secondbrain*.ps1`, fixture dei prompt, sorgenti e lock Python per le fonti. | Sì | No |
| `config/` | Schemi JSON (tracker, catalogo prompt, fonti, applicabilità), `shared.json` (policy condivisa) ed esempio di configurazione postazione. | Sì | No |
| `config/local/` | Segnaposto locale facoltativo che inoltra alla configurazione sotto `.runtime/hosts/<id>/`; ignorato da Git. | No | Con cautela |
| `direttive/` | Testo comune approvato (`AGENTS.global_ide.md`, `workstation.template.md`), [`AGENTS.repo.template.md`](../../direttive/AGENTS.repo.template.md) (modello da compilare a mano per le istruzioni specifiche di un prodotto; il blocco gestito `secondbrain:repository` è generato da `New-SBPortableRepositoryBody` in `SecondBrain.Portable.psm1`, non dal modello), `approved.json` con hash e autorizzazione. | Sì | No |
| `direttive/proposals/` | Proposta concreta di ogni revisione: testo e motivazioni. | Sì | Con cautela |
| `direttive/prompts/` | 81 schede del catalogo (65 core e 16 di manutenzione), con le traduzioni in `it/` e `en/`, più metadati; gli indici (uno per lingua e pacchetto) si generano con `build-prompts.ps1`. | Sì | No |
| `.github/ISSUE_TEMPLATE/` | Form delle issue (`bug.yml`, `feature.yml`, `config.yml`) usati da REP11; ammessi dal controllo di distribuzione. | Sì | No |
| `docs/` | Guide, architettura, procedure e questo file. | Sì | No |
| `docs/assets/` | Screenshot pubblici (copie ripulite dai metadati) e archivio tracker di esempio. Gli originali stanno in `.runtime/captures`. | Sì | Con cautela (sono linkati da README e guide) |

## Conoscenza PARA (locale, ignorata da Git)

Solo la struttura con i `.gitkeep` e i README sono versionati; il contenuto resta nel clone privato.

| Percorso | Contenuto | Cancellabile |
| --- | --- | --- |
| `01-projects/` | Progetti attivi (vuota finché non ne crei). | No |
| `02-areas/products/<repo>/` | Un dossier per ogni repository gestito sulla postazione. | **No** |
| `03-resources/` | Risorse trasversali: `authoritative-sources` (registro delle fonti: schede, profili, censimento), `architecture`, `technology-radar`, `troubleshooting`. | No |
| `04-archives/` | Progetti, aree e risorse archiviati. Non si riattivano implicitamente. | Con cautela |

### Dossier di un repository (`02-areas/products/<repo>/`)

| File | Contenuto |
| --- | --- |
| `brief.md`, `para.json` | Perimetro e metadati PARA (identificativo immutabile `area-…`). |
| `repository.json` | Identità del repository (`github.com/…` o `local:…`), alias e dichiarazione del tracker (`location=dossier`, `path=tracker.json`, `schemaVersion=1`). |
| `context.md` | Stato corrente, vincoli, problemi aperti e prossimo passo, in sintesi. |
| `memory.md` | Decisioni durevoli e gotcha, in sintesi. |
| `memory.agent.md` | Vista derivata di `memory.md` per gli agenti (generata da Sync, non modificare). |
| `tracker.json` | Tracker autorevole dei task (schema v1): stato, priorità, dipendenze, criteri di accettazione, evidenze. |
| `index.md`, `history/index.md` | Indici generati da `-Sync`: non modificare a mano. |
| `authoritative-sources.json` | Applicabilità del registro fonti al prodotto (se presente). |
| `history/` | Rapporti dei lotti, prove, snapshot e `compaction/<hash>/` con gli originali di contesto e memoria prima di ogni compattazione. |

Tutto il dossier è conoscenza non rigenerabile: **non cancellare**. La dimensione si contiene con la compattazione conservativa (SYS05), che archivia gli originali per hash e non perde informazioni.

## Runtime locale: `.runtime/` (ignorato da Git)

Per la routine di pulizia, le categorie e la proposta di pulizia vedi [manutenzione di .runtime](runtime-maintenance.md).

Tutti gli output operativi gestiti stanno qui, isolati per host. Il clone può stare su una share: `.runtime/hosts/<id>/` resta per host. Nulla sotto `.runtime` entra in un repository prodotto o nell'indice Git.

| Percorso | Chi lo scrive | Cosa contiene | Cancellabile |
| --- | --- | --- | --- |
| `hosts/<id>/workstation.json` | `-Setup` / `-Activate` | Configurazione attiva dell'host: binding repository, integrazioni IDE, ricevuta di selezione, stato degli output. | **No** |
| `hosts/<id>/inventory.json`, `ide-map.json`, `state.json`, `istruzioni-globali.md` | `-Setup`, `-Sync`, `ide-map.ps1` | Inventario, mappa IDE con osservazioni, hash dei blocchi gestiti, copia del testo globale distribuito. | **No** (`istruzioni-globali.md` si rigenera con `-Sync`) |
| `hosts/<id>/discovery.json`, `selection.json`, `unbind-*.json` | `-Discover`, `-Setup` | Rapporto di ricognizione e selezioni (proposta/confermata). | Sì dopo l'attivazione (si rigenerano con `-Setup`); tenere l'ultima selezione se serve la ricevuta |
| `hosts/<id>/backups/` | `Write-SBFile` | Originali dei file gestiti prima di ogni scrittura e record `.stage` delle transazioni. | Con cautela: `cleanup.ps1 -ListStageRecords` mostra i `.stage` oltre 90 giorni |
| `hosts/<id>/migrations/` | `import-tracker.ps1` | Sorgenti preservati delle importazioni. | Con cautela |
| `hosts/<id>/sources/` | `sources.ps1` | `python/` (ambiente dedicato per convertire le fonti), `reports/`, `latest.json`. | Sì: `python/` si ricrea dal lock; i rapporti hanno retention 90 giorni. Dopo la rimozione `sources.ps1 -Check` segnala rapporti assenti |
| `access/` | `access.ps1`, `Enter-SBOperation`, `SecondBrain.Pending.psm1` | Sessioni, lock, registro postazioni, `pending-writes/` e `pending-receipts/`. | **No** con sessioni attive o richieste pendenti; originali e ricevute si conservano, recupero con gli strumenti dedicati |
| `para-transaction.json` | `Invoke-SBParaTransaction` | Marker di una transazione in corso (assente a riposo). | **No**: se presente, recuperare con `recover.ps1` |
| `backups/transactions/` | Transazioni PARA e tracker | Manifest e originali di ogni scrittura transazionale (recuperabili con `recover.ps1`). | Con cautela (retention con `cleanup.ps1` e manifest) |
| `backups/tracker/`, `backups/tracker-*`, `backups/publication/` | Aggiornamenti del tracker, rapporti SEC07 | Copie dei tracker prima di una modifica e dei rapporti di pubblicazione. | Con cautela |
| `backup/mcp-pairing/` | Configurazione MCP degli IDE | Copie dei file di configurazione IDE prima della modifica. | Con cautela (recupero) |
| `publication/` | `publication.ps1` | `policy.json` (allowances e `binaryReviews` degli asset), `baseline.json` (incrementale SEC07), rapporti e copie `.bak-*`. | `policy.json` e `baseline.json`: **No**; rapporti e `.bak-*` vecchi: Sì |
| `captures/` | `assets.ps1`, script di cattura | Originali degli screenshot (stdout reale, fixture, manifest di revisione). Le copie pubbliche stanno in `docs/assets`. | Con cautela: perdi la provenienza; non si rigenerano identiche |
| `mcp-handshake/` | `test-secondbrain-mcp-handshake.ps1` | Rapporti dell'handshake MCP con gli IDE. | Sì |
| `tests/` | Suite `test-secondbrain*.ps1` | Una directory `run-<id>` per esecuzione, sempre conservata con `run.json`, log e fixture; runner figli in directory sorelle collegate nei rapporti. `esito.json` collega l'ultimo rapporto; `esito-concurrency.json` resta nel run o nella fixture autonoma. | **Con cautela**: le fixture si ricreano, le prove storiche no. Pulizia soltanto su richiesta esplicita, verificando riferimenti e recuperabilità |
| `cleanup/` | Pulizie richieste | Registro delle rimozioni eseguite (percorso, file, byte). | Con cautela (è la prova di cosa è stato tolto) |
| `hosts/<id>/repos/<repo>/<categoria>/<yyyyMMdd>-<slug>` e `hosts/<id>/repos/<repo>/temp/` | `work.ps1 -Category -Slug`, `Get-SBRuntimeWorkPath` | Layout annidato del lavoro degli agent per repository (`work`, `evidence`, `report`, `fixture`, `tmp`); `temp/` è l'area TEMP/TMP del repository. | Sì per `work`, `fixture`, `tmp` e `temp` dopo verifica; `evidence` e `report` con cautela. `cleanup.ps1 -RuntimeReport` li elenca |
| `operations/`, `q201/`, `t<numero>/`, `lotto-*`, `classify-*`, `compaction*/`, `work-<data>-<slug>`, `hosts/<id>/repositories/…`, file sciolti | Lavoro di agent e misure (legacy) | Cartelle di lavoro temporanee degli agent precedenti al layout annidato: copie `source/`, build, `node_modules`, log, evidenze, bundle Git. Nessuno script le legge. `cleanup.ps1 -RuntimeReport` le segnala come legacy con la destinazione proposta, senza spostarle. | Sì, con una verifica: riferimenti nei dossier, collegamenti (junction) e proprietà; `cleanup.ps1 -RuntimeReport` ne mostra dimensione ed età |
| `trace/<id>/<data>.jsonl` | `trace.ps1 -Event stop` (hook Stop) | Una riga di soli metadati per turno (ora, sessione, repository): serve a contare i turni dall'ultima compattazione. Nessun testo di prompt. | Con cautela: è una prova d'uso; si ruota per file, mai in automatico |
| `INDEX.md` | `cleanup.ps1 -RuntimeReport -ReportPath` | Vista derivata dell'intero `.runtime`. | **Sì** (si rigenera) |

### Prima di cancellare a mano

1. Controlla che nessuna sessione sia attiva (`access.ps1 -Status`) e che non esista `.runtime/para-transaction.json`.
2. Cerca collegamenti: `Get-ChildItem <cartella> -Recurse -Force -Attributes ReparsePoint`. Le junction vanno rimosse con `cmd /c rmdir <link>` prima di svuotare la cartella: così si elimina il collegamento e non il repository a cui punta.
3. Per percorsi oltre 260 caratteri (`node_modules`, build annidate) `Remove-Item` può fallire: svuota con `robocopy <cartella-vuota> <cartella> /MIR` e poi rimuovi la cartella.
4. Per backup e `.stage` usa `scripts/cleanup.ps1` con un manifest revisionato, che conserva hash e recuperabilità. `cleanup.ps1 -ListRuntime` mostra in sola lettura età, dimensione, riferimenti e protezione di ogni voce di `.runtime`.
5. Dopo una rimozione esegui `secondbrain.ps1 -Check`: deve restare lo stato noto della postazione (output da qualificare, superfici IDE manuali).

## Cosa NON è in questo clone

- I checkout dei prodotti: sono repository separati; SecondBrain ne conserva solo il dossier e il blocco gestito nel loro `AGENTS.md`.
- Credenziali e archivi di autenticazione: non vengono acquisiti.
- Task applicativi: la manutenzione centrale non esegue build o test dei prodotti.

## PARA: gestione dei Progetti

### Organizzazione

| Ambito | Percorso | Contenuto |
|---|---|---|
| Progetti | `01-projects/` | Iniziative finite, con obiettivo e criteri di completamento |
| Aree | `02-areas/products/` | Responsabilità continuative, dossier dei prodotti |
| Risorse | `03-resources/` | Riferimenti riutilizzabili |
| Archivi | `04-archives/{projects,areas,resources}/` | Entità inattive, spostate esplicitamente |

Ogni entità ha `para.json` schema 1, id stabile e `brief.md`. Stati dei Progetti: `active/completed/cancelled`; Aree e Risorse: `active/retired`. L'archiviazione è una posizione, non un nuovo id. Risolvere il percorso corrente da `para-index.json` e verificarlo sui metadati; `PARA.md` è la vista navigabile. Entrambi sono generati nella radice del clone e non sono versionati.

Le Aree conservano `repository.json`, contesto, memoria, eventuale tracker e snapshot. I Progetti collegano Aree per id e tracker per `area`/`path`; `repository: true` indica un eventuale tracker nel checkout. Le attività restano nel tracker esistente.

### Gestire un Progetto

```powershell
$cfg = '.runtime/hosts/<id>/workstation.json'
./scripts/para.ps1 -Check -ConfigPath $cfg
./scripts/para.ps1 -BuildIndex -ConfigPath $cfg
# Sostituire l'id Area con uno presente nell'indice:
./scripts/para.ps1 -NewProject -Id rilascio-prodotto -Title 'Rilascio prodotto' `
  -Areas @('area-identificatore-del-prodotto') -Objective 'Consegnare la release' `
  -Acceptance @('Test pertinenti superati', 'Artefatto verificato') -ConfigPath $cfg
```

### Comporre un prompt

```powershell
./scripts/prompts.ps1 -Compose -Prompt SEC01 -Objective 'Revisionare le modifiche locali' `
  -ProjectId adozione-para -ConfigPath $cfg
./scripts/prompts.ps1 -Compose -Prompt DEV02 -Objective 'Correggere il difetto descritto' `
  -Repository github.com/example-user/my-workspace -ConfigPath $cfg
```

`-ProjectId` e `-Repository` sono alternativi. Il compositore include brief del Progetto e percorsi verificati; non incorpora il contenuto dei dossier. Per checkout ambigui usare `-CheckoutPath` oppure `-CheckoutMapPath` (JSON identità GitHub → checkout presente nell'inventario locale). `-OutputPath` crea solo un nuovo `.txt`, senza sovrascrivere. Nessun task o servizio AI viene avviato.

### Creare una Risorsa e cambiare stato

```powershell
./scripts/para.ps1 -NewResource -Id guida-api -Title 'Guida API' -Objective 'Raccolta di riferimento' -ConfigPath $cfg
./scripts/para.ps1 -SetStatus -EntityId guida-api -Status retired -ConfigPath $cfg
```

`-NewResource` crea `03-resources/<id>/` con `para.json` e `brief.md`. `-SetStatus` cambia solo `status` in `para.json` dentro una transazione con backup: Progetto `active|completed|cancelled`, Area e Risorsa `active|retired`; un'entità archiviata va prima ripristinata. Solo ciò che è `completed`, `cancelled` o `retired` diventa candidato all'archiviazione. Le stesse regole sono nel prompt `MEM05` (`sb prompt MEM05`).

### Archiviare e riattivare

`para.ps1 -SuggestArchive -ConfigPath $cfg` propone entità in stato concluso/ritirato. Non sposta dati. Per un'Area verifica anche l'assenza di Progetti attivi collegati; l'assenza di checkout non prova il ritiro.

Solo su richiesta esplicita:

```powershell
./scripts/para.ps1 -Archive -EntityId rilascio-prodotto -ConfigPath $cfg `
  -BackupRoot 'C:/SecondBrainBackup/para'
./scripts/para.ps1 -Restore -EntityId rilascio-prodotto -ConfigPath $cfg `
  -BackupRoot 'C:/SecondBrainBackup/para'
```

Restore riporta lo stato ad `active`: un'Area torna con il suo identificatore, non con il nome di cartella di origine. Gli spostamenti aggiornano i riferimenti gestiti e conservano gli snapshot byte per byte; eseguire poi Sync per aggiornare anche i blocchi dei checkout. Una Sync non riscrive i dossier archiviati. Manifest e recupero sono descritti nella [guida dedicata](recovery.md).

I manifest tracker registrati sono aggiornati nella stessa transazione, con identita e hash dei payload preservati. Sono ammessi gli stati `completed` e `rolled_back`; una importazione tracker pendente impedisce lo spostamento prima di qualsiasi scrittura. Anche il recupero transazionale comprende i manifest nei backupRoot delle postazioni registrate, dopo la validazione dei percorsi. Dettagli nella [guida tracker](trackers.md#spostamenti-para).

Fonti: [modello PARA](https://fortelabs.com/blog/para/), [CLI](../../scripts/para.ps1), [metadati e transazioni](../../scripts/SecondBrain.Para.psm1), [compositore](../../scripts/prompts.ps1). Per schede e numerazione vedere [catalogo e direttive](customizing-prompts-and-directives.md#3-ciclo-di-approvazione-e-distribuzione-delle-direttive).
