# AUD04 — Verifica le dipendenze: obsolete, vulnerabili, inutilizzate e licenze

> **Scope**: repo/area | **Modalità**: lettura | **Cosa serve**: manifest, lock file e accesso ai registri dei pacchetti o agli avvisi | **Esempio d'uso**: `audit delle dipendenze prima dell'aggiornamento`

## Scopo

Fare l'inventario delle dipendenze dirette e transitive per decidere cosa aggiornare, sostituire o rimuovere.

## Quando usarlo

Prima di un aggiornamento (DEV04), prima di un rilascio o periodicamente.

## Input

Manifest e lock file, registri dei pacchetti raggiungibili, avvisi noti e politica sulle licenze del progetto.

## Attività specifiche

Elenca le dipendenze dirette e transitive con la versione in uso e l'ultima compatibile. Segnala quelle non più mantenute o deprecate, con avvisi registrati (consulta fonti ufficiali come il database OSV e gli avvisi GitHub), non referenziate dal codice, o con licenze incompatibili o non dichiarate. Ordina per urgenza: vulnerabilità sfruttabile, fine del supporto, versioni major arretrate.

## Verifiche

Non dedurre una vulnerabilità dal solo numero di versione: verifica che riguardi il percorso di codice effettivamente usato. Controlla a mano le dipendenze apparentemente inutilizzate (uso dinamico, plugin, script di build). Non modificare manifest o lock file.

## Consegna

Inventario con stato per dipendenza, priorità di aggiornamento, rischi e attività proposte per DEV04; licenze da approfondire con GOV01.

## Prompt vicini

- AUD01: Esegui un audit completo del repository con un unico rapporto, anche esportato.
- DEV04: Aggiorna le dipendenze verificando compatibilità e regressioni.
- GOV01: Verifica le licenze open source, la conformità dei file e le intestazioni SPDX.
