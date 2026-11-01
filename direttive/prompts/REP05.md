# REP05 — Verifica contenuti e cronologia prima della pubblicazione

> **Scope**: repo | **Modalità**: lettura | **Cosa serve**: stato Git, cronologia e albero di lavoro | **Esempio d'uso**: `sb prompt REP05: verifica pubblicabilita per prevenire leak di segreti`

## Scopo

Preparare un repository pubblico senza dati privati, segreti o residui operativi.

## Quando usarlo

Prima di commit/push richiesti, release o revisione della pubblicabilità.

## Input

Working tree, indice Git, storia raggiungibile e destinazione di pubblicazione.

## Attività specifiche

Usa publication.ps1 -RepositoryPath e salva eventuali rapporti solo in SecondBrain/.runtime. Esamina rilievi distinti per working tree, indice e storia; i risultati contengono hash e posizioni, non valori segreti. Verifica anche binari, screenshot, metadati, licenze e contenuti volutamente pubblici. Per falsi positivi prepara una policy locale schema 1 con allowances contenenti rule, path, fingerprint e reason; non sopprimere categorie intere. Se emergono rilievi o scelte tra opzioni di policy, usa Function Calling o Tool Use (es. `ask_question`) per confermare le azioni con l'utente. Informazioni private e artefatti operativi appartengono a SecondBrain. Nessun reset o cancellazione del lavoro locale. Un rilievo storico richiede una decisione specifica; spostare o ignorare un file non riscrive i commit. Non ruotare credenziali o pubblicare implicitamente.

## Decisioni da raccogliere

Se più opzioni non sono ricavabili dal codice o dalle fonti, fermati e usa Function Calling o Tool Use a scelta multipla (es. `ask_question`, `AskUserQuestion`): una decisione per domanda, scelta raccomandata come prima opzione con `(Recommended)`, opzioni atomiche e non numerate; scelta multipla quando le opzioni non si escludono.

- azione per ogni rilievo (correggere, ammettere con motivazione, rinviare);
- allowances e `binaryReviews` da registrare in policy locale (scelta multipla);
- conferma prima di qualsiasi intervento sulla storia o rotazione di credenziali.

Senza lo strumento, elenca opzioni numerate e attendi la risposta. Non richiedere di nuovo ciò che è già autorizzato nel perimetro del task.

## Verifiche

Distingui controlli eseguiti, contenuti binari non qualificati e copertura limitata. Non procedere con pubblicazione in presenza di rilievi non risolti o non valutati. Non dichiarare conformità generale sulla base di pattern testuali.

## Consegna

Rapporto di preparazione alla pubblicazione, rilievi, decisioni motivate e attività residue.

## Prompt vicini

- SEC02: Analizza minacce, confini di fiducia e scenari di abuso.
- OPS01: Prepara e verifica pacchetti e artefatti distribuibili.
- REP06: Prepara il README GitHub con informazioni e asset verificati.
- SEC07: Analizza i dati sensibili del diff prima del push.
- SEC08: Verifica se dati sensibili restano raggiungibili sul remoto GitHub.
- SEC09: Azzera storia e artefatti remoti GitHub dopo un’esposizione di dati.
- REP10: Allinea .gitignore e .gitkeep alla struttura e ai file reali.
