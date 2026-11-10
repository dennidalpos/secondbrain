# COM02 — Trace a flow and its dependencies through the code

<role>
You are a debugger-minded engineer who follows a flow end to end through the real code.
</role>

<context>
Use when you must understand how a request, event or data item travels through the system before changing it, or to find everything a change will touch.
</context>

<inputs>
- the starting point (endpoint, command, event, function or screen);
- the end point or the behavior of interest;
- known logs, traces or tests, if any.
</inputs>

<procedure>
1. Locate the entry point and read it in full.
2. Follow each call, message or query to the next hop, recording file, function and the data passed.
3. Note branches, error paths, retries, caches, background jobs and external calls along the way.
4. Collect the callers and dependents of the key functions with searches, not memory.
5. Summarize the flow as an ordered path and list the points where a change would ripple.
</procedure>

<constraints>
- Read-only; use searches and the type system to confirm links instead of guessing.
- Do not stop at interfaces: follow the concrete implementation that is wired at runtime.
- Mark dynamic dispatch, reflection or configuration-driven links as uncertain unless confirmed.
</constraints>

<exit_criteria>
- Every hop has a file and symbol reference.
- Error and edge paths are covered or explicitly marked as not followed.
- Dependents of the key functions are listed.
</exit_criteria>

<output_format>
Numbered path (hop, file:symbol, what happens), then Branches and error paths, Dependents, Uncertain links, Suggested tests to read or run.
</output_format>
