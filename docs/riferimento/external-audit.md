# Read-only GitHub audit

[Retained Italian source; use this English page for current behavior](external-audit.it.md)

audit-github.ps1 performs explicit GET requests through the existing GitHub CLI authentication. Sync and Check do not invoke the collector. Do not inspect credential stores or retain tokens.

~~~powershell
pwsh -NoProfile -File scripts/audit-github.ps1 -Repository github.com/example-user/my-app
~~~

The identity must belong to the active inventory and allowed owner policy. Without OutputPath, results go to stdout. An optional OutputPath must name a new JSON artifact in an initialized runtime report folder. It cannot overwrite a previous report or tracker. Pass SessionId for authorized longer writes.

The inventory hash is checked after collection; changing it invalidates the result. The collector changes no remote, checkout or tracker.

## Coverage

The collector inventories metadata, issues excluding PRs, PRs, issue comments, inline comments, reviews for observed PRs, branches, tags and forks. A fork list does not inspect fork contents.

Pages record endpoint, UTC timing, HTTP status and payload SHA-256. Titles/bodies are represented by hashes and lengths; raw payloads, authentication headers and raw stderr are not retained. Wiki content needs separate inspection.

Pagination follows next links only within the expected endpoint. Foreign links, unexpected parameters, cycles and more than 1,000 pages produce incomplete coverage. Identity-changing redirects are not followed.

## Results

| State | Meaning |
|---|---|
| accessible, complete=true, count=0 | Completed request and observed empty list |
| not_found_or_inaccessible | HTTP 404; absence and permissions remain indistinguishable |
| authentication_required / access_denied | HTTP 401 / 403 |
| rate_limited | Recognized 429/rate-limit 403; later collection stops |
| partial | Some pages obtained, no complete total |
| not_attempted | Missing prerequisite or global stop |
| Wiki disabled / unverified | Disabled in metadata / content not acquired |

complete and count describe the entire resource. observedCount retains partial results; incomplete requests leave count null. Reviews are complete only if the PR listing and each required review query are complete. Global authentication/rate limits stop later collection without automatic retries.

Snapshots are not atomic across endpoints. Attachments, Actions contents, caches, clones and external copies are outside coverage. A complete audit is not publication clearance.

Exit codes are 0 complete, 1 valid artifact with explicit limits, 2 invocation/configuration/write error. Fixture checks in test-secondbrain-external-audit.ps1 do not replace authenticated acquisition.

Primary references: [pagination](https://docs.github.com/en/rest/using-the-rest-api/using-pagination-in-the-rest-api), [gh api](https://cli.github.com/manual/gh_api), [REST troubleshooting](https://docs.github.com/en/rest/using-the-rest-api/troubleshooting-the-rest-api).
