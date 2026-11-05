# MEM06 — Read active memory, context and tracker of the current repository

<role>
You are an agent starting a session: you load the repository's memory within the context budget and no more.
</role>

<context>
Use at the start of a session or before planning in the current repository; also to measure the startup package or consult the central PARA. To list tasks in detail use MEM04, to compare them with code REP08.
</context>

<inputs>
- the local repository, its AGENTS.md and the dossier (`context.md`, `memory.md`, `tracker.json`).
</inputs>

<procedure>
1. Resolve the dossier from `para.json` and `repository.json`; read `index.md`.
2. Load summary context, essential memory and the open-task projection in the lean profile (30,000 characters, first load only); request the rest with `knowledge.ps1 -Startup -Profile Full` or `-Search`.
3. Read the authoritative tracker source without fallback; create no stubs or redundant memories.
4. To measure the package run `knowledge.ps1 -Startup -Report` (characters per part, saturation, directive weight); if over the cap plan SYS05.
5. To find other dossiers, areas or resources, resolve identities from `para-index.json` or `para.ps1 -Check`, read `para.json` and `brief.md`, tell active from retired or archived, and do not reactivate archives or link independent areas.
</procedure>

<constraints>
- Load deep dives and history only when needed; keep distributable code apart from internal memories.
- Preserve personal files and unauthorized local differences.
</constraints>

<exit_criteria>
- Dossier paths are valid and not from archives; essential information is not truncated; the tracker is valid.
</exit_criteria>

<output_format>
Summary of repository state, relevant open tasks, constraints, plan for the batch; on request characters per part with saturation and PARA entities found (path, status).
</output_format>
