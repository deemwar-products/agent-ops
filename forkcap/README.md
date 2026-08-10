# forkcap

Claude Code lets subagents spawn their own subagents. Issue #68619 (CRITICAL, open): they recurse 50+ levels deep, ignore the documented `CLAUDE_CODE_FORK_SUBAGENT=0` kill-switch, and burn 1.2M tokens in 30 minutes — with no working vendor fix. forkcap is a PreToolUse hook that puts a hard ceiling on Task/Agent spawns per session.

## Install — there's nothing to install

```bash
git clone https://github.com/deemwar-products/agent-ops
bash agent-ops/forkcap/forkcap install        # print the settings.json hook snippet
bash agent-ops/forkcap/forkcap status          # show spawn count per session
bash agent-ops/forkcap/forkcap reset [sid]     # clear a session's ledger (or all)
```

Wire it as a `Task|Agent` PreToolUse hook (`forkcap install` prints the exact JSON), then `export FORKCAP_MAX=40` if 25 is wrong for you.

## What it does

- Hook mode (default): reads the PreToolUse JSON on stdin and keeps a per-session ledger of Task/Agent spawn attempts.
- DENIES once a session crosses `FORKCAP_MAX` (default 25). Because PreToolUse hooks now fire inside subagents too (the payload carries `agent_id`/`agent_type`), one ledger bounds the **whole** spawn tree.
- The ledger latches: once over budget it stays over, so a runaway can't get around it. Appends are atomic, so concurrent subagents can't lose each other's writes.
- **Fails open**: bad/empty input, a missing state dir, or `FORKCAP_DISABLE` set → always allow (a guard that breaks the session is worse than no guard).
- Config (env): `FORKCAP_MAX`, `FORKCAP_STATE_DIR` (default `~/.cache/forkcap`), `FORKCAP_DISABLE`.

## Why it exists

Nested subagents recurse out of control and torch a token budget in minutes, and the documented kill-switch is ignored (anthropics/claude-code#68619). Full write-up: [blog-post.md](./blog-post.md).

## Tests

```bash
./test_forkcap.sh        # 16/16 checks
```

---

Part of **[agent-ops](https://github.com/deemwar-products/agent-ops)** — 29 small, dependency-light tools for running AI coding agents in production, **built & run by [deemwar](https://deemwar.com)**.

Running coding-agent fleets and hitting these same walls? **[Let's talk → deemwar.com/contact](https://deemwar.com/contact)**

MIT © deemwar
