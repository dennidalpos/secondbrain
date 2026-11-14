# Repository instructions: SecondBrain

<!-- secondbrain:repository:begin -->
Common directives applied: revision **1.3** — 2026-11-13. <!-- secondbrain:source global=6B4E10F48D98505DB4ABF6C08AD8BB01229A0D33FF844A2C91781D63F291B480 workstation=BD2E210B49B3B77000F570E6F6191DC694798722B50900E6C3864E3DBDD78FF7 -->
## SecondBrain

Repository knowledge lives in the SecondBrain dossier; code, guides, and publishable assets stay here.

- Load the slim startup with the SecondBrain checkout's scripts/knowledge.ps1 -Startup or MCP get_startup_context, and follow its references for detail. If the root is unreachable, report the dossier as unavailable.
- Write only to this repository's dossier `01-projects/<repo>/`, only through SecondBrain scripts or MCP write tools. Work folders come from scripts/work.ps1 -Init; sessions, retention, and cleanup rules load from `sb prompt`.
- Commits, pushes, deletions, and publication require specific authorization.
<!-- secondbrain:repository:end -->

## Setup
- PowerShell 7.5+ and Git on Windows; nothing to install. Scripts are in `scripts/`, directive and prompt texts in `direttive/`, documentation in `docs/`.
- The clone is the SecondBrain root: `.runtime/` (Git-ignored) holds the workstation's configuration, sessions, fixtures and backups.

## Checks
- Quick and pure: `pwsh -NoProfile -File scripts/test-secondbrain.ps1 -Quick`; default: no options; full: `-Full`; one group: `-Only quick|workflows|trackers|audit2|trace|concurrency|shared|pending|sources|external-audit|git-environment|runtime|prompts|tracker-audit|mcp-writes|runner|ide|agents|lint|cleanclone|orchestrator-e2e` (`-Full` runs the extra suites, `tracker-audit` included, in parallel as separate processes; `-Sequential` runs them one at a time).
- Desktop app `app/orchestrator` (Tauri 2): `npm ci` and `npm run build` (TypeScript check and build), `cargo test --manifest-path src-tauri/Cargo.toml`; guide in `docs/orchestratore.md`.
- Prompts: `scripts/build-prompts.ps1` regenerates the indexes from the catalog and the cards; `-Check` reports drift. Never edit the `README*.md` files in `direttive/prompts/` by hand.
- `scripts/secondbrain.ps1 -Check` and `scripts/ide-map.ps1 -Verify` check directives, IDEs and dossiers.
- Test fixtures go in `.runtime/hosts/<host>/repos/tests-<hash>/fixture/`; ACL failures in `concurrency` depend on the environment, not on this repository.

## Code style
- PowerShell with `Set-StrictMode`; messages only through keys in `Add-SBMessages` (no `throw` or `Write-Host` with literal text); writes only with `Write-SBFile` and verified backups.
- New product text is English: messages, help, UI, docs, prompts and diagnostics. Existing `it` message entries, Italian cards and `*.it.md` pages are removed only through the English-only tasks (#580–#586) and the reviewed removal manifest; do not add new Italian text unless a check still requires it.
- Prompt assets follow `docs/riferimento/asset-contracts.md`: cards, workflows, agent definitions and user decisions keep immutable IDs; codes and keys are display names, renamed only with a catalog version and an alias and never reused. Scripts, the app, config and directives refer to cards by ID or role, never by code. Add or change cards with the catalog's card procedure (`sb prompt`).
- Common directives change only through a proposal in `direttive/proposals/`, `scripts/approve-revision.ps1 -Preview` and explicit approval; managed blocks change only through their generators. `VERSION` and `CHANGELOG.md` follow the version rule.

## Security
- No secrets, personal paths or account data in the repository; publication scans (`scripts/publication.ps1` or MCP `check_publication`) come before every push.
- `.runtime` cleanups and migrations (`scripts/cleanup.ps1 -Migrate`, `-Regenerable`) preview by default and need `-Apply` with an explicit `-Authorization`.

## Pull requests
- One change per purpose, relevant tests run and reported, documentation updated; no commit or push without a specific request.
