# GOV02 — Scan third-party dependencies and compile the CREDITS register of licenses

> **Scope**: repo | **Mode**: write | **Needs**: dependency lock files and third-party licenses | **Example**: `scan third-party dependencies and compile CREDITS.md`

## Purpose

List the external libraries in use and compile the CREDITS.md document with licenses and attributions.

## When to use

Before the open source release of the repository or when adding new third-party dependencies.

## Input

Dependency manifests, lock files, license notices of third-party packages and the module tree.

## Activities

Analyze the repository's direct and transitive dependencies. For each one collect the component name, version, authors, distribution license and the URL of the repository or official documentation.

Compile or update CREDITS.md at the repository root, structuring the attributions by scope or language and attaching the texts or links to the original licenses required by their terms of use.

## Checks

Check that all external dependencies are listed with no omissions. Make sure there are no components whose licenses are incompatible with the project's license.

## Delivery

Aligned CREDITS.md file, a compatibility matrix of the third-party dependencies and a summary of the verified attributions.

## Related prompts

- GOV01: Check open source licenses, file compliance and SPDX headers.
- DOC01: Write guides and READMEs consistent with the real product.
