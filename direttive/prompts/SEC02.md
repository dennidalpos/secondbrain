# SEC02 — Analyze threats, trust boundaries and abuse scenarios

> **Scope**: repo | **Mode**: read | **Needs**: architecture and data flows toward the outside | **Example**: `threat model of the stdio and local file system flows`

## Purpose

Identify security risks tied to the real flows.

## When to use

Before designing defenses or when data, privileges or integrations change.

## Input

Assets, users, roles, entry points, data and system scope.

## Activities

Reconstruct flows and trust boundaries; assess actors, capabilities, abuse scenarios and the controls observed. Prioritize by impact and evidence without inventing a certification.

## Checks

Link each risk to a point in the system and distinguish a control that is verified, missing or cannot be established. Stay with analysis only.

## Delivery

Threat model, priority scenarios, evidence and proposed mitigations.

## Related prompts

- COM04: Assess the impact, risks and dependencies of a change.
- SEC03: Fix vulnerabilities and strengthen the affected defenses.
