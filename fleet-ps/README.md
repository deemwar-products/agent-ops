# fleet-ps

Run a dozen Claude Code agents and one of them is silently stuck on the
thinking-block 400 wedge — but you don't know which. fleet-ps is `ps` for your
agent fleet: every recent session on the machine, most-recently-active first,
with a health flag on each.

## Install — there's nothing to install

```bash
git clone https://github.com/deemwar-products/agent-ops
python3 agent-ops/fleet-ps/fleet-ps                 # sessions active in the last 6 hours
python3 agent-ops/fleet-ps/fleet-ps --since 30      # active in the last 30 minutes
python3 agent-ops/fleet-ps/fleet-ps --all           # every session on the machine
```

## What it does

- Scans `~/.claude/projects/*/` for the newest transcript per project and lists what's been running, sorted most-recently-active first.
- Reads project path and git branch from the transcript itself (`cwd` / `gitBranch`), so they're accurate even though the on-disk dir name is a lossy slug.
- Shows each session's age, session id, and size in KB.
- Flags sessions wedged on the thinking-block 400 (last assistant turn ends in a `thinking` block) and prints how to un-wedge a stuck one.

## Why it exists

A fleet of agents can run for hours, and a single orphaned thinking turn silently bricks one session — fleet-ps surfaces it at a glance. Full write-up: [A dozen agents — which one is stuck?](https://deemwar.com/insights/a-dozen-agents-which-one-is-stuck).

## Tests

```bash
./test_fleet_ps.sh        # 8/8 checks
```

---

Part of **[agent-ops](https://github.com/deemwar-products/agent-ops)** — 29 small, dependency-light tools for running AI coding agents in production, **built & run by [deemwar](https://deemwar.com)**.

Running coding-agent fleets and hitting these same walls? **[Let's talk → deemwar.com/contact](https://deemwar.com/contact)**

MIT © deemwar
