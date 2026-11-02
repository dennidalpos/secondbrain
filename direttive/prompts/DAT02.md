# DAT02 — Build imports and transformations that preserve the originals

> **Scope**: repo/area | **Mode**: write | **Needs**: source files, target model and validation rules | **Example**: `import the catalog from CSV to JSON preserving the originals`

## Purpose

Produce usable data from heterogeneous inputs with clear provenance.

## When to use

For imports, normalization, deduplication or requested conversions.

## Input

Formats, samples, expected schema, quality rules and destination.

## Activities

Analyze the originals without modifying them; define the mapping and the handling of errors. Distinguish accepted, transformed and rejected records; preserve provenance, numeric precision and relevant encodings.

## Checks

Test malformed inputs, duplicates, boundary values and re-runs. Compare records and totals; never drop anomalies silently.

## Delivery

Output, rules applied, justified rejections and a reconciliation with the originals.

## Related prompts

- DAT01: Migrate schema and data with verifiable comparison and recovery.
- DAT03: Integrate API services with error handling and request retries.
