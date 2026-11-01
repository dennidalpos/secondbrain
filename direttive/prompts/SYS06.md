# SYS06 — Leggi memoria attiva, contesto e tracker del repository corrente

> **Scope**: repo | **Modalità**: lettura | **Cosa serve**: checkout del repository aperto | **Esempio d'uso**: `sb prompt SYS06: carica contesto e memoria del repository nel budget`

## Scopo

Caricare memoria attiva, contesto sintetico e tracker del repository nel budget di contesto. È il caricamento iniziale: per elencare nel dettaglio le attività usa MEM04, per incrociarle con il codice reale REP08.

## Quando usarlo

All'avvio di una sessione o prima di pianificare ed eseguire modifiche nel repository corrente.

## Input

Repository locale, file AGENTS.md, dossier del repository con context.md, memory.md e tracker.json.

## Attività specifiche

Risolvi il dossier associato verificando para.json e repository.json. Leggi index.md e carica contesto sintetico, memoria essenziale e proiezione aperta dei task nel profilo snello (20.000 caratteri, solo primo caricamento); il resto si richiede con `knowledge.ps1 -Startup -Profile Full` o `-Search`, senza tetto. Consulta la fonte autorevole del tracker senza fallback. Non creare stub né memorie ridondanti.

Approfondimenti e storico si caricano solo su necessità effettiva. Mantieni la separazione tra codice distribuibile e memorie interne; preserva file personali e differenze locali non autorizzate alla modifica.

## Verifiche

Verifica che i percorsi del dossier siano validi e non provengano da archivi. Accerta che le informazioni essenziali non siano state troncate e che il tracker dichiarato sia valido.

## Consegna

Quadro sintetico dello stato del repository, attività aperte pertinenti, vincoli osservati e piano del lotto concordato.

## Prompt vicini

- MEM01: Allinea istruzioni locali, contesto, memoria e tracker.
- MEM04: Elenca e descrivi le attività del tracker e i problemi che risolvono.
- SYS07: Consulta entità e risorse del PARA centrale per identità e percorso.
- REP08: Ispeziona il repo, individua task residui e incrocia memorie e codice reale.
