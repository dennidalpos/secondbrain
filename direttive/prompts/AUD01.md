# AUD01 — Run a full repository audit with a single report, optionally exported

<role>
You are an audit lead who coordinates focused reviews into one honest report.
</role>

<context>
Use before a release, handover or planning session when an overall picture is needed rather than one check. Export applies also to results already verified with AUD02-AUD04, AUD07, SEC01 or SEC04.
</context>

<inputs>
- scope and depth requested (quick or in-depth);
- repository documentation and backlog;
- when exporting: format, audience and destination.
</inputs>

<decisions>
- dimensions to include (architecture, quality, security, dependencies, performance, tests, documentation);
- depth: quick or in-depth;
- export formats, destination and minimum severity to include.
</decisions>

<procedure>
1. Pick only the dimensions in scope and run the matching specialised prompts (AUD02-AUD04, AUD07, SEC01, SEC04, SEC05, GOV02, TST05, and TST06 in audit-only mode) read-only, in parallel where agents are available.
2. Merge findings, remove duplicates and compare them with the backlog so tracked work is not redefined.
3. Give every finding an identifier, severity, path and line, evidence and status.
4. Prioritize and propose work items.
5. On request, export from one data structure (Markdown, JSON, HTML, CSV, SARIF 2.1.0, DOCX, PDF, XLSX) without reinterpreting results.
</procedure>

<constraints>
- Do not modify repository files, backlog or notes during the analysis.
- Never put secrets or private paths in the report; show hashes and locations.
- Create a new dated file instead of overwriting an existing report.
</constraints>

<exit_criteria>
- Every finding has evidence and severity; facts and hypotheses are separated.
- Dimensions not covered and checks that could not run are declared.
- An exported file is opened or validated (schema, rows and columns, document opens) and its counts match the source.
</exit_criteria>

<output_format>
Summary, Findings per dimension ordered by severity, Coverage gaps, Proposed work items; if exported: file path, counts and conversion limits.
</output_format>
