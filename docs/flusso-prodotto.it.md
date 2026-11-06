# Flusso per prodotto

SecondBrain si usa in due modi con lo stesso risultato: **in chat**, scrivendo `sb ...` nell'agente (Claude, ChatGPT Codex o Antigravity per Windows), oppure **da script**, con PowerShell. Per ogni repository i passi sono gli stessi e vanno in quest'ordine.

| # | Passo | In chat | Da script |
|---|---|---|---|
| 1 | Attiva il repository (una volta per postazione) | `sb attiva` | `pwsh -NoProfile -File scripts/secondbrain.ps1 -Setup -Interactive` |
| 2 | Distribuisci direttive e dossier | `sb allinea` | `pwsh -NoProfile -File scripts/secondbrain.ps1 -Sync` |
| 3 | Collega e verifica l'IDE | `sb prompt SYS01` | `pwsh -NoProfile -File scripts/ide-map.ps1 -Verify` |
| 4 | Carica il contesto iniziale (profilo snello) | `sb prompt MEM06` | `pwsh -NoProfile -File scripts/knowledge.ps1 -Startup` |
| 5 | Scegli il prossimo task pronto | `sb prompt REP01` | `pwsh -NoProfile -File scripts/knowledge.ps1 -Tasks -ReadyOnly` |
| 6 | Lavora nel repository | l'agente, nei permessi della sessione | — |
| 7 | Prima del push: verifica di pubblicabilità | `sb prompt SEC07` | `pwsh -NoProfile -File scripts/publication.ps1 -RepositoryPath .` |
| 8 | Chiudi il task: stato nel tracker, memoria e contesto, poi Sync e Check | `sb prompt MEM03` | `pwsh -NoProfile -File scripts/knowledge.ps1 -UpdateTaskId ID -Status done` |
| 9 | Se Check chiede la compattazione: anteprima, poi applica | `sb compatta` | `pwsh -NoProfile -File scripts/knowledge.ps1 -Compact -CandidatePath FILE` |

I passi 1–3 si fanno una volta; 4–8 a ogni lavoro; 9 solo quando serve. Nuovi task: `knowledge.ps1 -NewTask` (non si modifica il tracker a mano).

Gli agenti dei prodotti eseguono build e test e conservano output, cache, temporanei, fixture ed evidenze nelle cartelle locali dei prodotti escluse da Git. Il dossier SecondBrain conserva sintesi e riferimenti.

## Dove sei e cosa fare ora

`sb prompt` è il menu iniziale. Con il percorso del repository aggiunge lo stato della postazione, il repository corrente (gestito o no) e il prossimo passo:

```powershell
pwsh -NoProfile -File scripts/prompts.ps1 -RepositoryPath .
```

Da MCP è lo strumento `get_prompt_home` con `repositoryPath`. Senza percorso la schermata è generica (comandi, primi passi e guide). In chat l'agente deve passare il checkout corrente: la schermata non lo ricava da sola.

## Chat o script?

| | In chat | Da script |
|---|---|---|
| Quando | Lavori già con un agente supportato | Senza agente, per diagnosi o automazione |
| Permessi | Quelli della sessione dell'agente | Quelli del tuo terminale |
| Risultato | Lo stesso: i comandi `sb` richiamano gli stessi script | Lo stesso |

Limiti: i comandi `sb` sono una convenzione scritta nelle direttive, non un programma installato; un file di regole aggiornato non prova che l'agente lo abbia caricato (controlla in una sessione nuova). Dettagli: [agenti e MCP](ide-e-mcp.md), [uso quotidiano](uso-quotidiano.md).
