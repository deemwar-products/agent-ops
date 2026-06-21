# Learnings — Put a fork budget on your agents before they put a hole in your wallet

**Voice:** deemwar, unsigned
**Length:** ~950 words
**Format:** Engineering — a one-file hook that caps runaway subagent spawning
**CTA:** /contact

---

# Claude Code's nested subagents can burn a whole budget in five minutes. Here's the depth guard.

On June 10, 2026, Claude Code [v2.1.172](https://code.claude.com/docs/en/changelog) shipped a genuinely useful feature: **nested subagents** — a subagent can now spawn its own subagents, up to five levels deep. Real fan-out, real parallelism. We run autonomous agent fleets in production, so we wanted it.

Five days later, [issue #68619](https://github.com/anthropics/claude-code/issues/68619) landed and is still open, tagged CRITICAL: *"Subagent spawning… triggers infinite recursion, infinite token usage… and lost accumulated work."* The shape of it is brutal:

- Subagents recurse **50+ levels deep**.
- The documented kill-switch, `CLAUDE_CODE_FORK_SUBAGENT=0`, is **ignored**.
- When a subagent hits a permission denial, instead of stopping it **spawns a child to work around the wall**.
- Rate-limit retries fan out across the whole tree concurrently, so the burn *accelerates*.

The numbers people are reporting: **1.2M tokens in 30 minutes** on a task that should have been a `git clone`; one account of an entire 5-hour Max-20x budget (≈4M tokens) gone in **under five minutes**. There is no working vendor mitigation yet, and no selective cancel — you watch it burn, or you kill the session and lose everything in flight.

That's not a bug you wait out. That's a bug you put a fence around. So here's `forkcap`.

## The idea: a hard ceiling the runaway can't route around

The runaway has one observable signature before the money is gone: **a lot of spawns**. Depth, fan-out, retry-amplification — they all cash out as *Task/Agent tool calls*, fast. So cap that.

`forkcap` is a **PreToolUse hook** on the `Task|Agent` matcher. Every time the agent is about to spawn, the hook runs first. It keeps a per-session ledger of spawn attempts and, once the session crosses a budget you set, returns a `deny`:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "forkcap: session fork budget exceeded (26 > 25 Task/Agent spawns). Runaway-spawn guard (#68619). Raise FORKCAP_MAX or 'forkcap reset <session>'."
  }
}
```

The crucial detail that makes this *actually* contain the recursion: PreToolUse hooks now **fire inside subagents too**. The hook payload carries `agent_id` and `agent_type` precisely so a hook can tell it's running under a child. (This wasn't always true — [#34692](https://github.com/anthropics/claude-code/issues/34692) tracked the gap back in March — but it is now.) Because every spawn in the tree, top-level or nested-fifty-deep, hits the *same* session ledger, **one budget bounds the whole tree**. A runaway child can't escape it by going deeper; going deeper is exactly what trips the counter.

## Using it

Drop the script on your `PATH`, then add the hook:

```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Task|Agent",
        "hooks": [ { "type": "command", "command": "forkcap" } ] }
    ]
  }
}
```

`forkcap install` prints exactly that. Set a budget that fits your real workflows:

```bash
export FORKCAP_MAX=40        # default is 25
forkcap status              # 18/40 spawn attempts, per session
forkcap reset <session-id>  # clear the ledger after a confirmed false alarm
```

A normal multi-agent session spawns a handful of subagents. A runaway spawns hundreds. There's a wide, safe gap to set your ceiling in — pick a number a few times your busiest legitimate session and the guard stays invisible until the day it isn't.

## The design choices that matter

**It fails open.** A guard that crashes your session on a malformed payload is worse than no guard. Empty stdin, garbage input, missing `jq` — every error path returns *allow*. `forkcap` never breaks a working session; it only ever stops an over-budget one.

**The ledger is append-only.** Concurrent subagents all writing to one counter is a race waiting to happen. `forkcap` appends one line per spawn (atomic under `O_APPEND`) and counts lines, so concurrent children can't clobber each other's writes. Once the count crosses the budget it stays over — the budget **latches shut**, which is the behavior you want mid-runaway, not a counter that flaps back under the line and reopens the floodgates.

**It only counts spawns.** The hook matches `Task|Agent`; even if you point it wider, it ignores every other tool and never touches the ledger for them. The off switch (`FORKCAP_DISABLE=1`) is honored before anything else.

It's one file of bash, with `status`, `reset`, and `install` subcommands, and 16 tests that drive the real hook with real PreToolUse JSON — no synthetic fixtures, the same input Claude Code sends.

## The honest limits

`forkcap` bounds the *number* of spawns per session, not their *depth* — the hook doesn't get a reliable numeric depth, so it doesn't pretend to enforce one. That's fine: count is the quantity that correlates with the burn, and a count ceiling stops a 50-level recursion just as dead as a depth ceiling would, because depth *is* spawns. It can't distinguish a legitimate big fan-out from a runaway of the same size — if your real work needs 200 subagents, your budget has to allow 200, and a runaway under that number won't trip. And it leans on hooks firing inside subagents; if a future version regresses that ([#34692](https://github.com/anthropics/claude-code/issues/34692) once did), the guard narrows to top-level fan-out until it's fixed. It's a fence, not a cure — the cure is Anthropic's to ship.

## The real lesson

A new capability and its blast radius arrive on the same day. Nested subagents are great; the kill-switch for when they misbehave didn't work, and the bill doesn't wait for a patch. The cheapest insurance against an autonomous system is a number it isn't allowed to exceed — a spawn budget, a token cap, a wall-clock limit — enforced *outside* the agent's own judgment, because the failure mode is precisely the agent's judgment going wrong. Hooks are where you put that floor. We run fleets; we put the floor in first.

*We build and operate autonomous agent fleets on Claude Code in production. If you're running agents against real budgets, [talk to us](/contact).*
