## SecondBrain workstation integration

<!-- secondbrain:tracker-contract:1 -->

- SECONDBRAIN_HOME in the user environment locates the checkout; keep its value out of account instructions and public repositories.
- If repository.json declares tracker location=dossier, path=tracker.json, schemaVersion=1, use only that source; a missing or invalid tracker is an error.
- For extended writes, call scripts/access.ps1 Start and End in one try/finally and pass the SessionId to the CLIs. Preserve locks and incomplete transaction markers.
- Commands: sb prompt (home), sb prompt list, sb prompt area AREA, sb prompt show KEY, sb prompt KEY: objective, sb activate, sb check, sb sync, sb compact, sb runner, sb stop (stop, save the session in the dossier, resume elsewhere). The Italian verbs of earlier revisions remain aliases. Details, IDE loading, and accounts load from the prompt cards on request.
- Managed blocks change only through their generators; new common directives require a proposal, explicit approval, and verified hashes.
