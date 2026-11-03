# SEC04 — Trova le credenziali esposte e verifica la validazione degli input

> **Scope**: repo | **Modalità**: verifica | **Cosa serve**: working tree e strumenti di scansione | **Esempio d'uso**: `esegui un audit di sicurezza delle credenziali`

## Scopo

Rilevare credenziali esposte (password, token, chiavi, certificati, stringhe di connessione) e input non validati ai confini del sistema. Per le dipendenze usa AUD04, per l'hardening SEC06, per i dati personali SEC05 e per il controllo sul diff prima di un push SEC07.

## Quando usarlo

Prima di committare, aprire una pull request o distribuire codice ed eseguibili, e dopo aver introdotto integrazioni che gestiscono segreti.

## Input

Working tree Git, indice, commit recenti, file di configurazione ed esempi di variabili d'ambiente.

## Attività specifiche

Cerca password, token API, certificati e chiavi private, stringhe di connessione e URL con credenziali nel working tree, nell'indice e nei commit pertinenti, con gli strumenti del progetto o con regole deterministiche. Verifica che gli input ai confini del sistema (richieste, file, argomenti, variabili d'ambiente, deserializzazione) siano validati e sanificati e che i segreti non finiscano in log ed errori. Riporta i rilievi con file, riga e tipo senza riprodurre il valore. Non rimuovere né riscrivere nulla senza autorizzazione: proponi come isolare i residui sensibili in un'area locale esclusa dal controllo di versione e quali credenziali ruotare.

## Verifiche

Verifica che `git diff --staged` non contenga credenziali o percorsi privati della postazione. Distingui i falsi positivi giustificati (valori di esempio, hash pubblici) dai rischi reali: una credenziale reale esposta richiede la rotazione, non solo la rimozione.

## Consegna

Rapporto che classifica i rilievi (posizione, tipo, gravità, falso positivo o rischio), correzioni applicate se autorizzate e i limiti della copertura.

## Prompt vicini

- SEC01: Rivedi modifiche o codice con rilievi concreti e riferimenti.
- SEC05: Verifica l'isolamento dei dati personali e la conformità a GDPR e policy.
- SEC06: Rafforza configurazione del repository, CI, container e accessi.
- SEC07: Controlla diff, repository e cronologia per dati sensibili prima di pubblicare.
