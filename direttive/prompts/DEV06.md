# DEV06 — Configura ed esegui linter, formattatori e analisi statica del codice

> **Scope**: repo/area/file | **Modalità**: scrittura | **Cosa serve**: configurazione linter e perimetro di analisi | **Esempio d'uso**: `sb prompt DEV06: configura linter ed esegui analisi statica`

## Scopo

Configurare e applicare linter, formattatori e strumenti di analisi statica per garantire uniformità stilistica, qualità e assenza di pattern rischiosi nel codice.

## Quando usarlo

Prima di aprire pull request, durante la modernizzazione del codice o per standardizzare le regole di linting del progetto.

## Input

Manifest del progetto, configurazione corrente dei linter (es. PSScriptAnalyzer, ESLint, Ruff), codice sorgente e suite di test.

## Attività specifiche

Configura i file di impostazioni del linter nel rispetto degli standard del progetto. Esegui la scansione e distingui errori critici, avvisi e preferenze stilistiche. Applica correzioni automatiche sicure solo dove non vi è rischio di alterare la semantica; per i rilievi complessi proponi modifiche puntuali.

## Verifiche

Esegui nuovamente l'analisi statica per confermare zero violazioni o la riduzione dei rilievi; esegui la suite di test del progetto per assicurare assenza di regressioni funzionali.

## Consegna

Codice formattato e bonificato, configurazione linter aggiornata e rapporto sintetico delle regole verificate.

## Prompt vicini

- DEV01: Implementa una funzionalità con verifiche pertinenti.
- TST04: Diagnostica e correggi errori di build e test nella CI.
