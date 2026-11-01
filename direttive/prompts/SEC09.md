# SEC09 — Azzera storia e artefatti remoti GitHub dopo un’esposizione di dati

> **Scope**: repo | **Modalità**: scrittura | **Cosa serve**: richiesta esplicita, backup verificato e accesso amministrativo al remoto | **Esempio d'uso**: `sb prompt SEC09: azzera storia, run e cache del remoto dopo l’esposizione`

## Scopo

Eliminare dal remoto GitHub storia e artefatti che espongono dati sensibili e riportare il repository a uno stato pulito, dopo la rotazione delle credenziali.

## Quando usarlo

Solo su richiesta esplicita, dopo un’esposizione confermata (SEC08, REP05). Le operazioni sono distruttive e irreversibili per il remoto.

## Input

Repository, autorizzazione dell’utente per ogni passo distruttivo, backup verificato, elenco dei segreti da ruotare e storia da conservare, se esiste.

## Attività specifiche

Ruota o revoca per prima cosa le credenziali esposte: la pulizia non rende sicuro un segreto già pubblicato. Poi, nell’ordine e con conferma per ciascun passo: 1) backup locale verificato (mirror e inventario di rami, tag, release e issue); 2) scelta della strategia: riscrittura mirata con `git filter-repo`, nuova storia con ramo orfano e un solo commit, oppure ricreazione del repository; 3) aggiornamento dei riferimenti remoti con `--force-with-lease` ed eliminazione di rami e tag residui; 4) eliminazione di workflow run e log, artefatti, cache di Actions, release e asset interessati (`gh run delete`, `gh cache delete`, API); 5) richiesta al supporto GitHub per riferimenti `refs/pull` e oggetti non eliminabili da soli; 6) avviso a proprietari di fork e di cloni perché riclonino. Verifica prima la disponibilità degli strumenti (`gh`, `git filter-repo`): se manca, proponi l’alternativa (ramo orfano o ricreazione) senza installare nulla senza autorizzazione. Mostra ogni comando in anteprima prima dell’esecuzione. Non eseguire alcuna operazione distruttiva senza richiesta esplicita dell’utente nel messaggio corrente.

## Decisioni da raccogliere

Se più opzioni non sono ricavabili dal codice o dalle fonti, fermati e usa Function Calling o Tool Use a scelta multipla (es. `ask_question`, `AskUserQuestion`): una decisione per domanda, scelta raccomandata come prima opzione con `(Recommended)`, opzioni atomiche e non numerate; scelta multipla quando le opzioni non si escludono.
- strategia: riscrittura mirata, nuova storia o ricreazione del repository;
- rami, tag e release da conservare;
- conferma esplicita per ogni passo distruttivo.

Senza lo strumento, elenca opzioni numerate e attendi la risposta. Non richiedere di nuovo ciò che è già autorizzato nel perimetro del task.

## Verifiche

Ripeti SEC08 per dimostrare cosa non è più raggiungibile, confronta l’albero del nuovo stato con quello atteso ed esegui REP05 sul risultato. Dichiara ciò che non si può verificare: copie di terzi, cache e oggetti irraggiungibili finché GitHub non li elimina.

## Consegna

Azioni eseguite con esito, stato prima e dopo, credenziali ruotate, esposizioni residue e passi manuali (richiesta al supporto GitHub).

## Prompt vicini

- SEC08: Verifica se dati sensibili restano raggiungibili sul remoto GitHub.
- REP05: Verifica contenuti e cronologia prima della pubblicazione.
- SEC04: Cerca credenziali esposte e verifica la validazione degli input.
