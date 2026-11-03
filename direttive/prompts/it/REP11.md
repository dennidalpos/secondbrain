# REP11 — Segnala un errore come issue GitHub nel formato del form, dopo conferma

> **Scope**: repo | **Modalità**: scrittura | **Cosa serve**: errore osservato, passi di riproduzione, versione e `gh` autenticato | **Esempio d'uso**: `segnala questo errore di build come issue GitHub`

## Scopo

Trasformare un errore verificato in una o più issue GitHub nel formato dei form del repository, senza pubblicare nulla che l'utente non abbia confermato.

## Quando usarlo

Quando un difetto, un errore di build o una funzionalità mancante è stato osservato e va tracciato su GitHub invece di essere corretto subito.

## Input

Testo o log dell'errore, passi per riprodurlo, versione e ambiente del prodotto, i form in `.github/ISSUE_TEMPLATE/` (`bug.yml`, `feature.yml`, `config.yml`) e il repository di destinazione.

## Attività specifiche

Verifica prima l'errore: riproducilo o leggi il log reale e il codice coinvolto, separando fatti e ipotesi. Controlla con `gh issue list --search` che nessuna issue aperta lo copra già. Dividi i problemi non correlati in issue distinte. Per ogni issue compila tutti i campi obbligatori del form corrispondente (`bug.yml` o `feature.yml`) con le stesse etichette, lo stesso ordine e la stessa terminologia, usando dati sintetici o oscurati: niente segreti, dati personali, percorsi dell'host o log grezzi, verificati come in SEC07. Mostra titolo, etichette e testo in anteprima. Pubblica con `gh issue create` solo dopo la conferma dell'utente per ciascuna issue, poi riporta numeri e link. Se `gh` manca o non è autenticato, fermati e consegna il testo preparato senza pubblicare.

## Decisioni da raccogliere

- una issue o più issue e come suddividerle;
- etichette, assegnatari e milestone, se il repository li usa;
- conferma alla pubblicazione di ciascuna issue preparata.

## Verifiche

Controlla che ogni campo obbligatorio del form sia compilato, che il testo non contenga dati sensibili, che non esista una issue duplicata e che quanto segnalato corrisponda all'errore osservato. Dopo la pubblicazione rileggi ogni issue con `gh issue view`.

## Consegna

L'elenco delle issue pubblicate con numero e link, oppure i testi preparati se non è stato pubblicato nulla, più eventuali duplicati trovati.

## Prompt vicini

- DEV07: Fai il triage di una segnalazione e riproducila, senza modificare il codice.
- COM05: Analizza log e incidenti per trovare la causa radice, senza toccare il codice.
- SEC07: Controlla diff, repository e cronologia per dati sensibili prima di pubblicare.
