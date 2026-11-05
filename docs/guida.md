# Guida unica

Installazione, uso con e senza IDE, variabili, concorrenza e casi limite in una pagina. Ogni comando qui sotto è quello reale degli script; i dettagli sono nelle [guide](../README.md#guides) e nel [riferimento](riferimento/operations.md).

## Installa e attiva

```powershell
git clone https://github.com/dennidalpos/SecondBrain.git C:/Progetti/SecondBrain
cd C:/Progetti/SecondBrain
pwsh -NoProfile -File scripts/secondbrain.ps1 -Check                 # sola lettura; prima dell'attivazione esce con 2
pwsh -NoProfile -File scripts/secondbrain.ps1 -Setup -Interactive    # scegli progetti e agenti, poi CONFERMO e APPLICA
pwsh -NoProfile -File scripts/secondbrain.ps1 -Sync                  # distribuisce le regole approvate
```

Servono Windows, Git 2.42+ e PowerShell 7.5+. Il preflight rifiuta Git assente, non eseguibile, precedente a 2.42 o con versione non riconoscibile. Il passo `-Setup` non scrive la variabile utente `SECONDBRAIN_HOME` se non lo confermi (vedi [Variabili](#variabili)).

## Agenti (IDE) e comandi `sb`

| Strumento | Regole | Collegamento MCP (opzionale) |
|---|---|---|
| Claude per Windows | `~/.claude/CLAUDE.md` | `scripts/mcp-server.ps1 -Pair -Target claude` |
| ChatGPT Codex per Windows | `~/.codex/AGENTS.md` | `-Target codex` |
| Antigravity per Windows | `~/.gemini/GEMINI.md` | `-Target antigravity` |

Senza `-Apply` il collegamento mostra solo l'anteprima. Nell'agente scrivi:

| Scrivi | Richiama |
|---|---|
| `sb prompt` | `scripts/prompts.ps1` (guide e comandi) |
| `sb prompt list` | `prompts.ps1 -List -Compact` |
| `sb prompt ambito test` | `prompts.ps1 -List -Category test` |
| `sb prompt mostra DEV03` | `prompts.ps1 -Show -Prompt DEV03` |
| `sb prompt DEV03: <obiettivo>` | `prompts.ps1 -Compose` (prompt composto con tag XML) |
| `sb controlla` / `sb allinea` | `secondbrain.ps1 -Check` / `-Sync` |
| `sb attiva` | `secondbrain.ps1 -Setup` |
| `sb compatta` | `knowledge.ps1 -Compact -CandidatePath <file>` (anteprima; `-Apply` per scrivere) |

I passi in ordine per ogni repository, in chat e da script, sono nel [flusso per prodotto](flusso-prodotto.md).

Le impostazioni dell'account Claude non hanno un file: incolla `.runtime/hosts/<id>/istruzioni-globali.md`. Un file aggiornato non prova il caricamento: apri una sessione nuova e scrivi `sb prompt`; `scripts/ide-map.ps1 -Verify` riepiloga lo stato.

## Solo riga di comando

MCP è facoltativo: gli stessi contenuti arrivano dalla CLI (un test confronta i due percorsi su tutti e 8 gli strumenti).

| Cosa | Comando |
|---|---|
| Contesto di un progetto | `scripts/knowledge.ps1 -Startup` (`-Profile Full` per tutto) |
| Task pronti / un task | `knowledge.ps1 -Tasks -ReadyOnly` / `knowledge.ps1 -Task <id o #seq>` |
| Cerca negli appunti | `knowledge.ps1 -Search <testo> [-Mode Relevance]` |
| Prompt | `prompts.ps1 -List -Compact`, `prompts.ps1 -Show -Prompt <CHIAVE>` |
| Chiudere o creare un task | `knowledge.ps1 -UpdateTaskId <id> -Status done` / `knowledge.ps1 -NewTask <titolo> ...` |
| Prima del push | `scripts/publication.ps1 -RepositoryPath <repo>` |

Dal checkout di un repository gestito `knowledge.ps1` trova da solo il dossier; altrove usa `-Repository` o `-CheckoutPath`. La vista di tutti i repository esiste solo con `-All` ed è in sola lettura.

## Variabili

| Variabile | Uso |
|---|---|
| `SECONDBRAIN_HOME` | Variabile utente col percorso del clone. `-Setup -Apply` la scrive solo con `-RegisterEnvironment` (o risposta `SI` in `-Interactive`); `-NoRegisterEnvironment` la esclude, anche da `-Activate -Apply`. Gli IDE aperti vanno riavviati. |
| `SECONDBRAIN_LANG` | Lingua dei messaggi (`it` o `en`). Ordine: `-Language` (su `knowledge.ps1`, `prompts.ps1`, `secondbrain.ps1`, `trace.ps1`), questa variabile, la chiave `language` in `workstation.json`, la lingua del sistema, `en`. I messaggi dei moduli già convertiti seguono la lingua, come la vista `sb prompt` (home, elenchi e schede dei prompt, anche via MCP con `language`); gli altri restano in italiano. |
| `SECONDBRAIN_SKIP_PRE_PUSH=1` | Salta l'hook pre-push per un solo push consapevole. |
| `SECONDBRAIN_LOCK_WAIT_SECONDS` | Attesa del lock di scrittura (predefinita 60); equivale a `-WaitSeconds`. |

L'hook pre-push (`publication.ps1 -InstallHook -Apply`) è fail-closed: senza `pwsh` o con `SECONDBRAIN_HOME` assente o errata il push si ferma con istruzioni.

## Coda e concorrenza

Le letture non prendono lock. Le scritture entrano in una coda FIFO su un solo lock: chi arriva dopo attende fino a `-WaitSeconds` (60 s) ed esce con codice **3**; non cancellare mai i lock.

```powershell
pwsh -NoProfile -File scripts/access.ps1 -Status    # sessioni attive
pwsh -NoProfile -File scripts/access.ps1 -Queue     # writer in coda (-Purge toglie solo i ticket orfani)
```

Una scrittura prolungata usa `access.ps1 -Start -Mode Write` e `-End` nello stesso script, con `try/finally`.

## Greenfield

`knowledge.ps1 -SetLifecycle greenfield` fissa nel `repository.json` del dossier che il repository si presenta come nuovo: `secondbrain.ps1 -Check` segnala `greenfield-violation` se compaiono `VERSION` modificato, `CHANGELOG.md` nuovo o con voci aggiunte, importazioni di schema o alias. `-SetLifecycle none` toglie il blocco (prompt SYS13).

## Git e backup

Git salva i file tracciati: se un file tracciato è pulito, SecondBrain lo riscrive senza copia `.bin` e registra commit e blob; se ha modifiche non committate si ferma con istruzioni (committa o `git stash`). Per i file fuori da Git resta la copia in `.runtime/hosts/<id>/backups/`. Ripristino: `scripts/restore-managed.ps1 -List -Path <file>`. Dettagli: [sicurezza e backup](riferimento/safety-backups.md).

## Casi limite

| Caso | Comportamento |
|---|---|
| `SECONDBRAIN_HOME` assente | Gli script funzionano dal clone; l'hook pre-push si ferma con istruzioni |
| Clone spostato | Rilancia `-Setup ... -RegisterEnvironment` dal nuovo percorso e riavvia gli IDE |
| Postazione non attivata | `-Check` esce con 2: esegui `-Setup` |
| Percorsi con spazi | Supportati; scrivi i percorsi tra virgolette |
| File tracciato sporco | La scrittura si ferma; in `-Sync` il blocco risulta `conflict` |
| Lock occupato | Exit 3 dopo l'attesa; guarda `access.ps1 -Status` e `-Queue` |

Altro: [portabilità](riferimento/portable-brain.md), [recupero](riferimento/recovery.md), [manutenzione di `.runtime`](riferimento/runtime-maintenance.md).
