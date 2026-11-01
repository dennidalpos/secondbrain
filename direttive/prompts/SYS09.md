# SYS09 — Esegui il backup compresso deterministico e verifica i digest SHA-256

> **Scope**: central | **Modalità**: scrittura | **Cosa serve**: configurazione attiva e root runtime di backup | **Esempio d'uso**: `sb prompt SYS09: esegui backup deterministico e valida il manifest sha-256`

## Scopo

Eseguire e validare il backup compresso deterministico dei dati locali di SecondBrain.

## Quando usarlo

Prima di modifiche architetturali, aggiornamenti delle direttive, migrazioni o al termine di sessioni rilevanti.

## Input

Albero PARA locale (01-projects/, 02-areas/, 03-resources/, 04-archives/), indici locali e .runtime/hosts.

## Attività specifiche

Invoca scripts/backup.ps1 per produrre un archivio compresso deterministico salvaguardato sotto .runtime/backups/. Genera il manifest con i digest crittografici SHA-256 di ciascun file incluso.

Esegui la convalida dell'archivio tramite scripts/backup.ps1 -Verify verificando l'integrità strutturale del file ZIP e la corrispondenza esatta di ogni hash calcolato.

## Verifiche

Verifica che l'archivio contenga tutti i dossier dichiarati e le configurazioni host. Accerta che file temporanei, build cache o socket non siano stati inclusi. Controlla che -Verify restituisca esito positivo.

## Consegna

Percorso dell'archivio generato, digest SHA-256 del pacchetto e dei contenuti, conteggio file protetti e riscontro di integrità.

## Prompt vicini

- SYS04: Controlla o allinea gli asset già gestiti della postazione.
- SYS06: Leggi memoria attiva, contesto e tracker del repository corrente.
