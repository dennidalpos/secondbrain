# DEV02 — Riproduci un difetto e correggine la causa

> **Scope**: repo/area/file | **Modalità**: scrittura | **Cosa serve**: riproduzione del difetto e log di errore | **Esempio d'uso**: `sb prompt DEV02: correggi errore di parsing per percorsi con spazi`

## Scopo

Eliminare la causa di un comportamento errato e prevenirne la ricomparsa.

## Quando usarlo

Per un difetto applicativo con sintomo o risultato atteso identificabile.

## Input

Riproduzione, errori, log, ambiente e differenza tra atteso e osservato.

## Attività specifiche

Ricostruisci il flusso e cerca una riproduzione minima. Formula e verifica ipotesi; correggi la causa e controlla ricorrenze della stessa origine. Se non riproducibile, separa diagnosi statica e prove.

## Verifiche

Dimostra il prima/dopo quando possibile e aggiungi una regressione significativa. Non modificare aspettative dei test per nascondere il difetto.

## Consegna

Causa, correzione, riproduzione e verifiche con i limiti rimasti.

## Prompt vicini

- TST03: Individua e correggi test instabili o non deterministici.
- TST04: Diagnostica e correggi errori di build e test nella CI.
