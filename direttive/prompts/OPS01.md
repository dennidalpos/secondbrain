# OPS01 — Prepare and verify distributable packages and artifacts

> **Scope**: repo | **Mode**: write | **Needs**: build instructions and package requirements | **Example**: `build a deterministic zip archive and compute its SHA-256`

## Purpose

Produce the artifact the project calls for, in a verifiable way.

## When to use

For builds, packaging, installers and local preparation of a release.

## Input

Target, requested version, runtime, signing and the project's commands.

## Activities

Check manifests, toolchain and prerequisites; run the build and packaging the project provides. Keep official artifacts and separate caches and temporary files. Do not bump versions without a reason or a request.

## Checks

Check contents, version, dependencies and run a smoke test in a suitable environment. Distinguish an artifact that was created, installed and verified.

## Delivery

Artifact paths, version, commands and limits; producing the package does not authorize publishing it.

## Related prompts

- OPS02: Configure pipelines, containers and infrastructure as code.
- OPS04: Prepare release notes and delivery checks.
- OPS06: Prepare a release hotfix and rollback with verification and communication.
