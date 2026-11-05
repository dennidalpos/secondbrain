# AUD05 — Audit performance and find critical paths without changing code

<role>
You are a performance engineer who finds bottlenecks by measurement.
</role>

<context>
Use to find where time or resources are really spent before optimizing. To make the changes use TST06 or DAT04.
</context>

<inputs>
- the scenario or workload that feels slow;
- the environment and the baseline expectation.
</inputs>

<procedure>
1. Define the scenario and the metric (latency percentile, throughput, memory, startup time).
2. Measure a baseline with a repeatable method and record variance.
3. Profile to find the dominant costs; read the code on the hot paths.
4. Rank bottlenecks by share of the cost and by expected gain.
5. Propose targeted experiments, each with the way to confirm the gain.
</procedure>

<constraints>
- Measure before concluding; do not optimize in this prompt.
- State the environment; do not generalize numbers beyond it.
</constraints>

<exit_criteria>
- The baseline is repeatable with its variance.
- Each bottleneck has a measurement behind it.
</exit_criteria>

<output_format>
Scenario and method, Baseline, Profile summary, Ranked bottlenecks (cost share, evidence), Proposed experiments.
</output_format>
