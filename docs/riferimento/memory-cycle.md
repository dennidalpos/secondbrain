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

memory-cycle-hook requires PermitPath and PermitSha256 binding exact repository, client/version, session/turn, transcript path, lastUserSha256, persistence, policyEvidence and initialized workspace. Native cwd/workspacePaths must match bindings before opening a writer session.

Codex uses turn_id, Claude Code the last human UUID and Antigravity executionNum. Changed request/session/turn/path invalidates a permit. Optional candidate/attachment paths authorize exact workspace files. The bridge neither installs hooks nor grants permission; errors do not prevent ending a client turn.

For an isolated probe, pass `-Diagnostics` and capture the bridge's stderr. It emits a JSON record with `schemaVersion`, `phase` and `outcome`. The record contains only fixed status values and can distinguish suppression during permit validation, native event handling, or repository binding from a capture attempt. The switch requires no diagnostic file and grants no persistence permission.

A live qualification receipt binds client/version, workspace, observation, evidence path/hash and the current module hash. Only evidenceKind=live-client can yield liveVerified. Hashes establish integrity, not truth or permission to persist.

When Codex Stop repeats the text of a final transcript message, the bridge keeps the structured transcript message once. It retains the Stop reply when the transcript lacks that final text or contains a different reply.

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

## Explicit single-turn CLI receipt (1.4.0)

Use an initialized evidence workspace from work.ps1. Prepare a private, Git-ignored request JSON containing schemaVersion=1, repository, client, clientVersion, sessionId, turnId, the absolute transcriptPath, requestContent, persistence="allowed" and policyEvidence for this one turn. requestContent must be the exact native human content: Codex text blocks, Claude Code string/blocks, or Antigravity userMessage. Do not infer consent from permission_mode, hook installation or an earlier turn.

    pwsh -NoProfile -File scripts/memory-cycle.ps1 -Operation Permit -InputPath <request.json> -Workspace <initialized-evidence>

Review the returned permit, then explicitly authorize that single request:

    pwsh -NoProfile -File scripts/memory-cycle.ps1 -Operation Permit -InputPath <request.json> -Workspace <initialized-evidence> -Apply

Supply the returned permitPath and permitSha256 to that turn's Stop command:

    pwsh -NoProfile -File scripts/memory-cycle-hook.ps1 -Client codex -PermitPath <permitPath> -PermitSha256 <permitSha256>

The native Stop JSON goes to the last command's stdin. This does not install or modify IDE hooks. When native boundaries are unavailable, use the guided normalized-envelope fallback; never invent IDs or reuse another turn's authorization. Issuance requires known session/turn identifiers before Stop delivery. This contract has synthetic tests for all three native formats, not new live-client qualification.

Preview writes nothing. Apply stores one immutable, content-addressed receipt under workspace/permits; it retains the human request hash, not requestContent. Reissuing identical input returns duplicate. The receipt binds repository, client/version, session/turn, exact transcript, policy evidence, workspace and current module/bridge revisions. The bridge needs both path and hash; missing/malformed/changed hashes and changed code suppress capture without blocking Stop. Old handwritten permits without the CLI authorization marker and current revision hashes are suppressed. Regenerate a receipt explicitly after a code revision.

Optional attachments list exact authorized files with retained eventId references. Optional candidatePath must name a workspace candidate already prepared by the agent; its bytes are hash-bound. For automatic promotion, set captureSha256="bind-current-turn": the bridge binds it to the captured record, then uses the existing transactional promotion checks. A changed candidate cannot be promoted. Unverified changes, stale destination hashes and ambiguous assertions remain proposals. A repeated Stop is idempotent; a different request/session/turn/transcript is rejected.

Unknown/denied permission and private permit requests exit before configuration, writer sessions, queues or recovery. To revoke an issued receipt, change its persistence to denied; its previous hash then no longer validates. No permanent consent, retroactive capture or automatic enablement of another repository is introduced. Hashes bind the reviewed local CLI artifact; they are not digital signatures or evidence that a client actually delivered an event.

Source for Codex native event fields: [OpenAI Docs: hooks](https://learn.chatgpt.com/docs/hooks). Client permission modes describe tool execution policy and are not memory-persistence authorization.
