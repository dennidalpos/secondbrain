# SEC06 — Rafforza configurazione del repository, CI, container e accessi

> **Scope**: repo/area | **Modalità**: scrittura | **Cosa serve**: configurazione, workflow CI, container e impostazioni del repository | **Esempio d'uso**: `rafforza i workflow GitHub Actions e i container`

## Scopo

Ridurre la superficie di attacco del repository e della sua catena di build e rilascio con configurazioni verificabili e privilegi minimi.

## Quando usarlo

Prima di rendere pubblico un repository, prima di un rilascio, dopo un incidente e periodicamente.

## Input

Configurazioni, workflow CI, Dockerfile e infrastruttura come codice, impostazioni del repository, permessi e segreti usati.

## Attività specifiche

Verifica i permessi minimi dei workflow (`permissions`), le action di terze parti fissate agli hash dei commit, i trigger rischiosi come `pull_request_target`, l'uso dei segreti, le immagini base e l'utente non privilegiato nei container, la protezione dei rami, le revisioni obbligatorie, la firma di commit e tag, la scansione dei segreti con push protection, i lock delle dipendenze e le impostazioni di sicurezza dei framework. Dichiara non applicabili le superfici assenti (per esempio nessun workflow o container tracciato) senza inventare lavoro. Per fissare action e immagini risolvi hash e digest con ricerche remote in sola lettura (per esempio `gh api repos/<owner>/<repo>/commits/<ref> --jq .sha`); se un riferimento non si può risolvere, lascialo com'è, segnalalo come non fissato e non inventare hash. Mostra la differenza e l'impatto operativo prima di cambiare qualsiasi cosa. Le impostazioni remote (protezione dei rami, scansione dei segreti) vengono proposte con i relativi comandi e applicate solo con autorizzazione esplicita. Non cambiare impostazioni di sistema o di sicurezza della macchina.

## Decisioni da raccogliere

- superfici da rafforzare (scelta multipla: CI, container, rami, segreti);
- applicare le modifiche o solo proporle.

## Verifiche

Esegui la pipeline locale pertinente e i controlli dopo le modifiche e verifica che nessuna correzione blocchi il lavoro legittimo; se mancano strumenti (per esempio `actionlint`, `hadolint`, `docker`), dichiara il controllo come non eseguito invece di dedurne l'esito. Distingui il rischio effettivo dalle raccomandazioni generiche e non dichiarare conformità a uno standard senza controlli specifici.

## Consegna

Misure applicate o proposte con evidenze, rischio residuo e passi manuali.

## Prompt vicini

- SEC04: Trova le credenziali esposte e verifica la validazione degli input.
- OPS02: Configura pipeline, container e infrastruttura come codice.
- SEC03: Correggi le vulnerabilità e rafforza le difese interessate.
