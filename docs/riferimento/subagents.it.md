# Definizioni dei subagenti (F8)

Un formato versionato descrive il subagente: ruolo, contesto iniziale, permessi e strumenti MCP di SecondBrain ammessi. Le definizioni sono asset del dossier, esportate per client; i lavori entrano nel [registro attività](activity-register.it.md) con riferimento all'agente padre. Stato: implementato e verificato su fixture sintetiche; nessun client reale ha ancora caricato una definizione esportata (l'export indica `liveVerified=false`).

## Definizione (schemaVersion 1)

Salvata in `<dossier>/subagents/<nome>.json`; il nome del file coincide con `name` (`^[a-z0-9][a-z0-9-]{0,63}$`). Campi sconosciuti, file estranei nella cartella e strumenti sconosciuti sono errori.

| Campo | Significato |
|---|---|
| `schemaVersion` | `1` |
| `name`, `description` | Identità e scopo in una riga |
| `role`, `context` | Ruolo di sistema e contesto iniziale |
| `permissions.tools` | Strumenti MCP ammessi (letture, `check_publication`, `preview_dossier_write`, `submit_dossier_write`) |
| `permissions.write` | `true` solo per elencare gli strumenti di scrittura; non autorizza nulla |

## I permessi non superano il padre

`Resolve` interseca la definizione con strumenti e scrittura del padre. Uno strumento o la scrittura non concessi al padre sono un errore, mai tagliati in silenzio. Anche con `write=true` su entrambi, le scritture passano dal percorso MCP rivisto del padre (anteprima, hash del piano, approvazione: F5); una definizione non può contenere permit.

## Comandi

Vedi la [guida inglese](subagents.md#commands): `scripts/subagents.ps1 -Operation Validate|Resolve|Export -Repository <identità>`. `Export` è anteprima senza `-Apply`, scrive solo sotto `.runtime`, mai in un checkout; per `claude-code` genera `.claude/agents/<nome>.md` con i soli strumenti ammessi, per gli altri client il JSON normalizzato finché il formato nativo non è verificato. Senza `-ParentTools` il padre è in sola lettura.

## Registro

I lavori dei subagenti sono record con `parent` (la `session` del padre) e `agent` (nome della definizione), sempre insieme, con `source=mcp`; la sessione padre deve già essere nel registro dello stesso repository, altrimenti l'append è rifiutato. L'append richiede `activityLogEnabled` (attivazione: #348).
