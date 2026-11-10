# Proposta: riepilogo minimo alla chiusura (#245)

Stato: **proposta non approvata, non distribuita**. Origine: `github.com/dennidalpos/secondbrain`, TASK-245. Revisione proposta **1.3**, versione proposta **1.3.0**, entrambe da confermare. Le altre regole previste da #255 restano fuori da questa proposta.

## Problema ed evidenze

La chiusura di un task non ricordava gli aggiornamenti di memoria e contesto. `Set-SBTrackerTaskStatus` ora restituisce `closureAdvice` per `done` e registra `extensions.lastClosure` nelle nuove transizioni. Check confronta il tempo della chiusura con l'ultima scrittura di `memory.md` ed emette il solo avviso `closure-memory-pending`. MEM03 offre la scelta del riepilogo in italiano e inglese.

Le prove riproducibili sono nella suite `scripts/test-secondbrain-portable.ps1`: CLI, anteprima senza scritture, avviso bilingue, aggiornamento memoria, ripetizione di `done`, riapertura e memoria mancante. Il confronto dei tempi è un segnale consultivo, non prova il contenuto né l'approvazione di una sintesi. Nessuna data è inventata per task già chiusi; la migrazione storica non è prevista.

## Testo minimo aggiunto

> A chiusura del task o lotto proponi con scelta multipla il riepilogo minimo aggiuntivo e la sua destinazione: decisione/gotcha in memory.md, rapporto in history/<data>-<slug>/report.md, oppure salta. Mostra contenuto e destinazione concreti; la scelta non sospende gli aggiornamenti obbligatori di tracker, memoria e contesto. Non trascrivere chat grezze o segreti e non leggere transcript_path.

## Applicabilità e controesempi

La regola si applica alla chiusura di un task o lotto nei repository gestiti, non a ogni risposta o consultazione. Una sintesi già salvata non si duplica. «Salta» riguarda soltanto il riepilogo aggiuntivo; non omette gli aggiornamenti obbligatori. Nessun hook legge o salva conversazioni. Nessuna impostazione IDE privata è modificata per aggirare le autorizzazioni.

## Approvazione e distribuzione

I due file candidati completi sono accanto a questo README; `hashes.json` lega basi e candidati ai byte SHA-256. Le sorgenti attive e `approved.json` restano invariate fino alla conferma.

Scelte da presentare dopo le verifiche:

1. Approvare testo e passaggio a 1.3.0: verificare nuovamente gli hash, aggiornare versione e riferimenti, applicare con `scripts/approve-revision.ps1 -ProposalPath direttive/proposals/2026-11-03-chiusura-riepilogo`, quindi Sync e Check su IDE e 22 repository gestiti.
2. Rinviare la direttiva e conservare codice e MEM03 alla versione 1.2.0: #245 resta parziale.
3. Rivedere il testo prima dell'approvazione.

L'approvazione della direttiva non autorizza commit o push, pulizia, compattazione o prove negli IDE reali.
