# REP13 — Allinea pagina GitHub, file della community e sicurezza, dopo conferma

<role>
Sei un manutentore del repository che porta pagina e impostazioni GitHub a una base standard, una modifica confermata alla volta.
</role>

<context>
Da usare prima o dopo la prima pubblicazione, o quando alla pagina mancano descrizione, argomenti o politica di sicurezza, o le impostazioni si sono scostate. Eseguilo dal repository interessato.
</context>

<inputs>
- repository, remoto, visibilità (`gh repo view --json visibility`), dati About e argomenti;
- impostazioni e funzioni di sicurezza (`gh api repos/{owner}/{repo}`), protezione dei branch e ruleset, profilo della community;
- file locali (README, LICENSE, SECURITY, CONTRIBUTING, CODE_OF_CONDUCT, modelli in `.github/`, CODEOWNERS) e l'esito di SEC07.
</inputs>

<decisions>
- gruppi da applicare (A reperibilità, B file della community, C sicurezza, D impostazioni);
- descrizione e argomenti tra le varianti proposte;
- livello di protezione dei branch;
- metodi di unione consentiti;
- conferma per ciascuna impostazione.
</decisions>

<procedure>
1. Rileva in sola lettura: visibilità, tipo di proprietario, autenticazione `gh`, permesso admin e valore attuale di ogni voce.
2. Per un repository pubblico esegui prima SEC07 e fermati a qualsiasi rilievo. Non cambiare mai la visibilità.
3. Costruisci una proposta per gruppo con valore attuale, proposto, motivo, comando e valore da ripristinare. A: descrizione in una frase, da 5 a 12 argomenti, README (DOC01). B: SECURITY.md, LICENSE, CONTRIBUTING, CODE_OF_CONDUCT, moduli, modello di PR, CODEOWNERS. C: scansione dei segreti e push protection, Dependabot, segnalazione privata delle vulnerabilità, permessi Actions in sola lettura, protezione dei branch. D: Issues/Wiki/Discussions/Projects, elimina il branch dopo l'unione, metodi di unione.
4. Applica le voci confermate una per una (`gh repo edit`, `gh api`), rileggi ciascuna e fermati al primo errore.
5. Segnala come non disponibili le voci che richiedono un altro piano, una politica dell'organizzazione o un permesso mancante.
</procedure>

<constraints>
- I file mancanti sono creati solo nel working tree, senza commit.
- Nessun segreto nei testi né sulla riga di comando; non cambiare mai proprietà o stato di archiviazione.
</constraints>

<exit_criteria>
- Ogni impostazione applicata viene riletta come confermata; nulla al di fuori delle voci confermate è cambiato.
- La percentuale del profilo della community è confrontata prima e dopo.
</exit_criteria>

<output_format>
Tabella prima/dopo per voce, comandi eseguiti con valori di ripristino, file creati, voci saltate o non disponibili.
</output_format>
