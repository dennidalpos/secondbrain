# Scritture differite senza bloccare le sessioni

Task, memoria, contesto e rapporti possono essere salvati anche quando un altro agente occupa SecondBrain. I comandi di conoscenza conservano prima una richiesta JSON, poi tentano l'integrazione con attesa del lock pari a zero. Il risultato distingue `applied`, `deferred`, `conflict` e `invalid`: `deferred` conferma il salvataggio della richiesta, non l'aggiornamento del dossier.

## Cosa usare

Per task nuovi e cambi di stato restano disponibili `knowledge.ps1 -NewTask` e `-UpdateTaskId`. Il risultato comprende `requestId` e `requestPath`; la numerazione di un task nuovo viene assegnata soltanto quando viene integrato.

Per memoria, contesto e rapporti:

```powershell
# Il contenuto e gia preparato in un file operativo sotto .runtime.
pwsh -NoProfile -File scripts/knowledge.ps1 -AppendFile memory.md -ContentPath $contentPath
pwsh -NoProfile -File scripts/knowledge.ps1 -SaveFile context.md -ContentPath $contentPath -ExpectedHash $baseHash
pwsh -NoProfile -File scripts/knowledge.ps1 -SaveFile history/2026-11-03-sessione/report.md -ContentPath $contentPath -ExpectedHash absent

pwsh -NoProfile -File scripts/knowledge.ps1 -PendingWrites
pwsh -NoProfile -File scripts/knowledge.ps1 -FlushPending
```

Il repository segue il checkout corrente; usare `-CheckoutPath` se il comando parte da un'altra cartella. `-SaveFile` richiede l'hash SHA-256 della base effettivamente letta, oppure `absent` per un file nuovo. `-AppendFile` aggiunge testo in fondo al file corrente e conserva le aggiunte altrui: non riorganizza le sezioni della memoria. I percorsi ammessi sono `memory.md`, `context.md` e `history/<slug>/report.md` nel dossier attivo risolto per identita. Il limite e 2 MiB per richiesta, inclusi metadati JSON.

Configurazioni, direttive, operazioni PARA e allegati generici non entrano nella coda. Per le API personalizzate, ogni modifica centrale resta protetta da `Enter-SBOperation` / `Exit-SBOperation` e dagli hash; una sessione aperta non protegge modifiche dirette effettuate con un editor o con API del filesystem.

## Recupero automatico

L'avvio MCP, le richieste MCP di consultazione, `knowledge.ps1` in lettura, `prompts.ps1` e `secondbrain.ps1 -Check` tentano l'integrazione di massimo 10 richieste per utilizzo. Ogni richiesta usa una transazione breve. Se il centro e ancora occupato, resta pendente e la consultazione prosegue. Non ci sono servizi residenti o monitor periodici aggiuntivi.

I JSON originali sono in `.runtime/access/pending-writes/`; le ricevute sono in `.runtime/access/pending-receipts/`. Sono metadati operativi della stessa cartella SecondBrain condivisa: ogni postazione li raggiunge attraverso il proprio alias della radice. I percorsi di destinazione sono risolti dal repository e dal dossier; non si riusano percorsi assoluti del PC produttore. Cloni Git separati non condividono questi file, esclusi da Git.

I cambi di stato compatibili usano `task.status` nella directory originaria. Gli aggiornamenti estesi nuovi usano `task.update` nella sottocartella `task-update/`, invisibile ai consumer precedenti. I consumer aggiornati integrano entrambe le directory, incluse le richieste estese già presenti nella directory originaria, con le stesse ricevute e lo stesso lock. Durante il rollout un consumer precedente può integrare richieste compatibili mentre quelle estese attendono un consumer aggiornato.

La modifica centrale e la ricevuta entrano nello stesso journal di recupero. Due importatori non applicano due volte la stessa richiesta. Originali, ricevute, conflitti e prove restano conservati fino a una pulizia esplicitamente richiesta.

## Conflitti e interruzioni

Per un cambio di stato si confronta il singolo task: modifiche a task diversi possono convivere. Una modifica concorrente allo stesso task o una sostituzione di file con base cambiata produce `conflict`; il dato corrente resta intatto. Un agente puo leggere richiesta e stato corrente, preparare una riconciliazione e inviare una nuova richiesta autorizzata. Il conflitto precedente resta consultabile.

Se il grafo esistente del tracker è invalido, una modifica al task con hash verificabile può essere accodata e resta pendente fino alla riparazione. L'integrazione riesamina l'hash del task e il grafo riparato. Se il tracker non permette di determinare con certezza l'hash, l'invio restituisce un errore. Le ricevute legacy `invalid` restano conservate per revisione e riconciliazione esplicita.

JSON invalidi e ricevute incoerenti sono segnalati; non impediscono l'integrazione delle altre richieste indipendenti. Errori di accesso non producono ricevute di successo. Una transazione centrale interrotta mantiene il normale gate di recupero: le nuove richieste restano salvate e le letture continuano, mentre il journal va recuperato con `recover.ps1`. Non si forzano lock o marker.

## Contratto MCP e sessioni gia aperte

I tool MCP possono applicare le richieste gia autorizzate prima di rispondere. Sono quindi dichiarati con `readOnlyHint=false`, `destructiveHint=true`, `idempotentHint=false` e `openWorldHint=false`. Le descrizioni e `initialize.instructions` espongono questo comportamento; l'output aggiunge il riepilogo dell'integrazione quando necessario.

Il server negozia `2025-03-26`, mantenendo `2024-11-05` se richiesto da un client precedente. Le annotazioni sono indicazioni per il client, non autorizzazioni. Le regole nominative si preparano con `-ApproveKnowledgeTools` (alias storico `-ApproveReadTools`); `check_publication` conserva la richiesta di consenso. Non vengono aggiunti tool per eseguire comandi arbitrari o nuove scritture MCP.

I processi MCP gia aperti mantengono il codice caricato: la nuova versione viene usata al loro prossimo avvio. Non si riavviano automaticamente sessioni di altri agenti. Il comportamento e verificato con processi locali e fixture; la qualificazione su due PC fisici e SMB reale resta distinta, come descritto in [shared-brain.md](shared-brain.md).
