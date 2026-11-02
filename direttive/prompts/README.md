# Catalogo prompt

Indice generato da catalog.json e schede Markdown con scripts/build-prompts.ps1. Non modificare questo indice a mano.

Nella chat: `sb prompt`, `sb prompt list`, `sb prompt maintenance`, `sb prompt ambito test`, `sb prompt mostra TST04`, `sb prompt TST04: descrizione`. Ogni prompt ha un ID immutabile (`pmt-` e 8 esadecimali) e uno o più alias (codice incluso): ID e alias risolvono allo stesso prompt.

Questo indice elenca i prompt generici (pacchetto core). I prompt di manutenzione di SecondBrain (memoria, dossier, postazione) sono separati: `sb prompt maintenance`.

La CLI compone testo; il task viene svolto dall'agente nei permessi e nella modalità della sessione. [Come usare e modificare i prompt](../../docs/prompt.md).

```text
Catalogo prompt
Legenda: 🔭 legge · ✅ verifica · 🔥 scrive · ⛔ distruttivo/irreversibile

UNDERSTANDING AND RESEARCH
🔭 COM01 | Explore the repository and identify main components and commands.
  • ID: pmt-a709a792
  • Scope: repo | Modalità: read
  • Serve: read access to the repository and a shell
  • Esempio: explore the structure and main modules

🔭 COM02 | Trace a flow and its dependencies through the code.
  • ID: pmt-e0fd59da
  • Scope: repo/area | Modalità: read
  • Serve: entry point or scenario to trace
  • Esempio: trace the authentication and session flow

🔭 COM03 | Find official sources that fit the technical problem.
  • ID: pmt-25c97d58
  • Scope: repo/area | Modalità: read
  • Serve: technical problem or library with its version
  • Esempio: find the official documentation for the runtime version in use

🔭 COM04 | Assess the impact, risks and dependencies of a change.
  • ID: pmt-179b9acc
  • Scope: repo | Modalità: read
  • Serve: proposed change or defect to fix
  • Esempio: assess the impact of isolating runtime logs

🔭 COM05 | Analyze logs and incidents to find the root cause, without changing code.
  • ID: pmt-1839927a
  • Scope: repo/area | Modalità: read
  • Serve: logs, errors or symptoms of the incident, time window and read access
  • Esempio: find the root cause of yesterday's errors in the logs


REQUIREMENTS AND DESIGN
🔭 PRG01 | Turn a request into requirements and acceptance criteria.
  • ID: pmt-98071f85
  • Scope: repo | Modalità: read
  • Serve: user request and existing documentation
  • Esempio: define acceptance criteria for full-text search

🔭 PRG02 | Compare architectural options and justify a decision.
  • ID: pmt-3e0ad55e
  • Scope: repo/area | Modalità: read
  • Serve: alternatives to evaluate and project constraints
  • Esempio: compare SQLite and JSON for local persistence

🔭 PRG03 | Design API contracts, data models and compatibility.
  • ID: pmt-83764c0d
  • Scope: repo/area | Modalità: read
  • Serve: requirements or current schema with its version
  • Esempio: design the JSON schema and API contracts for the task list

🔭 PRG04 | Prepare a phased plan with dependencies and checks.
  • ID: pmt-8541aed1
  • Scope: repo/area | Modalità: read
  • Serve: agreed requirements and scope of the work
  • Esempio: plan the migration in three atomic releases

🔥 PRG05 | Scaffold new modules with structure, configuration and tests.
  • ID: pmt-884419a5
  • Scope: repo/area | Modalità: write
  • Serve: agreed architectural scope and dependencies
  • Esempio: define the scaffolding of the new module

🔭 PRG06 | Plan a phased architectural refactoring with checks and rollback.
  • ID: pmt-3731bb7d
  • Scope: repo/area | Modalità: read
  • Serve: module to reorganize, existing tests and invariants to preserve
  • Esempio: plan the refactoring of the synchronization module


DEVELOPMENT AND MODERNIZATION
🔥 DEV01 | Implement a feature with relevant checks.
  • ID: pmt-83df1685
  • Scope: repo/area/file | Modalità: write
  • Serve: verified requirements or acceptance criteria
  • Esempio: implement the export command with hash validation

🔥 DEV02 | Reproduce a defect and fix its cause.
  • ID: pmt-25ac264e
  • Scope: repo/area/file | Modalità: write
  • Serve: report or expected and actual behavior
  • Esempio: fix the parsing error for paths containing spaces

🔥 DEV03 | Refactor code preserving contracts: targeted, phased or periodic.
  • ID: pmt-2b07a693
  • Scope: repo/area | Modalità: write
  • Serve: code to improve, existing tests and scope (targeted, phased or periodic)
  • Esempio: extract transaction handling into its own module

🔥 DEV04 | Update dependencies checking compatibility and regressions.
  • ID: pmt-e2405036
  • Scope: repo/area/file | Modalità: write
  • Serve: dependency manifests and lock files
  • Esempio: update the JSON serialization package

🔥 DEV05 | Migrate code or a framework to a defined target.
  • ID: pmt-22863973
  • Scope: repo/area | Modalità: write
  • Serve: source and target versions with release notes
  • Esempio: migrate the scripts from the old runtime version to the current one

🔥 DEV06 | Configure and run linters, formatters and static analysis.
  • ID: pmt-f3082c1b
  • Scope: repo/area/file | Modalità: write
  • Serve: linter configuration and analysis scope
  • Esempio: configure the linter and run static analysis

🔭 DEV07 | Triage and reproduce an issue before fixing it, without changing code.
  • ID: pmt-9bd26aad
  • Scope: repo/area | Modalità: read
  • Serve: issue text, environment and read access to the code
  • Esempio: triage and reproduce the path parsing issue

🔭 DEV08 | Review readability, consistency and maintainability without changing code.
  • ID: pmt-b16674bd
  • Scope: repo/area/file | Modalità: read
  • Serve: code to review, repository conventions and existing tests
  • Esempio: review readability and maintainability of the sync module


TESTING AND VERIFICATION
🔥 TST01 | Add unit and integration tests for the relevant risks.
  • ID: pmt-08bff671
  • Scope: repo/area | Modalità: write
  • Serve: test harness and the behavior to verify
  • Esempio: add boundary tests for the budget calculation

🔥 TST02 | Cover user journeys with end-to-end tests.
  • ID: pmt-286c3225
  • Scope: repo/area | Modalità: write
  • Serve: test environment and agreed user flows
  • Esempio: create an end-to-end test for the backup and restore cycle

🔥 TST03 | Find and fix flaky or non-deterministic tests.
  • ID: pmt-91021b67
  • Scope: repo/area | Modalità: write
  • Serve: logs of the intermittent failures and the test suite
  • Esempio: fix the instability in the async tests of the suite

🔥 TST04 | Diagnose and fix build and test failures in CI.
  • ID: pmt-bd98736f
  • Scope: repo/area/file | Modalità: write
  • Serve: CI logs and pipeline configuration
  • Esempio: fix the GitHub Actions runner failure on Windows

✅ TST05 | Verify real behavior against the requirements.
  • ID: pmt-ef96dea5
  • Scope: repo | Modalità: verify
  • Serve: acceptance criteria and a working environment
  • Esempio: verify that the output conforms to the specifications

🔥 TST06 | Measure and optimize performance and resources: one bottleneck or many modules.
  • ID: pmt-9de57e24
  • Scope: repo/area | Modalità: write
  • Serve: flow, representative load, environment, metric and threshold
  • Esempio: reduce host discovery time and memory use

🔥 TST07 | Set up a test harness with isolated fixtures and safe cleanup.
  • ID: pmt-37c695fe
  • Scope: repo | Modalità: write
  • Serve: test framework, test scripts and an assigned isolated fixture root
  • Esempio: create isolated on-disk fixtures and validate the automatic cleanup


REVIEW AND SECURITY
🔭 SEC01 | Review changes or code with concrete findings and references.
  • ID: pmt-27896824
  • Scope: repo | Modalità: read
  • Serve: diff, commit or files to analyze
  • Esempio: review the pull request for data leaks

🔭 SEC02 | Analyze threats, trust boundaries and abuse scenarios.
  • ID: pmt-deb7d01a
  • Scope: repo | Modalità: read
  • Serve: architecture and data flows toward the outside
  • Esempio: threat model of the stdio and local file system flows

🔥 SEC03 | Fix vulnerabilities and strengthen the affected defenses.
  • ID: pmt-b4cb6659
  • Scope: repo/area/file | Modalità: write
  • Serve: confirmed vulnerability and code context
  • Esempio: fix path traversal in path resolution

✅ SEC04 | Find exposed credentials and verify input validation.
  • ID: pmt-73fb4547
  • Scope: repo | Modalità: verify
  • Serve: working tree and scanning tools
  • Esempio: run a credentials security audit

✅ SEC05 | Verify personal data isolation and compliance with GDPR and policies.
  • ID: pmt-24189cb6
  • Scope: repo | Modalità: verify
  • Serve: data mapping and compliance policy
  • Esempio: check for personal data and GDPR privacy compliance

🔥 SEC06 | Harden repository configuration, CI, containers and access.
  • ID: pmt-c356eede
  • Scope: repo/area | Modalità: write
  • Serve: configuration, CI workflows, containers and repository settings
  • Esempio: harden the GitHub Actions workflows and containers

✅ SEC07 | Check diff, repository and history for sensitive data before publishing.
  • ID: pmt-058c474f
  • Scope: repo | Modalità: verify
  • Serve: commits, index, working tree and history to publish; destination
  • Esempio: check that it is safe to publish before the push

✅ SEC08 | Check whether sensitive data is still reachable on the GitHub remote.
  • ID: pmt-55186b10
  • Scope: repo | Modalità: verify
  • Serve: read-only access to the GitHub remote and fingerprints or patterns to look for
  • Esempio: check which runs, caches and links are still accessible

⛔ SEC09 | Wipe remote GitHub history and artifacts after a data exposure.
  • ID: pmt-7fc91f08
  • Scope: repo | Modalità: write
  • Serve: explicit request, verified backup and administrative access to the remote
  • Esempio: wipe the remote history, runs and caches after the exposure


AUDIT AND METRICS
🔭 AUD01 | Run a full repository audit with a single report, optionally exported.
  • ID: pmt-ccbf18b8
  • Scope: repo/area | Modalità: read
  • Serve: read access to the repository, its documentation and measurement tools
  • Esempio: full audit of the repository before the release

🔭 AUD02 | Measure the repository with reproducible metrics and find hotspots.
  • ID: pmt-4a9a4b4f
  • Scope: repo/area | Modalità: read
  • Serve: read access to the repository, its Git history and measurement tools
  • Esempio: metrics and hotspots of the repository

🔭 AUD03 | Audit architecture and technical debt not yet tracked.
  • ID: pmt-c692cc23
  • Scope: repo/area | Modalità: read
  • Serve: read access to the code, the backlog and architecture documentation
  • Esempio: audit of architecture and technical debt of the repository

🔭 AUD04 | Audit dependencies: outdated, vulnerable, unused and licenses.
  • ID: pmt-7dc63766
  • Scope: repo/area | Modalità: read
  • Serve: manifests, lock files and access to package registries or dependency advisories
  • Esempio: dependency audit before the upgrade

🔭 AUD05 | Audit performance and find critical paths without changing code.
  • ID: pmt-4efbc54f
  • Scope: repo/area | Modalità: read
  • Serve: representative load scenario and profiling or measurement tools
  • Esempio: find the critical paths for time and memory


INTERFACE AND USER EXPERIENCE
🔭 INT01 | Assess usability, consistency and states of user flows.
  • ID: pmt-33216f62
  • Scope: repo/area | Modalità: read
  • Serve: runnable application and flows to examine
  • Esempio: assess the usability of the setup wizard

🔥 INT02 | Implement an interface following requirements and references.
  • ID: pmt-db55c30d
  • Scope: repo/area | Modalità: write
  • Serve: guidelines or mockups and existing components
  • Esempio: build the synchronization screen

✅ INT03 | Verify accessibility and keyboard and assistive-technology use.
  • ID: pmt-2ea0c993
  • Scope: repo/area | Modalità: verify
  • Serve: working interface and reference standards
  • Esempio: verify ARIA conformance and accessibility

✅ INT04 | Verify internationalization of strings, formats and translations.
  • ID: pmt-805ca095
  • Scope: repo/area | Modalità: verify
  • Serve: interface or messages with supported languages and formats
  • Esempio: verify the strings, formats and translations of the CLI


DATA AND INTEGRATIONS
🔥 DAT01 | Migrate schema and data with verifiable comparison and recovery.
  • ID: pmt-32e3cf59
  • Scope: repo/area | Modalità: write
  • Serve: source schema, target schema and synthetic data
  • Esempio: migrate the schema with an atomic rollback script

🔥 DAT02 | Build imports and transformations that preserve the originals.
  • ID: pmt-3ddd1df9
  • Scope: repo/area | Modalità: write
  • Serve: source files, target model and validation rules
  • Esempio: import the catalog from CSV to JSON preserving the originals

🔥 DAT03 | Integrate API services with error handling and request retries.
  • ID: pmt-6b7b0e8d
  • Scope: repo/area | Modalità: write
  • Serve: API documentation, test credentials and schema
  • Esempio: implement a REST client with exponential backoff and retry


RELEASE AND OPERATIONS
🔥 OPS01 | Prepare and verify distributable packages and artifacts.
  • ID: pmt-a5c78cc6
  • Scope: repo | Modalità: write
  • Serve: build instructions and package requirements
  • Esempio: build a deterministic zip archive and compute its SHA-256

🔥 OPS02 | Configure pipelines, containers and infrastructure as code.
  • ID: pmt-ce00f261
  • Scope: repo | Modalità: write
  • Serve: deployment requirements and target environment
  • Esempio: configure a multi-stage Dockerfile for a reproducible build

🔥 OPS03 | Add logs, metrics and diagnostics useful for the problem.
  • ID: pmt-c2785b9c
  • Scope: repo/area/file | Modalità: write
  • Serve: scenario to monitor and logging standards
  • Esempio: add structured JSON logging

🔥 OPS04 | Prepare release notes and delivery checks.
  • ID: pmt-0618969e
  • Scope: repo | Modalità: write
  • Serve: commits, issues or tasks completed since the previous release
  • Esempio: compile the v1.1 release notes from commits and issues

🔥 OPS05 | Prepare commits and pull requests with verified scope, message and checks.
  • ID: pmt-3e3728b6 | Alias: REP09
  • Scope: repo | Modalità: write
  • Serve: local changes to deliver and an explicit request for a commit or pull request
  • Esempio: prepare the commits and the pull request description

🔥 OPS06 | Prepare a release hotfix and rollback with verification and communication.
  • ID: pmt-b377d5f0
  • Scope: repo | Modalità: write
  • Serve: faulty release, known previous version and criteria for going back
  • Esempio: prepare the hotfix and rollback for release 2.3.1


DOCUMENTATION
🔥 DOC01 | Write guides and READMEs consistent with the real product.
  • ID: pmt-07430e8c | Alias: REP02
  • Scope: repo | Modalità: write
  • Serve: implemented features, verified commands and approved screenshots
  • Esempio: update the guides and add Mermaid flow diagrams

🔥 DOC02 | Document APIs and contracts from the implementation.
  • ID: pmt-6e82e3a9 | Alias: REP03
  • Scope: repo/area | Modalità: write
  • Serve: source code of the contracts and endpoints
  • Esempio: document the parameters and response schemas of the endpoints

🔥 DOC03 | Capture real screenshots and prepare public assets.
  • ID: pmt-75786fd6 | Alias: REP07
  • Scope: repo | Modalità: write
  • Serve: working interface with synthetic data
  • Esempio: capture authentic screenshots from the real interface


REPOSITORY HYGIENE
🔥 REP01 | Complete the next ready task of the open repository.
  • ID: pmt-4cc383ba
  • Scope: repo | Modalità: write
  • Serve: planned task and acceptance criteria
  • Esempio: run the next priority task that can be done autonomously

⛔ REP04 | Remove leftovers and unused code after verification.
  • ID: pmt-40772e6e
  • Scope: repo/area | Modalità: write
  • Serve: proof of no references and green tests
  • Esempio: remove temporary files and orphaned build caches

🔭 REP08 | Inspect the repo and find leftover tasks against the real code.
  • ID: pmt-cc2c5f5a
  • Scope: repo/area | Modalità: read
  • Serve: working tree, recent history and any backlog or notes
  • Esempio: inspect the repo and detect leftover tasks

🔥 REP10 | Align .gitignore and .gitkeep with the real structure and files.
  • ID: pmt-f1df8757
  • Scope: repo | Modalità: write
  • Serve: Git state, exclusion rules and folders to preserve in the repository
  • Esempio: align gitignore and gitkeep before publishing


GOVERNANCE, LICENSING AND COMPLIANCE
✅ GOV01 | Check open source licenses, file compliance and SPDX headers.
  • ID: pmt-313da996
  • Scope: repo | Modalità: verify
  • Serve: source tree and license files
  • Esempio: check the MIT license and that the SPDX headers match

🔥 GOV02 | Scan third-party dependencies and compile the CREDITS register of licenses.
  • ID: pmt-adb9bfc0
  • Scope: repo | Modalità: write
  • Serve: dependency lock files and third-party licenses
  • Esempio: scan third-party dependencies and compile CREDITS.md

```
