# AIS04 — Realizza un chatbot con IA locale da inserire in un sito esistente

<role>
Sei uno sviluppatore full-stack che aggiunge un chatbot basato su un modello locale a un sito già esistente.
</role>

<context>
Da usare per inserire un assistente di supporto o vendita in un sito senza rifarlo. Il modello gira su infrastruttura aziendale; il widget parla solo con un backend che controlli.
</context>

<inputs>
- il sito esistente, il suo stack e i template di pagina da estendere;
- un endpoint di modello locale, le fonti di conoscenza e gli argomenti ammessi.
</inputs>

<decisions>
- stile e posizione del widget; risposte basate su documenti o libere;
- cosa il bot deve rifiutare e quando passa la mano a una persona.
</decisions>

<procedure>
1. Ispeziona il sito e scegli il punto di integrazione meno invasivo (tag script, componente o iframe).
2. Costruisci un backend sottile che custodisce le credenziali del modello, applica limiti di frequenza e registra senza dati personali.
3. Basa le risposte sulle fonti approvate (vedi AIS05) e scrivi un prompt di sistema con ambito, tono e regole di rifiuto.
4. Costruisci il widget con accessibilità, layout mobile, avviso che si tratta di un'AI e un passaggio chiaro a una persona.
5. Prova con domande reali e prompt ostili (iniezione, fuori tema, dati personali) e registra i risultati (vedi DEV12).
6. Documenta rilascio, monitoraggio e come spegnere il bot.
</procedure>

<constraints>
- Il browser non possiede mai chiavi del modello né accesso diretto ai sistemi interni.
- Mostra al visitatore che parla con un'AI e collega l'informativa privacy.
- Nessun commit o push senza richiesta esplicita.
</constraints>

<exit_criteria>
- Il widget funziona sul sito esistente con sola inferenza locale.
- I test ostili e fuori tema passano o i loro limiti sono registrati; esiste un interruttore di spegnimento.
</exit_criteria>

<output_format>
Punto di integrazione, Backend, Prompt e protezioni, Esiti dei test, Rilascio e interruttore.
</output_format>
