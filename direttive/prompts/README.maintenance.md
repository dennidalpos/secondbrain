# Prompt catalog — SecondBrain maintenance

Index generated from catalog.json and the Markdown cards with scripts/build-prompts.ps1. Do not edit this index by hand.

In the chat: `sb prompt`, `sb prompt list`, `sb prompt maintenance`, `sb prompt ambito test`, `sb prompt mostra TST04`, `sb prompt TST04: description`. Every prompt has an immutable ID (`pmt-` and 8 hex digits) and one or more aliases (code included): ID and aliases resolve to the same prompt.

SecondBrain maintenance prompts (memory, dossier, workstation, backup): they require SecondBrain as the working repository. Index of the generic prompts: [README.md](README.md).

The CLI composes text; the task is carried out by the agent within the permissions and mode of the session. [How to use and edit the prompts](../../docs/prompt.md). Language: [English](README.md) · [Italiano](README.it.md).

```text
Prompt catalog — SecondBrain maintenance
Legend: 🔭 reads · ✅ verifies · 🔥 writes · ⛔ destructive/irreversible

MEMORY AND CONTINUITY
🔥 MEM01 | Align local instructions, context, memory and tracker.
  • ID: pmt-f02db9d0
  • Scope: repo/area | Mode: write
  • Needs: recent decisions or changes not yet recorded
  • Example: sb prompt MEM01: align context.md and memory.md after completing a task

🔥 MEM02 | Migrate design and tasks into the SecondBrain dossier.
  • ID: pmt-64dfa49f
  • Scope: repo/area | Mode: write
  • Needs: historical documentation or external issues to migrate
  • Example: sb prompt MEM02: migrate scattered todos into the dossier's central tracker

🔥 MEM03 | Close the session: memories, tracker, handoff and commit and push request.
  • ID: pmt-76604e4a
  • Scope: repo/area | Mode: write
  • Needs: state of the work done, defined next tasks and delivery destination
  • Example: sb prompt MEM03: close the session and ask for commit and push

🔭 MEM04 | List and describe the tracker tasks and the problems they solve.
  • ID: pmt-23c3d2be
  • Scope: repo/area | Mode: read
  • Needs: repository dossier tracker
  • Example: sb prompt MEM04: list the tracker tasks and problems

🔥 MEM05 | Create, update and archive projects, areas and resources of the central PARA.
  • ID: pmt-4e1b7c52
  • Scope: central | Mode: write
  • Needs: goal of the PARA entity and a write session on the SecondBrain clone
  • Example: sb prompt MEM05: archive the finished resource res-guida

🔭 MEM06 | Read active memory, context and tracker of the current repository.
  • ID: pmt-821f7dec | Aliases: SYS06
  • Scope: repo | Mode: read
  • Needs: checkout of the open repository
  • Example: sb prompt MEM06: load the repository context and memory within budget


CENTRAL SYSTEM AND MAINTENANCE
✅ SYS01 | Check the IDEs; map, register accounts or realign on request.
  • ID: pmt-26817a61
  • Scope: central | Mode: verify
  • Needs: IDE installations and local authorizations; to register accounts also an activated workstation and consent
  • Example: sb prompt SYS01: register an ide with two accounts or two roots

✅ SYS02 | Check authoritative sources; acquire or update on request.
  • ID: pmt-5b593404
  • Scope: central | Mode: verify
  • Needs: PARA resource-authoritative-sources registry
  • Example: sb prompt SYS02: check regulatory updates in the sources registry

🔥 SYS03 | Activate SecondBrain after discovery and asset selection.
  • ID: pmt-5f9f93e0
  • Scope: central | Mode: write
  • Needs: SecondBrain volume and user consent on the assets
  • Example: sb prompt SYS03: activate secondbrain selecting local repositories and ides

✅ SYS04 | Check or align the workstation's already managed assets.
  • ID: pmt-677a10ab
  • Scope: central | Mode: verify
  • Needs: workstation configuration and approved directives
  • Example: sb prompt SYS04: check directive alignment in the managed repositories

🔥 SYS05 | Compact the dossier preserving originals, facts and TOC.
  • ID: pmt-77d7bf7a
  • Scope: central | Mode: write
  • Needs: dossier to compact and verifiable history
  • Example: sb prompt SYS05: compact the dossier history preserving facts and toc

🔥 SYS09 | Run the deterministic compressed backup and verify the SHA-256 digests.
  • ID: pmt-e498353a
  • Scope: central | Mode: write
  • Needs: active configuration and backup runtime root
  • Example: sb prompt SYS09: run a deterministic backup and validate the sha-256 manifest

⛔ SYS10 | Roll back and decommission a repository, returning its data for privacy.
  • ID: pmt-b98acaaa
  • Scope: central | Mode: write
  • Needs: repository dossier, target checkout and user consent
  • Example: sb prompt SYS10: roll back the decommissioned repository and clean up the data

🔥 SYS11 | Add, change or remove a prompt of the centralized catalog.
  • ID: pmt-364616bb
  • Scope: central | Mode: write
  • Needs: valid catalog, target area and a write session
  • Example: sb prompt SYS11: add a prompt to the catalog in the test area

🔥 SYS13 | Set or remove the greenfield lock (versions, changelog, migrations, aliases).
  • ID: pmt-29b3278f
  • Scope: repo/area | Mode: write
  • Needs: managed repository, active dossier and user confirmation
  • Example: sb prompt SYS13: set or remove the greenfield lock on this repository

🔥 SYS15 | Install the SecondBrain MCP server in the IDEs and verify the handshake.
  • ID: pmt-2d3c1d51
  • Scope: central | Mode: write
  • Needs: SecondBrain root, target IDEs and confirmation before writing
  • Example: sb prompt SYS15: install the mcp server in vscode and claude code

🔥 SYS16 | Update a skill from authoritative sources and verify the diff.
  • ID: pmt-9ef61b3d
  • Scope: central | Mode: write
  • Needs: identified skill, target agent and version, official sources
  • Example: sb prompt SYS16: update the local skill from official sources

```
