# OPS02 — Configura pipeline, container e infrastruttura come codice

> **Scope**: repo | **Modalità**: scrittura | **Cosa serve**: requisiti di distribuzione e ambiente di destinazione | **Esempio d'uso**: `configura un Dockerfile multi-stage per una build riproducibile`

## Scopo

Rendere ripetibile una procedura operativa nel perimetro autorizzato.

## Quando usarlo

Per creare o modificare configurazioni di CI/CD, container o infrastruttura.

## Input

Provider, ambienti, comandi, risorse e limiti di autorizzazione.

## Attività specifiche

Riusa strumenti e convenzioni; definisci input, dipendenze, cache, permessi minimi e gestione dei segreti. Mantieni espliciti gli ambienti e gli effetti di ogni fase.

## Verifiche

Convalida sintassi e semantica con strumenti reali; usa plan o dry-run dove disponibili e verifica l'idempotenza pertinente. Configurare una pipeline non autorizza un deploy o un apply su ambienti reali.

## Consegna

Configurazioni, evidenze locali, un piano degli effetti e i passi operativi ancora da autorizzare.

## Prompt vicini

- OPS01: Prepara e verifica pacchetti e artefatti distribuibili.
- TST04: Diagnostica e correggi i fallimenti di build e test in CI.
- SEC06: Rafforza configurazione del repository, CI, container e accessi.
