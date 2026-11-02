# OPS06 — Prepare a release hotfix and rollback with verification and communication

> **Scope**: repo | **Mode**: write | **Needs**: faulty release, known previous version and criteria for going back | **Example**: `prepare the hotfix and rollback for release 2.3.1`

## Purpose

Prepare and verify the urgent fix of a faulty release (hotfix) and the return to the previous version (rollback), with decision criteria, reversible steps and communication.

## When to use

When a release that is already distributed causes a serious defect and a choice must be made between fixing forward and going back. For ordinary release notes use OPS04, for packages OPS01, to diagnose the cause COM05.

## Input

Faulty release and symptoms, known stable previous version, distribution strategy, changes included in the release, any data or schema migrations already applied and the people to notify.

## Activities

Check the scope of the defect and compare the costs of hotfix and rollback: time, risk, irreversible migrations, data compatibility and dependencies released together. For the rollback list the steps in order, the points of no return and the verification of the state after going back (for example `git revert` of commits already published instead of rewriting history). For the hotfix start from the released version, limit the change to the fix, add a test that reproduces the defect (DEV02) and prepare the corrective version with consistent numbering (SemVer). Prepare the communication text and the notes (OPS04). Do not run distributions, pushes, tags or releases without an explicit request.

## Decisions to collect

- hotfix or rollback;
- target version and scope of the fix;
- channels and recipients of the communication;
- confirmation before any irreversible step or one that touches shared environments.

## Checks

Compare the plan with the real history of releases and commits, check that the steps are ordered, reversible where possible and testable in a non-production environment, and that the corrective version is compatible with the data already written. State what cannot be verified before distribution.

## Delivery

Reasoned decision, step-by-step plan with verification evidence and points of no return, the proposed change or rollback command, a draft of the communication and notes, residual risks. No distribution performed.

## Related prompts

- OPS04: Prepare release notes and delivery checks.
- OPS01: Prepare and verify distributable packages and artifacts.
- DEV02: Reproduce a defect and fix its cause.
- OPS05: Prepare commits and pull requests with verified scope, message and checks.
