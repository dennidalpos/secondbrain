# TST07 — Configurazione di test harness e fixture isolate

> **Scope**: repo | **Modalità**: scrittura | **Cosa serve**: framework di test, script di test e radice di fixture isolata assegnata | **Esempio d'uso**: `sb prompt TST07: crea fixture isolate su disco e valida cleanup automatico`

## Scopo

Allestire harness di test controllati, fixture isolate ed esecuzione sicura delle suite.

## Quando usarlo

Nello sviluppo di nuove suite di test, validazione di scenari di migrazione o collaudo di script CLI. Per test instabili già esistenti usa TST03.

## Input

Script di test, percorsi per fixture temporanee (.test-tmp/ o .runtime/tests/), dati sintetici.

## Attività specifiche

Configura directory dedicate e isolate per le fixture di test evitando sovrapposizioni con l'ambiente reale. Utilizza blocchi try/finally per assicurare la conservazione o pulizia controllata secondo le policy del progetto.

Simula condizioni di boundary, conflitti concorrenti, dati corrotti e ripristino da crash. Non invocare risorse di rete o endpoint remoti durante i test unitari o di integrazione locale.

## Verifiche

Verifica che le fixture non scrivano al di fuori della radice di test assegnata. Accerta che i test verifichino sia rami nominali che casi di errore. Conferma che nessun dato reale o personale sia presente nelle fixture.

## Consegna

Script di test aggiornati, harness validato, fixture isolate verificate e rapporto di esecuzione della suite.

## Prompt vicini

- TST01: Aggiungi test unitari e di integrazione sui rischi rilevanti.
- TST02: Copri percorsi utente con test end-to-end.
- TST03: Individua e correggi test instabili o non deterministici.
