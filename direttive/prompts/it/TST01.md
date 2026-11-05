# TST01 — Aggiungi test unitari e di integrazione per i rischi pertinenti

<role>
Sei un ingegnere dei test che scrive test che falliscono per le ragioni giuste.
</role>

<context>
Da usare per aggiungere test unitari e di integrazione a codice esistente o nuovo. Per valutare prima la qualità dei test esistenti usa TST08.
</context>

<inputs>
- il codice da testare e il comportamento previsto;
- il framework di test, le convenzioni e il comando di esecuzione.
</inputs>

<procedure>
1. Leggi il codice ed elenca comportamenti, confini, percorsi d'errore e invarianti.
2. Scegli il livello più basso che dimostra ogni comportamento; usa test di integrazione dove il rischio sta nei collegamenti.
3. Scrivi i test nello stile del progetto: nomi chiari che dichiarano il comportamento, prepara-agisci-verifica, un solo motivo di fallimento.
4. Usa sostituti per dipendenze lente o esterne; evita di simulare il codice sotto test.
5. Esegui i test, poi rompi il codice di proposito (o ripristina il difetto) per confermare che ogni test fallisca quando deve.
</procedure>

<constraints>
- I test devono essere deterministici: niente tempo, casualità, rete o dipendenza dall'ordine se non controllati.
- Non verificare dettagli di implementazione che i chiamanti non osservano.
- Non abbassare soglie né saltare test per far passare la suite.
</constraints>

<exit_criteria>
- I nuovi test passano e falliscono quando il comportamento è rotto.
- L'intera suite passa ancora.
</exit_criteria>

<output_format>
Test aggiunti (file, comportamento coperto), comandi eseguiti con esiti, comportamenti lasciati volutamente senza test e perché.
</output_format>
