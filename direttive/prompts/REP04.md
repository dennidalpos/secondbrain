# REP04 — Rimuovi residui e codice inutilizzato dopo le verifiche

> **Scope**: repo/area | **Modalità**: scrittura | **Cosa serve**: elenco percorsi candidati e verifica riferimenti attivi | **Esempio d'uso**: `sb prompt REP04: rimuovi file temporanei e build cache orfane`

## Scopo

Rimuovere file, codice, configurazioni, branch o worktree solo dopo aver dimostrato che sono superflui e che il recupero è possibile.

## Quando usarlo

Per pulizia richiesta di file, codice, configurazioni, branch o worktree.

## Input

Perimetro, stato Git reale, riferimenti e dati da preservare.

## Attività specifiche

Verifica consumatori e dipendenze; per branch/worktree controlla modifiche, commit e lavoro unico. Predisponi recupero verificabile per i dati interessati. I nomi delle cartelle e lo stato ignorato sono indizi, non prove di eliminabilità.

La pulizia di backup, build, cache, fixture e catture richiede richiesta esplicita con perimetro concreto. Usa manifest e hash; nessuna retention distruttiva automatica. I nomi delle directory non autorizzano cancellazioni. Conserva gli artefatti quando la pulizia non è richiesta.

## Verifiche

Usa anteprima degli strumenti disponibili, verifica target assoluti e backup prima delle rimozioni. Controlla diff e funzionalità interessate; conserva artefatti ufficiali.

## Consegna

Elementi rimossi, prove di inutilizzo e recupero, residui preservati con motivo.

## Prompt vicini

- DEV03: Esegui un refactoring preservando contratti e comportamento.
- MEM01: Allinea istruzioni locali, contesto, memoria e tracker.
- REP10: Allinea .gitignore e .gitkeep alla struttura e ai file reali.
