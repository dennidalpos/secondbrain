# Ciclo delle memorie per repository

Il ciclo conserva i nuovi turni in un registro separato dalle memorie derivate. I comandi operano su una sola identita Git, risolta in un dossier PARA attivo. Non importano automaticamente vecchie chat e non usano QMD o servizi di inferenza esterni.

## Stato e limiti

La CLI accetta eventi gia normalizzati ed esplicitamente autorizzati per il turno. I profili Claude Code, Codex e Antigravity descrivono l'evento nativo atteso; gli altri profili dichiarano il fallback. **Non e presente una cattura nativa qualificata delle chat**: l'installazione di un hook o la compatibilita con MCP non rendono esportabile una trascrizione. Senza una ricevuta verificata, `-Operation Adapter` restituisce `liveVerified=false` e copertura parziale. Il fallback richiede un'esportazione del solo turno corrente nel contratto normalizzato, senza leggere archivi di autenticazione. Non e dichiarato un risparmio di token verificato negli IDE.

Le nuove prescrizioni e il pilota richiedono approvazione esplicita dei testi e del perimetro. Un pilota guidato con envelope autorizzati non qualifica automaticamente i collector nativi dei client. Il vecchio hook Trace ora tace quando non riceve permesso esplicito per il turno. Nessun aggiornamento del registro viene inventato per i turni mancanti.

