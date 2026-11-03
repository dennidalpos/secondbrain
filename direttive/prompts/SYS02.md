# SYS02 — Verifica le fonti autorevoli; acquisisci o aggiorna su richiesta

> **Scope**: central | **Modalità**: verifica | **Cosa serve**: registro PARA resource-authoritative-sources | **Esempio d'uso**: `sb prompt SYS02: verifica aggiornamenti normativi nel registro fonti`

## Scopo

Mantenere riferimenti centrali affidabili senza adottare requisiti implicitamente.

## Quando usarlo

Nella manutenzione centrale del registro; verifica predefinita in lettura.

## Input

Risorsa resource-authoritative-sources, schede, versioni e perimetro richiesto.

## Attività specifiche

Risolvi registro da PARA e verifica metadati. Usa sources.ps1 -Check per controlli locali e -Probe per endpoint registrati. Solo su richiesta di raccolta/allineamento conserva candidate con -Collect e aggiorna viste con -BuildIndex, rispettando diritti e provenienza.

Nessun monitor o controllo periodico. Probe e acquisizioni avvengono soltanto su richiesta; rapporti, cache e conversioni restano nella radice SecondBrain/.runtime e non vengono cancellati automaticamente.

## Verifiche

Distingui accessibilità, trascrizione, applicabilità e attuazione. Verifica date, versioni e requisiti puntuali; segnala copertura incompleta. Non qualificare o eseguire task dei prodotti; regole comuni solo tramite proposta e approvazione.

## Consegna

Fonti controllate, variazioni, limiti, impatto e riferimenti per gli agenti prodotto; nessuna attestazione di conformità.

## Prompt vicini

- COM03: Trova le fonti ufficiali adatte al problema tecnico.
- SYS01: Verifica gli IDE; mappa, registra account o riallinea su richiesta.
