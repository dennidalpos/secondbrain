# TST07 — Prepara un'infrastruttura di test con fixture isolate e pulizia sicura

> **Scope**: repo | **Modalità**: scrittura | **Cosa serve**: framework di test, script di test e una radice di fixture isolata assegnata | **Esempio d'uso**: `crea fixture isolate su disco e convalida la pulizia automatica`

## Scopo

Predisporre infrastrutture di test controllate, fixture isolate e un'esecuzione sicura delle suite.

## Quando usarlo

Quando si sviluppano nuove suite di test, si convalidano scenari di migrazione o si provano script CLI. Per i test instabili già esistenti usa TST03.

## Input

Script di test, percorsi per le fixture temporanee (una directory dedicata fuori dall'albero tracciato) e dati sintetici.

## Attività specifiche

Predisponi directory dedicate e isolate per le fixture dei test, evitando sovrapposizioni con l'ambiente reale. Usa blocchi try/finally per garantire che le fixture siano conservate o ripulite in modo controllato secondo la policy del progetto.

Simula condizioni limite, conflitti concorrenti, dati corrotti e recupero dopo un crash. Non chiamare risorse di rete o endpoint remoti durante i test unitari o di integrazione locale.

## Verifiche

Verifica che le fixture non scrivano fuori dalla radice di test assegnata. Assicurati che i test esercitino sia i percorsi nominali sia i casi di errore. Conferma che nelle fixture non ci siano dati reali o personali.

## Consegna

Script di test aggiornati, un'infrastruttura convalidata, fixture isolate verificate e un rapporto di esecuzione della suite.

## Prompt vicini

- TST01: Aggiungi test unitari e di integrazione per i rischi pertinenti.
- TST02: Copri i percorsi utente con test end-to-end.
- TST03: Trova e correggi i test instabili o non deterministici.
