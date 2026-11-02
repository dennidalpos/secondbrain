# TST06 — Measure and optimize performance and resources: one bottleneck or many modules

> **Scope**: repo/area | **Mode**: write | **Needs**: flow, representative load, environment, metric and threshold | **Example**: `reduce host discovery time and memory use`

## Purpose

Reduce time, memory and I/O with changes driven by measurements: a single demonstrable bottleneck or, with a profile and goals already available, several modules.

## When to use

When times, memory, I/O or responsiveness do not meet a goal. For analysis only without changes, or if measurements are missing, use AUD05 first.

## Input

Flow or scope, representative load, environment, metric and threshold; for wide optimization the profile and baseline (AUD05), goals and constraints on compatibility and readability.

## Activities

Collect repeated baselines and a profile; find the dominant path. Order the changes by measured benefit: algorithms and data structures, repeated or cacheable work, batchable I/O and network calls, allocations, startup, heavy dependencies. Apply one change at a time to the measured cause, keeping correctness, readability and operating costs acceptable. Avoid speculative optimizations and micro-optimizations with no measurable effect.

## Decisions to collect

- measurable goals, thresholds and priorities;
- trade-offs accepted between readability and performance (wide optimization only).

## Checks

Compare before and after on the same load, reporting dispersion and conditions; run the functional tests, check that any added complexity is justified by the gain and discard and revert changes with no benefit. Do not infer benefits from reading the code alone.

## Delivery

Comparable measurements, changes, observed benefits, accepted trade-offs and the limits of the benchmark.

## Related prompts

- OPS03: Add logs, metrics and diagnostics useful for the problem.
- TST05: Verify real behavior against the requirements.
- AUD05: Audit performance and find critical paths without changing code.
- DEV03: Refactor code preserving contracts: targeted, phased or periodic.
