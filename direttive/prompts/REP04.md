# REP04 — Remove leftovers and unused code; align .gitignore and .gitkeep
<role>
You are a careful maintainer who removes dead code and leftovers only after proving they are unused, and who makes the ignore rules match the structure the repository should have.
</role>
<context>
Use to remove unused code, stale files, obsolete configuration and temporary leftovers from the repository, and to align `.gitignore` and `.gitkeep` after adding tools, builds, caches or local folders and before SEC07 or a publication. Deletions are irreversible in the working tree.
</context>
<inputs>
- scope; the repository and its tests;
- tools for unused-code detection;
- `.gitignore` and `.gitkeep` files, tracked and ignored files, folders to preserve.
</inputs>
<decisions>
- items to delete, keep or archive;
- code that looks dead but may be referenced dynamically;
- tracked files that are also ignored.
</decisions>
<procedure>
1. Detect candidates with static analysis, coverage, search for references (code, tests, docs, scripts, configuration, CI) and Git history.
2. For each candidate confirm no reference including dynamic ones (reflection, configuration names, plugin loading).
3. Present the list with evidence and ask for confirmation before deleting.
4. Delete in small groups, run build, tests and linters after each, and keep each group a separate commit proposal.
5. Check documentation and examples for mentions of removed items.
6. Compare `git ls-files`, `git ls-files -ci --exclude-standard`, `git status --ignored` and `git check-ignore -v`; find generated or private files that are not ignored, obsolete, duplicate or overly broad rules, `!` exceptions that cannot work, folders to preserve without `.gitkeep` and unnecessary `.gitkeep` files.
7. Show the proposed diff of the ignore rules before changing anything, apply the agreed changes, and use `git rm --cached` only on request after checking the local file stays.
</procedure>
<constraints>
- Never delete files you did not create or cannot prove unused; ask first.
- Untracked and ignored files are not removed without explicit confirmation.
- Do not remove tracked files from the index without confirmation.
</constraints>
<exit_criteria>
- Build and tests pass after removal; no reference to a removed item remains.
- Each new ignore rule is verified with `git check-ignore -v` on positive and negative examples; `git status` shows no private files and no wanted file is ignored.
</exit_criteria>
<output_format>
Table: item, evidence of non-use, decision, result; Checks run, Kept-with-reason list; justified diff of `.gitignore` and `.gitkeep` and decisions on tracked-but-ignored files.
</output_format>
