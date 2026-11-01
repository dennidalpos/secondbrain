# TST02 — Copri percorsi utente con test end-to-end

> **Scope**: repo/area | **Modalità**: scrittura | **Cosa serve**: ambiente di test e flussi utente concordati | **Esempio d'uso**: `sb prompt TST02: crea test end-to-end per il ciclo di backup e ripristino`

## Scopo

Verificare un percorso completo attraverso i componenti reali interessati.

## Quando usarlo

Per flussi critici che i test dei singoli componenti non dimostrano.

## Input

Percorso, criteri di successo, ambiente di test e dati consentiti.

## Attività specifiche

Prepara ambiente e dati isolati; guida il flusso attraverso interfacce reali. Usa selettori e attese basati su comportamento osservabile. Copri fallimenti e ripetizione del percorso dove pertinenti.

## Verifiche

Verifica stato iniziale e finale, ripetibilità, pulizia dei dati creati e artefatti diagnostici utili. Non usare dati di produzione implicitamente.

## Consegna

Scenari automatizzati, istruzioni di esecuzione e limiti delle integrazioni effettivamente provate.

## Prompt vicini

- TST01: Aggiungi test unitari e di integrazione sui rischi rilevanti.
- TST05: Verifica il comportamento reale rispetto ai requisiti.
