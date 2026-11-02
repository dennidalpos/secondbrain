# SEC07 — Check diff, repository and history for sensitive data before publishing

> **Scope**: repo | **Mode**: verify | **Needs**: commits, index, working tree and history to publish; destination | **Example**: `check that it is safe to publish before the push`

## Purpose

Prevent secrets, personal data and private leftovers from reaching a remote or a release, by checking the diff about to be sent and, when needed, the whole repository and its history.

## When to use

Before every push, pull request, release or publication of a repository. A check on the diff is the minimum; the whole repository and its history are qualified at the first publication, after imports or history rewrites and before a release. If the data is already on the remote use SEC08, to clean it up SEC09.

## Input

Commits, index and working tree to publish (tags included), reachable history, destination and visibility of the remote, scanning tools available and any exceptions already agreed.

## Activities

Determine the exact set of commits and files that would be sent (for example `@{upstream}..HEAD` and the tags). Run separate checks on the working tree, the index and the history with the tools available (secrets with SEC04, personal data with SEC05) and compare their scope with the set you just determined. Also check commit messages, file names, binaries, screenshots and metadata, ignored files added by force, private paths, non-public email addresses, licenses and content that is deliberately public. Report only hashes and locations, never the values.

For false positives propose targeted exceptions (rule, path, fingerprint and reason), never whole categories. Private information and operational artifacts do not belong in the public repository.

## Decisions to collect

- remote and destination visibility;
- action for each finding (fix, accept with a reason, defer);
- confirmation before any intervention on history or credential rotation.

## Checks

Distinguish checks run, justified false positives, binary content not qualified and limited coverage; do not declare general compliance on the basis of text patterns. If a secret is already in a local commit, local history must be rewritten before the push: do not proceed. No reset or deletion of local work and no push while findings remain unassessed; moving or ignoring a file does not rewrite commits.

## Delivery

Outcome per commit (ready, blocked, to assess), findings with location and suggested actions, reasoned decisions and remaining work; the push and the publication remain the user's choice.

## Related prompts

- SEC04: Find exposed credentials and verify input validation.
- SEC05: Verify personal data isolation and compliance with GDPR and policies.
- SEC08: Check whether sensitive data is still reachable on the GitHub remote.
- OPS01: Prepare and verify distributable packages and artifacts.
- DOC01: Write guides and READMEs consistent with the real product.
- SEC02: Analyze threats, trust boundaries and abuse scenarios.
- SEC09: Wipe remote GitHub history and artifacts after a data exposure.
- REP10: Align .gitignore and .gitkeep with the real structure and files.
