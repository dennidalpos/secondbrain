# Gotchas Catalog & Troubleshooting

> Catalogo di esperienze contestuali, non direttive universali. Ogni voce va verificata rispetto al progetto, al runtime e alle versioni attuali. Gli imperativi storici sotto riportati descrivono il contesto di origine, non autorizzano modifiche automatiche. Consultare solo le voci pertinenti.


`v1.1 · 2026-10-15` — Catalogo ragionato di bug d'ambiente, particolarità di piattaforma e soluzioni testate.

## 1. Ambiente Windows, PowerShell & COM
- **Line Endings (CRLF vs LF)**:
  * Evitare conversioni massive involontarie.
  * Mantenere `.gitattributes` con `* text=auto eol=lf` dove opportuno per build cross-platform coerenti.
  * Marcare `*.pdf binary`: PDF con stream ASCII85, come quelli di ReportLab, possono essere rilevati come testo da Git. La conversione dei fine riga invalida gli offset del PDF; confrontare i byte del file con il blob indicizzato prima del commit.
- **PowerShell Execution & Path Escaping**:
  * Attenzione agli spazi nei percorsi (es. cartelle Google Drive con "Il mio Drive"): usare sempre virgolette doppie o stringhe interpolate corrette.
  * Utilizzare percorsi con forward slash (`/`) negli URL markdown `file:///` e tool multi-piattaforma.
- **Encoding**:
  * UTF-8 senza BOM obbligatorio su tutti i nuovi file di configurazione, codice e documentazione.
- **Build e smoke test Windows**:
  * Eseguire in sequenza build e smoke test che caricano gli stessi assembly dalla cartella di output: il processo PowerShell può bloccare le DLL e produrre avvisi di copia `MSB3026` nella build parallela.
- **Download con redirect sullo stesso file**: attendere la chiusura e la rimozione dello stream parziale prima di avviare il redirect successivo. Avviare due stream sullo stesso percorso può produrre `EPERM` e callback tardivi dopo la conclusione del test o la pulizia della directory.
- **Firma Authenticode con certificato autofirmato**: `signtool sign` può riuscire e applicare un timestamp valido mentre `signtool verify /pa` fallisce perché la radice del firmatario non è attendibile sulla macchina di build. Confrontare l'impronta del firmatario con il certificato pubblico previsto; rendere attendibile solo quel certificato con una decisione esplicita, senza disattivare la verifica né rigenerare la chiave.
- **Avvio WinForms a istanza singola**: un evento di attivazione interprocesso può arrivare prima della registrazione del gestore o durante la costruzione del contesto tray. Conservare la richiesta fino al termine della costruzione e mostrare la finestra sul thread UI; il processo secondario deve ritentare brevemente se il primario ha creato il mutex ma non ancora l'evento. Uno smoke con ciclo WinForms reale deve isolare configurazione, preferenze, archivio e nome del segnale.
- **Contesto di sincronizzazione WinForms catturato troppo presto**: `SynchronizationContext.Current ?? new WindowsFormsSynchronizationContext()` non è sicuro, perché prima del primo controllo `Current` può essere un `SynchronizationContext` di base non null, il cui `Post` esegue sul thread pool. Una finestra creata lì resta "Non risponde" con i controlli bianchi. Creare esplicitamente `new WindowsFormsSynchronizationContext()` sul thread UI. Diagnosi: confrontare il thread proprietario della finestra (`GetWindowThreadProcessId`) con il thread principale del processo. Verificato con test WinForms STA e sul processo bloccato.
- **Testo copiabile in WinForms**: le `Label` non consentono selezione; per diagnostica e messaggi lunghi usare superfici di testo native in sola lettura. `Enabled=false` sul contenitore impedisce anche la copia: bloccare i controlli modificabili lasciando abilitati testi informativi e log. Verificato con controlli isolati e blocco/sblocco del ConfigTool.
- **Schede WinForms disegnate a mano**: esporre ruolo, stato selezionato e notifiche tramite `AccessibleObject`; un contenitore personalizzato deve esplicitare figli e selezione. Attivando una pagina di un `TabControl` nativo il focus può spostarsi nel contenuto: per continuare con le frecce ripristinarlo sulla scheda dopo il cambio, non prima. Verificato con test WinForms STA.
- **Test tastiera WinForms su desktop interattivo**: `PreProcessMessage` combina i messaggi sintetici con `ModifierKeys` reali e rende i test intermittenti. Per provare la navigazione del controllo, chiamare `ProcessDialogKey` con il valore `Keys` esplicito senza modificare lo stato della tastiera dell'utente.
- **Host COM & Uscita Applicazione**: Alla chiusura di un'app host COM (es. Outlook), il callback di uscita deve annullare solo il lavoro gestito, senza effettuare nuove chiamate COM. Dopo ogni `await` di estrazione o inferenza modello, ricontrollare il cancellation token prima di accedere nuovamente all'host o salvare.

