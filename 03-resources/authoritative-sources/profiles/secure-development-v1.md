# Profilo consultivo sviluppo sicuro - v1

Fonti: [NIST SSDF 1.1](../entries/nist-ssdf/metadata.json), [OWASP ASVS 5.0.0](../entries/owasp-asvs/metadata.json), [Password Storage](../entries/owasp-password-storage/metadata.json), [File Upload](../entries/owasp-file-upload/metadata.json). Versioni nella scheda del prodotto; queste guide non equivalgono a certificazioni o prescrizioni comuni aggiuntive.

| Ambito | Riferimenti iniziali | Valutazione pratica |
|---|---|---|
| Requisiti e responsabilita | SSDF PO.1-PO.5 | Rischi, ambienti e utenti supportati, requisiti verificabili e responsabilita |
| Codice e artefatti | SSDF PS.1-PS.3 | Accessi al codice, integrita, provenienza e recuperabilita degli artefatti |
| Progettazione e confini | SSDF PW.1-PW.2 | Architettura proporzionata, input non attendibili, privilegi e superfici esposte |
| Dipendenze e implementazione | SSDF PW.4-PW.6 | Componenti supportati, manifest e lock, segreti, compilazione e impostazioni sicure |
| Verifiche | SSDF PW.7-PW.9 | Review, test significativi, controlli obbligatori e configurazioni distribuite |
| Vulnerabilita | SSDF RV.1-RV.3 | Identificazione, correzione, analisi delle cause e comunicazione pertinente |
| Applicazioni e servizi web | ASVS 5.0.0 | Selezionare livello e requisiti pertinenti, citando identificatori comprensivi di versione |
| Password, archivi e upload | Guide OWASP pertinenti | Parametri motivati, gestione delle versioni, limiti, percorsi e contenuti; nessun algoritmo o costo imposto a ogni tecnologia |

Per ogni intervento scegliere controlli coerenti con manifest, runtime e contratti reali. Affidabilita, mantenibilita, accessibilita e recupero richiedono verifiche pertinenti al prodotto; conservare i comandi applicativi nei repository.
