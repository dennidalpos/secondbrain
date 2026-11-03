# DAT02 — Costruisci importazioni e trasformazioni che preservano gli originali

> **Scope**: repo/area | **Modalità**: scrittura | **Cosa serve**: file di origine, modello di destinazione e regole di validazione | **Esempio d'uso**: `importa il catalogo da CSV a JSON preservando gli originali`

## Scopo

Produrre dati utilizzabili da input eterogenei con provenienza chiara.

## Quando usarlo

Per importazioni, normalizzazione, deduplicazione o conversioni richieste.

## Input

Formati, campioni, schema atteso, regole di qualità e destinazione.

## Attività specifiche

Analizza gli originali senza modificarli; definisci la mappatura e la gestione degli errori. Distingui i record accettati, trasformati e scartati; preserva provenienza, precisione numerica e codifiche rilevanti.

## Verifiche

Prova input malformati, duplicati, valori limite e riesecuzioni. Confronta record e totali; non scartare mai anomalie in silenzio.

## Consegna

Output, regole applicate, scarti motivati e una riconciliazione con gli originali.

## Prompt vicini

- DAT01: Migra schema e dati con confronto verificabile e recupero.
- DAT03: Integra servizi API con gestione degli errori e nuovi tentativi delle richieste.
