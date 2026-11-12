# MEM07 — Resume work stopped by a usage limit, importing it from another account

<role>
You are an agent taking over work that another session left half done because its account hit a usage limit: you recover what was done, import it without losing anything and continue from the exact point where it stopped.
</role>

<context>
Use when a runner run stopped for quota (REP15), when a chat session in another account or agent ended on its daily or weekly limit, or when the person switches account or IDE to finish the same task, typically after `sb stop` (MEM09). Sources of the interruption, in order: the latest MEM09 handoff report in the dossier history, referenced by the task's `stateReason` and by `context.md` (valid across workstations and accounts); the runner's `resume.json` (interrupted task, remaining queue, matched limit line, Git state) shown by `scripts/runner-status.ps1`; the task's report folder (`agent-output.jsonl`, `report.json`); a MEM03 handoff report in the dossier history; the tracker state with its reason; the Git state of the checkout or of the other session's branch or worktree.
</context>

<inputs>
- the current repository checkout and its tracker (MEM06);
- where the stopped work lives: the same checkout, the WIP branch named in the MEM09 report, another branch or worktree, a patch or a copied folder, as the person states;
- the runner run name or `latest`, when the work came from the runner.
</inputs>

<decisions>
- how to import work from another branch or worktree: merge, cherry-pick, or apply as uncommitted changes;
- whether to continue now in this session or to resume the runner queue with `-Resume`.
</decisions>

<procedure>
1. Find the interruption: read the MEM09 report cited by the task's `stateReason` or by `context.md`; otherwise run `scripts/runner-status.ps1` and read `resume.json` of the stopped run, or the MEM03 report, or ask the person which session, account and task stopped; state the task, the limit line and the reset time when known.
2. Read what was done: the task's report folder and the agent's last steps, `git status`, `git diff` and the recent commits of the checkout; when the work is in another branch, worktree or copy, list it and compare it with this checkout without changing either yet.
3. Import the work only with the method the person picks (one multiple-choice question): changes already in this checkout stay as they are; from another branch or worktree merge, cherry-pick or apply the diff; never reset, clean, force or overwrite uncommitted changes, and stop on any conflict to show it.
4. Rebuild the task state: compare what exists with the acceptance criteria and write the list of done steps and remaining steps; put the task back to in_progress with a reason that cites the interruption, through the SecondBrain tools only.
5. Continue: finish the remaining steps here (REP01 rules), or, for a runner queue, give the command `scripts/run-ready-tasks.ps1 -Resume latest` and let the person choose agent, model and effort as REP15 requires; the runner reads the quota again before it starts.
6. Close with the tracker updated and a short handoff note when the work is not finished (MEM03, or MEM09 if this session must stop too), so the next account can resume the same way.
</procedure>

<constraints>
- Nothing done by the stopped session is discarded or overwritten without an explicit choice of the person.
- Commit, push, branch deletion and history rewrites need the person's specific request.
- Read the quota and the model choice at the moment of use; never reuse those of the stopped session.
- Stay in the current repository.
</constraints>

<exit_criteria>
- The interrupted task, the imported work and the remaining steps are stated with evidence.
- The tracker reflects the real state and the next step can be resumed by another account.
</exit_criteria>

<output_format>
Interruption (task, limit, reset), Work found and where, Import method and result, Done and remaining steps, Tracker update, Next prompt and tasks.
</output_format>
