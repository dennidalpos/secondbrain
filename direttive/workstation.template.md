## Integrazione SecondBrain della postazione

<!-- secondbrain:tracker-contract:1 -->

- Radice: risolvi SECONDBRAIN_HOME dall’ambiente utente; il valore è locale e non va copiato nelle istruzioni account né nei repository pubblici. Il bootstrap dal checkout funziona anche senza variabile. Configurazione e output operativi sono sotto .runtime del clone.
- Dossier: index.md, context.md, memory.md, repository.json e tracker dichiarato. Para-index.json risolve gli identificatori; archivi e conflitti richiedono gestione esplicita.
- Tracker: repository.json con tracker location=dossier, path=tracker.json, schemaVersion=1 richiede esclusivamente quella fonte; assenza o invalidità sono errori senza fallback. Le importazioni preservano originali, task e riferimenti.
- Avvio: scripts/knowledge.ps1 -Startup o -Tasks (o lo strumento MCP get_startup_context); -Profile Full e -Search (-Budget, -Limit, -AllDossiers) per approfondire; -Report misura caratteri e peso delle direttive. Scripts/prompts.ps1 -Context -RepositoryPath risolve soltanto i percorsi del dossier.
- Scritture: la lettura iniziale non usa sessioni Hold. Per scritture prolungate usa scripts/access.ps1 con Start/End nello stesso script (try/finally) e passa SessionId alle CLI; non forzare lock né cancellare marker di transazioni incomplete.
- Comandi sb: sb attiva (SYS03, discovery e conferma prima di ogni scrittura); sb controlla (SYS04, sola verifica); sb allinea (applica testi approvati, preserva conflitti, propone asset nuovi); sb compatta (SYS05, richiede il dossier). Sb prompt riporta integralmente la home dei prompt (scripts/prompts.ps1 o MCP get_prompt_home) senza eseguire primi passi che scrivono file; sb prompt list l’elenco compatto integrale (-List -Compact), una riga per prompt, mai troncato; sb prompt ambito AREA, sb prompt mostra CHIAVE e sb prompt CHIAVE: obiettivo risolvono per ID (pmt-…) o codice allo stesso prompt e caricano soltanto la scheda necessaria.
- Prompt: una sola lista; ogni scheda ha ruolo, contesto, input, procedura, vincoli, criteri di uscita e formato, e la composizione è strutturata in XML. In caso di dubbio chiedi con scelta strutturata.
- IDE: SYS01 distingue file locale, installazione, profilo, ambiente e account; un file allineato non dimostra il caricamento e il login non si automatizza. Scripts/trace.ps1 -InstallHook (anteprima, poi -Apply) installa l’hook Stop di Claude Code per l’avviso di compattazione.
- Modifiche: per i blocchi gestiti cambia i generatori, non snapshot o blocchi a mano. Le nuove prescrizioni comuni richiedono proposta concreta, approvazione esplicita e hash verificati prima della distribuzione.

- Ciclo memorie per repository: memory-cycle.ps1 e bridge con permesso verificato del turno. In sola lettura usa knowledge.ps1 -NoRecovery o server MCP avviato con -NoRecovery. Workspace evidence per registri e originali; nessuna importazione automatica delle vecchie chat.
