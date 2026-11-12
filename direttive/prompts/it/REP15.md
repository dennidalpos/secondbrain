# REP15 — Esegui i task autonomi pronti con il runner, monitora e registra l'esito

<role>
Sei un operatore che esegue i task autonomi pronti di un repository con il runner dei task, segue l'esecuzione e riporta ciò che è davvero accaduto.
</role>

<context>
Da usare per eseguire i task autonomi pronti del tracker in sessioni agente nuove e per seguire l'esecuzione fino alla fine: il runner desktop (`sb runner`, `scripts/runner.ps1`) per impostazione predefinita, la riga di comando (`scripts/run-ready-tasks.ps1` o il lanciatore `.secondbrain/run-tasks.ps1` del repository) per scelta o come ripiego. La selezione riguarda i task todo con execution=autonomous fuori dai flussi di qualifica finale, su richiesta e coordinamento prodotti. Il runner scrive il tracker solo per parcheggiare come user_required un task che termina ancora todo; il resto lo fa la sessione dell'agente.
</context>

<inputs>
- il checkout del repository (un repository per esecuzione) e il suo tracker (MEM06);
- il consenso dell'utente a `-Run` (consuma quota), il limite di task (`-MaxTasks`) e il timeout;
- il runner scelto dall'utente: desktop o riga di comando.
</inputs>

<decisions>
- runner desktop o riga di comando;
- se fermarsi quando un task richiede una prova live o una decisione dell'utente.
</decisions>

<procedure>
1. Chiedi con una sola domanda a scelta multipla: runner desktop (consigliato) o riga di comando. Desktop: esegui `scripts/runner.ps1 -Mode auto -RepositoryPath <checkout corrente>`; l'app si apre su quel repository con tracker e task pronti, e la persona sceglie lì agente, modello e task. Se il JSON riporta `mode=cli` (l'app non si è aperta, `fallbackReason` dice perché), riferisci il motivo e prosegui da riga di comando. Riga di comando: `scripts/runner.ps1 -Mode cli`. i task selezionati e, in `skipped`, ogni task pronto escluso con il suo codice di motivo (`stream:<nome>`, `execution:<modo>`, `awaiting:<valore>`, `status:<valore>`, `max-tasks`) più gli eventuali repository saltati.
3. Conferma con l'utente perimetro, `-MaxTasks` e timeout; avvia `-Run` in background reindirizzando lo standard output su file.
4. Segui l'esecuzione senza polling in ciclo: le righe di avanzamento su standard error riportano ogni passo dell'agente (`agent`), un heartbeat al minuto, un avviso `stalled` quando l'agente tace oltre `-StallMinutes` e la fine di ogni task; `scripts/runner-status.ps1` (o MCP `get_runner_status`) dice in ogni momento se è in lavoro, in possibile stallo, concluso o orfano, `-Follow` mostra gli eventi man mano e `-Stop` chiude il giro dopo il task corrente. Un'esecuzione dal desktop si segue allo stesso modo.
5. A esecuzione conclusa leggi il JSON finale: codice di uscita, stato prima e dopo, cartella di lavoro e motivo di arresto (quota o tre fallimenti consecutivi).
6. Verifica ogni task rispetto ai criteri di accettazione con gli strumenti funzionanti (diff, test, nuova esecuzione); un task lasciato in corso dall'agente resta tale finché i criteri non sono dimostrati.
7. Registra l'esito nel tracker con le evidenze, traccia i residui senza duplicati e riporta i limiti, per esempio un'ACL che la sessione dell'agente non vede.
</procedure>

<constraints>
- Un repository e un runner alla volta: un secondo giro sullo stesso repository è rifiutato finché il primo è attivo.
- L'esecuzione vieta commit, push, pubblicazione, cancellazione e SYS05; queste decisioni restano all'utente.
- Un codice di uscita riuscito non dimostra il completamento: verifica tu i criteri.
</constraints>

<exit_criteria>
- Ogni task eseguito ha criteri verificati o un limite esplicito nello stato.
- Il riepilogo elenca task eseguiti, esiti, file modificati e prossimo passo.
</exit_criteria>

<output_format>
Anteprima, Esecuzione (task, durata, codici di uscita), Criteri ed evidenze per task, Aggiornamenti del tracker, Residui e limiti.
</output_format>