## 2. Package Managers & Toolchain
- **Dipendenze transitive nei probe**: Gli script diagnostici devono risolvere una dipendenza transitiva tramite il pacchetto diretto che la dichiara. Un import diretto può funzionare solo grazie all'hoisting corrente del lockfile e fallire con `knip` o dopo una reinstallazione.
- **Audit Python di build congelate**: confrontare il lock generato con il manifest dell'ambiente prima di interrogare gli advisory; i soli `.dist-info` in un bundle PyInstaller possono rappresentare una frazione del set. `pip freeze` può omettere `pip`: confrontare i nomi/versioni normalizzati e registrare il perimetro realmente scansionato.
- **Pacchetti NuGet `Microsoft.Office.Interop.*` 15.0.4797.1004**: sono ripubblicazioni comunitarie degli assembly Microsoft (owner non verificato, nessuna licenza nei metadati del nuspec). Usarli solo con `EmbedInteropTypes=true`, così nessun file interop viene ridistribuito, e dichiararlo negli avvisi di terze parti; verificare licenza e owner dal nuspec su `api.nuget.org/v3-flatcontainer` prima di aggiungere un pacchetto. Verificato su OnlyWorkspace il 2026-10-15.
- **Conflitti di dipendenze / Lockfile**:
  * Mai modificare manualmente i lockfile (`package-lock.json`, `pnpm-lock.yaml`).
  * In caso di corruzione: eliminare `node_modules` e reinstallare tramite il package manager del progetto.
- **Build & TypeScript Typecheck**:
  * Eseguire sempre `tsc --noEmit` prima della build per intercettare errori di tipo che i bundler veloci (es. Vite) potrebbero ignorare durante la sola transpilazione.

## 3. Gestione del Contesto negli Agenti AI
- Le skill di un prodotto possono avere metadati YAML propri: verificare frontmatter e trigger con il parser/runtime che le carica. Un validatore generico Codex può rifiutare campi supportati dal prodotto, come `triggers` e `tags`.
- **Debug audit con opt-in unico**: se un log deve spiegare una run fallita, registrare ogni fase e i payload richiesti dall'utente con un solo interruttore; oscurare le credenziali, mantenere errori e percorsi utili, e applicare rotazione e retention esplicite.
- **Audit con delta e rotazione**: se una voce comprime un payload riferendosi a una baseline precedente, azzerare l'ancora a ogni rotazione affinché ogni generazione conservata resti ricostruibile da sola. Nel readback identificare le voci dai loro campi strutturati, non da sottostringhe nel payload; su errore di rotazione non troncare il file corrente.
- **Context Pollution**:
  * Sessioni troppo lunghe degradano la precisione dell'agente. Usare `/compact` o riavviare la sessione leggendo `memory.md` e `PROJECT_STATUS.json`.
- **Modifiche distruttive non volute**:
  * Verificare sempre `git diff` prima del gate finale di commit e push.

## 4. Strumenti Web dei provider IA
- Verificare la capacità del modello senza dati utente e annullare le verifiche superate da un cambio di modello; un elenco modelli non basta a provare il supporto dello strumento.
- Le API di ricerca possono restituire HTTP 200 con un errore dello strumento nel corpo (Anthropic). Validare l'esecuzione della ricerca, i limiti e gli URL delle fonti prima di mostrare la risposta come fondata sul web.
- Gemini può accettare `google_search` senza eseguire una ricerca: la sola presenza di `candidates` non prova il supporto operativo. Nella sonda richiedere metadati di grounding con query o fonti; altrimenti segnare l'esito come inconcludente.
- Un endpoint Responses compatibile OpenAI può divergere sui parametri e sul JSON restituito: QwenCloud ha rifiutato `tool_choice: required` per un modello Qwen e può omettere `status` da `web_search_call`. Usare la forma documentata dal provider e richiedere fonti HTTPS verificabili prima di accettare il risultato; ignorare le fonti associate a chiamate fallite.
- In un flusso IA con opt-in web per singola azione, fissare la scelta all'avvio e conservarla nella riprova; mostrare il risultato web in una sezione distinta quando l'azione produce anche conclusioni locali, così l'evidenza esterna non viene attribuita ai controlli locali.
- Uno schema JSON vincola la forma della risposta, non la correttezza semantica: in una prova Ollama su documento lungo il campo era valido ma conteneva il valore sbagliato. Indicare con precisione la riga sorgente e verificare il contenuto atteso.

