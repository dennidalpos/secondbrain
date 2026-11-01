# SEC06 — Applica hardening a configurazioni, CI, container e accessi del repository

> **Scope**: repo/area | **Modalità**: scrittura | **Cosa serve**: configurazioni, workflow di CI, container e impostazioni del repository | **Esempio d'uso**: `sb prompt SEC06: hardening dei workflow GitHub Actions e dei container`

## Scopo

Ridurre la superficie d’attacco del repository e della sua catena di build e rilascio con configurazioni verificabili e privilegio minimo.

## Quando usarlo

Prima di rendere pubblico un repository, prima di una release, dopo un incidente e periodicamente.

## Input

Configurazioni, workflow di CI, Dockerfile e infrastruttura come codice, impostazioni del repository, permessi e segreti usati.

## Attività specifiche

Verifica i permessi minimi dei workflow (`permissions`), le azioni di terzi fissate per hash di commit, i trigger rischiosi come `pull_request_target`, l’uso dei segreti, le immagini base e l’utente non privilegiato nei container, la protezione dei rami, le revisioni obbligatorie, la firma di commit e tag, il secret scanning con push protection, i lock delle dipendenze e le impostazioni di sicurezza dei framework. Prima di modificare mostra la differenza e l’impatto operativo. Le impostazioni remote (protezione dei rami, secret scanning) si propongono con i comandi e si applicano solo con autorizzazione esplicita. Non modificare impostazioni di sistema o di sicurezza della postazione.

## Decisioni da raccogliere

Se più opzioni non sono ricavabili dal codice o dalle fonti, fermati e usa Function Calling o Tool Use a scelta multipla (es. `ask_question`, `AskUserQuestion`): una decisione per domanda, scelta raccomandata come prima opzione con `(Recommended)`, opzioni atomiche e non numerate; scelta multipla quando le opzioni non si escludono.
- superfici da irrobustire (scelta multipla: CI, container, rami, segreti);
- applicare le modifiche o solo proporle.

Senza lo strumento, elenca opzioni numerate e attendi la risposta. Non richiedere di nuovo ciò che è già autorizzato nel perimetro del task.

## Verifiche

Esegui pipeline e controlli locali pertinenti dopo le modifiche e verifica che nessuna correzione blocchi il lavoro legittimo. Distingui il rischio effettivo dalle raccomandazioni generiche e non dichiarare conformità a uno standard senza controlli puntuali.

## Consegna

Misure applicate o proposte con prova, rischio residuo e passi manuali.

## Prompt vicini

- SEC04: Cerca credenziali esposte e verifica la validazione degli input.
- OPS02: Configura pipeline, container e infrastruttura come codice.
- SEC03: Correggi vulnerabilità e rafforza le difese interessate.
