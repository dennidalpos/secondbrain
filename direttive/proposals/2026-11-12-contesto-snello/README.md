# Contesto iniziale snello (revisione 1.1)

Origine: richiesta della persona titolare del 12 novembre 2026 («il contesto iniziale cresce troppo in fretta, ottimizzazioni anche distruttive»), con scelta esplicita di direttive globali snelle e chiusura senza accumulo.

**Problema.** All'avvio di ogni sessione restano in contesto circa 13.700 caratteri di direttive: `~/.claude/CLAUDE.md` 7.773 (testo comune 5.086 + postazione 2.634) e `AGENTS.md` del repository con un blocco gestito di 3.052. A questi si aggiungono la memoria e il contesto del dossier, che crescono a ogni chiusura perché la direttiva chiede di aggiungere voci a `memory.md` e `context.md`.

**Testo minimo.**
- `AGENTS.global_ide.md` passa da 5.086 a circa 3.500 caratteri. Restano principi, sicurezza, Git e chiusura; le procedure SecondBrain diventano rimandi alle schede di `sb prompt`. Il tetto di avvio è 25.000 caratteri.
- La chiusura aggiunge una voce di memoria solo per una nuova decisione durevole, su una riga, e sostituisce lo stato corrente di `context.md` invece di estenderlo (circa 1.500 caratteri per sezione).
- `workstation.template.md` passa da 2.634 a circa 1.000 caratteri: contratto del tracker, sessioni di scrittura, elenco dei comandi `sb` (compreso `sb runner`) e regola dei blocchi gestiti; il resto si carica dalle schede (SYS01, SYS03-SYS05).
- `AGENTS.repo.managed.md` passa da 3.052 a circa 700 caratteri: dossier, ambito di scrittura, autorizzazioni. Le regole su cartelle, sessioni e retention restano nelle schede e nella documentazione.

**Controesempi.** Un agente senza accesso a `sb prompt` perde le regole su retention e pulizia di `.runtime`. Queste restano comunque imposte dagli script (`work.ps1`, `cleanup.ps1` in anteprima predefinita).

Anteprima: `scripts/approve-revision.ps1 -Preview -ProposalPath direttive/proposals/2026-11-12-contesto-snello`.
