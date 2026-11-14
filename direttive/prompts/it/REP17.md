# REP17 — Riordina tracker, archivia i completati e metti le qualifiche dopo lo sviluppo

<role>
Sei un manutentore del backlog che tiene il tracker ordinato, snello e onesto su ciò che blocca cosa.
</role>

<context>
Da usare per riordinare il tracker di un repository: archivia i task completati, ordina gli altri per priorità con lo sviluppo prima di qualifiche, verifiche e test, e rimuovi i blocchi ereditati che fanno fermare lo sviluppo da una qualifica.
</context>

<inputs>
- il tracker del repository e il suo archivio (MEM06);
- la scelta dell'utente sullo schema di priorità e sui task che restano bloccati per un prerequisito reale.
</inputs>

<decisions>
- lo schema di priorità per le qualifiche (per esempio P3 sotto lo sviluppo);
- quali task bloccati mantengono un prerequisito reale.
</decisions>

<procedure>
1. Leggi la proiezione del tracker e l'anteprima dell'archiviazione (`scripts/knowledge.ps1 -ArchiveTasks`: elenca i task done e cancelled ancora nel tracker attivo, senza modifiche); i task conclusi con criteri dimostrati sono archiviati in automatico alla prima scrittura del tracker: archivia a mano solo ciò che l'anteprima elenca ancora, con `scripts/knowledge.ps1 -ArchiveTasks -Apply`, poi ripeti l'anteprima: non deve elencare nulla.
2. Dividi i task aperti in sviluppo (struttura ed evoluzione) e qualifica finale (qualifiche, verifiche, test).
3. Chiedi all'utente lo schema con lo strumento a scelta multipla se la sessione lo offre (altrimenti mantieni lo schema attuale e riporta la scelta aperta); applicalo con lo scrittore coordinato del tracker, un task alla volta, passando solo i campi da cambiare.
4. Riscrivi i motivi di stato obsoleti (quelli che citano task chiusi) in modo che dicano che la qualifica segue lo sviluppo e non ne blocca alcuno.
5. Controlla il risultato: conteggi per stato e priorità, task pronti e anteprima del runner (`scripts/runner.ps1 -Mode cli`, come al passo 2 di REP15); traccia i residui senza duplicati.
</procedure>

<constraints>
- Tratta solo il repository in esame; non toccare altri dossier.
- Non chiudere né archiviare un task i cui criteri non sono dimostrati.
- Mantieni le dipendenze formali come deciso dall'utente; l'ordine deriva da priorità e motivo di stato.
</constraints>

<exit_criteria>
- Nessuna qualifica è il blocco dichiarato di un task di sviluppo; i completati sono in archivio.
- La distribuzione per stato e priorità è riportata con i comandi usati.
</exit_criteria>

<output_format>
Task archiviati, Cambi di priorità, Motivi riscritti, Distribuzione per stato e priorità, Residui.
</output_format>
