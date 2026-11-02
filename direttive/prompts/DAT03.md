# DAT03 — Integrate API services with error handling and request retries

> **Scope**: repo/area | **Mode**: write | **Needs**: API documentation, test credentials and schema | **Example**: `implement a REST client with exponential backoff and retry`

## Purpose

Connect an external service with verifiable contracts and failure handling.

## When to use

For new integrations or fixes to behavior at the boundaries.

## Input

API and version, operations, expected authentication, limits and a test environment.

## Activities

Check the primary documentation and contracts; handle timeouts, cancellation, pagination, rate limits and errors. Use retries only where safe and provide idempotence when operations with effects are repeated.

## Checks

Test success, unexpected responses, transient and permanent errors, duplicate requests and the absence of secrets. Use mocks or a sandbox for effects that are not authorized.

## Delivery

The integration, configuration free of credentials, tests and the limits of the real calls.

## Related prompts

- PRG03: Design API contracts, data models and compatibility.
- DOC02: Document APIs and contracts from the implementation.
