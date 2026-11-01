# Audit esterno GitHub

`scripts/audit-github.ps1` esegue soltanto GET tramite GitHub CLI, usando l autenticazione gia configurata. E un comando esplicito: Sync e Check non lo importano e non acquisiscono dipendenze di rete. L audit remoto storico e stato verificato con PowerShell 7.6.8 e GitHub CLI 2.103.2. Le 31 verifiche isolate senza rete passano anche su PowerShell 7.5.11 e 7.6.9 (evidenze di collaudo conservate nelle fixture isolate). Questo non costituisce una nuova acquisizione autenticata dei remoti sulla 7.5.

```powershell
# Tutti i repository attivi dell inventario, output su stdout:
./scripts/audit-github.ps1 -ConfigPath .runtime/hosts/<id>/workstation.json

# Un repository gestito, artefatto locale nuovo:
./scripts/audit-github.ps1 -ConfigPath .runtime/hosts/<id>/workstation.json `
  -Repository github.com/example-user/my-app `
  -OutputPath ".runtime/reports/audit-github-onlybackup.json"
```

Il percorso JSON deve essere nuovo; non vengono sovrascritti audit, tracker o file preesistenti. Senza `-OutputPath` non si scrivono artefatti. Con output si usa il coordinamento Write e la scrittura verificata; durante una sessione prolungata passare `-SessionId` secondo la [procedura di accesso](access.md). Identita, owner e presenza nell inventario attivo sono controllati prima della rete; hash dell inventario verificato anche dopo la raccolta. Il comando non modifica remoti, checkout o tracker.

## Copertura ed esiti

Per ogni identita vengono censiti metadata repository, issue (escluse le PR), tutte le PR, commenti issue, commenti inline, review di ogni PR osservata, branch, tag e fork. Ogni pagina registra URL, orari UTC, HTTP status e SHA-256 del payload ricevuto. I corpi e i titoli degli elementi sono conservati come hash e lunghezza; il payload grezzo, gli header di autenticazione e stderr non sono salvati. L elenco dei fork non ne verifica i contenuti.

La paginazione segue il `Link` con relazione `next` fino all esaurimento. Link fuori dall endpoint previsto, parametri estranei, cicli o oltre 1000 pagine rendono la risorsa incompleta. Non si segue un redirect di identita verso un repository differente. [Contratto GitHub della paginazione](https://docs.github.com/en/rest/using-the-rest-api/using-pagination-in-the-rest-api), [opzioni di gh api](https://cli.github.com/manual/gh_api).

`complete` e `count` descrivono la risorsa intera; `observedCount` conserva gli elementi delle pagine ottenute. Un errore successivo lascia `count=null`, anche se alcuni elementi erano gia stati letti. Le review sono complete solo se sono complete sia la lista delle PR sia tutte le richieste per PR. Un elenco vuoto completo e distinto da una richiesta non eseguita.

| Stato | Significato |
|---|---|
| `accessible`, `complete=true`, `count=0` | Richiesta conclusa, elenco vuoto osservato |
| `not_found_or_inaccessible` | HTTP 404; nessuna deduzione fra assenza e permessi |
| `authentication_required` / `access_denied` | HTTP 401 / 403, distinti dai dati vuoti |
| `rate_limited` | HTTP 429 o limite riconosciuto su 403; raccolta successiva arrestata, nessun retry automatico |
| `partial` | Elementi gia ottenuti o review incomplete; nessun totale dichiarato |
| `not_attempted` | Prerequisito indisponibile o arresto globale |
| Wiki `disabled` | Metadata `has_wiki=false`; distinto da contenuto vuoto |
| Wiki `unverified` | Contenuto non acquisito: nessuna affermazione su pagine o accessibilita |

GitHub puo usare 404 per risorse private non accessibili; i limiti richiedono attesa prima di nuove richieste. Il collector interrompe la raccolta quando riconosce un limite o un problema globale di autenticazione. [Diagnostica ufficiale](https://docs.github.com/en/rest/using-the-rest-api/troubleshooting-the-rest-api).

Le Wiki abilitate richiedono una verifica separata del loro repository Git o dell interfaccia; il collector REST non la esegue. [Gestione delle Wiki](https://docs.github.com/en/communities/documenting-your-project-with-wikis/adding-or-editing-wiki-pages). Anche uno stato completo resta uno snapshot non atomico fra richieste: allegati, Actions, cache, cloni e copie esterne sono fuori copertura.

Exit code: **0** copertura completa; **1** artefatto valido con limiti espliciti; **2** errore di invocazione/configurazione/scrittura. I test isolati sono in `scripts/test-secondbrain-external-audit.ps1`, inclusi nella suite obbligatoria (evidenze reali e valutazione cronologia conservate nel runtime di test).
