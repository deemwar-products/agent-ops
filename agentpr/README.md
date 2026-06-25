# agentpr

Coding agents now open a lot of pull requests, and the worry in every 2026 engineering report is the same: they're bigger and they get less review (DORA tracked a 154% jump in PR size, Cortex a 31% rise in PRs merged with no review). agentpr checks that against your real data instead of vibes.

## Install — there's nothing to install

```bash
git clone https://github.com/deemwar-products/agent-ops
python3 agent-ops/agentpr/agentpr --repo owner/name      # live: classify + analyze merged PRs (needs gh)
python3 agent-ops/agentpr/agentpr --prs corpus.json      # offline: analyze a saved PR record set
```

## What it does

- Labels each merged PR with a clean ground truth: "agent" if its commits/body carry the Claude Code trailer ("Generated with Claude Code" / "Co-Authored-By: Claude").
- Splits agent vs human PRs and compares: SIZE (lines + files), REVIEW (review + discussion comments), TIME-TO-MERGE (minutes open→merge), and RUBBER-STAMP (%% merged with zero review comments AND under 10 minutes open).
- `--json` for machine output. Live mode needs `gh`.

The comparison is deterministic; "agent" is self-identified by the trailer, so it undercounts (a human set may contain a few unlabeled agent PRs) — which is conservative. Exit `0` always — it's a report.

## Why it exists

Agent PRs are bigger and merged with less review, and most teams only suspect it. Full write-up: [The AI skips code review — panic?](https://deemwar.com/insights/the-ai-skips-code-review-panic).

## Tests

```bash
./test_agentpr.sh        # 10/10 checks
```

---

Part of **[agent-ops](https://github.com/deemwar-products/agent-ops)** — 29 small, dependency-light tools for running AI coding agents in production, **built & run by [deemwar](https://deemwar.com)**.

Running coding-agent fleets and hitting these same walls? **[Let's talk → deemwar.com/contact](https://deemwar.com/contact)**

MIT © deemwar
