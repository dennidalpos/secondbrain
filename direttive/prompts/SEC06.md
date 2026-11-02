# SEC06 — Harden repository configuration, CI, containers and access

> **Scope**: repo/area | **Mode**: write | **Needs**: configuration, CI workflows, containers and repository settings | **Example**: `harden the GitHub Actions workflows and containers`

## Purpose

Reduce the attack surface of the repository and of its build and release chain with verifiable configurations and least privilege.

## When to use

Before making a repository public, before a release, after an incident and periodically.

## Input

Configurations, CI workflows, Dockerfiles and infrastructure as code, repository settings, permissions and the secrets used.

## Activities

Check the minimal permissions of workflows (`permissions`), third-party actions pinned to commit hashes, risky triggers such as `pull_request_target`, the use of secrets, base images and the non-privileged user in containers, branch protection, required reviews, signing of commits and tags, secret scanning with push protection, dependency locks and the security settings of frameworks. Declare surfaces that are absent as not applicable (for example no workflow or tracked container) without inventing work. To pin actions and images resolve hashes and digests with read-only remote lookups (for example `gh api repos/<owner>/<repo>/commits/<ref> --jq .sha`); if a reference cannot be resolved, leave it as is, flag it as not pinned and do not invent hashes. Show the difference and the operational impact before changing anything. Remote settings (branch protection, secret scanning) are proposed with their commands and applied only with explicit authorization. Do not change system or security settings of the machine.

## Decisions to collect

- surfaces to harden (multiple choice: CI, containers, branches, secrets);
- apply the changes or only propose them.

## Checks

Run the relevant local pipeline and checks after the changes and verify that no fix blocks legitimate work; if tools are missing (for example `actionlint`, `hadolint`, `docker`), declare the check as not run instead of inferring its outcome. Distinguish actual risk from generic recommendations and do not claim conformity to a standard without specific checks.

## Delivery

Measures applied or proposed with evidence, residual risk and manual steps.

## Related prompts

- SEC04: Find exposed credentials and verify input validation.
- OPS02: Configure pipelines, containers and infrastructure as code.
- SEC03: Fix vulnerabilities and strengthen the affected defenses.
