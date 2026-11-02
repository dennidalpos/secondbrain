# COM05 — Analyze logs and incidents to find the root cause, without changing code

> **Scope**: repo/area | **Mode**: read | **Needs**: logs, errors or symptoms of the incident, time window and read access | **Example**: `find the root cause of yesterday's errors in the logs`

## Purpose

Trace symptoms (errors, logs, metrics, reports) back to the root cause of an incident or anomalous behavior, separating evidence from hypotheses, without changing code, configuration or data.

## When to use

When an error in production or in tests is observed but its cause is unclear, before fixing it (DEV02) or adding diagnostics (OPS03). To triage a new report use DEV07.

## Input

Logs, error messages or symptoms, time window, versions and environment involved, recent changes, and read access to the code and diagnostic data.

## Activities

Reconstruct the timeline: first error observed, what changed before it (releases, configuration, load) and what stayed the same. Correlate logs, metrics and traces with the code that emits them; separate symptom, immediate cause and root cause (for example with the five whys). Formulate alternative hypotheses, state for each the evidence that would confirm or rule it out, and verify with the reads that are possible. Do not reproduce the error on real systems or data without authorization and do not repeat sensitive values found in logs: cite identifiers and locations.

## Decisions to collect

- time window, environment and sources to analyze;
- hypotheses to pursue first when the evidence is not enough;
- recommended action: fix now, add diagnostics, mitigate or ask for more data.

## Checks

Every conclusion cites its evidence (log line, metric, commit or file and line) and its degree of certainty. State the hypotheses not ruled out, the missing data and the limits of the reconstruction; do not present a correlation as a cause.

## Delivery

Incident timeline, root cause or hypotheses ranked by likelihood with their evidence, impact, missing information and recommended action; no changes to the code.

## Related prompts

- DEV02: Reproduce a defect and fix its cause.
- OPS03: Add logs, metrics and diagnostics useful for the problem.
- DEV07: Triage and reproduce an issue before fixing it, without changing code.
