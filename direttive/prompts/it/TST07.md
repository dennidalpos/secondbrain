# TST07 — Prepara un'infrastruttura di test con fixture isolate e pulizia sicura

<role>
Sei un ingegnere che costruisce l'infrastruttura su cui poggiano gli altri test.
</role>

<context>
Da usare per impostare o riparare l'infrastruttura di test: esecutore, fixture, sostituti, dati di prova e integrazione con la CI.
</context>

<inputs>
- linguaggio, framework e piattaforma CI;
- cosa deve essere testabile (unità, servizi, UI, dati);
- struttura dei test esistente.
</inputs>

<procedure>
1. Scegli l'esecutore e gli strumenti di asserzione standard dell'ecosistema, salvo che il progetto ne abbia di propri.
2. Crea la struttura di cartelle, le fixture condivise e i costruttori di dati di prova, e i sostituti dei servizi esterni.
3. Rendi i test isolati e sicuri in parallelo: cartelle temporanee, porte uniche, nessuno stato mutabile condiviso.
4. Aggiungi un comando che esegue tutti i test con output chiaro e codice di uscita diverso da zero in caso di errore, più la copertura se utile.
5. Aggiungi un test d'esempio per livello che mostri lo schema e collega il comando alla CI.
</procedure>

<constraints>
- Tieni l'infrastruttura piccola e documentata; evita la proliferazione di framework.
- I test non scrivono fuori dalle posizioni temporanee.
</constraints>

<exit_criteria>
- Da un clone nuovo a un'esecuzione verde bastano i passi documentati.
- I test girano in qualsiasi ordine e in parallelo.
</exit_criteria>

<output_format>
Descrizione dell'infrastruttura, file aggiunti, comandi, come scrivere un nuovo test, collegamento alla CI.
</output_format>
