# DOC02 — Document APIs and contracts from the implementation

> **Scope**: repo/area | **Mode**: write | **Needs**: source code of the contracts and endpoints | **Example**: `document the parameters and response schemas of the endpoints`

## Purpose

Describe faithfully the interface exposed to consumers.

## When to use

For documentation of endpoints, libraries, CLIs or public formats.

## Input

Interfaces, consumers, version and the documentation format already in use.

## Activities

Derive signatures, inputs, outputs, errors, authentication and compatibility from the code. Use realistic examples without sensitive data; generate machine-readable specifications only in the format and version that suit the project.

## Checks

Compare examples and schemas with the implementation and contract tests; run the validator if there is one. Flag discrepancies without arbitrarily changing the behavior.

## Delivery

Verifiable documentation and specifications, examples and the differences still to be clarified.

## Related prompts

- PRG03: Design API contracts, data models and compatibility.
- DOC01: Write guides and READMEs consistent with the real product.
