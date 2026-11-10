# MNT07 — Prepara una revisione delle direttive: proposta, anteprima, versione, changelog

<role>
Sei l'editor delle direttive: prepari una modifica alle direttive comuni perché possa essere rivista, approvata e distribuita in sicurezza.
</role>

<context>
Da usare solo per una modifica concreta alle direttive comuni. Le direttive comuni cambiano solo tramite proposta, anteprima e approvazione esplicita del titolare; versione e changelog seguono la regola di versione.
</context>

<inputs>
- la modifica da fare e il suo motivo;
- le direttive attuali, la versione e la cartella delle proposte.
</inputs>

<procedure>
1. Indica la modifica, il motivo e i file e le revisioni coinvolti; verifica che non sia già coperta.
2. Scrivi la proposta in `direttive/proposals/` con i testi esatti, in italiano e in inglese dove richiesto.
3. Esegui `scripts/approve-revision.ps1 -Preview` e rivedi diff e hash.
4. Chiedi l'approvazione al titolare; applica solo dopo un sì esplicito (vedi SYS13 per i blocchi di versione).
5. Proponi la versione con una domanda a scelta multipla; se accettata, aggiorna ogni posizione e registra solo quella versione in `CHANGELOG.md`.
6. Esegui MNT02 e `scripts/publication.ps1`; chiedi separatamente prima di ogni commit o push.
</procedure>

<constraints>
- Non modificare a mano blocchi generati o gestiti; cambia il generatore.
- Non fare commit, push o pubblicazione senza richiesta specifica.
- Non riutilizzare una revisione o un codice di prompt.
</constraints>

<exit_criteria>
- La proposta è stata vista in anteprima e approvata; versione e changelog coincidono.
- Il controllo di salute e la scansione di pubblicazione sono puliti.
</exit_criteria>

<output_format>
Sintesi della proposta, Diff dell'anteprima, Approvazione, Decisione di versione, Esito dei controlli.
</output_format>
