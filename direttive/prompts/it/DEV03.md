# DEV03 — Rifattorizza il codice preservando i contratti: mirato, a fasi o periodico

> **Scope**: repo/area | **Modalità**: scrittura | **Cosa serve**: codice da migliorare, test esistenti e perimetro dell'intervento | **Esempio d'uso**: `estrai la gestione delle transazioni in un modulo dedicato`

## Scopo

Ridurre complessità, duplicazione e codice morto e rendere il codice leggibile per chi arriva nuovo, senza cambiare il comportamento richiesto né i contratti pubblici.

## Quando usarlo

Per duplicazione, responsabilità confuse, una superficie pubblica non dichiarata o codice difficile da leggere: mirato su un componente, a fasi sull'intero perimetro (dopo DEV08, AUD02 o AUD03, o per un passaggio di consegne) oppure come manutenzione periodica dopo una serie di modifiche su più moduli. Per rivedere senza modificare usa DEV08; per pianificare una ristrutturazione architetturale PRG06; per le prestazioni TST06; per migrare a una nuova versione DEV05.

## Input

Perimetro (componente, modulo o repository), modalità (mirata, a fasi o periodica), convenzioni del repository, build e test verdi, contratti pubblici e invarianti osservabili, modifiche recenti (Git).

## Attività specifiche

Parti da build e test verdi; se mancano, scrivi prima test di caratterizzazione (TST01). Individua chiamanti, dipendenze e copertura. Lavora per piccoli lotti indipendenti, un modulo e una modifica alla volta: nomi che esprimono l'intento, funzioni brevi con una sola responsabilità, duplicazione eliminata, condizioni semplificate, gestione degli errori coerente, commenti che spiegano il perché.

Nella manutenzione periodica cerca anche funzioni con lo stesso scopo in moduli diversi (confronta il comportamento prima di unificarle), funzioni mai chiamate dal codice di produzione o usate solo dai test, una superficie pubblica esposta senza elenco esplicito, parametri e rami morti, flussi con diramazioni annidate o effetti nascosti. Unifica sulla versione corretta, sposta il codice usato solo dai test nei test, rendi esplicita la superficie esportata e rimuovi il codice morto solo dopo aver verificato i riferimenti (REP04).

Segui le convenzioni esistenti senza introdurne di nuove, non aggiungere astrazioni senza un uso concreto e non cambiare alcun contratto pubblico senza una decisione esplicita. Un lotto corrisponde a un commit logico proposto, mai mescolato con modifiche funzionali.

## Decisioni da raccogliere

- modalità, perimetro e ordine dei moduli;
- soglie di leggibilità (per esempio lunghezza massima delle funzioni) e granularità dei commit per lotto;
- quale versione mantenere quando funzioni duplicate divergono;
- quali funzioni appartengono alla superficie pubblica e vanno esportate;
- rimozione o mantenimento di codice che sembra morto ma ha riferimenti dinamici.

## Verifiche

Dopo ogni lotto esegui build, test e linter; confronta contratti pubblici e output prima e dopo e cerca riferimenti rimasti a nomi rinominati o rimossi (codice, test, documentazione, esempi). Fermati e annulla il lotto se il comportamento cambia; segnala gli invarianti non coperti dai test.

## Consegna

Modifiche eseguite con la motivazione, duplicati unificati, superficie esportata, codice rimosso o spostato, contratti preservati ed evidenze di equivalenza, metriche prima e dopo (AUD02) se disponibili, e residui che richiedono una decisione.

## Prompt vicini

- DEV05: Migra codice o un framework verso un obiettivo definito.
- REP04: Rimuovi residui e codice inutilizzato dopo la verifica.
- TST06: Misura e ottimizza prestazioni e risorse: un collo di bottiglia o molti moduli.
- DEV08: Rivedi leggibilità, coerenza e manutenibilità senza modificare il codice.
- PRG06: Pianifica un refactoring architetturale a fasi con controlli e rollback.
