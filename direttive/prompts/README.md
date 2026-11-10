# Prompt catalog

Index generated from catalog.json and the Markdown cards with scripts/build-prompts.ps1. Do not edit this index by hand.

In the chat: `sb prompt`, `sb prompt list`, `sb prompt ambito test`, `sb prompt mostra TST04`, `sb prompt TST04: description`. Every prompt has an immutable ID (`pmt-` and 8 hex digits) and a stable code that is never reused: ID and code resolve to the same prompt.

The CLI composes text; the task is carried out by the agent within the permissions and mode of the session. [How to use and edit the prompts](../../docs/prompt.md). Language: [English](README.md) · [Italiano](README.it.md).

```text
Prompt catalog
Legend: 🔭 reads · ✅ verifies · 🔥 writes · ⛔ destructive/irreversible

== CURRENT REPOSITORY: RUN FROM THE REPOSITORY YOU WORK ON ==

UNDERSTANDING AND ANALYSIS
🔭 COM01 | Explore the repository and identify main components and commands.
  • ID: pmt-a709a792
  • Scope: repo | Mode: read
  • Needs: read access to the repository and a shell
  • Example: explore the structure and main modules

🔭 COM02 | Trace a flow and its dependencies through the code.
  • ID: pmt-e0fd59da
  • Scope: repo/area | Mode: read
  • Needs: entry point or scenario to trace
  • Example: trace the authentication and session flow

🔭 COM03 | Find official sources that fit the technical problem.
  • ID: pmt-25c97d58
  • Scope: repo/area | Mode: read
  • Needs: technical problem or library with its version
  • Example: find the official documentation for the runtime version in use

🔭 COM04 | Assess the impact, risks and dependencies of a change.
  • ID: pmt-179b9acc
  • Scope: repo | Mode: read
  • Needs: proposed change or defect to fix
  • Example: assess the impact of isolating runtime logs

🔭 COM05 | Analyze logs and incidents to find the root cause, without changing code.
  • ID: pmt-1839927a
  • Scope: repo/area | Mode: read
  • Needs: logs, errors or symptoms of the incident, time window and read access
  • Example: find the root cause of yesterday's errors in the logs

🔭 COM06 | Explain code or a concept to someone new to the project
  • ID: pmt-fe04425a
  • Scope: repo/file | Mode: read
  • Needs: The code, module or concept to explain and the reader's starting level
  • Example: COM06: explain how the payment retry flow works to a new teammate

🔭 COM07 | Analyze the repository and propose authoritative skills for the project
  • ID: pmt-8bc4e0db
  • Scope: repo | Mode: read
  • Needs: read access to the repository and its manifests, and official skill sources to consult
  • Example: COM07: analyze this repository and propose the skills that would support it


REQUIREMENTS, ARCHITECTURE AND PLANNING
🔭 PRG01 | Turn a request into requirements and acceptance criteria.
  • ID: pmt-98071f85
  • Scope: repo | Mode: read
  • Needs: user request and existing documentation
  • Example: define acceptance criteria for full-text search

🔭 PRG02 | Compare architectural options and justify a decision.
  • ID: pmt-3e0ad55e
  • Scope: repo/area | Mode: read
  • Needs: alternatives to evaluate and project constraints
  • Example: compare SQLite and JSON for local persistence

🔭 PRG03 | Design API contracts, data models and compatibility.
  • ID: pmt-83764c0d
  • Scope: repo/area | Mode: read
  • Needs: requirements or current schema with its version
  • Example: design the JSON schema and API contracts for the task list

🔭 PRG04 | Prepare a phased plan with dependencies, checks and rollback.
  • ID: pmt-8541aed1
  • Scope: repo/area | Mode: read
  • Needs: agreed requirements and scope of the work; for a restructuring, the target structure and test coverage
  • Example: plan the migration in three atomic releases; plan the split of the data module

🔥 PRG05 | Scaffold new modules with structure, configuration and tests.
  • ID: pmt-884419a5
  • Scope: repo/area | Mode: write
  • Needs: agreed architectural scope and dependencies
  • Example: define the scaffolding of the new module

🔥 PRG07 | Record an architecture decision (ADR)
  • ID: pmt-c61c598b
  • Scope: repo | Mode: write
  • Needs: The decision made or to make, its context, constraints, options considered and who decides
  • Example: PRG07: record why we chose PostgreSQL over MongoDB


DEVELOPMENT AND MAINTENANCE
🔥 DEV01 | Implement a feature with relevant checks.
  • ID: pmt-83df1685
  • Scope: repo/area/file | Mode: write
  • Needs: verified requirements or acceptance criteria
  • Example: implement the export command with hash validation

🔥 DEV02 | Triage a defect report, reproduce it and fix its cause.
  • ID: pmt-25ac264e
  • Scope: repo/area/file | Mode: write
  • Needs: report or expected and actual behavior
  • Example: triage and fix the parsing error for paths containing spaces; triage only, no fix

🔥 DEV03 | Refactor code preserving contracts: targeted, phased or periodic.
  • ID: pmt-2b07a693
  • Scope: repo/area | Mode: write
  • Needs: code to improve, existing tests and scope (targeted, phased or periodic)
  • Example: extract transaction handling into its own module

🔥 DEV04 | Update dependencies checking compatibility and regressions.
  • ID: pmt-e2405036
  • Scope: repo/area/file | Mode: write
  • Needs: dependency manifests and lock files
  • Example: update the JSON serialization package

🔥 DEV05 | Migrate code or a framework to a defined target.
  • ID: pmt-22863973
  • Scope: repo/area | Mode: write
  • Needs: source and target versions with release notes
  • Example: migrate the scripts from the old runtime version to the current one

🔥 DEV06 | Configure and run linters, formatters and static analysis.
  • ID: pmt-f3082c1b
  • Scope: repo/area/file | Mode: write
  • Needs: linter configuration and analysis scope
  • Example: configure the linter and run static analysis


TESTING AND PERFORMANCE
🔥 TST01 | Add unit and integration tests for the relevant risks.
  • ID: pmt-08bff671
  • Scope: repo/area | Mode: write
  • Needs: test harness and the behavior to verify
  • Example: add boundary tests for the budget calculation

🔥 TST02 | Cover user journeys with end-to-end tests.
  • ID: pmt-286c3225
  • Scope: repo/area | Mode: write
  • Needs: test environment and agreed user flows
  • Example: create an end-to-end test for the backup and restore cycle

🔥 TST03 | Find and fix flaky or non-deterministic tests.
  • ID: pmt-91021b67
  • Scope: repo/area | Mode: write
  • Needs: logs of the intermittent failures and the test suite
  • Example: fix the instability in the async tests of the suite

🔥 TST04 | Diagnose and fix build and test failures in CI.
  • ID: pmt-bd98736f
  • Scope: repo/area/file | Mode: write
  • Needs: CI logs and pipeline configuration
  • Example: fix the GitHub Actions runner failure on Windows

✅ TST05 | Verify real behavior against the requirements.
  • ID: pmt-ef96dea5
  • Scope: repo | Mode: verify
  • Needs: acceptance criteria and a working environment
  • Example: verify that the output conforms to the specifications

🔥 TST06 | Audit or optimize performance and resources, measuring before and after.
  • ID: pmt-9de57e24
  • Scope: repo/area | Mode: write
  • Needs: flow, representative load, environment, metric and threshold
  • Example: find the critical paths of host discovery, then reduce time and memory use

🔥 TST07 | Set up a test harness with isolated fixtures and safe cleanup.
  • ID: pmt-37c695fe
  • Scope: repo | Mode: write
  • Needs: test framework, test scripts and an assigned isolated fixture root
  • Example: create isolated on-disk fixtures and validate the automatic cleanup

🔭 TST08 | Review test quality and find coverage gaps
  • ID: pmt-de5f1d8d
  • Scope: repo | Mode: read
  • Needs: Test suite, coverage reports if any, critical paths and recent defects
  • Example: TST08: review the billing module tests for gaps and weak assertions


REVIEW AND AUDIT
🔥 AUD01 | Run a full repository audit with a single report, optionally exported.
  • ID: pmt-ccbf18b8
  • Scope: repo/area | Mode: write
  • Needs: read access to the repository, its documentation and measurement tools
  • Example: full audit of the repository before the release

🔭 AUD02 | Measure the repository with reproducible metrics and find hotspots.
  • ID: pmt-4a9a4b4f
  • Scope: repo/area | Mode: read
  • Needs: read access to the repository, its Git history and measurement tools
  • Example: metrics and hotspots of the repository

🔭 AUD03 | Audit architecture and technical debt not yet tracked.
  • ID: pmt-c692cc23
  • Scope: repo/area | Mode: read
  • Needs: read access to the code, the backlog and architecture documentation
  • Example: audit of architecture and technical debt of the repository

🔭 AUD04 | Audit dependencies: outdated, vulnerable and unused.
  • ID: pmt-7dc63766
  • Scope: repo/area | Mode: read
  • Needs: manifests, lock files and access to package registries or dependency advisories
  • Example: dependency audit before the upgrade

🔭 SEC01 | Review changes or code for correctness, security and maintainability.
  • ID: pmt-27896824
  • Scope: repo | Mode: read
  • Needs: diff, commit or files to analyze
  • Example: review the pull request for data leaks; review the readability of the parser module


SECURITY, PRIVACY AND LICENSES
🔭 AUD07 | Audit the CI/CD pipeline and supply chain
  • ID: pmt-6b494996
  • Scope: repo | Mode: read
  • Needs: Pipeline definitions, workflow permissions, secrets handling, third-party actions and release process
  • Example: AUD07: audit the GitHub Actions workflows for unpinned actions and excess permissions

🔥 GOV02 | Verify licenses and compatibility and keep the CREDITS register up to date.
  • ID: pmt-adb9bfc0
  • Scope: repo | Mode: write
  • Needs: dependency lock files, manifests, vendored code and third-party licenses
  • Example: check licenses and SPDX headers and update CREDITS.md

🔭 SEC02 | Analyze threats, trust boundaries and abuse scenarios.
  • ID: pmt-deb7d01a
  • Scope: repo | Mode: read
  • Needs: architecture and data flows toward the outside
  • Example: threat model of the stdio and local file system flows

🔥 SEC03 | Fix vulnerabilities and strengthen the affected defenses.
  • ID: pmt-b4cb6659
  • Scope: repo/area/file | Mode: write
  • Needs: confirmed vulnerability and code context
  • Example: fix path traversal in path resolution

✅ SEC04 | Find exposed credentials and verify input validation.
  • ID: pmt-73fb4547
  • Scope: repo | Mode: verify
  • Needs: working tree and scanning tools
  • Example: run a credentials security audit

✅ SEC05 | Verify personal data isolation and compliance with GDPR and policies.
  • ID: pmt-24189cb6
  • Scope: repo | Mode: verify
  • Needs: data mapping and compliance policy
  • Example: check for personal data and GDPR privacy compliance

🔥 SEC06 | Harden repository configuration, CI, containers and access.
  • ID: pmt-c356eede
  • Scope: repo/area | Mode: write
  • Needs: configuration, CI workflows, containers and repository settings
  • Example: harden the GitHub Actions workflows and containers

✅ SEC07 | Check for sensitive data before publishing, locally and on the remote
  • ID: pmt-058c474f
  • Scope: repo | Mode: verify
  • Needs: Commits, index, working tree and history to publish; remote destination and visibility; scanning tools available
  • Example: SEC07: check the commits about to be pushed, and the remote, for sensitive data

⛔ SEC09 | Wipe remote GitHub history and artifacts after a data exposure.
  • ID: pmt-7fc91f08
  • Scope: repo | Mode: write
  • Needs: explicit request, verified backup and administrative access to the remote
  • Example: wipe the remote history, runs and caches after the exposure


DATA AND INTEGRATIONS
🔥 DAT01 | Migrate schema and data with verifiable comparison and recovery.
  • ID: pmt-32e3cf59
  • Scope: repo/area | Mode: write
  • Needs: source schema, target schema and synthetic data
  • Example: migrate the schema with an atomic rollback script

🔥 DAT02 | Build imports and transformations that preserve the originals.
  • ID: pmt-3ddd1df9
  • Scope: repo/area | Mode: write
  • Needs: source files, target model and validation rules
  • Example: import the catalog from CSV to JSON preserving the originals

🔥 DAT03 | Integrate API services with error handling and request retries.
  • ID: pmt-6b7b0e8d
  • Scope: repo/area | Mode: write
  • Needs: API documentation, test credentials and schema
  • Example: implement a REST client with exponential backoff and retry

🔥 DAT04 | Optimize database queries and indexes
  • ID: pmt-6b6c2ade
  • Scope: repo | Mode: write
  • Needs: Slow queries or endpoints, schema, indexes, execution plans and a safe test database
  • Example: DAT04: speed up the orders listing query without changing its results


INTERFACE AND USER EXPERIENCE
🔭 INT01 | Assess usability, consistency and states of user flows.
  • ID: pmt-33216f62
  • Scope: repo/area | Mode: read
  • Needs: runnable application and flows to examine
  • Example: assess the usability of the setup wizard

🔥 INT02 | Implement an interface following requirements and references.
  • ID: pmt-db55c30d
  • Scope: repo/area | Mode: write
  • Needs: guidelines or mockups and existing components
  • Example: build the synchronization screen

✅ INT03 | Verify accessibility and keyboard and assistive-technology use.
  • ID: pmt-2ea0c993
  • Scope: repo/area | Mode: verify
  • Needs: working interface and reference standards
  • Example: verify ARIA conformance and accessibility

✅ INT04 | Verify internationalization of strings, formats and translations.
  • ID: pmt-805ca095
  • Scope: repo/area | Mode: verify
  • Needs: interface or messages with supported languages and formats
  • Example: verify the strings, formats and translations of the CLI

🔥 INT05 | Write or review interface copy and error messages
  • ID: pmt-f3614e6a
  • Scope: repo/file | Mode: write
  • Needs: Screens or flows, audience, tone, existing terminology and supported languages
  • Example: INT05: rewrite the checkout error messages so each says what to do next


DOCUMENTATION
🔥 DOC01 | Write guides and READMEs consistent with the real product.
  • ID: pmt-07430e8c
  • Scope: repo | Mode: write
  • Needs: implemented features, verified commands and approved screenshots
  • Example: update the guides and add Mermaid flow diagrams

🔥 DOC02 | Document APIs and contracts from the implementation.
  • ID: pmt-6e82e3a9
  • Scope: repo/area | Mode: write
  • Needs: source code of the contracts and endpoints
  • Example: document the parameters and response schemas of the endpoints

🔥 DOC03 | Capture real screenshots and prepare public assets.
  • ID: pmt-75786fd6
  • Scope: repo | Mode: write
  • Needs: working interface with synthetic data
  • Example: capture authentic screenshots from the real interface

🔥 DOC04 | Write or update an operational runbook
  • ID: pmt-4b88488d
  • Scope: repo | Mode: write
  • Needs: The procedure, systems involved, access needed, failure modes and an operator who can validate it
  • Example: DOC04: write a runbook for restoring the database from backup


RELEASE AND OPERATIONS
🔥 OPS01 | Prepare and verify distributable packages and artifacts.
  • ID: pmt-a5c78cc6
  • Scope: repo | Mode: write
  • Needs: build instructions and package requirements
  • Example: build a deterministic zip archive and compute its SHA-256

🔥 OPS02 | Configure pipelines, containers and infrastructure as code.
  • ID: pmt-ce00f261
  • Scope: repo | Mode: write
  • Needs: deployment requirements and target environment
  • Example: configure a multi-stage Dockerfile for a reproducible build

🔥 OPS03 | Add logs, metrics and diagnostics useful for the problem.
  • ID: pmt-c2785b9c
  • Scope: repo/area/file | Mode: write
  • Needs: scenario to monitor and logging standards
  • Example: add structured JSON logging

🔥 OPS04 | Prepare release notes and delivery checks.
  • ID: pmt-0618969e
  • Scope: repo | Mode: write
  • Needs: commits, issues or tasks completed since the previous release
  • Example: compile the v1.1 release notes from commits and issues

🔥 OPS06 | Prepare a release hotfix and rollback with verification and communication.
  • ID: pmt-b377d5f0
  • Scope: repo | Mode: write
  • Needs: faulty release, known previous version and criteria for going back
  • Example: prepare the hotfix and rollback for release 2.3.1

🔥 OPS07 | Write a blameless incident postmortem
  • ID: pmt-28f4fbf5
  • Scope: repo | Mode: write
  • Needs: Incident timeline, impact, logs or alerts, the fix applied and the people involved
  • Example: OPS07: write the postmortem for last night's checkout outage


GIT AND GITHUB
🔥 OPS05 | Prepare commits and pull requests with verified scope, message and checks.
  • ID: pmt-3e3728b6
  • Scope: repo | Mode: write
  • Needs: local changes to deliver and an explicit request for a commit or pull request
  • Example: prepare the commits and the pull request description

⛔ REP04 | Remove leftovers and unused code; align .gitignore and .gitkeep.
  • ID: pmt-40772e6e
  • Scope: repo/area | Mode: write
  • Needs: proof of no references and green tests; tracked and ignored file lists
  • Example: remove temporary files and orphaned build caches and fix the ignore rules

🔥 REP11 | Report an error as GitHub issues in the form format, after confirmation.
  • ID: pmt-fe68329a
  • Scope: repo | Mode: write
  • Needs: observed error, reproduction steps, version and `gh` authenticated
  • Example: report this build error as a GitHub issue

🔥 REP12 | Consolidate branches with a --no-ff merge and delete the integrated ones.
  • ID: pmt-fabd3439
  • Scope: repo | Mode: write
  • Needs: local and remote branches, the base branch and a clean working tree
  • Example: consolidate the finished branches into master

🔥 REP13 | Align the GitHub page, community files and security, after confirmation.
  • ID: pmt-3e2e75f6
  • Scope: repo | Mode: write
  • Needs: `gh` authenticated with admin rights and a SEC07 result
  • Example: make this repository discoverable and apply standard security

🔭 REP14 | Triage open issues and pull requests
  • ID: pmt-f8dd6843
  • Scope: repo | Mode: read
  • Needs: GitHub repository with gh authenticated, labels, project rules, age and activity of issues and PRs
  • Example: REP14: triage open issues and PRs and propose labels and closures


BACKLOG, MEMORY AND CONTINUITY
🔥 MEM01 | Align local instructions, context, memory and tracker.
  • ID: pmt-f02db9d0
  • Scope: repo/area | Mode: write
  • Needs: recent decisions or changes not yet recorded
  • Example: sb prompt MEM01: align context.md and memory.md after completing a task

🔥 MEM02 | Migrate design and tasks into the SecondBrain dossier.
  • ID: pmt-64dfa49f
  • Scope: repo/area | Mode: write
  • Needs: historical documentation or external issues to migrate
  • Example: sb prompt MEM02: migrate scattered todos into the dossier's central tracker

🔥 MEM03 | Close the session: memories, tracker, handoff and commit and push request.
  • ID: pmt-76604e4a
  • Scope: repo/area | Mode: write
  • Needs: state of the work done, defined next tasks and delivery destination
  • Example: sb prompt MEM03: close the session and ask for commit and push

🔭 MEM06 | Read memory, context and tracker of the current repository and list its tasks.
  • ID: pmt-821f7dec
  • Scope: repo | Mode: read
  • Needs: checkout of the open repository
  • Example: sb prompt MEM06: load the repository context and list the ready tasks

🔥 REP01 | Complete the next ready task of the open repository.
  • ID: pmt-4cc383ba
  • Scope: repo | Mode: write
  • Needs: planned task and acceptance criteria
  • Example: run the next priority task that can be done autonomously

🔭 REP08 | Inspect the repo and find leftover tasks against the real code.
  • ID: pmt-cc2c5f5a
  • Scope: repo/area | Mode: read
  • Needs: working tree, recent history and any backlog or notes
  • Example: inspect the repo and detect leftover tasks

🔥 REP15 | Run ready autonomous tasks with the runner, monitor and record the outcome
  • ID: pmt-802ff569
  • Scope: repo | Mode: write
  • Needs: tracker with ready autonomous tasks, scripts/run-ready-tasks.ps1 or the repository launcher, and the user's go-ahead for -Run
  • Example: REP15: run the ready autonomous tasks, follow the run and record the outcome

🔥 REP16 | Unblock blocked tasks: verify the real reason, then make them autonomous
  • ID: pmt-876bccc6
  • Scope: repo | Mode: write
  • Needs: tracker with blocked tasks, their state reasons and acceptance criteria, and the answers of the user to a structured interview
  • Example: REP16: review the blocked tasks and make the ones without a real prerequisite autonomous

🔥 REP17 | Reorder the tracker, archive done tasks and put qualifications after development
  • ID: pmt-c1e1e70c
  • Scope: repo | Mode: write
  • Needs: tracker with its archive, the priority scheme chosen by the user and the list of tasks with real prerequisites
  • Example: REP17: archive the done tasks and move qualifications below development

🔥 SYS13 | Set or remove the greenfield lock (versions, changelog, migrations, aliases).
  • ID: pmt-29b3278f
  • Scope: repo/area | Mode: write
  • Needs: managed repository, active dossier and user confirmation
  • Example: sb prompt SYS13: set or remove the greenfield lock on this repository


WEBSITES AND WEB APPS
🔥 WEB01 | Define the requirements, audience and success criteria of a site or app
  • ID: pmt-ca497b4e
  • Scope: repo | Mode: write
  • Needs: a brief of the site or app, its audience and constraints, and write access to the docs folder
  • Example: WEB01: define the requirements and success criteria of the new company website

🔥 WEB02 | Choose the stack, hosting and architecture of a site or app with trade-offs
  • ID: pmt-68ab97c9
  • Scope: repo | Mode: write
  • Needs: the requirements (WEB01), team skills, budget and hosting constraints
  • Example: WEB02: compare stacks and hosting for the new site and record the decision

🔥 WEB03 | Design information architecture, user flows, content and a small design system
  • ID: pmt-203f2c25
  • Scope: repo | Mode: write
  • Needs: the requirements (WEB01), the chosen architecture and any brand assets
  • Example: WEB03: design the sitemap, key flows and design tokens for the new site

🔥 WEB04 | Scaffold the project and build a first working vertical slice
  • ID: pmt-1ea75934
  • Scope: repo | Mode: write
  • Needs: architecture and design decisions, an empty or new repository and a working toolchain
  • Example: WEB04: scaffold the project and deliver the first page end to end with tests

🔥 WEB05 | Develop the remaining features in phases with tests and accessibility checks
  • ID: pmt-9deb1414
  • Scope: repo | Mode: write
  • Needs: the first vertical slice (WEB04), a phased backlog and a working test setup
  • Example: WEB05: build the next phase of features and verify tests and accessibility

🔥 WEB06 | Prepare release, hosting, monitoring, backups and handover of a site or app
  • ID: pmt-019f989e
  • Scope: repo | Mode: write
  • Needs: a built and tested application, the hosting target and the delivery owner
  • Example: WEB06: prepare the production release, monitoring and handover notes

🔥 WEB07 | Harden a website: headers, TLS, forms, admin, dependencies and abuse limits
  • ID: pmt-5dfba80d
  • Scope: repo | Mode: write
  • Needs: the site code and configuration, its hosting target and write access to the repository
  • Example: WEB07: harden the company website before the public launch

🔥 WEB08 | Verify and update site indexing: sitemap, robots, webmaster tools, schema
  • ID: pmt-f7a96c3d
  • Scope: repo | Mode: write
  • Needs: the live or staging site, the domain owner's access to the search tools, write access to the repository
  • Example: WEB08: verify what is indexed and update sitemap, robots and webmaster tools

🔥 WEB09 | Control AI crawlers and bots: robots rules, verification, rate limits, logs
  • ID: pmt-f1fdcecb
  • Scope: repo | Mode: write
  • Needs: the site, its access logs or CDN/WAF console and the owner's policy on AI use of content
  • Example: WEB09: block AI training crawlers on the site and verify the rules in the logs


AI AND LANGUAGE-MODEL FEATURES
🔭 AIS01 | Assess company AI use cases, data readiness and feasibility, then rank them
  • ID: pmt-9e1ebedb
  • Scope: repo | Mode: read
  • Needs: a description of the business processes and data, and the stakeholders to interview
  • Example: AIS01: assess where AI fits in our company and rank the use cases

🔥 AIS02 | Design a local inference system: models, hardware, serving, scaling and limits
  • ID: pmt-45641386
  • Scope: repo | Mode: write
  • Needs: the chosen use case (AIS01), data sensitivity, available hardware and latency targets
  • Example: AIS02: design the on-premises inference service for the support use case

🔥 AIS03 | Connect inference to business applications and production systems safely
  • ID: pmt-692f03a1
  • Scope: repo | Mode: write
  • Needs: the inference service (AIS02), the API or database of the target application and an agreed owner
  • Example: AIS03: connect the local model to the ERP and the production line dashboard

🔥 AIS04 | Build a local-AI chatbot to embed in an existing website
  • ID: pmt-22aecc7c
  • Scope: repo | Mode: write
  • Needs: the existing site and its stack, a local model endpoint (AIS02), the knowledge sources and the tone of voice
  • Example: AIS04: add a local-AI chatbot widget to our existing website

🔥 AIS05 | Design retrieval (RAG) over company documents with access control and evals
  • ID: pmt-61a987a2
  • Scope: repo | Mode: write
  • Needs: the document sources, their permissions and a set of real questions to answer
  • Example: AIS05: design retrieval over the company manuals and test it on real questions

🔥 AIS06 | Evaluate, monitor and operate an AI system in production
  • ID: pmt-866ddd80
  • Scope: repo | Mode: write
  • Needs: a running AI feature, a representative evaluation set and access to its logs
  • Example: AIS06: set up evaluation, monitoring and a rollback plan for the chatbot

🔭 AIS07 | Assess AI privacy, security and compliance (GDPR, AI Act, prompt injection)
  • ID: pmt-df63e53f
  • Scope: repo | Mode: read
  • Needs: the AI system design, the data it processes and the jurisdiction
  • Example: AIS07: assess privacy, security and compliance risks of the company chatbot

🔭 AIS08 | Estimate cost, ROI and an adoption and training plan for company AI
  • ID: pmt-6c6771d0
  • Scope: repo | Mode: read
  • Needs: the ranked use cases (AIS01), expected volumes and the current process cost
  • Example: AIS08: estimate cost and return of the chatbot and plan staff adoption

🔥 AIS09 | Automate a business process with AI agents, tools and human review
  • ID: pmt-9f755f33
  • Scope: repo | Mode: write
  • Needs: a documented process, the systems it touches and the people who approve exceptions
  • Example: AIS09: automate invoice triage with an AI agent and human approval

🔥 DEV12 | Build or review an LLM feature with evaluations
  • ID: pmt-0715c64b
  • Scope: repo | Mode: write
  • Needs: The LLM or agent feature, model and provider, expected behavior, failure cases and sample inputs
  • Example: DEV12: add an evaluation set for the support bot before changing its prompt


== CENTRAL SECONDBRAIN: RUN FROM THE SECONDBRAIN CHECKOUT ==

WORKSTATION AND IDES
✅ SYS01 | Check the IDEs; map, register accounts or realign on request.
  • ID: pmt-26817a61
  • Scope: central | Mode: verify
  • Needs: IDE installations and local authorizations; to register accounts also an activated workstation and consent
  • Example: sb prompt SYS01: register an ide with two accounts or two roots

🔥 SYS03 | Activate SecondBrain after discovery and asset selection.
  • ID: pmt-5f9f93e0
  • Scope: central | Mode: write
  • Needs: SecondBrain volume and user consent on the assets
  • Example: sb prompt SYS03: activate secondbrain selecting local repositories and ides

✅ SYS04 | Check or align the workstation's already managed assets.
  • ID: pmt-677a10ab
  • Scope: central | Mode: verify
  • Needs: workstation configuration and approved directives
  • Example: sb prompt SYS04: check directive alignment in the managed repositories

⛔ SYS10 | Roll back and decommission a repository, returning its data for privacy.
  • ID: pmt-b98acaaa
  • Scope: central | Mode: write
  • Needs: repository dossier, target checkout and user consent
  • Example: sb prompt SYS10: roll back the decommissioned repository and clean up the data

🔥 SYS15 | Install the SecondBrain MCP server in the IDEs and verify the handshake.
  • ID: pmt-2d3c1d51
  • Scope: central | Mode: write
  • Needs: SecondBrain root, target IDEs and confirmation before writing
  • Example: sb prompt SYS15: install the mcp server in vscode and claude code


DOSSIER, SOURCES AND DIRECTIVES
🔥 MEM05 | Create, update and archive projects, areas and resources of the central PARA.
  • ID: pmt-4e1b7c52
  • Scope: central | Mode: write
  • Needs: goal of the PARA entity and a write session on the SecondBrain clone
  • Example: sb prompt MEM05: archive the finished resource res-guida

🔥 MNT07 | Prepare a directive revision: proposal, preview, version, changelog, checks
  • ID: pmt-fd98d7ce
  • Scope: central | Mode: write
  • Needs: a concrete change to the common directives and the owner's approval path
  • Example: MNT07: prepare the revision proposal for the new common directive

✅ SYS02 | Check authoritative sources; acquire or update on request.
  • ID: pmt-5b593404
  • Scope: central | Mode: verify
  • Needs: PARA resource-authoritative-sources registry
  • Example: sb prompt SYS02: check regulatory updates in the sources registry

🔥 SYS05 | Compact the dossier preserving originals, facts and TOC.
  • ID: pmt-77d7bf7a
  • Scope: central | Mode: write
  • Needs: dossier to compact and verifiable history
  • Example: sb prompt SYS05: compact the dossier history preserving facts and toc

🔥 SYS11 | Add, change or remove a prompt of the centralized catalog.
  • ID: pmt-364616bb
  • Scope: central | Mode: write
  • Needs: valid catalog, target area and a write session
  • Example: sb prompt SYS11: add a prompt to the catalog in the test area

🔥 SYS16 | Update a skill from authoritative sources and verify the diff.
  • ID: pmt-9ef61b3d
  • Scope: central | Mode: write
  • Needs: identified skill, target agent and version, official sources
  • Example: sb prompt SYS16: update the local skill from official sources


SECONDBRAIN MAINTENANCE
🔭 MNT01 | Plan a SecondBrain maintenance round and choose the routines to run
  • ID: pmt-511dd7da
  • Scope: central | Mode: read
  • Needs: read access to the checkout, the dossier tracker and the latest reports in history
  • Example: MNT01: plan this week's maintenance round and list what is due

✅ MNT02 | Health check: directives, IDEs, prompts, tests and publication scan
  • ID: pmt-1456d6b9
  • Scope: central | Mode: verify
  • Needs: the SecondBrain checkout, PowerShell 7.5+ and Git
  • Example: MNT02: run the health check and report what drifted

🔥 MNT03 | Tidy the dossier: archive done tasks, compact, reorder and sync
  • ID: pmt-36e8d784
  • Scope: central | Mode: write
  • Needs: write access to the dossiers through the coordinated writer and a recent backup
  • Example: MNT03: tidy the SecondBrain dossier after the last release

✅ MNT04 | Verify backups with a real restore test and report coverage gaps
  • ID: pmt-03822742
  • Scope: central | Mode: verify
  • Needs: the backup archives, the manifest and an empty scratch folder for the restore
  • Example: MNT04: test the latest backup by restoring it into a scratch folder

🔥 MNT05 | Review .runtime and clean up in preview; apply only with authorization
  • ID: pmt-ba610991
  • Scope: central | Mode: write
  • Needs: the checkout, no active sessions and the owner's authorization before any deletion
  • Example: MNT05: report what .runtime holds and propose the cleanup preview

🔥 MNT06 | Refresh authoritative sources, skills and tool versions and verify the diff
  • ID: pmt-0fdd6f29
  • Scope: central | Mode: write
  • Needs: network access to official sources and the registered sources and skills of the workstation
  • Example: MNT06: check the registered sources and skills for updates

🔥 SYS09 | Run the deterministic compressed backup and verify the SHA-256 digests.
  • ID: pmt-e498353a
  • Scope: central | Mode: write
  • Needs: active configuration and backup runtime root
  • Example: sb prompt SYS09: run a deterministic backup and validate the sha-256 manifest

```
