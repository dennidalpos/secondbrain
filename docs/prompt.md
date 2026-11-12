# Prompts

[Retained Italian source; use this English page for current behavior](prompt.it.md)

The catalog contains 121 prompt cards in 17 categories, in two groups (current repository and central SecondBrain). The reference cards are in English, with Italian counterparts under `direttive/prompts/it/`.

~~~text
sb prompt list
sb prompt ambito test
sb prompt mostra DEV01
sb prompt DEV01: add PDF export
~~~

See the generated [English catalog](../direttive/prompts/README.md) or [Italian catalog](../direttive/prompts/README.it.md). Memory and central maintenance prompts belong to the same list.

## Where you are

`sb prompt` (`scripts/prompts.ps1`) reads the current folder and names its location: a **managed repository** (dossier, tracker and runner available), a **repository not onboarded** (reduced mode), the **SecondBrain checkout**, or **no project** (outside a Git checkout). The home screen then shows two command groups, **repository commands** and **SecondBrain activation and maintenance**, with the maintenance group first in the SecondBrain checkout and outside a project.

**Standard starting chain:** `sb prompt MEM08` (repository state, SecondBrain alignment when managed, proposed next tasks), then `sb prompt REP01` or `sb runner`, and `sb prompt MEM03` when the work is done; `sb prompt MEM07` resumes work stopped by a usage limit, also from another account. `sb stop` (MEM09) stops the agent before a limit, saves a handoff report in the dossier and leaves the task in progress, so `sb prompt MEM07` can resume it from another IDE or account. When `sb attiva` (SYS03) activates a repository that has its own tracker, it imports it with `import-tracker.ps1`; without a tracker it runs a reconnaissance and creates the tasks you approve. Every composed prompt ends with `<next_steps>`: two to four next prompts and ready tasks, proposed as a multiple choice.

**Without onboarding** a repository still works: repository prompts are composed without a dossier and carry a `<degraded>` block. Not available: startup context and memory, tracker and ready tasks in the next steps, runner and Orchestrator, MEM03 handoff reports and the runner resume, memory and tracker writes, sync of the managed `AGENTS.md` block, applicable authoritative sources, SYS05 compaction and `-Check` of that repository. Central prompts and MEM/SYS writes still need a dossier. Onboarding stays optional (`sb attiva`, SYS03).

## Card structure

| XML tag | Content |
|---|---|
| `role` | The agent's responsibility |
| `context` | When to use the card and its scope |
| `inputs` | Required evidence |
| `decisions` | Material choices to ask the user, where needed |
| `procedure` | Ordered steps |
| `constraints` | Boundaries and prohibited actions |
| `exit_criteria` | Verifiable completion conditions |
| `output_format` | Required report |

Composition combines the objective, repository context and card in XML with `task`, `context`, `operating_rules` and `next_steps`. The card organizes the task; it does not grant permissions. A read-only audit proposes changes without applying them. Write workflows remain subject to the user's authorization and current IDE mode.

`sb prompt mostra` shows the source card. Display language follows `-Language`, `SECONDBRAIN_LANG` and the configured language fallback; MCP calls accept `language: en|it`. The indexes are generated, not edited by hand.

## Categories

Prompts are grouped by development area or need, not by code prefix. A repository prompt works only on the repository it runs from; central prompts run from the SecondBrain checkout. No card reads another repository: 03-resources is the only shared area.

**Current repository: run from the repository you work on**

| ID | Area | Codes |
|---|---|---|
| `understand` | Understanding and analysis | COM01, COM02, COM03, COM04, COM05, COM06, COM07, COM08 |
| `design` | Requirements, architecture and planning | PRG01, PRG02, PRG03, PRG04, PRG05, PRG07 |
| `develop` | Development and maintenance | DEV01, DEV02, DEV03, DEV04, DEV05, DEV06 |
| `test` | Testing and performance | TST01, TST02, TST03, TST04, TST05, TST06, TST07, TST08 |
| `review` | Review and audit | AUD01, AUD02, AUD03, AUD04, SEC01 |
| `security` | Security, privacy and licenses | AUD07, GOV02, SEC02, SEC03, SEC04, SEC05, SEC06, SEC07, SEC09 |
| `data` | Data and integrations | DAT01, DAT02, DAT03, DAT04 |
| `interface` | Interface and user experience | INT01, INT02, INT03, INT04, INT05 |
| `docs` | Documentation | DOC01, DOC02, DOC03, DOC04, DOC05, DOC06 |
| `operations` | Release and operations | OPS01, OPS02, OPS03, OPS04, OPS06, OPS07 |
| `git` | Git and GitHub | OPS05, REP04, REP11, REP12, REP13, REP14 |
| `backlog` | Backlog, memory and continuity | MEM01, MEM02, MEM03, MEM06, MEM07, MEM08, MEM09, REP01, REP08, REP15, REP16, REP17, REP18, SYS13 |
| `web` | Websites and web apps | WEB01, WEB02, WEB03, WEB04, WEB05, WEB06, WEB07, WEB08, WEB09 |
| `ai` | AI and language-model features | AIS01, AIS02, AIS03, AIS04, AIS05, AIS06, AIS07, AIS08, AIS09, DEV12 |

**Central SecondBrain: run from the SecondBrain checkout**

| ID | Area | Codes |
|---|---|---|
| `system` | Workstation and IDEs | SYS01, SYS03, SYS04, SYS10, SYS15, SYS17 |
| `knowledge` | Dossier, sources and directives | MEM05, MNT07, SYS02, SYS05, SYS11, SYS16 |
| `maintenance` | SecondBrain maintenance | MNT01, MNT02, MNT03, MNT04, MNT05, MNT06, SYS09 |

Security and supply-chain areas follow the practice groups of NIST SP 800-218 SSDF 1.1 (source `nist-ssdf` of the authoritative registry, verified). The remaining areas follow the usual development activities; they are not derived from SWEBOK or ISO/IEC/IEEE 12207, which the registry does not hold.

Codes and immutable IDs are stable and are not reused. Gaps in numbering are intentional.

## Modes

| Icon | Mode | Meaning |
|---|---|---|
| 🔭 | Read | Analyze and report |
| ✅ | Verify | Compare evidence with pass/fail criteria |
| 🔥 | Write | Change authorized files or state |
| ⛔ | Destructive | Requires explicit confirmation for irreversible work |

These modes describe the workflow, not an exemption from session permissions or tool side effects.

## Customize

Use SYS11 to add or change a prompt:

~~~text
sb prompt SYS11: add a database migration prompt
~~~

Maintain both language cards and the catalog, then run:

~~~powershell
pwsh -NoProfile -File scripts/build-prompts.ps1 -Check
~~~

Regeneration is a writing operation. Common instructions require a concrete proposal, explicit approval and verified hashes before distribution. See [customization](riferimento/customizing-prompts-and-directives.md).
