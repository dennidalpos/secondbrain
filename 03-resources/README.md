# 03-resources

Riferimenti condivisi e riusabili da tutti i repository: fonti autorevoli, architettura, radar tecnologico, troubleshooting.

- **Creazione:** `scripts/para.ps1 -NewResource -Id <id> -Title <titolo> -Objective <obiettivo>`.
- **Chi scrive:** script SecondBrain e persona titolare; una risorsa non contiene dati di un singolo repository.
- **Git:** il contenuto è tracciato (catalogo, domini, profili, metadati, trascrizioni e prove delle fonti public-reusable), esclusi gli originali (`versions/*/originals/`) e gli screenshot di controllo (`census/qa/`). Gli originali si scaricano con `scripts/resources.ps1 -Sync` (o `-Restore`) e si scrivono solo se lo SHA-256 coincide con il manifest. Un testo conservato di una fonte non public-reusable è rifiutato da `scripts/check-distribution.ps1`.
