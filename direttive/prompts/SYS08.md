# SYS08 — Misura i caratteri di contesto, memoria e tracker rispetto al budget

> **Scope**: central | **Modalità**: verifica | **Cosa serve**: dossier target e tetto di 20.000 caratteri del primo caricamento | **Esempio d'uso**: `sb prompt SYS08: verifica conteggio caratteri rispetto a 20000`

## Scopo

Misurare l'occupazione in caratteri del dossier rispetto al tetto di 20.000 caratteri del primo caricamento (profilo snello).

## Quando usarlo

Prima di una compattazione SYS05 o durante verifiche di allineamento e salute della memoria.

## Input

Dossier del repository (context.md, memory.md, tracker autoritativo, index.md).

## Attività specifiche

Calcola la somma dei caratteri del pacchetto iniziale: context.md, memory.md e la proiezione delle sole attività aperte del tracker. Confronta il totale con il tetto contrattuale di 20.000 caratteri (profilo snello); `knowledge.ps1 -Startup -Report` mostra caratteri per parte, stima token e peso delle direttive. Il contesto completo (`-Profile Full`) non ha tetto.

Distingui caratteri grezzi da token stimati. Individua sezioni con narrazioni storiche o dettagli superati che devono essere trasferiti nello storico del dossier.

## Verifiche

Accerta che il calcolo escluda i file di approfondimento, i log e gli archivi storici conservati. Se il pacchetto snello supera 20.000 caratteri, riorganizza i livelli o pianifica la compattazione conservativa SYS05.

## Consegna

Report metrico con conteggio caratteri per file, percentuale di saturazione del budget e indicazione sulle compattazioni necessarie.

## Prompt vicini

- SYS05: Compatta il dossier preservando originali, fatti e TOC.
- SYS06: Leggi memoria attiva, contesto e tracker del repository corrente.
