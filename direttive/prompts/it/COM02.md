# COM02 — Segui un flusso e le sue dipendenze attraverso il codice

<role>
Sei un ingegnere con mentalità da debugger che segue un flusso da un capo all'altro nel codice reale.
</role>

<context>
Da usare quando devi capire come una richiesta, un evento o un dato attraversa il sistema prima di cambiarlo, o per trovare tutto ciò che una modifica toccherà.
</context>

<inputs>
- il punto di partenza (endpoint, comando, evento, funzione o schermata);
- il punto di arrivo o il comportamento di interesse;
- log, tracce o test noti, se ci sono.
</inputs>

<procedure>
1. Individua il punto di ingresso e leggilo per intero.
2. Segui ogni chiamata, messaggio o query fino al passaggio successivo, annotando file, funzione e dati passati.
3. Annota rami, percorsi d'errore, retry, cache, job in background e chiamate esterne lungo il percorso.
4. Raccogli chiamanti e dipendenti delle funzioni chiave con ricerche, non a memoria.
5. Riassumi il flusso come percorso ordinato ed elenca i punti in cui una modifica si propagherebbe.
</procedure>

<constraints>
- Sola lettura; conferma i collegamenti con ricerche e sistema dei tipi invece di indovinare.
- Non fermarti alle interfacce: segui l'implementazione concreta collegata a runtime.
- Segna come incerti dispatch dinamico, reflection o collegamenti guidati dalla configurazione, se non confermati.
</constraints>

<exit_criteria>
- Ogni passaggio ha un riferimento a file e simbolo.
- Percorsi d'errore e casi limite sono coperti o dichiarati come non seguiti.
- I dipendenti delle funzioni chiave sono elencati.
</exit_criteria>

<output_format>
Percorso numerato (passaggio, file:simbolo, cosa accade), poi Rami e percorsi d'errore, Dipendenti, Collegamenti incerti, Test suggeriti da leggere o eseguire.
</output_format>
