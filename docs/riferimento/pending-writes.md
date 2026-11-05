# Deferred dossier writes

[Retained Italian source; use this English page for current behavior](pending-writes.it.md)

Supported changes are saved as requests before integration. A zero-wait central transaction then returns applied, deferred, conflict or invalid. Deferred means the request is retained, not that the dossier changed.

## Submit and inspect

Task operations use NewTask and UpdateTaskId. Results include requestId and requestPath; a new task receives its sequence only when integrated.

File requests accept memory.md, context.md and history/<slug>/report.md in the active identity-resolved dossier:

~~~powershell
pwsh -NoProfile -File scripts/knowledge.ps1 -AppendFile memory.md -ContentPath $contentPath -CheckoutPath $checkout
pwsh -NoProfile -File scripts/knowledge.ps1 -SaveFile context.md -ContentPath $contentPath -ExpectedHash $baseHash -CheckoutPath $checkout
pwsh -NoProfile -File scripts/knowledge.ps1 -PendingWrites -NoRecovery
~~~

Prepare content inside the managed runtime. Use the SHA-256 of the base actually read, or absent for a new target. Save replaces the expected base; Append preserves additions but does not reorganize memory. The request, including metadata, is limited to 2 MiB.

Configuration, directives, PARA operations and arbitrary attachments are outside this queue. Session ownership does not replace operation locks or hash preconditions.

## Automatic integration

Default MCP startup/lookups, knowledge reads, prompts.ps1 and Check attempt up to 10 requests per invocation. Each uses a short transaction. Busy centers leave requests pending while lookup continues. No extra periodic polling service is installed.

Strict no-write policy also forbids persistence, queues and recovery. Use knowledge NoRecovery or start the server with NoRecovery. Per-call noRecovery cannot undo startup recovery.

Requests and receipts remain under .runtime/access/pending-writes and pending-receipts. Extended task.update requests use a task-update subdirectory; updated consumers also recognize compatible earlier layouts. Older consumers cannot apply the new extended operations. Separate Git clones do not share these ignored files.

Destinations resolve through repository identity and the current brain alias rather than producer-host absolute paths. The destination change and receipt share a journal; duplicate importers do not apply one request twice.

## Conflicts and interruption

Expected hashes apply at task or file scope. Independent tasks may change concurrently; an edit to the same task/base produces conflict and preserves current data. Reconciliation is a new authorized request, not modification of the old evidence.

An invalid tracker graph can defer a request whose task hash remains verifiable; an unknown hash is an error. Invalid requests/receipts do not suppress independent valid work. Access errors are not successful receipts.

Interrupted transactions retain the normal recovery gate. Preserve manifests and use recover.ps1 after review; never delete markers or alter hashes to hide changed evidence.

## MCP contract

Tools advertise readOnlyHint=false, destructiveHint=true, idempotentHint=false and openWorldHint=false. These annotations describe behavior, not authorization. The server negotiates 2025-03-26 and supports 2024-11-05 when requested.

ApproveKnowledgeTools prepares named knowledge-tool consent; ApproveReadTools remains an alias. check_publication requires separate consent. No arbitrary shell or additional dossier-writing MCP tool is introduced.

Running servers keep loaded code until restarted. Do not restart another agent's session automatically. Fixture qualification and real shared-host qualification remain distinct; see [shared brain](shared-brain.md).
