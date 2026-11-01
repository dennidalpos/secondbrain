# SYS07 — Consulta entità e risorse del PARA centrale per identità e percorso

> **Scope**: central | **Modalità**: lettura | **Cosa serve**: archivio PARA centrale e para-index.json | **Esempio d'uso**: `sb prompt SYS07: consulta entita del para centrale per percorso e id`

## Scopo

Navigare e consultare tassonomia, aree, progetti e risorse dell'archivio centrale PARA.

## Quando usarlo

Ritirato: usa SYS06, che include la consultazione del PARA centrale. Resta come storico e per i riferimenti esistenti.

Per individuare dossier, risolvere identità repository o consultare registri e risorse centrali.

## Input

Tassonomia centrale PARA (01-projects/, 02-areas/, 03-resources/, 04-archives/), para-index.json.

## Attività specifiche

Consulta para-index.json o usa scripts/para.ps1 -Check per risolvere identità e percorsi delle entità. Individua dossier di progetti o aree senza deduzioni arbitrarie dal filesystem. Distingui entità attive da ritirate o archiviate.

Leggi i metadati para.json e il brief.md associato. Non riattivare archivi né creare legami non documentati tra aree indipendenti.

## Verifiche

Verifica la coerenza tra para-index.json e i metadati para.json sul disco. Accerta che nessun dossier ritirato venga referenziato come attivo senza esplicita riattivazione.

## Consegna

Elenco entità individuate, percorsi assoluti dei dossier, stato di attivazione e riferimenti per l'agente.

## Prompt vicini

- SYS05: Compatta il dossier preservando originali, fatti e TOC.
- SYS06: Leggi memoria attiva, contesto e tracker del repository corrente.
