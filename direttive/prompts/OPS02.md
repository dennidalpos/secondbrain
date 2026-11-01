# OPS02 — Configura pipeline, container e infrastruttura come codice

> **Scope**: repo | **Modalità**: scrittura | **Cosa serve**: requisiti di deployment e ambiente di destinazione | **Esempio d'uso**: `sb prompt OPS02: configura Dockerfile multi-stage per build riproducibile`

## Scopo

Rendere ripetibile una procedura operativa nel perimetro autorizzato.

## Quando usarlo

Per creare o modificare configurazioni CI/CD, container o infrastruttura.

## Input

Provider, ambienti, comandi, risorse e confini di autorizzazione.

## Attività specifiche

Riusa strumenti e convenzioni; definisci input, dipendenze, cache, permessi minimi e gestione dei segreti. Mantieni espliciti gli ambienti e gli effetti di ogni fase.

## Verifiche

Valida sintassi e semantica con strumenti reali; usa plan/dry-run dove disponibili e verifica idempotenza pertinente. Configurare una pipeline non autorizza deploy o apply su ambienti reali.

## Consegna

Configurazioni, prove locali, piano degli effetti e passaggi operativi ancora da autorizzare.

## Prompt vicini

- TST04: Diagnostica e correggi errori di build e test nella CI.
- OPS01: Prepara e verifica pacchetti e artefatti distribuibili.
- SEC06: Applica hardening a configurazioni, CI, container e accessi del repository.
