# GOV02 — Analizza le dipendenze di terze parti e compila il registro CREDITS

> **Scope**: repo | **Modalità**: scrittura | **Cosa serve**: lock file delle dipendenze e licenze di terze parti | **Esempio d'uso**: `analizza le dipendenze di terze parti e compila CREDITS.md`

## Scopo

Elencare le librerie esterne in uso e compilare il documento CREDITS.md con licenze e attribuzioni.

## Quando usarlo

Prima del rilascio open source del repository o quando si aggiungono nuove dipendenze di terze parti.

## Input

Manifest delle dipendenze, lock file, avvisi di licenza dei pacchetti di terze parti e albero dei moduli.

## Attività specifiche

Analizza le dipendenze dirette e transitive del repository. Per ciascuna raccogli nome del componente, versione, autori, licenza di distribuzione e URL del repository o della documentazione ufficiale.

Compila o aggiorna CREDITS.md nella radice del repository, strutturando le attribuzioni per ambito o linguaggio e allegando i testi o i collegamenti alle licenze originali richiesti dai termini d'uso.

## Verifiche

Verifica che tutte le dipendenze esterne siano elencate senza omissioni. Assicurati che non ci siano componenti con licenze incompatibili con quella del progetto.

## Consegna

File CREDITS.md allineato, una matrice di compatibilità delle dipendenze di terze parti e un riepilogo delle attribuzioni verificate.

## Prompt vicini

- GOV01: Verifica le licenze open source, la conformità dei file e le intestazioni SPDX.
- DOC01: Scrivi guide e README coerenti con il prodotto reale.
