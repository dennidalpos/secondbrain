# TST04 — Diagnostica e correggi errori di build e test nella CI

> **Scope**: repo/area/file | **Modalità**: scrittura | **Cosa serve**: definizione workflow ci e log del job fallito | **Esempio d'uso**: `sb prompt TST04: correggi fallimento del runner GitHub Actions su Windows`

## Scopo

Ripristinare il controllo fallito comprendendo la differenza tra CI e locale.

## Quando usarlo

Quando una pipeline fallisce o il fallimento dipende dal runner.

## Input

Job, commit, log completi pertinenti, runner, versioni, comandi e artefatti.

## Attività specifiche

Individua il primo errore causale e confronta checkout, toolchain, cache, permessi e variabili non segrete con l’ambiente locale. Riproduci il comando su fixture o ambiente compatibile; correggi codice o pipeline secondo le prove.

## Verifiche

Riesegui il controllo pertinente. Non eliminare gate, allargare permessi o marcare successo per aggirare il fallimento. Distingui verifica locale e nuovo run remoto.

## Consegna

Causa, differenza ambientale, correzione e stato verificato del job.

## Prompt vicini

- TST03: Individua e correggi test instabili o non deterministici.
- OPS02: Configura pipeline, container e infrastruttura come codice.
- DEV06: Configurazione ed esecuzione linter, formattatori e analisi statica.
