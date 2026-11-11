# Portable workstation setup

[Retained Italian source; use this English page for current behavior](portable-brain.it.md)

SecondBrain resolves its root from the running checkout and optional user-local SECONDBRAIN_HOME. It does not require a hard-coded personal path, silently install prerequisites or install a background monitor.

<a id="configurazione-e-prerequisiti"></a>

## Prerequisites and discovery

Use Windows, PowerShell 7.5+ and Git 2.42+. Inspect the actual version with pwsh and git before activation. Source approval hashes in direttive/approved.json must match the approved text before distribution.

~~~powershell
pwsh -NoProfile -File scripts/secondbrain.ps1 -Setup -Roots C:/Projects -Interactive
~~~

Interactive Setup performs preflight, discovery and preview before confirmation and application. Discovery requires explicit roots (`-Roots`): scanning all volumes is refused, and the saved discovery record keeps only the repositories you selected. Only selected repositories are bound; everything else stays unmanaged and unlisted. Known system and build trees are excluded and coverage and errors are reported. Metadata discovery leaves authentication stores alone. For team activation and workstation storage, see the [shared-root procedure](shared-brain.md). To enroll a single repository use `-AddRepo <path> [-Customer <name>] [-ApplyAdd]` (preview by default): it records identity, path and customer in the Git-ignored `config/local/allowlist.json` and activates the repository. When the allowlist exists, discovery neither reads nor lists repositories outside it. Setup no longer has `-All`.

Discover can save a runtime report; MaxDirectories/ResumePath support bounded resumable discovery. New checkouts are not managed until selected. Raw discovery contains host paths and must not be published.

## Selection and activation

| Option | Purpose |
|---|---|
| Roots / MaxDirectories | Bound discovery |
| Select / All | Select confirmed repository candidates |
| Ides / AllIdes | Select confirmed client integrations |
| ApproveExistingBlocks | Record review of differing existing managed blocks |
| Yes | Record noninteractive confirmation already obtained from the user |
| Apply | Perform the confirmed selection instead of preview |
| RegisterEnvironment / NoRegisterEnvironment | Explicitly control user-root registration |
| AndSync | Synchronize on applied setup; disable only deliberately |

Preview the current command and selection; do not treat flags as authorization. Activate SelectionPath is the lower-level path for a confirmed selection with matching report/fingerprint hashes. Outdated selections are refused. Setup Status reads current bindings/integrations/receipt.

New dossiers start with an English context template. Slim startup, compaction and memory-cycle promotion recognize the four required context headings in English or Italian. New dossiers can start with an empty tracker only if no existing authoritative tracker source needs explicit import. Conversion/import and adoption of old memories remain separate reviewed actions. RegisterEnvironment behavior is explicit; restart IDEs to pick up user-environment changes.

## Configuration and identity

Workstation state, inventory, backups and selection receipts live under .runtime/hosts/<id>. repository.json and PARA establish dossier identity; configuration binds actual checkouts. Use ConfigPath for an explicit configuration override, not an example file as authority to manage assets.

Spaces are supported when paths are quoted. Missing SECONDBRAIN_HOME does not prevent direct checkout bootstrap, but the pre-push hook needs a resolvable brain/runtime. Moving a real workstation configuration requires reviewed setup/reconciliation; aliases are not automatically relocation.

A Git push does not synchronize ignored dossiers/runtime. Shared-root access is a separate [deployment/qualification model](shared-brain.md), not a private-Git synchronization mechanism.

## Categorized and incremental search (F7)

`knowledge.ps1 -Search <term>` and the MCP tool `search_knowledge` accept two options that reduce what is returned.

