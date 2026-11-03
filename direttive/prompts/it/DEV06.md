# DEV06 — Configura ed esegui linter, formattatori e analisi statica

> **Scope**: repo/area/file | **Modalità**: scrittura | **Cosa serve**: configurazione del linter e perimetro dell'analisi | **Esempio d'uso**: `configura il linter ed esegui l'analisi statica`

## Scopo

Configurare e applicare linter, formattatori e strumenti di analisi statica per garantire coerenza di stile, qualità e assenza di pattern rischiosi nel codice.

## Quando usarlo

Prima di aprire una pull request, durante la modernizzazione del codice o per uniformare le regole di linting del progetto.

## Input

Manifest del progetto, configurazione attuale del linter (per esempio ESLint, Ruff, PSScriptAnalyzer), codice sorgente e suite di test.

## Attività specifiche

Configura i file di impostazioni del linter in linea con gli standard del progetto. Esegui la scansione e distingui errori critici, avvisi e preferenze di stile. Applica correzioni automatiche sicure solo dove non c'è rischio di alterare la semantica; per i rilievi complessi proponi modifiche mirate.

## Verifiche

Riesegui l'analisi statica per confermare zero violazioni o meno rilievi; esegui la suite di test del progetto per assicurarti che non ci siano regressioni funzionali.

## Consegna

Codice formattato e ripulito, configurazione del linter aggiornata e un rapporto conciso delle regole verificate.

## Prompt vicini

- DEV01: Implementa una funzionalità con i controlli pertinenti.
- TST04: Diagnostica e correggi i fallimenti di build e test in CI.
