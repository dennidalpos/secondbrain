# PARA e workflow

## Organizzazione

| Ambito | Percorso | Contenuto |
|---|---|---|
| Progetti | `01-projects/` | Iniziative finite, con obiettivo e criteri di completamento |
| Aree | `02-areas/products/` | Responsabilità continuative, dossier dei prodotti |
| Risorse | `03-resources/` | Riferimenti riutilizzabili |
| Archivi | `04-archives/{projects,areas,resources}/` | Entità inattive, spostate esplicitamente |

Ogni entità ha `para.json` schema 1, id stabile e `brief.md`. Stati dei Progetti: `active/completed/cancelled`; Aree e Risorse: `active/retired`. L'archiviazione è una posizione, non un nuovo id. Risolvere il percorso corrente da `para-index.json` e verificarlo sui metadati; `PARA.md` è la vista navigabile. Entrambi sono generati nella radice del clone e non sono versionati.

Le Aree conservano `repository.json`, contesto, memoria, eventuale tracker e snapshot. I Progetti collegano Aree per id e tracker per `area`/`path`; `repository: true` indica un eventuale tracker nel checkout. Le attività restano nel tracker esistente.

## Gestire un Progetto

```powershell
$cfg = '.runtime/hosts/<id>/workstation.json'
./scripts/para.ps1 -Check -ConfigPath $cfg
./scripts/para.ps1 -BuildIndex -ConfigPath $cfg
# Sostituire l'id Area con uno presente nell'indice:
./scripts/para.ps1 -NewProject -Id rilascio-prodotto -Title 'Rilascio prodotto' `
  -Areas @('area-identificatore-del-prodotto') -Objective 'Consegnare la release' `
  -Acceptance @('Test pertinenti superati', 'Artefatto verificato') -ConfigPath $cfg
```

## Comporre un prompt

```powershell
./scripts/prompts.ps1 -Compose -Prompt SEC01 -Objective 'Revisionare le modifiche locali' `
  -ProjectId adozione-para -ConfigPath $cfg
./scripts/prompts.ps1 -Compose -Prompt DEV02 -Objective 'Correggere il difetto descritto' `
  -Repository github.com/example-user/my-workspace -ConfigPath $cfg
```

`-ProjectId` e `-Repository` sono alternativi. Il compositore include brief del Progetto e percorsi verificati; non incorpora il contenuto dei dossier. Per checkout ambigui usare `-CheckoutPath` oppure `-CheckoutMapPath` (JSON identità GitHub → checkout presente nell'inventario locale). `-OutputPath` crea solo un nuovo `.txt`, senza sovrascrivere. Nessun task o servizio AI viene avviato.

## Archiviare e riattivare

`para.ps1 -SuggestArchive -ConfigPath $cfg` propone entità in stato concluso/ritirato. Non sposta dati. Per un'Area verifica anche l'assenza di Progetti attivi collegati; l'assenza di checkout non prova il ritiro.

Solo su richiesta esplicita:

```powershell
./scripts/para.ps1 -Archive -EntityId rilascio-prodotto -ConfigPath $cfg `
  -BackupRoot 'C:/SecondBrainBackup/para'
./scripts/para.ps1 -Restore -EntityId rilascio-prodotto -ConfigPath $cfg `
  -BackupRoot 'C:/SecondBrainBackup/para'
```

Restore riporta lo stato ad `active`. Gli spostamenti aggiornano i riferimenti gestiti e conservano gli snapshot byte per byte; eseguire poi Sync per aggiornare anche i blocchi dei checkout. Una Sync non riscrive i dossier archiviati. Manifest e recupero sono descritti nella [guida dedicata](recovery.md).

I manifest tracker registrati sono aggiornati nella stessa transazione, con identita e hash dei payload preservati. Sono ammessi gli stati `completed` e `rolled_back`; una importazione tracker pendente impedisce lo spostamento prima di qualsiasi scrittura. Anche il recupero transazionale comprende i manifest nei backupRoot delle postazioni registrate, dopo la validazione dei percorsi. Dettagli nella [guida tracker](trackers.md#spostamenti-para).

Fonti: [modello PARA](https://fortelabs.com/blog/para/), [CLI](../../scripts/para.ps1), [metadati e transazioni](../../scripts/SecondBrain.Para.psm1), [compositore](../../scripts/prompts.ps1). Per schede e numerazione vedere [cataloghi](directives-prompts.md).
