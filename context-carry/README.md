# context-carry

The real cost of a tool result isn't how big it is — it's how LONG it stays in context. An
agent re-sends its entire accumulated context every turn, so a big file read early in a long
session is paid for again and again. Two reads of identical size can differ 50x in true cost
purely by WHEN they happened. context-carry finds the reads that dominate.

## Install — there's nothing to install

```bash
git clone https://github.com/deemwar-products/agent-ops
python3 agent-ops/context-carry/context-carry --latest        # weight the most recent transcript
python3 agent-ops/context-carry/context-carry session.jsonl --top 20  # a specific transcript
```

## What it does

- Reads a Claude Code transcript and weights every tool result by its residence time: `carry(result) = result_tokens × (turns it is re-sent on after it lands)`.
- Reports a per-item leaderboard in **token-turns** — which specific reads dominate, showing that loading them early is why a 1,000-token read can become ~57,000 token-turns.
- Surfaces the session-wide `carry / naive-sum` "amplification factor" (the literature's median is ~84x across 857 sessions).
- `--top N` caps the leaderboard; `--json` gives machine-readable output.

Token counts are an **ESTIMATE** (~4 chars/token). Honest caveat: prompt caching makes re-sent tokens ~10x cheaper in DOLLARS, but they still fill the finite context WINDOW and the cache is fragile (5-min TTL, breaks on any earlier-token change) — so carry-in-tokens is the real pressure on your window.

Exit `0` normally, `1` on a fatal error.

## Why it exists

The dominant context cost driver is residence time, not read size — and avoiding (or evicting) big early reads is the highest-leverage hygiene move. Full write-up: [The cost of a read is how long it stays](https://deemwar.com/insights/the-cost-of-a-read-is-how-long-it-stays).

## Tests

```bash
./test_context_carry.sh        # 11/11 checks
```

---

Part of **[agent-ops](https://github.com/deemwar-products/agent-ops)** — 29 small, dependency-light tools for running AI coding agents in production, **built & run by [deemwar](https://deemwar.com)**.

Running coding-agent fleets and hitting these same walls? **[Let's talk → deemwar.com/contact](https://deemwar.com/contact)**

MIT © deemwar
