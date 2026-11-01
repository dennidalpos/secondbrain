# Alberatura di SecondBrain

> Tool portabile: [procedura corrente](portable-brain.md). Nessun monitor; output operativi sotto `.runtime` e pulizia solo su richiesta.

Mappa di ogni cartella del clone, di chi la scrive e di cosa si può cancellare a mano. Nessun percorso della postazione compare qui: `<id>` è l'identificativo dell'host (`ws-` più 16 cifre esadecimali) e `<repo>` il nome di un dossier prodotto.

**Legenda «Cancellabile»**

| Valore | Significato |
| --- | --- |
| **Sì** | Si rigenera con un comando indicato o non ha riferimenti: si può rimuovere senza conseguenze. |
| **Con cautela** | Contiene prove, copie di recupero o stato referenziato: rimuovere solo dopo aver verificato i riferimenti e, per i backup, con `scripts/cleanup.ps1` e un manifest. |
| **No** | È codice, contratto, dossier o stato attivo: la rimozione rompe la postazione o fa perdere conoscenza. |

Regola generale: nulla viene cancellato dagli strumenti. Backup, build, cache, fixture e catture restano finché qualcuno non le toglie con richiesta, perimetro e verifica (vedi [recupero](recovery.md)).

## Radice del clone

| Percorso | Contenuto | Versionato | Cancellabile |
| --- | --- | --- | --- |
| `AGENTS.md` | Istruzioni del repository: blocco gestito (generato da `-Sync`, non modificare a mano) e regole specifiche. | Sì | No |
| `README.md`, `CREDITS.md`, `LICENSE` | Presentazione pubblica, crediti e licenza. | Sì | No |
| `PARA.md` | Indice PARA generato da `para.ps1`; ignorato da Git. | No | Sì (si rigenera con `para.ps1`) |
| `para-index.json` | Indice PARA leggibile da macchina (identificativi → percorsi); ignorato da Git. | No | Sì (si rigenera con `para.ps1`) |
| `scripts/` | Moduli `SecondBrain.*.psm1`, comandi `*.ps1`, test `test-secondbrain*.ps1`, fixture dei prompt, sorgenti e lock Python per le fonti. | Sì | No |
| `config/` | Schemi JSON (tracker, catalogo prompt, fonti, applicabilità), `shared.json` (policy condivisa) ed esempio di configurazione postazione. | Sì | No |
| `config/local/` | Segnaposto locale facoltativo che inoltra alla configurazione sotto `.runtime/hosts/<id>/`; ignorato da Git. | No | Con cautela |
| `direttive/` | Testo comune approvato (`AGENTS.global_ide.md`, `workstation.template.md`), template del repository, `approved.json` con hash e autorizzazione. | Sì | No |
| `direttive/proposals/` | Proposta concreta di ogni revisione: testo e motivazioni. | Sì | Con cautela |
| `direttive/prompts/` | 80 schede del catalogo (COM01–GOV02) più metadati; l'indice si genera con `build-prompts.ps1`. | Sì | No |
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
| `access/` | `access.ps1`, `Enter-SBOperation` | Sessioni, `writer.lock`, `operation.lock`, registro `workstations.json`. | **No** con sessioni attive; lock e sessioni orfane si trattano con `access.ps1 -Reconcile` o `recover.ps1`, non a mano |
| `para-transaction.json` | `Invoke-SBParaTransaction` | Marker di una transazione in corso (assente a riposo). | **No**: se presente, recuperare con `recover.ps1` |
| `backups/transactions/` | Transazioni PARA e tracker | Manifest e originali di ogni scrittura transazionale (recuperabili con `recover.ps1`). | Con cautela (retention con `cleanup.ps1` e manifest) |
| `backups/tracker/`, `backups/tracker-*`, `backups/publication/` | Aggiornamenti del tracker, rapporti REP05 | Copie dei tracker prima di una modifica e dei rapporti di pubblicazione. | Con cautela |
| `backup/mcp-pairing/` | Configurazione MCP degli IDE | Copie dei file di configurazione IDE prima della modifica. | Con cautela (recupero) |
| `publication/` | `publication.ps1` | `policy.json` (allowances e `binaryReviews` degli asset), `baseline.json` (incrementale REP05), rapporti e copie `.bak-*`. | `policy.json` e `baseline.json`: **No**; rapporti e `.bak-*` vecchi: Sì |
| `captures/` | `assets.ps1`, script di cattura | Originali degli screenshot (stdout reale, fixture, manifest di revisione). Le copie pubbliche stanno in `docs/assets`. | Con cautela: perdi la provenienza; non si rigenerano identiche |
| `mcp-handshake/` | `test-secondbrain-mcp-handshake.ps1` | Rapporti dell'handshake MCP con gli IDE. | Sì |
| `tests/` | Suite `test-secondbrain*.ps1` | Fixture conservate di ogni esecuzione (portable, workflows, tracker, sorgenti…). | **Sì**, tutte: le suite le ricreano. Tenere le ultime se serve ripetere un fallimento |
| `cleanup/` | Pulizie richieste | Registro delle rimozioni eseguite (percorso, file, byte). | Con cautela (è la prova di cosa è stato tolto) |
| `perf/`, `operations/`, `candidates/`, `portable-implementation/`, file sciolti | Lavoro di agent e misure | Cartelle di lavoro temporanee degli agent: copie `source/`, build, `node_modules`, log, evidenze, bundle Git. Nessuno script le legge. | Sì, con una verifica: riferimenti nei dossier, collegamenti (junction) verso repository reali, bundle Git usati come punti di ripristino |

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
