# DEV08 — Rivedi leggibilità, coerenza e manutenibilità senza modificare il codice

> **Scope**: repo/area/file | **Modalità**: lettura | **Cosa serve**: codice da rivedere, convenzioni del repository e test esistenti | **Esempio d'uso**: `rivedi leggibilità e manutenibilità del modulo di sincronizzazione`

## Scopo

Valutare qualità, coerenza e manutenibilità del codice indicato, con rilievi e proposte concreti, senza modificarlo.

## Quando usarlo

Prima di un refactoring o di una revisione della qualità. Per rilievi di sicurezza e correttezza su una modifica usa SEC01, per le regole automatiche DEV06, per applicare le correzioni DEV03.

## Input

File o moduli da rivedere, convenzioni e istruzioni del repository, esiti di linter e test, cronologia recente delle modifiche.

## Attività specifiche

Leggi il codice nel contesto delle convenzioni del repository per nomi, commenti e struttura. Individua duplicazione, complessità eccessiva, responsabilità confuse, accoppiamento, gestione degli errori incoerente e codice morto. Ordina i rilievi per impatto sulla manutenzione e indica per ciascuno percorso e riga, il motivo e una proposta. Non modificare file e non introdurre nuove convenzioni: segui quelle esistenti.

## Verifiche

Verifica ogni rilievo sul codice reale e controlla che non sia già coperto da un linter o da una voce del backlog. Distingui i difetti provati dalle preferenze di stile.

## Consegna

Un elenco prioritizzato di rilievi con percorso, motivo e proposta, più eventuali attività da registrare; nessuna modifica al codice.

## Prompt vicini

- DEV03: Rifattorizza il codice preservando i contratti: mirato, a fasi o periodico.
- DEV06: Configura ed esegui linter, formattatori e analisi statica.
- SEC01: Rivedi modifiche o codice con rilievi concreti e riferimenti.
- AUD02: Misura il repository con metriche riproducibili e individua gli hotspot.
