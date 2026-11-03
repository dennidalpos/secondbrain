# SYS01 — Verifica gli IDE; mappa, registra account o riallinea su richiesta

> **Scope**: central | **Modalità**: verifica | **Cosa serve**: installazioni IDE e autorizzazioni locali; per registrare account anche postazione attivata e consenso | **Esempio d'uso**: `sb prompt SYS01: registra un ide con due account o due radici`

## Scopo

Controllare l’integrazione degli IDE e degli agenti con le direttive approvate e, su richiesta, registrare uno stesso IDE usato con più account, profili o radici di configurazione come integrazioni distinte, così che gli allineamenti futuri le distinguano e segnalino i testi obsoleti.

## Quando usarlo

Nella manutenzione centrale della postazione; la verifica in lettura è il caso predefinito. La registrazione serve quando un IDE ha più account (per esempio l’app Claude con due login) o più radici (per esempio `CLAUDE_CONFIG_DIR` o `CODEX_HOME` diversi), o dopo un nuovo accesso. Con un solo account e la radice predefinita bastano SYS03 e la verifica.

## Input

Configurazione locale, runtimeRoot, mappa IDE e richiesta (verifica, mappa, riallinea o registra). Per la registrazione: postazione attivata, IDE rilevati da SYS03 e, per ogni integrazione, alias dichiarato dall’utente, profilo, ambiente ed eventuale percorso del file di istruzioni.

## Attività specifiche

Verifica: esegui `ide-map.ps1 -Verify`. Per mappare consulta fonti ufficiali e superfici installate; per riallineare usa solo il testo globale approvato, backup verificati e conservazione del testo personale. Il monitor non rileva IDE e non ne scrive i file. Usa SYS03 per discovery e selezione. Distingui installazione, profilo, ambiente e account; registra un alias locale, revisione/hash osservati e prova di caricamento. Una nuova identità account invalida il riscontro precedente. Un file allineato a una revisione può coesistere con istruzioni account più vecchie: segnala il disallineamento. L’allineamento account è assistito soltanto se autorizzato e possibile; niente automazione del login. Le superfici non osservate restano unverified; exit 0 sui file non certifica gli account.

Registrazione di più account o radici: mostra prima il disclaimer e prosegui solo dopo conferma (SecondBrain non rileva gli account né legge archivi di autenticazione: l’account è dichiarato dall’utente e provato da una ricevuta di osservazione; `.runtime` non si pubblica). Verifica lo stato con `secondbrain.ps1 -Setup -Status`, raccogli le decisioni e registrale con lo script guidato, senza scrivere selection.json a mano: `secondbrain.ps1 -Setup -IdeAccount "id-o-nome|alias[|profile=..|environment=..|path=..|revision=..|hash=..]"`, più voci separate da `;`. `path` vale solo per gli IDE di tipo file, assoluto, sotto il profilo utente e con il nome file atteso; voci con stesso profilo, alias, ambiente e percorso sono duplicati e vengono rifiutate. Senza -Apply esegue l’anteprima; `-Yes` e `-Apply` solo dopo la conferma finale. Ritira un accesso superato con `-Unbind <id>` (i file dell’IDE restano). Per le superfici manuali senza file (per esempio le istruzioni dell’account Claude) l’aggiornamento è assistito: l’utente incolla il testo approvato da `runtimeRoot/istruzioni-globali.md`, salva, ricarica e rilegge l’hash; registra revisione e hash con `revision=` e `hash=` e conserva la ricevuta in `.runtime`.

## Decisioni da raccogliere

- operazione: verifica, mappa, riallinea o registra;
- IDE da registrare, numero di account o radici, alias, profilo e ambiente di ogni integrazione;
- percorso del file di istruzioni di ogni radice alternativa (solo IDE di tipo file);
- conferma del disclaimer e conferma finale prima di `-Yes` e `-Apply`.

## Verifiche

Ripeti la verifica dopo le scritture autorizzate con `ide-map.ps1 -Verify` e `secondbrain.ps1 -Check`: ogni integrazione compare con id e alias e un testo osservato diverso dall’approvato è `ide-directive-stale` (revisione osservata e attesa). Distingui file allineato, testo account osservato, caricamento in una nuova sessione e superfici manuali non osservate.

## Consegna

Esiti per IDE, prove e passaggi manuali; per la registrazione, integrazioni registrate (id, alias, profilo, ambiente, percorso) e ricevute. exit 0 non certifica il caricamento. Nessun commit o push implicito.

## Prompt vicini

- MEM01: Allinea istruzioni locali, contesto, memoria e tracker.
- SYS02: Verifica le fonti autorevoli; acquisisci o aggiorna su richiesta.
- SYS03: Attiva SecondBrain dopo discovery e selezione degli asset.
- SYS04: Controlla o allinea gli asset già gestiti della postazione.
- SYS15: Installa il server MCP SecondBrain negli IDE e verifica l'handshake.
