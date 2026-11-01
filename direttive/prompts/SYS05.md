# SYS05 — Compatta il dossier preservando originali, fatti e TOC

> **Scope**: central | **Modalità**: scrittura | **Cosa serve**: dossier con file storici e budget da ripristinare | **Esempio d'uso**: `sb prompt SYS05: compatta cronologia del dossier preservando fatti e toc`

## Scopo

Ridurre il contesto iniziale senza perdere originali, decisioni e possibilità di approfondimento.

## Quando usarlo

Su richiesta esplicita sb compatta oppure durante sb allinea per dossier oltre budget.

## Input

Dossier identificato da PARA, fonti attuali, task aperti e tetto di 20.000 caratteri per l'avvio snello.

## Attività specifiche

Leggi index.md e le fonti necessarie. Applica la regola di sintesi minima registrando solo operazioni chiave, decisioni attive, vincoli, problemi aperti e prossimo passo; non rinnovare autorizzazioni storiche. Sposta dettagli in knowledge o history e aggiorna collegamenti. Se l'ambiente supporta Function Calling o Tool Use (es. `ask_question`), usalo per sottoporre all'utente la conferma del perimetro e delle opzioni di compattazione. Prepara in .runtime un candidato JSON schema 1 con repository, sources (context.md e memory.md: SHA-256), summaries (testo completo per entrambi), openTaskIds, reviewed=true e reviewNote motivata. Il contesto deve avere sezioni Stato corrente, Vincoli, Problemi aperti, Prossimo passo. Usa knowledge.ps1 -Compact -Dossier -CandidatePath prima in anteprima e poi -Apply. Gli originali sono conservati per hash. Non troncare per rispettare il budget e non cancellare archivi.

## Decisioni da raccogliere

Se più opzioni non sono ricavabili dal codice o dalle fonti, fermati e usa Function Calling o Tool Use a scelta multipla (es. `ask_question`, `AskUserQuestion`): una decisione per domanda, scelta raccomandata come prima opzione con `(Recommended)`, opzioni atomiche e non numerate; scelta multipla quando le opzioni non si escludono.

- dossier da compattare (scelta multipla) e budget da raggiungere;
- informazioni da conservare in sintesi e conferma del candidato prima di `-Apply`.

Senza lo strumento, elenca opzioni numerate e attendi la risposta. Non richiedere di nuovo ciò che è già autorizzato nel perimetro del task.

## Verifiche

Confronta fatti essenziali prima/dopo; verifica originali byte per byte, task aperti, schema, link e TOC. Misura caratteri, non presentare una stima come conteggio esatto dei token. I dettagli su richiesta devono restare raggiungibili.

## Consegna

Sintesi e TOC, manifest degli originali, dimensione prima/dopo e eventuale budget non raggiunto.

## Prompt vicini

- MEM01: Allinea istruzioni locali, contesto, memoria e tracker.
- MEM03: Chiudi la sessione: memorie, tracker, handoff e richiesta di commit e push.
- SYS04: Controlla o allinea gli asset già gestiti della postazione.
