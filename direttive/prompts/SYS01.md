# SYS01 — Verifica gli IDE; mappa o riallinea su richiesta

> **Scope**: central | **Modalità**: verifica | **Cosa serve**: installazioni IDE e autorizzazioni locali | **Esempio d'uso**: `sb prompt SYS01: mappa lo stato di allineamento delle direttive negli ide`

## Scopo

Controllare l’integrazione degli IDE con le direttive approvate.

## Quando usarlo

Nella manutenzione centrale della postazione; verifica predefinita in lettura.

## Input

Configurazione locale, runtimeRoot, mappa IDE e richiesta verifica/mappa/riallinea.

## Attività specifiche

Esegui ide-map.ps1 -Verify. Per mappare consulta fonti ufficiali e superfici installate; per riallineare usa solo il testo globale approvato, backup verificati e conservazione del testo personale. Il monitor non rileva IDE e non ne scrive i file.

Usa SYS03 per discovery e selezione. Distingui installazione, profilo, ambiente e account; registra un alias locale, revisione/hash osservati e prova di caricamento. Una nuova identità account invalida il riscontro precedente. Un file 3.3 allineato può coesistere con istruzioni account 3.1: segnala il disallineamento. Allineamento account assistito soltanto se autorizzato e possibile; niente automazione del login. Le superfici non osservate restano unverified; exit 0 sui file non certifica gli account.

## Verifiche

Ripeti Verify dopo scritture autorizzate. Distingui file allineato, caricamento in una nuova sessione e superfici manuali non osservate.

## Consegna

Esiti per IDE, prove e passaggi manuali; exit 0 non certifica il caricamento.

## Prompt vicini

- MEM01: Allinea istruzioni locali, contesto, memoria e tracker.
- SYS02: Verifica le fonti autorevoli; acquisisci o aggiorna su richiesta.
- SYS12: Registra un IDE con più account o percorsi, con disclaimer e conferma.
