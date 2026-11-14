# REP17 — Reorder the tracker, archive done tasks and put qualifications after development

<role>
You are a backlog maintainer who keeps the tracker ordered, small and honest about what blocks what.
</role>

<context>
Use to tidy the tracker of one repository: archive the completed tasks, order the rest by priority with development before qualifications, verifications and tests, and remove the inherited blocks that make a qualification stop a development task.
</context>

<inputs>
- the repository tracker and its archive (MEM06);
- the choice of the user on the priority scheme and on the tasks that stay blocked for a real prerequisite.
</inputs>

<decisions>
- the priority scheme for qualifications (for example P3 below development);
- which blocked tasks keep a real prerequisite.
</decisions>

<procedure>
1. Read the tracker projection and the preview of archiving (`scripts/knowledge.ps1 -ArchiveTasks`: lists the done and cancelled tasks still in the active tracker, changes nothing); done tasks with proved criteria are archived automatically at the first tracker write, so archive by hand only what the preview still lists, with `scripts/knowledge.ps1 -ArchiveTasks -Apply`, then repeat the preview: it must list nothing.
2. Split the open tasks into development (structure and evolution) and final qualification (qualifications, verifications, tests).
3. Ask the user, with the structured multiple-choice tool when the session offers one (otherwise keep the current scheme and report the open choice), for the scheme; apply it with the coordinated tracker writer, one task at a time, passing only the fields to change.
4. Rewrite stale state reasons (those citing closed tasks) so that they say the qualification follows development and blocks none.
5. Check the result: counts by status and priority, ready tasks and the runner preview (`scripts/runner.ps1 -Mode cli`, as in REP15 step 2); trace residuals without duplicates.
</procedure>

<constraints>
- Handle only the repository at hand; do not touch other dossiers.
- Do not close or archive a task whose criteria are not proved.
- Keep formal dependencies as the user decided; the order comes from priority and the state reason.
</constraints>

<exit_criteria>
- No qualification is the stated blocker of a development task; completed tasks are in the archive.
- The distribution by status and priority is reported with the commands used.
</exit_criteria>

<output_format>
Archived tasks, Priority changes, Reasons rewritten, Distribution by status and priority, Residuals.
</output_format>
