# REP10 — Allinea .gitignore e .gitkeep alla struttura e ai file reali

> **Scope**: repo | **Modalità**: scrittura | **Cosa serve**: stato Git, regole di esclusione e cartelle da preservare nel repository | **Esempio d'uso**: `sb prompt REP10: allinea gitignore e gitkeep prima della pubblicazione`

## Scopo

Rendere coerenti le regole di esclusione e i segnaposto di cartella con la struttura che il repository deve avere.

## Quando usarlo

Dopo aver aggiunto strumenti, build, cache o cartelle locali e prima di REP05 o di una pubblicazione.

## Input

`.gitignore` (radice e annidati), `.gitkeep`, file tracciati e ignorati, cartelle da preservare e regole di pubblicazione.

## Attività specifiche

Confronta `git ls-files`, `git ls-files -ci --exclude-standard` (tracciati ma ignorati), `git status --ignored` e `git check-ignore -v`. Individua file generati o privati non ignorati, regole obsolete, duplicate o troppo ampie che nascondono file legittimi, eccezioni `!` inefficaci su directory ignorate, cartelle da preservare senza `.gitkeep` e `.gitkeep` superflui in cartelle già popolate. Mostra la differenza prima di modificare. Non togliere dall’indice file già tracciati senza conferma: `git rm --cached` solo su richiesta e dopo aver verificato che il file locale resti.

## Decisioni da raccogliere

Se più opzioni non sono ricavabili dal codice o dalle fonti, fermati e usa Function Calling o Tool Use a scelta multipla (es. `ask_question`, `AskUserQuestion`): una decisione per domanda, scelta raccomandata come prima opzione con `(Recommended)`, opzioni atomiche e non numerate; scelta multipla quando le opzioni non si escludono.
- file tracciati ma ignorati: mantenere o togliere dall’indice;
- cartelle da preservare con `.gitkeep`.

Senza lo strumento, elenca opzioni numerate e attendi la risposta. Non richiedere di nuovo ciò che è già autorizzato nel perimetro del task.

## Verifiche

Verifica ogni regola nuova con `git check-ignore -v` su esempi positivi e negativi, controlla che `git status` non mostri file privati e che nessun file voluto risulti ignorato, ed esegui i controlli di distribuzione del progetto.

## Consegna

Differenza di `.gitignore` e `.gitkeep` motivata, decisioni sui file tracciati ma ignorati e residui.

## Prompt vicini

- REP04: Rimuovi residui e codice inutilizzato dopo le verifiche.
- REP05: Verifica contenuti e cronologia prima della pubblicazione.
- SEC05: Verifica isolamento dati personali e conformità a GDPR e policy.
