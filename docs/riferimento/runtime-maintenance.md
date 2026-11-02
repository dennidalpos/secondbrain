# Manutenzione di `.runtime` e contesto iniziale

`.runtime/` contiene tutto ciò che SecondBrain produce sul tuo PC: configurazione della postazione, backup, fixture dei test, rapporti. È escluso da Git e cresce nel tempo: nel clone del maintainer ha raggiunto circa 2,8 GB. Nulla viene cancellato in automatico; la pulizia è sempre una tua richiesta esplicita. Prima di toccare qualcosa leggi anche [sicurezza e backup](safety-backups.md) e la [mappa completa](tree.md).

## Cosa contiene, per categoria

`cleanup.ps1 -ListRuntime` classifica ogni voce di primo livello:

| Categoria | Cartelle tipiche | Si può cancellare? | Come si recupera |
|---|---|---|---|
| `protected` | `hosts/<id>/` (configurazione, `state.json`, `inventory.json`), `access/` (sessioni e lock), `backups/` della postazione corrente | **No** | Non si rigenera: è la configurazione e la prova di cosa è gestito |
| `regenerable` | `tests/` (fixture delle suite), `mcp-handshake/`, `hosts/<id>/sources/python` | Sì | `tests/`: rieseguendo le suite `test-secondbrain*.ps1`; handshake: rieseguendo il test; `sources/python`: lo ricrea `sources.ps1` |
| `evidence` | `cleanup/` (registro delle pulizie), `captures/` (originali degli screenshot), `publication/` (policy e baseline REP05), `directives-activation/` | Con cautela | Non si rigenerano identiche: servono come prova o provenienza |
| `backup` | `backups/` e `workstations/<id di origine>/` (host precedenti), `backup/mcp-pairing/` | Con cautela, solo con manifest | Sono i recuperi dei file che SecondBrain ha sostituito |
| `working` | `perf/`, `operations/`, `candidates/`, cartelle di lavoro degli agent | Dopo verifica | Lavoro temporaneo: controlla riferimenti e proprietà |

Dentro `hosts/<id>/`: `workstation.json`, `state.json`, `inventory.json`, `ide-map.json`, `istruzioni-globali.md` non si cancellano; `backups/` contiene gli originali (`<guid>.bin` e `.bin.json`) e i record `.stage`; `sources/` contiene l'ambiente Python (rigenerabile) e i rapporti.

Cause tipiche di crescita: le suite conservano la fixture di ogni esecuzione (`tests/`, anche decine di migliaia di file), ogni scrittura gestita aggiunge un backup, gli zip di `backup.ps1` pesano centinaia di MB.

## Routine di manutenzione (una volta al mese)

```powershell
# 1. Rapporto per categoria, in sola lettura (dimensione, età, riferimenti, come si recupera)
pwsh -NoProfile -File scripts/cleanup.ps1 -ListRuntime

# 2. Proposta di pulizia, in sola lettura: nessuna cartella viene rimossa
pwsh -NoProfile -File scripts/cleanup.ps1 -ProposeRuntime -KeepFixtures 5
pwsh -NoProfile -File scripts/cleanup.ps1 -ProposeRuntime -ProposalPath .runtime/cleanup/proposals/2026-11.json   # salva la proposta in un nuovo file

# 3. Backup .stage oltre 90 giorni (elenco), da rimuovere solo con un manifest revisionato
pwsh -NoProfile -File scripts/cleanup.ps1 -ListStageRecords -OlderThanDays 90
```

