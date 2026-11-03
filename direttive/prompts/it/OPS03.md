# OPS03 — Aggiungi log, metriche e diagnostica utili al problema

> **Scope**: repo/area/file | **Modalità**: scrittura | **Cosa serve**: scenario da monitorare e standard di logging | **Esempio d'uso**: `aggiungi il logging JSON strutturato`

## Scopo

Rendere osservabile un comportamento senza esporre dati sensibili.

## Quando usarlo

Per errori difficili da ricostruire o quando mancano segnali operativi utili.

## Input

Domanda diagnostica, flusso, segnali esistenti e vincoli sui dati.

## Attività specifiche

Scegli eventi, identificatori di correlazione e misure che rispondono alla domanda. Evita segreti, payload personali e cardinalità non controllata. Integra gli strumenti esistenti senza imporre un fornitore.

## Verifiche

Genera scenari di successo e di errore; verifica l'utilità, l'oscuramento e il costo dei segnali. Non collegare sistemi né modificare monitor di produzione in modo implicito.

## Consegna

Segnali aggiunti, esempi sanificati, evidenze e come usarli per la diagnosi.

## Prompt vicini

- DEV02: Riproduci un difetto e correggine la causa.
- TST06: Misura e ottimizza prestazioni e risorse: un collo di bottiglia o molti moduli.
- COM05: Analizza log e incidenti per trovare la causa radice, senza toccare il codice.
