# Registro delle modifiche

Formato [Keep a Changelog](https://keepachangelog.com/it-IT/1.1.0/). La numerazione segue il file `VERSION`. Questo registro cambia solo quando accetti un cambio di versione: vedi [Cambiare versione](docs/uso-quotidiano.md).

> Versione corrente: **1.0.0**, numerazione reimpostata il 2026-11-04 con le funzionalità attuali conservate. Le sezioni seguenti mantengono la cronologia dei rilasci precedenti.

## [Non rilasciato]

## [1.2.0] - 2026-11-02

### Aggiunto

- `MEM05`: regola unica per creare, aggiornare, archiviare e ripristinare progetti, aree e risorse del PARA; `para.ps1 -NewResource` e `-SetStatus`.
- `cleanup.ps1 -RuntimeReport`: indice leggibile di `.runtime` (opzionale `.runtime/INDEX.md`) e convenzione `<categoria>-<yyyyMMdd>-<slug>` per le nuove cartelle degli agent.
- `trace.ps1`: traccia di fine turno (hook Stop di Claude Code, solo metadati) e avviso `compaction-advised` in `secondbrain.ps1 -Check`.

### Modificato

- Direttive comuni 1.2: rimando a MEM05, nomi in `.runtime`, proposta di SYS05 alla chiusura del task; il contesto iniziale si carica con `knowledge.ps1 -Startup`, non con `prompts.ps1 -Context`.
- Il tetto di 20.000 caratteri del primo caricamento ha una fonte unica (`Get-SBSlimStartupBudget`).

## [1.1.0] - 2026-11-01

### Modificato

- Direttive comuni 1.1: ogni decisione durevole è una riga «Decisione: … — Motivo: …» in `memory.md` (nessun file ADR separato) e il cambio di versione accettato si registra nel `CHANGELOG.md`.
- `SYS11`: il ritiro predefinito di un prompt non usa `deprecations`, riservate a eliminazione e rinomina.
- Il modello di postazione rimanda a REP02 per la preparazione del README (REP06 è fuso in REP02).

## [1.0.0] - 2026-11-01

### Aggiunto

- Memoria, contesto e task per ogni progetto, con caricamento a strati entro 20.000 caratteri al primo avvio.
- Catalogo di 80 prompt in 13 aree, composti secondo CO-STAR.
- Server MCP in sola lettura per Claude, Codex e Antigravity.
- Controllo di pubblicabilità (REP05) su file, indice e storia.
- Backup e ripristino di ogni file sostituito.
- README e guide in `docs/`, con riferimento tecnico in `docs/riferimento/`.
