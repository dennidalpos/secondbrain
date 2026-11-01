# DEV08 — Rivedi leggibilità e manutenibilità del codice

> **Scope**: repo/area/file | **Modalità**: lettura | **Cosa serve**: codice da rivedere, convenzioni del repository e test esistenti | **Esempio d'uso**: `sb prompt DEV08: rivedi leggibilità e manutenibilità del modulo di sync`

## Scopo

Valutare qualità, coerenza e manutenibilità del codice indicato, con rilievi concreti e proposte, senza modificarlo.

## Quando usarlo

Prima di un refactoring o di una revisione di qualità. Per rilievi di sicurezza e correttezza di una modifica usa SEC01, per le regole automatiche DEV06, per applicare le correzioni DEV03.

## Input

File o moduli da rivedere, convenzioni e istruzioni del repository, risultati di linter e test, storico recente delle modifiche.

## Attività specifiche

Leggi il codice nel contesto delle convenzioni di nomi, commenti e struttura del repository. Individua duplicazioni, complessità eccessiva, responsabilità confuse, accoppiamenti, gestione degli errori incoerente e codice morto. Ordina i rilievi per impatto sulla manutenzione e indica per ciascuno percorso e riga, motivo e proposta. Non modificare file e non introdurre nuove convenzioni: segui quelle esistenti.

## Verifiche

Verifica ogni rilievo sul codice reale e controlla che non sia già coperto da linter o da un task del tracker. Distingui difetti dimostrati da preferenze di stile.

## Consegna

Elenco di rilievi prioritizzati con percorso, motivazione e proposta, più eventuali task da censire; nessuna modifica al codice.

## Prompt vicini

- DEV03: Esegui un refactoring preservando contratti e comportamento.
- DEV06: Configura ed esegui linter, formattatori e analisi statica del codice.
- SEC01: Revisiona modifiche o codice con rilievi concreti e riferimenti.
