# Inizia

Dieci minuti per attivare SecondBrain. Niente viene scritto senza la tua conferma.

```mermaid
flowchart LR
    A["1. Scarica"] --> B["2. Controlla"]
    B --> C["3. Attiva"]
    C --> D["4. Distribuisci le regole"]
    D --> E["5. Collega l'agente"]
    E --> F["6. Scrivi: sb prompt"]
```

Servono Windows, Git e PowerShell 7.5+.

## 1. Scarica

```powershell
git clone https://github.com/dennidalpos/SecondBrain.git C:/Progetti/SecondBrain
cd C:/Progetti/SecondBrain
```

Meglio un tuo repository privato: le note restano sul PC, ma così puoi salvarle.

## 2. Controlla

```powershell
pwsh -NoProfile -File scripts/secondbrain.ps1 -Check
```

Non scrive nulla. La prima volta dice `Postazione non attivata`: è normale, si risolve al passo 3.

## 3. Attiva

```powershell
pwsh -NoProfile -File scripts/secondbrain.ps1 -Setup -Interactive
```

Elenca i progetti e gli agenti trovati. Scegli i tuoi, poi conferma scrivendo `CONFERMO` e `APPLICA`.

## 4. Distribuisci le regole

```powershell
pwsh -NoProfile -File scripts/secondbrain.ps1 -Sync
```

Aggiunge un breve testo in `AGENTS.md` dei progetti e nel file di regole di ogni agente. Il resto del file non cambia.

## 5. Collega l'agente

```powershell
pwsh -NoProfile -File scripts/mcp-server.ps1 -Pair -Target claude
pwsh -NoProfile -File scripts/mcp-server.ps1 -Pair -Target claude -Apply
```

Il primo comando mostra cosa farà, il secondo lo fa. Al posto di `claude` puoi usare `codex` o `antigravity`.

## 6. Prova

Riavvia l'agente e scrivi in chat:

```text
sb prompt
```

Se vedi l'elenco dei comandi, è tutto pronto. Per controllare in ogni momento:

```powershell
pwsh -NoProfile -File scripts/ide-map.ps1 -Verify
```

## Se qualcosa non va

| Sintomo | Cosa fare |
|---|---|
| L'agente non conosce `sb prompt` | Riavvialo e apri una nuova sessione |
| Dopo l'attivazione `-Check` termina con codice 1 | Leggi le voci in `issues`: spesso sono solo promemoria |
| Vuoi tornare indietro | [Ripristina un file](sicurezza.md#ripristina-un-file) |

Prossimo passo: [uso quotidiano](uso-quotidiano.md). Tutte le opzioni: [configurazione](riferimento/portable-brain.md#configurazione-e-prerequisiti).
