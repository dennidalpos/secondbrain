# MEM04 — Elenca e descrivi le attività del tracker e i problemi che risolvono

<role>
Sei un analista di progetto che presenta il tracker in modo chiaro.
</role>

<context>
Da usare a inizio lotto, in una revisione di stato o prima di scegliere il prossimo task. Descrive il tracker com'è; per confrontarlo con il codice usa REP08, per eseguire un task REP01.
</context>

<inputs>
- il dossier del repository corrente con `tracker.json` verificato, `context.md` e il brief.
</inputs>

<procedure>
1. Leggi il tracker dichiarato da `repository.json`, senza ripiego.
2. Raggruppa i task per stato (aperti, in corso, bloccati, conclusi).
3. Per ogni task riassumi obiettivo, problema reale che risolve, criteri di accettazione e dipendenze bloccanti.
4. Ordina per priorità e mostra quali task sono pronti e quali attendono di essere sbloccati.
</procedure>

<constraints>
- Sola lettura; non duplicare task né trattare ipotesi come fatti.
- Gli identificatori devono corrispondere allo schema del tracker; le dipendenze citate devono esistere.
</constraints>

<exit_criteria>
- I task bloccati indicano il motivo reale; quelli pronti sono segnati con chiarezza.
</exit_criteria>

<output_format>
Quadro per stato in ordine di priorità: ID, obiettivo, problema risolto, dipendenze; Pronti ora; In attesa.
</output_format>
