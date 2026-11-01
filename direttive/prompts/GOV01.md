# GOV01 — Verifica licenze open source, conformità dei file e header SPDX

> **Scope**: repo | **Modalità**: verifica | **Cosa serve**: albero sorgenti e file di licenza | **Esempio d'uso**: `sb prompt GOV01: verifica licenza mit e corrispondenza intestazioni spdx`

## Scopo

Applicare e verificare la licenza software del repository e la conformità degli identificatori SPDX.

## Quando usarlo

All'inizializzazione di un repository pubblico, prima di un rilascio o durante l'audit legale del progetto.

## Input

File LICENSE, sorgenti distribuiti, manifest di pacchetto e informazioni di copyright.

## Attività specifiche

Verifica la presenza del file LICENSE conforme allo standard prescelto (es. MIT) nella radice del repository. Inserisci o convalida gli header con identificatore SPDX-License-Identifier nei sorgenti distribuiti.

Verifica che l'intestazione di copyright indichi l'anno corrente e l'autore legittimo. Accerta che non vi siano clausole discordanti o licenze non compatibili tra i moduli del progetto.

## Verifiche

Accerta che il testo di LICENSE sia integro e non alterato rispetto al testo ufficiale SPDX. Controlla che tutti i componenti pubblici rechino l'attribuzione corretta.

## Consegna

File LICENSE validato, report di conformità degli header SPDX e attestazione di compatibilità legale per il rilascio.

## Prompt vicini

- REP05: Verifica contenuti e cronologia prima della pubblicazione.
- GOV02: Scansiona dipendenze esterne e compila il registro CREDITS con licenze terze.
- AUD04: Audita dipendenze: obsolete, vulnerabili, inutilizzate e licenze.
