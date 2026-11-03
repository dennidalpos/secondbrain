# OPS04 — Prepara note di rilascio e controlli di consegna

> **Scope**: repo | **Modalità**: scrittura | **Cosa serve**: commit, segnalazioni o task completati dal rilascio precedente | **Esempio d'uso**: `compila le note di rilascio della v1.1 da commit e segnalazioni`

## Scopo

Descrivere una consegna e verificarne i prerequisiti.

## Quando usarlo

Quando una versione o un lotto è pronto per la revisione di rilascio.

## Input

Intervallo di modifiche, artefatti, destinatari e criteri di rilascio.

## Attività specifiche

Ricava le modifiche da diff ed evidenze, separando funzionalità, correzioni, modifiche incompatibili e migrazioni. Prepara note, istruzioni e controlli di consegna coerenti con il progetto.

## Verifiche

Verifica che ogni affermazione abbia un'evidenza e che versione e artefatti corrispondano. Evidenzia i blocchi; non pubblicare né distribuire in modo implicito. Non cambiare il numero di versione senza chiedere: proponilo come scelta multipla; se l'utente accetta, esegui il cambio ovunque serva, se rifiuta lascialo invariato.

## Consegna

Note di rilascio, stato dei controlli, rischi e passi operativi in sospeso.

## Prompt vicini

- OPS01: Prepara e verifica pacchetti e artefatti distribuibili.
- OPS06: Prepara hotfix e rollback di un rilascio con verifica e comunicazione.
