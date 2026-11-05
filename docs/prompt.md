# Prompt

91 prompt in un'unica lista, in 14 aree. Scegli, aggiungi il tuo obiettivo, e l'agente ha tutto ciò che serve.

```text
sb prompt list
sb prompt ambito test
sb prompt mostra DEV01
sb prompt DEV01: aggiungi l'esportazione in PDF
```

Elenco completo: [catalogo](../direttive/prompts/README.it.md) ([English](../direttive/prompts/README.md)). I prompt che gestiscono SecondBrain stesso (memoria `MEM`, sistema `SYS`) sono nella stessa lista.

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

| Codice | Area |
|---|---|
| COM | Comprensione e ricerca |
| PRG | Requisiti e progettazione |
| DEV | Sviluppo e modernizzazione |
| TST | Test e verifica |
| SEC | Review e sicurezza |
| AUD | Audit e metriche |
| INT | Interfaccia ed esperienza utente |
| DAT | Dati e integrazioni |
| OPS | Rilascio e operatività |
| DOC | Documentazione |
| REP | Igiene del repository |
| GOV | Licenze e conformità |
| MEM | Memoria e continuità di SecondBrain |
| SYS | Sistema e manutenzione centrale |

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

A mano: [modificare i prompt](riferimento/customizing-prompts-and-directives.md#modifica-dei-prompt) e [modificare le regole](riferimento/customizing-prompts-and-directives.md#modifica-delle-direttive).

Una nuova regola comune richiede sempre la tua approvazione.
