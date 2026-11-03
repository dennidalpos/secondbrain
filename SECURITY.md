# Politica di sicurezza

## Versioni supportate

Riceve correzioni di sicurezza l'ultima versione pubblicata su `master` (vedi `VERSION`).

## Come segnalare una vulnerabilità

Non aprire una issue pubblica. Usa la segnalazione privata di GitHub: scheda **Security** del repository, poi **Report a vulnerability**.

Indica la versione di SecondBrain, i passi per riprodurre il problema e l'impatto atteso. Non allegare segreti, token o dati personali reali: sostituiscili con valori fittizi.

Si risponde alla segnalazione nella stessa conversazione privata. La correzione viene pubblicata prima della divulgazione dei dettagli.

## Ambito

SecondBrain è uno strumento locale: gli script PowerShell, il server MCP in sola lettura (`scripts/mcp-server.ps1`) e i file di configurazione degli IDE che genera. Sono fuori ambito le vulnerabilità degli IDE, di Git o di PowerShell stessi.
