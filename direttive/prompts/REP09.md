# REP09 — Prepara commit e pull request con perimetro, messaggio e controlli verificati

> **Scope**: repo | **Modalità**: scrittura | **Cosa serve**: modifiche locali da consegnare e richiesta esplicita di commit o pull request | **Esempio d'uso**: `sb prompt REP09: prepara commit e descrizione della pull request`

## Scopo

Preparare la consegna delle modifiche locali: perimetro verificato, messaggi coerenti con la storia del repository e descrizione della pull request fondata sulle prove.

## Quando usarlo

Quando l'utente chiede esplicitamente di creare un commit o una pull request. Commit e push non sono mai impliciti. Per la verifica di pubblicabilità usa REP05.

## Input

Working tree e indice Git, ramo e destinazione, convenzioni dei messaggi nella storia recente, esiti dei controlli del progetto.

## Attività specifiche

Esamina `git status` e il diff completo, separando le modifiche pertinenti da lavoro estraneo, file generati, residui e dati privati o segreti. Proponi un perimetro per commit atomici e prepara messaggi nello stile della storia recente. Prima di creare il commit esegui i controlli del progetto pertinenti. Per la pull request redigi titolo e descrizione con motivazione, modifiche, prove e limiti, senza includere dati interni. Non usare reset, forzature o riscritture della storia, e non saltare i controlli o gli hook.

## Decisioni da raccogliere

Se più opzioni non sono ricavabili dalla richiesta, fermati e usa Function Calling o Tool Use a scelta multipla (es. `ask_question`, `AskUserQuestion`): una decisione per domanda, scelta raccomandata come prima opzione con `(Recommended)`.

- file e modifiche da includere nel commit, anche quando c'è lavoro estraneo;
- ramo, destinazione e visibilità del repository prima di push o pull request.

Senza lo strumento, elenca opzioni numerate e attendi la risposta. Non richiedere di nuovo ciò che è già autorizzato nel perimetro del task: una richiesta esplicita di commit e push autorizza entrambi in sequenza.

## Verifiche

Verifica che l'indice contenga solo il perimetro concordato, che i controlli pertinenti siano verdi e che non compaiano segreti o dati privati. Dopo l'operazione controlla l'esito con `git status` e `git log`.

## Consegna

Commit creati o proposti con messaggio e perimetro, descrizione della pull request, controlli eseguiti, modifiche escluse con motivo ed eventuali blocchi.

## Prompt vicini

- REP05: Verifica contenuti e cronologia prima della pubblicazione.
- REP04: Rimuovi residui e codice inutilizzato dopo le verifiche.
- REP01: Completa il prossimo task eseguibile del repository aperto.
