# Istruzioni del repository: <Nome>

Revisione 1.0 — 2026-11-04. Vincoli specifici del progetto; i contenuti comuni sono gestiti separatamente.

Modello da compilare soltanto con informazioni verificate; omettere le sezioni non pertinenti.

## Contesto
- Scopo e utenti del progetto.
- Stack, versioni e ambienti effettivi: riferimenti ai manifest e lockfile.
- Confini architetturali e invarianti che non sono immediatamente evidenti dal codice.

## Lavoro e verifiche
- Comandi realmente presenti: prerequisiti, directory, shell e criterio di successo.
- Controlli richiesti prima di una consegna o di un commit, se definiti dal progetto.
- Vincoli specifici su compatibilità, dati, release e collaborazione Git.

## Riferimenti e collaborazione
- Consultare README e documentazione effettivamente presenti; versioni dai manifest/lockfile, non da ipotesi sullo stack.
- `02-areas/products/<Nome>/memory.md` e `02-areas/products/<Nome>/context.md` (nel dossier SecondBrain) conservano decisioni tecniche durevoli, gotcha e architettura; aggiornarli nei task di scrittura solo con novità pertinenti e verificate.
- Collegamenti al tracker (`tracker.json` o `02-areas/products/<Nome>/tracker.md`) e a direttive annidate, se presenti.
- Nei task di scrittura rimuovere temporanei del task e residui confermati preservando dati e lavoro unico. Sincronizzare SecondBrain dopo modifiche a dossier o direttive, oppure su richiesta; nelle sole analisi segnalare i residui preesistenti senza rimuoverli.
- A chiusura del task verificare i criteri di accettazione, aggiornare il tracker del dossier (`tracker.json`) e verificare che i task completati o annullati siano archiviati nello storico con ID, dipendenze e prove, registrare decisioni durevoli in `memory.md`, aggiornare `context.md` ed eseguire la sincronizzazione SecondBrain.

Non copiare esempi di altri stack come comandi operativi. Non attribuire automaticamente una modalità Greenfield, obblighi normativi o un workflow Git. Il blocco SecondBrain gestito viene aggiunto separatamente da `secondbrain.ps1 -Sync`.
