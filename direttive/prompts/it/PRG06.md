# PRG06 — Pianifica un refactoring architetturale a fasi con controlli e rollback

> **Scope**: repo/area | **Modalità**: lettura | **Cosa serve**: modulo da riorganizzare, test esistenti e invarianti da preservare | **Esempio d'uso**: `pianifica il refactoring del modulo di sincronizzazione`

## Scopo

Impostare un piano di refactoring architetturale in fasi atomiche e verificabili che preservi i contratti pubblici e il comportamento esistente.

## Quando usarlo

Quando il debito tecnico o la complessità richiedono una riorganizzazione strutturale. Per un piano generico usa PRG04, per eseguire le modifiche DEV03, per un nuovo modulo PRG05.

## Input

Codice e confini dei moduli, dipendenze attuali, copertura dei test, invarianti architetturali e obiettivo della riorganizzazione.

## Attività specifiche

Mappa responsabilità, dipendenze e contratti pubblici. Individua i punti di rottura e suddividi il lavoro in fasi atomiche, ciascuna con passi intermedi eseguibili, criteri di verifica, ordine delle dipendenze e rollback. Non modificare il codice e non aggiornare il backlog se non esplicitamente richiesto.

## Decisioni da raccogliere

- confine del refactoring e fasi da includere nel piano;
- compatibilità da preservare per i contratti pubblici.

## Verifiche

Verifica che ogni fase abbia un esito verificabile, che i contratti pubblici non vengano rotti per errore e che la suite di test copra il comportamento da preservare.

## Consegna

Un documento di piano a fasi con dipendenze, controlli, rollback, punti decisionali concordati, ipotesi e limiti.

## Prompt vicini

- PRG04: Prepara un piano a fasi con dipendenze e controlli.
- DEV03: Rifattorizza il codice preservando i contratti: mirato, a fasi o periodico.
- PRG05: Crea l'impalcatura di nuovi moduli con struttura, configurazione e test.
- AUD03: Verifica architettura e debito tecnico non ancora tracciati.
