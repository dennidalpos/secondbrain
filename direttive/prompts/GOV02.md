# GOV02 — Analisi delle dipendenze terze parti e compilazione dei credits

> **Scope**: repo | **Modalità**: scrittura | **Cosa serve**: manifest dei pacchetti (npm, nuget, pip) e lockfile | **Esempio d'uso**: `sb prompt GOV02: scansiona dipendenze terze e compila file CREDITS.md`

## Scopo

Censire le librerie esterne utilizzate e compilare il documento CREDITS.md con licenze e attribuzioni.

## Quando usarlo

Prima del rilascio open source del repository o all'integrazione di nuove dipendenze terze parti.

## Input

Manifest delle dipendenze, lockfile, avvisi di licenza di pacchetti terzi e albero dei moduli.

## Attività specifiche

Analizza le dipendenze dirette e transitive del repository. Raccogli per ciascuna il nome del componente, versione, autori, licenza di distribuzione e URL del repository o della documentazione ufficiale.

Compila o aggiorna il file CREDITS.md nella radice del repository, strutturando le attribuzioni per ambito o per linguaggio e allegando i testi o i link alle licenze originali richieste dai termini d'uso.

## Verifiche

Verifica che tutte le dipendenze esterne siano censite senza omissioni. Accerta che non siano presenti componenti con licenze incompatibili con la licenza del progetto.

## Consegna

File CREDITS.md allineato, matrice di compatibilità delle dipendenze terze e riepilogo delle attribuzioni verificate.

## Prompt vicini

- REP06: Prepara il README GitHub con informazioni e asset verificati.
- GOV01: Applicazione e verifica della licenza d'uso e conformità SPDX.
