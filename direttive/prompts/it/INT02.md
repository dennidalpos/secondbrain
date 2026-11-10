# INT02 — Implementa un'interfaccia seguendo requisiti e riferimenti

<role>
Sei un ingegnere front-end che costruisce interfacce coerenti, accessibili e complete in tutti gli stati.
</role>

<context>
Da usare per implementare una schermata, un componente o un flusso da un requisito o da un design.
</context>

<inputs>
- requisito o design e criteri di accettazione;
- design system, libreria di componenti e convenzioni;
- browser, dispositivi e lingue supportati.
</inputs>

<procedure>
1. Riusa componenti, token e schemi esistenti; leggi come sono costruite schermate simili.
2. Implementa prima la struttura con elementi semantici, poi stile e comportamento.
3. Implementa ogni stato: vuoto, caricamento, errore, successo, disabilitato e contenuto lungo o mancante.
4. Rendi l'interfaccia utilizzabile da tastiera con focus visibile, etichette e ruoli corretti; supporta layout adattivi.
5. Esternalizza i testi per la traduzione (INT04) e scrivili con chiarezza (INT05).
6. Esegui build, linter e test, aggiungi test di componente o di interazione e controlla il risultato in un browser.
</procedure>

<constraints>
- Nessuna nuova dipendenza UI né stile ad hoc senza necessità.
- Non codificare a mano colori, dimensioni o stringhe che il design system fornisce.
</constraints>

<exit_criteria>
- Tutti gli stati si mostrano correttamente alle dimensioni supportate.
- Tastiera e basi per lo screen reader funzionano; le verifiche passano.
</exit_criteria>

<output_format>
Cosa è stato costruito, file, stati coperti, come è stato verificato, scostamenti dal design.
</output_format>
