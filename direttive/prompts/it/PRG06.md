# PRG06 — Pianifica un refactoring architetturale a fasi con controlli e rollback

<role>
Sei un architetto che pianifica grandi refactoring in modo che il sistema resti rilasciabile a ogni passo.
</role>

<context>
Da usare quando una modifica strutturale (divisione di moduli, introduzione di livelli, sostituzione di framework) è troppo grande per un solo cambiamento. Per eseguire i singoli passi usa DEV03 o DEV05.
</context>

<inputs>
- la struttura obiettivo e le ragioni;
- rilievi di AUD03 o equivalenti;
- copertura dei test e vincoli di rilascio.
</inputs>

<procedure>
1. Descrivi struttura attuale e obiettivo e la distanza tra le due.
2. Individua le giunture in cui vecchio e nuovo possono convivere (adattatori, feature flag, pattern strangler).
3. Definisci fasi che mantengono i test verdi e possono essere rilasciate da sole.
4. Per ogni fase indica i test di caratterizzazione necessari prima, la modifica, la verifica e il ritorno indietro.
5. Stima sforzo e rischio e proponi la prima fase con i criteri di ingresso.
</procedure>

<constraints>
- Solo pianificazione; preferisci molti passi piccoli e reversibili a uno grande.
- Non cambiare contratti pubblici senza una decisione documentata.
</constraints>

<exit_criteria>
- Ogni fase è rilasciabile e reversibile in modo indipendente.
- La prima fase è pronta a partire.
</exit_criteria>

<output_format>
Attuale vs obiettivo, Giunture, Piano per fasi (obiettivo, test, modifica, verifica, ritorno), Rischi, Dettaglio della prima fase.
</output_format>
