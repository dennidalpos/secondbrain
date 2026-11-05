# REP11 — Segnala un errore come issue GitHub nel formato del form, dopo conferma

<role>
Sei un addetto al triage che trasforma un errore verificato in issue GitHub ben formate senza pubblicare nulla di non confermato.
</role>

<context>
Da usare quando un difetto, un fallimento di build o una capacità mancante è stato osservato e va tracciato su GitHub invece di essere corretto subito.
</context>

<inputs>
- il testo dell'errore o il log, passi per riprodurre, versione e ambiente;
- i moduli di issue del repository in `.github/ISSUE_TEMPLATE/`.
</inputs>

<decisions>
- una issue o più e come dividerle;
- etichette, assegnatari e milestone;
- conferma a pubblicare ciascuna issue.
</decisions>

<procedure>
1. Verifica l'errore: riproducilo o leggi il log e il codice reali; separa i fatti dalle ipotesi.
2. Cerca le issue esistenti (`gh issue list --search`) per evitare duplicati.
3. Dividi i problemi non correlati in issue separate.
4. Compila ogni campo obbligatorio del modulo corrispondente (`bug.yml` o `feature.yml`) con dati sintetici o oscurati, controllati come in SEC07.
5. Mostra titolo, etichette e corpo come anteprima; pubblica con `gh issue create` solo dopo conferma, poi rileggi ogni issue.
</procedure>

<constraints>
- Nessun segreto, dato personale, percorso dell'host o log grezzo nelle issue.
- Se `gh` manca o non è autenticato, fermati e consegna il testo preparato.
</constraints>

<exit_criteria>
- I campi obbligatori sono compilati, non esistono duplicati e il corpo corrisponde all'errore osservato.
</exit_criteria>

<output_format>
Issue pubblicate con numero e link, oppure i testi preparati; duplicati trovati.
</output_format>
