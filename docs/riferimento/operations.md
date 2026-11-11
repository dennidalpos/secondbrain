# Operations reference

[Retained Italian source; use this English page for current behavior](operations.it.md)

Run scripts from the SecondBrain checkout with PowerShell 7.5+ and Git 2.42+. ConfigPath is optional after activation; the current host configuration resolves under .runtime/hosts/<id>.

## Workflow

~~~mermaid
flowchart LR
    A[Discover and activate] --> B[Sync approved instructions]
    B --> C[Verify selected IDE]
    C --> D[Load essential context and ready work]
    D --> E[Authorized repository work]
    E --> F[Evidence and permitted closure]
    F --> G[Publication check before authorized push]
~~~

prompts Context resolves paths; knowledge Startup loads the actual packet. A resolved path is not loaded knowledge.

### Review workstation setup

Run `scripts/secondbrain.ps1 -Setup -PreviewOnly -Roots <folder>` to list discovered repositories and IDEs. Add `-Interactive` to select several assets, or pass `-Select` and `-Ides` to review an explicit selection. The resulting plan lists dossier metadata paths and MCP destinations. The preview skips the runtime write probe and leaves discovery, selection, activation and MCP files untouched.

Run `-Setup -Interactive -Roots <folder>` to review the activation and MCP plans and apply them in the same run. Type `APPLICA` to confirm. Press Enter to finish with the preview and leave workstation files untouched.

For team setup, pass `-TeamRoot '\\server\share'` for an existing authoritative SecondBrain root. Discovery still targets the local checkout by default. Use `-PreviewOnly` to review the plan, or set `SECONDBRAIN_STATE_ROOT` to a directory on a fixed local drive and use `-Interactive` to review and activate in one run. Automation can use `-Yes -Apply` for an already approved selection. Team access uses the share's existing ACLs.

If a selected repository has an active dossier in both roots, `dossierConflicts` lists the identity, checkout and both dossier paths. Setup stops before writing. Review the dossiers against that checkout before agreeing on consolidation.

Setup keeps the workstation configuration, inventory, discovery, selection, receipts and IDE state in the local state directory. The share receives dossier changes, generated PARA views and coordination records, including recovery journals under `.runtime/access/recovery`. Run subsequent commands from the authoritative root with the same local state setting.

<a id="controllo-e-sincronizzazione-su-richiesta"></a>

## Check and Sync

~~~powershell
pwsh -NoProfile -File scripts/secondbrain.ps1 -Check
pwsh -NoProfile -File scripts/secondbrain.ps1 -Sync
~~~


**Exit code.** `-Check` and `ide-map.ps1 -Verify` exit 1 whenever `aligned` is false, that is on any issue, not only on file misalignment (exit 2 = error, 3 = writer busy, 4 = write denied). Expected on a workstation without live evidence: `ide-write-scope-unverified`, `ide-loading-unverified`, `account-unverified` (manual Claude account instructions) and `candidate-pending` are environmental and clear only with a real session receipt, a write-scope probe or a reviewed account; `changed` and `authoritative-source` entries need `resources.ps1 -Sync` or SYS05. Exit 0 requires none of them.
Check first attempts already-authorized deferred writes with zero lock wait. Asset checks do not apply their corrections. concurrent-writer/pending-transaction warnings mean the observed state may be intermediate.

Sync writes immediately through coordination, backups and hashes. It generates approved managed blocks/local views, preserves unrelated text and reports conflicts. New assets require explicit Setup selection; unapproved source text is not distributed. Neither command schedules monitoring.

Use NoRecovery-capable knowledge lookup/server startup when the session forbids all writes. A filtered Check/Sync with Repository limits coverage to that managed identity; it does not certify other products, IDEs or global instructions.

## Knowledge and closure

Slim selects whole Markdown blocks deterministically, with a first-load default of 50,000 characters. Without explicit TaskIds it includes no task detail. Full and deeper lookups remain available; essential content is not silently discarded.

A permitted transition to done records closure advice/lastClosure. The closure-memory-pending timestamp warning is advisory and does not certify content quality. Do not invent closure dates for historic tasks. An audit that proposes tracker corrections leaves the tracker untouched.

## Running tracker tasks in fresh sessions

`scripts/run-ready-tasks.ps1` runs the ready autonomous tasks of one repository's tracker one after the other, each in a new agent session (`claude -p`, prompt on standard input). You start it yourself: it is not a scheduler or monitor, and it runs nothing by default.

~~~powershell
# Preview only: lists the tasks that would run and the prompt of each session; changes nothing.
pwsh -NoProfile -File scripts/run-ready-tasks.ps1

