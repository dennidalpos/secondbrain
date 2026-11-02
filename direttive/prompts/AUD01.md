# AUD01 — Run a full repository audit with a single report, optionally exported

> **Scope**: repo/area | **Mode**: read | **Needs**: read access to the repository, its documentation and measurement tools | **Example**: `full audit of the repository before the release`

## Purpose

Assess architecture, quality, security, dependencies, performance, tests and documentation in a single pass, with verified findings and priorities, and deliver the result as one report, exported in the requested format.

## When to use

Before a release, a handover or a planning session, when an overall picture is needed rather than a single check. Export also applies to already verified results from AUD02-AUD05, SEC01 or SEC04.

## Input

Scope and depth requested, repository documentation and any backlog and, if exporting, output format, audience and destination.

## Activities

Orchestrate without duplicating the specialised cards: use AUD02 (metrics), AUD03 (architecture and debt), AUD04 (dependencies), AUD05 (performance), SEC01, SEC04 and SEC05 (security and sensitive data), GOV01 (licenses), DEV08 (readability) and TST05 (behavior) only for the dimensions included in the scope. Work read-only and, where available, with parallel agents for independent dimensions. Merge the findings, remove duplicates and compare them with the backlog so that already tracked work is not redefined.

Export, only on request: start from a single data structure (findings with identifier, severity, path, line, evidence and status; metrics with method and date) from which every format is derived, without reinterpreting the results. Formats: Markdown, JSON, standalone HTML, CSV, SARIF 2.1.0 for analysis findings, DOCX, PDF and XLSX with the tools available. Choose the destination with the user, outside the product repository unless asked otherwise, and never include secrets, sensitive values or private paths: report hashes and locations.

## Decisions to collect

- dimensions to include (multiple choice);
- depth: quick or in-depth;
- export: format or formats, destination and minimum severity of findings to include.

## Checks

Every finding has evidence (file and line, command or measurement) and a severity; separate facts from hypotheses, state the dimensions not covered and the checks that could not be run. The analysis does not modify repository files, the backlog or notes. An exported file is opened or validated (JSON or SARIF schema, CSV rows and columns, the document opens), counts match the source and formats that cannot be verified are declared; an existing report is never overwritten, a new dated version is created.

## Delivery

A single report with summary, findings per dimension ordered by severity, coverage gaps and proposed work items; if requested, a file in the chosen format with its path, counts and conversion limits.

## Related prompts

- AUD02: Measure the repository with reproducible metrics and find hotspots.
- AUD03: Audit architecture and technical debt not yet tracked.
- AUD04: Audit dependencies: outdated, vulnerable, unused and licenses.
- AUD05: Audit performance and find critical paths without changing code.
- SEC01: Review changes or code with concrete findings and references.
