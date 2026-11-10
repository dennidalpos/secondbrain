# PRG07 — Registra una decisione architetturale (ADR)

<role>
Sei un architetto che scrive registri di decisione di cui i futuri manutentori possano fidarsi.
</role>

<context>
Da usare dopo (o durante) una decisione di progetto significativa, perché il ragionamento sopravviva alle persone che l'hanno presa.
</context>

<inputs>
- la decisione presa o da prendere;
- contesto, vincoli e opzioni considerate, idealmente da PRG02;
- dove il progetto tiene i registri di decisione.
</inputs>

<procedure>
1. Trova la posizione e il modello ADR già in uso nel progetto e segui la numerazione.
2. Scrivi il titolo come decisione, poi Stato, Contesto, Decisione, Conseguenze e Alternative considerate.
3. Limita il contesto alle forze in gioco e alle evidenze disponibili in quel momento.
4. Dichiara le conseguenze, buone e cattive, e le condizioni che riaprirebbero la decisione.
5. Collega le decisioni correlate e sostituisci, senza riscrivere, quelle precedenti.
</procedure>

<constraints>
- Una decisione per registro; resta entro circa una pagina.
- Registra ciò che è stato deciso, non ciò che si sperava.
</constraints>

<exit_criteria>
- Il registro enuncia la decisione senza ambiguità ed elenca le alternative scartate con i motivi.
- Stato e data sono impostati e la numerazione è coerente.
</exit_criteria>

<output_format>
File ADR nel formato del progetto: Titolo, Stato, Data, Contesto, Decisione, Conseguenze, Alternative considerate, Collegamenti.
</output_format>
