# MEM06 — Leggi memoria attiva, contesto e tracker del repository corrente

> **Scope**: repo | **Modalità**: lettura | **Cosa serve**: checkout del repository aperto | **Esempio d'uso**: `sb prompt MEM06: carica contesto e memoria del repository nel budget`

## Scopo

Caricare memoria attiva, contesto sintetico e tracker del repository nel budget di contesto. È il caricamento iniziale: per elencare nel dettaglio le attività usa MEM04, per incrociarle con il codice reale REP08.

## Quando usarlo

All'avvio di una sessione o prima di pianificare ed eseguire modifiche nel repository corrente; anche per misurare il pacchetto iniziale rispetto al tetto o per consultare il PARA centrale per identità e percorso.

## Input

Repository locale, file AGENTS.md, dossier del repository con context.md, memory.md e tracker.json.

## Attività specifiche

Risolvi il dossier associato verificando para.json e repository.json. Leggi index.md e carica contesto sintetico, memoria essenziale e proiezione aperta dei task nel profilo snello (20.000 caratteri, solo primo caricamento); il resto si richiede con `knowledge.ps1 -Startup -Profile Full` o `-Search`, senza tetto. Consulta la fonte autorevole del tracker senza fallback. Non creare stub né memorie ridondanti.

Per misurare il pacchetto iniziale usa `knowledge.ps1 -Startup -Report`: caratteri per parte (non token), saturazione rispetto ai 20.000 del profilo snello e peso delle direttive; il contesto completo (`-Profile Full`) non ha tetto. Se il pacchetto supera il tetto, riorganizza i livelli o pianifica la compattazione conservativa SYS05.

Per individuare altri dossier, aree o risorse del PARA centrale risolvi identità e percorsi da `para-index.json` o `scripts/para.ps1 -Check`, leggi `para.json` e `brief.md` senza dedurre dal filesystem, distingui entità attive da ritirate o archiviate e non riattivare archivi né creare legami non documentati tra aree indipendenti.

Approfondimenti e storico si caricano solo su necessità effettiva. Mantieni la separazione tra codice distribuibile e memorie interne; preserva file personali e differenze locali non autorizzate alla modifica.

## Verifiche

Verifica che i percorsi del dossier siano validi e non provengano da archivi. Accerta che le informazioni essenziali non siano state troncate e che il tracker dichiarato sia valido. Controlla la coerenza tra `para-index.json` e i `para.json` su disco e che il calcolo dei caratteri escluda approfondimenti, log e archivi storici.

## Consegna

Quadro sintetico dello stato del repository, attività aperte pertinenti, vincoli osservati e piano del lotto concordato; se richiesto, conteggio dei caratteri per parte con percentuale di saturazione ed entità PARA individuate con percorso e stato.

## Prompt vicini

- MEM01: Allinea istruzioni locali, contesto, memoria e tracker.
- MEM04: Elenca e descrivi le attività del tracker e i problemi che risolvono.
- REP08: Ispeziona il repo e trova i task residui rispetto al codice reale.
