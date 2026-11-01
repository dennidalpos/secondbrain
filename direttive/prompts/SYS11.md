# SYS11 — Aggiungi, modifica o rimuovi un prompt del catalogo centralizzato

> **Scope**: central | **Modalità**: scrittura | **Cosa serve**: catalogo valido, area di destinazione e sessione di scrittura | **Esempio d'uso**: `sb prompt SYS11: aggiungi un prompt al catalogo nell'area test`

## Scopo

Aggiungere, modificare o ritirare un prompt del catalogo centralizzato mantenendo ID immutabili, alias risolvibili, schede uniformi, indice generato e riferimenti coerenti.

## Quando usarlo

Quando un workflow manca, va corretto o non serve più. Non per cambiare il testo delle direttive comuni (SYS04 e approvazione esplicita) né per le schede di un solo repository.

## Input

Operazione richiesta (aggiungi, modifica, rimuovi), codice o ID del prompt, area, modalità, scope, testo della scheda e prompt collegati. Catalogo `direttive/prompts/catalog.json`, schede `direttive/prompts/*.md`, schema `config/prompt-catalog.schema.json`.

## Attività specifiche

Leggi catalogo e schede senza modificarli e individua l'operazione. Lavora in una sessione di scrittura (`scripts/access.ps1 -Start -Mode Write`, `-End` nello stesso script).

**Aggiungi.** Scegli il codice libero della sua area (`^[A-Z]{2,4}[0-9]{2}$`, numerazione successiva, nessun riuso di codici ritirati), genera un ID `pmt-` con 8 esadecimali non presente tra ID, alias e `deprecations`, scrivi la scheda `CODICE.md` con intestazione standardizzata e tutte le sezioni (Scopo, Quando usarlo, Input, Attività specifiche, Verifiche, Consegna, Prompt vicini; «Decisioni da raccogliere» se il prompt chiede scelte) e aggiungi la voce a `catalog.json` con `file`, `summary` (codice e titolo entro 88 caratteri), `example`, `requires`, `references`, `related`. Titolo, intestazione (scope, modalità, «Cosa serve», esempio) e voci di «Prompt vicini» della scheda ripetono parola per parola `summary`, `scope`, `mode`, `requires`, `example` e il `summary` dei prompt in `related` (il controllo li rifiuta se divergono). Ogni prompt collegato deve comparire con il suo codice nella scheda, in entrambe le direzioni.

**Modifica.** L'ID e gli alias esistenti non cambiano mai. Un cambio di corpo, titolo, modalità o scope aggiorna scheda e voce insieme. Se il codice cambia, il vecchio codice resta come alias oppure in `deprecations` verso lo stesso ID; i collegamenti `related` usano ID e restano validi.

**Rimuovi.** Per impostazione predefinita ritira, non cancellare (ritiro morbido): imposta `status: deprecated` con `supersededBy` (un ID attivo diverso) e lascia voce, scheda e ID come storico. Il codice resta nel catalogo e continua a risolvere al sostituto con avviso: non registrarlo in `deprecations`, perché un codice ancora presente occupa già il nome e il validatore rifiuta il conflitto. L'eliminazione definitiva (voce e scheda) o la rinomina del codice avviene solo su richiesta esplicita: togli l'ID dai `related` delle altre schede, aggiungi in `deprecations` il vecchio codice verso il sostituto (ora non più nel catalogo) e non riusare mai l'ID. Prima verifica dove il codice compare: `README`, guide, test, MCP, esempi e dossier. Un prompt non può essere ritirato né eliminato senza sostituto.

Dopo ogni operazione rigenera l'indice con `scripts/build-prompts.ps1` (non modificare `direttive/prompts/README.md` a mano), aggiorna i conteggi dichiarati (README, guide, test, descrizione MCP) e riesegui Sync e Check con la sessione di scrittura. Non modificare il testo delle direttive comuni: ogni nuova regola comune richiede proposta concreta e approvazione esplicita.

## Decisioni da raccogliere

Se più elementi non sono ricavabili dal catalogo, fermati e poni le domande con Function Calling o Tool Use a scelta multipla (es. `ask_question`, `AskUserQuestion`), una sola decisione per domanda e la scelta raccomandata come prima opzione con `(Recommended)`:

- operazione: aggiungi, modifica, rimuovi (anche più operazioni in un lotto: scelta multipla);
- area e codice proposto tra i primi codici liberi;
- modalità (lettura, scrittura, verifica) e scope (repo, area, file, central) del prompt;
- prompt collegati da documentare in entrambe le direzioni;
- ritiro (predefinito) o eliminazione definitiva, e sostituto quando più prompt attivi sono compatibili;
- conferma finale del perimetro prima di scrivere.

Se lo strumento non è disponibile, elenca opzioni numerate e attendi la risposta. Non chiedere di nuovo ciò che l'utente ha già autorizzato nel perimetro.

## Verifiche

`scripts/build-prompts.ps1 -Check` deve uscire 0: ID unici, nessun conflitto tra ID, codici e alias, categoria esistente, `related` validi e documentati, nessun segnaposto irrisolto, sezioni presenti e non vuote. Controlla con `scripts/prompts.ps1 -Show -Prompt <codice>` che la scheda uniforme si componga, che un alias ritirato risolva al sostituto con avviso e che `scripts/test-secondbrain-workflows.ps1` resti verde. Verifica che nessun conteggio dichiarato sia rimasto vecchio.

## Consegna

Voce di catalogo e scheda nuove o modificate, ID e alias coinvolti, indice rigenerato, riferimenti aggiornati, esito di Check e test, e l'elenco di ciò che non è stato toccato (direttive comuni, schede non pertinenti). Commit e push solo su richiesta esplicita.

## Prompt vicini

- SYS04: Controlla o allinea gli asset già gestiti della postazione.
- MEM01: Allinea istruzioni locali, contesto, memoria e tracker.
- GOV02: Scansiona dipendenze esterne e compila il registro CREDITS con licenze terze.
