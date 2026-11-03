# REP13 — Align the GitHub page, community files and security, after confirmation

> **Scope**: repo | **Mode**: write | **Needs**: `gh` authenticated with admin rights and a SEC07 result | **Example**: `make this repository discoverable and apply standard security`

## Purpose

Bring the GitHub page and settings of the repository to a standard baseline — findable in search, a complete community profile and the security features on — proposing every change as a choice and applying only what the user confirms.

## When to use

Before or after the first publication, when the page lacks a description, topics or a security policy, or when settings have drifted from the standard. Run it from the session of the repository concerned.

## Input

The repository and its remote, the visibility (`gh repo view --json visibility`), the About data and topics, the settings and security features (`gh api repos/{owner}/{repo}`), branch protection and rulesets of the default branch, the community profile (`gh api repos/{owner}/{repo}/community/profile`), the local files (README, LICENSE, `SECURITY.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `.github/` forms and templates, `CODEOWNERS`) and the result of SEC07 or `check_publication`.

## Activities

Detect first, with read-only calls: visibility, owner type, `gh` authentication, the admin permission and the current value of every item. A private repository is never made public and its visibility is never changed here; for a public one run SEC07 first and stop on any finding. Then build the proposal by group, showing for each item the current value, the proposed value, the reason, the `gh` command and the value to restore:

- **A. Discoverability**: a one-sentence About description (what it is, for whom, the main technology), 5 to 12 specific lowercase topics, a website only if it exists, and a README that states what it does, how to install and use it and its limits (DOC01).
- **B. Community files**: `SECURITY.md` with a private reporting channel, LICENSE, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, issue forms, a pull request template and `CODEOWNERS` when more people work on it. Missing files are created in the working tree only and left uncommitted (OPS05).
- **C. Security**: secret scanning and push protection, Dependabot alerts and security updates, private vulnerability reporting, read-only default permissions for Actions, and for the default branch one of three levels — none, block force-push and deletion, or require pull requests and checks.
- **D. Settings**: Issues on only with forms, Wiki, Discussions and Projects off unless used, delete the branch after merge, and the merge methods allowed by the project policy (REP12).

Offer each group as a multiple choice — apply all proposals, apply only the selected items, or skip the group. Apply the confirmed items one by one (`gh repo edit` for About data and features, `gh api` for the rest), read each back, and stop at the first failure. Report as unavailable, with the reason, any item that needs another plan, an organization policy or a permission the account lacks, instead of failing silently. Never put secrets, personal data or host paths in the text, never pass tokens on the command line, and never change visibility, ownership or archive state.

## Decisions to collect

- the groups to apply (A to D, more than one);
- description and topics among the proposed variants, and their language;
- missing community files to create in the working tree;
- the branch protection level, with the warning that requiring pull requests blocks direct pushes for a single owner;
- merge methods to allow;
- confirmation for each setting before it is applied.

## Checks

Check that SEC07 or `check_publication` was ready before any visibility proposal, that every applied setting reads back as confirmed, that no item outside the confirmed ones changed and that visibility is unchanged. Compare the community profile percentage before and after.

## Delivery

A before and after table for each item, the commands run with the values to restore, the files created and left uncommitted, and the items skipped or unavailable with the reason.

## Related prompts

- SEC07: Check diff, repository and history for sensitive data before publishing.
- SEC06: Harden repository configuration, CI, containers and access.
- REP11: Report an error as GitHub issues in the form format, after confirmation.
- DOC01: Write guides and READMEs consistent with the real product.
