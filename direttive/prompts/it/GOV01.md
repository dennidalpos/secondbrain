# GOV01 — Verifica le licenze open source, la conformità dei file e le intestazioni SPDX

> **Scope**: repo | **Modalità**: verifica | **Cosa serve**: albero dei sorgenti e file di licenza | **Esempio d'uso**: `verifica la licenza MIT e che le intestazioni SPDX corrispondano`

## Scopo

Applicare e verificare la licenza software del repository e la conformità degli identificatori SPDX.

## Quando usarlo

All'inizializzazione di un repository pubblico, prima di un rilascio o durante l'audit legale del progetto.

## Input

File LICENSE, sorgenti distribuiti, manifest dei pacchetti e informazioni sul copyright.

## Attività specifiche

Verifica che il file LICENSE sia conforme allo standard scelto (per esempio MIT) e si trovi nella radice del repository. Inserisci o convalida le intestazioni SPDX-License-Identifier nei sorgenti distribuiti.

Verifica che l'avviso di copyright riporti l'anno corrente e l'autore legittimo. Assicurati che non ci siano clausole in conflitto o licenze incompatibili tra i moduli del progetto.

## Verifiche

Assicurati che il testo di LICENSE sia integro e non alterato rispetto al testo ufficiale SPDX. Verifica che tutti i componenti pubblici riportino l'attribuzione corretta.

## Consegna

File LICENSE convalidato, rapporto di conformità delle intestazioni SPDX e una dichiarazione di compatibilità legale per il rilascio.

## Prompt vicini

- GOV02: Analizza le dipendenze di terze parti e compila il registro CREDITS.
- SEC07: Controlla diff, repository e cronologia per dati sensibili prima di pubblicare.
- AUD04: Verifica le dipendenze: obsolete, vulnerabili, inutilizzate e licenze.
