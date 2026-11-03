# SYS01 — Check the IDEs; map, register accounts or realign on request

> **Scope**: central | **Mode**: verify | **Needs**: IDE installations and local authorizations; to register accounts also an activated workstation and consent | **Example**: `sb prompt SYS01: register an ide with two accounts or two roots`

## Purpose

Check the integration of IDEs and agents with the approved directives and, on request, register the same IDE used with several accounts, profiles or configuration roots as distinct integrations, so that future alignments tell them apart and flag outdated texts.

## When to use

In central maintenance of the workstation; the read-only check is the default case. Registration is needed when an IDE has several accounts (for example the Claude app with two logins) or several roots (for example different `CLAUDE_CONFIG_DIR` or `CODEX_HOME`), or after a new sign-in. With a single account and the default root, SYS03 and the check are enough.

## Input

Local configuration, runtimeRoot, IDE map and the request (check, map, realign or register). For registration: activated workstation, IDEs detected by SYS03 and, for each integration, the alias declared by the user, profile, environment and any path of the instructions file.

## Activities

Check: run `ide-map.ps1 -Verify`. To map, consult official sources and installed surfaces; to realign, use only the approved global text, verified backups and preservation of personal text. The monitor does not detect IDEs and does not write their files. Use SYS03 for discovery and selection. Distinguish installation, profile, environment and account; record a local alias, observed revision/hash and proof of loading. A new account identity invalidates the earlier finding. A file aligned to a revision can coexist with older account instructions: flag the mismatch. Account alignment is assisted only if authorized and possible; no login automation. Surfaces not observed stay unverified; exit 0 on files does not certify accounts.

Registering several accounts or roots: show the disclaimer first and proceed only after confirmation (SecondBrain does not detect accounts or read authentication stores: the account is declared by the user and proved by an observation receipt; `.runtime` is not published). Check the state with `secondbrain.ps1 -Setup -Status`, collect the decisions and register them with the guided script, without writing selection.json by hand: `secondbrain.ps1 -Setup -IdeAccount "id-or-name|alias[|profile=..|environment=..|path=..|revision=..|hash=..]"`, several entries separated by `;`. `path` applies only to file-type IDEs, absolute, under the user profile and with the expected file name; entries with the same profile, alias, environment and path are duplicates and are rejected. Without -Apply it runs the preview; `-Yes` and `-Apply` only after the final confirmation. Retire an outdated sign-in with `-Unbind <id>` (the IDE's files stay). For manual surfaces without a file (for example the Claude account instructions) the update is assisted: the user pastes the approved text from `runtimeRoot/istruzioni-globali.md`, saves, reloads and rereads the hash; record revision and hash with `revision=` and `hash=` and keep the receipt in `.runtime`.

## Decisions to collect

- operation: check, map, realign or register;
- IDE to register, number of accounts or roots, alias, profile and environment of each integration;
- path of the instructions file of each alternative root (file-type IDEs only);
- confirmation of the disclaimer and final confirmation before `-Yes` and `-Apply`.

## Checks

Repeat the check after the authorized writes with `ide-map.ps1 -Verify` and `secondbrain.ps1 -Check`: each integration appears with id and alias and an observed text different from the approved one is `ide-directive-stale` (observed and expected revision). Distinguish an aligned file, an observed account text, loading in a new session and unobserved manual surfaces.

## Delivery

Outcomes per IDE, evidence and manual steps; for registration, the integrations registered (id, alias, profile, environment, path) and receipts. exit 0 does not certify loading. No implicit commit or push.

## Related prompts

- MEM01: Align local instructions, context, memory and tracker.
- SYS02: Check authoritative sources; acquire or update on request.
- SYS03: Activate SecondBrain after discovery and asset selection.
- SYS04: Check or align the workstation's already managed assets.
- SYS15: Install the SecondBrain MCP server in the IDEs and verify the handshake.
