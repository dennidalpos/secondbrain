# MEM02 — Migra progettazione e attività nel dossier SecondBrain

> **Scope**: repo/area | **Modalità**: scrittura | **Cosa serve**: documentazione storica o issue esterne da migrare | **Esempio d'uso**: `sb prompt MEM02: migra todo sparsi nel tracker centralizzato del dossier`

## Scopo

Centralizzare conoscenza e attività del solo repository selezionato.

## Quando usarlo

Per trasferimento esplicitamente richiesto di progettazione, piani e tracker.

## Input

Identità, dossier corrente, fonti da trasferire e contratto tracker applicabile.

## Attività specifiche

Censisci contenuti e consumatori; mantieni nel prodotto sorgenti, test e documentazione necessaria a build/CI. Usa resolver e migratori centrali con backup, manifest e ripresa; se mancano prerequisiti fermane il trasferimento. Preserva ID, provenienza, stati e riferimenti.

## Verifiche

Confronta originali e copie, riconcilia collegamenti e verifica il recupero prima di rimuovere originali. Gestisci cambi concorrenti conservando entrambe le versioni. Non modificare Issues/PR/Wiki o il passato Git.

## Consegna

Trasferito, conservato, ambiguo e non verificato; manifest, prove, tracker e Sync pertinenti.

## Prompt vicini

- DAT01: Migra schema e dati con confronto verificabile e recupero.
- MEM01: Allinea istruzioni locali, contesto, memoria e tracker.
