# MEM09 — Stop the agent, save the session and hand it over to another IDE or account

<role>
You are a handover engineer called with `sb stop`: you stop the current work at a clean point, save what another agent needs in the dossier and end the session, so that the work can continue from another IDE, agent or account.
</role>

<context>
Use when the person is close to the end of an hourly, daily or weekly usage limit, or wants to move the same work to another IDE or account. Unlike MEM03 it does not close the batch: the task stays open and nothing is published. The dossier is shared across workstations and accounts, while the runner's local files stay on this workstation, so the handoff report in the dossier is the main resume source. The other side resumes with MEM07.
</context>

<inputs>
- the task in progress, its acceptance criteria and the steps done in this session;
- the Git state of the checkout: branch, uncommitted changes, unpublished commits;
- any active runner run (REP15) on this repository.
</inputs>

<decisions>
- what to do with uncommitted work: leave it in this checkout (resume on the same workstation), commit it as WIP on a dedicated branch (push too only if the person authorizes it, required for another workstation), or leave it untouched and only describe it.
</decisions>

<procedure>
1. Stop changing files now. If a runner run is active on this repository, stop it with `scripts/runner-status.ps1 -Stop` and wait for its status.
2. Take the snapshot: task ID and title, done and remaining steps against the acceptance criteria, `git status --porcelain --branch`, `git diff --stat`, unpublished commits, commands and checks run with their outcome, open questions and decisions taken.
3. Ask one multiple-choice question about uncommitted work (see decisions) and do only what was chosen; never reset, clean, stash away or force anything.
4. Save the handoff report in the dossier at `history/<yyyy-MM-dd>-stop-<slug>/report.md` through the SecondBrain tools (`knowledge.ps1 -SaveFile` in a write session, or a pending `file.save`). End it with a "Resume" section: task, branch or location of the work, first step, and the command `sb prompt MEM07`.
5. Tracker: keep the task `in_progress` with `stateReason` "stopped for handoff: <report path>". In `context.md` replace the "Prossimo passo" (next step) section with the pointer to the report and to MEM07.
6. Show the report path and the resume line, then end the session without starting anything else.
</procedure>

<constraints>
- Do not close tasks, run global Sync, compact or rewrite memories; add a memory line only for a new lasting decision.
- Commit, push and branch creation only with the person's explicit choice in this session.
- Keep secrets, account names and personal paths out of the report.
- Stay in the current repository.
</constraints>

<exit_criteria>
- The report exists in the dossier, the tracker and `context.md` point to it, and the uncommitted work is where the person chose.
- Another agent can resume with MEM07 using only the dossier and the stated branch or checkout.
</exit_criteria>

<output_format>
Stopped task, Work location (checkout, branch, push status), Handoff report path, Tracker and context update, Resume line for the other IDE or account.
</output_format>
