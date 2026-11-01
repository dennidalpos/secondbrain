# Proposta 4.4 — Direttive ridotte senza perdita di regole vincolanti

Stato: **non attivata** (analisi conclusa il 2026-11-01). `direttive/approved.json` non è stato modificato e nessuna sincronizzazione è stata eseguita.

Testi da esaminare:

- [Principi comuni 4.4](AGENTS.global_ide.md) (SHA-256 `4A4D2EF0668ADE14F80774CC46882E98F8F4CF31530FED53D021B8D008C0B11B`)
- [Integrazione postazione 4.4](workstation.template.md) (SHA-256 `1DBFB42DD28FA905713F0DC1037AC27C7F5B75DCFEDDA32D88068B7FD3DB9FF6`)

Vincolo dell'utente (2026-11-01): approvazione preventiva valida solo se nessuna regola vincolante va persa.

## Mappatura delle modifiche (testi attivi 4.3 → proposta 4.4)

| # | Testo 4.3 | Proposta 4.4 | Regola vincolante conservata in |
|---|---|---|---|
| 1 | Principi, riga revisione | Revisione 4.4 — 2026-11-01 | Intestazione (formato letto da Core e ide-map) |
| 2 | Principi, caricamento: «…; il tetto vale solo per il primo caricamento: dopo» | «…) e vale solo per il primo caricamento: dopo» | Stessa riga (20.000 caratteri, solo primo caricamento, poi nessun tetto) |
| 3 | Postazione, Controllo: «I dossier e le memorie applicano la regola generale di sintesi minima…» | Frase rimossa (duplicato) | Principi, riga di tracciamento: «Regola generale di sintesi minima…» |
| 4 | Postazione, CLI: «profilo snello entro 20.000 caratteri solo per il primo caricamento (predefinito)…» | «profilo snello predefinito…» | Principi, riga del caricamento (tetto e ambito) |
| 5 | Postazione, Scheda prompt: elenco dei valori tra parentesi di Modalità/Ambito e frase «Regola vincolante: in caso di dubbio fermati…» | Elenco dei campi senza parentesi, frase rimossa | Principi, prima riga (fermarsi e chiedere con Function Calling o Tool Use a scelta multipla); contenuto della scheda imposto da catalogo e test |
| 6 | Postazione, sb prompt: «…riassunto; seguono» | «…riassunto. Seguono» | Stessa riga |

Nessuna altra riga è stata toccata; il marcatore `<!-- secondbrain:tracker-contract:1 -->` resta.

## Esito della misura

Caratteri: 10.035 → 9.655 (**-380, circa 3,8%**). Una riduzione sostanziale non è possibile senza perdere dettaglio operativo: le righe lunghe (sb prompt, CLI, tracker) descrivono comportamenti che l'agente deve conoscere prima di eseguire `sb prompt`, e spostarle nel catalogo le toglierebbe dal contesto iniziale. Per questo la proposta **non è stata attivata**: 380 caratteri non giustificano di riscrivere il blocco gestito di 22 repository prodotto (revisione e hash) e di lasciarli con il working tree modificato.

Se in futuro si vuole una riduzione maggiore, la decisione è dell'utente: accettare di spostare in `sb prompt` l'elenco dei comandi e delle aree (perdita di dettaglio non vincolante, ma l'agente li vedrebbe solo dopo `sb prompt`).

Per attivare comunque questa versione: `scripts/approve-revision.ps1 -Authorization <testo> -ConfigPath <config> -ProposalPath direttive/proposals/2026-11-01-direttive-ridotte`, poi `scripts/secondbrain.ps1 -Sync` e `-Check`.
