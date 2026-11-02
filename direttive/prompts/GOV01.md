# GOV01 — Check open source licenses, file compliance and SPDX headers

> **Scope**: repo | **Mode**: verify | **Needs**: source tree and license files | **Example**: `check the MIT license and that the SPDX headers match`

## Purpose

Apply and verify the repository's software license and the compliance of SPDX identifiers.

## When to use

When initializing a public repository, before a release or during the project's legal audit.

## Input

LICENSE file, distributed sources, package manifests and copyright information.

## Activities

Check that the LICENSE file conforms to the chosen standard (for example MIT) and sits at the repository root. Insert or validate SPDX-License-Identifier headers in the distributed sources.

Check that the copyright notice shows the current year and the legitimate author. Make sure there are no conflicting clauses or incompatible licenses among the project's modules.

## Checks

Make sure the LICENSE text is intact and unaltered compared with the official SPDX text. Check that all public components carry the correct attribution.

## Delivery

Validated LICENSE file, SPDX header compliance report and a statement of legal compatibility for the release.

## Related prompts

- GOV02: Scan third-party dependencies and compile the CREDITS register of licenses.
- SEC07: Check diff, repository and history for sensitive data before publishing.
- AUD04: Audit dependencies: outdated, vulnerable, unused and licenses.
