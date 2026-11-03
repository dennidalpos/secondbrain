# REP04 — Rimuovi residui e codice inutilizzato dopo la verifica

> **Scope**: repo/area | **Modalità**: scrittura | **Cosa serve**: prova dell'assenza di riferimenti e test verdi | **Esempio d'uso**: `rimuovi i file temporanei e le cache di build orfane`

## Scopo

Rimuovere file, codice, configurazione, rami o worktree solo dopo aver dimostrato che sono superflui e che il recupero è possibile.

## Quando usarlo

Per pulizie richieste di file, codice, configurazione, rami o worktree.

## Input

Perimetro, stato Git reale, riferimenti e dati da preservare.

## Attività specifiche

Verifica consumatori e dipendenze; per rami e worktree controlla modifiche, commit e lavoro unico. Predisponi un recupero verificabile per i dati coinvolti. Nomi di cartelle e stato di ignorato sono indizi, non prova che qualcosa si possa cancellare.

La pulizia di backup, build, cache, fixture e catture richiede una richiesta esplicita con un perimetro concreto. Usa manifest e hash; nessuna retention distruttiva automatica. I nomi delle directory non autorizzano cancellazioni. Conserva gli artefatti quando la pulizia non è richiesta.

## Verifiche

Usa l'anteprima degli strumenti disponibili, verifica i bersagli assoluti ed esegui un backup prima delle rimozioni. Verifica il diff e le funzionalità coinvolte; conserva gli artefatti ufficiali.

## Consegna

Elementi rimossi, prova di non utilizzo e di recupero, residui preservati con il motivo.

## Prompt vicini

- DEV03: Rifattorizza il codice preservando i contratti: mirato, a fasi o periodico.
- REP10: Allinea .gitignore e .gitkeep alla struttura e ai file reali.
