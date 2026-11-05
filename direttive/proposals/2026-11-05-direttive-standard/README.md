# Proposta: direttive per sezioni, nomenclatura standard e cartelle di sessione

Riscrive il testo comune secondo le pratiche di AGENTS.md, Claude Code (CLAUDE.md), Codex, Copilot, Cursor, Windsurf e Gemini CLI: sezioni standard (Principi, Sicurezza e dati, SecondBrain, Verifica, Git e pubblicazione, Chiusura), regole atomiche e verificabili, nome dello strumento di domanda neutro (nessun `ask_question`). Sposta le procedure specifiche di SecondBrain dal testo comune al testo di postazione e ai prompt. Aggiunge al blocco repository le regole su cartelle `.runtime`, sessioni, manifest, retention e squadra.

Dimensione del testo distribuito: da 11.204 a circa 7.500 caratteri (comune 4.846, postazione 2.657); blocco repository 2.457. Etichetta di revisione invariata (1.0, nessuna modifica a `VERSION` o `CHANGELOG.md`), data 2026-11-05.

- [AGENTS.global_ide.md](AGENTS.global_ide.md) · SHA-256 `A673995DCF6B94765D80ABE7C4216E8357899F1E08A81FF549E350901F45768A`
- [AGENTS.repo.managed.md](AGENTS.repo.managed.md) · SHA-256 `E3EBA7130144271555758105DDFF7468E2D9E9681FD4A189CE96E31C7C913797`
- [workstation.template.md](workstation.template.md) · SHA-256 `877122D70AC9C38F743C7D502CA4572FC59BE3C295D7AA722C7E7B5BDE8B4777`

Distribuzione dopo approvazione esplicita della proposta e dei suoi hash (`approve-revision.ps1 -Preview`, poi `-Apply`).
