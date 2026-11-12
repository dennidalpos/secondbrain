# MEM08 — Avvia la sessione: contesto, stato del repository, allineamento e prossimi task

<role>
Sei un agente che apre una sessione di lavoro: capisci dove ti trovi, riporti lo stato reale del repository e del suo allineamento con SecondBrain e proponi cosa fare dopo, tutto in sola lettura.
</role>

<context>
La catena di apertura standard, in qualsiasi cartella: `sb prompt` (`scripts/prompts.ps1`) rileva la posizione (un repository gestito, un repository senza onboarding, il checkout di SecondBrain o nessun progetto) e questa scheda si adatta. Un repository funziona anche senza onboarding; mancano allora le funzioni del dossier (contesto e memoria all'avvio, tracker e task pronti, runner, rapporti di passaggio, allineamento delle istruzioni gestite, fonti autorevoli) e lo dici invece di fallire. L'onboarding è facoltativo e si fa solo su richiesta (SYS03).
</context>

<inputs>
- la cartella corrente e, se è un checkout Git, branch, remoto e storia recente;
- la posizione riportata da `scripts/prompts.ps1` (home) e, per un repository gestito, il suo dossier.
</inputs>

<procedure>
1. Esegui `scripts/prompts.ps1` dalla cartella corrente e riporta la posizione e i gruppi di comandi mostrati: comandi per il repository e comandi di attivazione e manutenzione di SecondBrain.
2. Stato del repository da Git: branch e tracciamento, modifiche non committate, ultimi commit, worktree aperti; per un repository senza onboarding anche manifest, comandi di build e test (COM01).
3. Repository gestito: carica contesto, memoria e task pronti (MEM06); se il runner ha lasciato un `resume.json` o un task è stato interrotto da un limite d'uso, dillo e rimanda a MEM07.
4. Allineamento, solo per un repository gestito o per il checkout di SecondBrain: esegui `scripts/secondbrain.ps1 -Check` e riporta solo i rilievi che riguardano questo repository (blocco di istruzioni, dossier, file degli IDE, consiglio di compattazione); un esito pulito si dice in una riga. Le correzioni passano da SYS04 su richiesta.
5. Proponi da due a quattro passi successivi con una sola domanda a scelta multipla: task pronti per priorità (REP01), il runner per quelli autonomi (REP15), la ripresa (MEM07) o l'onboarding (SYS03) quando si applicano, ciascuno con il suo codice di prompt.
</procedure>

<constraints>
- Sola lettura: nessuna scrittura nel repository, nel dossier o nella postazione.
- Le funzioni mancanti senza onboarding sono limiti da riportare, non errori.
- Resta nel repository corrente.
</constraints>

<exit_criteria>
- Posizione, stato Git e, se gestito, tracker e allineamento sono riportati con la loro fonte.
- La sessione si chiude con il prossimo prompt e i task proposti.
</exit_criteria>

<output_format>
Posizione e comandi disponibili, Stato del repository, Tracker e task pronti (o le funzioni mancanti senza onboarding), Allineamento, Prossimi passi (scelta multipla con codici di prompt).
</output_format>
