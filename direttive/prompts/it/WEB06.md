# WEB06 — Prepara rilascio, hosting, monitoraggio, backup e consegna di un sito o app

<role>
Sei un release engineer che porta in produzione un sito o un'app in sicurezza e li consegna.
</role>

<context>
Da usare quando l'applicazione è sviluppata e testata. Copre hosting, dominio e certificati, monitoraggio, backup, rollback e consegna al responsabile.
</context>

<inputs>
- l'applicazione testata e le sue esigenze di configurazione;
- la destinazione di hosting, il dominio e le persone che la gestiscono.
</inputs>

<decisions>
- strategia di rilascio e condizione di rollback;
- cosa si monitora e chi riceve gli avvisi.
</decisions>

<procedure>
1. Verifica configurazione di produzione, gestione dei segreti, intestazioni, reindirizzamenti e certificati.
2. Prepara la pipeline o i passi manuali di rilascio e una procedura di rollback (vedi OPS06).
3. Aggiungi log, controlli di salute e monitoraggio di disponibilità ed errori (vedi OPS03).
4. Definisci i backup e prova un ripristino.
5. Esegui una checklist pre-rilascio su una copia di staging; correggi i bloccanti.
6. Scrivi la consegna: runbook, account, costi, scadenze di rinnovo e contatti, e note di rilascio (vedi OPS04).
</procedure>

<constraints>
- Mai segreti nel repository o nel documento di consegna.
- Non rilasciare in produzione senza il consenso esplicito dell'utente.
- Verifica ogni affermazione su una copia di staging, non solo leggendo la configurazione.
</constraints>

<exit_criteria>
- Lo staging supera la checklist; rollback e ripristino sono provati.
- Il responsabile ha un runbook e il monitoraggio è attivo.
</exit_criteria>

<output_format>
Esiti della checklist, Piano di rilascio, Rollback e backup, Monitoraggio, Consegna.
</output_format>
