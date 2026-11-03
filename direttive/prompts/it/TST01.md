# TST01 — Aggiungi test unitari e di integrazione per i rischi pertinenti

> **Scope**: repo/area | **Modalità**: scrittura | **Cosa serve**: infrastruttura di test e comportamento da verificare | **Esempio d'uso**: `aggiungi test dei casi limite per il calcolo del budget`

## Scopo

Proteggere i comportamenti importanti con test affidabili.

## Quando usarlo

Quando mancano evidenze per comportamenti o per i confini tra componenti.

## Input

Comportamento da proteggere, il rischio e il framework effettivamente in uso.

## Attività specifiche

Individua scenari, casi limite ed errori non coperti. Scegli il livello del test in base al confine da verificare; usa fixture isolate e dipendenze controllate. Evita asserzioni che ripetono l'implementazione.

## Verifiche

Verifica che i test distinguano i risultati corretti da quelli errati e non dipendano da ordine, rete o stato utente inatteso.

## Consegna

Test aggiunti, comportamenti coperti, comando e risultato; nessuna percentuale di copertura arbitraria.

## Prompt vicini

- TST02: Copri i percorsi utente con test end-to-end.
- TST03: Trova e correggi i test instabili o non deterministici.
