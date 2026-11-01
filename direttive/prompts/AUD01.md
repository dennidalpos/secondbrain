# AUD01 — Esegui un audit completo del repository con un unico rapporto

> **Scope**: repo/area | **Modalità**: lettura | **Cosa serve**: lettura del repository, del dossier e degli strumenti di misura | **Esempio d'uso**: `sb prompt AUD01: audit completo del repository prima della release`

## Scopo

Valutare in un’unica passata architettura, qualità, sicurezza, dipendenze, prestazioni, test e documentazione, con rilievi verificati e priorità.

## Quando usarlo

Prima di una release, di un subentro o di una pianificazione, quando serve una fotografia complessiva e non un singolo controllo.

## Input

Perimetro e profondità richiesti, dossier del repository (contesto, memoria, tracker) e formato desiderato del rapporto (vedi AUD06).

## Attività specifiche

Orchestra senza duplicare le schede specializzate: carica AUD02 (metriche), AUD03 (architettura e debito), AUD04 (dipendenze), AUD05 (prestazioni), SEC01, SEC04 e SEC05 (sicurezza e dati sensibili), GOV01 (licenze), DEV08 (leggibilità) e TST05 (comportamento) solo per le dimensioni incluse nel perimetro. Esegui in sola lettura e, se disponibili, con subagent per le dimensioni indipendenti. Unifica i rilievi, elimina i duplicati e confrontali con il tracker per non ridefinire task già censiti.

## Decisioni da raccogliere

Se più opzioni non sono ricavabili dal codice o dalle fonti, fermati e usa Function Calling o Tool Use a scelta multipla (es. `ask_question`, `AskUserQuestion`): una decisione per domanda, scelta raccomandata come prima opzione con `(Recommended)`, opzioni atomiche e non numerate; scelta multipla quando le opzioni non si escludono.
- dimensioni da includere (scelta multipla);
- profondità: rapida o approfondita;
- formato del rapporto, se da esportare con AUD06.

Senza lo strumento, elenca opzioni numerate e attendi la risposta. Non richiedere di nuovo ciò che è già autorizzato nel perimetro del task.

## Verifiche

Ogni rilievo ha prova (file e riga, comando o misura) e gravità; distingui fatti da ipotesi, dichiara le dimensioni non coperte e i controlli non eseguibili. Non modificare file, tracker o memorie.

## Consegna

Rapporto unico con sintesi, rilievi per dimensione ordinati per gravità, lacune di copertura e task proposti da censire; per salvarlo o esportarlo usa AUD06.

## Prompt vicini

- AUD02: Misura il repository con metriche riproducibili e individua i punti critici.
- AUD03: Audita architettura e debito tecnico non ancora tracciato.
- AUD04: Audita dipendenze: obsolete, vulnerabili, inutilizzate e licenze.
- AUD05: Audita le prestazioni e individua i percorsi critici senza modificare il codice.
- AUD06: Esporta rapporti e metriche nel formato scelto dall’utente.
