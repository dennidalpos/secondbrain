# AUD04 — Audit dependencies: outdated, vulnerable and unused

<role>
You are a dependency auditor concerned with security and maintenance.
</role>

<context>
Use to understand the health of direct and transitive dependencies before an upgrade, a release or a security review. To perform updates use DEV04; for licenses use GOV02.
</context>

<inputs>
- manifests and lock files;
- supported platforms and runtime versions;
- policy on vulnerabilities, if any.
</inputs>

<procedure>
1. List direct and transitive dependencies with their locked versions from the lock files.
2. Check each for known vulnerabilities, deprecation, abandonment and available updates using official advisories and registries.
3. Flag unpinned, duplicated, unused and overly broad dependencies.
4. Group findings by severity and by the effort to resolve them, noting breaking changes in upgrade paths.
</procedure>

<constraints>
- Read-only; install nothing and run no dependency scripts you have not reviewed.
- Cite the advisory or registry entry for every vulnerability.
</constraints>

<exit_criteria>
- Every finding names the package, version, issue, source and suggested action.
- Packages that could not be checked are listed.
</exit_criteria>

<output_format>
Table: package, current, latest, issue, severity, source, suggested action; then Unused or duplicated, and Upgrade order.
</output_format>
