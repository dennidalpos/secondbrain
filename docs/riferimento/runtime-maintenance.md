# Runtime work, retained tests and layered context

[Retained Italian source; use this English page for current behavior](runtime-maintenance.it.md)

.runtime contains host configuration, backups, reports, fixtures and operational work. It is excluded from Git. Growth does not authorize cleanup; preserve references, original evidence and other sessions' ownership.

## Categories and inspection

| Category | Treatment |
|---|---|
| protected | Active configuration, coordination, state and recovery gates |
| evidence / report | Non-reproducible proof/provenance; no automatic expiry |
| backup | Recovery originals, metadata and transaction records |
| working | Session-owned temporary development work |
| regenerable | Re-creatable outputs; still require an authorized cleanup |

~~~powershell
pwsh -NoProfile -File scripts/cleanup.ps1 -RuntimeReport
pwsh -NoProfile -File scripts/cleanup.ps1 -ListRuntime
~~~

RuntimeReport without ReportPath prints a derived index. ReportPath .runtime/INDEX.md regenerates that view; another report target must be new and inside runtime. Neither inspection removes or moves data.

## Work folders and sessions

New work uses hosts/<id>/repos/<repo>/<category>/<yyyyMMdd>-<slug> with work/evidence/report/fixture/tmp. The repository segment includes an identity hash. TEMP/TMP use the repository temp area.

Initialize with work.ps1 Repository/Category/Slug/Init/Task/SessionId; Close marks the manifest closed. A plan without Init/Run creates nothing. Normal access Start/End belongs in one try/finally script; pass the same SessionId to CLIs.

Manifests bind host/user/client/session/task, status and expiry. Fixture/tmp default to 7 days and retain the latest five per repository; work is considered after 30 days from closure. Evidence/report do not expire automatically. These are manifest policy metadata, not a scheduled deletion service. The current Regenerable selector does not enforce manifest expiry/closed state or current-host ownership: it considers fixture/tmp beyond the latest five across hosts using MinAgeMinutes (default 10). Do not assume the 7/30-day policy is enforced by that command; review exact targets, ownership and recovery before any separately authorized cleanup.

Old flat/legacy layouts are preserved. Migrate previews proposed same-volume moves; Apply needs explicit Authorization and checks active sessions, recent folders, reparse points and collisions. Regenerable cleanup is preview-first and records a journal, but has the manifest/host-selection gap described above. No migration/cleanup belongs to an ordinary documentation update.

## Verification levels

~~~powershell
pwsh -NoProfile -File scripts/test-secondbrain.ps1 -Quick
pwsh -NoProfile -File scripts/test-secondbrain.ps1
pwsh -NoProfile -File scripts/test-secondbrain.ps1 -Full
pwsh -NoProfile -File scripts/build-prompts.ps1 -Check
pwsh -NoProfile -File scripts/check-distribution.ps1
~~~

Quick is pure local source verification (no Git/child processes), budget 15 seconds. Default essential checks have a 90-second budget; Full adds critical boundaries with 300 seconds on the reference workstation. Run relevant sub-suites for changed behavior; do not repeat successful checks without changed inputs, errors or new uncertainty.

Every run preserves run.json, logs and fixtures, including successful runs. Child runners use sibling directories linked by reports; esito.json points to the latest run. KeepFixtures remains accepted, but preservation is already the current behavior. Run evidence binds commands, environment, source hashes and durations. A timestamp alone is not reusable validation; compare inputs/environment and coverage.

Git environment, locale, long paths and fixture prerequisites can affect tests. Use process-scoped overrides and restore them even on error. ACL/loopback/SMB skips are explicit limits, not successful application qualification. Product checks belong to product agents with verified output redirection. Optional pending-queue benchmarks are explicit workloads, not routine maintenance.

## Layered startup

~~~powershell
pwsh -NoProfile -File scripts/knowledge.ps1 -Startup -NoRecovery -Report
pwsh -NoProfile -File scripts/knowledge.ps1 -Startup -Profile Full -NoRecovery
pwsh -NoProfile -File scripts/knowledge.ps1 -Search "terms" -NoRecovery
~~~

Slim composes index, essential context/memory, explicitly selected TaskIds and references to deeper layers. Its first-load default is 30,000 characters, not tokens. Without TaskIds it does not include tasks. Full has no default budget; search separately defaults to 20 matches and 10,000 characters, with paging/overrides.

Selection keeps whole blocks in deterministic order. If the essential minimum exceeds budget, report withinBudget=false/minimumCharacters rather than dropping essentials. PreviousRevision can suppress repeated unchanged parts. After the first package, load relevant sections/task/history through the documented commands; the initial ceiling is not a permanent conversation cap.

## Compaction

SYS05 reviews a complete candidate and preserves originals by hash. knowledge Compact previews; CandidatePath Apply requires the reviewed source hashes and confirmation. Tracker/history are not discarded to fit a budget, and historical permissions are not renewed.

Trace/memory-cycle turn counting only covers observed authorized metadata. Missing or legacy collector IDs affect coverage; no turn transcript is invented. See [memory cycle](memory-cycle.md), [recovery](recovery.md), [safe writes](safety-backups.md).
