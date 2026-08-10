# context-lint

CLAUDE.md / AGENTS.md is loaded into *every* session, so its cost is paid every turn and its
mistakes mislead every run. context-lint audits the file for the three things that actually
hurt: instruction bloat, stale path references, and missing build/test commands.

## Install — there's nothing to install

```bash
git clone https://github.com/deemwar-products/agent-ops
python3 agent-ops/context-lint/context-lint                   # lint ./CLAUDE.md and ./AGENTS.md if present
python3 agent-ops/context-lint/context-lint CLAUDE.md         # lint a specific file
```

## What it does

- **bloat** — flags files past the ~150–200 instructions a frontier model follows reliably (later instructions get silently dropped), and warns when the file crosses ~2,000 tokens loaded every session.
- **stale refs** — finds backtick-quoted path references that point at files that don't exist, sending the agent looking for code that isn't there.
- **missing** — flags the absence of build/test commands, the single most useful thing to omit.

Token figures are an **ESTIMATE** (~4 chars/token).

Exit `0` = healthy, `1` = at least one finding.

## Why it exists

Context engineering is the leverage point — the model is rarely the bottleneck, the always-loaded context file usually is. Full write-up: [The most expensive file runs every turn](https://deemwar.com/insights/the-most-expensive-file-runs-every-turn).

## Tests

```bash
./test_context_lint.sh        # 10/10 checks
```

---

Part of **[agent-ops](https://github.com/deemwar-products/agent-ops)** — 29 small, dependency-light tools for running AI coding agents in production, **built & run by [deemwar](https://deemwar.com)**.

Running coding-agent fleets and hitting these same walls? **[Let's talk → deemwar.com/contact](https://deemwar.com/contact)**

MIT © deemwar
