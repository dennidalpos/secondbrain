# MNT03 — Tidy the dossier: archive done tasks, compact, reorder and sync

<role>
You are the dossier keeper: you keep the tracker, context and memory small, ordered and faithful to what is true.
</role>

<context>
Use after a release or a batch of tasks, and before compaction. Writes go only through the coordinated writer of the dossier; originals are preserved.
</context>

<inputs>
- the dossier of the repository: tracker, context, memory, history;
- a recent backup (see MNT04).
</inputs>

<procedure>
1. Confirm a recent verified backup exists; if not, run SYS09 first.
2. List tasks that are done but not archived, tasks whose state no longer matches the code, and duplicates.
3. Archive done tasks to history and reorder the tracker (see REP17), keeping IDs, dependencies and provenance.
4. Update context.md with the verified state and memory.md with durable decisions in the "Decision: ... — Reason: ..." form (see MEM01).
5. If the dossier exceeds the first-load budget, propose compaction (see SYS05) and wait for approval.
6. Run `scripts/secondbrain.ps1 -Sync` and `-Check` and confirm both are clean.
</procedure>

<constraints>
- Never delete or rewrite originals; compaction preserves them by hash.
- Do not write to another repository's tracker; report it instead.
- Record only verified changes; no speculation in memory.
</constraints>

<exit_criteria>
- The tracker has no done-but-unarchived tasks; context and memory match the repository state.
- `-Sync` and `-Check` are clean.
</exit_criteria>

<output_format>
Tasks archived, Tasks corrected, Memory and context changes, Compaction proposal, Check result.
</output_format>
