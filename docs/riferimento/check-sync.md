# Controllo e sincronizzazione su richiesta

SecondBrain non programma scansioni, controlli o aggiornamenti in background: Check e Sync si eseguono solo su richiesta.

## Controllare e aggiornare

Nella chat dell'IDE, `sb controlla` carica SYS04 in verifica; `sb allinea` applica gli aggiornamenti già autorizzati nel perimetro gestito. Entrambi distinguono i nuovi asset che richiedono selezione tramite SYS03.

```powershell
pwsh -NoProfile -File scripts/secondbrain.ps1 -Check
pwsh -NoProfile -File scripts/secondbrain.ps1 -Sync
```

Check non corregge e non prende lock bloccanti: con un writer attivo o una transazione interrotta il JSON contiene `warnings` (`concurrent-writer`, `pending-transaction`) e il risultato può essere intermedio. Sync usa lock, backup verificati e stato per rilevare modifiche concorrenti; aggiorna TOC e indici. Distribuisce soltanto direttive comuni approvate, conserva il testo personale e segnala conflitti. Una proposta non approvata non viene distribuita.

## Output e stato

L'inventario e la mappa IDE risiedono nel runtime locale della postazione. I dossier e l'indice PARA sono condivisi. La presenza di un nuovo checkout nel filesystem non lo aggiunge al perimetro gestito; l'assenza di un percorso non elimina dossier o task.

Il pacchetto iniziale (profilo snello) comprende TOC, sezioni essenziali di contesto e memoria, task pronti in una riga e l'elenco dei livelli non caricati. Quando supera il tetto del primo caricamento (20.000 caratteri, solo per l'avvio), SYS04 prepara con SYS05 una compattazione revisionata; la CLI non inventa sintesi e non tronca dati. Gli originali restano conservati.

| Exit code | Significato |
|---|---|
| 0 | Verifiche richieste concluse senza segnalazioni |
| 1 | Disallineamenti, conflitti o verifiche mancanti |
| 2 | Errore operativo o discovery incompleta |
| 3 | Lock di scrittura non ottenuto entro l'attesa (`-WaitSeconds`, predefinita 60 s) |

Il risultato JSON espone i problemi specifici. Le prove IDE sono vincolate alla sessione e all'account osservati: il confronto dei file non certifica il caricamento.

## Recupero

Non esistono monitor o task pianificati.

Per interruzioni usare il [recupero da manifest](recovery.md) e la [guida portabile](portable-brain.md).
