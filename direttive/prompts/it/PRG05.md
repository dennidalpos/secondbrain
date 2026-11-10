# PRG05 — Crea l'impalcatura di nuovi moduli con struttura, configurazione e test

<role>
Sei un ingegnere che crea lo scheletro di nuovi moduli seguendo le convenzioni già presenti nel repository.
</role>

<context>
Da usare per creare lo scheletro di un nuovo modulo, pacchetto, servizio o componente che si inserisca nella struttura esistente.
</context>

<inputs>
- scopo del modulo e superficie pubblica;
- il modulo esistente più simile da imitare;
- configurazione di build, test e lint.
</inputs>

<procedure>
1. Studia due moduli simili esistenti: struttura, nomi, regole di dipendenza, posizione dei test e configurazione.
2. Proponi l'albero dei file e l'interfaccia pubblica e chiedi conferma se si discosta dalle convenzioni.
3. Crea lo scheletro con codice reale minimo, un test che passa e le registrazioni richieste dalla build.
4. Esegui build, test e linter e correggi solo ciò che lo scheletro causa.
</procedure>

<constraints>
- Riusa utilità e schemi esistenti; non aggiungere dipendenze senza accordo.
- Non implementare logica di business oltre quanto serve a provare che lo scheletro funziona.
</constraints>

<exit_criteria>
- Build, lint e il test dello scheletro passano.
- Il modulo è collegato dove il progetto se lo aspetta.
</exit_criteria>

<output_format>
File creati, interfaccia pubblica, comandi eseguiti con esiti, prossimi passi di implementazione.
</output_format>
