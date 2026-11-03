# AUD01 — Esegui un audit completo del repository con un unico rapporto, anche esportato

> **Scope**: repo/area | **Modalità**: lettura | **Cosa serve**: accesso in lettura a repository, documentazione e strumenti di misura | **Esempio d'uso**: `audit completo del repository prima del rilascio`

## Scopo

Valutare architettura, qualità, sicurezza, dipendenze, prestazioni, test e documentazione in un solo passaggio, con rilievi verificati e priorità, e consegnare il risultato in un unico rapporto, esportato nel formato richiesto.

## Quando usarlo

Prima di un rilascio, di un passaggio di consegne o di una sessione di pianificazione, quando serve un quadro d'insieme e non un singolo controllo. L'esportazione vale anche per risultati già verificati di AUD02-AUD05, SEC01 o SEC04.

## Input

Perimetro e profondità richiesti, documentazione del repository ed eventuale backlog e, se si esporta, formato di output, destinatari e destinazione.

## Attività specifiche

Orchestra senza duplicare le schede specialistiche: usa AUD02 (metriche), AUD03 (architettura e debito), AUD04 (dipendenze), AUD05 (prestazioni), SEC01, SEC04 e SEC05 (sicurezza e dati sensibili), GOV01 (licenze), DEV08 (leggibilità) e TST05 (comportamento) solo per le dimensioni incluse nel perimetro. Lavora in sola lettura e, dove disponibili, con agenti paralleli per le dimensioni indipendenti. Unisci i rilievi, elimina i duplicati e confrontali con il backlog così da non ridefinire il lavoro già tracciato.

Esportazione, solo su richiesta: parti da un'unica struttura di dati (rilievi con identificatore, gravità, percorso, riga, evidenza e stato; metriche con metodo e data) da cui derivare ogni formato, senza reinterpretare i risultati. Formati: Markdown, JSON, HTML autonomo, CSV, SARIF 2.1.0 per i rilievi di analisi, DOCX, PDF e XLSX con gli strumenti disponibili. Scegli la destinazione con l'utente, fuori dal repository del prodotto salvo diversa richiesta, e non includere mai segreti, valori sensibili o percorsi privati: riporta hash e posizioni.

## Decisioni da raccogliere

- dimensioni da includere (scelta multipla);
- profondità: rapida o approfondita;
- esportazione: formato o formati, destinazione e gravità minima dei rilievi da includere.

## Verifiche

Ogni rilievo ha un'evidenza (file e riga, comando o misura) e una gravità; separa i fatti dalle ipotesi, dichiara le dimensioni non coperte e i controlli che non è stato possibile eseguire. L'analisi non modifica file del repository, backlog o note. Un file esportato viene aperto o validato (schema JSON o SARIF, righe e colonne del CSV, il documento si apre), i conteggi coincidono con la sorgente e i formati non verificabili sono dichiarati; un rapporto esistente non viene mai sovrascritto, si crea una nuova versione datata.

## Consegna

Un unico rapporto con sintesi, rilievi per dimensione ordinati per gravità, lacune di copertura e attività proposte; se richiesto, un file nel formato scelto con percorso, conteggi e limiti della conversione.

## Prompt vicini

- AUD02: Misura il repository con metriche riproducibili e individua gli hotspot.
- AUD03: Verifica architettura e debito tecnico non ancora tracciati.
- AUD04: Verifica le dipendenze: obsolete, vulnerabili, inutilizzate e licenze.
- AUD05: Verifica le prestazioni e trova i percorsi critici senza modificare il codice.
- SEC01: Rivedi modifiche o codice con rilievi concreti e riferimenti.
