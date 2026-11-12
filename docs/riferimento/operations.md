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


**Exit code.** `-Check` exits 1 only when `aligned` is false, and `aligned` depends only on files (`issues`). Environmental findings are listed apart in `environment` and never change the exit code: `ide-write-scope-*`, `ide-loading-unverified`, `ide-context-changed`, `ide-directive-stale`, `account-unverified`, `mcp-consent-unverified`, `authoritative-source` and `compaction-required`. They clear only with a real session receipt, a write-scope probe, a reviewed account, `resources.ps1 -Sync` or SYS05. `ide-map.ps1 -Verify` keeps its own contract (exit 1 when IDEs need alignment; 2 = error, 3 = writer busy, 4 = write denied).
Check never integrates deferred writes (`knowledge.ps1 -FlushPending` does). Asset checks do not apply their corrections. concurrent-writer/pending-transaction warnings mean the observed state may be intermediate.

Sync writes immediately through coordination, backups and hashes. It generates approved managed blocks/local views, preserves unrelated text and reports conflicts. New assets require explicit Setup selection; unapproved source text is not distributed. Neither command schedules monitoring.

Use `-NoRecovery` on knowledge commands and on the MCP server when the session forbids all writes: it refuses writes outright. A filtered Check/Sync with Repository limits coverage to that managed identity; it does not certify other products, IDEs or global instructions.

## Knowledge and closure

Slim selects whole Markdown blocks deterministically, with a first-load default of 25,000 characters. Without explicit TaskIds it includes no task detail. Full and deeper lookups remain available; essential content is not silently discarded.

A permitted transition to done records closure advice/lastClosure. The closure-memory-pending timestamp warning is advisory and does not certify content quality. Do not invent closure dates for historic tasks. An audit that proposes tracker corrections leaves the tracker untouched.

## Running tracker tasks in fresh sessions

`scripts/run-ready-tasks.ps1` runs the ready autonomous tasks of one repository's tracker one after the other, each in a new agent session (`claude -p` by default, `codex exec` or `gemini` with `-Provider`; prompt on standard input). You start it yourself: it is not a scheduler, and it runs nothing by default. `sb runner` (`scripts/runner.ps1`) opens the [desktop orchestrator](../orchestratore.md) on the current repository and falls back to this CLI when the window cannot start.

**Agent CLIs, model and effort.** `-Provider claude|codex|gemini` picks the CLI; `-Model` and `-Effort` are checked against `scripts/agents.ps1 -Probe` before anything runs, and an unknown model stops with exit 2 unless `-AllowCustomModel` is given. The probe reads `--version` and `--help` of the installed CLI, then its configuration (`~/.claude/settings.json`; `config.toml` and `models_cache.json` under `CODEX_HOME`; `~/.gemini/settings.json`), while the fallback table `config/agent-models.json` (local additions in `.runtime/hosts/<host>/agent-models.local.json`) only validates a typed model: it does not fill the lists, and an agent that is not installed exposes no models. Every model and level carries its source. The executable is searched on the process `PATH`, the user and machine `PATH` read again from the registry (Windows), known folders (WinGet Links, WindowsApps, npm, pnpm, Volta, scoop, bun; Homebrew, snap, nvm, fnm and `~/.local/bin` on macOS and Linux) and, for Codex installed from the Microsoft Store, the `OpenAI.Codex` package. The probe reports `status` (`ready`, `not-found`, `not-responding`) and `origin` (`path`, `search`, `package`) and probes the three providers in parallel. Observed on this workstation: Claude Code 2.1.318 lists its effort levels and model aliases in `--help`; Codex lists models and per-model levels in `models_cache.json`. Gemini CLI exposes no effort level and its fallback model names are not verified. Flags missing from the installed `--help` are left out and reported. The permission profile is fixed: Claude `acceptEdits` with git commit/push/tag/reset/clean and deletion denied, Codex `--sandbox workspace-write`, Gemini `--approval-mode auto_edit`; the Codex and Gemini commands have not been run with a real CLI here. `-TaskIds` runs only the named tasks in the given order (others reported as `not-queued`, unknown ones as `not-ready`), `-Events` writes progress as JSON lines on standard error, and `-StopFile <path>` ends the run before the next task. The [desktop orchestrator](../orchestratore.md) uses these options.

