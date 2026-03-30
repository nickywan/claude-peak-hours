# Security Policy

## Scope

This is a read-only Claude Code statusline plugin. It:

- Reads Claude Code's stdin JSON (model info, context window)
- Fetches a public JSON config from this GitHub repo
- Fetches usage data from Anthropic's official OAuth API using your existing Claude Code tokens
- Writes cached data to `/tmp/claude/`

It does **not** store credentials, transmit your data to third parties, or modify your code.

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.x     | Yes       |

## Reporting a Vulnerability

If you discover a security issue, **do not open a public issue**.

Instead, please use [GitHub's private security advisory feature](https://github.com/nickywan/claude-peak-hours/security/advisories/new) to report it confidentially.

You can expect an initial response within 48 hours.

## What Counts as a Security Issue

- The plugin sending data to unexpected endpoints
- Credential leakage (OAuth tokens exposed in logs, cache files with wrong permissions, etc.)
- Code injection via the remote `peak-hours.json` config
- Any behavior that could compromise the user's system or Claude Code session
