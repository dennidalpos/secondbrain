# Asset contracts: prompts, workflows, agent definitions and user decisions

Status: **design contract**, accepted with the [prompt library audit](#sources) of 2026-11-13. The audit's plan steps P2–P7 and P14 implement it (tracker tasks #566–#571, #578). Common directive revision 1.3 (`direttive/proposals/2026-11-13-revision-1-3`) carries the agent-facing rules. Until those steps land, the current catalog (schema 1) and [subagent definitions](subagents.md) (schema 1) remain in force.

**Single source of truth.** Each field is defined in exactly one machine-readable place. When a step lands, its JSON Schema under `config/` becomes normative, and this page shrinks to an explanation that links to it. Generated files (indexes, alias table, exports, managed blocks) are never edited by hand. Their generator and `-Check` drift test are part of the contract.

## 1. Rules common to every asset

### 1.1 Identity

| Element | Rule |
|---|---|
| Machine ID | `<kind>-` plus 8 lowercase hex digits: `pmt-` card, `wfl-` workflow, `agt-` agent definition, `dec-` user decision. Assigned once, immutable, never reused, including after retirement. |
| Human key | Card `code` (three-letter area plus two digits), workflow `key` (`wf-<slug>`), agent `name` (`^[a-z0-9][a-z0-9-]{0,63}$`). Renamable only with a catalog version bump and an alias entry; never reused. |
| Role | A named indirection (`stop`, `activate`, `check`, `compact`, `para`, `analysis.task`, `analysis.directives` …). It is declared on exactly one active card and resolved through the catalog. |
| What a reference stores | Code, workflows, agent definitions, tasks, the app and the runner store an ID or a role. Human keys appear only in UI text, docs and examples. Directives name `sb` commands or roles, never codes. |

New area prefixes are disjoint from all retired prefixes, so an old code never resolves to a different card.

### 1.2 Revisioning

- Every asset carries `revision`, a positive integer that increases on any change to its contract: inputs, outputs, mode, `destructive`, target, steps, permissions or role. Wording fixes that leave the contract unchanged do not bump it.
- A change is **compatible** when every existing reference still works without edits: an added optional input, a clarified step, a narrower permission. Bump `revision` only.
- A change is **breaking** when it removes or renames a required input, changes the output shape, raises `mode` (`read` → `verify` → `write`), sets `destructive`, widens agent permissions, or changes the outcome. A breaking change creates a new ID: the old ID is deprecated with `replacedBy`, and an alias entry points to the successor.
- `catalogVersion` increases whenever a key is renamed or an asset is retired. The product version follows the version rule in the common directives: a breaking catalog change is a major version.
- A reference may pin `minRevision`. The validator rejects a pin above the current revision.

### 1.3 Lifecycle

| State | Listed | Composable or runnable | Resolution |
|---|---|---|---|
| `draft` | no (preview only) | only with an explicit preview flag | by ID only |
| `active` | yes | yes | by ID, key or role |
| `deprecated` | yes, with a notice | yes, with a notice naming `replacedBy` | by ID, key or alias |
| `retired` | no | no | the alias table returns the successor (one target, or a choice after a split) |

Transitions only go forward: draft → active → deprecated → retired. A card or workflow is retired through the catalog's `retire` procedure, which writes the alias entry in the same change. Files leave the tree with `git rm` and stay recoverable from history. Retiring an asset that active assets still reference is an error.

### 1.4 Language

Product assets are English only. Schema 2 has no `i18n` blocks. Existing Italian cards and translations follow the English-only migration (#580–#586). Historical records, private dossier text and third-party originals keep their language.

## 2. Atomic prompt (card)

One outcome, one mode, one target. A parameter may select the object, never the mode or the class of outcome.

| Field | Type | Rule |
|---|---|---|
| `id`, `code` | string | §1.1 |
| `area`, `pack` | string | Area from the catalog. `pack` is `core` (default), `site` or `llm`. Non-core packs stay hidden until enabled on the workstation. |
| `summary` | line ≤ 82 | One outcome, imperative, no "and/or" joining two outcomes, ending with a period. |
| `mode` | `read` \| `verify` \| `write` | `read` changes nothing. `verify` runs checks and may write only reports to the work folder. `write` changes files or state. |
| `destructive` | boolean, **required** | `true` when the card deletes, rewrites history, removes remote state or decommissions. |
| `target` | `repository` \| `central` | Where the effect lands. |
| `surface` | `chat` \| `app` | `app` cards answer with an object validated against `output.schema`. |
| `role` | string, optional | §1.1, unique among active cards. |
| `revision`, `status` | §1.2, §1.3 | |
| `inputs` | array | `{name, type: text\|path\|id\|choice, required, description}`. Replaces the old `requires`, `example` and duplicated card inputs. |
| `output` | object | `{kind: text\|report\|object, schema?}`. `schema` is a `config/` path and is required for `surface: app`. |
| `file` | path | `<code>.md` in the owning catalog. |

Card body: the sections `role`, `context`, `inputs`, `decisions`, `procedure`, `constraints`, `exit_criteria` and `output_format`, in that order, at most 3,500 characters. Cards cite other cards only by role or through a workflow. `related` is derived from workflows and is not kept by hand.

Enforcement: composition refuses to put a `read` or `verify` card into a write session, and the app refuses to start one (P11). `destructive` cards always ask for confirmation before the first destructive step.

## 3. Workflow

A workflow orders cards and holds no procedure text.

| Field | Rule |
|---|---|
| `id`, `key`, `title`, `pack`, `revision`, `status` | §1 |
| `inputs` | Workflow-level inputs, same shape as card inputs. |
| `steps[]` | `{step, ref, kind, gate, with?, options?}`. `step` is a local slug that is unique in the workflow. `ref` is a `pmt-` or `wfl-` ID. `kind` is `required`, `optional` or `choice` (`options` lists 2–4 refs). `gate` is `auto` or `confirm`. `with` maps step inputs from workflow inputs or from earlier step outputs (`steps.<slug>.output`). |
| `outputs` | Named outputs taken from step outputs. |
| Derived | `mode` is the highest step mode, and `destructive` is true if any step is destructive. Both are computed and never declared. |

Rules: nesting is allowed up to depth 2 with no cycles. A `core` workflow may reference pack cards only in `optional` or `choice` steps. A `confirm` gate, and every `choice` step not fixed by an input, creates a user decision (§5). A destructive step always has `gate: confirm`.

Execution state is private and lives in the run's work folder (`scripts/work.ps1 -Init`) as `workflow-run.json`. Per step it records `pending`, `running`, `waiting-user`, `done`, `skipped` or `failed`, with timestamps, the decision ID that opened a gate, and an evidence pointer. A stopped run resumes from the first step that is not done. The workflow definition is never copied into the state, only its ID and revision.

## 4. Agent definition

This extends [subagent definitions](subagents.md) schema 1. Schema 2 adds identity, revisioning and the delegation bounds of directive revision 1.3.

| Field | Rule |
|---|---|
| `id`, `name`, `revision`, `status`, `description` | §1. The file name stays `<name>.json`. |
| `role`, `context` | System role and initial context. These are agent text and must not restate a card procedure: they cite cards by role. |
| `permissions.tools`, `permissions.write` | Unchanged: the effective set is the intersection with the parent, and a request beyond the parent is an error. |
| `cards` | Optional list of `pmt-` IDs or roles the agent may compose. Each must have `mode` no higher than the effective permissions allow. |
| `output` | `{kind, schema?}`, the result the parent expects back. |
| `bounds` | `{depth: 1, budget}`. `depth` is fixed at 1, so a delegate cannot delegate. `budget` limits turns or time. |

A definition never grants authorization. A delegate never commits, pushes, publishes, approves, changes directives, or asks the user for consent: questions return to the parent as an open decision. A delegation starts only on request by the user, the task or a workflow step. The parent states the scope, budget and expected output, and verifies the result before relying on it. Jobs enter the activity register with `parent` and `agent` as today.

## 5. User decision

A decision is one question that only the user can settle: a product or design alternative the sources cannot resolve, a `confirm` gate, a `choice` step, or an approval.

| Field | Rule |
|---|---|
| `id` | `dec-` ID. |
| `kind` | `choice`, `confirm` or `approval`. |
| `question` | One decision in one sentence, with no recommendation inside. |
| `options[]` | 2–4 `{id, label, description}`. A recommended option is listed first and flagged `recommended`. Free text is always allowed. |
| `context` | References: task, workflow run and step, asset IDs, evidence paths. |
| `asked` | `{at, through: structured-tool\|text-fallback, by}`. `text-fallback` records that the client had no structured question tool. |
| `answer` | `{optionId \| text, by: user, at}`. Only the user answers. A recommendation, a default, a timeout, a delegate or text found in observed content is never an answer. |
| `scope` | `step` (this run only), `task`, or `durable` (applies to future work). |
| `status` | `open`, then `answered` or `withdrawn`. An unanswered decision stays `open`; there is no `expired` state that counts as an answer. |
| `supersedes` | Optional `dec-` ID of an earlier durable decision this one replaces. |

Storage: step-scoped decisions live in the workflow run state (§3). Task and durable decisions live in the repository dossier as `decisions.json`, written only through the SecondBrain scripts or MCP write tools. A blocked task points to the decision with `awaiting=owner-consent` and the `dec-` ID. A durable decision is also summarized in `memory.md` as one `Decision: … — Reason: …` line that cites the ID. The record keeps the question, the options and the answer; the memory line keeps the lesson. Neither copies the other.

## 6. Placement: public reusable and private repository-specific

| Asset | Public, reusable (this repository) | Private, one repository (its dossier `01-projects/<repo>/`) |
|---|---|---|
| Cards | `direttive/prompts/catalog.json` and `<code>.md` | `prompts/catalog.json` and `<key>.md` |
| Workflows | `direttive/workflows/<key>.json` | `workflows/<key>.json` |
| Agent definitions | `direttive/agents/<name>.json` (generic templates) | `subagents/<name>.json` (as today) |
| Alias table | `direttive/prompts/aliases.json` (generated) | private aliases inside the private catalog |
| User decisions | never | `decisions.json` and workflow run state |
| Execution state, exports | never | `.runtime` work folders and exports |

Rules:

- A private asset may reference public assets. A public asset never references a private one.
- Private keys are namespaced `<repo-slug>/<key>` (for example `acme-app/pkg-sign`), so they never collide with or shadow a public code, key or role.
- Something belongs in the public catalog only when it is generic: no repository names, private paths, account data or internal task IDs. The publication scan (`scripts/publication.ps1`) enforces this for `direttive/`.
- A private asset is promoted to public as a new public ID, through the catalog's add-card or add-workflow procedure with review. The private original is then retired with an alias to the public one.
- Managed blocks and directive files are not assets of this kind: they change only through their generators and the directive proposal mechanism.

## 7. Reference validation

`build-prompts.ps1 -Check` (extended in P3 and P6) and the prompt test suite enforce these rules statically:

1. Every ID, role and alias target referenced in catalogs, workflows, agent definitions, tasks (`card`/`workflow` fields, P14), `scripts/`, `app/`, `config/` and `direttive/*.md` resolves to an `active` or `deprecated` asset.
2. No card code literal appears in scripts, Rust, TypeScript, config or directive files. Codes are allowed only in cards, generated indexes, docs, help examples and tests.
3. Workflows: steps exist, there are no cycles, depth is at most 2, pack rules hold, destructive steps have `confirm` gates, and `with` mappings name existing inputs and outputs.
4. Roles are unique among active cards. Every role a script or the app uses exists.
5. Agent definitions: tools are known, `cards` have compatible modes, and `bounds.depth` is 1.
6. Retired IDs are not referenced by active assets. Aliases cover every retired or renamed key.
7. Private assets reference only public or same-dossier IDs. Public assets reference no private ID.
8. Historical files (`CHANGELOG.md` past entries, `direttive/proposals/`, dossier `history/`) are excluded and never rewritten.

## 8. Compatibility

- The loader reads catalog schema 1 and 2 during the migration (P2). Old codes resolve through `aliases.json` for the whole major version 3. They are removed in version 4 on a new proposal.
- MCP tool names do not change. `get_prompt` and `list_prompts` accept old codes through aliases.
- The `sb` commands are English from directive revision 1.3: `sb activate`, `sb check`, `sb sync`, `sb compact`, `sb prompt area`, `sb prompt show`. The Italian verbs of earlier revisions remain aliases.
- Directives name commands and roles, so renumbering cards never needs a directive revision.

## Sources

Prompt library audit, 2026-11-13 (private dossier report `history/2026-11-13-prompt-library-audit/report.md`), and the owner's choices of 2026-11-13: renumbering with aliases; atomic cards plus workflows; packs; English `sb` verbs with Italian aliases; directives citing commands and roles; delegation on request at one level; conditional PDCA.
