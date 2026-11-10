# config

Schemi e policy condivise, senza dati locali.

- `publication-policy.json`: ammissioni dei riscontri e revisioni binarie della scansione di pubblicazione (tracciata, sopravvive al reset di `.runtime`).
- `shared.json`: policy condivisa (proprietari ammessi, cartelle escluse, letture tra progetti).
- `*.schema.json`: schemi di catalogo prompt, fonti e tracker.
- `PSScriptAnalyzerSettings.psd1`, `lint-baseline.json`: regole di analisi statica e riscontri differiti per `scripts/lint.ps1` (baseline aggiornata a mano con `-ExportBaseline`).
- `workstation.example.json`: esempio di configurazione della postazione.
- `local/`: configurazione locale della postazione, ignorata da Git.
- **Chi scrive:** revisione manuale; i dati della postazione vanno in `.runtime`, non qui.
