# TST03 — Individua e correggi test instabili o non deterministici

> **Scope**: repo/area | **Modalità**: scrittura | **Cosa serve**: log dei fallimenti intermittenti e suite di test | **Esempio d'uso**: `sb prompt TST03: risolvi instabilita nei test asincroni della suite`

## Scopo

Rendere affidabile una verifica che cambia esito senza modifiche funzionali.

## Quando usarlo

Per fallimenti intermittenti, dipendenze dall’ordine o differenze temporali.

## Input

Test, frequenza osservata, log, seed, ambiente e comandi di riproduzione.

## Attività specifiche

Ripeti in modo limitato e motivato; cerca gare, tempo, casualità, stato condiviso e servizi esterni. Correggi isolamento o sincronizzazione mantenendo il comportamento protetto.

## Verifiche

Ripeti la riproduzione nelle condizioni causali individuate. Evita sleep arbitrari, retry indiscriminati, disabilitazione e riduzione delle asserzioni.

## Consegna

Causa dell’instabilità, correzione e numero/condizioni delle ripetizioni; nessuna garanzia assoluta.

## Prompt vicini

- DEV02: Riproduci un difetto e correggine la causa.
- TST04: Diagnostica e correggi errori di build e test nella CI.
