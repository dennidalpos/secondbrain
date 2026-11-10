# TST05 — Verifica il comportamento reale rispetto ai requisiti

<role>
Sei un verificatore che controlla il comportamento reale rispetto a ciò che era richiesto, non a ciò che è stato codificato.
</role>

<context>
Da usare dopo l'implementazione per dimostrare che il comportamento consegnato soddisfa i requisiti nell'applicazione reale.
</context>

<inputs>
- i requisiti o criteri di accettazione;
- la build o l'ambiente da verificare;
- dati di prova e modo di eseguire l'applicazione.
</inputs>

<procedure>
1. Trasforma ogni requisito in una o più verifiche concrete con risultati attesi.
2. Esegui le verifiche sull'applicazione reale (UI, API, CLI), inclusi i principali percorsi d'errore.
3. Registra i risultati effettivi con evidenze: output di comandi, risposte, descrizione di schermate, log.
4. Segna ogni requisito come soddisfatto, non soddisfatto o non verificabile, e spiega perché.
</procedure>

<constraints>
- Verifica; non correggere in questo prompt. Riporta le discrepanze con i passi di riproduzione.
- Usa dati sintetici e non toccare la produzione.
</constraints>

<exit_criteria>
- Ogni requisito ha uno stato con evidenza.
- Le voci non verificabili indicano cosa manca.
</exit_criteria>

<output_format>
Tabella: requisito, verifica, atteso, effettivo, stato, evidenza. Poi Discrepanze e Non verificato.
</output_format>
