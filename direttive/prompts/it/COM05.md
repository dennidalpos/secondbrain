# COM05 — Analizza log e incidenti per trovare la causa radice, senza toccare il codice

> **Scope**: repo/area | **Modalità**: lettura | **Cosa serve**: log, errori o sintomi, finestra temporale e accesso in lettura | **Esempio d'uso**: `trova la causa radice degli errori di ieri nei log`

## Scopo

Risalire dai sintomi (errori, log, metriche, segnalazioni) alla causa radice di un incidente o di un comportamento anomalo, separando evidenze e ipotesi, senza modificare codice, configurazione o dati.

## Quando usarlo

Quando si osserva un errore in produzione o nei test ma la causa non è chiara, prima di correggerlo (DEV02) o di aggiungere diagnostica (OPS03). Per fare triage di una nuova segnalazione usa DEV07.

## Input

Log, messaggi di errore o sintomi, finestra temporale, versioni e ambiente coinvolti, modifiche recenti e accesso in lettura al codice e ai dati diagnostici.

## Attività specifiche

Ricostruisci la cronologia: primo errore osservato, che cosa è cambiato prima (rilasci, configurazione, carico) e che cosa è rimasto uguale. Correla log, metriche e tracce con il codice che le emette; separa sintomo, causa immediata e causa radice (per esempio con i cinque perché). Formula ipotesi alternative, indica per ciascuna l'evidenza che la confermerebbe o la escluderebbe e verifica con le letture possibili. Non riprodurre l'errore su sistemi o dati reali senza autorizzazione e non ripetere valori sensibili trovati nei log: cita identificatori e posizioni.

## Decisioni da raccogliere

- finestra temporale, ambiente e fonti da analizzare;
- ipotesi da approfondire per prime quando le evidenze non bastano;
- azione consigliata: correggere ora, aggiungere diagnostica, mitigare o chiedere altri dati.

## Verifiche

Ogni conclusione cita la propria evidenza (riga di log, metrica, commit o file e riga) e il grado di certezza. Dichiara le ipotesi non escluse, i dati mancanti e i limiti della ricostruzione; non presentare una correlazione come causa.

## Consegna

Cronologia dell'incidente, causa radice o ipotesi ordinate per probabilità con le relative evidenze, impatto, informazioni mancanti e azione consigliata; nessuna modifica al codice.

## Prompt vicini

- DEV02: Riproduci un difetto e correggine la causa.
- OPS03: Aggiungi log, metriche e diagnostica utili al problema.
- DEV07: Fai il triage di una segnalazione e riproducila, senza modificare il codice.
