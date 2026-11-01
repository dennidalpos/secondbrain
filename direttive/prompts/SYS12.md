# SYS12 — Registra un IDE con più account o percorsi, con disclaimer e conferma

> **Scope**: central | **Modalità**: scrittura | **Cosa serve**: postazione attivata, IDE rilevato, alias degli account e consenso utente | **Esempio d'uso**: `sb prompt SYS12: registra un ide con due account o due radici`

## Scopo

Registrare in SecondBrain uno stesso IDE o agent usato con più account, profili o radici di configurazione, come integrazioni distinte, così che gli allineamenti futuri le distinguano e segnalino i testi obsoleti.

## Quando usarlo

Quando un IDE ha più account (es. app Claude con due login) o più radici (es. `CLAUDE_CONFIG_DIR` o `CODEX_HOME` diversi), o dopo un nuovo accesso. Non serve per un solo account con la radice predefinita: bastano SYS03 e SYS01.

## Input

Postazione attivata, IDE rilevati da SYS03 e, per ogni integrazione, alias dichiarato dall’utente, profilo, ambiente ed eventuale percorso del file di istruzioni.

## Attività specifiche

Mostra prima il disclaimer e prosegui solo dopo conferma: SecondBrain non rileva gli account e non legge archivi di autenticazione; l’account è dichiarato dall’utente (alias) e provato da una ricevuta di osservazione. Un file allineato o una ricevuta non provano il caricamento nelle chat. Niente automazione del login. `.runtime` non si pubblica.

Verifica lo stato con `secondbrain.ps1 -Setup -Status` e la discovery con SYS03. Per ogni integrazione raccogli le decisioni, poi registrale con lo script guidato (l’agente non scrive selection.json a mano): `secondbrain.ps1 -Setup -IdeAccount "id-o-nome|alias[|profile=..|environment=..|path=..|revision=..|hash=..]"`, più voci separate da `;`. `path` (percorso alternativo) vale solo per gli IDE di tipo file (Claude Code, Codex, Antigravity): assoluto, sotto il profilo utente, con il nome file atteso. Voci con stesso profilo, alias, ambiente e percorso sono duplicati e vengono rifiutate. Senza -Apply esegue l’anteprima; -Yes e -Apply solo dopo la conferma finale. Ritira un accesso superato con `-Unbind <id>` (i file dell’IDE restano).

Per le superfici manuali senza file (es. istruzioni dell’account Claude) l’aggiornamento del testo è assistito e autorizzato dall’utente, che esegue il login: incolla il testo approvato da `runtimeRoot/istruzioni-globali.md`, salva, ricarica e rileggi l’hash. Registra revisione e hash osservati con `revision=` e `hash=` (solo IDE manuali, insieme) e conserva la ricevuta in `.runtime`; usa `-ObservationPath` solo per prove di caricamento in una sessione nuova.

## Decisioni da raccogliere

Se più opzioni non sono ricavabili dal codice o dalle fonti, fermati e usa Function Calling o Tool Use a scelta multipla (es. `ask_question`, `AskUserQuestion`): una decisione per domanda, scelta raccomandata come prima opzione con `(Recommended)`, opzioni atomiche e non numerate; scelta multipla quando le opzioni non si escludono.

- IDE da registrare e numero di account o radici;
- alias, profilo e ambiente di ogni integrazione;
- percorso del file di istruzioni di ogni radice alternativa (solo IDE di tipo file);
- conferma del disclaimer e conferma finale prima di `-Yes` e `-Apply`.

Senza lo strumento, elenca opzioni numerate e attendi la risposta. Non richiedere di nuovo ciò che è già autorizzato nel perimetro del task.

## Verifiche

Esegui `ide-map.ps1 -Verify` e `secondbrain.ps1 -Check`: ogni integrazione compare con id e alias e un testo osservato diverso dall’approvato è `ide-directive-stale` (revisione osservata e attesa). Distingui file allineato, testo account osservato e caricamento in una nuova sessione.

## Consegna

Integrazioni registrate (id, alias, profilo, ambiente, percorso), ricevute, esiti per account e passi manuali ancora necessari. Nessun commit o push implicito.

## Prompt vicini

- SYS01: Verifica gli IDE; mappa o riallinea su richiesta.
- SYS03: Attiva SecondBrain dopo discovery e selezione degli asset.
- SYS04: Controlla o allinea gli asset già gestiti della postazione.
