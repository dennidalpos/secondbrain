## SecondBrain workstation integration

<!-- secondbrain:tracker-contract:1 -->

- SECONDBRAIN_HOME in the user environment locates the checkout; keep its value out of account instructions and public repositories.
- If repository.json declares tracker location=dossier, path=tracker.json, schemaVersion=1, use only that source; a missing or invalid tracker is an error.
- For extended writes, call scripts/access.ps1 Start and End in one try/finally and pass the SessionId to the CLIs. Preserve locks and incomplete transaction markers.
- Commands: sb prompt (home), sb prompt list, sb prompt ambito AREA, sb prompt mostra CHIAVE, sb prompt CHIAVE: objective, sb attiva, sb controlla, sb allinea, sb compatta, sb runner. Their details load from the prompt cards on request (SYS01 for loading and accounts).
- Managed blocks change only through their generators; new common directives require a proposal, explicit approval, and verified hashes.
