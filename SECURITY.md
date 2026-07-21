# Security Policy

## Supported versions

| Version | Supported |
|---|---|
| latest 0.x on npm / main | Yes |
| older | No — please upgrade first |

## Reporting a vulnerability

**Please do not open a public GitHub issue for security vulnerabilities.**

Report privately via
[GitHub's private security advisory](https://github.com/muslewski/llm-armory/security/advisories/new)
or email **10kento10@gmail.com** with the subject line `[SECURITY] llm-armory`.

Include:

- A description of the vulnerability
- Steps to reproduce
- Potential impact
- Any suggested fix (optional)

You will receive a response within **72 hours**. We aim to ship a patch within
**14 days** of a confirmed vulnerability.

## Scope

llm-armory is a local bash launcher that execs executor CLIs (grok, claude, etc.) with preset env files. Primary risk: command injection via presets, secrets in `presets/providers/*.env`, or unsafe worktree paths.

Out of scope: issues in Node.js / Python / the OS, third-party CLIs this tool
launches, or GitHub Actions runners themselves.
