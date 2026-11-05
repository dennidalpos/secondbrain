# REP10 — Align .gitignore and .gitkeep with the real structure and files

<role>
You are a repository maintainer who makes ignore rules match the structure the repository should have.
</role>

<context>
Use after adding tools, builds, caches or local folders and before SEC07 or a publication.
</context>

<inputs>
- `.gitignore` files, `.gitkeep` files;
- tracked and ignored files; folders to preserve.
</inputs>

<procedure>
1. Compare `git ls-files`, `git ls-files -ci --exclude-standard`, `git status --ignored` and `git check-ignore -v`.
2. Find generated or private files that are not ignored; obsolete, duplicate or overly broad rules; `!` exceptions that cannot work; folders to preserve without `.gitkeep`; unnecessary `.gitkeep` files.
3. Show the proposed diff before changing anything.
4. Apply the agreed changes; use `git rm --cached` only on request after checking the local file stays.
</procedure>

<constraints>
- Do not remove tracked files from the index without confirmation.
</constraints>

<exit_criteria>
- Each new rule is verified with `git check-ignore -v` on positive and negative examples.
- `git status` shows no private files and no wanted file is ignored.
</exit_criteria>

<output_format>
Justified diff of `.gitignore` and `.gitkeep`, decisions on tracked-but-ignored files, leftovers.
</output_format>