~~~powershell
# Preview only: lists the tasks that would run and the prompt of each session; changes nothing.
pwsh -NoProfile -File scripts/run-ready-tasks.ps1

# Run the next task of this checkout (use -MaxTasks 0 for no limit, default 3) with the CLI's own model and effort.
pwsh -NoProfile -File scripts/run-ready-tasks.ps1 -MaxTasks 1 -Run -UseCliDefault > .runtime/run-result.json

# Another repository: point the runner at its checkout (its own dossier and tracker are resolved from its Git identity).
pwsh -NoProfile -File scripts/run-ready-tasks.ps1 -CheckoutPath C:/Projects/MyProduct -MaxTasks 1 -Run -Model <id> -Effort <level>
~~~

**One script per repository.** The runner handles one repository only. Each managed repository carries its own thin launcher, `.secondbrain/run-tasks.ps1`, which holds no logic: it finds SecondBrain through the `SECONDBRAIN_HOME` environment variable and runs the runner for that checkout alone.

~~~powershell
# From SecondBrain: preview, then install the launcher where absent (new files only; nothing is staged or committed).
pwsh -NoProfile -File scripts/install-task-launcher.ps1
pwsh -NoProfile -File scripts/install-task-launcher.ps1 -Apply [-Repository github.com/owner/product]

# From a repository: preview, then run its next task (-Provider, -Model, -Effort, -UseCliDefault and -AllowCustomModel reach the runner unchanged).
pwsh -NoProfile -File .secondbrain/run-tasks.ps1
pwsh -NoProfile -File .secondbrain/run-tasks.ps1 -MaxTasks 1 -Run -UseCliDefault
~~~

The installer never overwrites a different existing file (it reports it as `different`), skips SecondBrain itself and writes no personal path. The launcher files are untracked and exist only on the workstation where the installer ran. Committing one in a product repository is a separate, authorized step and needs that product's SEC07 gate to be ready (see [publication](#publication)); a product with unreviewed historic findings cannot publish it.

**All repositories.** There is no single command for all repositories: loop over the launchers, one repository at a time. The loop below is a suggestion that has not been run on several repositories. The loop itself does not stop at quota exhaustion: each launcher reads the quota first and stops at once when it is exhausted, or after its own three consecutive failures, so keep `-MaxTasks` low.

~~~powershell
Get-ChildItem C:/Projects -Directory |
  Where-Object { Test-Path "$($_.FullName)/.secondbrain/run-tasks.ps1" } |
  ForEach-Object { pwsh -NoProfile -File "$($_.FullName)/.secondbrain/run-tasks.ps1" -MaxTasks 1 -Run -UseCliDefault }
~~~

A launcher installed from an earlier template, never edited, is reported as `outdated` and replaced by `install-task-launcher.ps1 -Apply` with a backup; an edited one stays `different` and is not touched. SecondBrain has no launcher: use `scripts/run-ready-tasks.ps1` there. Tasks in the `coordinamento-prodotti` stream are never selected, so a product may have nothing runnable; the preview shows what would start.

**Read perimeter in code.** The runner starts each agent with `SECONDBRAIN_RUNNER_REPOSITORY` (the task repository). With these variables set, `knowledge.ps1` and the MCP tools refuse `-All`, `-AllDossiers`, `all=true` and `allDossiers=true`; they refuse any other repository (through `-Repository`, `-CheckoutPath` or `-Dossier`) for reads and writes. An unresolvable search scope falls back to the task repository instead of all areas. Project isolation (no switch) refuses the global views for everyone. The check is a guard against mistakes, not a sandbox: a process that clears the variables is no longer restricted. The test entry point clears them for its synthetic fixtures. Covered by the `runner` group on fixtures; not yet observed with a real agent and its MCP server.

