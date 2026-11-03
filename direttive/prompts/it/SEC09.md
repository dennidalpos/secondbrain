# SEC09 — Cancella cronologia e artefatti del remoto GitHub dopo un'esposizione di dati

> **Scope**: repo | **Modalità**: scrittura | **Cosa serve**: richiesta esplicita, backup verificato e accesso amministrativo al remoto | **Esempio d'uso**: `cancella cronologia, run e cache del remoto dopo l'esposizione`

## Scopo

Rimuovere dal remoto GitHub la cronologia e gli artefatti che espongono dati sensibili e riportare il repository a uno stato pulito, dopo che le credenziali sono state ruotate.

## Quando usarlo

Solo su richiesta esplicita, dopo un'esposizione confermata (SEC08, SEC07). Le operazioni sono distruttive e irreversibili per il remoto.

## Input

Repository, autorizzazione dell'utente per ogni passo distruttivo, un backup verificato, l'elenco dei segreti da ruotare e l'eventuale cronologia da conservare.

## Attività specifiche

Prima ruota o revoca le credenziali esposte: la pulizia non rende sicuro un segreto già pubblicato. Poi, in ordine e con conferma per ogni passo: 1) un backup locale verificato (mirror e inventario di rami, tag, rilasci e issue); 2) scelta della strategia: riscrittura mirata con `git filter-repo` (`--invert-paths --path <file>` o `--replace-text`; elimina i vecchi tag che riscrive e va eseguita su un clone nuovo), una nuova cronologia con un ramo orfano e un solo commit (i vecchi commit restano raggiungibili tramite `refs/remotes/*`, tag e reflog: elimina quei riferimenti, esegui `git reflog expire --expire=now --all` e `git gc --prune=now`, poi verifica che il segreto non si trovi più con `git log --all -p`), oppure ricreare il repository; 3) aggiorna i riferimenti remoti con `--force-with-lease` ed elimina rami e tag residui; 4) elimina run e log dei workflow, artefatti, cache di Actions, rilasci e gli asset coinvolti (`gh run delete`, `gh cache delete`, le API); 5) una richiesta al supporto GitHub per i riferimenti `refs/pull` e gli oggetti che non si possono eliminare da soli; 6) avvisa i proprietari di fork e cloni perché cloni di nuovo. Verifica prima che gli strumenti siano disponibili (`gh`, `git filter-repo`): se ne manca uno, proponi l'alternativa (ramo orfano o ricreazione) senza installare nulla senza autorizzazione. Mostra ogni comando in anteprima prima di eseguirlo. Non eseguire alcuna operazione distruttiva senza una richiesta esplicita dell'utente nel messaggio corrente.

## Decisioni da raccogliere

- strategia: riscrittura mirata, nuova cronologia o ricreazione del repository;
- rami, tag e rilasci da conservare;
- conferma esplicita per ogni passo distruttivo.

## Verifiche

Ripeti SEC08 per mostrare che cosa non è più raggiungibile, confronta l'albero del nuovo stato con quello atteso ed esegui SEC07 sul risultato. Dichiara ciò che non si può verificare: copie di terzi, cache e oggetti non raggiungibili finché GitHub non li rimuove.

## Consegna

Azioni eseguite con il loro esito, stato prima e dopo, credenziali ruotate, esposizioni residue e passi manuali (richiesta al supporto GitHub).

## Prompt vicini

- SEC08: Verifica se dati sensibili sono ancora raggiungibili sul remoto GitHub.
- SEC07: Controlla diff, repository e cronologia per dati sensibili prima di pubblicare.
- SEC04: Trova le credenziali esposte e verifica la validazione degli input.
