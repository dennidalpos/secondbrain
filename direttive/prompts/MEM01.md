# MEM01 — Allinea istruzioni locali, contesto, memoria e tracker

> **Scope**: repo/area | **Modalità**: scrittura | **Cosa serve**: modifiche effettuate e dossier del repository | **Esempio d'uso**: `sb prompt MEM01: allinea context.md e memory.md dopo completamento task`

## Scopo

Rendere le fonti operative coerenti con il repository verificato.

## Quando usarlo

Per riallineamento documentale e delle informazioni durevoli del prodotto.

## Input

Repository, istruzioni applicabili, dossier corrente e tracker autorevole.

## Attività specifiche

Confronta codice, manifest e comandi con i documenti. Registra decisioni/gotcha in memoria, architettura/stato nel contesto e attività nel tracker esistente. Modifica istruzioni locali fuori dai blocchi gestiti; proponi separatamente nuove regole comuni. Applica tassativamente la regola di sintesi minima: sintetizza memorie, contesti e dossier al minimo indispensabile registrando soltanto le operazioni chiave effettuate.

Aggiorna il TOC index.md e mantieni il pacchetto iniziale entro 50.000 caratteri senza troncare. Carica tracker e storico in modo selettivo; per la sintesi revisionata usa SYS05. Tutti gli output di lavoro, incluse build/cache dove supportato e verificato, risiedono in SecondBrain/.runtime.

## Decisioni da raccogliere

Se più opzioni non sono ricavabili dal codice o dalle fonti, fermati e usa Function Calling o Tool Use a scelta multipla (es. `ask_question`, `AskUserQuestion`): una decisione per domanda, scelta raccomandata come prima opzione con `(Recommended)`, opzioni atomiche e non numerate; scelta multipla quando le opzioni non si escludono.

- documenti e fonti da allineare (scelta multipla: contesto, memoria, tracker, istruzioni locali);
- novità da registrare come decisione, gotcha o residuo;
- compattazione con SYS05 quando il pacchetto supera il budget.

Senza lo strumento, elenca opzioni numerate e attendi la risposta. Non richiedere di nuovo ciò che è già autorizzato nel perimetro del task.

## Verifiche

Verifica veridicità, link, schema e storico; evita cronache ridondanti. Non eseguire task applicativi dalla manutenzione centrale. Dopo modifiche pertinenti esegui Sync e Check con sessione di scrittura.

## Consegna

Informazioni riconciliate, evidenze e discrepanze residue senza dichiarare verificato ciò che è soltanto documentato.

## Prompt vicini

- REP02: Scrivi guide e README coerenti con il prodotto reale.
- MEM03: Prepara un passaggio di sessione con ripresa verificabile.
- MEM04: Elenca e descrivi le attività del tracker e i problemi che risolvono.
- SYS11: Aggiungi, modifica o rimuovi un prompt del catalogo centralizzato.
