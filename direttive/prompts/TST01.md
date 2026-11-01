# TST01 — Aggiungi test unitari e di integrazione sui rischi rilevanti

> **Scope**: repo/area | **Modalità**: scrittura | **Cosa serve**: harness di test e comportamento da verificare | **Esempio d'uso**: `sb prompt TST01: aggiungi test di boundary per il calcolo budget caratteri`

## Scopo

Proteggere comportamenti importanti con test affidabili.

## Quando usarlo

Quando mancano prove sui comportamenti o sui confini tra componenti.

## Input

Comportamento da proteggere, rischio e framework realmente usato.

## Attività specifiche

Individua scenari scoperti, casi limite ed errori. Scegli il livello del test secondo il confine da verificare; usa fixture isolate e dipendenze controllate. Evita asserzioni che riproducono l’implementazione.

## Verifiche

Verifica che i test distinguano risultati corretti ed errati e non dipendano da ordine, rete o stato utente non previsto.

## Consegna

Test aggiunti, comportamenti coperti, comando e risultato; nessuna percentuale arbitraria di copertura.

## Prompt vicini

- TST02: Copri percorsi utente con test end-to-end.
- TST03: Individua e correggi test instabili o non deterministici.
