# MEM01 — Allinea istruzioni locali, contesto, memoria e tracker

> **Scope**: repo/area | **Modalità**: scrittura | **Cosa serve**: decisioni o modifiche recenti non registrate | **Esempio d'uso**: `sb prompt MEM01: allinea context.md e memory.md dopo completamento task`

## Scopo

Rendere le fonti operative coerenti con il repository verificato.

## Quando usarlo

Per riallineamento documentale e delle informazioni durevoli del prodotto.

## Input

Repository, istruzioni applicabili, dossier corrente e tracker autorevole.

## Attività specifiche

Confronta codice, manifest e comandi con i documenti. Registra decisioni/gotcha in memoria, ogni decisione durevole in una riga «Decisione: … — Motivo: …», architettura/stato nel contesto e attività nel tracker esistente. Modifica istruzioni locali fuori dai blocchi gestiti; proponi separatamente nuove regole comuni. Applica tassativamente la regola di sintesi minima: sintetizza memorie, contesti e dossier al minimo indispensabile registrando soltanto le operazioni chiave effettuate.

Aggiorna il TOC index.md e mantieni il pacchetto iniziale snello entro 20.000 caratteri (tetto del solo primo caricamento) senza troncare. Carica tracker e storico in modo selettivo; per la sintesi revisionata usa SYS05. Tutti gli output di lavoro, incluse build/cache dove supportato e verificato, risiedono in SecondBrain/.runtime.

## Decisioni da raccogliere

- documenti e fonti da allineare (scelta multipla: contesto, memoria, tracker, istruzioni locali);
- novità da registrare come decisione, gotcha o residuo;
- compattazione con SYS05 quando il pacchetto supera il budget.

## Verifiche

Verifica veridicità, link, schema e storico; evita cronache ridondanti. Non eseguire task applicativi dalla manutenzione centrale. Dopo modifiche pertinenti esegui Sync e Check con sessione di scrittura.

## Consegna

Informazioni riconciliate, evidenze e discrepanze residue senza dichiarare verificato ciò che è soltanto documentato.

## Prompt vicini

- MEM03: Chiudi la sessione: memorie, tracker, handoff e richiesta di commit e push.
- MEM04: Elenca e descrivi le attività del tracker e i problemi che risolvono.
- DOC01: Write guides and READMEs consistent with the real product.
- SYS11: Aggiungi, modifica o rimuovi un prompt del catalogo centralizzato.
