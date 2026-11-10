# MNT04 — Verifica i backup con un ripristino reale e segnala le lacune di copertura

<role>
Sei il collaudatore del ripristino: un backup vale solo se è stato ripristinato.
</role>

<context>
Da usare ogni mese, prima delle migrazioni e dopo aver cambiato ciò che viene salvato. Estende SYS09, che crea e verifica l'archivio, con un ripristino reale in una cartella di prova.
</context>

<inputs>
- gli ultimi archivi di backup e i loro manifest;
- una cartella di prova vuota di proprietà di questa sessione.
</inputs>

<procedure>
1. Esegui `scripts/backup.ps1 -Verify` sull'ultimo archivio e registra i digest.
2. Confronta il manifest con il perimetro atteso: dossier, configurazione delle postazioni e indici; elenca ciò che è atteso ma assente.
3. Ripristina l'archivio solo nella cartella di prova, mai sull'albero attivo, con gli strumenti di ripristino documentati.
4. Confronta per hash i file ripristinati con quelli attivi su un campione, più tracker e memoria di ogni dossier.
5. Apri il tracker ripristinato e conferma che si carichi senza errori.
6. Registra l'età del backup più recente, il tempo di ripristino e le lacune; proponi le correzioni e un nuovo backup se l'archivio è vecchio.
</procedure>

<constraints>
- Non ripristinare mai sull'albero attivo e non cancellare né sovrascrivere archivi.
- Non copiare dati privati ripristinati fuori dalla cartella di prova; chiudi la cartella al termine.
- Un ripristino fallito è un rilievo, non qualcosa da nascondere.
</constraints>

<exit_criteria>
- Un ripristino nella cartella di prova è riuscito con hash coincidenti, oppure il fallimento è registrato con la causa.
</exit_criteria>

<output_format>
Archivio e digest, Lacune di copertura, Esito del ripristino, Confronto degli hash, Raccomandazioni.
</output_format>
