# MEM08 — Start a session: context, repository state, alignment and next tasks

<role>
You are an agent opening a work session: you find where you are, report the real state of the repository and its SecondBrain alignment, and propose what to do next, all read-only.
</role>

<context>
The standard opening chain, whatever the folder: `sb prompt` (`scripts/prompts.ps1`) detects the location (a managed repository, a repository not onboarded, the SecondBrain checkout, or no project) and this card adapts to it. A repository works without onboarding; then the dossier functions are missing (startup context and memory, tracker and ready tasks, runner, handoff reports, managed instruction sync, authoritative sources) and you say so instead of failing. Onboarding is optional and done only on request (SYS03).
</context>

<inputs>
- the current folder and, when it is a Git checkout, its branch, remote and recent history;
- the location reported by `scripts/prompts.ps1` (home) and, for a managed repository, its dossier.
</inputs>

<procedure>
1. Run `scripts/prompts.ps1` from the current folder and report the location and the command groups it shows: repository commands, and SecondBrain activation and maintenance commands.
2. Repository state from Git: branch and tracking, uncommitted changes, last commits, open worktrees; for a repository not onboarded also its manifests, build and test commands (COM01).
3. Managed repository: load context, memory and ready tasks (MEM06); if the runner left a `resume.json` or a task was interrupted by a usage limit, say so and point to MEM07.
4. Alignment, only for a managed repository or the SecondBrain checkout: run `scripts/secondbrain.ps1 -Check` and report only the findings that concern this repository (instruction block, dossier, IDE files, compaction advice); a clean result is stated in one line. Changes go to SYS04 on request.
5. Propose two to four next steps as one multiple-choice question: ready tasks by priority (REP01), the runner for autonomous ones (REP15), the resume (MEM07) or the onboarding (SYS03) when they apply, each with its prompt code.
</procedure>

<constraints>
- Read-only: no writes to the repository, the dossier or the workstation.
- Report missing functions without onboarding as limits, not as errors.
- Stay in the current repository.
</constraints>

<exit_criteria>
- The location, the Git state and, when managed, the tracker and the alignment are reported with their source.
- The session ends with the proposed next prompt and tasks.
</exit_criteria>

<output_format>
Location and available commands, Repository state, Tracker and ready tasks (or the functions missing without onboarding), Alignment, Next steps (multiple choice with prompt codes).
</output_format>
