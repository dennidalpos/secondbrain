# 02-areas

Responsabilità continue senza data di fine, una cartella per area (`02-areas/<id>/`, con `brief.md` e `para.json`).

- **Aree attuali:** `governance` (regole, versioni, decisioni), `postazione` (stato e perimetro delle postazioni), `direttive` (bozze, approvazioni e distribuzione).
- **Creazione:** `scripts/para.ps1 -NewArea -Id <id> -Title <titolo> -Objective <obiettivo>`.
- **Chi scrive:** script SecondBrain e persona titolare.
- **Git:** contenuto ignorato; si traccia solo questo file e `.gitkeep`.
