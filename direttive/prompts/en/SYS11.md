# SYS11 — Add, change or remove a prompt of the centralized catalog

> **Scope**: central | **Mode**: write | **Needs**: valid catalog, target area and a write session | **Example**: `sb prompt SYS11: add a prompt to the catalog in the test area`

## Purpose

Add, change or retire a prompt of the centralized catalog keeping IDs immutable, aliases resolvable, cards uniform, the index generated and references consistent.

## When to use

When a workflow is missing, needs fixing or is no longer needed. Not for changing the text of the common directives (SYS04 and explicit approval) nor for the cards of a single repository.

## Input

Requested operation (add, change, remove), prompt code or ID, area, mode, scope, card text and related prompts. Catalog `direttive/prompts/catalog.json`, cards `direttive/prompts/*.md`, schema `config/prompt-catalog.schema.json`.

## Activities

Read the catalog and cards without changing them and identify the operation. Work in a write session (`scripts/access.ps1 -Start -Mode Write`, `-End` in the same script).

**Add.** Pick the free code of its area (`^[A-Z]{2,4}[0-9]{2}$`, next number, no reuse of retired codes), generate a `pmt-` ID with 8 hexadecimal digits not present among IDs, aliases and `deprecations`, write the `CODE.md` card with the standardized header and all the sections (Purpose, When to use, Input, Activities, Checks, Delivery, Related prompts; «Decisions to collect» if the prompt asks for choices) and add the entry to `catalog.json` with `file`, `summary` (code and title within 88 characters), `example`, `requires`, `references`, `related`. Also add the translation: the card in `direttive/prompts/en/CODE.md` (for a core prompt in `it/`) and the `i18n` entry of the non-source language with translated `summary`, `requires` and `example` (same limits); the translation's title, header and «Related prompts» repeat the `i18n` values and, for the neighbours, their summary in the same language. Title, header (scope, mode, «Needs», example) and the «Related prompts» entries of the card repeat word for word `summary`, `scope`, `mode`, `requires`, `example` and the `summary` of the prompts in `related` (the check rejects them if they diverge). Every related prompt must appear with its code in the card, in both directions.

**Change.** The ID and existing aliases never change. A change to body, title, mode or scope updates the card and the entry together. If the code changes, the old code stays as an alias or in `deprecations` pointing to the same ID; the `related` links use IDs and remain valid.

**Remove.** By default retire, do not delete (soft retirement): set `status: deprecated` with `supersededBy` (a different active ID) and leave entry, card and ID as history. The code stays in the catalog and keeps resolving to the replacement with a warning: do not register it in `deprecations`, because a code still present already occupies the name and the validator rejects the conflict. Permanent deletion (entry and card) or renaming the code happens only on explicit request: remove the ID from the `related` of the other cards, add to `deprecations` the old code pointing to the replacement (now no longer in the catalog) and never reuse the ID. First check where the code appears: `README`, guides, tests, MCP, examples and dossiers. A prompt cannot be retired or deleted without a replacement.

After every operation regenerate the index with `scripts/build-prompts.ps1` (do not edit `direttive/prompts/README.md` by hand), update the declared counts (README, guides, tests, MCP description) and rerun Sync and Check with the write session. Do not change the text of the common directives: every new common rule requires a concrete proposal and explicit approval.

## Decisions to collect

- operation: add, change, remove (also several operations in a batch: multiple choice);
- area and proposed code among the first free codes;
- mode (read, write, verify) and scope (repo, area, file, central) of the prompt;
- related prompts to document in both directions;
- retirement (default) or permanent deletion, and the replacement when several active prompts are compatible;
- final confirmation of the scope before writing.

## Checks

`scripts/build-prompts.ps1 -Check` must exit 0: unique IDs, no conflict among IDs, codes and aliases, existing category, mandatory translation in the other language for every active prompt (`i18n` entry and translated card), valid and documented `related`, no unresolved placeholder, sections present and non-empty. Check with `scripts/prompts.ps1 -Show -Prompt <code>` that the uniform card composes, that a retired alias resolves to the replacement with a warning and that `scripts/test-secondbrain-workflows.ps1` stays green. Verify that no declared count was left stale.

## Delivery

New or changed catalog entry and card, IDs and aliases involved, regenerated index, updated references, outcome of Check and tests, and the list of what was not touched (common directives, unrelated cards). Commit and push only on explicit request.

## Related prompts

- SYS04: Check or align the workstation's already managed assets.
- MEM01: Align local instructions, context, memory and tracker.
- GOV02: Scan third-party dependencies and compile the CREDITS register of licenses.
