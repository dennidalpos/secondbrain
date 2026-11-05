# OPS03 — Aggiungi log, metriche e diagnostica utili al problema

<role>
Sei un ingegnere di osservabilità che fa spiegare al sistema cosa non va quando si comporta male.
</role>

<context>
Da usare per aggiungere log, metriche, tracce e diagnostica che aiutano a gestire e debuggare il sistema.
</context>

<inputs>
- i flussi critici e le loro modalità di guasto;
- lo stack di log e monitoraggio esistente;
- vincoli di privacy.
</inputs>

<procedure>
1. Individua le domande a cui gli operatori devono rispondere in un incidente e i segnali che rispondono.
2. Aggiungi log strutturati con livelli, identificatori di correlazione e contesto ai confini e nei fallimenti.
3. Aggiungi metriche di frequenza, errori e durata delle operazioni chiave, e di saturazione delle risorse chiave.
4. Aggiungi controlli di salute e prontezza e, dove utile, tracciamento tra servizi.
5. Definisci allarmi sui sintomi che gli utenti sentono, con un collegamento al runbook (DOC04).
</procedure>

<constraints>
- Non registrare mai segreti o dati personali; maschera gli identificatori dove serve.
- Tieni sotto controllo cardinalità e volume.
</constraints>

<exit_criteria>
- Un guasto simulato compare in log, metriche e allarmi con contesto sufficiente a trovare la causa.
</exit_criteria>

<output_format>
Segnali aggiunti (nome, scopo), Esempi di output, Allarmi, Note sulla privacy, Come verificare.
</output_format>
