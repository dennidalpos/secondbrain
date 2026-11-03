# Catalogo dei prompt — manutenzione SecondBrain

Indice generato da catalog.json e dalle schede Markdown con scripts/build-prompts.ps1. Non modificarlo a mano.

In chat: `sb prompt`, `sb prompt list`, `sb prompt maintenance`, `sb prompt ambito test`, `sb prompt mostra TST04`, `sb prompt TST04: descrizione`. Ogni prompt ha un ID immutabile (`pmt-` e 8 cifre esadecimali) e uno o più alias (codice incluso): ID e alias risolvono allo stesso prompt.

Prompt di manutenzione di SecondBrain (memoria, dossier, postazione, backup): richiedono SecondBrain come repository operativo. Indice dei prompt generici: [README.it.md](README.it.md).

La CLI compone il testo; il task è svolto dall'agente nei permessi e nella modalità della sessione. [Come usare e modificare i prompt](../../docs/prompt.md). Lingua: [English](README.md) · [Italiano](README.it.md).

```text
Catalogo prompt — manutenzione SecondBrain
Legenda: 🔭 legge · ✅ verifica · 🔥 scrive · ⛔ distruttivo/irreversibile

MEMORIA E CONTINUITÀ
🔥 MEM01 | Allinea istruzioni locali, contesto, memoria e tracker.
  • ID: pmt-f02db9d0
  • Ambito: repo/area | Modalità: write
  • Cosa serve: decisioni o modifiche recenti non registrate
  • Esempio d'uso: sb prompt MEM01: allinea context.md e memory.md dopo completamento task

🔥 MEM02 | Migra progettazione e attività nel dossier SecondBrain.
  • ID: pmt-64dfa49f
  • Ambito: repo/area | Modalità: write
  • Cosa serve: documentazione storica o issue esterne da migrare
  • Esempio d'uso: sb prompt MEM02: migra todo sparsi nel tracker centralizzato del dossier

🔥 MEM03 | Chiudi la sessione: memorie, tracker, handoff e richiesta di commit e push.
  • ID: pmt-76604e4a
  • Ambito: repo/area | Modalità: write
  • Cosa serve: stato del lavoro svolto, task successivi definiti e destinazione di consegna
  • Esempio d'uso: sb prompt MEM03: chiudi la sessione e chiedi commit e push

🔭 MEM04 | Elenca e descrivi le attività del tracker e i problemi che risolvono.
  • ID: pmt-23c3d2be
  • Ambito: repo/area | Modalità: read
  • Cosa serve: tracker del dossier di repository
  • Esempio d'uso: sb prompt MEM04: elenca attivita e problemi del tracker

🔥 MEM05 | Crea, aggiorna e archivia progetti, aree e risorse del PARA centrale.
  • ID: pmt-4e1b7c52
  • Ambito: central | Modalità: write
  • Cosa serve: obiettivo dell'entità PARA e sessione di scrittura sul clone SecondBrain
  • Esempio d'uso: sb prompt MEM05: archivia la risorsa conclusa res-guida

🔭 MEM06 | Leggi memoria attiva, contesto e tracker del repository corrente.
  • ID: pmt-821f7dec | Alias: SYS06
  • Ambito: repo | Modalità: read
  • Cosa serve: checkout del repository aperto
  • Esempio d'uso: sb prompt MEM06: carica contesto e memoria del repository nel budget


SISTEMA E MANUTENZIONE CENTRALE
✅ SYS01 | Verifica gli IDE; mappa, registra account o riallinea su richiesta.
  • ID: pmt-26817a61
  • Ambito: central | Modalità: verify
  • Cosa serve: installazioni IDE e autorizzazioni locali; per registrare account anche postazione attivata e consenso
  • Esempio d'uso: sb prompt SYS01: registra un ide con due account o due radici

✅ SYS02 | Verifica le fonti autorevoli; acquisisci o aggiorna su richiesta.
  • ID: pmt-5b593404
  • Ambito: central | Modalità: verify
  • Cosa serve: registro PARA resource-authoritative-sources
  • Esempio d'uso: sb prompt SYS02: verifica aggiornamenti normativi nel registro fonti

🔥 SYS03 | Attiva SecondBrain dopo discovery e selezione degli asset.
  • ID: pmt-5f9f93e0
  • Ambito: central | Modalità: write
  • Cosa serve: volume SecondBrain e consenso utente sugli asset
  • Esempio d'uso: sb prompt SYS03: attiva secondbrain selezionando repository e ide locali

✅ SYS04 | Controlla o allinea gli asset già gestiti della postazione.
  • ID: pmt-677a10ab
  • Ambito: central | Modalità: verify
  • Cosa serve: configurazione postazione e direttive approvate
  • Esempio d'uso: sb prompt SYS04: verifica allineamento direttive nei repository gestiti

🔥 SYS05 | Compatta il dossier preservando originali, fatti e TOC.
  • ID: pmt-77d7bf7a
  • Ambito: central | Modalità: write
  • Cosa serve: dossier da compattare e storico verificabile
  • Esempio d'uso: sb prompt SYS05: compatta cronologia del dossier preservando fatti e toc

🔥 SYS09 | Esegui il backup compresso deterministico e verifica i digest SHA-256.
  • ID: pmt-e498353a
  • Ambito: central | Modalità: write
  • Cosa serve: configurazione attiva e root runtime di backup
  • Esempio d'uso: sb prompt SYS09: esegui backup deterministico e valida il manifest sha-256

⛔ SYS10 | Esegui rollback e dismissione repository restituendo i dati per privacy.
  • ID: pmt-b98acaaa
  • Ambito: central | Modalità: write
  • Cosa serve: dossier del repository, checkout di destinazione e consenso utente
  • Esempio d'uso: sb prompt SYS10: esegui rollback del repository dismesso e pulisci i dati

🔥 SYS11 | Aggiungi, modifica o rimuovi un prompt del catalogo centralizzato.
  • ID: pmt-364616bb
  • Ambito: central | Modalità: write
  • Cosa serve: catalogo valido, area di destinazione e sessione di scrittura
  • Esempio d'uso: sb prompt SYS11: aggiungi un prompt al catalogo nell'area test

🔥 SYS13 | Fissa o rimuovi il blocco greenfield (versioni, changelog, migrazioni, alias).
  • ID: pmt-29b3278f
  • Ambito: repo/area | Modalità: write
  • Cosa serve: repository gestito, dossier attivo e conferma dell'utente
  • Esempio d'uso: sb prompt SYS13: fissa o rimuovi il blocco greenfield su questo repository

🔥 SYS15 | Installa il server MCP SecondBrain negli IDE e verifica l'handshake.
  • ID: pmt-2d3c1d51
  • Ambito: central | Modalità: write
  • Cosa serve: radice SecondBrain, IDE di destinazione e conferma prima di scrivere
  • Esempio d'uso: sb prompt SYS15: installa il server mcp in vscode e claude code

```
