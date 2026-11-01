# SEC03 — Correggi vulnerabilità e rafforza le difese interessate

> **Scope**: repo/area/file | **Modalità**: scrittura | **Cosa serve**: segnalazione vulnerabilita o cve e codice affetto | **Esempio d'uso**: `sb prompt SEC03: bonifica path traversal nella risoluzione dei percorsi`

## Scopo

Mitigare rischi di sicurezza verificati nel perimetro richiesto.

## Quando usarlo

Per finding confermati, advisory applicabili o hardening mirato.

## Input

Finding, evidenze, componenti e versioni; scenari da impedire.

## Attività specifiche

Valida il finding e l’applicabilità. Correggi il confine vulnerabile con minimo privilegio e validazione coerente; proteggi segreti e messaggi di errore. Usa fonti primarie per advisory e mitigazioni.

## Verifiche

Prova input avversi e regressioni pertinenti in ambiente isolato. Distingui corretto, residuo e non verificato; non dichiarare assenza generale di vulnerabilità.

## Consegna

Mitigazioni, prove, dipendenze interessate e rischi residui.

## Prompt vicini

- DEV04: Aggiorna dipendenze verificando compatibilità e regressioni.
- SEC02: Analizza minacce, confini di fiducia e scenari di abuso.
- SEC06: Applica hardening a configurazioni, CI, container e accessi del repository.
