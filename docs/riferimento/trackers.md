# Tracker e importazione

> Tool portabile: [procedura corrente](portable-brain.md). Nessun monitor; output operativi sotto .runtime e pulizia solo su richiesta.

## Fonte autorevole

Il resolver condiviso da compositore, Sync e Check risolve il dossier tramite identita GitHub e metadati PARA. In assenza di dichiarazione controlla l'eventuale `tracker.md` nel dossier; le fonti sono censite come `dossier_di origine` o `absent`. Un tracker di origine non e automaticamente conforme allo schema comune e non viene convertito dal monitor.

Il contratto JSON e attivo per ogni dossier; approved.json ne registra lo stato attivo. La dichiarazione nel `repository.json` del dossier e:

```json
"tracker": {"location":"dossier","path":"tracker.json","schemaVersion":1}
```

Una dichiarazione invalida, una destinazione mancante, un contratto non approvato o un tracker non valido sono errori, senza fallback. I Progetti collegati devono indicare la stessa fonte. Il generatore degli AGENTS usa il risultato del resolver; non modificare i blocchi a mano.

## Contratto e conversione

[Schema v1](../../config/tracker.schema.json). Il contratto usa [JSON Schema Draft 2020-12](https://json-schema.org/draft/2020-12/), validato tramite [Test-Json](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/test-json?view=powershell-7.5). La validazione applicativa verifica inoltre data, identita, unicita degli ID, dipendenze esistenti e cicli, anche fra repository gestiti. Gli schemi sono locali; non si aggiunge una dipendenza di rete al monitor. Suite completa e CLI in fixture verificate su PowerShell 7.5.11 e 7.6.9, inclusi DateKind, schema, ripresa e recupero (evidenze e collaudi conservati nel runtime di test).

Le otto collezioni censite alimentano i task conservando priorita e valori originali in `extensions.di origine`. Le note non diventano attivita. Gli ID presenti restano invariati; per testi senza ID viene usato un identificatore esplicito univoco oppure un hash stabile per identita, collezione e contenuto canonico. Collisioni richiedono risoluzione esplicita, senza fusione. Stati o dipendenze ambigui producono `unknown` e impediscono l attivazione. I criteri importati non diventano prove superate.

Il convertitore Markdown riconosce la tabella aperta e le checkbox dei residui del tracker SecondBrain, oltre ai completamenti espliciti della tabella nello storico indicato. Non e un importatore generico di Markdown: formati diversi richiedono una conversione esplicita. L intero originale rimane archiviato e conservato anche nelle estensioni. I record `done` consentono di risolvere le dipendenze storiche; le attivita aperte escludono `done` e `cancelled`.

Ogni riga di tabella o checkbox non riconosciuta fa fallire la conversione, anche dopo righe valide: l'errore indica la riga da revisionare. Non si attiva un tracker parziale o vuoto ignorando attivita. Note in prosa ed esempi nei blocchi di codice sono conservati senza importarli; un documento privo di attivita o una tabella supportata vuota restano validi. Anteprima e attivazione applicano lo stesso riconoscimento.

## Anteprima, preparazione e ripresa

Per riprendere un'importazione, risolvere $manifest dal registro tracker-migrations nel runtime configurato. L anteprima seguente legge lo stato registrato senza scrivere. La preparazione di un elenco esistente richiede -Repository e -SourcePath sul relativo tracker autorevole; non e eseguita automaticamente.

```powershell
$cfg = '.runtime/hosts/<id>/workstation.json'
./scripts/import-tracker.ps1 -ConfigPath $cfg -ResumeManifest $manifest
```

Senza `-Apply` la CLI valida in sola lettura. Con `-Apply` prepara manifest, backup, copia storica esatta e candidato JSON nel backupRoot, fino a `verified`. Il candidato non e ancora la fonte autorevole. Exit 1 indica preparazione con attivazione pendente; exit 0 indica anteprima valida o migrazione completata. Gli errori PowerShell terminano con esito non zero e messaggio diagnostico.

Le fasi sono `pending`, `prepared`, `copied`, `verified`, `references_updated`, `originals_removed`, `completed`; il recupero termina in `rolled_back`. Il registro nel runtime collega ogni identita al proprio manifest nel backupRoot configurato. I manifest sono dati operativi, non autorizzazioni. Ogni operazione registra hash precedente, hash atteso e payload di recupero prima della scrittura. Le copie storiche hanno attributi Git `-text` per preservare i byte.

```powershell
# Solo dopo l approvazione esplicita della proposta concreta:
./scripts/import-tracker.ps1 -ConfigPath $cfg -ResumeManifest $manifest -Apply -Activate
# Anteprima del recupero, poi applicazione esplicita:
./scripts/import-tracker.ps1 -ConfigPath $cfg -RollbackManifest $manifest
./scripts/import-tracker.ps1 -ConfigPath $cfg -RollbackManifest $manifest -Apply
```

L attivazione aggiorna dichiarazione e riferimenti, inclusi i Progetti, e rimuove l originale solo dopo averne verificato le copie. Una sorgente modificata dopo la preparazione blocca la ripresa; non aggiornare a mano gli hash per superare il blocco. Il recupero verifica prima tutti i payload e le destinazioni e rifiuta di sovrascrivere modifiche successive. Una migrazione preparata non congela il tracker: se questo cambia, recuperare la preparazione e prepararne una nuova dalla fonte corrente.

La conversione usa le copie verificate, con il formato originale. Il controllo della fonte viene ripetuto prima dell attivazione e della rimozione, anche nella ripresa da `references_updated`; l hash atteso per rimuovere resta quello della fonte convertita. Una fonte gia assente e ammessa in questa fase soltanto se la rimozione e registrata nel journal con lo stesso hash. I riferimenti correnti nel dossier migrato e i Progetti che usavano tracker nel checkout vengono riconciliati nella transazione; storico, snapshot, esempi inline e fence restano conservati.

Anteprima, preparazione, attivazione e ripresa usano la stessa raccolta non ricorsiva dei tracker correlati del resolver. Il grafo viene rivalidato prima dell attivazione: una dipendenza rimossa dopo la preparazione blocca il passaggio, come un task inesistente, un ciclo o un identita non gestita.

Usare sessioni Write Start/End nello stesso script con `try/finally`, passando `-SessionId` alle CLI. Dopo le scritture eseguire Sync e i controlli del progetto. Build e CI dei prodotti restano indipendenti da SecondBrain.

## Copertura di Check

Check legge contesto, memoria, brief e tracker Markdown correnti delle Aree non archiviate: segnala riferimenti di origine e target Markdown locali mancanti, escludendo storico, snapshot, blocchi di codice e link dimostrativi nel codice inline. Non verifica anchor o URL remoti. Verifica inoltre fonti dichiarate, riferimenti dei Progetti e registri di migrazione; una preparazione `verified` resta una segnalazione di lavoro incompleto. Nessuna copia o correzione e eseguita da Check.

I limiti GitHub/Wiki restano separati: un'importazione locale o un esito strutturale non li risolve.

## Spostamenti PARA

Archive e Restore aggiornano anche i percorsi operativi dei manifest tracker delle postazioni registrate, nella stessa transazione del dossier e degli inventari. Gli hash di candidato, originali e payload non vengono ricalcolati; il registro continua a indicare il manifest nel backupRoot della relativa postazione. Il recupero PARA comprende i soli manifest registrati e validati, anche se il dossier e ancora spostato parzialmente.

Le migrazioni `completed` e `rolled_back` consentono lo spostamento; qualsiasi fase pendente lo impedisce prima delle scritture. Un manifest completato puo essere letto e ripreso anche con Area archiviata o ritirata. Il recupero tracker continua a rifiutare modifiche successive, compresi aggiornamenti al tracker dopo Archive/Restore. Queste operazioni richiedono comunque una richiesta esplicita; nessuna archiviazione e implicita nella importazione tracker.

Il tracker JSON corrente viene incluso nella transazione anche per i suoi riferimenti: provenance, evidence, history e extensions.source. I percorsi relativi al repository seguono lo spostamento; quelli relativi al dossier vengono risolti rispetto alla posizione precedente e ricalcolati dalla nuova, conservando i suffissi. Candidate e originali archiviati, hash delle fonti e valori importati in di origine restano invariati. Il journal aggiorna l'hash distribuito del tracker solo se questo coincideva ancora con la versione della migrazione: lo spostamento non rende ammissibile un rollback gia impedito da modifiche utente.

## Review esplicita della conversione

`import-tracker.ps1 -ReviewPath <file.json>` e facoltativo nella preparazione e nell anteprima. Il documento ha `schemaVersion: 1`, `repository`, `sourceSha256` e `tasks`: ogni decisione contiene `id`, `status`, `reason` e, quando necessario, `dependencies` tipizzate e `prerequisites` testuali. ID inesistenti o duplicati, identita/hash divergenti e dipendenze irrisolte senza riconciliazione esplicita sono rifiutati. Non si modificano i dati di origine.

La review viene copiata byte per byte nel manifest e nello storico; le decisioni e il loro hash restano nelle estensioni del tracker. La ripresa usa la copia registrata, controllando che anche la fonte sia invariata prima dell attivazione. Non modificare il candidato o i suoi hash a mano. Una review classifica lo stato e i prerequisiti: non costituisce una nuova verifica dei criteri applicativi. I manifest precedenti senza review restano compatibili.

## Proiezione e mutazione atomica dei task

La proiezione dei task con `Get-SBTaskProjection` (o `scripts/knowledge.ps1 -Tasks`) supporta il filtro `-ReadyOnly`, che seleziona le sole attività non bloccate le cui dipendenze risultano tutte soddisfatte (`done` o `completed`), risolvendo sia dipendenze locali che dipendenze cross-repository tramite il dizionario dei tracker correlati.

### Perimetro per repository

`knowledge.ps1 -Tasks`, `-Startup` e `-UpdateTaskId` (come i tool MCP `get_ready_tasks` e `get_startup_context`) operano sul repository in lavoro: `-Repository` esplicito oppure quello del checkout corrente (`-CheckoutPath` o directory corrente), risolto da binding e origin. Fuori da un checkout riconoscibile terminano con errore invece di elencare altri repository. La vista globale è un opt-in in sola lettura (`knowledge.ps1 -Tasks -All`, MCP `all=true`), incompatibile con `-Repository`, con ogni voce etichettata `scope: global`. `-UpdateTaskId` e `Set-SBTrackerTaskStatus -WorkingRepository` rifiutano la scrittura sul tracker di un repository diverso da quello in lavoro.

`secondbrain.ps1 -Check|-Sync -Repository <identità>` limita il controllo a un solo repository gestito: nessun esito di altri repository, IDE o testi globali; il risultato dichiara la copertura in `scope` (`repository-only` con l'elenco di ciò che non copre; senza filtro `workstation`). Il Sync filtrato non riscrive inventario, mappa IDE né indice PARA. I prompt di repository (REP01) rifiutano task di altri repository anche se `autonomous`.

Per aggiornare lo stato di un task nel tracker autorevole senza rischiare corruzioni dello schema o incoerenze nel grafo delle dipendenze, `SecondBrain.Tracker.psm1` mette a disposizione le funzioni `Set-SBTrackerTaskStatus` e `Update-SBTrackerTask` (quest'ultima risolve il tracker da identità o percorso):
- Verifica preventivamente la validità dello schema v1 e delle regole del grafo tramite `Test-SBTrackerData` prima di qualsiasi scrittura su disco;
- Rifiuta stati sconosciuti, task inesistenti o cicli/dipendenze non valide;
- Esegue la scrittura in modo atomico tramite `Invoke-SBParaTransaction`, creando un backup di rollback e un manifest transazionale sotto `.runtime/backups`.

## Proiezione dei Task e Budget

Il `tracker.json` conserva tutti i task con il loro stato (`todo`, `in_progress`, `blocked`, `done`, `cancelled`, `unknown`); non esiste una archiviazione automatica verso file separati. Per contenere il pacchetto di avvio snello entro **20.000 caratteri**, `knowledge.ps1 -Startup` e il server MCP usano una proiezione: i task chiusi (`done`/`cancelled`) non vengono inclusi, e con `-ReadyOnly` (`get_ready_tasks`) restano solo i task non bloccati le cui dipendenze sono soddisfatte. Se il tracker cresce troppo, la compattazione conservativa (SYS05) archivia gli originali per hash senza cancellare informazioni.
