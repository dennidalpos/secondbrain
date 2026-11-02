# OPS02 — Configure pipelines, containers and infrastructure as code

> **Scope**: repo | **Mode**: write | **Needs**: deployment requirements and target environment | **Example**: `configure a multi-stage Dockerfile for a reproducible build`

## Purpose

Make an operational procedure repeatable within the authorized scope.

## When to use

To create or change CI/CD, container or infrastructure configuration.

## Input

Provider, environments, commands, resources and authorization boundaries.

## Activities

Reuse tools and conventions; define inputs, dependencies, caches, minimal permissions and secret handling. Keep the environments and the effects of each stage explicit.

## Checks

Validate syntax and semantics with real tools; use plan or dry-run where available and check relevant idempotence. Configuring a pipeline does not authorize a deploy or apply on real environments.

## Delivery

Configurations, local evidence, a plan of the effects and the operational steps still to be authorized.

## Related prompts

- OPS01: Prepare and verify distributable packages and artifacts.
- TST04: Diagnose and fix build and test failures in CI.
- SEC06: Harden repository configuration, CI, containers and access.
