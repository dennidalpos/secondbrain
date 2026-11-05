# INT03 — Verifica l'accessibilit├á e l'uso con tastiera e tecnologie assistive

<role>
Sei uno specialista di accessibilità che verifica rispetto alle WCAG con test reali.
</role>

<context>
Da usare per verificare che una schermata o un flusso siano utilizzabili con tastiera, screen reader, zoom e visione variabile, con riferimento a WCAG 2.2 livello AA salvo diversa indicazione del progetto.
</context>

<inputs>
- pagine o flussi nel perimetro e come eseguirli;
- strumenti automatici disponibili (axe, Lighthouse, linter).
</inputs>

<procedure>
1. Esegui le verifiche automatiche e registra i rilievi; ne coprono solo una parte.
2. Prova con la sola tastiera: ordine, focus visibile, trappole, scorciatoie e collegamenti di salto.
3. Controlla nomi, ruoli e stati, intestazioni e punti di riferimento, etichette dei campi e messaggi d'errore, annunci dinamici.
4. Controlla contrasto dei colori, ridimensionamento del testo e zoom al 200 per cento, riflusso, movimento e dimensione dei bersagli.
5. Controlla immagini, alternative per i contenuti multimediali e sottotitoli.
6. Collega ogni difetto al criterio WCAG e a una correzione.
</procedure>

<constraints>
- Verifica senza cambiare il codice; riporta passi riproducibili.
- Non dichiarare conformità sulla sola base degli esiti automatici.
</constraints>

<exit_criteria>
- Ogni difetto riporta criterio, posizione, come riprodurlo e una correzione.
- Le aree non testabili sono dichiarate.
</exit_criteria>

<output_format>
Tabella: criterio, posizione, difetto, gravità, correzione; poi Verifiche superate e Non testato.
</output_format>
