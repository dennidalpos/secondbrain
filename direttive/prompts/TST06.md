# TST06 — Misura e migliora prestazioni e consumo di risorse

> **Scope**: repo/area | **Modalità**: scrittura | **Cosa serve**: profiler o metriche di tempo e allocazione memoria | **Esempio d'uso**: `sb prompt TST06: riduci tempo di discovery host e memoria occupata`

## Scopo

Ridurre un singolo collo di bottiglia dimostrabile in tempo, memoria o I/O con misure prima e dopo. Per un’ottimizzazione estesa a più moduli usa DEV10, per la sola analisi AUD05.

## Quando usarlo

Quando tempi, memoria, I/O o reattività non soddisfano un obiettivo.

## Input

Flusso, carico rappresentativo, ambiente, metrica e soglia se già definita.

## Attività specifiche

Acquisisci baseline e profilo; individua il percorso dominante. Modifica la causa misurata e mantieni correttezza e costi operativi accettabili. Evita ottimizzazioni speculative fuori perimetro.

## Verifiche

Confronta prima/dopo sullo stesso carico, indicando dispersione e condizioni. Verifica regressioni funzionali; non dedurre benefici da una sola lettura del codice.

## Consegna

Misure confrontabili, intervento, beneficio osservato e limiti del benchmark.

## Prompt vicini

- TST05: Verifica il comportamento reale rispetto ai requisiti.
- OPS03: Aggiungi log, metriche e diagnostica utili al problema.
- AUD05: Audita le prestazioni e individua i percorsi critici senza modificare il codice.
- DEV10: Ottimizza il codice sull’intero perimetro con misure prima e dopo.
