# REP01 — Completa il prossimo task eseguibile del repository aperto

> **Scope**: repo | **Modalità**: scrittura | **Cosa serve**: tracker.json verificato e repository aperto | **Esempio d'uso**: `sb prompt REP01: esegui il prossimo task autonomo prioritario`

## Scopo

Portare a completamento una sola attività concreta del tracker autorevole. Per elencare le attività usa MEM04, per individuare residui non tracciati nel codice REP08.

## Quando usarlo

Quando viene richiesto di avanzare il lavoro già registrato.

## Input

Repository aperto e fonte del tracker risolta; eventuale preferenza sul task.

## Attività specifiche

Valuta priorità, dipendenze, stato e criteri reali senza presumere schema. Seleziona un task eseguibile del repository corrente, implementalo e verifica l’esito. Elenca i task con `knowledge.ps1 -Tasks -ReadyOnly` dal checkout (o `get_ready_tasks`), che risolvono il repository in lavoro; la vista globale (`-All`, `all=true`) è solo informativa. Rifiuta i task di altri repository, anche se autonomous: SecondBrain è un perimetro singolo e le scritture sul tracker restano nel repository in lavoro.

## Verifiche

Chiudi solo criteri dimostrati; conserva parziali e bloccati con motivo. Non considerare una voce del tracker come autorizzazione indipendente dalla richiesta.

## Consegna

Task scelto, risultato, prove e aggiornamento secondo schema e storico esistenti; motivo se nessun task è eseguibile.

## Prompt vicini

- PRG04: Prepara un piano per fasi con dipendenze e verifiche.
- DEV01: Implementa una funzionalità con verifiche pertinenti.
- REP08: Ispeziona il repo, individua task residui e incrocia memorie e codice reale.
- MEM04: Elenca e descrivi le attività del tracker e i problemi che risolvono.
