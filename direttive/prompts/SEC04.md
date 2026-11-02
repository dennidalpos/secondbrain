# SEC04 — Find exposed credentials and verify input validation

> **Scope**: repo | **Mode**: verify | **Needs**: working tree and scanning tools | **Example**: `run a credentials security audit`

## Purpose

Detect exposed credentials (passwords, tokens, keys, certificates, connection strings) and unvalidated input at the system boundaries. For dependencies use AUD04, for hardening SEC06, for personal data SEC05 and for the check on the diff before a push SEC07.

## When to use

Before committing, opening a pull request or distributing code and executables, and after introducing integrations that handle secrets.

## Input

Git working tree, index, recent commits, configuration files and examples of environment variables.

## Activities

Scan for passwords, API tokens, certificates and private keys, connection strings and URLs with credentials in the working tree, the index and the relevant commits, with the project's tools or with deterministic rules. Check that inputs at the system boundaries (requests, files, arguments, environment variables, deserialization) are validated and sanitized and that secrets do not end up in logs and errors. Report findings with file, line and type without reproducing the value. Do not remove or rewrite anything without authorization: propose how to isolate sensitive leftovers in a local area excluded from version control and which credentials to rotate.

## Checks

Check that `git diff --staged` contains no credentials or private workstation paths. Distinguish justified false positives (example values, public hashes) from real risks: a real exposed credential requires rotation, not just removal.

## Delivery

Report classifying the findings (location, type, severity, false positive or risk), fixes applied if authorized and the limits of the coverage.

## Related prompts

- SEC01: Review changes or code with concrete findings and references.
- SEC05: Verify personal data isolation and compliance with GDPR and policies.
- SEC06: Harden repository configuration, CI, containers and access.
- SEC07: Check diff, repository and history for sensitive data before publishing.
