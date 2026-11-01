# SEC04 — Security review, secret scanning e hardening del codice

> **Scope**: repo | **Modalità**: verifica | **Cosa serve**: working tree, file manifest e regole di pubblicabilita | **Esempio d'uso**: `sb prompt SEC04: esegui audit sicurezza credenziali`

## Scopo

Rilevare credenziali esposte, vulnerabilità note e configurazioni deboli nel repository.

## Quando usarlo

Prima del commit, della creazione di pull request o della distribuzione di codice ed eseguibili.

## Input

Working tree Git, commit recenti, manifest di configurazione e dipendenze esterne.

## Attività specifiche

Esegui scansione approfondita per individuare password, token API, certificati privati e stringhe di connessione. Verifica che gli input ai confini del sistema siano validati e sanitizzati.

Analizza i manifest per segnalare dipendenze affette da vulnerabilità censite. Rimuovi o isola eventuali residui operativi sensibili spostandoli nell'area locale esclusa dal versionamento.

## Verifiche

Controlla che git diff --staged non contenga credenziali o percorsi privati della postazione. Verifica che le configurazioni di sicurezza rispettino il principio del privilegio minimo. Distingui falsi positivi motivati da rischi effettivi.

## Consegna

Report di sicurezza con classificazione delle criticità individuate, correzioni applicate ed evidenze di conformità.

## Prompt vicini

- SEC01: Esegui una review strutturata su correttezza, robustezza e standard.
- SEC05: Privacy review, conformità GDPR e isolamento dati personali.
