# SEC05 — Verifica isolamento dei dati personali e conformità al GDPR

> **Scope**: repo | **Modalità**: verifica | **Cosa serve**: dossier, log operativi e repository pubblico | **Esempio d'uso**: `sb prompt SEC05: controlla assenza dati personali e conformita privacy gdpr`

## Scopo

Verificare che dati personali e sensibili siano minimizzati, isolati dal repository pubblicabile e trattati secondo il GDPR e le policy del progetto.

## Quando usarlo

Nella revisione di flussi di dati, log e documentazione e prima della pubblicazione di repository e guide.

## Input

Codice, log, snapshot di ambiente, documentazione, directory locali ed eventuale registro dei trattamenti.

## Attività specifiche

Ispeziona il repository per tracce di dati personali: percorsi con nomi utente reali, credenziali personali, contatti, identificativi di persone o macchine, indirizzi IP, dati in fixture e screenshot. Mappa i flussi dei dati personali (raccolta, uso, conservazione, condivisione, cancellazione) e verifica minimizzazione, finalità e base giuridica dichiarate, tempi di conservazione, accessi e diritti degli interessati (accesso, rettifica, cancellazione) dove il prodotto tratta tali dati. Accerta che note, memorie e dati operativi privati risiedano solo in aree escluse da Git e che `.gitignore` le protegga. Sostituisci i riferimenti reali con dati sintetici o segnaposto neutri nella documentazione pubblica.

## Verifiche

Verifica che nessun dato personale sia nell’indice Git né nella cronologia dei commit pubblici e che esportazioni e pubblicazioni applichino filtri stringenti. Non dichiarare conformità legale: l’applicabilità del GDPR dipende dal trattamento e va valutata sulle fonti ufficiali e, se serve, con un consulente.

## Consegna

Report di audit privacy con dati trovati, flussi mappati, sanitizzazioni eseguite, lacune e limiti; nessuna attestazione di conformità legale.

## Prompt vicini

- SEC01: Revisiona modifiche o codice con rilievi concreti e riferimenti.
- SEC04: Cerca credenziali esposte e verifica la validazione degli input.
- SEC07: Analizza i dati sensibili del diff prima del push.
