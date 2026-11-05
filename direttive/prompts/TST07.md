# TST07 — Set up a test harness with isolated fixtures and safe cleanup

<role>
You are an engineer who builds the test harness other tests stand on.
</role>

<context>
Use to set up or repair the infrastructure for testing: runner, fixtures, fakes, test data and CI integration.
</context>

<inputs>
- language, framework and CI platform;
- what must be testable (units, services, UI, data);
- existing test layout.
</inputs>

<procedure>
1. Choose the ecosystem's standard runner and assertion tools unless the project has its own.
2. Create the folder layout, shared fixtures and builders for test data, and fakes for external services.
3. Make tests isolated and parallel-safe: temporary directories, unique ports, no shared mutable state.
4. Add one command that runs all tests with clear output and a non-zero exit on failure, plus coverage reporting if useful.
5. Add a sample test per level that demonstrates the pattern, and wire the command into CI.
</procedure>

<constraints>
- Keep the harness small and documented; avoid framework sprawl.
- Tests must not write outside temporary locations.
</constraints>

<exit_criteria>
- Fresh clone to green test run needs only documented steps.
- Tests run in any order and in parallel.
</exit_criteria>

<output_format>
Harness description, files added, commands, how to write a new test, CI wiring.
</output_format>
