# DEV02 — Riproduci un difetto e correggine la causa

> **Scope**: repo/area/file | **Modalità**: scrittura | **Cosa serve**: segnalazione o comportamento atteso e osservato | **Esempio d'uso**: `correggi l'errore di parsing per i percorsi contenenti spazi`

## Scopo

Rimuovere la causa di un comportamento errato e impedirne il ritorno.

## Quando usarlo

Per un difetto applicativo con un sintomo o un risultato atteso identificabile.

## Input

Riproduzione, errori, log, ambiente e la differenza tra atteso e osservato.

## Attività specifiche

Ricostruisci il flusso e cerca una riproduzione minima. Formula e verifica ipotesi; correggi la causa e cerca ricorrenze della stessa origine. Se non è riproducibile, separa la diagnosi statica dalle evidenze.

## Verifiche

Mostra prima e dopo quando possibile e aggiungi un test di regressione significativo. Non cambiare le aspettative dei test per nascondere il difetto.

## Consegna

Causa, correzione, riproduzione e controlli, con i limiti residui.

## Prompt vicini

- TST03: Trova e correggi i test instabili o non deterministici.
- TST04: Diagnostica e correggi i fallimenti di build e test in CI.
- COM05: Analizza log e incidenti per trovare la causa radice, senza toccare il codice.
- OPS06: Prepara hotfix e rollback di un rilascio con verifica e comunicazione.
