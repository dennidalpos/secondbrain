# SEC07 — Analizza i dati sensibili del diff prima del push

> **Scope**: repo | **Modalità**: verifica | **Cosa serve**: commit e modifiche da inviare, destinazione e visibilità del remoto | **Esempio d'uso**: `sb prompt SEC07: controlla dati sensibili nei commit prima del push`

## Scopo

Impedire che segreti, dati personali e residui privati arrivino su un remoto con il prossimo push.

## Quando usarlo

Prima di ogni push o pull request. È un controllo mirato sul diff; REP05 qualifica l’intero repository e la sua storia.

## Input

Commit, indice e working tree da pubblicare, tag inclusi, destinazione e visibilità del remoto.

## Attività specifiche

Determina l’insieme esatto di commit e file che verrebbero inviati (per esempio `@{upstream}..HEAD` e i tag). Esegui `scripts/publication.ps1 -RepositoryPath` del clone SecondBrain (o lo strumento MCP `check_publication`) quando disponibile; ricorda che la scansione incrementale parte dal baseline del repository e non da `@{upstream}`, quindi confrontala con l'insieme appena determinato e le scansioni di SEC04 (segreti) e SEC05 (dati personali) limitate a questo insieme. Controlla anche messaggi di commit, nomi di file, binari, file ignorati aggiunti a forza, percorsi privati e indirizzi email non pubblici. Riporta solo hash e posizioni, mai i valori.

## Decisioni da raccogliere

Se più opzioni non sono ricavabili dal codice o dalle fonti, fermati e usa Function Calling o Tool Use a scelta multipla (es. `ask_question`, `AskUserQuestion`): una decisione per domanda, scelta raccomandata come prima opzione con `(Recommended)`, opzioni atomiche e non numerate; scelta multipla quando le opzioni non si escludono.
- remoto e visibilità di destinazione;
- azione per ogni rilievo (correggere, ammettere con motivazione, rinviare).

Senza lo strumento, elenca opzioni numerate e attendi la risposta. Non richiedere di nuovo ciò che è già autorizzato nel perimetro del task.

## Verifiche

Distingui i falsi positivi motivati dai rischi reali. Se un segreto è già in un commit locale, indica che la storia locale va riscritta prima del push e non procedere. Nessun push in presenza di rilievi non valutati.

## Consegna

Esito per commit (pronto, bloccato, da valutare), rilievi con posizione e azioni suggerite; il push resta una scelta dell’utente.

## Prompt vicini

- SEC04: Cerca credenziali esposte e verifica la validazione degli input.
- SEC05: Verifica isolamento dati personali e conformità a GDPR e policy.
- REP05: Verifica contenuti e cronologia prima della pubblicazione.
- SEC08: Verifica se dati sensibili restano raggiungibili sul remoto GitHub.
