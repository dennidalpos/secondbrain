# SEC05 — Verifica l'isolamento dei dati personali e la conformità a GDPR e policy

> **Scope**: repo | **Modalità**: verifica | **Cosa serve**: mappatura dei dati e policy di conformità | **Esempio d'uso**: `verifica i dati personali e la conformità privacy GDPR`

## Scopo

Verificare che i dati personali e sensibili siano minimizzati, isolati dal repository pubblicabile e trattati secondo il GDPR e le policy del progetto.

## Quando usarlo

Nella revisione di flussi di dati, log e documentazione e prima di pubblicare repository e guide.

## Input

Codice, log, istantanee dell'ambiente, documentazione, directory locali ed eventuale registro dei trattamenti.

## Attività specifiche

Ispeziona il repository alla ricerca di tracce di dati personali: percorsi con nomi utente reali, credenziali personali, contatti, identificatori di persone o macchine, indirizzi IP, dati in fixture e screenshot. Mappa i flussi di dati personali (raccolta, uso, conservazione, condivisione, cancellazione) e verifica minimizzazione, finalità dichiarate e base giuridica, tempi di conservazione, accessi e diritti degli interessati (accesso, rettifica, cancellazione) dove il prodotto tratta tali dati. Assicurati che note e dati operativi privati risiedano solo in aree escluse da Git e che `.gitignore` li protegga. Sostituisci i riferimenti reali con dati sintetici o segnaposto neutri nella documentazione pubblica.

## Verifiche

Verifica che nessun dato personale sia nell'indice Git o nella cronologia dei commit pubblici e che esportazioni e pubblicazioni applichino filtri rigorosi. Non dichiarare la conformità legale: l'applicabilità del GDPR dipende dal trattamento e va valutata sulle fonti ufficiali e, se necessario, con un consulente.

## Consegna

Rapporto di audit sulla privacy con i dati trovati, i flussi mappati, le sanificazioni eseguite, le lacune e i limiti; nessuna attestazione di conformità legale.

## Prompt vicini

- SEC01: Rivedi modifiche o codice con rilievi concreti e riferimenti.
- SEC04: Trova le credenziali esposte e verifica la validazione degli input.
- SEC07: Controlla diff, repository e cronologia per dati sensibili prima di pubblicare.
