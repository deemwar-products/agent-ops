# agent-guard

A coding agent ran `git reset --hard` and destroyed 12 unpushed commits (anthropics/claude-code#34327); another deleted untracked work (#46444). agent-guard is a Claude Code PreToolUse hook that blocks the handful of irreversibly destructive commands **before** the agent runs them.

## Install — there's nothing to install

```bash
git clone https://github.com/deemwar-products/agent-ops
# Wire it as a Bash PreToolUse hook in .claude/settings.json:
{"hooks":{"PreToolUse":[{"matcher":"Bash",
  "hooks":[{"type":"command","command":"${CLAUDE_PROJECT_DIR}/.claude/hooks/agent-guard"}]}]}}
# Deliberate cleanup? Disable for the run:
AGENT_GUARD_OFF=1 python3 agent-ops/agent-guard/agent-guard
```

The hook reads the PreToolUse JSON on stdin (`{"tool_name":"Bash","tool_input":{"command":"..."}}`).

## What it does

- Matches the Bash command against a fixed set of work-destroying patterns: `git reset --hard`, `git clean -f`, `git push --force` (allows `--force-with-lease`), `git branch -D`, `git checkout/restore .`, `git stash drop/clear`, `git worktree remove --force`, and `rm -rf`.
- On a match: emits a structured `deny` decision with the reason and a safer alternative (e.g. "use `git push --force-with-lease`, which refuses if the remote moved").
- **Fails safe**: it only ever denies. A parse error, non-Bash tool, or unrecognized shape allows normal permission flow.
- Escape hatch: `AGENT_GUARD_OFF=1` disables it entirely.

## Why it exists

Born from real incidents where agents ran `git reset --hard` / deleted untracked files and stranded unpushed work. Full write-up: [Stop your agent running git reset --hard](https://deemwar.com/insights/stop-your-agent-running-git-reset-hard).

## Tests

```bash
./test_agent_guard.sh        # 23/23 checks
```

---

Part of **[agent-ops](https://github.com/deemwar-products/agent-ops)** — 29 small, dependency-light tools for running AI coding agents in production, **built & run by [deemwar](https://deemwar.com)**.

Running coding-agent fleets and hitting these same walls? **[Let's talk → deemwar.com/contact](https://deemwar.com/contact)**

MIT © deemwar