La proposta indica cartelle candidate (fixture di test oltre le ultime `-KeepFixtures`, rapporti handshake oltre soglia, ambiente Python delle fonti, zip di backup oltre i due più recenti, backup `.bin` duplicati di Git (file ora tracciato e pulito, copia con SHA-256 pari a `previousHash` e contenuto presente come blob: senza blob il `.bin` è l'unica copia e non è candidato), lavoro di agent senza riferimenti), con dimensione, età, riferimenti e come si ricreano. **Non è un manifest eseguibile.** Rimuovere le cartelle è un passo separato:

1. Chiudi le sessioni di scrittura (`access.ps1 -Status`) e verifica che non esista `.runtime/para-transaction.json`.
2. **Cartelle rigenerabili** (fixture di test oltre le ultime `-KeepFixtures` e `hosts/<id>/sources/python`): usa `cleanup.ps1 -Regenerable`.
   ```powershell
   # Anteprima (nessuna rimozione): target, saltati con il motivo, file e byte
   pwsh -NoProfile -File scripts/cleanup.ps1 -Regenerable -KeepFixtures 5
   # Applicazione, solo dopo una tua richiesta esplicita (da citare in -Authorization)
   pwsh -NoProfile -File scripts/cleanup.ps1 -Regenerable -KeepFixtures 5 -Apply -Authorization "richiesta utente del <data>: pulizia rigenerabili"
   ```
   Il perimetro è fisso. Si salta ciò che è stato scritto negli ultimi `-MinAgeMinutes` (predefinito 10), che contiene percorsi della configurazione o che è un reparse point; si rifiuta con transazione pendente o sessioni di accesso attive. Junction e symlink si scollegano senza seguirli e i file di sola lettura (oggetti Git) sono gestiti. Non c'è backup, perché tutto si ricrea (suite `test-secondbrain*.ps1`, `sources.ps1`); resta un registro `.runtime/cleanup/regenerable-<data>.json` con autorizzazione, elementi rimossi, dimensioni e come ricrearli. Esce con 1 se una cartella non si rimuove (esito `partial`).
3. Per file con backup e hash (`.stage`, backup, rapporti) usa `cleanup.ps1 -ManifestPath` con un manifest revisionato e `-Authorization`.
4. Per altre cartelle (rapporti handshake, lavoro di agent, zip) controlla i collegamenti (`Get-ChildItem <cartella> -Recurse -Force -Attributes ReparsePoint`; una junction si toglie con `cmd /c rmdir <link>`); per percorsi oltre 260 caratteri svuota con `robocopy <cartella-vuota> <cartella> /MIR`.
5. Dopo la pulizia esegui `secondbrain.ps1 -Check`: deve restare lo stato noto della postazione.

## Contesto iniziale: cosa viene caricato e come ridurlo

Dopo `sb prompt` l'agente carica il pacchetto di avvio del dossier. Il profilo predefinito è **snello** (tetto 20.000 caratteri, **solo per il primo caricamento**): indice, sezioni essenziali di `context.md` e `memory.md`, task pronti in una riga ciascuno e un elenco dei livelli non caricati. Il resto non è eliminato e si richiede quando serve: dopo il primo caricamento **non c'è nessun altro tetto**. `-Profile Full` e la ricerca (`-Search`, `search_knowledge`) restituiscono tutto ciò che è pertinente alla richiesta; `-Budget` è un limite facoltativo che imposti tu.

```powershell
# Pacchetto snello (predefinito) e rapporto: caratteri per parte, stima token, peso delle direttive
pwsh -NoProfile -File scripts/knowledge.ps1 -Startup -Report

# Contesto completo (senza tetto) o ricerca mirata nei livelli non caricati
pwsh -NoProfile -File scripts/knowledge.ps1 -Startup -Profile Full
pwsh -NoProfile -File scripts/knowledge.ps1 -Search "termine"
pwsh -NoProfile -File scripts/knowledge.ps1 -Search "più termini della richiesta" -Mode Relevance -Limit 10 -Offset 0

# Recupero a strati: task integro (anche archiviato) o sezione intera
pwsh -NoProfile -File scripts/knowledge.ps1 -Task SB-SIMP-QUEUE-20261101
pwsh -NoProfile -File scripts/knowledge.ps1 -Section "Stato" -Source context
```

Dal server MCP: `get_startup_context` con `profile` = `slim` (predefinito) o `full`; i task completi con `get_ready_tasks` (`includeAcceptance`) o `get_task` (ID o `#seq`, anche archiviati).

**Caricamento a strati**: il profilo snello applica la Progressive Summarization (metodo di Tiago Forte, autore di PARA): ogni livello è un riassunto più breve dell'originale, e i livelli più profondi si leggono solo su richiesta. Qui il riassunto è sempre una scelta di sezioni, mai una riscrittura che perde informazioni: gli originali restano per hash.

**Decisioni in `memory.md`**: ogni scelta durevole va in una riga `Decisione: … — Motivo: …`, senza file dedicati (ADR leggera). Il motivo permette di riesaminarla senza rileggere la cronaca.

**Livelli in `memory.md` e `context.md`**: una sezione `##` è storica, e quindi non caricata nel profilo snello, se il titolo finisce con `(storico)` oppure se la prima riga sotto il titolo è `<!-- sb:tier=history -->`. Le decisioni durevoli e i gotcha restano nelle sezioni essenziali; la cronaca di sessioni e lotti va in quelle storiche. Un file senza marcatori si carica per intero. Per riorganizzare un dossier senza perdere nulla usa la compattazione conservativa (SYS05, `knowledge.ps1 -Compact -CandidatePath`): il candidato è revisionato, l'anteprima precede `-Apply` e gli originali restano per hash in `history/compaction/`.

Il tetto di `-Compact` (`-Budget`, predefinito 50.000) conta le sole parti caricate all'avvio: `context.md` e `memory.md` senza le sezioni storiche, più indice e proiezione dei task. Una riorganizzazione per livelli che sposta la cronaca in sezioni `(storico)` non richiede quindi un `-Budget` esplicito; la stessa cronaca senza marcatore di livello supera il tetto e viene rifiutata.

**Baseline di pubblicazione**: `publication.ps1 -Initial` scrive il baseline REP05 in `publication/baseline-<id>.json`, un file per repository (l'id deriva dal percorso del checkout). Un `-Initial` su un repository non altera il baseline degli altri. Il file unico `publication/baseline.json` delle versioni precedenti è letto solo se registrato per lo stesso repository e non viene riscritto.

**Riferimenti scansionati da REP05**: la storia esaminata (primo controllo e `-Initial`) parte da rami, tag, remoti e `HEAD`. I riferimenti locali che non lasciano il clone (per esempio `refs/codex/*` creati dagli strumenti, stash, notes) non sono scansionati e il rapporto li elenca in `excludedRefs`; se uno di essi va pubblicato, trasformalo in ramo o tag prima del controllo. La scansione incrementale (`baseline..HEAD`) non cambia.

Cosa il rapporto **non** misura: prompt di sistema, definizioni degli strumenti MCP e skill dell'IDE. Se il contesto iniziale resta alto, guarda il riepilogo del contesto dell'IDE per vedere quali server MCP e skill pesano di più. Le misure sono in caratteri, non in token (la stima è caratteri/4).
