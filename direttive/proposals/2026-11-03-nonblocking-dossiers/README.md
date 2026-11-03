# Proposta: dossier concorrenti e riepilogo minimo (#292, #245)

Stato: **non approvata e non distribuita**. Origine: `github.com/dennidalpos/secondbrain`. Questa proposta riunisce la chiusura con riepilogo di #245 e il flusso di scritture differite scelto dall'utente per #292. Le modifiche di #255 su pulizia, layout e commit restano escluse.

## Comportamento da distribuire agli agenti

1. Una sessione di lavoro registra l'identita; i lock proteggono soltanto le singole operazioni centrali.
2. Task, memoria, contesto e rapporti si scrivono con `knowledge.ps1`: richiesta salvata prima dell'integrazione, senza attesa del lock se il centro e occupato.
3. Letture e avvio MCP possono integrare le richieste gia autorizzate. Contratto e permessi dichiarano la possibilita di scrivere; non ci sono nuove autorizzazioni implicite.
4. Originali e ricevute restano conservati; conflitti visibili, nessuna sovrascrittura automatica di basi cambiate. Configurazioni, direttive e PARA conservano le operazioni esplicite.
5. Alla chiusura si propone il riepilogo aggiuntivo minimo (memoria, storico oppure salta), senza omettere gli aggiornamenti obbligatori e senza trascrizioni grezze.

## Testo nuovo per le scritture dei dossier

> Nei dossier SecondBrain, per task usa knowledge.ps1 -NewTask/-UpdateTaskId; per memoria, contesto e rapporti usa -SaveFile con hash della base oppure -AppendFile per aggiunte esplicite. Se il centro e occupato conserva la richiesta in .runtime/access e continua; non trattenere lock durante lavoro o test. Letture e avvio MCP possono integrare soltanto richieste gia autorizzate, con effetto e permessi dichiarati. Conserva originali e ricevute e segnala i conflitti senza sovrascrivere. Configurazioni, direttive e PARA restano operazioni esplicite; non riavviare o chiudere implicitamente sessioni altrui.

La regola sul riepilogo e quella della [proposta #245](../2026-11-03-chiusura-riepilogo/README.md), inclusa nei candidati completi. Le sorgenti attive e `approved.json` restano invariate fino all'approvazione.

## Due varianti concrete

| Scelta | Direttive candidate | Versione prodotto |
|---|---|---|
| Approvare e passare a 1.3.0 | [Testo comune](v1.3.0/AGENTS.global_ide.md), [postazione](v1.3.0/workstation.template.md) | 1.3.0 da applicare solo dopo conferma |
| Approvare mantenendo 1.2.0 | [Testo comune](v1.2.0/AGENTS.global_ide.md), [postazione](v1.2.0/workstation.template.md) | 1.2.0 invariata |
| Rinviare o rivedere | Nessuna distribuzione | 1.2.0 invariata |

I candidati differiscono solo per l'etichetta della revisione. `hashes.json` registra basi, testo della proposta e candidati per byte SHA-256. Dopo approvazione verificare nuovamente gli hash, usare `approve-revision.ps1` sulla variante scelta, poi Sync e Check. Se viene accettata 1.3.0, aggiornare anche VERSION, badge, riferimenti di versione e CHANGELOG; non inserire numeri non accettati.

Le prove locali sono in `scripts/test-secondbrain-pending.ps1` e nelle regressioni generali. La verifica su due PC fisici e SMB reale resta distinta; non e una condizione inventata come gia superata. I processi MCP gia aperti caricheranno il nuovo codice al prossimo avvio, senza interruzioni forzate.

L'approvazione non autorizza commit, push, pulizia o compattazione SYS05.
