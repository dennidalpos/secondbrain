# PRG05 — Crea l'impalcatura di nuovi moduli con struttura, configurazione e test

> **Scope**: repo/area | **Modalità**: scrittura | **Cosa serve**: perimetro architetturale concordato e dipendenze | **Esempio d'uso**: `definisci l'impalcatura del nuovo modulo`

## Scopo

Definire lo scheletro iniziale di un nuovo modulo, componente o servizio seguendo le convenzioni del repository.

## Quando usarlo

Quando si avvia un nuovo componente o servizio. Per riorganizzare codice esistente usa PRG06 (piano di refactoring) e DEV03 (esecuzione).

## Input

Albero delle cartelle, manifest del progetto, invarianti architetturali e requisiti del nuovo modulo.

## Attività specifiche

Analizza i confini del modulo e le dipendenze attuali. Crea la struttura delle cartelle, i file di configurazione, i manifest e i test scheletro seguendo le convenzioni del repository, senza introdurre dipendenze non concordate e senza sovrascrivere file esistenti.

## Verifiche

Verifica che la separazione delle responsabilità sia rispettata, che lo scheletro compili e che i test scheletro vengano eseguiti.

## Consegna

Struttura del progetto creata, file generati e controlli eseguiti, con i limiti che restano.

## Prompt vicini

- PRG02: Confronta le opzioni architetturali e motiva una decisione.
- PRG04: Prepara un piano a fasi con dipendenze e controlli.
- PRG06: Pianifica un refactoring architetturale a fasi con controlli e rollback.
