# TST03 — Trova e correggi i test instabili o non deterministici

> **Scope**: repo/area | **Modalità**: scrittura | **Cosa serve**: log dei fallimenti intermittenti e suite di test | **Esempio d'uso**: `correggi l'instabilità dei test asincroni della suite`

## Scopo

Rendere affidabile un controllo il cui esito cambia senza modifiche funzionali.

## Quando usarlo

Per fallimenti intermittenti, dipendenze dall'ordine o differenze di tempistica.

## Input

Test, frequenza osservata, log, seed, ambiente e comandi di riproduzione.

## Attività specifiche

Ripeti in modo limitato e motivato; cerca race, tempo, casualità, stato condiviso e servizi esterni. Correggi isolamento o sincronizzazione mantenendo il comportamento protetto.

## Verifiche

Ripeti la riproduzione nelle condizioni causali individuate. Evita attese arbitrarie, nuovi tentativi indiscriminati, test disabilitati e asserzioni ridotte.

## Consegna

Causa dell'instabilità, la correzione e il numero e le condizioni delle ripetizioni; nessuna garanzia assoluta.

## Prompt vicini

- DEV02: Riproduci un difetto e correggine la causa.
- TST04: Diagnostica e correggi i fallimenti di build e test in CI.
