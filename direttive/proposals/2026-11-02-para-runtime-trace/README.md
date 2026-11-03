# Proposta: regole PARA, nomi in `.runtime` e avviso di compattazione

Stato: **approvata dall'utente il 2026-11-02 come revisione 1.2** (`VERSION` 1.2.0); lo stato «in attesa» era rimasto non aggiornato (corretto in #264). Il testo fu poi ridotto dalla proposta `2026-11-02-direttive-snelle` (stessa etichetta 1.2, nessun cambio di `VERSION`).

## Problema ed evidenze

- Gli agenti non ricevono alcuna regola su dove inserire, aggiornare e archiviare progetti, aree e risorse PARA: le direttive dicono solo di non dedurre il dossier e di non riattivare archivi. `para.ps1` esiste ma è descritto solo in `docs/riferimento/tree.md`.
- `.runtime` ha superato 11 GB; le cartelle create dagli agenti (`operations/`, `q201/`, `t*/`, `lotto-*`) non hanno nome né categoria riconoscibili e il codice non le conosce.
- `prompts.ps1 -Context` restituisce solo percorsi: un agente che legge i file indicati aggira il tetto di 20.000 caratteri del primo caricamento.
- Nessun segnale automatico ricorda la compattazione dopo molti turni: esiste solo `compaction-required` oltre il tetto.

## Testo minimo (diff rispetto a `direttive/`)

- `AGENTS.global_ide.md`: revisione 1.2; riga sul dossier PARA → rimando a MEM05 e `para.ps1`, divieto di spostamenti a mano e di modifiche a `PARA.md`/`para-index.json`; riga su `.runtime` → nome `<categoria>-<yyyyMMdd>-<slug>` e `cleanup.ps1 -RuntimeReport`; riga di chiusura task → su `compaction-required` o `compaction-advised` proporre SYS05 senza applicarla.
- `workstation.template.md`: comandi PARA (`-NewProject`, `-NewResource`, `-SetStatus`, `-Archive`, `-Restore`); `prompts.ps1 -Context` risolve i soli percorsi e il contesto si carica con `knowledge.ps1 -Startup` o MCP `get_startup_context`; `trace.ps1 -InstallHook` per l'hook Stop.

## Controesempi e applicabilità

La traccia contiene solo metadati (nessun prompt) e l'hook è facoltativo, fail-open e locale; senza hook resta la regola di chiusura. Nessun nome esistente viene cambiato. L'avviso non compatta mai da solo. Vale per i repository con dossier; per i prodotti cambia solo il blocco gestito di `AGENTS.md`.

## Se approvata

1. Confermare la revisione 1.2 (`VERSION`, `CHANGELOG.md`).
2. `approve-revision.ps1 -ProposalPath direttive/proposals/2026-11-02-para-runtime-trace -Authorization "<richiesta>"`, poi `secondbrain.ps1 -Sync` e `-Check`.
