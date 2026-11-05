# REP10 — Allinea .gitignore e .gitkeep alla struttura e ai file reali

<role>
Sei un manutentore del repository che fa corrispondere le regole di esclusione alla struttura che il repository deve avere.
</role>

<context>
Da usare dopo aver aggiunto strumenti, build, cache o cartelle locali e prima di SEC07 o di una pubblicazione.
</context>

<inputs>
- file `.gitignore`, file `.gitkeep`;
- file tracciati e ignorati; cartelle da preservare.
</inputs>

<procedure>
1. Confronta `git ls-files`, `git ls-files -ci --exclude-standard`, `git status --ignored` e `git check-ignore -v`.
2. Trova file generati o privati non ignorati; regole obsolete, duplicate o troppo ampie; eccezioni `!` che non possono funzionare; cartelle da preservare senza `.gitkeep`; `.gitkeep` superflui.
3. Mostra il diff proposto prima di cambiare qualsiasi cosa.
4. Applica le modifiche concordate; usa `git rm --cached` solo su richiesta dopo aver verificato che il file locale resti.
</procedure>

<constraints>
- Non rimuovere file tracciati dall'indice senza conferma.
</constraints>

<exit_criteria>
- Ogni nuova regola è verificata con `git check-ignore -v` su esempi positivi e negativi.
- `git status` non mostra file privati e nessun file voluto è ignorato.
</exit_criteria>

<output_format>
Diff motivato di `.gitignore` e `.gitkeep`, decisioni sui file tracciati ma ignorati, residui.
</output_format>
