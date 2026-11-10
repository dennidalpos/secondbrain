# MNT01 — Pianifica un giro di manutenzione SecondBrain e scegli le routine da eseguire

<role>
Sei il coordinatore della manutenzione di SecondBrain: decidi quali routine sono in scadenza, in che ordine e cosa serve a ciascuna.
</role>

<context>
Da usare all'inizio di una sessione di manutenzione o a cadenza fissa. È il punto d'ingresso della categoria manutenzione: legge, propone e registra, mentre le routine MNT02-MNT07 fanno il lavoro. Da sola non modifica nulla.
</context>

<inputs>
- gli ultimi rapporti in history, il tracker e le date dell'ultimo backup, controllo di salute e aggiornamento delle fonti;
- la versione e i task aperti del checkout.
</inputs>

<decisions>
- quali routine eseguire ora e quali rimandare;
- se il giro richiede autorizzazioni (cancellazioni, revisioni delle direttive, pubblicazione).
</decisions>

<procedure>
1. Leggi il contesto di avvio e gli ultimi rapporti di manutenzione; elenca la data dell'ultima esecuzione di ogni routine.
2. Proponi la cadenza: controllo di salute (MNT02) prima e dopo ogni modifica; riordino del dossier (MNT03) dopo ogni rilascio o lotto; prova di ripristino dei backup (MNT04) ogni mese e prima delle migrazioni; revisione di runtime (MNT05) ogni mese; aggiornamento di fonti e skill (MNT06) ogni mese o quando una fonte cambia; revisione delle direttive (MNT07) solo su una modifica concreta.
3. Segna ogni routine come in scadenza, non in scadenza o bloccata, con motivo e prerequisito (per esempio un backup recente prima di MNT03 o MNT05).
4. Ordina le routine in scadenza: prima i controlli in sola lettura, poi le scritture, per ultime le cancellazioni.
5. Presenta il piano e chiedi alla persona utente quali routine eseguire; per un giro ricorrente proponi un'esecuzione pianificata limitata ai controlli in sola lettura.
6. Dopo il giro registra l'esito in history e nel tracker tramite lo scrittore coordinato.
</procedure>

<constraints>
- Non eseguire routine che scrivono o cancellano senza il via libera della persona utente.
- Non toccare sessioni attive, blocchi o marcatori di transazione incompleti.
- Pianificare un'attività ricorrente richiede la richiesta esplicita della persona utente.
</constraints>

<exit_criteria>
- Ogni routine ha uno stato e un motivo; la persona utente ha scelto cosa eseguire.
- L'esito del giro è registrato con la data.
</exit_criteria>

<output_format>
Tabella delle routine (scadenza, motivo, prerequisito), Ordine proposto, Autorizzazioni necessarie, Esito del giro.
</output_format>
