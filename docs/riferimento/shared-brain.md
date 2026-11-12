# A shared SecondBrain root

[Retained Italian source; use this English page for current behavior](shared-brain.it.md)

The implementation supports a shared-root model with one authoritative dossier per identity, per-host configuration and serialized writes. Local and loopback SMB fixtures exist; real multi-PC/multi-user SMB qualification remains incomplete. Do not present that deployment as fully supported from fixture success alone.

## Topology

~~~mermaid
flowchart LR
    A[PC A: local checkouts and IDE] --> S[Authoritative UNC brain]
    B[PC B: local checkouts and IDE] --> S
    S --> D[Shared dossiers and instructions]
    S --> C[Shared access coordination]
    S --> H[Isolated host and repository runtime]
~~~

Dossiers, the PARA index, shared policy, directives and `.runtime/access` are shared. Team Setup places bindings, state, inventory, receipts and IDE files in the workstation's local state directory. Older deployments may have these files under `.runtime/hosts/<id>`. `SECONDBRAIN_HOME` belongs to each user's environment. Separate Git clones do not share ignored dossiers or queues.

## Permissions and activation

Windows/SMB/NTFS enforce rights; SecondBrain is not a user-authorization service. Pure reads require read access. Session registration, `knowledge.ps1 -FlushPending` and writers need the corresponding modification rights. Check, knowledge and MCP lookups do not write to the dossier.

Assign script/policy/catalog maintenance only to intended maintainers. Writers also need create/replace access to the relevant runtime/coordination paths. Approval hashes establish integrity, not access control.

Prefer an explicit UNC path over user/session-specific drive mappings. From the local SecondBrain checkout, use `-Setup -TeamRoot <UNC> -Interactive` with `SECONDBRAIN_STATE_ROOT` on a fixed local drive. The same run previews the selection and applies it after confirmation. Use the authoritative root for later commands. A real workstation relocation needs Reconcile.

ExecutionPolicy/zone classification and Git ownership must be checked on the actual host. Do not weaken global policy or trust arbitrary safe.directory entries to hide a configuration error.

## Writes and interruption

Ordinary sessions record ownership/heartbeat; writer.lock and operation.lock protect individual transactions through FIFO tickets. General writers wait up to the configured limit and return exit 3 on timeout. Supported dossier requests instead wait briefly (SECONDBRAIN_PENDING_WAIT_SECONDS, default 8 s), then stay queued until `knowledge.ps1 -FlushPending`.

Readers report active-writer or pending-transaction warnings. Their snapshot can be intermediate. Protected writes validate base hashes and preserve recovery data. Never remove locks or incomplete markers.

An interrupted PARA transaction blocks central writes. A different host may recover only after validating the common root/manifest through its own alias. Preview recover.ps1 before separately authorized Apply; later destination edits are refused.

## Performance and operational limits

UNC PARA scans have a short process cache invalidated by writes. Runtime work/cache/temp are host-scoped. The optional SECONDBRAIN_WORK_LOCAL_ROOT override is a declared tool capability, not a default relocation authorization; verify its local-only destination and output plan.

A slow network, lost session, ACL difference or NAS lease behavior can differ from loopback tests. FIFO tickets use producing-host UTC timestamps; clock skew across PCs can affect apparent arrival order.

## Required real-host qualification

Before claiming multi-host support, test on two or three actual PCs with the intended accounts/share:

1. Setup through UNC/FQDN; verify distinct host IDs and preserved bindings.
2. Concurrent Sync: serialization or documented timeout without overlap.
3. Read during writing: warning and no blocking wait.
4. Interrupted writer and recovery from another host.
5. Short-name/FQDN/mapped aliases, effective permissions and execution policy.
6. FileShare.None/leases, clock behavior, latency and any NAS/Samba implementation.

Local process concurrency and a simulated second profile do not change actual MachineName/SID. Loopback SMB exercises the stack on one PC/user and therefore does not satisfy this checklist. Record outcomes as partial until those missing cases are observed.

See [access](access.md), [recovery](recovery.md), [portable configuration](portable-brain.md).
