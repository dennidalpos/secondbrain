# Security policy

## Supported versions

Security fixes are applied to the latest version published on `master` (see `VERSION`).

## Reporting a vulnerability

Do not open a public issue. Use GitHub's private reporting: open the **Security** tab of the repository, then **Report a vulnerability**.

Include the SecondBrain version, the steps to reproduce the problem and the expected impact. Do not attach real secrets, tokens or personal data: replace them with dummy values.

Replies are sent in the same private conversation. The fix is published before the details are disclosed.

## Scope

SecondBrain is a local tool: the PowerShell scripts, the local stdio MCP server (`scripts/mcp-server.ps1`, whose startup and lookups can integrate already-authorized queued dossier writes) and the IDE configuration files it generates. Vulnerabilities in the IDEs, Git or PowerShell themselves are out of scope.
