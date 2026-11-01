# Configurazione

SecondBrain richiede Windows, Git e PowerShell 7.5+. Il bootstrap non installa software, non richiede percorsi preimpostati e non registra monitor.

## Procedura rapida

Prima leggi [cosa modifica SecondBrain e dove sono i backup](safety-backups.md). Dalla radice del clone, in PowerShell 7.5+:

```powershell
# 1. Clone (privato o tuo fork) e ingresso nella cartella: scegli un percorso senza spazi
git clone https://github.com/dennidalpos/SecondBrain.git C:/Progetti/SecondBrain
cd C:/Progetti/SecondBrain

# 2. Schermata iniziale (è ciò che mostra `sb prompt` in chat) e controllo in sola lettura
pwsh -NoProfile -File scripts/prompts.ps1
pwsh -NoProfile -File scripts/secondbrain.ps1 -Check

# 3. Attivazione guidata: elenca repository e IDE, scrive solo dopo CONFERMO e APPLICA
pwsh -NoProfile -File scripts/secondbrain.ps1 -Setup -Interactive

# 4. Server MCP: anteprima, poi applicazione a un IDE (backup automatico)
pwsh -NoProfile -File scripts/mcp-server.ps1 -Pair -Target claude
pwsh -NoProfile -File scripts/mcp-server.ps1 -Pair -Target claude -Apply

# 5. Direttive globali: distribuzione del blocco gestito e verifica
pwsh -NoProfile -File scripts/secondbrain.ps1 -Sync
pwsh -NoProfile -File scripts/ide-map.ps1 -Verify
```

`SECONDBRAIN_HOME` è una variabile utente impostata da `-Setup -Apply` (non con `-NoRegisterEnvironment`): indica il clone ai tuoi agent. Gli IDE già aperti vanno riavviati per leggerla. Per gli IDE senza file locale (impostazioni account web, Continue, Android Studio) copia a mano il testo di `.runtime/hosts/<id>/istruzioni-globali.md`: vedi [guida utente](user-guide.md).

## Primo avvio con un agent

Apri il checkout SecondBrain nell'IDE e scrivi `sb attiva`. Se l'IDE non carica AGENTS.md, usa il [prompt completo nel README operativo](portable-brain.md#avvio-da-un-nuovo-pc). SYS03 guida discovery, selezione e attivazione tramite `scripts/secondbrain.ps1 -Setup` (utilizzabile anche senza agent: `-Setup -Interactive`): i repository scoperti non vengono gestiti finché non li selezioni.

Il clone corrente viene registrato nella variabile utente `SECONDBRAIN_HOME`. Configurazione, inventario host, backup e output restano sotto `.runtime` nel clone e sono esclusi da Git. Ogni PC mantiene la propria mappa; dossier e identità sono condivisi tramite il Git privato di SecondBrain.

## File e percorsi

La configurazione locale viene generata dall'attivazione. [L'esempio schema 3](../config/workstation.example.json) illustra i campi senza contenere percorsi personali; non copiarlo come autorizzazione a gestire asset. `-ConfigPath` è un override esplicito; in assenza di override le CLI risolvono la configurazione della postazione.

Le istruzioni comuni e gli account IDE non devono contenere percorsi del singolo PC. Gli IDE già aperti possono avere una vecchia copia dell'ambiente di processo: verificare il valore utente aggiornato senza sovrascrivere variabili globali dei tool prodotto.

## Schemi e avvio

| Dato | Schema |
|---|---|
| Configurazione postazione portabile | 3 |
| Inventario locale | 4 |
| Mappa IDE con profili e account | 2 |
| Metadati PARA e tracker dei dossier | 1 |
| Catalogo prompt | schema 1, catalogo v2 |

Per una postazione già configurata con versioni precedenti, chiudere la sessione Write attiva e rieseguire `secondbrain.ps1 -Setup`. Non eliminare dati locali o directory runtime per forzare una riattivazione.

## Verifiche e limiti

Eseguire suite principale, Check, verifica IDE e catalogo. File allineati, account osservati, funzionamento reale e copertura della scansione sono esiti distinti. La prova di portabilità su un secondo PC rimane distinta dalle fixture.

La prima implementazione usa Windows; non è dichiarato supporto macOS/Linux. [Dettagli operativi e contratti](portable-brain.md). JSON è validato con [PowerShell Test-Json](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/test-json?view=powershell-7.5).
