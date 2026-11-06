# Repository memory cycle

[Retained Italian source; use this English page for current behavior](memory-cycle.it.md)

The cycle keeps new authorized turns in a faithful registry separate from derived context/memory. It resolves one Git identity to an active PARA dossier. It does not import old chats, hidden reasoning or authentication stores automatically.

## Qualification and permission

The CLI accepts normalized events authorized for the current turn. Adapter profiles describe expected client events; they do not prove native capture. Without a verified live receipt Adapter reports liveVerified=false and partial coverage. A guided envelope pilot does not qualify native collectors or prove token savings.

Repository activation, common-text approval and turn persistence permission are separate. An installed hook or previous authorization is not a current permit. Unknown/disabled policy forbids persistence, queues and recovery.

~~~powershell
pwsh -NoProfile -File scripts/memory-cycle.ps1 -Operation Adapter -Client codex
pwsh -NoProfile -File scripts/knowledge.ps1 -Startup -NoRecovery
~~~

Adapter, Context and Maintenance are read-only. Capture/Promote require InputPath and preview without Apply; Index Apply rebuilds derived indexes. Initialize evidence workspaces through work.ps1.

## Capture contract

Schema 1 envelopes identify repository, client/version, session/turn, persistence, policyEvidence, termination, ordered events and attachments. Event kinds are user, assistant, tool-request, tool-result, error and interruption; IDs must be unique. Producer completeness remains declared-complete-unverified.

Limits are 8 MiB and 10,000 events per CLI envelope; excess does not silently truncate a turn. Private/do-not-memorize tags and flags exclude content before persistence. Open private regions continue to their closing boundary; private human requests also exclude resulting assistant/tool echoes until a new public human request. Only omission counts remain, without excluded text/paths/IDs.

Attachments need retained-event references and separately authorized exact AttachmentPath values. A transcript path is not permission. Originals up to 64 MiB are hashed/deduplicated within repository/host scope. Supported text formats use strict UTF-8 extraction; other formats remain original-only. Do not claim universal binary-secret detection, OCR or unperformed conversion.

## Bridge and receipts

memory-cycle-hook requires PermitPath binding exact repository, client/version, session/turn, transcript path, lastUserSha256, persistence, policyEvidence and initialized workspace. Native cwd/workspacePaths must match bindings before opening a writer session.

Codex uses turn_id, Claude Code the last human UUID and Antigravity executionNum. Changed request/session/turn/path invalidates a permit. Optional candidate/attachment paths authorize exact workspace files. The bridge neither installs hooks nor grants permission; errors do not prevent ending a client turn.

For an isolated probe, pass `-Diagnostics` and capture the bridge's stderr. It emits a JSON record with `schemaVersion`, `phase` and `outcome`. The record contains only fixed status values and can distinguish suppression during permit validation, native event handling, or repository binding from a capture attempt. The switch requires no diagnostic file and grants no persistence permission.

A live qualification receipt binds client/version, workspace, observation, evidence path/hash and the current module hash. Only evidenceKind=live-client can yield liveVerified. Hashes establish integrity, not truth or permission to persist.

## Promotion

A candidate binds capture path/hash, expected destination hashes and verified changes referencing retained event IDs.

| Kind | Required content |
|---|---|
| decision | Stable id, text/reason; supersession preserves earlier text |
| context | Complete required current-state sections |
| topic | Permitted topics path and content |
| task | ID, status, evidence; done includes matching verified acceptance |

These are reviewable agent assertions, not semantic engine proof. Ambiguity/stale hashes/missing evidence become proposals. Tracker/archive and memory changes share a transaction; earlier file versions remain hash-addressed. Derived-index failure does not undo a completed promotion.

Structured active/superseded markers coexist with older memory lines. Agent views omit superseded text while originals remain. Pragmatic STE wording is not ASD-STE100 certification.

## Loading and maintenance

Slim defaults to 30,000 characters and explicitly selected TaskIds; Full retains the full task projection. PreviousRevision can return changed=false without repeating parts. A changed packet does not guarantee replacement of client history. Essential sections/tasks are not dropped to manufacture budget compliance.

turns-index stores capture metadata transactionally. Notices distinguish captured and legacy turns; one collector per event avoids duplicates. SYS05 maintains batch history with preview/confirmation; MEM03 handles incremental closure. Historical permissions are not current authorization.