**Unattended start.** The runner is started by you or by a scheduler you configure; nothing is installed for it. With Windows Task Scheduler, run `pwsh -NoProfile -File <SecondBrain>\scripts\run-ready-tasks.ps1 -MaxTasks 0 -Run -UseCliDefault` as your own user, with `claude` and `SECONDBRAIN_HOME` available to that user. This setup is not tested here, and the computer must not sleep during the run. Agents have no sandbox: after each run check `git status` and the reports. A coding assistant session may refuse to start such unattended agents, so start it yourself or from the scheduler.

**Progress.** The console shows the tracker being read, the number of runnable tasks, `[n/total]` when a task starts and ends (exit code, status change, seconds), the agent's steps as they arrive, and a final summary. Progress lines go to standard error; standard output carries only the final JSON, so `> file` keeps the console readable and the file clean (it stays empty until the run ends).

**Monitoring.** The agent writes events: Claude Code with `--output-format stream-json --verbose`, Codex with `exec --json`, Gemini with `stream-json` when its `--help` offers it (otherwise plain text, and the steps only show at the end). The runner reads the output line by line, saves it live to `agent-output.jsonl` in the task folder and derives compact `agent` events from it (`start`, `tool`, `text`, `result`, `error`; for tools only the name and the path or command, never file contents). With `-Run` each run opens a work folder `report/<date>-runner-run-<time>-<pid>` with `status.json` and `events.jsonl`. `status.json` holds the phase (`probe`, `init`, `agent`, `flush`, `close`), the process ID and start time, the current task, the last runner and agent events, counts and the stop file (by default `stop.flag` in the folder). It is updated on every event and at least every 15 seconds, also in phases without an agent. After `-StallMinutes` (default 5) without a signal from the agent the runner emits `stalled`, once per silence, and stops nothing: the timeout remains the only forced stop. A second `-Run` on the same repository exits 2 while the first process is alive; a run whose process died without closing is reported as `orphaned`.

`scripts/runner-status.ps1 [-CheckoutPath <checkout>]` reports the active or last run with the verdict `working`, `stalled`, `finished`, `orphaned` or `none`, the phase, the task and the age of the last signal. `-Follow` follows the events until the end; `-Stop` writes the stop file, so the run ends after the current task (exit 2 when no run is active). The MCP tool `get_runner_status` returns the same report, read-only.

**Selection.** Only `todo` tasks with `execution=autonomous` outside the `qualifica-finale`, `intervento-su-richiesta` and `coordinamento-prodotti` streams and not waiting on a person. Order is priority, then number. When the checkout is not the SecondBrain checkout (for example through the launcher), the agent starts inside it and its prompt names the absolute SecondBrain tools to use. A checkout with no active dossier is reported in `skipped`; so is every ready task left out, as `{repository,id,seq,reason}` with the reason `stream:<name>`, `execution:<mode>`, `awaiting:<value>`, `status:<value>`, `requires:computer-use` (the task declares `extensions.requires` with `computer-use`, which needs an attended session: `claude -p` cannot approve apps; set it with `knowledge.ps1 -UpdateTaskId <id> -Requires computer-use`, `-NewTask ... -Requires computer-use` or the `requires` field of the MCP write tools; an empty value clears it) or `max-tasks` (cut by `-MaxTasks`).

