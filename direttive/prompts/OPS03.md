# OPS03 — Add logs, metrics and diagnostics useful for the problem

> **Scope**: repo/area/file | **Mode**: write | **Needs**: scenario to monitor and logging standards | **Example**: `add structured JSON logging`

## Purpose

Make a behavior observable without exposing sensitive data.

## When to use

For errors that are hard to reconstruct or when useful operational signals are missing.

## Input

Diagnostic question, flow, existing signals and constraints on the data.

## Activities

Choose events, correlation identifiers and measurements that answer the question. Avoid secrets, personal payloads and uncontrolled cardinality. Integrate existing tools without imposing a vendor.

## Checks

Generate success and failure scenarios; verify the usefulness, redaction and cost of the signals. Do not connect systems or change production monitors implicitly.

## Delivery

Signals added, sanitized examples, evidence and how to use them for diagnosis.

## Related prompts

- DEV02: Reproduce a defect and fix its cause.
- TST06: Measure and optimize performance and resources: one bottleneck or many modules.
- COM05: Analyze logs and incidents to find the root cause, without changing code.
