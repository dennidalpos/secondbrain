# SEC08 — Check whether sensitive data is still reachable on the GitHub remote

> **Scope**: repo | **Mode**: verify | **Needs**: read-only access to the GitHub remote and fingerprints or patterns to look for | **Example**: `check which runs, caches and links are still accessible`

## Purpose

Detect what remains accessible on the remote after an exposure or a rewrite: commits, references, runs, artifacts, caches, releases and links.

## When to use

After a wrong publication, before SEC09 and as the final check of a cleanup.

## Input

Remote repository, fingerprints, prefixes or patterns to search for (never secrets in clear) and read-only authorization.

## Activities

Read-only, with `gh` or the APIs: list branches, tags, `refs/pull/*` and fork branches; look for commits reachable by SHA even if no longer in any branch; list workflow runs with their logs, artifacts, Actions caches, releases and assets, wikis, packages, issues, comments, descriptions and the Pages site. Treat forks and copies as external exposures and check whether links to specific files or SHAs still respond. GitHub may keep cached views and unreachable objects: follow the official documentation for the support request.

## Checks

Every item reports its URL or identifier, type, the outcome of the request (accessible or not) and the date of the check. Do not download or reproduce the sensitive content. Distinguish data that is really exposed from harmless references.

## Delivery

Inventory of exposures with severity, items that cannot be verified from outside (third-party copies, caches) and proposed steps for SEC09 and for credential rotation.

## Related prompts

- SEC07: Check diff, repository and history for sensitive data before publishing.
- SEC09: Wipe remote GitHub history and artifacts after a data exposure.
