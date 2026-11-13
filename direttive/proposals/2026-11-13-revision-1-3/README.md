# Directive revision 1.3: English product, prompt identity, structured questions, conditional PDCA, bounded delegation

Origin: owner request of 2026-11-13 to define asset contracts from the accepted prompt library audit and prepare the common-directive proposal. Owner choices made in that session through structured questions: English `sb` verbs with Italian aliases; directives cite commands and roles, never card codes; delegation only on request, one level deep; PDCA for non-trivial changes. The asset contracts are in `docs/riferimento/asset-contracts.md`. Tracker: #572 (directive revision), #580 (English-only policy).

## Problem

1. **Language.** The product is moving to English only (#580–#586), but the common directives carry Italian tokens: the revision line `Revisione`, the memory format `Decisione: … — Motivo: …`, and the `sb` verbs `attiva`, `controlla`, `allinea`, `compatta`, `ambito`, `mostra`.
2. **Prompt codes.** The audit renumbers every card (prefixes change, IDs stay). Revision 1.2 cites seven card codes (MEM05, MEM07, MEM09, SYS01, SYS03, SYS04, SYS05), so every renumbering would force a new directive revision.
3. **Questions.** "Ask one multiple-choice question and wait" does not say how to ask, or that a recommendation or a timeout is not an answer. Agents with a structured question tool sometimes answer their own question by picking the recommendation.
4. **Work cycle.** Nothing says when to plan and check a change. Agents either skip checks on multi-file work or run a full cycle on one-line edits.
5. **Delegation.** Subagents, forked and parallel agents exist in every supported client, but nothing bounds them: depth, scope, permissions, and who may ask the user or commit.

## Change

`AGENTS.global_ide.md` (3,461 → 4,737 bytes, 4,729 characters; limit 5,500):

- Header `Revisione 1.2 — 2026-11-12.` → `Revision 1.3 — 2026-11-13.`
- Principles: the question rule names the structured question tool, states that recommendations, defaults, and timeouts are not answers, and adds a text fallback that pauses dependent work. New rule: product content is English; private user content, third-party originals, attribution, and historical records stay as they are.
- New section **Work cycle**: conditional Plan-Do-Check-Act, and bounded delegation (on request, one level, stated scope, budget, and output, permissions no wider than the parent's, no commit, push, publish, approval, or user questions by delegates, results verified).
- SecondBrain: `MEM05` → "scripts/para.ps1 and its `sb prompt` procedure"; the procedures line lists `sb activate`, `sb check`, `sb compact`, `sb stop` instead of card codes; new prompt identity rule (immutable `pmt-` ID, codes renamed only with catalog version and alias, never reused, never stored).
- Closing work: `"Decisione: … — Motivo: …"` → `"Decision: … — Reason: …"`; `use SYS05` → `use sb compact`.

`workstation.template.md` (1,029 → 1,038 bytes; limit 3,200):

- The command list is in English (`sb prompt area AREA`, `sb prompt show KEY`, `sb activate`, `sb check`, `sb sync`, `sb compact`). It states that the Italian verbs remain aliases. The `MEM09`/`MEM07`/`SYS01` mentions are replaced by plain descriptions.

`AGENTS.repo.managed.md`: unchanged (identical copy of revision 1.2, hash `B7798368…6AEA`).

No card code remains in the three files.

## Effect

The startup context grows by 1,285 characters (global plus workstation), well inside the 25,000 cap. Distribution by `secondbrain.ps1 -Sync` rewrites the managed blocks of every activated repository and IDE. Existing copies that still say `Revisione 1.2` keep parsing.

## Counterexamples

- The English rule does not authorize translating or deleting private dossiers, historical records, third-party originals or CREDITS attribution. Removals follow only the reviewed manifest of #581.
- The delegation rule does not require delegation and does not authorize it beyond the request. A workflow step that delegates still runs under the parent's permissions.
- PDCA does not add a report to read-only work or trivial edits. "Act" records only durable lessons, never task progress.
- A structured question is required only for substantial unresolved product or design alternatives. Routine choices with a conventional default proceed and are stated.

## Prepared before approval (compatible, already in the working tree)

- Parsers accept both `Revision` and `Revisione` (`Core`, `ide-map.ps1`, `IdeObservation`, `Portable`, quick and prompts tests).
- The memory view accepts `Decision:` and `Reason:` alongside `Decisione:` and `Motivo:` (`Knowledge`).
- The `sb` registry is English-primary with `aliases` for the Italian verbs. English messages and the generated index use the English verbs. `test-secondbrain-prompts.ps1` checks the English verbs in this proposal and the aliases in the registry.

## After approval

1. `scripts/approve-revision.ps1 -ProposalPath direttive/proposals/2026-11-13-revision-1-3 -ExpectedProposalHash <preview hash> -Authorization "<owner text>"`.
2. Managed-block generators: the stamp `Direttive comuni applicate: revisione **x** — date.` becomes `Common directives applied: revision **x** — date.` (`Portable.psm1` `New-SBPortableRepositoryBody`, `agents.ps1` `Get-AgentsComposedBlock`). The closing text in `SecondBrain.Prompts.psm1` uses `Decision: … — Reason: …`. These are deferred so that `-Check` stays aligned on 1.2 until approval.
3. `secondbrain.ps1 -Sync`, then `-Check` and `ide-map.ps1 -Verify`.
4. The memory-cycle writer (`MemoryCycle.psm1`) emitting `Decisione` stays in #582. Cards that still mention Italian verbs (SYS03, SYS04, SYS05) are rewritten in #569/#583. Both resolve through the aliases meanwhile.
5. Version: decided separately (the audit proposes 3.0.0 with the catalog migration). Revision 1.3 alone changes no CLI contract.

Preview: `scripts/approve-revision.ps1 -Preview -ProposalPath direttive/proposals/2026-11-13-revision-1-3`.
