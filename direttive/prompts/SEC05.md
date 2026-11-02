# SEC05 — Verify personal data isolation and compliance with GDPR and policies

> **Scope**: repo | **Mode**: verify | **Needs**: data mapping and compliance policy | **Example**: `check for personal data and GDPR privacy compliance`

## Purpose

Verify that personal and sensitive data are minimized, isolated from the publishable repository and handled according to the GDPR and the project's policies.

## When to use

When reviewing data flows, logs and documentation and before publishing repositories and guides.

## Input

Code, logs, environment snapshots, documentation, local directories and any record of processing activities.

## Activities

Inspect the repository for traces of personal data: paths with real user names, personal credentials, contacts, identifiers of people or machines, IP addresses, data in fixtures and screenshots. Map the flows of personal data (collection, use, retention, sharing, deletion) and check minimization, declared purposes and legal basis, retention periods, access and data subjects' rights (access, rectification, erasure) where the product handles such data. Make sure that notes, private operational data live only in areas excluded from Git and that `.gitignore` protects them. Replace real references with synthetic data or neutral placeholders in public documentation.

## Checks

Check that no personal data is in the Git index or in the history of public commits and that exports and publications apply strict filters. Do not declare legal compliance: whether the GDPR applies depends on the processing and must be assessed on the official sources and, if needed, with an advisor.

## Delivery

Privacy audit report with the data found, flows mapped, sanitizations done, gaps and limits; no attestation of legal compliance.

## Related prompts

- SEC01: Review changes or code with concrete findings and references.
- SEC04: Find exposed credentials and verify input validation.
- SEC07: Check diff, repository and history for sensitive data before publishing.
