# perm-audit

Your Claude Code agent's `.claude/settings.json` decides how much it can do *without asking you*. One over-permissive line turns a single injected instruction into a free hand on your shell. perm-audit checks that permission config — the layer underneath what the agent reads, exfiltrates, or runs.

## Install — there's nothing to install

```bash
git clone https://github.com/deemwar-products/agent-ops
python3 agent-ops/perm-audit/perm-audit                  # default: ./.claude/settings.json
python3 agent-ops/perm-audit/perm-audit path/settings.json   # audit a specific file
```

## What it does

- Flags dangerous permission modes — `defaultMode: bypassPermissions` (CRITICAL: every call runs with no check) and `acceptEdits` (WARN: edits auto-approved).
- Warns when `enableAllProjectMcpServers` is true — every MCP server auto-approved as an untrusted tool surface.
- Catches broad `allow` rules that auto-approve a whole tool (pure wildcards), with `Bash` rated HIGH; also flags allow rules that permit network egress (`WebFetch`/`WebSearch`, or `Bash(curl …)`, `wget`, `nc`, `scp`, `ssh`).
- Checks for missing `deny` rules protecting secrets (`.env`, `.ssh`, `credentials`, etc.) when an allowlist or bypass/acceptEdits mode is in play.

If there's no settings file, it tells you the safe Claude Code defaults apply and exits clean.

Exit `0` = no high-severity issues, `1` = at least one HIGH/CRITICAL finding.

## Why it exists

Over-permissive agent settings turn one injected instruction into full shell access. Full write-up: [The loosest line in your Claude settings](https://deemwar.com/insights/the-loosest-line-in-your-claude-settings).

## Tests

```bash
./test_perm_audit.sh        # 12/12 checks
```

---

Part of **[agent-ops](https://github.com/deemwar-products/agent-ops)** — 29 small, dependency-light tools for running AI coding agents in production, **built & run by [deemwar](https://deemwar.com)**.

Running coding-agent fleets and hitting these same walls? **[Let's talk → deemwar.com/contact](https://deemwar.com/contact)**

MIT © deemwar
