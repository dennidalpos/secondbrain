# COM02 — Segui un flusso e le sue dipendenze attraverso il codice

> **Scope**: repo/area | **Modalità**: lettura | **Cosa serve**: punto di ingresso o scenario da seguire | **Esempio d'uso**: `segui il flusso di autenticazione e sessione`

## Scopo

Spiegare il percorso effettivo di una richiesta, un evento o un dato.

## Quando usarlo

Quando occorre capire un comportamento specifico prima di intervenire.

## Input

Evento, operazione o sintomo iniziale; il risultato di cui ricostruire l'origine.

## Attività specifiche

Segui chiamanti e chiamati dal punto di ingresso fino agli effetti. Individua validazioni, autorizzazioni, trasformazioni, errori, confini asincroni e dipendenze esterne. Evidenzia le responsabilità e i punti in cui cambia lo stato. Presenta come scelte definite i bivi o gli scenari alternativi che richiedono un'indicazione.

## Decisioni da raccogliere

- flusso o scenario alternativo da seguire quando il punto di ingresso ha più rami;
- confini (asincroni, esterni) da includere nella traccia (scelta multipla).

## Verifiche

Verifica ogni passaggio su simboli e riferimenti reali; separa i rami possibili da quelli osservati a runtime.

## Consegna

Sequenza del flusso con riferimenti precisi e un diagramma solo se chiarisce le relazioni.

## Prompt vicini

- COM01: Esplora il repository e individua componenti principali e comandi.
- DEV02: Riproduci un difetto e correggine la causa.
