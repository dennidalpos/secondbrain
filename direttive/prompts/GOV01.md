# GOV01 — Applicazione e verifica della licenza d'uso e conformità SPDX

> **Scope**: repo | **Modalità**: verifica | **Cosa serve**: file LICENSE, header dei sorgenti e inventory | **Esempio d'uso**: `sb prompt GOV01: verifica licenza mit e corrispondenza intestazioni spdx`

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
- GOV02: Analisi delle dipendenze terze parti e compilazione dei credits.
