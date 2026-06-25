# agentdrift

A repo that supports more than one coding agent ends up with several instruction files — CLAUDE.md, AGENTS.md, .cursorrules, copilot-instructions.md — all SUPPOSED to say the same thing. Left to hand-maintenance, they quietly drift: one says "use pytest", another still says "use unittest", and different agents follow different rules in the same repo. agentdrift finds those files and checks whether they agree.

## Install — there's nothing to install

```bash
git clone https://github.com/deemwar-products/agent-ops
python3 agent-ops/agentdrift/agentdrift .                 # audit one repo (default: .)
python3 agent-ops/agentdrift/agentdrift --corpus repos/   # audit every subdir as a repo (for studies)
```

## What it does

- Finds a repo's known agent-instruction files (CLAUDE.md, AGENTS.md, GEMINI.md, .cursorrules, .windsurfrules, copilot-instructions.md, rule-file dirs, …).
- Classifies the set: SINGLE SOURCE (good), CANONICAL+REDIRECT — one real file, the rest are stubs pointing to it (good), DUPLICATED — near-identical real files kept in sync by copy-paste (warn), or DRIFT — substantive files that have diverged (fail).
- `--threshold N` sets the similarity %% below which two real files count as drift (default 90); `--json` for machine output.

Exit `0` = single-source or clean redirect pattern, `1` = duplication or drift found.

## Why it exists

Multi-agent repos accumulate instruction files that silently disagree. Full write-up: [CLAUDE.md and AGENTS.md have drifted](https://deemwar.com/insights/claude-md-and-agents-md-have-drifted).

## Tests

```bash
./test_agentdrift.sh        # 19/19 checks
```

---

Part of **[agent-ops](https://github.com/deemwar-products/agent-ops)** — 29 small, dependency-light tools for running AI coding agents in production, **built & run by [deemwar](https://deemwar.com)**.

Running coding-agent fleets and hitting these same walls? **[Let's talk → deemwar.com/contact](https://deemwar.com/contact)**

MIT © deemwar