Il bridge `memory-cycle-hook.ps1 -Client <client> -PermitPath <permesso-del-turno> -PermitSha256 <hash-ricevuta>` legge lo stdin nativo, normalizza meccanicamente il solo turno corrente e usa lo stesso writer. Il permesso deve dichiarare repository, client e versione, sessionId, turnId, transcriptPath esatto, lastUserSha256 (hash della serializzazione JSON stabile del contenuto dell'ultimo messaggio umano), persistence e policyEvidence, oltre a workspace gia inizializzata. Codex usa turn_id, Claude Code l'UUID dell'ultimo messaggio umano, Antigravity executionNum. Turno, sessione, percorso o richiesta diversi rendono il permesso inutilizzabile. Il bridge non installa hook o concede permessi da solo; errori e formati non riconosciuti lasciano il turno libero di terminare.

Il permesso deve risiedere nella workspace evidence autorizzata della postazione e del repository. Prima di aprire una sessione Write, il bridge verifica anche cwd/workspacePaths nativi contro i binding registrati: repository diversi, radici sconosciute o assenti non vengono registrati. Un cambio di remoto richiede la riconciliazione del binding tramite i controlli esistenti.

Le fixture verificano formati JSONL rappresentativi, non i formati effettivamente esportati dalle versioni installate. Per la promozione al termine, il permesso puo riferire candidatePath nella stessa workspace e candidateSha256 verificato; il candidato con captureSha256=bind-current-turn viene legato in memoria alla cattura appena eseguita. Eventuali allowedAttachmentPaths autorizzano file esatti; il testo della trascrizione non li concede.

`Adapter -Repository <identita> -ObservationPath <ricevuta>` puo leggere una qualificazione conservata nella workspace evidence del repository. La ricevuta richiede schemaVersion=1, repository, client, clientVersion, workspace, observedAt, coverage (partial/complete), evidenceKind, evidencePath, evidenceSha256 e moduleSha256 del modulo MemoryCycle corrente. Fonte e ricevuta devono restare nella stessa workspace. Solo evidenceKind=live-client segnala liveVerified; una fixture non lo fa. La verifica degli hash accerta integrita e revisione della ricevuta, non dimostra da sola la veridicita dell'osservazione: la prova live deve essere realmente acquisita e revisionata. La ricevuta non autorizza la persistenza dei turni.

## Interfacce

```powershell
# Tutti questi comandi sono di sola lettura e non recuperano scritture pendenti.
pwsh -NoProfile -File scripts/memory-cycle.ps1 -Operation Adapter -Client codex
pwsh -NoProfile -File scripts/memory-cycle.ps1 -Operation Context -Repository <identita>
pwsh -NoProfile -File scripts/memory-cycle.ps1 -Operation Maintenance -Repository <identita>
pwsh -NoProfile -File scripts/knowledge.ps1 -Startup -NoRecovery
pwsh -NoProfile -File scripts/mcp-server.ps1 -NoRecovery
```

Il server MCP non integra mai scritture pendenti. L'argomento tool `noRecovery=true` o `_meta.noRecovery=true` in JSON-RPC vieta nuove scritture per quella richiesta; per un'intera sessione senza scritture avviare il server con `-NoRecovery`.

`Capture` e `Promote` richiedono `-InputPath`; senza `-Apply` mostrano un'anteprima. `Index -Repository <identita> -Apply` ricostruisce gli indici. Le applicazioni aprono una sessione Write con chiusura in finally se non viene fornito un SessionId. Le cartelle evidence vengono create con work.ps1 -Init; registro, originali e ricevute non sono soggetti a cancellazione automatica.

## Contratto di acquisizione

Esempio sintetico di envelope (non e una concessione di permessi):

```json
{
  "schemaVersion": 1,
  "repository": "github.com/example/project",
  "client": "codex",
  "clientVersion": "observed-version",
  "sessionId": "session-1",
  "turnId": "turn-1",
  "persistence": "allowed",
  "policyEvidence": "Current turn authorization reference",
  "termination": "completed",
  "events": [
    {"id": "user-1", "kind": "user", "content": "Inspect the configuration."},
    {"id": "tool-1", "kind": "tool-result", "content": "Synthetic observed result", "exitCode": 0}
  ],
  "attachments": []
}
```

La chiamata con `-Apply` e la politica corrente devono essere autorizzate: il testo di un allegato o di un evento non autorizza operazioni. Politica `disabled`, assente o sconosciuta termina prima di creare cartelle o code. Non dedurre il permesso da una precedente autorizzazione o da un hook installato.

Tipi evento: user, assistant, tool-request, tool-result, error, interruption. La posizione conserva l'ordine di ingresso; ID ripetuti sono rifiutati. Una dichiarazione di completezza del produttore resta `declared-complete-unverified`. Non vengono importati campi di ragionamento nascosto. Il limite di sicurezza e 8 MiB per envelope CLI e 10.000 eventi; non si tronca un turno per rispettarlo.

`<private>...</private>`, `<do-not-memorize>...</do-not-memorize>`, `private=true` e `doNotMemorize=true` escludono l'evento prima della persistenza. Una regione privata aperta continua fino alla chiusura; dopo una richiesta umana privata anche risposte e operazioni restano escluse fino a una nuova richiesta umana pubblica, per evitare di registrarne gli echi. Si conserva solo il conteggio delle omissioni, senza testo, percorsi o ID esclusi. Gli allegati devono riferirsi a un evento conservato. Candidati di memoria con riferimenti evento non risolvibili non vengono salvati neppure come proposte.

Per un allegato, l'envelope indica `eventId` e un percorso assoluto. Il chiamante deve autorizzare separatamente ogni file con `-AttachmentPath`: il solo percorso nell'envelope non permette la lettura. Originali fino a 64 MiB sono verificati con SHA-256 e deduplicati entro il repository/postazione; i riferimenti effettivi sono in `assetLocations`. Testo UTF-8 di md/txt/json/csv/tsv/log viene estratto con decodifica stretta. Altri formati restano `original-only`, senza dichiarare OCR o conversioni non eseguite. File esplicitamente privati e percorsi di autenticazione sono esclusi. La marcatura di un file binario deve provenire dai metadati del turno: non e implementato un rilevatore universale di segreti nei binari.

## Promozione e recupero

Un candidato di promozione contiene schemaVersion, repository, persistence e policyEvidence, capturePath e captureSha256 (hash del file acquisito), sources (hash dei file destinatari; `absent` per un nuovo topic) e changes. Richiede la stessa cartella evidence con `-Workspace`.

Ogni variazione include `verified=true`, eventIds esistenti nel registro e kind:

| kind | Campi e comportamento |
|---|---|
| decision | id, text, reason; supersedes opzionale per una decisione attiva strutturata |
| context | text completo con le quattro sezioni essenziali |
| topic | path sotto topics/ e text |
| task | id, status, evidenceReference; per done, verifiedAcceptance uguale ai criteri del task |

Le evidenze sono dichiarazioni strutturate dell'agente da revisionare nel suo perimetro; il motore non prova semanticamente che una conclusione sia vera. Ambiguita, evidenze mancanti e hash obsoleti producono proposte senza aggiornare memorie. Tracker e archivio dei task terminali condividono la transazione delle memorie. Le versioni precedenti dei file modificati rimangono per hash; la vista agente viene rigenerata nella stessa transazione. Gli indici sono derivati ricostruibili: un errore successivo nella loro rigenerazione non annulla una promozione gia completata.

Le decisioni usano marcatori `<!-- sb:decision id=<id> state=active -->`; una sostituzione conserva il testo precedente con state=superseded. Le righe tradizionali rimangono leggibili. La vista agente esclude i blocchi superati; i loro originali restano consultabili. I derivati applicano principi STE pragmatici nella lingua del dossier, senza una certificazione ASD-STE100 o un linter semantico automatico.

Il contesto Slim predefinito include solo i task esplicitamente selezionati (`TaskIds`), mentre Full conserva la vista completa. `memory-cycle -Operation Context` e `knowledge -Startup` accettano `-PreviousRevision`; MCP `get_startup_context` espone `previousRevision`. Una revisione invariata restituisce `changed=false` senza ripetere le parti; una revisione nuova produce un pacchetto aggiornato, non una sostituzione garantita della cronologia interna del client. Memoria essenziale, sezioni correnti obbligatorie e task selezionati non vengono eliminati per far apparire rispettato il budget. Se il minimo supera il tetto, il risultato segnala `withinBudget=false` e il minimo richiesto. Il default di Slim e Compact e 25.000 caratteri; gli override espliciti restano disponibili.

Ogni cattura aggiorna nella stessa transazione `turns-index.json`, con soli metadati. Gli avvisi di compattazione contano questi indici locali e la traccia metadata legacy senza caricare conversazioni grezze. Il risultato distingue capturedTurns, legacyTurns e copertura del conteggio: configurare un solo collector per evento evita di contare anche una traccia legacy priva di ID per lo stesso turno. Context lega la revisione a fonti, task selezionati e budget e segnala indici mancanti/obsoleti e proposte pendenti.

SYS05 gestisce la manutenzione per lotti con anteprima e conferma, preservando le fonti. MEM03 distingue la chiusura incrementale dalla consegna del lotto. Le autorizzazioni nello storico non sono permessi correnti.

## Ricevuta CLI esplicita per turno

Preparare in una cartella evidence inizializzata con work.ps1 un JSON privato con schemaVersion=1, repository, client, clientVersion, sessionId, turnId, transcriptPath assoluto, requestContent nel formato umano nativo esatto, persistence="allowed" e policyEvidence del solo turno. Codex usa i blocchi di testo; Claude Code stringa/blocchi; Antigravity userMessage. Non dedurre il consenso da permission_mode o dall installazione.

Eseguire memory-cycle.ps1 -Operation Permit -InputPath <richiesta.json> -Workspace <evidence> per l anteprima, poi la stessa CLI con -PreviewSha256 <permitSha256 dell anteprima> e -Apply per autorizzare esplicitamente: hash assente, alterato o diverso viene rifiutato prima di configurazione, sessioni e ricevute, quindi richiesta, candidato o revisioni cambiati dopo l anteprima richiedono una nuova anteprima. Passare permitPath e permitSha256 restituiti al bridge memory-cycle-hook.ps1 tramite -PermitPath e -PermitSha256. Lo stdin del bridge contiene lo Stop nativo con nome evento stringa (hook_event_name, hookEventName o eventName) uguale a Stop; UserPromptSubmit, PreToolUse, altri nomi o payload senza tipo sono soppressi prima di cattura, promozione o sessione writer. Nessuna installazione automatica di hook; se il client non espone i confini prima dello Stop, mantenere il fallback guidato senza inventare identificatori.

La ricevuta immutabile in workspace/permits conserva l hash della richiesta e vincola repo, client/versione, sessione/turno, transcript, policy, workspace e revisioni di modulo/bridge. Il riuso identico restituisce duplicate; un turno diverso non è autorizzato. Hash assente, alterato o revisione cambiata: soppressione non bloccante. I vecchi permessi manuali senza marker CLI e hash correnti non abilitano la cattura.

Attachments autorizza solo i file esatti collegati agli eventId conservati. candidatePath opzionale vincola un candidato già preparato nella workspace; captureSha256="bind-current-turn" lo collega alla cattura. Promozione transazionale, proposte per ambiguità/conflitti, replay idempotente. I permessi sconosciuti/vietati e le richieste private escono prima di configurazione, sessioni, code o recovery. La modifica della ricevuta per revocare il consenso invalida l hash precedente. Le prove sono sintetiche, separate dalle qualifiche live. Vedere la [guida inglese](memory-cycle.md#explicit-single-turn-cli-receipt) per comandi, limiti e fonte ufficiale Codex.

## Limiti osservati

Il bridge accetta solo un payload nativo con nome evento stringa Stop; nomi diversi, assenti o vuoti sono soppressi (fixture negative per UserPromptSubmit, PreToolUse e payload senza tipo). Permit -Apply richiede il permitSha256 dell anteprima e rifiuta un hash diverso prima di ogni scrittura. Entrambi i controlli sono verificati solo su fixture sintetiche: i client reali non sono qualificati e la qualifica live resta in #322/#351/#352; la raccolta nativa automatica resta un pilota guidato. Gli hash vincolano l artefatto CLI locale esaminato; non sono firme digitali. Le qualifiche di client, account e SMB restano distinte.
