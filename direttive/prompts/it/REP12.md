# REP12 — Consolida i branch con merge --no-ff ed elimina quelli integrati

> **Scope**: repo | **Modalità**: scrittura | **Cosa serve**: branch locali e remoti, ramo base e working tree pulito | **Esempio d'uso**: `consolida i branch conclusi in master`

## Scopo

Portare il lavoro concluso dei branch laterali nel ramo base con un merge commit tracciabile e rimuovere i branch interamente integrati, senza perdere lavoro unico.

## Quando usarlo

Quando si sono accumulati branch laterali, worktree o diramazioni del lavoro e il ramo base deve raccoglierli prima di un rilascio o di una pulizia.

## Input

`git branch -a -vv`, `git worktree list`, il ramo base, l'ordine di merge richiesto e le regole di protezione o revisione del remoto.

## Attività specifiche

Prima di unire registra lo stato: working tree e indice puliti, branch corrente, `git fetch`, divergenza di ogni branch dal ramo base (`git rev-list --left-right --count`), commit unici di ciascuno e se è già contenuto (`git branch --merged`). Esegui i controlli del progetto su ogni branch che intendi unire. Unisci un branch alla volta con `git merge --no-ff`, nell'ordine concordato, fermandoti al primo conflitto per risolverlo con l'utente; mai rebase, squash o force push di tua iniziativa. Dopo ogni merge esegui i controlli pertinenti e confronta il risultato con lo stato registrato prima. Elimina un branch (`git branch -d`, sul remoto `git push --delete`) solo dopo conferma e solo se `git branch --merged` prova che è integrato; un branch con lavoro unico o con un worktree in uso resta e va segnalato.

## Decisioni da raccogliere

- branch da unire e relativo ordine;
- branch da eliminare, locali e remoti, dopo il merge;
- come risolvere un conflitto.

## Verifiche

Controlla prima e dopo il merge che il working tree sia pulito, che il ramo base contenga ogni merge commit, che i controlli del progetto passino, che nessun commit unico sia andato perso (`git log` rispetto alla punta precedente) e che i branch eliminati fossero integrati. Nulla viene inviato con push senza richiesta specifica.

## Consegna

I merge commit creati, i branch eliminati e quelli conservati con il motivo, i controlli eseguiti e quanto resta all'utente.

## Prompt vicini

- OPS05: Prepara commit e pull request con perimetro, messaggio e controlli verificati.
- REP04: Rimuovi residui e codice inutilizzato dopo la verifica.
- REP10: Allinea .gitignore e .gitkeep alla struttura e ai file reali.
