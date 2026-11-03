# REP13 — Allinea pagina GitHub, file della community e sicurezza, dopo conferma

> **Scope**: repo | **Modalità**: scrittura | **Cosa serve**: `gh` con diritti di amministratore ed esito di SEC07 | **Esempio d'uso**: `rendi trovabile questo repository e applica la sicurezza standard`

## Scopo

Portare la pagina GitHub e le impostazioni del repository a una base standard — trovabile nelle ricerche, profilo della community completo e funzioni di sicurezza attive — proponendo ogni modifica come scelta e applicando solo ciò che l'utente conferma.

## Quando usarlo

Prima o dopo la prima pubblicazione, quando alla pagina mancano descrizione, topic o politica di sicurezza, o quando le impostazioni si sono allontanate dallo standard. Da lanciare nella sessione del repository interessato.

## Input

Il repository e il suo remoto, la visibilità (`gh repo view --json visibility`), i dati About e i topic, le impostazioni e le funzioni di sicurezza (`gh api repos/{owner}/{repo}`), protezione del ramo e ruleset del ramo predefinito, il profilo della community (`gh api repos/{owner}/{repo}/community/profile`), i file locali (README, LICENSE, `SECURITY.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, form e template in `.github/`, `CODEOWNERS`) e l'esito di SEC07 o `check_publication`.

## Attività specifiche

Rileva prima, con sole chiamate in lettura: visibilità, tipo di proprietario, autenticazione di `gh`, permesso di amministratore e valore attuale di ogni voce. Un repository privato non viene mai reso pubblico e qui non se ne cambia la visibilità; per uno pubblico esegui prima SEC07 e fermati a ogni rilievo. Poi costruisci la proposta per gruppo, mostrando per ogni voce valore attuale, valore proposto, motivo, comando `gh` e valore di ripristino:

- **A. Visibilità nelle ricerche**: una descrizione About di una frase (che cos'è, per chi, tecnologia principale), da 5 a 12 topic specifici in minuscolo, un sito web solo se esiste e un README che dice che cosa fa, come si installa e si usa e quali sono i limiti (DOC01).
- **B. File della community**: `SECURITY.md` con un canale di segnalazione privato, LICENSE, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, form delle issue, template di pull request e `CODEOWNERS` quando lavora più di una persona. I file mancanti si creano solo nel working tree e restano senza commit (OPS05).
- **C. Sicurezza**: secret scanning e push protection, alert e aggiornamenti di sicurezza di Dependabot, segnalazione privata delle vulnerabilità, permessi predefiniti di sola lettura per Actions e, per il ramo predefinito, uno di tre livelli: nessuno, blocco di force-push ed eliminazione, oppure pull request e controlli obbligatori.
- **D. Impostazioni**: Issues attive solo con i form, Wiki, Discussions e Projects disattivi se non usati, eliminazione del ramo dopo il merge e metodi di merge ammessi dalla politica del progetto (REP12).

Proponi ogni gruppo come scelta multipla: applica tutte le proposte, applica solo le voci scelte oppure salta il gruppo. Applica le voci confermate una alla volta (`gh repo edit` per i dati About e le funzioni, `gh api` per il resto), rileggile e fermati al primo errore. Segnala come non disponibile, con il motivo, ogni voce che richiede un altro piano, una politica dell'organizzazione o un permesso che l'account non ha, invece di fallire in silenzio. Non inserire mai segreti, dati personali o percorsi dell'host nei testi, non passare token nella riga di comando e non cambiare mai visibilità, proprietà o stato di archiviazione.

## Decisioni da raccogliere

- i gruppi da applicare (da A a D, anche più di uno);
- descrizione e topic tra le varianti proposte, e la loro lingua;
- i file della community mancanti da creare nel working tree;
- il livello di protezione del ramo, con l'avviso che richiedere le pull request blocca i push diretti per un proprietario singolo;
- i metodi di merge da ammettere;
- la conferma di ogni impostazione prima di applicarla.

## Verifiche

Controlla che SEC07 o `check_publication` fosse pronto prima di ogni proposta di visibilità, che ogni impostazione applicata si rilegga come confermata, che nulla fuori dalle voci confermate sia cambiato e che la visibilità sia invariata. Confronta la percentuale del profilo della community prima e dopo.

## Consegna

Una tabella prima e dopo per ogni voce, i comandi eseguiti con i valori di ripristino, i file creati e lasciati senza commit e le voci saltate o non disponibili con il motivo.

## Prompt vicini

- SEC07: Controlla diff, repository e cronologia per dati sensibili prima di pubblicare.
- SEC06: Rafforza configurazione del repository, CI, container e accessi.
- REP11: Segnala un errore come issue GitHub nel formato del form, dopo conferma.
- DOC01: Scrivi guide e README coerenti con il prodotto reale.
