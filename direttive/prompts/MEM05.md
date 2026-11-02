# MEM05 — Crea, aggiorna e archivia progetti, aree e risorse del PARA centrale

> **Scope**: central | **Modalità**: scrittura | **Cosa serve**: obiettivo dell'entità PARA e sessione di scrittura sul clone SecondBrain | **Esempio d'uso**: `sb prompt MEM05: archivia la risorsa conclusa res-guida`

## Scopo

Dare a ogni agente una regola unica su dove inserire, aggiornare e archiviare le entità PARA, senza dedurla dal filesystem né spostare cartelle a mano.

## Quando usarlo

Quando un lavoro richiede un nuovo progetto o una nuova risorsa, quando un'entità cambia stato (conclusa, annullata, ritirata) o quando va archiviata o ripristinata.

## Input

Tipo di entità (progetto, area o risorsa), identificatore (`^[a-z][a-z0-9-]{0,95}$`), titolo, obiettivo, criteri di completamento per i progetti, Aree collegate e stato desiderato. Radice SecondBrain con `para-index.json` e `para.json` delle entità.

## Attività specifiche

Dove sta ogni cosa:

- **Area** (`02-areas/products/<nome>--<hash>`): un dossier per repository, creato solo da `sb attiva` (SYS03). Non crearlo né spostarlo a mano.
- **Progetto** (`01-projects/<id>`): lavoro con obiettivo e criteri di completamento, legato a una o più Aree attive.
- **Risorsa** (`03-resources/<id>`): conoscenza di riferimento non legata a un repository.
- **Archivio** (`04-archives/{areas,projects,resources}/<id>`): destinazione delle entità concluse o ritirate. `PARA.md` e `para-index.json` sono viste generate: non modificarle.

Comandi di `scripts/para.ps1` (scritture con `-SessionId` di una sessione Write; leggi prima con `-Check` e `-SuggestArchive`):

1. **Inserire.** `-NewProject -Id -Title -Areas -Objective -Acceptance` (Aree attive esistenti, non repository) oppure `-NewResource -Id -Title -Objective`. L'identificatore deve essere libero. Il progetto nasce senza tracker: collega un tracker solo con riferimento valido (area e percorso) e verifica con `-Check`.
2. **Aggiornare.** `-SetStatus -EntityId -Status`: progetto `active|completed|cancelled`, area e risorsa `active|retired`. Cambia solo `status` in `para.json`, dentro una transazione con backup. Per il resto aggiorna `brief.md`, `context.md` e `memory.md` con la regola di sintesi minima (MEM01).
3. **Archiviare.** Solo entità `completed`, `cancelled` o `retired`, e Aree senza progetti attivi collegati: `-Archive -EntityId`. Il comando sposta la cartella in `04-archives/<categoria>/<id>` e aggiorna riferimenti e manifest tracker nella stessa transazione. Il dossier archiviato non si riattiva implicitamente.
4. **Ripristinare.** `-Restore -EntityId` riporta l'entità attiva in `02-areas/products/<id>`, `01-projects/<id>` o `03-resources/<id>`: un'Area torna con il suo identificatore, non con il nome di cartella originale.
5. **Dopo ogni scrittura.** Esegui `secondbrain.ps1 -Sync` e `-Check`; `para.ps1 -Check` conferma la coerenza di indice e metadati.

Non cancellare né sovrascrivere entità esistenti, non toccare `.runtime/para-transaction.json`: una transazione interrotta si ripristina con `recover.ps1` e il manifest indicato.

## Decisioni da raccogliere

Se tipo, identificatore, Aree collegate o stato non sono ricavabili dalla richiesta, fermati e usa Function Calling o Tool Use a scelta multipla (es. `ask_question`, `AskUserQuestion`): una decisione per domanda, scelta raccomandata come prima opzione con `(Recommended)`.

- tipo di entità e identificatore;
- Aree collegate al progetto;
- archiviare ora o solo proporre (`-SuggestArchive`).

Senza lo strumento, elenca opzioni numerate e attendi la risposta. Non chiedere di nuovo ciò che è già autorizzato nel perimetro del task.

## Verifiche

`para.ps1 -Check` e `secondbrain.ps1 -Check` senza problemi; l'entità compare in `para-index.json` con il percorso atteso; nessun file residuo nella cartella di origine dopo l'archiviazione.

## Consegna

Entità create, spostate o con stato cambiato (identificatore, percorso, stato prima e dopo), esito dei controlli ed eventuali manifest di recupero.

## Prompt vicini

- SYS06: Leggi memoria attiva, contesto e tracker del repository corrente.
- SYS05: Compatta il dossier preservando originali, fatti e TOC.
- MEM03: Chiudi la sessione: memorie, tracker, handoff e richiesta di commit e push.
