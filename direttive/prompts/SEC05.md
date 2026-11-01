# SEC05 — Privacy review, conformità GDPR e isolamento dati personali

> **Scope**: repo | **Modalità**: verifica | **Cosa serve**: dossier, log operativi e repository pubblico | **Esempio d'uso**: `sb prompt SEC05: controlla assenza dati personali e conformita privacy gdpr`

## Scopo

Garantire l'isolamento dei dati personali e sensibili nel vault protetto locale escludendoli da Git.

## Quando usarlo

Nella revisione di flussi di dati, analisi dei log e prima della pubblicazione di repository e guide.

## Input

Codice sorgente, file di log, snapshot di ambiente, documentazione e directory di runtime.

## Attività specifiche

Ispeziona il repository per individuare tracce di PII: percorsi utente reali, credenziali personali, contatti o identificativi di macchine reali. Accerta che note e memorie private risiedano solo nelle cartelle protette escluse da Git.

Verifica che .gitignore blocchi la sincronizzazione remota di directory locali (PARA, .runtime, backup). Sostituisci riferimenti reali con dati sintetici o segnaposto neutrali nella documentazione pubblica.

## Verifiche

Verifica che nessun dato personale sia accessibile nell'indice Git o nella cronologia dei commit pubblici. Controlla che le procedure di esportazione o pubblicazione applichino filtri stringenti.

## Consegna

Report di audit privacy con attestazione di conformità, elenco dei percorsi isolati localmente e sanitizzazioni eseguite.

## Prompt vicini

- SEC01: Esegui una review strutturata su correttezza, robustezza e standard.
- SEC04: Security review, secret scanning e hardening del codice.
