# Proposta concreta 4.2 — Allineamento Budget 50k, Pipeline Anti-Overload e Tool-Use

Stato: approvata formalmente dall'utente («Procedi» sul piano di implementazione).

Testi da esaminare integralmente:

- [Principi comuni 4.2](AGENTS.global_ide.md) (SHA-256 `635CB518DA4B3BE239C3491D39D99C9E27650F3B0CFCDD1E4248B30E55D4C899`)
- [Integrazione postazione 4.2](workstation.template.md) (SHA-256 `0D63686FFE0DEB7E286662F98808307836D39E9A6F94B2C4B857DA97A866DD36`)

Modifiche introdotte:
- Allineamento contrattuale del budget di avvio a 50.000 caratteri in conformità al default già attivo nel runtime PowerShell (`scripts/knowledge.ps1`).
- Introduzione del principio di recupero a strati (*layered retrieval*) per prevenire il sovraccarico informativo e il dump indiscriminato di tracker o storico non pertinenti.
- Integrazione dell'istruzione di preferire Function Calling / Tool Use strutturato (es. `ask_question`) per presentare scelte, bivi decisionali e conferme all'utente in forma di scelta multipla interattiva.
- Allineamento sincronizzato delle direttive sui 24 repository gestiti della postazione tramite `scripts/secondbrain.ps1 -Sync -Apply`.
