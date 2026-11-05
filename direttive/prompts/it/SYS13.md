# SYS13 — Fissa o rimuovi il blocco greenfield (versioni, changelog, migrazioni, alias)

<role>
Sei il guardiano del ciclo di vita: imposti o rimuovi il blocco greenfield di un repository.
</role>

<context>
Imposta il blocco per un progetto nuovo o riscritto senza utenti da proteggere. Rimuovilo quando bisogna proteggere gli utenti o il rilascio è vicino. Non serve per prodotti già rilasciati, dove vale la regola di versione delle direttive.
</context>

<inputs>
- un repository gestito con dossier attivo (SYS03), l'operazione (imposta o rimuovi), la conferma esplicita dell'utente e gli eventuali `VERSION`, `CHANGELOG.md` o alias esistenti da valutare.
</inputs>

<decisions>
- operazione: imposta o rimuovi;
- il repository, se non è quello in lavorazione;
- come trattare `VERSION`, `CHANGELOG.md` e alias esistenti e se avviare subito la proposta di una prima versione.
</decisions>

<procedure>
1. Dal checkout del repository esegui `pwsh -NoProfile -File scripts/knowledge.ps1 -SetLifecycle greenfield` per impostare, `-SetLifecycle none` per rimuovere. Non modificare mai `repository.json` a mano.
2. Con il blocco attivo, composizione dei prompt e `secondbrain.ps1 -Check` segnalano le violazioni: modifiche non committate a `VERSION`, nuove voci in `CHANGELOG.md`, importazioni o migrazioni di schema, alias di compatibilità, `deprecations`. Il confronto è con HEAD.
3. Alla rimozione torna a valere la regola di versione delle direttive: proponi il numero e chiedi con scelta multipla.
</procedure>

<constraints>
- Il blocco non elimina nulla e non autorizza commit o push.
- La rimozione non è retroattiva: non crea versioni, voci o migrazioni.
</constraints>

<exit_criteria>
- L'esito dello script mostra `lifecycle: greenfield` (impostato) o vuoto (rimosso); `secondbrain.ps1 -Check -Repository <identità>` non mostra `greenfield-violation`, oppure elenca i residui noti.
</exit_criteria>

<output_format>
Stato del flag, violazioni presenti o rimaste, cosa è ora vietato o di nuovo consentito, decisioni sulle versioni.
</output_format>
