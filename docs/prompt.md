# Prompts

[Retained Italian source; use this English page for current behavior](prompt.it.md)

The catalog contains 91 prompt cards in 14 categories. The reference cards are in English, with Italian counterparts under `direttive/prompts/it/`.

~~~text
sb prompt list
sb prompt ambito test
sb prompt mostra DEV01
sb prompt DEV01: add PDF export
~~~

See the generated [English catalog](../direttive/prompts/README.md) or [Italian catalog](../direttive/prompts/README.it.md). Memory and central maintenance prompts belong to the same list.

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

| Prefix | Area |
|---|---|
| COM | Understanding and research |
| PRG | Requirements and design |
| DEV | Development and modernization |
| TST | Testing and verification |
| SEC | Review and security |
| AUD | Audit and metrics |
| INT | Interface and user experience |
| DAT | Data and integrations |
| OPS | Release and operations |
| DOC | Documentation |
| REP | Repository maintenance |
| GOV | Licensing and compliance |
| MEM | Memory and continuity |
| SYS | System and central maintenance |

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
