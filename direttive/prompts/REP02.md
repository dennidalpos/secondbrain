# REP02 — Scrivi guide e README coerenti con il prodotto reale

> **Scope**: repo | **Modalità**: scrittura | **Cosa serve**: funzionalita osservate nel codice e documentazione corrente | **Esempio d'uso**: `sb prompt REP02: aggiorna guide e genera flussi mermaid`

## Scopo

Fornire documentazione operativa accurata ai destinatari indicati.

## Quando usarlo

Per guide utente/manutentore, onboarding o README da creare o aggiornare.

## Input

Destinatari, uso previsto, documenti esistenti e parti da documentare.

## Attività specifiche

Verifica comandi, configurazione e comportamento sui file reali. Scrivi istruzioni orientate al compito, esempi senza segreti e prerequisiti effettivi. Aggiorna la fonte curata anziché output generati.

Integra diagrammi di flusso e architetturali in formato Mermaid (`flowchart TD/LR`, `sequenceDiagram`, `stateDiagram-v2`, `classDiagram`) inseriti direttamente nel Markdown per rappresentare visivamente architettura dei moduli, sequenze di chiamata, cicli di vita o pipeline di dati osservate nel codice reale. Segui la sintassi Mermaid standard compatibile con GitHub e gli IDE (es. etichette quotate per caratteri speciali nei nodi, assenza di tag HTML non supportati).

Per la presentazione GitHub usa anche REP06 e screenshot reali REP07. Mantieni rapporti e dati personali in SecondBrain; le guide pubbliche non contengono percorsi o informazioni private.

## Verifiche

Verifica link, comandi e la corretta resa sintattica dei diagrammi Mermaid in ambiente compatibile; distingue esempi verificati da quelli illustrativi. Non riscrivere memoria o storico per una semplice guida.

## Consegna

Documenti aggiornati, diagrammi di flusso Mermaid verificati, destinatari coperti e verifiche con limiti.

## Prompt vicini

- REP03: Documenta API e contratti a partire dall’implementazione.
- MEM01: Allinea istruzioni locali, contesto, memoria e tracker.
