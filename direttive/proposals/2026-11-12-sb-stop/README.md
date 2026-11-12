# Comando sb stop nelle direttive (revisione 1.2)

Origine: richiesta della persona titolare del 12 novembre 2026 («Prepara la proposta MNT07 per sb stop nelle direttive»), dopo il rilascio 2.7.0, che ha aggiunto il prompt MEM09 e il comando `sb stop` al registro `Get-SBWorkflowCommands`.

**Problema.** Gli agenti conoscono i comandi `sb` dall'elenco del testo di postazione (`workstation.template.md`) e i prompt di procedura dalla riga SecondBrain del testo comune (`AGENTS.global_ide.md`). Dalla 2.7.0 la schermata `sb prompt` mostra `sb stop`, ma nessuna delle due direttive lo cita. Un agente che riceve «sb stop» senza aver aperto `sb prompt` non sa che il comando compone MEM09. Così rischia di chiudere la sessione senza salvare il rapporto di passaggio nel dossier.

**Modifica.**
- `workstation.template.md`: l'elenco dei comandi aggiunge `sb stop (MEM09: stop, save the session in the dossier, resume elsewhere with MEM07)` dopo `sb runner` (+76 caratteri, da 953 a 1.029 byte).
- `AGENTS.global_ide.md`: la riga «Procedures load on request» aggiunge `MEM09 stop and handoff`, e l'intestazione passa da «Revisione 1.1» a «Revisione 1.2» (+24 caratteri, da 3.437 a 3.461 byte).
- `AGENTS.repo.managed.md`: invariato (copia identica della revisione 1.1).

**Effetto sul contesto iniziale.** In totale +100 caratteri, ben dentro il tetto di 25.000.

**Controesempi.** Il nuovo comando non autorizza commit né push. MEM09 chiede una scelta esplicita sul lavoro non committato, e push e branch restano soggetti all'autorizzazione specifica (sezione Git del testo comune).

**Dopo l'approvazione.**
- Aggiungere `sb stop` agli elenchi verificati da `scripts/test-secondbrain-prompts.ps1` (comando descritto nel testo di postazione).
- `secondbrain.ps1 -Sync` distribuisce i testi con hash verificati.
- La versione del prodotto si decide a parte.

Anteprima: `scripts/approve-revision.ps1 -Preview -ProposalPath direttive/proposals/2026-11-12-sb-stop`.