# Run the next task of this checkout (use -MaxTasks 0 for no limit, default 3).
pwsh -NoProfile -File scripts/run-ready-tasks.ps1 -MaxTasks 1 -Run > .runtime/run-result.json

# Another repository: point the runner at its checkout (its own dossier and tracker are resolved from its Git identity).
pwsh -NoProfile -File scripts/run-ready-tasks.ps1 -CheckoutPath C:/Projects/MyProduct -MaxTasks 1 -Run
~~~

**One script per repository.** The runner handles one repository only. Each managed repository carries its own thin launcher, `.secondbrain/run-tasks.ps1`, which holds no logic: it finds SecondBrain through the `SECONDBRAIN_HOME` environment variable and runs the runner for that checkout alone.

~~~powershell
# From SecondBrain: preview, then install the launcher where absent (new files only; nothing is staged or committed).
pwsh -NoProfile -File scripts/install-task-launcher.ps1
pwsh -NoProfile -File scripts/install-task-launcher.ps1 -Apply [-Repository github.com/owner/product]

# From a repository: preview, then run its next task.
pwsh -NoProfile -File .secondbrain/run-tasks.ps1
pwsh -NoProfile -File .secondbrain/run-tasks.ps1 -MaxTasks 1 -Run
~~~

The installer never overwrites a different existing file (it reports it as `different`), skips SecondBrain itself and writes no personal path. The launcher files are untracked and exist only on the workstation where the installer ran. Committing one in a product repository is a separate, authorized step and needs that product's SEC07 gate to be ready (see [publication](#publication)); a product with unreviewed historic findings cannot publish it.

**All repositories.** There is no single command for all repositories: loop over the launchers, one repository at a time. The loop below is a suggestion that has not been run on several repositories. It does not stop at quota exhaustion (each launcher stops only after its own three consecutive failures), so keep `-MaxTasks` low.

~~~powershell
Get-ChildItem C:/Projects -Directory |
  Where-Object { Test-Path "$($_.FullName)/.secondbrain/run-tasks.ps1" } |
  ForEach-Object { pwsh -NoProfile -File "$($_.FullName)/.secondbrain/run-tasks.ps1" -MaxTasks 1 -Run }
~~~

SecondBrain has no launcher: use `scripts/run-ready-tasks.ps1` there. Tasks in the `coordinamento-prodotti` stream are never selected, so a product may have nothing runnable; the preview shows what would start.

