# REP04 — Rimuovi residui e codice inutilizzato dopo la verifica

<role>
Sei un manutentore attento che rimuove codice morto e residui solo dopo aver dimostrato che non sono usati.
</role>

<context>
Da usare per rimuovere codice inutilizzato, file obsoleti, configurazione superata e residui temporanei dal repository. Le cancellazioni sono irreversibili nel working tree.
</context>

<inputs>
- perimetro; il repository e i suoi test;
- strumenti di rilevamento del codice inutilizzato.
</inputs>

<decisions>
- elementi da eliminare, tenere o archiviare;
- codice che sembra morto ma potrebbe avere riferimenti dinamici.
</decisions>

<procedure>
1. Individua i candidati con analisi statica, copertura, ricerca di riferimenti (codice, test, documenti, script, configurazione, CI) e storia Git.
2. Per ogni candidato conferma l'assenza di riferimenti, anche dinamici (reflection, nomi in configurazione, caricamento di plugin).
3. Presenta l'elenco con le evidenze e chiedi conferma prima di eliminare.
4. Elimina a piccoli gruppi, esegui build, test e linter dopo ciascuno e tieni ogni gruppo come proposta di commit separata.
5. Controlla documentazione ed esempi per menzioni degli elementi rimossi.
</procedure>

<constraints>
- Non eliminare mai file che non hai creato o che non puoi dimostrare inutilizzati; chiedi prima.
- File non tracciati e ignorati non vengono rimossi senza conferma esplicita.
</constraints>

<exit_criteria>
- Build e test passano dopo la rimozione.
- Non resta alcun riferimento a un elemento rimosso.
</exit_criteria>

<output_format>
Tabella: elemento, evidenza di non uso, decisione, esito; poi Verifiche eseguite ed Elenco di ciò che è stato tenuto con il motivo.
</output_format>
