# claude-md-gen

The most valuable thing in a CLAUDE.md is how to build and test — and it's the thing people most often forget to write down, so the agent starts every session not knowing how to build the repo. claude-md-gen reads the real signals your repo already declares and writes a short starter CLAUDE.md you can refine.

## Install — there's nothing to install

```bash
git clone https://github.com/deemwar-products/agent-ops
python3 agent-ops/claude-md-gen/claude-md-gen .        # print a starter CLAUDE.md for the current dir
python3 agent-ops/claude-md-gen/claude-md-gen . -o     # write it to ./CLAUDE.md (won't overwrite)
```

## What it does

- Reads real build/test/lint commands the repo declares — `package.json` scripts (npm/pnpm/yarn/bun), `pyproject.toml`/`setup.py`, `go.mod`, `Cargo.toml`, `Gemfile`, `Makefile` targets.
- Detects the project language and the source directories that actually exist (`src`, `lib`, `cmd`, `internal`, `tests`, …).
- Writes a short starter CLAUDE.md from those signals so the agent knows how to build, test, and where the code lives.
- Does NOT invent rules — it only states what the repo actually says. The `-o` mode won't overwrite an existing CLAUDE.md.

## Why it exists

Agents waste the first part of every session rediscovering the build, when the repo already declared it. Full write-up: [Your repo already knows how to build itself](https://deemwar.com/insights/your-repo-already-knows-how-to-build-itself).

## Tests

```bash
./test_claude_md_gen.sh        # 12/12 checks
```

---

Part of **[agent-ops](https://github.com/deemwar-products/agent-ops)** — 29 small, dependency-light tools for running AI coding agents in production, **built & run by [deemwar](https://deemwar.com)**.

Running coding-agent fleets and hitting these same walls? **[Let's talk → deemwar.com/contact](https://deemwar.com/contact)**

MIT © deemwar
