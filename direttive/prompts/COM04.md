# COM04 — Valuta impatto, rischi e dipendenze di una modifica

> **Scope**: repo | **Modalità**: lettura | **Cosa serve**: proposta di modifica e punti di contatto nel codice | **Esempio d'uso**: `sb prompt COM04: valuta impatto dell isolamento dei log runtime`

## Scopo

Stimare gli effetti di una modifica prima dell’implementazione.

## Quando usarlo

Per interventi trasversali, contratti condivisi o comportamenti poco documentati.

## Input

Modifica proposta, perimetro e vincoli da preservare.

## Attività specifiche

Ricerca consumatori, dipendenze, dati persistiti, compatibilità e percorsi di errore. Distingui codice da cambiare, integrazioni da verificare e rischi di migrazione. Non estendere l’analisi ad altri repository senza autorizzazione.

## Verifiche

Collega ogni rischio a una dipendenza o a un comportamento concreto; segnala copertura incompleta. Non modificare file.

## Consegna

Matrice sintetica di impatto, rischi, controlli necessari e stima qualitativa dell’intervento.

## Prompt vicini

- PRG03: Progetta contratti API, modelli dati e compatibilità.
- PRG04: Prepara un piano per fasi con dipendenze e verifiche.
