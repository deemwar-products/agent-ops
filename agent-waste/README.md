# agent-waste

Coding agents waste context in predictable ways: re-reading the same file, reading a file
they just edited, re-running the same command, re-grepping the same pattern. Every redundant
tool result is paid for again in tokens — on the turn it lands and every turn that carries it
forward. agent-waste audits a session transcript and shows you where.

## Install — there's nothing to install

```bash
git clone https://github.com/deemwar-products/agent-ops
python3 agent-ops/agent-waste/agent-waste --latest             # audit the most recent transcript
python3 agent-ops/agent-waste/agent-waste session.jsonl --top 20  # audit a specific transcript
```

## What it does

Reads a Claude Code transcript (`~/.claude/projects/<slug>/<id>.jsonl`), reconstructs each tool call and the size of the result it returned, and reports the wasted work:

- **duplicate reads** — the same file read more than once
- **read-after-own-edit** — a file read again after THIS session edited/wrote it
- **repeated commands** — an identical Bash command run again
- **repeated searches** — the same grep/glob run again

`--top N` caps the leaderboard, `--threshold-tokens N` turns it into a gate, `--json` gives machine-readable output.

Wasted-token figures are an **ESTIMATE** (~4 chars/token; Claude's tokenizer isn't public) of the repeated tool-result payloads — a signal for which habits cost you, not a bill. It's heuristic: a few repeats are legitimate (re-run a test, re-check `git status`), so read it as "here's where to look."

Exit `0` = clean, `1` = `--threshold-tokens` exceeded or a fatal error.

## Why it exists

Static config tells you what an agent *can* do; the transcript tells you what it *actually did* — and where it burned tokens twice. Full write-up: [The tokens your agent wastes in the transcript](https://deemwar.com/insights/the-tokens-your-agent-wastes-in-the-transcript).

## Tests

```bash
./test_agent_waste.sh        # 13/13 checks
```

---

Part of **[agent-ops](https://github.com/deemwar-products/agent-ops)** — 29 small, dependency-light tools for running AI coding agents in production, **built & run by [deemwar](https://deemwar.com)**.

Running coding-agent fleets and hitting these same walls? **[Let's talk → deemwar.com/contact](https://deemwar.com/contact)**

MIT © deemwar
