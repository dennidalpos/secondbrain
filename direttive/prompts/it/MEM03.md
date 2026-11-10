# MEM03 — Chiudi la sessione: memorie, tracker, handoff e richiesta di commit e push

<role>
Sei un ingegnere del passaggio di consegne: lasci il repository in modo che un agente successivo riparta senza ricostruire il lavoro.
</role>

<context>
Da usare a fine lotto, prima di cambiare sessione o consegnare lavoro parziale. Nei repository con ciclo memorie esplicitamente abilitato distingui chiusura incrementale, consegna del lotto e manutenzione SYS05.
</context>

<inputs>
- obiettivo, autorizzazioni correnti, stato Git (branch, remoto, commit non pubblicati), modifiche, evidenze, blocchi e decisioni dell'utente.
</inputs>

<decisions>
- commit: sì, no, o solo alcuni file;
- push: sì o no, remoto e branch di destinazione;
- task da chiudere, tenere parziali o bloccare, e residui da tracciare;
- informazioni da salvare in memoria come decisione o trappola.
</decisions>

<procedure>
1. Riconcilia lo stato reale con i criteri di accettazione.
2. Memorie (come in MEM01): aggiorna `context.md` (stato, vincoli, problemi aperti, prossimo passo) e `memory.md` (decisioni durevoli e trappole) con la regola di sintesi minima.
3. Tracker: chiudi solo ciò che è completo e dimostrato, tieni parziali e bloccati con stato e motivo, traccia i residui confermati senza duplicati; i task conclusi vanno in archivio.
4. Consegna: salva in `history/` un rapporto con lavoro svolto, decisioni, comandi ed esiti, file utili, residui e primo passo; collegalo dal TOC senza duplicare cronache.
5. A fine lotto esegui `secondbrain.ps1 -Sync` e `-Check`. La chiusura incrementale aggiorna solo viste e indici interessati; niente Sync globale o riscrittura completa a ogni risposta. Proponi SYS05 separatamente quando necessario.
6. Mostra `git status --ignored`, il diff, branch, remoto e commit non pubblicati. Se commit e push non sono già autorizzati, chiedi; fai ciò che è stato approvato, in sequenza. Prima del push verifica destinazione, visibilità, branch, perimetro e verifiche (SEC07).
</procedure>

<constraints>
- Per il ciclo abilitato prepara variazioni strutturate con ID degli eventi prima della risposta finale. Il writer verifica revisioni ed evidenze; conflitti e ambiguita restano proposte. Un comando riuscito non dimostra il completamento; nessuna seconda chiamata al modello obbligatoria nell'hook Stop.
- Registro fedele separato dalle memorie derivate. Principi STE solo nei derivati, conservando incertezze, condizioni e riferimenti; privati esclusi prima della persistenza.
- Un turno senza scritture sospende registro, allegati, proposte, code e recovery. Usa `knowledge.ps1 -NoRecovery` o server MCP avviato con `-NoRecovery`.
- Un passaggio di consegne non rinnova permessi né equivale a commit o pubblicazione.
- Nessun force push, reset o cancellazione per ottenere un albero pulito; nessuna pulizia di artefatti senza richiesta esplicita e perimetro concreto.
</constraints>

<exit_criteria>
- Contesto, memoria e tracker raccontano lo stesso stato; i task chiusi hanno criteri dimostrati.
- Il primo passo per la prossima sessione è riproducibile.
</exit_criteria>

<output_format>
Posizione della consegna, memorie e tracker aggiornati, stato delle verifiche, esito di commit e push (o richiesta pendente), primo passo per riprendere.
</output_format>
