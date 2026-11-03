# TST04 — Diagnostica e correggi i fallimenti di build e test in CI

> **Scope**: repo/area/file | **Modalità**: scrittura | **Cosa serve**: log della CI e configurazione della pipeline | **Esempio d'uso**: `correggi il fallimento del runner GitHub Actions su Windows`

## Scopo

Ripristinare il controllo fallito capendo la differenza tra la CI e l'ambiente locale.

## Quando usarlo

Quando una pipeline fallisce o il fallimento dipende dal runner.

## Input

Job, commit, i log completi pertinenti, runner, versioni, comandi e artefatti.

## Attività specifiche

Individua il primo errore causale e confronta checkout, toolchain, cache, permessi e variabili non segrete con l'ambiente locale. Riproduci il comando su una fixture o su un ambiente compatibile; correggi il codice o la pipeline in base alle evidenze.

## Verifiche

Riesegui il controllo pertinente. Non rimuovere gate, non ampliare i permessi e non marcare il successo per aggirare il fallimento. Distingui la verifica locale da una nuova esecuzione remota.

## Consegna

Causa, differenza ambientale, correzione e lo stato verificato del job.

## Prompt vicini

- DEV06: Configura ed esegui linter, formattatori e analisi statica.
- OPS02: Configura pipeline, container e infrastruttura come codice.
- TST03: Trova e correggi i test instabili o non deterministici.
