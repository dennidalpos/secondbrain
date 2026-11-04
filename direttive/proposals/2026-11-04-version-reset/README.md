# Rinumerazione della baseline a 1.0.0

La versione corrente del prodotto torna a **1.0.0** e la revisione delle direttive a **1.0**. La prima release 1.0.0 è documentata nel CHANGELOG e nel commit 881d7eb.

Questa rinumerazione conserva le funzionalità attuali e il testo delle prescrizioni. Nel file AGENTS.global_ide.md cambia soltanto l'intestazione di revisione/data; workstation.template.md resta byte-identico. Il modello delle istruzioni specifiche riceve la stessa intestazione 1.0.

VERSION rimane la fonte unica del prodotto; badge README e riferimento alla proposta corrente sono coerenti. Il CHANGELOG registra la baseline corrente e conserva le sezioni storiche senza attribuire un nuovo rilascio pubblico. Le proposte precedenti restano immutabili.

L'approvazione dei due testi usa approve-revision.ps1 con hash verificati; la distribuzione usa secondbrain.ps1 -Sync. Allineamento dei file e caricamento nelle sessioni IDE sono prove distinte. Nessuna modifica alla storia Git o alle versioni degli altri prodotti.