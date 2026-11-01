# OPS04 — Prepara note di rilascio e verifiche di consegna

> **Scope**: repo | **Modalità**: scrittura | **Cosa serve**: changelog, commit recenti e tracker delle attivita | **Esempio d'uso**: `sb prompt OPS04: compila note di rilascio v1.1 da commit e tracker`

## Scopo

Descrivere una consegna e verificarne i prerequisiti.

## Quando usarlo

Quando una versione o un lotto è pronto per la revisione di rilascio.

## Input

Intervallo di modifiche, artefatti, destinatari e criteri di rilascio.

## Attività specifiche

Ricava cambiamenti da diff e prove, separando funzionalità, correzioni, incompatibilità e migrazioni. Prepara note, istruzioni e controlli di consegna coerenti con il progetto.

## Verifiche

Controlla che ogni affermazione abbia evidenze e che versione/artefatti coincidano. Evidenzia impedimenti; non pubblicare o distribuire implicitamente. Non cambiare il numero di versione senza chiedere: proponilo con scelta multipla; se l'utente accetta esegui il cambio ovunque serva, se rifiuta lascialo invariato.

## Consegna

Note di rilascio, stato dei controlli, rischi e passaggi operativi pendenti.

## Prompt vicini

- OPS01: Prepara e verifica pacchetti e artefatti distribuibili.
- MEM03: Prepara un passaggio di sessione con ripresa verificabile.
