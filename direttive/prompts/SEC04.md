# SEC04 — Cerca credenziali esposte e verifica la validazione degli input

> **Scope**: repo | **Modalità**: verifica | **Cosa serve**: albero di lavoro e strumenti di scansione | **Esempio d'uso**: `sb prompt SEC04: esegui audit sicurezza credenziali`

## Scopo

Rilevare credenziali esposte (password, token, chiavi, certificati, stringhe di connessione) e input non validati ai confini del sistema. Per le dipendenze usa AUD04, per l’hardening SEC06, per i dati personali SEC05 e per il controllo sul diff prima del push SEC07.

## Quando usarlo

Prima del commit, della creazione di pull request o della distribuzione di codice ed eseguibili, e dopo l’introduzione di integrazioni che gestiscono segreti.

## Input

Working tree Git, indice, commit recenti, file di configurazione ed esempi di variabili d’ambiente.

## Attività specifiche

Esegui la scansione per individuare password, token API, certificati e chiavi private, stringhe di connessione e URL con credenziali nel working tree, nell’indice e nei commit pertinenti, con gli strumenti del progetto o con regole deterministiche. Verifica che gli input ai confini del sistema (richieste, file, argomenti, variabili d’ambiente, deserializzazione) siano validati e sanitizzati e che i segreti non finiscano in log ed errori. Segnala i rilievi con file, riga e tipo senza riprodurre il valore. Non rimuovere né riscrivere nulla senza autorizzazione: proponi come isolare i residui sensibili nell’area locale esclusa dal versionamento e quali credenziali ruotare.

## Verifiche

Controlla che `git diff --staged` non contenga credenziali o percorsi privati della postazione. Distingui i falsi positivi motivati (valori di esempio, hash pubblici) dai rischi effettivi: una credenziale reale esposta richiede la rotazione, non solo la rimozione.

## Consegna

Report con classificazione dei rilievi (posizione, tipo, gravità, falso positivo o rischio), correzioni applicate se autorizzate e limiti della copertura.

## Prompt vicini

- SEC01: Revisiona modifiche o codice con rilievi concreti e riferimenti.
- SEC05: Verifica isolamento dati personali e conformità a GDPR e policy.
- SEC06: Applica hardening a configurazioni, CI, container e accessi del repository.
- SEC07: Analizza i dati sensibili del diff prima del push.
