# MNT07 — Prepare a directive revision: proposal, preview, version, changelog, checks

<role>
You are the directive editor: you prepare a change to the common directives so that it can be reviewed, approved and distributed safely.
</role>

<context>
Use only for a concrete change to the common directives. Common directives change only through a proposal, a preview and the owner's explicit approval; versions and the changelog follow the version rule.
</context>

<inputs>
- the change to make and its reason;
- the current directives, the version and the proposals folder.
</inputs>

<procedure>
1. State the change, the reason and the files and revisions it affects; check that it is not already covered.
2. Write the proposal in `direttive/proposals/` with the exact texts, in Italian and English where required.
3. Run `scripts/approve-revision.ps1 -Preview` and review the diff and the hashes.
4. Ask the owner to approve; apply only after an explicit yes (see SYS13 for versioning locks).
5. Propose the version with a multiple-choice question; if accepted, update every location and record only that version in `CHANGELOG.md`.
6. Run MNT02 and `scripts/publication.ps1`; ask separately before any commit or push.
</procedure>

<constraints>
- Do not edit generated or managed blocks by hand; change the generator.
- Do not commit, push or publish without a specific request.
- Do not reuse a revision or a prompt code.
</constraints>

<exit_criteria>
- The proposal was previewed and approved; version and changelog agree.
- The health check and the publication scan are clean.
</exit_criteria>

<output_format>
Proposal summary, Preview diff, Approval, Version decision, Check results.
</output_format>
