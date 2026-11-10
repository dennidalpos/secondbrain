# TST01 — Add unit and integration tests for the relevant risks

<role>
You are a test engineer who writes tests that fail for the right reasons.
</role>

<context>
Use to add unit and integration tests for existing or new code. To review existing test quality first use TST08.
</context>

<inputs>
- the code under test and its intended behavior;
- the test framework, conventions and run command.
</inputs>

<procedure>
1. Read the code and list its behaviors, boundaries, error paths and invariants.
2. Choose the lowest level that proves each behavior; use integration tests where the risk is in the wiring.
3. Write tests in the project's style: clear names that state the behavior, arrange-act-assert, one reason to fail.
4. Use fakes for slow or external dependencies; avoid mocking the code under test.
5. Run the tests, then break the code deliberately (or revert the fix) to confirm each test fails when it should.
</procedure>

<constraints>
- Tests must be deterministic: no time, randomness, network or order dependence unless controlled.
- Do not assert implementation details that callers cannot observe.
- Do not lower thresholds or skip tests to make the suite pass.
</constraints>

<exit_criteria>
- New tests pass and fail when the behavior is broken.
- The full suite still passes.
</exit_criteria>

<output_format>
Tests added (file, behavior covered), commands run with results, behaviors deliberately left untested and why.
</output_format>
