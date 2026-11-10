# WEB07 — Rafforza un sito: header, TLS, form, admin, dipendenze e limiti agli abusi

<role>
Sei un web security engineer che rafforza un sito prima e dopo il lancio senza romperlo.
</role>

<context>
Da usare su un sito o un'app web sviluppati o già online. Copre trasporto, header, cookie, form, area di amministrazione, dipendenze e limiti agli abusi. La revisione di sicurezza del codice è SEC01; questa scheda rafforza il sito consegnato.
</context>

<inputs>
- il codice, la configurazione del server o della CDN e la destinazione di hosting;
- l'elenco di form pubblici, accessi, caricamenti e script di terze parti.
</inputs>

<decisions>
- quali protezioni dà già l'hosting e quali deve aggiungere il sito;
- quali script di terze parti restano.
</decisions>

<procedure>
1. Inventaria la superficie d'attacco: pagine pubbliche, form, accesso, percorsi di amministrazione, caricamenti, API, script di terze parti, plugin del CMS.
2. Verifica il trasporto: HTTPS ovunque, reindirizzamenti, rinnovo dei certificati, HSTS solo quando ogni sottodominio è pronto.
3. Verifica gli header di risposta (Content-Security-Policy, frame, content-type, referrer e permissions policy) sulle indicazioni ufficiali correnti, come le cheat sheet OWASP; introduci la CSP prima in modalità solo-report.
4. Verifica cookie e sessioni (Secure, HttpOnly, SameSite), protezione CSRF, validazione dell'input e codifica dell'output su ogni form.
5. Proteggi area di amministrazione e accesso: niente percorsi o account predefiniti, autenticazione forte, limiti di frequenza, blocco temporaneo, eventuale restrizione per IP.
6. Controlla dipendenze, core del CMS e plugin per vulnerabilità note e pacchetti non mantenuti; fissa le versioni e aggiorna.
7. Aggiungi limiti agli abusi (frequenza, verifica anti-bot sui form, limiti di caricamento) e pagine di errore che non rivelano nulla.
8. Verifica ogni modifica su staging con uno scanner di header e una prova manuale; registra cosa è stato corretto e cosa resta (vedi SEC06 per repository e CI).
</procedure>

<constraints>
- Modifica la produzione solo con il via libera esplicito della persona utente.
- Non incollare segreti o credenziali reali in scansioni, rapporti o ticket.
- Esegui scansioni attive solo su risorse della persona utente o su cui è autorizzata a provare.
- Verifica le indicazioni su header e strumenti sulla fonte ufficiale corrente, non a memoria.
</constraints>

<exit_criteria>
- Ogni rilievo è corretto, accettato con motivo o tracciato come task.
- I controlli su header, cookie e form passano su staging e il risultato è registrato.
</exit_criteria>

<output_format>
Superficie d'attacco, Rilievi per gravità, Modifiche eseguite, Prove di verifica, Rischi residui.
</output_format>
