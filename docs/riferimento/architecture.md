# Architecture and modules

[Retained Italian source; use this English page for current behavior](architecture.it.md)

SecondBrain separates distributable code and approved instructions from private knowledge and workstation state.

~~~mermaid
flowchart LR
    A[Git identity] --> B[PARA and repository metadata]
    B --> C[Authoritative dossier and tracker]
    C --> D[Layered knowledge CLI]
    D --> E[Local stdio MCP]
    F[Approved instruction sources] --> G[Managed blocks]
    H[Runtime coordination and recovery] --> C
    H --> G
~~~

## Data boundary and modules

Git tracks scripts, schemas, public documentation and approved instruction sources. PARA dossiers and .runtime are excluded. Ignore rules are not encryption or history scrubbing.

| Module family | Responsibility |
|---|---|
| Core | Hashes, path validation, stable serialization and guarded I/O |
| Access / Pending | Configuration, sessions, FIFO locks and deferred requests |
| Host / Portable | Discovery, bindings and instruction distribution |
| Para / Tracker | Entity IDs, declared tracker, graph validation and transactions |
| Knowledge | Startup composition, task/section lookup, search and compaction |
| Prompts | Catalog/card validation, context resolution and XML composition |
| Mcp | stdio JSON-RPC and ten exposed tools, including reviewed write preview/submission |
| Publication | Working-tree/index/history checks |
| Sources / ExternalAudit | Explicit source and GitHub acquisition |
| Trace / MemoryCycle | Turn metadata and separately enabled repository memory |

The exact current decomposition is in scripts/SecondBrain.*.psm1. The brain may reside locally or on an explicitly configured shared root; host configuration and work remain isolated. Separate Git clones do not synchronize ignored knowledge.

## Context resolution

Resolve checkout identity from Git/bindings, map it through PARA and verify repository.json. Its declared tracker is authoritative; missing/invalid data is an error.

prompts Context resolves paths. knowledge Startup builds index, context, essential memory, selected tasks and references to deeper levels. Slim defaults to 30,000 characters on first load; without TaskIds it does not include task details. Full has no default budget. Insufficient essential budget reports minimumCharacters/withinBudget rather than silently dropping essential content.

PreviousRevision can suppress unchanged parts. Search uses separate paging/budget defaults. Complete historical evidence is loaded only when pertinent.

## Writes, tasks and recovery

Authorized operations coordinate, validate paths/base hashes, stage bytes adjacent to targets, verify them and replace destinations. Clean tracked originals are recoverable by commit/blob; local originals use verified backups. Dirty tracked instructions are protected.

Ordinary sessions record ownership without holding writer.lock throughout. Deferred requests integrate through short transactions with receipts. Interruptions preserve journals and require explicit recovery. Hashes prove integrity/change detection, not digital signatures or user authorization.

Tracker schema 1 supports todo/in_progress/blocked/done/cancelled/unknown, with priority, execution, dependencies, acceptance and provenance. Ready status depends on the validated graph. Verified terminal tasks move to history preserving identifiers and references; code existence alone is not acceptance.

## Distribution and publication

Sync verifies approved source hashes and generates delimited repository/global blocks. It preserves unrelated text and reports dirty/conflicting instructions. Proposal approval, deployment and live IDE loading are separate steps.

check-distribution examines the Git distribution boundary. publication inventories working tree, index and reachable history plus supplied push objects. Rules identify credential/private-path/email/operational artifacts, with fingerprint-specific reviews and explicit incomplete coverage.

ready=true is bounded by those checks. Binary contents, external copies, undiscovered secrets and legal compliance are not certified. Explicit remote/source operations and dependency acquisition can use networking; do not claim every command is offline.

MCP uses stdio without a listening port. Startup/lookups may integrate already-authorized writes, so it is not strictly read-only. NoRecovery is needed when writes are forbidden. Live collectors/client loading and real two-host SMB remain distinct from local fixture qualification.
