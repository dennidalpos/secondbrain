# Prompt

120 prompt in un'unica lista, in 17 aree e due gruppi (repository corrente e SecondBrain centrale). Scegli, aggiungi il tuo obiettivo, e l'agente ha tutto ciò che serve.

```text
sb prompt list
sb prompt ambito test
sb prompt mostra DEV01
sb prompt DEV01: aggiungi l'esportazione in PDF
```

Elenco completo: [catalogo](../direttive/prompts/README.it.md) ([English](../direttive/prompts/README.md)). I prompt che gestiscono SecondBrain stesso (aree `system`, `knowledge`, `maintenance`) sono nella stessa lista.

## Dove sei

`sb prompt` (`scripts/prompts.ps1`) legge la cartella corrente e ne indica la posizione: **repository gestito** (dossier, tracker e runner disponibili), **repository senza onboarding** (modalità ridotta), **checkout di SecondBrain** o **nessun progetto** (fuori da un checkout Git). La home mostra poi due gruppi di comandi, **comandi per il repository** e **attivazione e manutenzione di SecondBrain**, con la manutenzione in testa nel checkout di SecondBrain e fuori da un progetto.

**Catena iniziale standard:** `sb prompt MEM08` (stato del repository, allineamento con SecondBrain se gestito, prossimi task proposti), poi `sb prompt REP01` o `sb runner`, e `sb prompt MEM03` a lavoro finito; `sb prompt MEM07` riprende il lavoro fermato da un limite d'uso, anche da un altro account. Ogni prompt composto termina con `<next_steps>`: da due a quattro prompt e task pronti successivi, proposti come scelta multipla.

**Senza onboarding** un repository funziona comunque: i prompt di repository si compongono senza dossier e riportano un blocco `<degraded>`. Non sono disponibili: contesto e memoria all'avvio, tracker e task pronti nei prossimi passi, runner e Orchestrator, rapporti di passaggio MEM03 e ripresa del runner, scritture di memoria e tracker, allineamento del blocco gestito di `AGENTS.md`, fonti autorevoli applicabili, compattazione SYS05 e `-Check` di quel repository. I prompt centrali e le scritture MEM/SYS richiedono comunque un dossier. L'onboarding resta facoltativo (`sb attiva`, SYS03).

## Come è fatta una scheda

Le schede sono scritte in inglese (lingua di riferimento), con la traduzione italiana in `direttive/prompts/it/` a tuo comodo. Ogni scheda ha le stesse sezioni, delimitate da tag XML, come raccomandato dalle guide di prompt engineering di Anthropic, OpenAI e Google.

| Tag | Cosa contiene |
|---|---|
| `role` | Chi è l'agente per questo compito |
| `context` | Quando usare il prompt e con quali limiti |
| `inputs` | Cosa serve prima di iniziare |
| `decisions` | Scelte da chiedere all'utente (solo dove servono) |
| `procedure` | Passi numerati |
| `constraints` | Cosa non fare |
| `exit_criteria` | Quando il lavoro è finito, in termini verificabili |
| `output_format` | Come riportare il risultato |

Il prompt composto (`sb prompt CODICE: obiettivo`) riunisce il tuo obiettivo, il contesto del repository e la scheda in un unico testo XML con `task`, `context`, le sezioni della scheda, `operating_rules` e `next_steps`. Nel framework CO-STAR: `task` = Objective, `context` = Context, `role` = Audience e Style, `constraints` = Style e Tone, `output_format` = Response. La chiusura cambia con la modalità: un prompt di sola lettura riporta senza modificare nulla, uno di scrittura verifica e aggiorna il dossier solo per i prompt di memoria e sistema.

`sb prompt mostra` fa vedere la scheda sorgente. La lingua di visualizzazione segue `-Language` (`prompts.ps1`), `SECONDBRAIN_LANG` o la lingua del sistema; il tool MCP accetta `language` (`en|it`). Gli indici sono generati per lingua con `scripts/build-prompts.ps1`.

## Le aree

