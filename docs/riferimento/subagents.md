# Subagent definitions (F8)

One versioned format describes a subagent: role, initial context, permissions and the SecondBrain MCP tools it may call. Definitions are dossier assets, exported per client, and their jobs enter the [activity register](activity-register.md) with a reference to the parent agent. Development status: implemented and verified on synthetic fixtures; no live client has loaded an exported definition yet (the export marks `liveVerified=false`).

## Definition (schemaVersion 1)

Stored as `<dossier>/subagents/<name>.json`; the file name must equal `name` (`^[a-z0-9][a-z0-9-]{0,63}$`). Unknown fields, foreign files in the folder and unknown tools are errors.

| Field | Meaning |
|---|---|
| `schemaVersion` | `1` |
| `name`, `description` | Identity and one-line purpose (up to 8192 characters) |
| `role`, `context` | System role and initial context text |
| `permissions.tools` | Allowed MCP tools: `get_startup_context`, `get_ready_tasks`, `get_task`, `search_knowledge`, `list_prompts`, `get_prompt_home`, `get_prompt`, `check_publication`, `preview_dossier_write`, `submit_dossier_write` |
| `permissions.write` | `true` only to list the write tools; it carries no authorization |

## Permissions never exceed the parent

`Resolve` intersects a definition with the parent's tools and write flag. A tool or write flag the parent lacks is an error, never trimmed silently. Even with `write=true` on both sides, writes go through the parent's reviewed MCP write path (preview, plan hash, approval: F5); a definition cannot hold a permit.

## Commands

    pwsh -NoProfile -File scripts/subagents.ps1 -Operation Validate -Repository <identity>
    pwsh -NoProfile -File scripts/subagents.ps1 -Operation Resolve -Repository <identity> [-ParentTools <tools>] [-ParentWrite]
    pwsh -NoProfile -File scripts/subagents.ps1 -Operation Export -Repository <identity> -Client claude-code -OutputPath .runtime/export/agents [-Apply]

`Export` previews unless `-Apply`, writes only under `.runtime` and never into a checkout: copy the package where the client expects it. `claude-code` produces `.claude/agents/<name>.md` with only the allowed `mcp__secondbrain__*` tools; other clients get the normalized JSON until their native format is verified with the adapters of the [memory cycle](memory-cycle.md). Without `-ParentTools` the parent is read-only with all read tools.

## Register

Subagent jobs are ordinary records with two extra fields, `parent` (the parent's `session`) and `agent` (the definition name). They go together, require `source=mcp`, and the parent session must already be in the register for the same repository, otherwise the append is rejected. Build them with `New-SBSubagentActivityRecord`; appending still needs `activityLogEnabled` (activation: #348).
