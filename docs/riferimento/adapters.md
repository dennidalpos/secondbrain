# IDE adapters and live qualification

[Retained Italian source; use this English page for current behavior](adapters.it.md)

SecondBrain distinguishes file configuration, installed client, profile, environment, account and actual loaded instructions. Evidence on one surface does not certify the others. SYS01 guides verification after setup and after login/profile changes.

## Inspect the map

~~~powershell
pwsh -NoProfile -File scripts/ide-map.ps1 -Verify
~~~

The verifier compares selected instruction files with the expected generated global block. Manual integrations require an observation receipt. Exit codes are 0 aligned/verified within scope, 1 pending alignment/qualification or missing map, 2 error.

The host map is generated from active bindings/discovery. Do not manually mark a client/account verified. A file can be aligned while account/loading remains unverified; record both outcomes.

## Surface-specific workflow

| Surface | Required evidence |
|---|---|
| Repository instructions | Correct AGENTS source and generated adapter pointers |
| User file | Actual selected configuration root and approved block hash |
| Project/profile | Workspace/profile identity and the configuration really used |
| Account setting | User-declared account alias and manually observed instruction text |
| Running client | New-session observation with revision/hash and evidence |
| Write capability | Actual permitted roots and observed command/denial, not a guessed sandbox model |

No credential/authentication archive is read to discover accounts. Multiple accounts/config roots need distinct declared entries; login is manual. Treat changed account/profile/environment identity as ide-context-changed and requalify it.

## File and manual integrations

Claude-family, Codex and Antigravity have supported file/registration paths in the implementation. Additional adapters can be discovered without being live-qualified. A running executable or directory is evidence of presence only.

Manual account surfaces, including app settings and integrations without an instruction file, require the user to apply the generated text and provide a real observation. Do not infer account instructions from a generic help page or another profile.

The repository common source is AGENTS.md. Sync manages CLAUDE.md/GEMINI.md import pointers for adapters needing them; other clients may require their own supported configuration. Preserve unrelated content and report conflicts instead of editing generated blocks by hand.

## MCP is a separate check

Pair preview inspects target/scope/path; Apply changes selected configuration after authorization. Codex/Claude Code user registration and workspace configuration are different scopes. A successful stdio handshake proves protocol behavior in that run, not live instruction loading or account state.

Use [MCP setup](mcp-setup.md) for target/permission/package details. Restart only the intended owned client session when configuration changes require it.

## Observation receipts and limits

ObservationPath supplies a schema-validated receipt bound to the intended host/client/account/profile, expected text hash and real evidence. Freshness/current context and source revision matter. A fabricated receipt or a fixture cannot qualify a live client.

Write access is also observed, not assumed. core.write.denied/CLI exit 4 differs from lock contention (exit 3). Preserve original diagnostics and recovery markers; do not automatically widen writable roots or modify private IDE instructions as a shortcut.

Sources in local fixtures demonstrate parser/adaptor behavior. They do not prove every installed client version, GUI permission dialog, account setting, native collector or multi-host filesystem condition. Report unavailable observations as pending.

See [safe writes](safety-backups.md), [access](access.md), [memory cycle](memory-cycle.md) and [operations](operations.md).
