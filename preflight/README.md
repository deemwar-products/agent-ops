# preflight

Two agents are about to land changes on the same repo — would they conflict if merged right now? `preflight` answers *before* a patch lands, using git's own merge engine (`git merge-tree --write-tree`) to simulate a real three-way merge in memory: no checkout, no index, no commit, no working-tree touch. Fast enough for a pre-commit / PreToolUse hook.

## Install — there's nothing to install

```bash
git clone https://github.com/deemwar-products/agent-ops
bash agent-ops/preflight/preflight <ref1> <ref2>        # preflight two committed refs
bash agent-ops/preflight/preflight --working <ref>      # preflight THIS worktree's edits vs <ref>
```

## What it does

- `preflight <ref1> <ref2>` — simulates merging two committed refs (e.g. two agent worktree HEADs, or HEAD vs the integration branch).
- `preflight --working <ref>` — snapshots this worktree's uncommitted edits into a throwaway unreferenced commit and preflights that against `<ref>` (merge-tree only reads committed refs, so it's otherwise blind to your in-flight work).
- Catches the same TEXTUAL conflicts git itself would flag at merge time — no more, no less. It does not catch semantic conflicts (edits that merge cleanly but are logically incompatible). That honesty is the point.

Exit `0` = `CLEAR` (clean merge), `1` = `CONFLICT` (followed by one conflicting path per line). Bad ref / not a repo / usage → exit `2`.

## Why it exists

Parallel agents collide on the same files, and the conflict only surfaces at merge time when the work is already done. Full write-up: [Preflight check before agents collide](https://deemwar.com/insights/preflight-check-before-agents-collide).

## Tests

```bash
./test-preflight.sh        # 5/5 checks
```

---

Part of **[agent-ops](https://github.com/deemwar-products/agent-ops)** — 29 small, dependency-light tools for running AI coding agents in production, **built & run by [deemwar](https://deemwar.com)**.

Running coding-agent fleets and hitting these same walls? **[Let's talk → deemwar.com/contact](https://deemwar.com/contact)**

MIT © deemwar
