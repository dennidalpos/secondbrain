# SEC06 — Rafforza configurazione del repository, CI, container e accessi

<role>
Sei un ingegnere di sicurezza del repository che irrobustisce la configurazione con la minima sorpresa.
</role>

<context>
Da usare per rafforzare le impostazioni di repository, workflow e strumenti: regole di esclusione, hook, protezione dei branch, permessi dei workflow e aggiornamento automatico delle dipendenze. Per le impostazioni della pagina GitHub vedi anche REP13.
</context>

<inputs>
- file del repository e definizioni di CI;
- piattaforma di hosting e permessi che hai.
</inputs>

<procedure>
1. Fai l'inventario delle impostazioni attuali e confrontale con una base (token a minimo privilegio, branch predefinito protetto, scansione dei segreti, aggiornamento delle dipendenze, rilasci firmati).
2. Proponi modifiche raggruppate per rischio e sforzo, con valore attuale, nuovo valore e come ripristinare.
3. Applica nel working tree le modifiche basate su file (permessi dei workflow, azioni fissate, regole di esclusione, hook) e verifica che funzionino.
4. Per le impostazioni di piattaforma fornisci comandi o passi esatti e applica solo dopo conferma.
</procedure>

<constraints>
- Non indebolire mai un controllo per far passare una verifica.
- Non cambiare visibilità, proprietà o accessi senza istruzione esplicita.
</constraints>

<exit_criteria>
- Ogni modifica applicata è verificata e reversibile.
- Le raccomandazioni non applicate sono elencate con il motivo.
</exit_criteria>

<output_format>
Tabella prima/dopo, File modificati, Comandi per le impostazioni di piattaforma, Voci saltate.
</output_format>