## 5. Backup ZIP di configurazione
- Se il formato ammette pochi file, leggere solo i nomi consentiti con limiti di dimensione durante la decompressione; rifiutare percorsi e duplicati prima di scrivere la configurazione. L'estrazione indiscriminata in una cartella temporanea amplia inutilmente la superficie per ZIP ostili.

## 6. WebView2 e HTML incorporato
- Con `NavigateToString`, la navigazione può apparire come `data:text/html;charset=utf-8;base64,...` in `NavigationStarting`, mentre il documento e `WebMessageReceived.Source` risultano `about:blank`. Per un bridge nativo, ammettere solo il payload `data:` esatto prodotto dall'host per quel caricamento, una sola volta, e verificare la sorgente del messaggio e del documento prima di agire. Provare il comportamento con il runtime installato: un test della sola regola non rivela la differenza tra URI di navigazione e sorgente finale.

## 7. Ripristino di più file
- Quando un backup aggiorna configurazione e vault separati, validare tutto prima di scrivere, preparare i nuovi file sul volume di destinazione e conservare la versione precedente del primo file finché il secondo non è stato sostituito. Su errore della seconda scrittura, ripristinare il primo; se il rollback fallisce, preservare la copia precedente e indicarne il percorso. Le sostituzioni di singoli file non rendono atomica la coppia rispetto a crash o lettori concorrenti.

## 8. Riconciliazione di indici locali
- Una scansione interrotta o basata su cache non prova l'assenza di un elemento: conservare la scansione aperta attraverso il riavvio e marcare assenti i record mancanti solo dopo un inventario completo e verificato. Per elementi privi di ID stabile, non fondere copie usando solo attributi descrittivi; possono essere duplicati reali.
- Nella scoperta di archivi migrati, aprire prima il formato nuovo valido. I nomi legacy normalizzati possono collidere tra profili distinti: leggere l'identità interna di ogni copia valida prima di considerarla sostituita; ignorare una copia illeggibile solo se il suo percorso corrisponde a un profilo nuovo già aperto. Senza un sostituto valido, mantenere il blocco per non nascondere dati indisponibili.
- Quando una preferenza disabilita l'indicizzazione di una fonte, eliminare anche i riepiloghi derivati che potrebbero incorporarne il contenuto. Ricontrollare la preferenza prima del salvataggio di lavori IA avviati in precedenza, oltre a rimuovere i termini dall'indice.
- Se più sorgenti condividono un provider cloud, salvare il consenso per sorgente e versione della policy. Filtrare la coda sulle sorgenti autorizzate e ricontrollare la decisione nella transazione che salva il risultato: una risposta tardiva dopo una revoca non deve comparire nell'indice. Un cambio di policy deve invalidare anche i consensi delle sorgenti temporaneamente chiuse.

## 9. Contatori di uso IA in streaming
- Una richiesta annullata localmente può essere già stata elaborata dal provider; se l'uso token arriva solo nell'ultimo blocco, non interpretare la sua assenza come consumo zero. Registrare un tentativo persistente prima dell'invio, chiuderlo atomicamente con l'uso osservato e sospendere altri invii soggetti a quota fino alla fine della finestra se il consumo resta ignoto. Tenere separati token misurati e tentativi incerti.

## 10. Installer di terze parti
- Se manca un digest autenticato o una firma verificabile prima dell'esecuzione, aprire una pagina ufficiale costante nel browser invece di scaricare ed eseguire il binario nell'app. Distinguere apertura della pagina, download, installazione e disponibilità del servizio negli esiti e nella UI.

## 11. Journal di cancellazione con staging
- Pubblicare un'operazione distruttiva solo dopo manifest e backup con readback completo. Al riavvio, promuovere lo staging integro; conservare e rendere esportabile quello incompleto senza bloccare dati non coinvolti. Verificare separatamente il ripristino dopo pulizia parziale; la terminazione di processo non prova la durata a perdita di alimentazione.

## 12. Salvataggi differiti e chiusura desktop
- La pulizia asincrona di una vista React non garantisce il salvataggio alla chiusura. Per revisioni che devono sopravvivere a un salvataggio canonico rifiutato, richiedere prima un acknowledgment di staging persistente dal processo Main; eliminare lo staging solo dopo l'acknowledgment della stessa revisione. Al riavvio, Retry deve confrontare la base canonica ed evitare di sovrascrivere una revisione divergente; Export conserva una via di recupero manuale.

## 13. Database locali & SQLite
- Per database SQLite con WAL e VACUUM, misurare `AvailableFreeSpace` sul volume del file: WAL e file temporanei consumano spazio disponibile. Prima di VACUUM, verificare un margine per una copia temporanea fino a circa due volte il DB oltre alla riserva operativa minima.
