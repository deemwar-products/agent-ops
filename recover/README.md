# recover

An agent removed a worktree, deleted a branch, or did a `reset --hard` — and the commits are suddenly unreachable from any ref. The work isn't gone yet: git still has the dangling objects until gc prunes them. `recover` finds those orphaned commits and restores them onto a fresh branch.

## Install — there's nothing to install

```bash
git clone https://github.com/deemwar-products/agent-ops
bash agent-ops/recover/recover list                  # dangling commits, newest first
bash agent-ops/recover/recover to rescued <sha>      # restore one onto a new branch
```

## What it does

- `list` — runs `git fsck --no-reflogs --dangling` to find truly orphaned commits (unreachable from refs and reflogs), sorted newest first, with short-sha / author / date / subject / diffstat.
- `show <sha>` — full diff of one dangling commit so you can confirm it's the work you want.
- `to <branch> <sha>` — creates a new branch pointing at the recovered commit.
- Time-bounded: only works until `git gc --prune=now` (or the gc grace period) drops the dangling objects from the object store.

## Why it exists

An agent's just-finished work vanished when its worktree was cleaned and the branch was never reachable from a ref — but git hadn't gc'd it yet. Full write-up: [Recover an agent's vanished work](https://deemwar.com/insights/recover-an-agents-vanished-work).

## Tests

```bash
./test_recover.sh        # 7/7 checks
```

---

Part of **[agent-ops](https://github.com/deemwar-products/agent-ops)** — 29 small, dependency-light tools for running AI coding agents in production, **built & run by [deemwar](https://deemwar.com)**.

Running coding-agent fleets and hitting these same walls? **[Let's talk → deemwar.com/contact](https://deemwar.com/contact)**

MIT © deemwar
