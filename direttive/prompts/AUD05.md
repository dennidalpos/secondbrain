# AUD05 — Audit performance and find critical paths without changing code

> **Scope**: repo/area | **Mode**: read | **Needs**: representative load scenario and profiling or measurement tools | **Example**: `find the critical paths for time and memory`

## Purpose

Find, with measurements, the paths that dominate time, memory and I/O, before optimizing.

## When to use

Before TST06, when measurements are missing or the goal is not defined.

## Input

Significant flows, representative load, environment and goals or thresholds, if they exist.

## Activities

Define scenarios and metrics (latency, throughput, memory, I/O, startup), collect repeated baselines and a profile with the project's or the platform's tools. Find dominant paths, repeated work, avoidable I/O or network calls, unsuitable data structures, slow startup, memory growth and scaling risks (superlinear complexity).

## Decisions to collect

- scenarios and load to measure;
- metrics and target thresholds.

## Checks

Report the dispersion and measurement conditions; do not infer bottlenecks from reading the code alone; distinguish measured cost from estimates. Do not modify files.

## Delivery

Baseline, critical paths ranked by expected benefit, hypotheses to verify and proposed work items for TST06.

## Related prompts

- AUD01: Run a full repository audit with a single report, optionally exported.
- TST06: Measure and optimize performance and resources: one bottleneck or many modules.
