# OPS01 — Prepara e verifica pacchetti e artefatti distribuibili

> **Scope**: repo | **Modalità**: scrittura | **Cosa serve**: albero dei file compilati e script di packaging | **Esempio d'uso**: `sb prompt OPS01: prepara archivio zip deterministico e calcola sha-256`

## Scopo

Produrre l’artefatto previsto dal progetto in modo verificabile.

## Quando usarlo

Per build, packaging, installer e preparazione locale di un rilascio.

## Input

Destinazione, versione richiesta, runtime, firma e comandi del progetto.

## Attività specifiche

Verifica manifest, toolchain e prerequisiti; esegui build e packaging previsti. Conserva artefatti ufficiali e separa cache e temporanei. Non incrementare versioni senza motivazione o richiesta.

## Verifiche

Controlla contenuti, versione, dipendenze e smoke test in ambiente appropriato. Distingui artefatto creato, installato e verificato.

## Consegna

Percorsi degli artefatti, versione, comandi e limiti; produrre il pacchetto non autorizza pubblicarlo.

## Prompt vicini

- OPS02: Configura pipeline, container e infrastruttura come codice.
- OPS04: Prepara note di rilascio e verifiche di consegna.
