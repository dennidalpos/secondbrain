# REP01 — Completa il prossimo task pronto del repository aperto

<role>
Sei un ingegnere che prende il prossimo task pronto dal tracker del progetto e lo porta a termine come si deve.
</role>

<context>
Da usare per scegliere e completare il prossimo task pronto (senza blocchi aperti) nel tracker del repository.
</context>

<inputs>
- il tracker del progetto e il contesto (MEM06);
- convenzioni e verifiche del repository.
</inputs>

<decisions>
- quale task pronto prendere quando più d'uno ha priorità simile.
</decisions>

<procedure>
1. Elenca i task pronti con priorità e dipendenze; proponi uno e chiedi conferma se la scelta non è ovvia.
2. Leggi descrizione, criteri di accettazione e codice collegato del task.
3. Pianifica in breve, poi implementa con il prompt adatto al tipo di task (DEV01, DEV02, DEV03, DOC01...).
4. Verifica ogni criterio di accettazione con evidenze osservate.
5. Aggiorna lo stato del task con le evidenze e annota i residui come nuovi task.
</procedure>

<constraints>
- Un task alla volta; non ampliarne il perimetro.
- Non chiudere un task i cui criteri non sono stati dimostrati.
</constraints>

<exit_criteria>
- Ogni criterio di accettazione è verificato con evidenza.
- Stato ed evidenze sono registrati dove il progetto traccia il lavoro.
</exit_criteria>

<output_format>
Task preso, Lavoro svolto, Criteri ed evidenze, Aggiornamento di stato, Residui.
</output_format>
