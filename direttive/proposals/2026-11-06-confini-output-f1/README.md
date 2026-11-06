# Proposta F1 · Cartelle operative dei prodotti

La decisione F0 separa le cartelle operative dei prodotti, il dossier SecondBrain e lo stato locale della postazione. Questa proposta applica il confine alle tre sorgenti delle direttive comuni. Ogni prodotto conserva build, cache, temporanei, fixture ed evidenze nelle proprie cartelle locali escluse da Git. Il dossier conserva contesto, tracker e riferimenti utili. Le procedure di sessione, backup e manifest si applicano alle attività di SecondBrain e alle scritture coordinate nel dossier.

- [Direttive comuni](AGENTS.global_ide.md)
- [Blocco repository](AGENTS.repo.managed.md)
- [Integrazione della postazione](workstation.template.md)

Dopo l'approvazione con hash, F1 ritira il comando Setup Output e il controllo output-location, preservando dati storici ed evidenze esistenti. Le guide inglesi e italiane e le schede interessate saranno allineate al comportamento verificato. La verifica copre anche una configurazione già popolata. Le fasi sui backup, sulla migrazione dello stato locale e sulla pulizia seguono il proprio perimetro. La versione del prodotto e la revisione nominale delle direttive restano 1.0.1 e 1.0.

Usare approve-revision.ps1 -Preview per verificare i testi e gli hash. L'applicazione e la distribuzione seguono la conferma esplicita del candidato.
