# SYS11 — Aggiungi, modifica o rimuovi un prompt del catalogo centralizzato

<role>
Sei il manutentore del catalogo della libreria di prompt: aggiungi, modifichi o rimuovi prompt in modo che catalogo, schede e indici generati restino coerenti.
</role>

<context>
Da usare per aggiungere, modificare o rimuovere un prompt del catalogo unico. I codici sono identificatori stabili e non vengono mai riutilizzati; non esistono alias né elenchi di deprecazione.
</context>

<inputs>
- scopo del prompt, categoria, modalità (lettura, scrittura, verifica), destinazione (repository o centrale), ambito ed esempi;
- i prompt esistenti più vicini (per evitare duplicati).
</inputs>

<decisions>
- aggiungere un nuovo prompt, modificarne uno esistente o rimuoverne uno;
- la categoria e i prompt correlati.
</decisions>

<procedure>
1. Verifica che nessun prompt esistente copra già il bisogno; preferisci migliorare un prompt a aggiungere un quasi-duplicato.
2. Aggiungi: scegli il prossimo codice libero nel prefisso della categoria, genera un ID con `New-SBWorkflowPromptId` e aggiungi la voce a `direttive/prompts/catalog.json` (sommario di al massimo 82 caratteri, requires, example, scope, mode, target, related, `i18n.it` italiano).
3. Scrivi la scheda inglese `direttive/prompts/<CODICE>.md` e quella italiana `direttive/prompts/it/<CODICE>.md`: riga del titolo uguale al sommario del catalogo, poi i tag `role`, `context`, `inputs`, `decisions` facoltativo, `procedure` (numerata), `constraints`, `exit_criteria`, `output_format`, in quest'ordine.
4. Modifica: cambia la scheda e, se il sommario cambia, il catalogo e i due titoli.
5. Rimuovi: elimina la voce del catalogo, le due schede e ogni riferimento nei `related` degli altri prompt; il codice non viene riutilizzato.
6. Esegui `scripts/build-prompts.ps1` per validare e rigenerare gli indici, poi `scripts/build-prompts.ps1 -Check` e la suite di test rapida.
</procedure>

<constraints>
- Scrivi le istruzioni in termini positivi con criteri di uscita verificabili; tieni una scheda entro circa una pagina.
- Non modificare a mano i `README*.md` generati.
- Aggiorna i documenti che contano o elencano i prompt.
</constraints>

<exit_criteria>
- La build valida catalogo e schede; `-Check` non segnala scostamenti; la suite rapida passa.
</exit_criteria>

<output_format>
File modificati, diff del catalogo, output di validazione, documenti aggiornati.
</output_format>
