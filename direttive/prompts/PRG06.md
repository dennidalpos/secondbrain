# PRG06 — Pianifica un refactoring architetturale a fasi

> **Scope**: repo/area | **Modalità**: lettura | **Cosa serve**: modulo da riorganizzare, test esistenti e invarianti da preservare | **Esempio d'uso**: `sb prompt PRG06: pianifica il refactoring del modulo di sincronizzazione`

## Scopo

Impostare un piano di refactoring architetturale a fasi atomiche e verificabili che preservi contratti pubblici e comportamento esistente.

## Quando usarlo

Quando il debito tecnico o la complessità richiedono una riorganizzazione strutturale. Per un piano generico usa PRG04, per eseguire le modifiche DEV03, per un nuovo modulo PRG05.

## Input

Codice e confini dei moduli, dipendenze correnti, copertura dei test, invarianti architetturali e obiettivo della riorganizzazione.

## Attività specifiche

Mappa responsabilità, dipendenze e contratti pubblici. Individua i punti di rottura e dividi il lavoro in fasi atomiche, ciascuna con passi intermedi eseguibili, criteri di verifica, ordine delle dipendenze e rollback. Non modificare il codice e non aggiornare il tracker salvo richiesta esplicita.

## Decisioni da raccogliere

Se più opzioni non sono ricavabili dal codice, fermati e usa Function Calling o Tool Use a scelta multipla (es. `ask_question`, `AskUserQuestion`): una decisione per domanda, scelta raccomandata come prima opzione con `(Recommended)`.

- confine del refactoring e fasi da includere nel piano;
- compatibilità da preservare per i contratti pubblici.

Senza lo strumento, elenca opzioni numerate e attendi la risposta. Non richiedere di nuovo ciò che è già autorizzato nel perimetro del task.

## Verifiche

Controlla che ogni fase abbia un esito verificabile, che i contratti pubblici non vengano spezzati inavvertitamente e che la suite di test copra il comportamento da preservare.

## Consegna

Documento di piano per fasi con dipendenze, verifiche, rollback, punti di decisione concordati, assunzioni e limiti.

## Prompt vicini

- PRG04: Prepara un piano per fasi con dipendenze e verifiche.
- DEV03: Esegui un refactoring preservando contratti e comportamento.
- PRG05: Crea lo scaffolding di nuovi moduli con struttura, configurazione e test.
