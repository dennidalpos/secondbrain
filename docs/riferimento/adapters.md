# IDE adapters and live qualification

[Retained Italian source; use this English page for current behavior](adapters.it.md)

SecondBrain distinguishes file configuration, installed client, profile, environment, account and actual loaded instructions. Evidence on one surface does not certify the others. SYS01 guides verification after setup and after login/profile changes.

## Inspect the map

~~~powershell
pwsh -NoProfile -File scripts/ide-map.ps1 -Verify
~~~

The verifier compares selected instruction files with the expected generated global block. Manual integrations require an observation receipt. Exit codes are 0 aligned/verified within scope, 1 pending alignment/qualification or missing map, 2 error.

The host map is generated from active bindings/discovery. Do not manually mark a client/account verified. A file can be aligned while account/loading remains unverified; record both outcomes.

## Surface-specific workflow

| Surface | Required evidence |
|---|---|
| Repository instructions | Correct AGENTS source and generated adapter pointers |
| User file | Actual selected configuration root and approved block hash |
| Project/profile | Workspace/profile identity and the configuration really used |
| Account setting | User-declared account alias and manually observed instruction text |
| Running client | New-session observation with revision/hash and evidence |
| Write capability | Actual permitted roots and observed command/denial, not a guessed sandbox model |

No credential/authentication archive is read to discover accounts. Multiple accounts/config roots need distinct declared entries; login is manual. Treat changed account/profile/environment identity as ide-context-changed and requalify it.

## File and manual integrations

Claude-family, Codex and Antigravity have supported file/registration paths in the implementation. Additional adapters can be discovered without being live-qualified. A running executable or directory is evidence of presence only.

Manual account surfaces, including app settings and integrations without an instruction file, require the user to apply the generated text and provide a real observation. Do not infer account instructions from a generic help page or another profile.

The repository common source is AGENTS.md. Sync manages CLAUDE.md/GEMINI.md import pointers for adapters needing them; other clients may require their own supported configuration. Preserve unrelated content and report conflicts instead of editing generated blocks by hand.

## MCP is a separate check

Pair preview inspects target/scope/path; Apply changes selected configuration after authorization. Codex/Claude Code user registration and workspace configuration are different scopes. A successful stdio handshake proves protocol behavior in that run, not live instruction loading or account state.

Use [MCP setup](mcp-setup.md) for target/permission/package details. Restart only the intended owned client session when configuration changes require it.

## Account text from a receipt (#188)

Typed `revision=` and `hash=` values can contain typos. `-IdeAccount "<ide>|<alias>|observation=<path>"` reads them instead from a JSON receipt under `.runtime` (manual IDE surfaces only; not combinable with `revision=`/`hash=`):

    {"schemaVersion":1,"ideId":"<optional id>","accountAlias":"<optional alias>","observedRevision":"1.0","observedHash":"<64 hex sha256 of the account text>"}

The path must be inside `.runtime`; unknown fields, a non-numeric revision, a hash that is not 64 hex characters, an `ideId` or `accountAlias` that differs from the entry, a missing or malformed file are rejected before the preview. The registered entry records the receipt file hash in its note, and the setup preview shows revision and hash before confirmation. Loading in a chat remains unverified (see delegated verification). Verified on fixtures for the reader (`-Only trace`) and by a read-only `-Setup -PreviewOnly` run with a valid receipt (revision and hash appear in `ideBindings`), a path outside `.runtime` and a `revision=` mix (both rejected); no applied activation was run.

## Delegated verification (#155)

What the filesystem cannot show (active account, loading in a new session) is delegated to an agent already installed. SecondBrain builds the package; the agent observes and produces the receipt; SecondBrain validates and registers it. Nothing here logs in, reads authentication stores or edits IDE files.

    pwsh -NoProfile -File scripts/ide-observation.ps1 -Operation Package -IdeId <id>
    pwsh -NoProfile -File scripts/ide-observation.ps1 -Operation Register -IdeId <id> -InputPath <receipt.json>
    pwsh -NoProfile -File scripts/ide-observation.ps1 -Operation Register -IdeId <id> -InputPath <receipt.json> -PreviewSha256 <previewed hash> -Apply
    pwsh -NoProfile -File scripts/ide-observation.ps1 -Operation Prune [-Apply]
    pwsh -NoProfile -File scripts/ide-map.ps1 -Verify -ObservationPath <repo>/.runtime/hosts/<host>/ide-observations.json

- Package (read-only) prints the new-session steps, the expected revision and hash, the account alias and an exact receipt template. One account is one integration id, so two accounts of the same IDE get two packages.
- Register validates the receipt with the same predicate as `ide-map.ps1 -Verify` (host, profile, account alias, text hash, freshness of 15 minutes, evidence hash inside `.runtime`) and rejects unknown fields. The preview writes nothing; Apply requires the previewed hash and rejects a missing or different one, so a receipt changed after review is never stored. A new receipt replaces only the same id.
- Prune removes receipts of integrations no longer in the map, for example after `secondbrain.ps1 -Setup -Unbind <id>`.
- Limit: the receipt is declared by the observing agent and proven only by the evidence hash. Verified on synthetic fixtures (two alternating accounts, `-Only trace`); live observations stay in #153/#180.

## Observation receipts and limits

ObservationPath supplies a schema-validated receipt bound to the intended host/client/account/profile, expected text hash and real evidence. Freshness/current context and source revision matter. A fabricated receipt or a fixture cannot qualify a live client.

Write access is also observed, not assumed. core.write.denied/CLI exit 4 differs from lock contention (exit 3). Preserve original diagnostics and recovery markers; do not automatically widen writable roots or modify private IDE instructions as a shortcut.

Sources in local fixtures demonstrate parser/adaptor behavior. They do not prove every installed client version, GUI permission dialog, account setting, native collector or multi-host filesystem condition. Report unavailable observations as pending.

See [safe writes](safety-backups.md), [access](access.md), [memory cycle](memory-cycle.md) and [operations](operations.md).

## Reviewed MCP writes

The [write support matrix](mcp-writes.md#client-support-and-approval-matrix) separates the synthetic stdio contract from real client qualification. Local receipts bind one request to its user, workstation and checkout. Neither existing preauthorization scope includes the new tools. Personal IDE settings are unchanged.

## Single-turn memory permissions

Memory collectors use the explicit [Permit CLI receipt](memory-cycle.md#explicit-single-turn-cli-receipt-140). Codex, Claude Code and Antigravity share receipt validation and the Stop bridge, with native boundaries checked on synthetic fixtures. Those fixtures do not qualify installed client versions. If the client does not expose the required request and turn identifiers, keep the normalized-envelope fallback. Existing live receipts are revision-bound; a changed module requires new qualification.

| Client | Native boundary checked on fixture | Version claim |
|---|---|---|
| Codex | session_id, turn_id, transcript_path, exact human text blocks; Stop final text deduplication | clientVersion="fixture"; no new installed-version qualification |
| Claude Code | session_id, transcript_path, last human UUID and exact content | clientVersion="fixture"; no new installed-version qualification |
| Antigravity | conversationId, executionNum, transcriptPath, exact userMessage, declared terminationReason | clientVersion="fixture"; no new installed-version qualification |

The CLI stores the version asserted by its caller. It does not discover or certify that version. Error/interruption fields supplied by a producer can be preserved; missing native delivery or missing termination fields remain unknown. Physical crashes and real client interruptions remain in #352.