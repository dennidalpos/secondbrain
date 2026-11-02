# AUD02 — Measure the repository with reproducible metrics and find hotspots

> **Scope**: repo/area | **Mode**: read | **Needs**: read access to the repository, its Git history and measurement tools | **Example**: `metrics and hotspots of the repository`

## Purpose

Quantify size, complexity, duplication, change over time and coverage of the repository with reproducible measurements.

## When to use

To get an objective baseline before refactoring, optimization or planning, and to compare two points in time.

## Input

Scope (paths and languages), Git history range and the measurement tools the project already uses.

## Activities

Use the project's tools or `git` and standard utilities already present; do not install dependencies without authorization. Measure files and lines per language, cyclomatic complexity and long functions, duplication, change per file (churn) and hotspots (frequent changes in complex code), contributors per area, test coverage, number and age of dependencies, size of tracked binaries and artifacts. Record the command, tool version and date of every measurement.

## Decisions to collect

- scope and languages;
- history range to analyze.

## Checks

Repeat each measurement to verify its stability; exclude generated files, vendor code and fixtures and say so; do not compare values obtained with different tools or thresholds.

## Delivery

Metrics table with method and scope, ranked hotspots, proposed thresholds (to be confirmed) and limits; exportable with AUD01.

## Related prompts

- AUD01: Run a full repository audit with a single report, optionally exported.
- DEV08: Review readability, consistency and maintainability without changing code.
