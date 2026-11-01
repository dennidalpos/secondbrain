# OPS03 — Aggiungi log, metriche e diagnostica utili al problema

> **Scope**: repo/area/file | **Modalità**: scrittura | **Cosa serve**: flussi critici da osservare e destinazione dei log | **Esempio d'uso**: `sb prompt OPS03: aggiungi logging strutturato json`

## Scopo

Rendere osservabile un comportamento senza esporre dati sensibili.

## Quando usarlo

Per errori difficili da ricostruire o assenza di segnali operativi utili.

## Input

Domanda diagnostica, flusso, segnali esistenti e vincoli sui dati.

## Attività specifiche

Scegli eventi, identificatori di correlazione e misure che rispondono alla domanda. Evita segreti, payload personali e cardinalità incontrollata. Integra strumenti esistenti senza imporre un fornitore.

## Verifiche

Genera scenari di successo e fallimento; verifica utilità, redazione e costo dei segnali. Non collegare sistemi o modificare monitor di produzione implicitamente.

## Consegna

Segnali aggiunti, esempi sanitizzati, prove e modo di usarli per la diagnosi.

## Prompt vicini

- DEV02: Riproduci un difetto e correggine la causa.
- TST06: Misura e migliora prestazioni e consumo di risorse.
