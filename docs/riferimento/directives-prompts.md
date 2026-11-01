# Direttive e cataloghi

Le regole comuni attive sono [AGENTS.global_ide.md](../../direttive/AGENTS.global_ide.md) e [workstation.template.md](../../direttive/workstation.template.md), [approved.json](../../direttive/approved.json) registra hash e autorizzazione. La [proposta iniziale](../../direttive/proposals/2026-11-01-v1.0/README.md) contiene il testo approvato.

Per cambiare le regole: proposta concreta, approvazione esplicita dei due testi, registrazione con `approve-revision.ps1 -ProposalPath <cartella> -Authorization <riscontro> -ConfigPath <config>`, Sync e [SYS01](adapters.md). Non modificare hash o blocchi generati per eludere il processo.

Gli AGENTS applicativi distinguono revisione comune applicata e revisione specifica del progetto. Una marcatura allineata non prova caricamento in sessione o validità tecnica di tutti i contenuti applicativi.

## Uso quotidiano

Nella chat dell'IDE con le direttive caricate:

```text
sb prompt
sb prompt tutti
sb prompt ambito test
sb prompt mostra TST04
sb prompt REP01: completa il prossimo task eseguibile
```

Il [catalogo](../../direttive/prompts/README.md) contiene 80 workflow (COM01–GOV02). La [guida](prompt-workflows.md) descrive CLI, contesto, input e numerazione. I comandi sono istruzioni in chat, non alias installati nella shell. L'agente carica la sola scheda scelta e lavora nel repository corrente, rispettando autorizzazioni e modalità Plan.

## Generazione e verifica

```powershell
$cfg = '.runtime/hosts/<id>/workstation.json'
./scripts/build-prompts.ps1 -Check -ConfigPath $cfg
./scripts/build-prompts.ps1 -ConfigPath $cfg
./scripts/prompts.ps1 -Context -ConfigPath $cfg
./scripts/prompts.ps1 -Compose -Prompt SEC01 -Objective 'Revisionare le modifiche locali' -ConfigPath $cfg
```

Metadati in catalog.json e singole schede Markdown sono le sorgenti; README.md è generato. La CLI compone testo e riferimenti locali, senza eseguire task o inviare dati a modelli. L'eventuale nuovo TXT è creato solo con -OutputPath e non sovrascrive file esistenti.

## Ritiro del catalogo precedente

Gli alias del catalogo sono dichiarati in `catalog.json` accanto all'ID immutabile di ogni prompt (`pmt-` e 8 esadecimali).

Le proposte approvate restano immutabili.

## Manutenzione centrale e prodotti

SecondBrain mantiene direttive, prompt, blocchi AGENTS gestiti e riferimenti. I task prodotto restano ai rispettivi agenti, anche se registrati qui come autonomous. REP01 seleziona solo attività del repository aperto; REP02-MEM01 coprono documentazione, memoria, pulizia e tracker; MEM02 l'importazione nel dossier; SYS01-SYS02 richiedono SecondBrain come repository operativo.

L'agente del prodotto confronta codice e stato Git con dossier corrente, fonte tracker e schede di applicabilità. Consultare un riferimento non autorizza automaticamente esecuzione o modifica delle prescrizioni comuni.
