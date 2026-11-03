# SEC03 — Correggi le vulnerabilità e rafforza le difese interessate

> **Scope**: repo/area/file | **Modalità**: scrittura | **Cosa serve**: vulnerabilità confermata e contesto del codice | **Esempio d'uso**: `correggi il path traversal nella risoluzione dei percorsi`

## Scopo

Mitigare rischi di sicurezza verificati nel perimetro richiesto.

## Quando usarlo

Per rilievi confermati, avvisi applicabili o hardening mirato.

## Input

Rilievo, evidenze, componenti e versioni; scenari da prevenire.

## Attività specifiche

Convalida il rilievo e la sua applicabilità. Correggi il confine vulnerabile con privilegi minimi e validazione coerente; proteggi segreti e messaggi di errore. Usa fonti primarie per avvisi e mitigazioni.

## Verifiche

Prova input ostili e regressioni pertinenti in un ambiente isolato. Distingui corretto, residuo e non verificato; non affermare un'assenza generale di vulnerabilità.

## Consegna

Mitigazioni, evidenze, dipendenze coinvolte e rischi residui.

## Prompt vicini

- DEV04: Aggiorna le dipendenze verificando compatibilità e regressioni.
- SEC02: Analizza minacce, confini di fiducia e scenari di abuso.
- SEC06: Rafforza configurazione del repository, CI, container e accessi.