**Computer use without a person.** `scripts/computer-use.ps1 -Table` prints the capability table per IDE: Claude Code is interactive-only (`claude -p` cannot approve apps), Codex on Windows can pre-approve apps with `[computer_use.windows] always_allowed_app_ids` (documented in the Codex configuration reference, not verified here with `codex exec`), Cursor, Antigravity and Copilot expose only MCP tools, Windsurf documents nothing. `computer-use.ps1 -CodexApps -AppId <id>[,<id>]` previews adding apps to the Codex `config.toml` (it only adds, refuses ambiguous or multi-line forms and writes nothing); `-Apply -PreviewSha256 <hash>` writes it with a verified backup. The runner preflight follows the table: tasks with `requires:computer-use` run only when the agent has a documented opt-in and the setting is present; the preview reports it as `computerUse`. `-CodexApps -AppId` refuses IDs with spaces or quotes, prints the exact apply command in the preview, and `-Apply` without `-PreviewSha256` reports the hash as missing; without arguments the script lists its modes and exits 2.

**Safety.** The prompt forbids commit, push, publication, deletion, SYS05 and other tasks, and the agent is started with `--disallowedTools` for `git commit`, `git push`, `git tag`, `git reset`, `git clean`, `rm` and `Remove-Item`. The agent is allowed `Bash`, `Read`, `Edit`, `Write`, `Grep`, `Glob` and `Skill` (`--allowedTools`); the last three only read or consult. These are not a sandbox: the agent can still edit files and write the dossier through its own coordinated session, so review `git status` and the reports afterwards. The script writes the tracker in one case only: a task that is still `todo` after its session moves to `execution=user_required` (the agent's reason stays), so the next run does not hit the same limit again.

**Results.** Each task leaves a closed `report` work folder (`agent-output.json`, `agent-error.txt`, `report.json`) under the workstation runtime. A negative exit code is reported as `crashed` and an empty answer as `no-output`, never as `finished`. The run stops on quota exhaustion (`stopReason: quota`), after three consecutive failures (`failures`), or when `-TimeoutMinutes` (default 30) kills an agent (`timeout`). Exit code 1 means at least one task did not end cleanly.

**Model, effort and quota.** `-Run` needs an explicit choice read from the probe at that moment: `-Model` and `-Effort` (when the CLI accepts them) or `-UseCliDefault`; otherwise it exits 2 and lists the models, efforts and CLI defaults it just read. The quota is read before the run and before every task, never reused: Codex from its session files (`rate_limits`, 5-hour and weekly windows), Claude Code and Gemini CLI from the last limit an agent reported on this workstation (a `rate_limit_event` or a quota stop). `exhausted` with a future reset stops before starting an agent; `unknown` proceeds until the agent itself reports the limit. The limit is recognized only in the agent's final error envelope with each provider's own texts (Claude Code "You've hit your limit", "You're out of usage credits", `usage_limit_reached`; Codex "You've hit your usage limit"; Gemini daily `RESOURCE_EXHAUSTED`); quota words in the agent's text, tool output or the stderr of a killed agent are ignored. A transient rate limit (429, `rate_limit_error`, Gemini per-minute quota) is `throttled`: the runner waits 30 seconds and goes on.

**Resume.** A quota stop writes `resume.json` in the run folder (interrupted task, remaining queue, matched limit line, reset when known, Git state) and puts the interrupted task back to todo when the agent left it in progress. `run-ready-tasks.ps1 -Resume latest` (or the run folder name) runs that queue again, interrupted task first with a note that tells the agent to read the previous report and continue; it reads the quota and needs the model choice again. MEM07 covers the same resume from another account or a manual chat session.

**Verification and limits.** Selection, stop conditions, progress, event streaming, `status.json`, stall detection, the per-repository lock, `runner-status.ps1`, the launcher, the installer and the `runner.ps1` dispatcher are verified on synthetic fixtures with a fake agent (`test-secondbrain.ps1 -Only runner`, included in Full), which never touches the real trackers. A real agent has been run on single tasks only; behaviour at the weekly quota limit with a real agent has not been observed. The limit texts come from the installed Claude Code 2.1 binary and from the Codex session files of this workstation; the Gemini texts are not verified on a real CLI.

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
| 5 | `knowledge.ps1` write accepted but not applied yet (deferred or conflict); 0 always means applied. Run `knowledge.ps1 -FlushPending` or `-PendingWrites` |

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
