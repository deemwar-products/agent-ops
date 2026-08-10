# session-stats

You ran a Claude Code session for an hour and want to know what it actually did —
how many turns, which tools, which files it touched, and whether it ended healthy
or wedged. session-stats reads the session transcript and summarizes the run.

## Install — there's nothing to install

```bash
git clone https://github.com/deemwar-products/agent-ops
python3 agent-ops/session-stats/session-stats find        # newest transcript for cwd
python3 agent-ops/session-stats/session-stats <transcript.jsonl>   # summarize a session
```

## What it does

- `find [project_dir]` prints the path to the newest transcript for a project (defaults to the current directory).
- Summarizes a transcript: session id, file size with a rough token estimate (~bytes/4, labeled rough), line count, and user/assistant turn counts.
- Breaks down thinking blocks (and empty-text ones), tool calls by name with a total, and the set of files touched (first 8; `--files` shows all).
- Reports health: flags a session whose last assistant turn ends on an orphaned thinking block (the 400 'thinking blocks' wedge), plus a compact line-type census.

## Why it exists

After a long agent run you need a fast read on what happened and whether the transcript is wedged before you resume it. Full write-up: [What's in your Claude Code session file?](https://deemwar.com/insights/whats-in-your-claude-code-session-file).

## Tests

```bash
./test_session_stats.sh        # 12/12 checks
```

---

Part of **[agent-ops](https://github.com/deemwar-products/agent-ops)** — 29 small, dependency-light tools for running AI coding agents in production, **built & run by [deemwar](https://deemwar.com)**.

Running coding-agent fleets and hitting these same walls? **[Let's talk → deemwar.com/contact](https://deemwar.com/contact)**

MIT © deemwar
