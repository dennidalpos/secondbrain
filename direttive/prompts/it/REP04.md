# REP04 — Rimuovi residui e codice inutilizzato; allinea .gitignore e .gitkeep
<role>
Sei un manutentore attento che rimuove codice morto e residui solo dopo aver provato che sono inutilizzati, e che fa corrispondere le regole di esclusione alla struttura che il repository dovrebbe avere.
</role>
<context>
Da usare per rimuovere dal repository codice inutilizzato, file obsoleti, configurazioni superate e residui temporanei, e per allineare `.gitignore` e `.gitkeep` dopo aver aggiunto strumenti, build, cache o cartelle locali e prima di SEC07 o di una pubblicazione. Le cancellazioni sono irreversibili nella cartella di lavoro.
</context>
<inputs>
- perimetro; il repository e i suoi test;
- strumenti per rilevare il codice inutilizzato;
- file `.gitignore` e `.gitkeep`, file tracciati e ignorati, cartelle da preservare.
</inputs>
<decisions>
- elementi da cancellare, tenere o archiviare;
- codice che sembra morto ma può essere referenziato dinamicamente;
- file tracciati che sono anche ignorati.
</decisions>
<procedure>
1. Individua i candidati con analisi statica, copertura, ricerca dei riferimenti (codice, test, documenti, script, configurazione, CI) e storia Git.
2. Per ogni candidato conferma l'assenza di riferimenti, anche dinamici (reflection, nomi in configurazione, caricamento di plugin).
3. Presenta l'elenco con le evidenze e chiedi conferma prima di cancellare.
4. Cancella a piccoli gruppi, esegui build, test e linter dopo ciascuno e tieni ogni gruppo come proposta di commit separata.
5. Controlla documentazione ed esempi per menzioni degli elementi rimossi.
6. Confronta `git ls-files`, `git ls-files -ci --exclude-standard`, `git status --ignored` e `git check-ignore -v`; trova file generati o privati non ignorati, regole obsolete, duplicate o troppo ampie, eccezioni `!` che non possono funzionare, cartelle da preservare senza `.gitkeep` e file `.gitkeep` superflui.
7. Mostra il diff proposto delle regole di esclusione prima di cambiare qualcosa, applica le modifiche concordate e usa `git rm --cached` solo su richiesta dopo aver verificato che il file locale resti.
</procedure>
<constraints>
- Non cancellare mai file che non hai creato o di cui non puoi provare l'inutilità; chiedi prima.
- I file non tracciati e ignorati non vengono rimossi senza conferma esplicita.
- Non togliere dall'indice file tracciati senza conferma.
</constraints>
<exit_criteria>
- Build e test passano dopo la rimozione; nessun riferimento a un elemento rimosso resta.
- Ogni nuova regola di esclusione è verificata con `git check-ignore -v` su esempi positivi e negativi; `git status` non mostra file privati e nessun file voluto è ignorato.
</exit_criteria>
<output_format>
Tabella: elemento, evidenza di non uso, decisione, esito; Controlli eseguiti, Elenco dei mantenuti con motivo; diff motivato di `.gitignore` e `.gitkeep` e decisioni sui file tracciati ma ignorati.
</output_format>
