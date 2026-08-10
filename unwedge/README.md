# unwedge

A Claude Code session dies on a `400` — "thinking/redacted_thinking blocks in the latest assistant message cannot be modified" — and every "continue" reproduces it. An extended-thinking turn got cut mid-stream, leaving an orphaned signed thinking block as the last assistant message; it gets resent on every request and the API rejects it. `unwedge` surgically drops that trailing turn so the session resumes — keeping the rest of the conversation intact (unlike `/rewind` or `/clear`).

## Install — there's nothing to install

```bash
git clone https://github.com/deemwar-products/agent-ops
python3 agent-ops/unwedge/unwedge find                       # newest transcript for cwd's project
python3 agent-ops/unwedge/unwedge diagnose <transcript>      # is it wedged?
python3 agent-ops/unwedge/unwedge fix <transcript> --write   # back up + repair
```

## What it does

- `find [project_dir]` — prints the newest `.jsonl` transcript for a project (defaults to cwd).
- `diagnose <transcript>` — reports whether the transcript ends in an orphaned thinking block, and which clean `user` line a fix would cut back to.
- `fix <transcript>` — DRY-RUN by default: shows the cut it would make. Add `--write` to back up the transcript and truncate it to the last clean `user` line.
- Refuses to touch a transcript that isn't actually wedged, or one with no clean user line to cut back to.

Exit `0` = clean, `1` = wedged (on `diagnose`).

IMPORTANT: quit the stuck session first — a live session holds history in memory and will overwrite the file on exit, undoing the repair.

## Why it exists

A signed thinking block from an interrupted turn permanently wedged a session on a 400, with no built-in recovery that preserved context. Full write-up: [Unwedge a stuck Claude Code session](https://deemwar.com/insights/unwedge-a-stuck-claude-code-session).

## Tests

```bash
./test_unwedge.sh        # 12/12 checks
```

---

Part of **[agent-ops](https://github.com/deemwar-products/agent-ops)** — 29 small, dependency-light tools for running AI coding agents in production, **built & run by [deemwar](https://deemwar.com)**.

Running coding-agent fleets and hitting these same walls? **[Let's talk → deemwar.com/contact](https://deemwar.com/contact)**

MIT © deemwar
