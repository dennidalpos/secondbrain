# REP11 — Report an error as GitHub issues in the form format, after confirmation

> **Scope**: repo | **Mode**: write | **Needs**: observed error, reproduction steps, version and `gh` authenticated | **Example**: `report this build error as a GitHub issue`

## Purpose

Turn a verified error into one or more GitHub issues that follow the repository's issue forms, without publishing anything the user has not confirmed.

## When to use

When a defect, build failure or missing feature has been observed and must be tracked on GitHub rather than fixed on the spot.

## Input

The error text or log, the steps to reproduce, product version and environment, the issue forms in `.github/ISSUE_TEMPLATE/` (`bug.yml`, `feature.yml`, `config.yml`) and the target repository.

## Activities

Verify the error first: reproduce it or read the real log and the code involved, and separate facts from hypotheses. Check with `gh issue list --search` that no open issue already covers it. Split unrelated problems into separate issues. For each issue fill every required field of the matching form (`bug.yml` or `feature.yml`) with the same labels, order and wording, using synthetic or redacted data: no secrets, personal data, host paths or raw logs, checked as in SEC07. Show title, labels and body as a preview. Publish with `gh issue create` only after the user confirms each issue, then report the issue numbers and links. If `gh` is missing or not authenticated, stop and hand over the prepared text without publishing.

## Decisions to collect

- one issue or several, and the split between them;
- labels, assignees and milestone, if the repository uses them;
- confirmation to publish each prepared issue.

## Checks

Check that every required form field is filled, that the body contains no sensitive data, that no duplicate issue exists and that the reported issue matches the observed error. After publishing, read each issue back with `gh issue view`.

## Delivery

The list of published issues with number and link, or the prepared texts when nothing was published, plus any duplicate found.

## Related prompts

- DEV07: Triage and reproduce an issue before fixing it, without changing code.
- COM05: Analyze logs and incidents to find the root cause, without changing code.
- SEC07: Check diff, repository and history for sensitive data before publishing.
