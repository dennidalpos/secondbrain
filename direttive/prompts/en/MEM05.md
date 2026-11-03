# MEM05 — Create, update and archive projects, areas and resources of the central PARA

> **Scope**: central | **Mode**: write | **Needs**: goal of the PARA entity and a write session on the SecondBrain clone | **Example**: `sb prompt MEM05: archive the finished resource res-guida`

## Purpose

Give every agent a single rule on where to insert, update and archive PARA entities, without inferring it from the file system or moving folders by hand.

## When to use

When work needs a new project or resource, when an entity changes status (completed, cancelled, retired) or when it must be archived or restored.

## Input

Entity type (project, area or resource), identifier (`^[a-z][a-z0-9-]{0,95}$`), title, goal, completion criteria for projects, linked Areas and the desired status. SecondBrain root with `para-index.json` and the entities' `para.json`.

## Activities

Where everything lives:

- **Area** (`02-areas/products/<name>--<hash>`): one dossier per repository, created only by `sb attiva` (SYS03). Do not create or move it by hand.
- **Project** (`01-projects/<id>`): work with a goal and completion criteria, tied to one or more active Areas.
- **Resource** (`03-resources/<id>`): reference knowledge not tied to a repository.
- **Archive** (`04-archives/{areas,projects,resources}/<id>`): destination of completed or retired entities. `PARA.md` and `para-index.json` are generated views: do not edit them.

`scripts/para.ps1` commands (writes with the `-SessionId` of a Write session; read first with `-Check` and `-SuggestArchive`):

1. **Insert.** `-NewProject -Id -Title -Areas -Objective -Acceptance` (existing active Areas, not repositories) or `-NewResource -Id -Title -Objective`. The identifier must be free. A project starts without a tracker: link a tracker only with a valid reference (area and path) and verify with `-Check`.
2. **Update.** `-SetStatus -EntityId -Status`: project `active|completed|cancelled`, area and resource `active|retired`. It changes only `status` in `para.json`, inside a transaction with backup. For the rest update `brief.md`, `context.md` and `memory.md` with the minimal-summary rule (MEM01).
3. **Archive.** Only `completed`, `cancelled` or `retired` entities, and Areas with no linked active projects: `-Archive -EntityId`. The command moves the folder to `04-archives/<category>/<id>` and updates references and tracker manifests in the same transaction. An archived dossier is not implicitly reactivated.
4. **Restore.** `-Restore -EntityId` returns the entity to active in `02-areas/products/<id>`, `01-projects/<id>` or `03-resources/<id>`: an Area comes back with its identifier, not with its original folder name.
5. **After every write.** Run `secondbrain.ps1 -Sync` and `-Check`; `para.ps1 -Check` confirms the consistency of index and metadata.

Do not delete or overwrite existing entities and do not touch `.runtime/para-transaction.json`: an interrupted transaction is restored with `recover.ps1` and the manifest indicated.

## Decisions to collect

- entity type and identifier;
- Areas linked to the project;
- archive now or only propose (`-SuggestArchive`).

## Checks

`para.ps1 -Check` and `secondbrain.ps1 -Check` with no problems; the entity appears in `para-index.json` with the expected path; no leftover file in the source folder after archiving.

## Delivery

Entities created, moved or with a changed status (identifier, path, status before and after), outcome of the checks and any recovery manifests.

## Related prompts

- MEM06: Read active memory, context and tracker of the current repository.
- SYS05: Compact the dossier preserving originals, facts and TOC.
- MEM03: Close the session: memories, tracker, handoff and commit and push request.
