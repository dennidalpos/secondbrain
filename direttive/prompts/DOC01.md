# DOC01 — Write guides and READMEs consistent with the real product

> **Scope**: repo | **Mode**: write | **Needs**: implemented features, verified commands and approved screenshots | **Example**: `update the guides and add Mermaid flow diagrams`

## Purpose

Write or update guides, READMEs and flow diagrams that describe only what the product really does, for the stated audience, with verified commands and examples.

## When to use

For user or maintainer guides, onboarding material or a README to create or update.

## Input

Audience, intended use, existing documents and the parts to document.

## Activities

Verify commands, configuration and behavior against the real files. Write task-oriented instructions, examples without secrets and the real prerequisites. Update the curated source rather than generated output.

Add flow and architecture diagrams in Mermaid (`flowchart TD/LR`, `sequenceDiagram`, `stateDiagram-v2`, `classDiagram`) directly in the Markdown to show the module architecture, call sequences, life cycles or data pipelines observed in the real code. Follow standard Mermaid syntax compatible with GitHub and IDEs (for example quoted labels for special characters in nodes, no unsupported HTML tags).

For a GitHub README prepare purpose, usefulness, real features, screenshots, quick start, prerequisites, limits and support. Reuse the existing visual identity without inventing capabilities or badges, use relative paths and alt text, put only the selected public assets in docs/assets and keep evidence and drafts out of the repository. For screenshots use DOC03. Legitimate public attributions must not be removed indiscriminately. No publication or upload without a specific request; GitHub Pages is excluded unless requested.

Keep reports and personal data out of public guides: they must not contain private paths or information.

## Checks

Verify links, commands and that the Mermaid diagrams render correctly in a compatible environment; distinguish verified examples from illustrative ones. For the README also check the rendered Markdown, the images, light/dark mode where applicable and the badges, and run SEC07, stating what you could not render or test. Do not rewrite history or notes for a simple guide.

## Delivery

Updated documents (README included), verified Mermaid flow diagrams, an actual preview, the sources of the information, the audiences covered and the checks with their limits.

## Related prompts

- DOC02: Document APIs and contracts from the implementation.
- SEC07: Check diff, repository and history for sensitive data before publishing.
- DOC03: Capture real screenshots and prepare public assets.