I prompt sono raggruppati per area di sviluppo o necessità, non per prefisso del codice. Un prompt di repository lavora solo sul repository da cui gira; quelli centrali girano dal checkout di SecondBrain. Una scheda che deve leggere un altro repository lo dichiara (per esempio l'allowlist di sola lettura di REP16).

**Repository corrente: da eseguire nel repository su cui lavori**

| ID | Area | Codici |
|---|---|---|
| `understand` | Comprensione e analisi | COM01, COM02, COM03, COM04, COM05, COM06, COM07 |
| `design` | Requisiti, architettura e pianificazione | PRG01, PRG02, PRG03, PRG04, PRG05, PRG07 |
| `develop` | Sviluppo e manutenzione del codice | DEV01, DEV02, DEV03, DEV04, DEV05, DEV06 |
| `test` | Test e prestazioni | TST01, TST02, TST03, TST04, TST05, TST06, TST07, TST08 |
| `review` | Revisione e audit | AUD01, AUD02, AUD03, AUD04, SEC01 |
| `security` | Sicurezza, privacy e licenze | AUD07, GOV02, SEC02, SEC03, SEC04, SEC05, SEC06, SEC07, SEC09 |
| `data` | Dati e integrazioni | DAT01, DAT02, DAT03, DAT04 |
| `interface` | Interfaccia ed esperienza utente | INT01, INT02, INT03, INT04, INT05 |
| `docs` | Documentazione | DOC01, DOC02, DOC03, DOC04 |
| `operations` | Rilascio e operatività | OPS01, OPS02, OPS03, OPS04, OPS06, OPS07 |
| `git` | Git e GitHub | OPS05, REP04, REP11, REP12, REP13, REP14 |
| `backlog` | Backlog, memoria e continuità | MEM01, MEM02, MEM03, MEM06, MEM07, MEM08, REP01, REP08, REP15, REP16, REP17, SYS13 |
| `web` | Siti e applicazioni web | WEB01, WEB02, WEB03, WEB04, WEB05, WEB06, WEB07, WEB08, WEB09 |
| `ai` | AI e funzioni basate su modelli linguistici | AIS01, AIS02, AIS03, AIS04, AIS05, AIS06, AIS07, AIS08, AIS09, DEV12 |

**SecondBrain centrale: da eseguire dal checkout di SecondBrain**

| ID | Area | Codici |
|---|---|---|
| `system` | Postazione e IDE | SYS01, SYS03, SYS04, SYS10, SYS15, SYS17 |
| `knowledge` | Dossier, fonti e direttive | MEM05, MNT07, SYS02, SYS05, SYS11, SYS16 |
| `maintenance` | Manutenzione SecondBrain | MNT01, MNT02, MNT03, MNT04, MNT05, MNT06, SYS09 |

Le aree di sicurezza e catena di fornitura seguono i gruppi di pratiche del NIST SP 800-218 SSDF 1.1 (fonte `nist-ssdf` del registro autorevole, verificata). Le altre aree seguono le usuali attività di sviluppo; non derivano da SWEBOK né da ISO/IEC/IEEE 12207, che il registro non contiene.

I codici sono stabili e non vengono riutilizzati: dopo un accorpamento restano dei vuoti nella numerazione (per esempio non esiste `SEC08`, confluito in `SEC07`).

## Le icone

Ogni elenco mostra la modalità del prompt:

| Icona | Modalità | Significato |
|---|---|---|
| 🔭 | lettura | analizza e riporta; nessun effetto |
| ✅ | verifica | confronta con criteri, esito pass/fail; non modifica |
| 🔥 | scrittura | modifica file o stato |
| ⛔ | distruttivo | scrittura irreversibile: chiede conferma esplicita |

## Personalizza

Il modo più semplice è chiederlo all'agente:

```text
sb prompt SYS11: aggiungi un prompt per le migrazioni del database
```

A mano: [modificare i prompt](riferimento/customizing-prompts-and-directives.it.md#modifica-dei-prompt) e [modificare le regole](riferimento/customizing-prompts-and-directives.it.md#modifica-delle-direttive).

Una nuova regola comune richiede sempre la tua approvazione.
