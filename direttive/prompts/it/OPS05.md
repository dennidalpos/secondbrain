# OPS05 — Prepara commit e pull request con perimetro, messaggio e controlli verificati

> **Scope**: repo | **Modalità**: scrittura | **Cosa serve**: modifiche locali da consegnare e richiesta esplicita di commit o PR | **Esempio d'uso**: `prepara i commit e la descrizione della pull request`

## Scopo

Preparare la consegna delle modifiche locali: un perimetro verificato, messaggi coerenti con la cronologia del repository e una descrizione della pull request basata su evidenze.

## Quando usarlo

Quando l'utente chiede esplicitamente un commit o una pull request. Commit e push non sono mai impliciti. Per verificare se il contenuto è sicuro da pubblicare usa SEC07.

## Input

Working tree e indice Git, ramo e destinazione, convenzioni dei messaggi nella cronologia recente, esiti dei controlli del progetto.

## Attività specifiche

Esamina `git status` e il diff completo, separando le modifiche pertinenti dal lavoro estraneo, dai file generati, dai residui e dai dati privati o segreti. Proponi un perimetro per commit atomici e prepara messaggi nello stile della cronologia recente. Prima di creare il commit esegui i controlli pertinenti del progetto. Per la pull request scrivi titolo e descrizione con motivazione, modifiche, evidenze e limiti, senza includere dati interni. Non usare reset, opzioni di forzatura o riscritture della cronologia e non saltare controlli o hook.

## Decisioni da raccogliere

- file e modifiche da includere nel commit, anche quando c'è lavoro estraneo;
- ramo, destinazione e visibilità del repository prima di un push o di una pull request.

## Verifiche

Verifica che l'indice contenga solo il perimetro concordato, che i controlli pertinenti passino e che non compaiano segreti o dati privati. Dopo l'operazione verifica l'esito con `git status` e `git log`.

## Consegna

Commit creati o proposti con messaggio e perimetro, la descrizione della pull request, i controlli eseguiti, le modifiche escluse con il motivo ed eventuali blocchi.

## Prompt vicini

- SEC07: Controlla diff, repository e cronologia per dati sensibili prima di pubblicare.
- REP04: Rimuovi residui e codice inutilizzato dopo la verifica.
- REP01: Completa il prossimo task pronto del repository aperto.