**Read perimeter in code.** The runner starts each agent with `SECONDBRAIN_RUNNER_REPOSITORY` (the task repository) and `SECONDBRAIN_RUNNER_READS` (the task's `readRepositories` allowlist, `;`-separated). With these variables set, `knowledge.ps1` and the MCP tools refuse `-All`, `-AllDossiers`, `all=true` and `allDossiers=true`; they read another repository (through `-Repository`, `-CheckoutPath` or `-Dossier`) only when it is in the allowlist, and they write only to the task repository. An unresolvable search scope falls back to the task repository instead of all areas. Sessions you start yourself do not have the variables and keep the global views. The check is a guard against mistakes, not a sandbox: a process that clears the variables is no longer restricted. The test entry point clears them for its synthetic fixtures. Covered by the `runner` group on fixtures; not yet observed with a real agent and its MCP server.

**Unattended start.** The runner is started by you or by a scheduler you configure; nothing is installed for it. With Windows Task Scheduler, run `pwsh -NoProfile -File <SecondBrain>\scripts\run-ready-tasks.ps1 -MaxTasks 0 -Run` as your own user, with `claude` and `SECONDBRAIN_HOME` available to that user. This setup is not tested here, and the computer must not sleep during the run. Agents have no sandbox: after each run check `git status` and the reports. A coding assistant session may refuse to start such unattended agents, so start it yourself or from the scheduler.

**Progress.** The console shows the tracker being read, the number of runnable tasks, `[n/total]` when a task starts and ends (exit code, status change, seconds), a heartbeat every minute while an agent works, and a final summary. Progress lines go to standard error; standard output carries only the final JSON, so `> file` keeps the console readable and the file clean (it stays empty until the run ends).

**Selection.** Only `todo` tasks with `execution=autonomous` outside the `qualifica-finale`, `intervento-su-richiesta` and `coordinamento-prodotti` streams and not waiting on a person. Order is priority, then number. When the checkout is not the SecondBrain checkout (for example through the launcher), the agent starts inside it and its prompt names the absolute SecondBrain tools to use. A checkout with no active dossier is reported in `skipped`; so is every ready task left out, as `{repository,id,seq,reason}` with the reason `stream:<name>`, `execution:<mode>`, `awaiting:<value>`, `status:<value>`, `requires:computer-use` (the task declares `extensions.requires` with `computer-use`, which needs an attended session: `claude -p` cannot approve apps; set it with `knowledge.ps1 -UpdateTaskId <id> -Requires computer-use`, `-NewTask ... -Requires computer-use` or the `requires` field of the MCP write tools; an empty value clears it) or `max-tasks` (cut by `-MaxTasks`).

**Computer use without a person.** `scripts/computer-use.ps1 -Table` prints the capability table per IDE: Claude Code is interactive-only (`claude -p` cannot approve apps), Codex on Windows can pre-approve apps with `[computer_use.windows] always_allowed_app_ids` (documented in the Codex configuration reference, not verified here with `codex exec`), Cursor, Antigravity and Copilot expose only MCP tools, Windsurf documents nothing. `computer-use.ps1 -CodexApps -AppId <id>[,<id>]` previews adding apps to the Codex `config.toml` (it only adds, refuses ambiguous or multi-line forms and writes nothing); `-Apply -PreviewSha256 <hash>` writes it with a verified backup. The runner preflight follows the table: tasks with `requires:computer-use` run only when the agent has a documented opt-in and the setting is present; the preview reports it as `computerUse`.

**Safety.** The prompt forbids commit, push, publication, deletion, SYS05 and other tasks, and the agent is started with `--disallowedTools` for `git commit`, `git push`, `git tag`, `git reset`, `git clean`, `rm` and `Remove-Item`. The agent is allowed `Bash`, `Read`, `Edit`, `Write`, `Grep`, `Glob` and `Skill` (`--allowedTools`); the last three only read or consult. These are not a sandbox: the agent can still edit files and write the dossier through its own coordinated session, so review `git status` and the reports afterwards. The script never writes the tracker.

**Results.** Each task leaves a closed `report` work folder (`agent-output.json`, `agent-error.txt`, `report.json`) under the workstation runtime. A negative exit code is reported as `crashed` and an empty answer as `no-output`, never as `finished`. The run stops on quota exhaustion (`stopReason: quota`), after three consecutive failures (`failures`), or when `-TimeoutMinutes` (default 30) kills an agent (`timeout`). Exit code 1 means at least one task did not end cleanly.

**Verification and limits.** Selection, stop conditions, progress, the launcher and the installer are verified on synthetic fixtures with a fake agent (`test-secondbrain.ps1 -Only runner`, included in Full), which never touches the real trackers. A real agent has been run on single tasks only; behaviour at the weekly quota limit with a real agent has not been observed.

## Publication

~~~powershell
pwsh -NoProfile -File scripts/check-distribution.ps1
pwsh -NoProfile -File scripts/publication.ps1 -RepositoryPath C:/Projects/MyProduct
~~~

Distribution checks the Git public boundary, not general working-tree cleanliness. SEC07 separately examines working tree, index and relevant history, with findings/incomplete coverage. Commit, push, tags and releases remain separately authorized.

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Requested operation completed without its reported blocking findings |
| 1 | Attention, conflicts, missing qualification or bounded incomplete result |
| 2 | Operational/configuration error or incomplete discovery |
| 3 | Writer coordination timeout |
| 4 | Access denied during a write; core.write.denied |

Inspect command-specific JSON. A destination write can precede failed result recording; check hashes/journal before retry.

Trace stop events are fail-open and require current-turn persistence permission. trace.event.lost means no event was saved. Missing turns are not reconstructed.

## Reference map

| Topic | Guide |
|---|---|
| Installation/bindings | [Portable brain](portable-brain.md) |
| Shared-host limits | [Shared brain](shared-brain.md) |
| Workspaces, retained runs, loading | [Runtime](runtime-maintenance.md) |
| Side effects/backups | [Safe writes](safety-backups.md) |
| Cleanup/interrupted writes | [Recovery](recovery.md) |
| Dossier and runtime layout | [Tree](tree.md) |
| Task authority/import/history | [Trackers](trackers.md) |
| Optional dossier write roots | [Sandbox roots](sandbox-roots.md) |
| IDE/account qualification | [Adapters](adapters.md) |
| Reviewed dossier writes | [MCP writes](mcp-writes.md) |
| Team activity register | [Activity register](activity-register.md) |
| Pairing/local stdio | [MCP](mcp-setup.md) |
| Catalog/common instructions | [Customization](customizing-prompts-and-directives.md) |
| Source applicability | [Sources](authoritative-sources.md) |
| Explicit remote acquisition | [GitHub audit](external-audit.md) |
| Sessions/deferred writes | [Access](access.md), [queue](pending-writes.md) |
| Per-turn collection | [Memory cycle](memory-cycle.md) |

Fixture success, file alignment and observed live loading are different evidence. Product checks belong to product agents.
