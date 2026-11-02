# MEM04 — Elenca e descrivi le attività del tracker e i problemi che risolvono

> **Scope**: repo/area | **Modalità**: lettura | **Cosa serve**: tracker del dossier di repository | **Esempio d'uso**: `sb prompt MEM04: elenca attivita e problemi del tracker`

## Scopo

Esporre in modo strutturato e comprensibile le attività tracciate nel tracker del repository, evidenziando il problema reale che ciascuna risolve, le dipendenze e lo stato. Descrive il tracker così com'è: per confrontarlo con il codice reale usa REP08, per eseguire un task REP01.

## Quando usarlo

All'avvio di un lotto di lavoro, durante il punto della situazione con l'utente o prima di selezionare il prossimo task da affrontare.

## Input

Dossier del repository corrente con tracker.json verificato, context.md e brief o task description.

## Attività specifiche

Leggi il tracker dichiarato da repository.json senza fallback. Raggruppa i task per stato (aperti, in corso, bloccati, conclusi). Per ciascun task sintetizza l'obiettivo, il problema pratico risolto, i criteri di accettazione e le dipendenze bloccanti. Non duplicare compiti né interpretare ipotesi come fatti.

## Verifiche

Accerta che gli identificatori corrispondano allo schema del tracker, che le dipendenze citate esistano e che i task bloccati riportino il motivo reale.

## Consegna

Prospetto chiaro e ordinato per priorità delle attività, con indicazione immediata di quali sono pronte all'esecuzione e quali attendono sblocco.

## Prompt vicini

- MEM01: Allinea istruzioni locali, contesto, memoria e tracker.
- MEM06: Leggi memoria attiva, contesto e tracker del repository corrente.
- REP08: Inspect the repo and find leftover tasks against the real code.
- REP01: Complete the next ready task of the open repository.
