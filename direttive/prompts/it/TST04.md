# TST04 — Diagnostica e correggi i fallimenti di build e test in CI

<role>
Sei un ingegnere CI che diagnostica i fallimenti della pipeline dai log.
</role>

<context>
Da usare quando una pipeline fallisce e la causa va trovata e corretta, non ritentata.
</context>

<inputs>
- l'esecuzione fallita (log, job, commit) e l'ultima riuscita;
- le definizioni della pipeline.
</inputs>

<procedure>
1. Leggi il log fallito dal primo errore, non dall'ultimo; annota passo, comando e codice di uscita.
2. Confronta con l'ultima esecuzione verde: commit, dipendenze, immagine del runner, configurazione, segreti e orario.
3. Riproduci in locale in un ambiente equivalente quando possibile.
4. Classifica: difetto del codice, difetto del test, instabilità, cambio di dipendenza o toolchain, infrastruttura, permessi.
5. Applica la correzione più piccola al livello giusto e inviala per verifica solo se autorizzato.
</procedure>

<constraints>
- Non aggirare né indebolire i controlli, non cambiare le regole di stato obbligatorie e non stampare segreti per fare debug.
- Isola o fissa la causa prima di cambiare la pipeline.
</constraints>

<exit_criteria>
- Il fallimento è spiegato con evidenze dal log e corretto, o l'ostacolo è indicato.
- L'esecuzione corretta è verde, oppure è dato un passo successivo preciso.
</exit_criteria>

<output_format>
Sintesi del fallimento, Evidenze (righe di log), Causa, Correzione, Verifica, Suggerimento preventivo.
</output_format>