- `-Category` / `category`: `memoria` (`memory.md`), `informazioni` (`context.md`, `tracker.json`, archive, batch reports and any other topic file), `normative` and `policy` (files under `topics/<category>/` or `knowledge/<category>/`), and `prompt` (the `direttive/prompts/*.md` cards, searched only when requested; the README index is excluded). Without a category every dossier category is searched and prompts are left out. Each extract carries its `category`.
- Convention for `normative` and `policy`: notes live in `topics/normative/<slug>.md` and `topics/policy/<slug>.md` of the dossier. A normative note names registry cards, accepted versions and hashes and says where they bear on the product; applicability stays in `authoritative-sources.json` and source text is never copied. A policy note records a project rule with its decision, application and limits. Both are orientation notes, not compliance statements.
- `-PreviousRevision` / `previousRevision`: every search returns `revision`, a hash of query, mode, categories and the hash of each searched file. Passing it back on the same search with `offset` 0 returns `unchanged=true` with no extracts while nothing searched changed, so unchanged content is not repeated; any changed file, query or category gives the full result. Pagination (`offset`, `limit`, `nextOffset`) is unchanged and each match appears once.

Measured on a synthetic dossier (`-Only trace`, 18 checks): the full result is 2,691 characters, `memoria` only 915 and an unchanged answer 302. Real-dossier numbers against the #271 baseline are in the batch report.

## Operations, output and recovery

~~~powershell
pwsh -NoProfile -File scripts/secondbrain.ps1 -Check
pwsh -NoProfile -File scripts/secondbrain.ps1 -Sync
pwsh -NoProfile -File scripts/ide-map.ps1 -Verify
~~~

Check may integrate already-authorized pending dossier writes. Sync writes approved blocks and generated views, reporting dirty/conflicting files rather than forcing them. File alignment, profile/account observation and live loading are separate outcomes.

SecondBrain work folders use work Init with category, slug, manifest and session. Product agents keep build output, caches, temporary files, fixtures and evidence in Git-ignored local folders of the product checkout. The product agent verifies any tool-specific paths. Preserve test runs and recovery records.

Slim defaults to 50,000 characters for first load and explicitly selected tasks; Full has no default budget. Search defaults to 20 matches/10,000 characters unless overridden. Compact previews a candidate; Apply needs review/confirmation and preserves originals by hash.

MCP is optional and exposes eleven tools through stdio, including reviewed write preview and submission; see [MCP writes](mcp-writes.md). Use Pair preview before Apply; default startup/reads may process pending writes. For strict read-only knowledge use NoRecovery. Publication, source collection, task import and memory-cycle permission each retain their own contracts.

See [safe writes](safety-backups.md), [MCP](mcp-setup.md), [trackers](trackers.md), [runtime](runtime-maintenance.md).

## Project isolation

Each managed repository has its own dossier in `01-projects/<name>--<hash>/` (kind project with `repository.json`, plus `specs/`, `material/` and `data/` for the material to implement in that repository). Only `03-resources/` is shared between repositories. By default every read is scoped to the working repository: `-All`, `-AllDossiers`, `all=true` and a search with no resolved repository are refused with a project-isolation error. A brain that really needs the cross-repository views sets `"crossProjectReads": true` in `config/shared.json`.

Dossiers created before this layout live in `02-areas/products/`. Preview the move with `pwsh -NoProfile -File scripts/para.ps1 -MigrateToProjects`, then run it with `-Apply` (optionally `-Only <id or identity>`). Each dossier moves in its own PARA transaction with a backup, keeps its id and files, and gets `specs/`, `material/` and `data/`; bindings and state files are rewritten to the new paths. Take a verified `backup.ps1` archive first.

## New projects and roadmap

- `scripts/secondbrain.ps1 -NewProject <path> [-Remote <url>] [-Customer <name>] [-ApplyNew]` creates a project from scratch in one command. It previews by default; with `-ApplyNew` it creates the folder, runs `git init`, adds the remote, records the repository in `config/local/allowlist.json`, activates it (dossier, tracker seed, managed block), declares the greenfield lifecycle and stores the customer in `repository.json`.
- `scripts/knowledge.ps1 -Roadmap [-Format Markdown|Json] [-Since yyyy-MM-dd]` prints the roadmap of the working repository only: interventions from its tracker history (date from the history folder, task numbers, commit and pull-request mentions) and its git log, with the customer from `repository.json`. Data of other repositories is never read.
