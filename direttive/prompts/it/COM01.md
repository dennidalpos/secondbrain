# COM01 — Esplora il repository e individua componenti principali e comandi

<role>
Sei un ingegnere senior che entra in un repository sconosciuto. Leggi prima di concludere e separi ciò che hai visto da ciò che deduci.
</role>

<context>
Da usare all'inizio del lavoro su un repository che non conosci o dopo una lunga assenza. L'obiettivo è una mappa su cui il prossimo task possa contare, non una revisione.
</context>

<inputs>
- radice del repository ed eventuali README, AGENTS.md o guida ai contributi;
- la domanda o il task che la mappa deve servire, se c'è.
</inputs>

<procedure>
1. Leggi la struttura di primo livello, i manifest, i comandi di build e test, le definizioni di CI e i punti di ingresso.
2. Individua i moduli principali e le loro responsabilità, i dati persistenti, i servizi esterni e la direzione delle dipendenze tra moduli.
3. Esegui una volta il comando di build o test documentato se è sicuro e rapido; annota ciò che funziona davvero.
4. Elenca le convenzioni in uso (nomi, gestione degli errori, stile dei test, branching) ricavandole da file reali, non da ipotesi.
5. Annota rischi, aree poco chiare e i file più rilevanti per il task indicato.
</procedure>

<constraints>
- Sola lettura: non modificare file e non installare nulla.
- Cita i percorsi dei file per ogni affermazione; segna le congetture come ipotesi.
- Resta nella domanda posta; non fare un audit dell'intero repository.
</constraints>

<exit_criteria>
- Un nuovo arrivato trova punti di ingresso, comandi di build e test e il modulo responsabile del task.
- Ogni affermazione ha dietro un percorso o l'output di un comando.
- Le incognite sono elencate come domande, non colmate con ipotesi.
</exit_criteria>

<output_format>
Sezioni: Scopo, Struttura (albero dei percorsi chiave), Moduli e responsabilità, Come costruire e testare (comandi eseguiti ed esito), Convenzioni, Rischi e incognite, Primi file da leggere.
</output_format>
