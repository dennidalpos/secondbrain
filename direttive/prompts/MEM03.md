# MEM03 — Chiudi la sessione: memorie, tracker, handoff e richiesta di commit e push

> **Scope**: repo/area | **Modalità**: scrittura | **Cosa serve**: stato git, verifiche superate e destinazione di consegna | **Esempio d'uso**: `sb prompt MEM03: chiudi la sessione e chiedi commit e push`

## Scopo

Consentire a un agente successivo di riprendere senza ricostruire il lavoro: memorie e tracker aggiornati, handoff verificabile, stato Git chiaro e richiesta esplicita di commit e push.

## Quando usarlo

A fine lotto, prima di cambiare sessione o consegnare lavoro parziale.

## Input

Obiettivo, autorizzazioni attuali, stato Git (branch, remoto, commit non pubblicati), modifiche, prove, impedimenti e decisioni dell'utente.

## Attività specifiche

Riconcilia stato effettivo e criteri di accettazione, poi nell'ordine:

1. **Memorie.** Aggiorna `context.md` (stato, vincoli, problemi aperti, prossimo passo) e `memory.md` (decisioni durevoli e gotcha) con la regola di sintesi minima: solo operazioni chiave e novità verificate, senza cronache ridondanti né autorizzazioni storiche rinnovate.
2. **Tracker.** Imposta lo stato dei task dopo aver verificato i criteri: chiudi solo ciò che è completo e provato, mantieni parziali e bloccati con stato e motivo, traccia i nuovi residui confermati senza duplicati e fuori dal lotto corrente.
3. **Handoff.** Salva nel dossier (`history/`) un rapporto con lavoro svolto, decisioni, comandi ed esiti, file utili, residui e primo passo; collega lo storico e il TOC senza duplicare cronache nell'avvio.
4. **Allineamento.** Esegui Sync e Check con la sessione di scrittura; riporta artefatti conservati e configurazione di output, senza pulizie non richieste.
5. **Stato Git.** Mostra `git status --ignored`, diff, branch, remoto e commit non pubblicati.
6. **Consegna.** Se commit e push non sono già autorizzati, chiedili esplicitamente; esegui solo ciò che l'utente ha approvato, in sequenza e senza ulteriore conferma finale quando entrambi sono stati richiesti. Prima del push verifica destinazione, visibilità, branch, perimetro e controlli (REP05); niente force push, reset o cancellazioni per ottenere un working tree pulito.

## Decisioni da raccogliere

Se più opzioni non sono ricavabili dal codice o dalle fonti, fermati e usa Function Calling o Tool Use a scelta multipla (es. `ask_question`, `AskUserQuestion`): una decisione per domanda, scelta raccomandata come prima opzione con `(Recommended)`, opzioni atomiche e non numerate; scelta multipla quando le opzioni non si escludono.

- commit: sì, no o solo alcuni file (scelta multipla sul perimetro);
- push: sì o no, remoto e branch di destinazione;
- task da chiudere, mantenere parziali o bloccare, e nuovi residui da tracciare (scelta multipla);
- informazioni da salvare in memoria come decisione o gotcha (scelta multipla);
- pulizie di artefatti: mai senza richiesta esplicita e perimetro concreto.

Senza lo strumento, elenca opzioni numerate e attendi la risposta. Non richiedere di nuovo ciò che è già autorizzato nel perimetro del task.

## Verifiche

Verifica percorsi, diff e attività incomplete; accerta che context, memory e tracker dicano lo stesso stato e che i criteri dei task chiusi siano provati. Distingui autorizzazioni attuali e cronologia: un handoff non rinnova permessi né costituisce commit o pubblicazione.

## Consegna

Handoff nel dossier, memorie e tracker aggiornati, stato dei controlli, esito di commit e push (o richiesta in sospeso) e primo passo riproducibile per la ripresa in una nuova sessione.

## Prompt vicini

- PRG04: Prepara un piano per fasi con dipendenze e verifiche.
- MEM01: Allinea istruzioni locali, contesto, memoria e tracker.
- SYS04: Controlla o allinea gli asset già gestiti della postazione.
