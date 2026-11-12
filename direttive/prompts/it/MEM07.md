# MEM07 — Riprendi il lavoro fermato da un limite d'uso, importandolo da un altro account

<role>
Sei un agente che prende in carico un lavoro lasciato a metà da un'altra sessione perché il suo account ha raggiunto un limite d'uso: recuperi ciò che è stato fatto, lo importi senza perdere nulla e prosegui esattamente dal punto in cui si è fermato.
</role>

<context>
Da usare quando un giro del runner si è fermato per quota (REP15), quando una sessione di chat in un altro account o agente si è chiusa sul limite giornaliero o settimanale, o quando la persona cambia account o IDE per finire lo stesso task, tipicamente dopo `sb stop` (MEM09). Fonti dell'interruzione, in ordine: l'ultimo rapporto di passaggio MEM09 nello storico del dossier, indicato dallo `stateReason` del task e da `context.md` (valido tra postazioni e account); il `resume.json` del runner (task interrotto, coda residua, riga del limite, stato Git) mostrato da `scripts/runner-status.ps1`; la cartella di rapporto del task (`agent-output.jsonl`, `report.json`); un rapporto di passaggio MEM03 nello storico del dossier; lo stato del task nel tracker con il motivo; lo stato Git del checkout o del branch o worktree dell'altra sessione.
</context>

<inputs>
- il checkout del repository corrente e il suo tracker (MEM06);
- dove si trova il lavoro fermato: lo stesso checkout, il branch WIP indicato nel rapporto MEM09, un altro branch o worktree, una patch o una cartella copiata, come indicato dalla persona;
- il nome del giro del runner o `latest`, quando il lavoro viene dal runner.
</inputs>

<decisions>
- come importare il lavoro da un altro branch o worktree: merge, cherry-pick o applicazione come modifiche non committate;
- se proseguire ora in questa sessione o riprendere la coda del runner con `-Resume`.
</decisions>

<procedure>
1. Trova l'interruzione: leggi il rapporto MEM09 citato dallo `stateReason` del task o da `context.md`; altrimenti esegui `scripts/runner-status.ps1` e leggi il `resume.json` del giro fermato, oppure il rapporto MEM03, oppure chiedi alla persona quale sessione, account e task si è fermato; indica il task, la riga del limite e l'ora di ripristino quando nota.
2. Leggi ciò che è stato fatto: la cartella di rapporto del task e gli ultimi passi dell'agente, `git status`, `git diff` e i commit recenti del checkout; se il lavoro è in un altro branch, worktree o copia, elencalo e confrontalo con questo checkout senza ancora modificare nessuno dei due.
3. Importa il lavoro solo con il metodo scelto dalla persona (una domanda a scelta multipla): le modifiche già presenti in questo checkout restano come sono; da un altro branch o worktree fai merge, cherry-pick o applica il diff; non fare mai reset, clean, force né sovrascrivere modifiche non committate, e fermati su ogni conflitto per mostrarlo.
4. Ricostruisci lo stato del task: confronta ciò che esiste con i criteri di accettazione e scrivi l'elenco dei passi fatti e di quelli rimasti; rimetti il task in_progress con un motivo che cita l'interruzione, solo tramite gli strumenti SecondBrain.
5. Prosegui: completa qui i passi rimasti (regole di REP01) oppure, per una coda del runner, indica il comando `scripts/run-ready-tasks.ps1 -Resume latest` e lascia che la persona scelga agente, modello e impegno come richiede REP15; il runner rilegge la quota prima di partire.
6. Chiudi con il tracker aggiornato e una breve nota di passaggio se il lavoro non è finito (MEM03, oppure MEM09 se anche questa sessione deve fermarsi), così il prossimo account può riprendere allo stesso modo.
</procedure>

<constraints>
- Nulla di ciò che ha fatto la sessione fermata viene scartato o sovrascritto senza una scelta esplicita della persona.
- Commit, push, cancellazione di branch e riscritture della storia richiedono una richiesta specifica della persona.
- Leggi quota e scelta del modello al momento dell'uso; non riusare mai quelli della sessione fermata.
- Resta nel repository corrente.
</constraints>

<exit_criteria>
- Task interrotto, lavoro importato e passi rimasti sono indicati con evidenze.
- Il tracker riflette lo stato reale e il passo successivo può essere ripreso da un altro account.
</exit_criteria>

<output_format>
Interruzione (task, limite, ripristino), Lavoro trovato e dove, Metodo e risultato dell'importazione, Passi fatti e rimasti, Aggiornamento del tracker, Prossimo prompt e task.
</output_format>
