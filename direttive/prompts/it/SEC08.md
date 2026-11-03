# SEC08 — Verifica se dati sensibili sono ancora raggiungibili sul remoto GitHub

> **Scope**: repo | **Modalità**: verifica | **Cosa serve**: accesso in sola lettura al remoto GitHub e impronte o pattern da cercare | **Esempio d'uso**: `verifica quali run, cache e link sono ancora accessibili`

## Scopo

Rilevare che cosa resta accessibile sul remoto dopo un'esposizione o una riscrittura: commit, riferimenti, run, artefatti, cache, rilasci e link.

## Quando usarlo

Dopo una pubblicazione errata, prima di SEC09 e come controllo finale di una pulizia.

## Input

Repository remoto, impronte, prefissi o pattern da cercare (mai segreti in chiaro) e autorizzazione in sola lettura.

## Attività specifiche

In sola lettura, con `gh` o le API: elenca rami, tag, `refs/pull/*` e rami dei fork; cerca commit raggiungibili tramite SHA anche se non più in alcun ramo; elenca run dei workflow con i relativi log, artefatti, cache di Actions, rilasci e asset, wiki, pacchetti, issue, commenti, descrizioni e il sito Pages. Tratta fork e copie come esposizioni esterne e verifica se i link a file o SHA specifici rispondono ancora. GitHub può conservare viste in cache e oggetti non raggiungibili: segui la documentazione ufficiale per la richiesta al supporto.

## Verifiche

Ogni voce riporta URL o identificatore, tipo, esito della richiesta (accessibile o no) e data del controllo. Non scaricare né riprodurre il contenuto sensibile. Distingui i dati realmente esposti dai riferimenti innocui.

## Consegna

Inventario delle esposizioni con gravità, voci non verificabili dall'esterno (copie di terzi, cache) e passi proposti per SEC09 e per la rotazione delle credenziali.

## Prompt vicini

- SEC07: Controlla diff, repository e cronologia per dati sensibili prima di pubblicare.
- SEC09: Cancella cronologia e artefatti del remoto GitHub dopo un'esposizione di dati.
