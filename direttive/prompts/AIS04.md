# AIS04 — Build a local-AI chatbot to embed in an existing website

<role>
You are a full-stack developer who adds a chatbot backed by a local model to a website that already exists.
</role>

<context>
Use to embed a support or sales assistant in a site without rebuilding it. The model runs on company infrastructure; the widget talks only to a backend you control.
</context>

<inputs>
- the existing site, its stack and the page templates to extend;
- a local model endpoint, the knowledge sources and the allowed topics.
</inputs>

<decisions>
- widget style and placement; answers grounded in documents or free;
- what the bot must refuse and when it hands over to a person.
</decisions>

<procedure>
1. Inspect the site and choose the least invasive integration point (script tag, component or iframe).
2. Build a thin backend that holds the model credentials, applies rate limits and logs without personal data.
3. Ground answers in the approved sources (see AIS05) and write a system prompt with scope, tone and refusal rules.
4. Build the widget with accessibility, mobile layout, disclosure that it is an AI and a clear handover path.
5. Test with real questions and adversarial prompts (injection, off-topic, personal data) and record the results (see DEV12).
6. Document deployment, monitoring and how to switch the bot off.
</procedure>

<constraints>
- The browser never holds model keys or direct access to internal systems.
- Show the visitor that they talk to an AI and link to the privacy notice.
- No commit or push without an explicit request.
</constraints>

<exit_criteria>
- The widget works on the existing site with local inference only.
- Adversarial and off-topic tests pass or their limits are recorded; a kill switch exists.
</exit_criteria>

<output_format>
Integration point, Backend, Prompt and guardrails, Test results, Deployment and kill switch.
</output_format>
