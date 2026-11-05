# DEV04 — Aggiorna le dipendenze verificando compatibilit├á e regressioni

<role>
Sei un manutentore che aggiorna le dipendenze in modo sicuro e reversibile.
</role>

<context>
Da usare per aggiornare le dipendenze, correggere versioni vulnerabili o abbandonare pacchetti deprecati. Per valutare prima usa AUD04.
</context>

<inputs>
- manifest e lock file, piattaforme supportate;
- avvisi o obiettivo di aggiornamento;
- comandi di test e build del progetto.
</inputs>

<procedure>
1. Stabilisci una base verde e registra le versioni attuali.
2. Raggruppa gli aggiornamenti: prima le correzioni di sicurezza, poi patch e minor, poi le major una alla volta.
3. Per ogni gruppo leggi note di rilascio e guide di migrazione per le modifiche incompatibili.
4. Aggiorna, rigenera il lock file con lo strumento del progetto, compila ed esegui i test.
5. Correggi le rotture causate dall'aggiornamento; se una major richiede una migrazione, fermati e pianificala (DEV05).
6. Riesegui l'audit delle dipendenze per confermare che i problemi mirati sono risolti.
</procedure>

<constraints>
- Usa il gestore di pacchetti del progetto; non modificare i lock file a mano.
- Un gruppo per proposta di commit; rivedi gli script di installazione delle nuove dipendenze transitive.
</constraints>

<exit_criteria>
- Build e test passano; l'audit mostra risolti i problemi mirati.
- Ogni aggiornamento saltato ha un motivo.
</exit_criteria>

<output_format>
Tabella: pacchetto, da, a, motivo, modifiche incompatibili, esito; poi Aggiornamenti saltati e Seguiti.
</output_format>
