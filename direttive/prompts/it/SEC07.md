# SEC07 — Controlla diff, repository e cronologia per dati sensibili prima di pubblicare

> **Scope**: repo | **Modalità**: verifica | **Cosa serve**: commit, indice, working tree e cronologia da pubblicare; destinazione | **Esempio d'uso**: `verifica che sia sicuro pubblicare prima del push`

## Scopo

Impedire che segreti, dati personali e residui privati raggiungano un remoto o un rilascio, controllando il diff che sta per essere inviato e, quando serve, l'intero repository e la sua cronologia.

## Quando usarlo

Prima di ogni push, pull request, rilascio o pubblicazione di un repository. Un controllo sul diff è il minimo; l'intero repository e la sua cronologia vengono qualificati alla prima pubblicazione, dopo importazioni o riscritture della cronologia e prima di un rilascio. Se i dati sono già sul remoto usa SEC08, per ripulirli SEC09.

## Input

Commit, indice e working tree da pubblicare (tag compresi), cronologia raggiungibile, destinazione e visibilità del remoto, strumenti di scansione disponibili ed eventuali eccezioni già concordate.

## Attività specifiche

Determina l'insieme esatto di commit e file che verrebbero inviati (per esempio `@{upstream}..HEAD` e i tag). Esegui controlli separati su working tree, indice e cronologia con gli strumenti disponibili (segreti con SEC04, dati personali con SEC05) e confronta il loro perimetro con l'insieme appena determinato. Controlla anche messaggi di commit, nomi di file, binari, screenshot e metadati, file ignorati aggiunti a forza, percorsi privati, indirizzi email non pubblici, licenze e contenuti deliberatamente pubblici. Riporta solo hash e posizioni, mai i valori.

Per i falsi positivi proponi eccezioni mirate (regola, percorso, impronta e motivo), mai intere categorie. Informazioni private e artefatti operativi non appartengono al repository pubblico.

## Decisioni da raccogliere

- remoto e visibilità della destinazione;
- azione per ciascun rilievo (correggere, accettare con un motivo, rimandare);
- conferma prima di qualsiasi intervento sulla cronologia o rotazione di credenziali.

## Verifiche

Distingui controlli eseguiti, falsi positivi giustificati, contenuto binario non qualificato e copertura limitata; non dichiarare una conformità generale sulla base di pattern testuali. Se un segreto è già in un commit locale, la cronologia locale va riscritta prima del push: non procedere. Nessun reset o cancellazione di lavoro locale e nessun push finché restano rilievi non valutati; spostare o ignorare un file non riscrive i commit.

## Consegna

Esito per commit (pronto, bloccato, da valutare), rilievi con posizione e azioni suggerite, decisioni motivate e lavoro rimasto; il push e la pubblicazione restano una scelta dell'utente.

## Prompt vicini

- SEC04: Trova le credenziali esposte e verifica la validazione degli input.
- SEC05: Verifica l'isolamento dei dati personali e la conformità a GDPR e policy.
- SEC08: Verifica se dati sensibili sono ancora raggiungibili sul remoto GitHub.
- OPS01: Prepara e verifica pacchetti e artefatti distribuibili.
- DOC01: Scrivi guide e README coerenti con il prodotto reale.
- SEC02: Analizza minacce, confini di fiducia e scenari di abuso.
- SEC09: Cancella cronologia e artefatti del remoto GitHub dopo un'esposizione di dati.
- REP10: Allinea .gitignore e .gitkeep alla struttura e ai file reali.
