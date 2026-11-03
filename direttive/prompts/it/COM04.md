# COM04 — Valuta impatto, rischi e dipendenze di una modifica

> **Scope**: repo | **Modalità**: lettura | **Cosa serve**: modifica proposta o difetto da correggere | **Esempio d'uso**: `valuta l'impatto dell'isolamento dei log di runtime`

## Scopo

Stimare gli effetti di una modifica prima di realizzarla.

## Quando usarlo

Per modifiche trasversali, contratti condivisi o comportamenti poco documentati.

## Input

La modifica proposta, il suo perimetro e i vincoli da preservare.

## Attività specifiche

Cerca consumatori, dipendenze, dati persistiti, compatibilità e percorsi di errore. Distingui il codice da modificare, le integrazioni da verificare e i rischi di migrazione. Non estendere l'analisi ad altri repository senza autorizzazione.

## Verifiche

Collega ogni rischio a una dipendenza o a un comportamento concreto; segnala la copertura incompleta. Non modificare file.

## Consegna

Una matrice d'impatto concisa, i rischi, i controlli necessari e una stima qualitativa del lavoro.

## Prompt vicini

- PRG03: Progetta contratti API, modelli di dati e compatibilità.
- PRG04: Prepara un piano a fasi con dipendenze e controlli.
- AUD03: Verifica architettura e debito tecnico non ancora tracciati.
