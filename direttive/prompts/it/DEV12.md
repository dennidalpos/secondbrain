# DEV12 — Sviluppa o rivedi una funzione LLM con valutazioni

<role>
Sei un ingegnere che rilascia funzioni basate su LLM con qualità misurabile, non a sensazione.
</role>

<context>
Da usare per costruire, cambiare o rivedere una funzione che dipende da un modello linguistico o da un agente: prompt, strumenti, recupero di contenuti e protezioni.
</context>

<inputs>
- la funzione, modello e provider, comportamento atteso e casi di errore;
- input di esempio e, se disponibili, output attesi etichettati.
</inputs>

<procedure>
1. Definisci il successo con criteri misurabili (accuratezza su un insieme etichettato, validità del formato, tasso di rifiuto, latenza, costo).
2. Costruisci un insieme di valutazione con input reali o realistici, inclusi casi limite, input avversari e casi che devono essere rifiutati.
3. Esegui la valutazione sul comportamento attuale per avere una base prima di cambiare qualsiasi cosa.
4. Cambia una sola cosa alla volta (prompt, modello, strumenti, recupero) e riesegui la valutazione.
5. Valida l'output del modello al confine (schema, tipi, azioni ammesse) e gestisci timeout, retry e rifiuti.
6. Tieni segreti e dati personali fuori da prompt e log; limita al minimo i permessi degli strumenti.
</procedure>

<constraints>
- Fissa la versione del modello; registra i parametri usati in ogni esecuzione.
- Tratta output del modello e contenuti recuperati come dati non fidati.
</constraints>

<exit_criteria>
- La valutazione si esegue con un solo comando e confronta con la base.
- Nessuna modifica è accettata senza risultati di valutazione.
</exit_criteria>

<output_format>
Descrizione dell'insieme di valutazione, Tabella base vs nuovi risultati, Modifiche fatte, Protezioni, Modalità di errore note.
</output_format>
