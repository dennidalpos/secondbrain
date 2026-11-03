# OPS06 — Prepara hotfix e rollback di un rilascio con verifica e comunicazione

> **Scope**: repo | **Modalità**: scrittura | **Cosa serve**: rilascio difettoso, versione precedente nota e criteri per tornare indietro | **Esempio d'uso**: `prepara l'hotfix e il rollback per il rilascio 2.3.1`

## Scopo

Preparare e verificare la correzione urgente di un rilascio difettoso (hotfix) e il ritorno alla versione precedente (rollback), con criteri di decisione, passi reversibili e comunicazione.

## Quando usarlo

Quando un rilascio già distribuito causa un difetto grave e occorre scegliere tra correggere in avanti e tornare indietro. Per le normali note di rilascio usa OPS04, per i pacchetti OPS01, per diagnosticare la causa COM05.

## Input

Rilascio difettoso e sintomi, versione precedente stabile nota, strategia di distribuzione, modifiche incluse nel rilascio, eventuali migrazioni di dati o schema già applicate e le persone da avvisare.

## Attività specifiche

Verifica la portata del difetto e confronta i costi di hotfix e rollback: tempo, rischio, migrazioni irreversibili, compatibilità dei dati e dipendenze rilasciate insieme. Per il rollback elenca i passi in ordine, i punti di non ritorno e la verifica dello stato dopo il ritorno (per esempio `git revert` dei commit già pubblicati invece di riscrivere la cronologia). Per l'hotfix parti dalla versione rilasciata, limita la modifica alla correzione, aggiungi un test che riproduce il difetto (DEV02) e prepara la versione correttiva con numerazione coerente (SemVer). Prepara il testo della comunicazione e le note (OPS04). Non eseguire distribuzioni, push, tag o rilasci senza una richiesta esplicita.

## Decisioni da raccogliere

- hotfix o rollback;
- versione di destinazione e perimetro della correzione;
- canali e destinatari della comunicazione;
- conferma prima di ogni passo irreversibile o che tocca ambienti condivisi.

## Verifiche

Confronta il piano con la cronologia reale di rilasci e commit, verifica che i passi siano ordinati, reversibili dove possibile e provabili in un ambiente non di produzione, e che la versione correttiva sia compatibile con i dati già scritti. Dichiara ciò che non si può verificare prima della distribuzione.

## Consegna

Decisione motivata, piano passo per passo con evidenze di verifica e punti di non ritorno, il comando di modifica o di rollback proposto, una bozza della comunicazione e delle note, rischi residui. Nessuna distribuzione eseguita.

## Prompt vicini

- OPS04: Prepara note di rilascio e controlli di consegna.
- OPS01: Prepara e verifica pacchetti e artefatti distribuibili.
- DEV02: Riproduci un difetto e correggine la causa.
- OPS05: Prepara commit e pull request con perimetro, messaggio e controlli verificati.
