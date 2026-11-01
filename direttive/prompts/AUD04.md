# AUD04 — Audita dipendenze: obsolete, vulnerabili, inutilizzate e licenze

> **Scope**: repo/area | **Modalità**: lettura | **Cosa serve**: manifest, lock file e accesso ai registri o agli advisory delle dipendenze | **Esempio d'uso**: `sb prompt AUD04: audit delle dipendenze prima dell’aggiornamento`

## Scopo

Fotografare lo stato delle dipendenze dirette e transitive per decidere cosa aggiornare, sostituire o rimuovere.

## Quando usarlo

Prima di aggiornare (DEV04), prima di una release o periodicamente.

## Input

Manifest e lock, registri dei pacchetti raggiungibili, advisory noti e politica di licenza del progetto.

## Attività specifiche

Elenca le dipendenze dirette e transitive con la versione in uso e la più recente compatibile. Segnala quelle non più mantenute o deprecate, con advisory censiti (verifica sulle fonti ufficiali, come il database OSV e gli advisory GitHub), non referenziate dal codice, con licenze incompatibili o non dichiarate. Classifica per urgenza: vulnerabilità sfruttabile, fine supporto, ritardo di versioni major.

## Verifiche

Non dedurre una vulnerabilità dal solo numero di versione: verifica l’applicabilità al percorso di codice realmente usato. Controlla a mano le dipendenze apparentemente inutilizzate (uso dinamico, plugin, script di build). Non modificare manifest né lock.

## Consegna

Inventario con stato per dipendenza, priorità di aggiornamento, rischi e task proposti per DEV04; licenze da approfondire con GOV01.

## Prompt vicini

- AUD01: Esegui un audit completo del repository con un unico rapporto.
- DEV04: Aggiorna dipendenze verificando compatibilità e regressioni.
- GOV01: Verifica licenze open source, conformità dei file e header SPDX.
