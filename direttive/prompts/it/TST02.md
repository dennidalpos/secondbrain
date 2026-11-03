# TST02 — Copri i percorsi utente con test end-to-end

> **Scope**: repo/area | **Modalità**: scrittura | **Cosa serve**: ambiente di test e flussi utente concordati | **Esempio d'uso**: `crea un test end-to-end per il ciclo di backup e ripristino`

## Scopo

Verificare un percorso completo attraverso i componenti reali coinvolti.

## Quando usarlo

Per flussi critici che i test dei singoli componenti non dimostrano.

## Input

Percorso, criteri di successo, ambiente di test e dati consentiti.

## Attività specifiche

Prepara un ambiente e dati isolati; guida il flusso attraverso le interfacce reali. Usa selettori e attese basati sul comportamento osservabile. Copri i guasti e la ripetizione del percorso dove pertinente.

## Verifiche

Verifica stato iniziale e finale, ripetibilità, pulizia dei dati creati e artefatti diagnostici utili. Non usare dati di produzione in modo implicito.

## Consegna

Scenari automatizzati, istruzioni di esecuzione e i limiti delle integrazioni effettivamente provate.

## Prompt vicini

- TST01: Aggiungi test unitari e di integrazione per i rischi pertinenti.
- TST05: Verifica il comportamento reale rispetto ai requisiti.
