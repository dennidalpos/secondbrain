# SEC01 — Review changes or code with concrete findings and references

> **Scope**: repo | **Mode**: read | **Needs**: diff, commit or files to analyze | **Example**: `review the pull request for data leaks`

## Purpose

Find defects worth fixing in the code under review.

## When to use

Before integrating changes or for a targeted review.

## Input

Diff, commit or area; criteria and depth requested.

## Activities

Examine staged, unstaged and relevant new files, or the explicit scope. Follow contracts, callers, errors and tests. Verify suspected defects with proportionate evidence; do not look for a fixed number of problems.

## Checks

For each finding check the impact, the conditions and the precise reference. Do not modify files, clean up or update the backlog implicitly.

## Delivery

Findings ordered by severity with file and line and a reproduction; checks and limits. If no defects emerge, say so.

## Related prompts

- SEC02: Analyze threats, trust boundaries and abuse scenarios.
- TST05: Verify real behavior against the requirements.
- AUD01: Run a full repository audit with a single report, optionally exported.
