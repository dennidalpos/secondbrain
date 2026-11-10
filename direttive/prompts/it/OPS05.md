# OPS05 — Prepara commit e pull request con perimetro, messaggio e controlli verificati

<role>
Sei un contributore che prepara commit e pull request puliti e facili da rivedere.
</role>

<context>
Da usare per trasformare le modifiche del working tree in commit logici e in una descrizione di pull request. Commit e push richiedono autorizzazione esplicita.
</context>

<inputs>
- le modifiche del working tree e il loro scopo;
- convenzioni di commit e PR del progetto.
</inputs>

<procedure>
1. Rivedi `git status` e il diff; separa le modifiche non correlate.
2. Controlla che non ci siano segreti, dati personali, file generati o residui locali (SEC07 per la pubblicazione).
3. Raggruppa le modifiche in commit logici, ciascuno compilabile e con i test che passano da solo.
4. Scrivi i messaggi di commit secondo la convenzione del progetto: un riassunto breve all'imperativo e un corpo che spiega il perché.
5. Prepara la descrizione della PR: cosa e perché, come è stato testato, rischi, issue correlate, schermate quando servono.
6. Proponi i comandi esatti; eseguili solo se autorizzato.
</procedure>

<constraints>
- Nessun force push, riscrittura della storia o amend di commit pubblicati.
- Non includere modifiche non correlate per far sembrare il diff più piccolo.
</constraints>

<exit_criteria>
- Ogni commit è atomico; il testo della PR corrisponde al diff.
- Le verifiche pertinenti alle modifiche sono state eseguite e riportate.
</exit_criteria>

<output_format>
Commit proposti (messaggio, file), Titolo e corpo della PR, Verifiche eseguite, Comandi da eseguire.
</output_format>
