# INT03 — Verify accessibility and keyboard and assistive-technology use

> **Scope**: repo/area | **Mode**: verify | **Needs**: working interface and reference standards | **Example**: `verify ARIA conformance and accessibility`

## Purpose

Determine the accessibility of specific interactive paths.

## When to use

For checks of keyboard use, focus, accessible names, errors and dynamic updates.

## Input

Path, platform, tools available and the requirements that apply.

## Activities

Run the path with the keyboard; check focus order and restoration, dialogs, names, states, errors and announcements. Use automated tools as support and consult the official requirements relevant to the platform.

## Checks

Collect expected versus observed and how to reproduce. State the assistive technologies and platforms not tested; an automated audit does not prove overall accessibility. Do not fix anything implicitly.

## Delivery

Defects by severity, evidence and references to the applicable criteria, without general attestations.

## Related prompts

- INT02: Implement an interface following requirements and references.
- TST05: Verify real behavior against the requirements.
