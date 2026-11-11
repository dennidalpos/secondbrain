# Struttura delle cartelle e permessi di scrittura

Guida di riferimento: dove sta cosa, chi può scrivere e dove. Valida dalla revisione di direttive del 10 novembre 2026.

## Cartelle di primo livello

| Cartella | Ruolo | Chi scrive | Git |
|---|---|---|---|
| `01-projects/<repo>/` | Un dossier per ogni repository gestito: contesto, memoria, tracker, specifiche, storico | Solo gli script SecondBrain e i tool MCP di scrittura | ignorata |
| `02-areas/<id>/` | Responsabilità continue senza fine: `governance`, `postazione`, `direttive` | Script e persona titolare | tracciata, esclusi gli originali scaricabili |
| `03-resources/<id>/` | Riferimenti condivisi: fonti autorevoli, architettura, radar tecnologico, troubleshooting | Script e persona titolare | tracciata, esclusi gli originali scaricabili |
| `04-archives/{projects,areas,resources}/` | Entità chiuse o ritirate, sola lettura | Solo `para.ps1 -Archive` e `-Restore` | ignorata |
| `config/` | Schemi e policy condivise, nessun dato locale | Revisione manuale | tracciata |
| `direttive/` | Testi sorgente delle direttive, prompt, proposte | Revisione manuale; modifiche con `approve-revision.ps1` | tracciata |
| `docs/`, `scripts/`, `.github/` | Guide, codice, automazione | Revisione manuale | tracciata |
| `.runtime/` | Stato e lavoro generato dalla postazione, mai conoscenza | Solo gli script | ignorata |

Di `01`–`04` si traccia solo il `README.md` della cartella e i `.gitkeep`. `PARA.md` e `para-index.json` sono viste generate.

Creazione delle entità PARA: `para.ps1 -NewProject`, `-NewArea`, `-NewResource`; cambio di stato `-SetStatus`; chiusura `-Archive`.

## Dossier di un repository (`01-projects/<repo>/`)

| File o cartella | Ruolo |
|---|---|
| `brief.md` | Scopo e perimetro (obbligatorio per `secondbrain.ps1 -Check`) |
| `context.md` | Stato corrente, vincoli, problemi aperti, prossimo passo |
| `memory.md`, `memory.agent.md` | Decisioni durevoli; la seconda è la vista per agenti, generata |
| `tracker.json` | Task attivi (schema 1) |
| `repository.json`, `para.json`, `index.md` | Identità, tipo PARA, indice generato |
| `authoritative-sources.json` | Fonti autorevoli del repository |
| `specs/` | Specifiche del repository |
| `history/` | Rapporti, compattazioni, task terminati; non si pubblica |

## `.runtime`

```
.runtime/
  access/                      sessioni, lock e coda di scrittura
  hosts/<id-postazione>/       stato della postazione
    *.json, istruzioni-globali.md   configurazione, selezione, inventario, mappa IDE, stato
    backups/para-*/            backup e marker delle transazioni di scrittura sul dossier
    repos/<repo>/<categoria>/<yyyyMMdd>-<slug>/   lavoro con MANIFEST.json
                               categorie: work, evidence, report, fixture, tmp
    repos/tests-<hash>/        fixture delle suite di test, svuotabili
```

Regole:
- Cartelle di lavoro solo con `work.ps1 -Init`; mai file o cartelle create a mano nella radice di `.runtime`.
- `access.ps1 -Start` apre una sessione di scrittura: accetta un `-SessionId` nuovo (32 cifre esadecimali) oppure ne genera uno e lo restituisce. Lo stesso valore va passato a ogni CLI e a `-End`. Le sessioni chiuse o scadute si rimuovono ad ogni `-Start`.
- `.runtime` si può cancellare e ricreare con un nuovo Setup (`secondbrain.ps1 -Setup -Roots <cartelle>`): contiene solo stato rigenerabile.

## Dove scrive un agente

| Agente | Può scrivere | Non può scrivere |
|---|---|---|
| Sessione in un repository prodotto | Il repository stesso; in SecondBrain solo `01-projects/<repo>/` (tramite script o MCP) e cartelle `work.ps1` | Altri dossier, `02-areas`, `03-resources`, `04-archives`, `.runtime` a mano |
| Sessione in SecondBrain | `direttive/`, `scripts/`, `docs/`, `config/` e PARA tramite script | `.runtime` a mano |
| Runner dei task | Solo il dossier del proprio repository | Qualsiasi altro percorso |

Un percorso fuori da queste regole si segnala alla persona titolare e non si scrive.
