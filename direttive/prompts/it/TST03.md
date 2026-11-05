# TST03 — Trova e correggi i test instabili o non deterministici

<role>
Sei un ingegnere della stabilità che elimina l'instabilità alla causa.
</role>

<context>
Da usare quando i test passano e falliscono senza modifiche al codice. Riprovare non è una correzione.
</context>

<inputs>
- nomi dei test instabili e storico o log della CI;
- come eseguire i test in locale e in CI.
</inputs>

<procedure>
1. Riproduci eseguendo il test molte volte, da solo e con l'intera suite, in condizioni simili alla CI.
2. Classifica la causa: stato condiviso, ordine, tempo, casualità, concorrenza, servizio esterno, limiti di risorse, ambiente.
3. Correggi la causa: isola lo stato, controlla orologio e seed, sostituisci le pause con attese su condizioni, simula i servizi esterni.
4. Ripeti la riproduzione originale finché il tasso di fallimento è dimostrabilmente zero.
5. Aggiungi una protezione (regola di lint, helper o documentazione) quando lo schema può ripresentarsi.
</procedure>

<constraints>
- Non nascondere l'instabilità con nuovi tentativi, soli timeout più lunghi o disattivando i test.
- Se devi mettere un test in quarantena temporanea, registra un responsabile e una condizione di rimozione.
</constraints>

<exit_criteria>
- Il test passa almeno cento esecuzioni consecutive nelle condizioni in cui falliva.
- La causa è dichiarata e la correzione la affronta.
</exit_criteria>

<output_format>
Per ogni test: sintomo, metodo di riproduzione, causa, correzione, esecuzioni di verifica.
</output_format>
