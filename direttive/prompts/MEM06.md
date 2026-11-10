# MEM06 — Read memory, context and tracker of the current repository and list its tasks
<role>
You are an agent starting a session: you load the repository's memory within the context budget and no more, and you present its tracker clearly.
</role>
<context>
Use at the start of a session, before planning or before picking the next task in the current repository; also to describe the open tasks and the problems they solve, or to measure the startup package. To compare the tracker with the code use REP08, to execute a task REP01. Other dossiers and PARA entities are out of scope: use MEM05 from SecondBrain.
</context>
<inputs>
- the local repository, its AGENTS.md and the dossier (`context.md`, `memory.md`, `tracker.json`).
</inputs>
<procedure>
1. Resolve the dossier of this repository from `para.json` and `repository.json`; read `index.md`.
2. Load summary context, essential memory and the open-task projection in the lean profile (30,000 characters, first load only); request the rest with `knowledge.ps1 -Startup -Profile Full` or `-Search`.
3. Read the authoritative tracker source declared by `repository.json`, without fallback; create no stubs or redundant memories.
4. Group tasks by status (open, in progress, blocked, done); for each open task summarize the goal, the real problem it solves, acceptance criteria and blocking dependencies; order by priority and show which tasks are ready and which wait to be unblocked.
5. To measure the package run `knowledge.ps1 -Startup -Report` (characters per part, saturation, directive weight); if over the cap plan SYS05.
</procedure>
<constraints>
- Read-only; do not duplicate tasks or treat hypotheses as facts.
- Identifiers must match the tracker schema; cited dependencies must exist.
- Stay in the current repository: do not read other dossiers or global views.
- Load deep dives and history only when needed; keep distributable code apart from internal memories.
- Preserve personal files and unauthorized local differences.
</constraints>
<exit_criteria>
- Dossier paths are valid and not from archives; essential information is not truncated; the tracker is valid.
- Blocked tasks give the real reason; ready tasks are clearly marked.
</exit_criteria>
<output_format>
Summary of repository state, Overview by status ordered by priority (ID, goal, problem solved, dependencies), Ready now, Waiting, constraints, plan for the batch; on request characters per part with saturation.
</output_format>
