# SYS03 — Activate SecondBrain after discovery and asset selection

> **Scope**: central | **Mode**: write | **Needs**: SecondBrain volume and user consent on the assets | **Example**: `sb prompt SYS03: activate secondbrain selecting local repositories and ides`

## Purpose

Prepare a new Windows workstation or reconcile its assets without preset paths.

## When to use

From SecondBrain, even before local configuration; explicit call sb attiva.

## Input

Current SecondBrain checkout, prerequisites, discovery report and the user's actual choice.

## Activities

Derive the root from the checkout and use the guided script secondbrain.ps1 -Setup: it is the main path, the agent does not write selection.json by hand. First step without -Select: it runs preflight (PowerShell, git, writable .runtime, shared.json, approved directives) and discovery (all fixed volumes without -Roots), saves the report and the per-host selection in .runtime/hosts/<id>/ and ends as a proposal (exit 1, confirmed=false). Show coverage, repos, checkouts, IDEs/profiles and separate environments. Do not treat found data as authorizations. Ask which assets to manage and present the concrete changes; if the environment supports Function Calling or Tool Use (e.g. `ask_question`), use it to present the asset selection in an interactive multiple-choice window. Rerun the same script non-interactively with -Roots, -Select (id, name or path, comma-separated) and any -Ides, -ApproveExistingBlocks after reviewing the managed blocks; add -Yes only after the user's confirmation, which records user, host and date in the selection. Without -Apply it runs the preview; -Apply only for the confirmed scope. Strictly exclude forbidden repositories and external projects. In the generated dossiers apply the minimal-summary rule (key operations, zero verbosity). Identify trackers and memories to migrate; do not replace an existing source with an empty tracker. -Apply registers SECONDBRAIN_HOME (-NoRegisterEnvironment for trials); the distribution of the directives stays separate (-Sync, or -AndSync after the check). The primitives -Discover and -Activate -SelectionPath remain available; do not install monitors. Unapproved texts stay candidates.

## Decisions to collect

- repositories to manage (multiple choice) and roots to examine;
- IDE or agent integrations to bind, with profile and account (multiple choice);
- existing managed blocks to approve and final confirmation before `-Yes` and `-Apply`.

## Checks

Check fingerprint, previous hashes, exclusions, backup, resume and identity. Do not initialize other repos. Tell activated metadata, distributed directives, build output to qualify and actual loading apart.

## Delivery

Local report, selection, managed assets and manual steps or obstacles. No implicit commit or push.

## Related prompts

- SYS01: Check the IDEs; map, register accounts or realign on request.
- SYS04: Check or align the workstation's already managed assets.
- SYS15: Install the SecondBrain MCP server in the IDEs and verify the handshake.
