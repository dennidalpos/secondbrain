# OPS01 — Prepara e verifica pacchetti e artefatti distribuibili

> **Scope**: repo | **Modalità**: scrittura | **Cosa serve**: istruzioni di build e requisiti del pacchetto | **Esempio d'uso**: `costruisci un archivio zip deterministico e calcola il suo SHA-256`

## Scopo

Produrre l'artefatto richiesto dal progetto in modo verificabile.

## Quando usarlo

Per build, creazione di pacchetti, installer e preparazione locale di un rilascio.

## Input

Destinazione, versione richiesta, runtime, firma e comandi del progetto.

## Attività specifiche

Verifica manifest, toolchain e prerequisiti; esegui la build e il packaging previsti dal progetto. Conserva gli artefatti ufficiali e tieni separati cache e file temporanei. Non incrementare le versioni senza un motivo o una richiesta.

## Verifiche

Controlla contenuto, versione, dipendenze ed esegui uno smoke test in un ambiente adatto. Distingui un artefatto creato, installato e verificato.

## Consegna

Percorsi degli artefatti, versione, comandi e limiti; produrre il pacchetto non autorizza a pubblicarlo.

## Prompt vicini

- OPS02: Configura pipeline, container e infrastruttura come codice.
- OPS04: Prepara note di rilascio e controlli di consegna.
- OPS06: Prepara hotfix e rollback di un rilascio con verifica e comunicazione.
