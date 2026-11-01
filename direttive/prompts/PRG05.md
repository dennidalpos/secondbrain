# PRG05 — Crea lo scaffolding di nuovi moduli con struttura, configurazione e test

> **Scope**: repo/area | **Modalità**: scrittura | **Cosa serve**: perimetro architetturale e dipendenze concordate | **Esempio d'uso**: `sb prompt PRG05: definisci scaffolding del nuovo modulo`

## Scopo

Definire l'ossatura iniziale di un nuovo modulo, componente o servizio seguendo le convenzioni del repository.

## Quando usarlo

All'avvio di un nuovo componente o servizio. Per riorganizzare codice esistente usa PRG06 (piano di refactoring) e DEV03 (esecuzione).

## Input

Albero delle cartelle, manifest di progetto, invarianti architetturali e requisiti del nuovo modulo.

## Attività specifiche

Analizza i confini dei moduli e le dipendenze correnti. Crea la struttura delle cartelle, i file di configurazione, i manifest e i test skeleton seguendo le convenzioni del repository, senza introdurre dipendenze non concordate e senza sovrascrivere file esistenti.

## Verifiche

Verifica che la separazione delle responsabilità sia rispettata, che lo scheletro si costruisca e che i test skeleton vengano eseguiti.

## Consegna

Struttura del progetto creata, file generati e verifiche eseguite con i limiti rimasti.

## Prompt vicini

- PRG02: Confronta soluzioni architetturali e motiva una decisione.
- PRG04: Prepara un piano per fasi con dipendenze e verifiche.
- PRG06: Pianifica un refactoring architetturale a fasi con verifiche e rollback.
