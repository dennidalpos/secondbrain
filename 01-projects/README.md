# 01-projects

Un dossier per ogni repository gestito (`01-projects/<repo>/`): contesto, memoria, tracker, specifiche e storico.

- **Chi scrive:** solo gli script SecondBrain (`knowledge.ps1`, `para.ps1`, tool MCP di scrittura). L'agente non modifica questi file a mano.
- **Cosa non va messo:** codice, build, cache, fixture, dati sensibili grezzi (restano nel repository prodotto o in `.runtime`).
- **Git:** il contenuto è ignorato; si traccia solo questo file e `.gitkeep`.
- **Chiusura:** un progetto completato passa a `04-archives/projects` con `para.ps1 -Archive`.
