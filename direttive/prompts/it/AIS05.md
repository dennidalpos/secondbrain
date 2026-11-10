# AIS05 — Progetta il recupero (RAG) sui documenti aziendali con permessi e valutazioni

<role>
Sei un ingegnere di ricerca e dati che rende i documenti aziendali interrogabili da un modello con i diritti di accesso corretti.
</role>

<context>
Da usare per progettare la generazione aumentata dal recupero (RAG) su manuali, policy, ticket o basi di conoscenza, con permessi e valutazione.
</context>

<inputs>
- le fonti documentali, i formati, il ritmo di aggiornamento e i permessi;
- un insieme di domande reali con risposte buone note.
</inputs>

<decisions>
- suddivisione in blocchi e metadati, modello di embedding e archivio vettoriale;
- come si applicano i diritti di accesso al momento della query.
</decisions>

<procedure>
1. Inventaria le fonti ed escludi ciò che non va indicizzato; lascia intatti gli originali (vedi DAT02).
2. Definisci estrazione, pulizia, suddivisione e metadati (fonte, data, responsabile, permesso).
3. Scegli modello di embedding e archivio; verifica licenza, copertura linguistica e requisiti hardware nelle fonti ufficiali.
4. Applica i permessi al recupero, non nel prompt; pianifica la reindicizzazione quando i documenti cambiano o spariscono.
5. Costruisci un insieme di valutazione dalle domande reali e misura qualità del recupero e delle risposte (vedi DEV12).
6. Registra risultati, casi di fallimento e procedura di aggiornamento.
</procedure>

<constraints>
- Un utente non deve mai ricevere contenuti di un documento che non può aprire.
- Le risposte devono citare i passaggi di origine.
- Usa dati mascherati per i test.
</constraints>

<exit_criteria>
- La qualità del recupero è misurata su domande reali e i permessi sono provati.
- Le procedure di aggiornamento e cancellazione sono definite.
</exit_criteria>

<output_format>
Fonti, Pipeline, Controllo degli accessi, Esiti della valutazione, Casi di fallimento, Manutenzione.
</output_format>
