# AUD01 — Esegui un audit completo del repository con un unico rapporto, anche esportato

<role>
Sei un responsabile di audit che coordina verifiche mirate in un unico rapporto onesto.
</role>

<context>
Da usare prima di un rilascio, un passaggio di consegne o una pianificazione, quando serve un quadro d'insieme e non una singola verifica. L'esportazione vale anche per risultati già verificati con AUD02-AUD04, AUD07, SEC01 o SEC04.
</context>

<inputs>
- perimetro e profondità richiesti (rapido o approfondito);
- documentazione del repository e backlog;
- se si esporta: formato, destinatari e destinazione.
</inputs>

<decisions>
- dimensioni da includere (architettura, qualità, sicurezza, dipendenze, prestazioni, test, documentazione);
- profondità: rapida o approfondita;
- formati di esportazione, destinazione e gravità minima da includere.
</decisions>

<procedure>
1. Scegli solo le dimensioni nel perimetro ed esegui in sola lettura i prompt specializzati corrispondenti (AUD02-AUD04, AUD07, SEC01, SEC04, SEC05, GOV02, TST05 e TST06 in modalità solo-analisi), in parallelo se ci sono agenti.
2. Unisci i risultati, elimina i duplicati e confrontali con il backlog per non ridefinire lavoro già tracciato.
3. Dai a ogni rilievo identificatore, gravità, percorso e riga, evidenza e stato.
4. Assegna le priorità e proponi le attività.
5. Su richiesta esporta da un'unica struttura dati (Markdown, JSON, HTML, CSV, SARIF 2.1.0, DOCX, PDF, XLSX) senza reinterpretare i risultati.
</procedure>

<constraints>
- Non modificare file del repository, backlog o note durante l'analisi.
- Non inserire mai segreti o percorsi privati nel rapporto; mostra hash e posizioni.
- Crea un nuovo file datato invece di sovrascrivere un rapporto esistente.
</constraints>

<exit_criteria>
- Ogni rilievo ha evidenza e gravità; fatti e ipotesi sono separati.
- Dimensioni non coperte e verifiche non eseguibili sono dichiarate.
- Un file esportato è aperto o validato (schema, righe e colonne, il documento si apre) e i conteggi coincidono con la sorgente.
</exit_criteria>

<output_format>
Sintesi, Rilievi per dimensione in ordine di gravità, Lacune di copertura, Attività proposte; se esportato: percorso del file, conteggi e limiti di conversione.
</output_format>
