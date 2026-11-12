# Deferred dossier writes

[Retained Italian source; use this English page for current behavior](pending-writes.it.md)

Supported changes are saved as requests before integration. A central transaction then waits for the writer lock for at most SECONDBRAIN_PENDING_WAIT_SECONDS (0-120, default 8) and returns applied, deferred, conflict or invalid. A CLI submission also integrates the other queued requests of the same repository; MCP `submit_dossier_write` integrates only its own. Deferred means the request is retained, not that the dossier changed.

## Submit and inspect

Task operations use NewTask and UpdateTaskId. Results include requestId and requestPath; a new task receives its sequence only when integrated.

File requests accept memory.md, context.md and history/<slug>/report.md in the active identity-resolved dossier:

~~~powershell
pwsh -NoProfile -File scripts/knowledge.ps1 -AppendFile memory.md -ContentPath $contentPath -CheckoutPath $checkout
pwsh -NoProfile -File scripts/knowledge.ps1 -SaveFile context.md -ContentPath $contentPath -ExpectedHash $baseHash -CheckoutPath $checkout
pwsh -NoProfile -File scripts/knowledge.ps1 -PendingWrites -NoRecovery
pwsh -NoProfile -File scripts/knowledge.ps1 -PendingWrites -PendingSummary
pwsh -NoProfile -File scripts/knowledge.ps1 -PendingWrites -PendingState conflict,deferred
~~~

`-PendingSummary` prints only the totals per state with a next step; `-PendingState` filters the list (deferred, conflict, applied, discarded, invalid). The default output is unchanged.

Prepare content inside the managed runtime. Use the SHA-256 of the base actually read, or absent for a new target. Save replaces the expected base; Append preserves additions but does not reorganize memory. The request, including metadata, is limited to 2 MiB.

Configuration, directives, PARA operations and arbitrary attachments are outside this queue. Session ownership does not replace operation locks or hash preconditions.

## Automatic integration

Reads never write (#474): MCP startup and lookups, knowledge -Startup/-Tasks/-Task/-Section/-Search/-Roadmap/-PendingWrites, prompts.ps1 and secondbrain.ps1 -Check leave the queue and the dossier unchanged. Queued requests are integrated only by an explicit command, and only those of the dossier in work:

~~~powershell
pwsh -NoProfile -File scripts/knowledge.ps1 -FlushPending -CheckoutPath $checkout
~~~

-FlushPending waits for the writer lock (shared policy), takes -Repository or the checkout's repository and refuses to run without one; submit_dossier_write integrates its own reviewed request. No periodic polling service is installed. NoRecovery (CLI switch, MCP server switch or per-call noRecovery) is kept for compatibility: on the CLI it is a no-op for reads, on MCP it forbids new writes.

Requests and receipts remain under .runtime/access/pending-writes and pending-receipts. Extended task.update requests use a task-update subdirectory; updated consumers also recognize compatible earlier layouts. Older consumers cannot apply the new extended operations. Separate Git clones do not share these ignored files.

Destinations resolve through repository identity and the current brain alias rather than producer-host absolute paths. The destination change and receipt share a journal; duplicate importers do not apply one request twice.

## Conflicts and interruption

Expected hashes apply at task or file scope. Independent tasks may change concurrently; an edit to the same task/base produces conflict and preserves current data. Reconciliation is a new authorized request, not modification of the old evidence.

An invalid tracker graph can defer a request whose task hash remains verifiable; an unknown hash is an error. Invalid requests/receipts do not suppress independent valid work. Access errors are not successful receipts.

Interrupted transactions retain the normal recovery gate. Preserve manifests and use recover.ps1 after review; never delete markers or alter hashes to hide changed evidence.

A conflict or invalid request that is no longer needed (its effect already reached the dossier by another write) is retired explicitly, never deleted by hand:

~~~powershell
pwsh -NoProfile -File scripts/knowledge.ps1 -DiscardPending <32-hex request id>
~~~

Only conflict, invalid and invalid-receipt states are accepted; deferred and applied requests are refused. Request and receipt move to .runtime/access/pending-discarded/<id>/ with a discarded.json note (state, request hash, time), so the evidence is preserved. The command takes the writer lock and is incompatible with NoRecovery.

## MCP contract

Every tool advertises readOnlyHint=true, destructiveHint=false, idempotentHint=true and openWorldHint=false, except submit_dossier_write (readOnlyHint=false, destructiveHint=true, idempotentHint=true). These annotations describe behavior, not authorization. The server negotiates 2025-03-26 and supports 2024-11-05 when requested.

ApproveKnowledgeTools prepares named knowledge-tool consent; ApproveReadTools remains an alias. check_publication requires separate consent. No arbitrary shell is exposed. The two additional reviewed-write tools are documented in [MCP writes](mcp-writes.md); they do not inherit the existing named preauthorization scopes.

Running servers keep loaded code until restarted. Do not restart another agent's session automatically. Fixture qualification and real shared-host qualification remain distinct; see [shared brain](shared-brain.md).
