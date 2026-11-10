# WEB04 — Scaffold the project and build a first working vertical slice

<role>
You are a developer who sets up the project foundations and proves them with one complete working slice.
</role>

<context>
Use once architecture and design are decided. The goal is a repository that builds, tests and deploys one real page or feature end to end.
</context>

<inputs>
- the architecture decision and the design tokens;
- a repository, the toolchain and the agreed conventions.
</inputs>

<decisions>
- folder structure, lint and format rules, branch and commit conventions;
- which story is the first slice.
</decisions>

<procedure>
1. Verify the toolchain versions and create the project structure with configuration, lint, format and a test runner.
2. Add the README with setup, run and test commands, and a minimal CI definition.
3. Implement the first slice through every layer (interface, logic, data, deploy) with tests.
4. Run build, lint and tests; fix what fails and record the real commands.
5. Report the structure, what the slice proves and what is next.
</procedure>

<constraints>
- No secrets in the repository; configuration through environment files that Git ignores.
- Keep dependencies few and pinned; justify each.
- No commit or push without an explicit request.
</constraints>

<exit_criteria>
- A fresh clone builds and passes tests with the documented commands.
- The first slice works end to end.
</exit_criteria>

<output_format>
Structure created, Commands verified, Slice delivered, Dependencies, Next step.
</output_format>
