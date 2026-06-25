# spinlint

Flag **wasted-loop / stuck** agent sessions from a transcript.

An unattended agent can spin: it reruns the same failing command, ping-pongs the same edit, or hits the same error over and over — burning turns and tokens with no progress. There are public reports of a single stuck session costing $500+ in tokens. `spinlint` reads a session transcript and exits non-zero when the agent was spinning, so a fleet can gate wasted spend without piping every session into a trace SaaS.

**The load-bearing heuristic:** identical action + repeated *error* outcome = stuck; a varying input OR an eventual success = productive. Outcome, not call count — a retry that finally succeeds is never flagged.

## Checks

1. **REPEAT-CALL** — the same tool call (name + identical input) made N+ times within a sliding window. If every repeat also errored, that's the classic "retrying a failing command without changing it" loop.
2. **REPEAT-ERROR** — the same (normalized) tool error recurring N+ times (agent not learning).
3. **PING-PONG** — one file edited with oscillating / low-diversity changes (churn).

## Usage

```bash
spinlint --transcript session.jsonl
spinlint session.jsonl
cat session.jsonl | spinlint
```

Exit `1` if the session was spinning, `0` if productive. One file, `python3`, no install, no network, no model call.

---

Built and run by [deemwar](https://deemwar.com). Putting agents to work on code that matters? **[Talk to us](https://deemwar.com/contact).**
