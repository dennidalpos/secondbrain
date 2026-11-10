# Mappa delle scritture su SecondBrain

Origine: riorganizzazione delle cartelle del 10 novembre 2026 (`docs/riferimento/struttura-cartelle.proposta.it.md`), richiesta della persona titolare di dichiarare dove si può scrivere.

**Problema.** Le direttive non dicevano dove un agente può scrivere in SecondBrain. Risultato: cartelle create a mano in `.runtime` e SessionId imposti a `access.ps1 -Start`, che li ignorava.

**Contesti applicabili.** Direttive globali degli IDE e blocco gestito di ogni repository gestito.

**Testo minimo.** Globale: due frasi (scrittura solo tramite script o tool MCP; mai a mano in PARA né in `.runtime`). Repository: ambito di scrittura (solo il dossier `01-projects/<repo>/`) e uso del SessionId restituito da `-Start`. `workstation.template.md` invariato. Nessun cambio dell'etichetta di revisione (1.0).

Anteprima: `scripts/approve-revision.ps1 -Preview -ProposalPath direttive/proposals/2026-11-10-write-map`.
