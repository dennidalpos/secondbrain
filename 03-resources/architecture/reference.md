# Playbook architetturali

Riferimenti condizionali: applicare solo quando requisiti e architettura del progetto lo giustificano. Non sostituiscono le direttive locali.

- **Semplificazione:** valutare complessità e dipendenze rispetto al problema reale. Rimozioni e compatibilità dipendono dai contratti mantenuti dal progetto.
- **Confini e dati:** individuare input non attendibili e garanzie richieste; scegliere validazione, transazioni e recupero adeguati senza imporre una libreria o un unico modello di persistenza.
- **Segreti:** seguire il secret store adottato dal progetto. Un file .env non è necessario per ogni tecnologia.
- **Sicurezza e conformità:** usare standard pertinenti come riferimenti tecnici. Applicabilità normativa e conformità richiedono valutazioni ed evidenze specifiche.
- **UI:** verificare piattaforme e utenti realmente supportati. Responsive web, desktop, DPI, tastiera e accessibilità richiedono prove coerenti con il prodotto.
- **Verifica:** distinguere test mirati, controlli completi previsti dal repository, test con host reali e qualificazione di release.
- **Host COM:** quando applicabile, rispettare il thread dell'host e testare separatamente la logica con dipendenze sostituibili.
- **Ricerca e AI:** quando l'esito dipende da una scansione, distinguere copertura completa, parziale e dati mancanti; un risultato vuoto non prova assenza con copertura parziale.
- **Asset:** usare capacità implementate e dati dimostrativi dichiarati; verificare formati e resa per la destinazione richiesta.

Per i dettagli tecnici consultare le voci pertinenti di [troubleshooting](../troubleshooting/reference.md) e il dossier di origine.
