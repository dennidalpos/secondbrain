# Reviewed MCP dossier writes

Two tools extend the nine other tools: preview_dossier_write returns a plan without persisting it; submit_dossier_write verifies a local CLI receipt and integrates only that request through pending-writes. MCP cannot approve its own writes.

## Operations

| Operation | Payload | Destination and precondition |
|---|---|---|
| task.status | taskId, status, optional reason | One task; hash of the complete current record |
| task.update | taskId plus at least one of status, reason, priority, execution, stream, awaiting, requires (array of capabilities) | One task through the task-update queue; hash of the complete current record; same validation as `knowledge.ps1 -UpdateTaskId` |
| task.new | title, acceptance array, provenance; optional description, priority, pointer, requires | Declared tracker and existing dossier history provenance; both hashes |
| memory.append | content | memory.md; current hash; agent view regenerated |
| activity.append | taskId, sessionId, when, outcome, detail | history/activity/report.md; current hash and local activation policy |
| history.save | path, content | history/<slug>/report.md; current hash or absent |

Only the active dossier of a managed checkout is writable. Repository, checkout, exact dossier path, workstation, OS user, operation, content, preconditions and a 32-character lowercase hexadecimal request ID are bound into the plan hash. New task IDs are MCP-<requestId>. Paths, field names, value types and sizes are validated. Cross-dossier provenance, shell commands, metadata paths and history replacement of the activity transport are refused.

For task.update, an empty string clears awaiting or stream, an empty requires array removes the capability list. `requires` accepts only `computer-use` (CLI: `knowledge.ps1 -Requires computer-use`, with `-NewTask` or `-UpdateTaskId`); the task runner leaves such tasks to an attended session. Each readRepositories entry must be a canonical identity (`github.com/<owner>/<name>` in lowercase or `local:<32 hex>`); duplicates are dropped. The allowlist is read-only: it never grants writes or access to another repository's tasks. A task.update that carries only status and reason is queued as task.status.

Explicit private/do-not-memorize tags are rejected before approval storage or queueing. This is not a general secret detector: review the plan and omit private material before sending it.

## Review, approve, submit

1. Call preview_dossier_write with repository, checkoutPath, requestId, operation and payload. Use a new ID for new content.
2. Save the exact returned JSON plan to an owned private, ignored work folder. Review all fields and hashes. The file is data, not authorization.
3. Approve through the local CLI in a coordinated session for that repository.
4. Call submit_dossier_write with repository, checkoutPath, requestId and planHash. MCP arguments cannot supply an approval boolean or a receipt path.

After explicit approval of the reviewed plan:

~~~powershell
$identity = 'github.com/example/product'
$session = & "$brain/scripts/access.ps1" -Start -Mode Write -Client Codex -Repository $identity | ConvertFrom-Json
try {
    $approval = @{
        Approve = $true
        PlanPath = $reviewedPlanPath
        ExpectedPlanHash = $reviewedPlanHash
        Authorization = 'Explicit approval of this operation and content'
        SessionId = $session.sessionId
    }
    & "$brain/scripts/mcp-write.ps1" @approval
} finally {
    & "$brain/scripts/access.ps1" -End -SessionId $session.sessionId
}
~~~

Resolve $brain locally. Never commit plans, receipts or workstation paths. Use the normal work.ps1 folder workflow for SecondBrain activity; product artifacts use their own ignored local folders.

The CLI verifies the plan against current files and writes a ten-minute receipt under localStateRoot/mcp-write-approvals/<repository-segment>/<requestId>.json. It does not submit. Changes require a new plan, ID and approval. Moving a dossier invalidates its old receipt, including MCP replay; normal recovery of an already queued request remains separate. Plans larger than 256 KiB in UTF-8 are refused at preview. The receipt includes the reviewed plan, actor, issue/expiry times and integrity hashes.

Filesystem permissions and OS identity protect this store. It is not a cryptographic boundary against code running as the same OS user. A process able to write that user's approval store or invoke the approving CLI with their authority is inside this trust boundary. The Authorization text must reflect an actual approval; an agent must not invent it.

## Replay, conflicts and recovery

One request ID maps to one queue file. Replays return/integrate the existing receipt without duplicating tasks, memory or activity entries. Different content cannot reuse the ID. Changed hashes produce a conflict and preserve intervening edits; there is no automatic rebase.

Expired unconsumed receipts cannot create requests. Once queued, a request is already authorized and can be recovered by normal consumers, including another host. Expiry or disabling a policy does not revoke an existing queued authorization. Backups, queue files, receipts and journals remain retained.

Submit integrates only its request and leaves unrelated entries waiting. No MCP tool performs automatic recovery; a denial does not drain the queue. A NoRecovery server, or submit with noRecovery=true, refuses submissions while still allowing previews.

## Activity transport

F5 emits version-1 records with eventId, user, repository, taskId, session, when, where, computer, outcome and detail. The caller supplies a timestamp and session reference; the server derives OS actor and checkout scope. The private history file contains one compact JSON record per line.

New activity submissions are disabled unless the workstation configuration explicitly has activityLogEnabled=true. Tests enable this only in isolated synthetic configuration. This change does not enable it on the real workstation. F6 owns activation, indexing, Trace integration and the generated team view; F11 retains checks before actual team activation. Do not set the flag to bypass those steps.

## Client support and approval matrix

| Surface | Contract | Evidence |
|---|---|---|
| Local stdio | Twelve tools; preview, local receipt and submit | Synthetic handshake, CLI and operation fixtures |
| Codex CLI / Claude Code | Tool discovery after restarting an owned session; local receipt required | Protocol contract only; live qualification deferred |
| Cursor / VS Code / Windsurf / Antigravity / Claude Desktop | Same server contract where tools are exposed | Real UI, profile and approval behavior unverified |
| Another workstation | Recovery of an authorized shared request; no reuse of another host's local receipt for a new submit | Physical multi-host/SMB qualification deferred |

ApproveKnowledgeTools and ApproveAllTools retain their seven/eight existing named scopes; neither includes the new tools. Host confirmation and the local receipt are separate controls. This feature does not install wildcard approvals or change personal IDE settings.

The [MCP tools specification](https://modelcontextprotocol.io/specification/2025-03-26/server/tools) leaves the interaction model to clients and defines schemas/annotations. The local receipt is a SecondBrain contract, not a universal MCP approval token. Protocol negotiation is unchanged. Synthetic tests do not qualify real clients, accounts or physical hosts; those checks remain after structural development.
## Test profiles

Fast runs a write-free MCP smoke for scope/hash binding, denial, private payload rejection and NoRecovery. The complete synthetic operation, CLI and protocol matrix is unchanged in -Only mcp-writes and is included as a separate process in Full. Publication still requires the complete Full profile; budgets are 90/600 seconds.
