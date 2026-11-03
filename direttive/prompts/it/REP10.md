# REP10 — Allinea .gitignore e .gitkeep alla struttura e ai file reali

> **Scope**: repo | **Modalità**: scrittura | **Cosa serve**: stato Git, regole di esclusione e cartelle da preservare nel repository | **Esempio d'uso**: `allinea gitignore e gitkeep prima di pubblicare`

## Scopo

Rendere coerenti le regole di esclusione e i segnaposto delle cartelle con la struttura che il repository dovrebbe avere.

## Quando usarlo

Dopo aver aggiunto strumenti, build, cache o cartelle locali e prima di SEC07 o di una pubblicazione.

## Input

`.gitignore` (radice e annidati), `.gitkeep`, file tracciati e ignorati, cartelle da preservare e regole di pubblicazione.

## Attività specifiche

Confronta `git ls-files`, `git ls-files -ci --exclude-standard` (tracciati ma ignorati), `git status --ignored` e `git check-ignore -v`. Individua file generati o privati non ignorati, regole obsolete, duplicate o troppo ampie che nascondono file legittimi, eccezioni `!` senza effetto su directory ignorate, cartelle da preservare senza `.gitkeep` e file `.gitkeep` superflui in cartelle che hanno già contenuto. Mostra la differenza prima di cambiare qualsiasi cosa. Non rimuovere dall'indice file già tracciati senza conferma: `git rm --cached` solo su richiesta e dopo aver verificato che il file locale resti.

## Decisioni da raccogliere

- file tracciati ma ignorati: mantenere o rimuovere dall'indice;
- cartelle da preservare con `.gitkeep`.

## Verifiche

Verifica ogni nuova regola con `git check-ignore -v` su esempi positivi e negativi, controlla che `git status` non mostri file privati e che nessun file voluto finisca ignorato, ed esegui i controlli di distribuzione del progetto.

## Consegna

Un diff motivato di `.gitignore` e `.gitkeep`, decisioni sui file tracciati ma ignorati e residui.

## Prompt vicini

- REP04: Rimuovi residui e codice inutilizzato dopo la verifica.
- SEC07: Controlla diff, repository e cronologia per dati sensibili prima di pubblicare.
- SEC05: Verifica l'isolamento dei dati personali e la conformità a GDPR e policy.
