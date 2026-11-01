# SEC08 — Verifica se dati sensibili restano raggiungibili sul remoto GitHub

> **Scope**: repo | **Modalità**: verifica | **Cosa serve**: sola lettura sul remoto GitHub e impronte o pattern dei dati da cercare | **Esempio d'uso**: `sb prompt SEC08: verifica run, cache e link ancora accessibili`

## Scopo

Rilevare ciò che resta accessibile sul remoto dopo un’esposizione o una riscrittura: commit, riferimenti, run, artefatti, cache, release e link.

## Quando usarlo

Dopo una pubblicazione sbagliata, prima di SEC09 e come verifica finale di una pulizia.

## Input

Repository remoto, impronte, prefissi o pattern da cercare (mai segreti in chiaro) e autorizzazione di sola lettura.

## Attività specifiche

In sola lettura con `gh` o con le API: elenca rami, tag, `refs/pull/*` e rami dei fork; cerca commit raggiungibili per SHA anche se non più nei rami; elenca workflow run con log, artefatti, cache di Actions, release e asset, wiki, pacchetti, issue, commenti, descrizioni e sito Pages. Considera fork e copie come esposizioni esterne e verifica se i link a file o SHA specifici rispondono ancora. GitHub può conservare viste in cache e oggetti irraggiungibili: segui la documentazione ufficiale per la richiesta al supporto.

## Verifiche

Ogni elemento riporta URL o identificativo, tipo, esito della richiesta (accessibile o no) e data del controllo. Non scaricare né riprodurre i contenuti sensibili. Distingui i dati realmente esposti dai riferimenti innocui.

## Consegna

Inventario delle esposizioni con gravità, elementi non verificabili dall’esterno (copie di terzi, cache) e passi proposti per SEC09 e per la rotazione delle credenziali.

## Prompt vicini

- SEC07: Analizza i dati sensibili del diff prima del push.
- SEC09: Azzera storia e artefatti remoti GitHub dopo un’esposizione di dati.
- REP05: Verifica contenuti e cronologia prima della pubblicazione.
