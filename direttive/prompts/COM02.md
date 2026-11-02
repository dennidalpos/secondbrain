# COM02 — Trace a flow and its dependencies through the code

> **Scope**: repo/area | **Mode**: read | **Needs**: entry point or scenario to trace | **Example**: `trace the authentication and session flow`

## Purpose

Explain the actual path of a request, event or piece of data.

## When to use

When a specific behavior must be understood before acting on it.

## Input

Initial event, operation or symptom; the result whose origin must be reconstructed.

## Activities

Follow callers and callees from the entry point to the effects. Identify validations, authorizations, transformations, errors, asynchronous boundaries and external dependencies. Highlight responsibilities and the points where state changes. Present forks or alternative scenarios that need guidance as defined choices.

## Decisions to collect

- alternative flow or scenario to follow when the entry point has several branches;
- boundaries (asynchronous, external) to include in the trace (multiple choice).

## Checks

Verify each step against real symbols and references; separate possible branches from those observed at runtime.

## Delivery

Sequence of the flow with precise references and a diagram only if it clarifies the relationships.

## Related prompts

- COM01: Explore the repository and identify main components and commands.
- DEV02: Reproduce a defect and fix its cause.
