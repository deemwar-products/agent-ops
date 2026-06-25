# auto-snapshot

The one loss class nothing can recover is work that was *never committed* — an agent edits files, the worktree gets cleaned, and there's nothing in the object store to fsck back. `auto-snapshot` closes that gap: as a Claude Code Stop hook it snapshots the dirty working tree every turn into git's object store, without touching your working tree, index, branch, or history.

## Install — there's nothing to install

```bash
git clone https://github.com/deemwar-products/agent-ops
bash agent-ops/auto-snapshot/auto-snapshot              # take a snapshot (no-op if clean)
bash agent-ops/auto-snapshot/auto-snapshot list         # list snapshots, newest first
bash agent-ops/auto-snapshot/auto-snapshot restore <sha>  # re-apply onto your working tree
```

Install as a Stop hook in `.claude/settings.json`:

```json
{"hooks":{"Stop":[{"hooks":[{"type":"command",
  "command":"${CLAUDE_PROJECT_DIR}/.claude/hooks/auto-snapshot"}]}]}}
```

## What it does

- `snapshot` (default) — stages everything dirty, including untracked files (which `git stash create` silently drops), into a throwaway index and commits the tree, pinned under `refs/wip-snapshots/<ts>` so gc can't drop it. No-op if the tree is clean.
- `list` — snapshots newest first, with age, sha, branch, and diffstat.
- `restore <sha|latest>` — re-applies a snapshot's files onto your working tree (overwrites the paths it contains; doesn't delete newer files).
- `prune [--keep N]` — keeps the N newest snapshots (default 50).

## Why it exists

Uncommitted agent work has no object in the store to recover from once the worktree is gone — so snapshot it every turn before that can happen. Full write-up: [The agent work you can't recover](https://deemwar.com/insights/the-agent-work-you-cant-recover).

## Tests

```bash
./test_auto_snapshot.sh        # 10/10 checks
```

---

Part of **[agent-ops](https://github.com/deemwar-products/agent-ops)** — 29 small, dependency-light tools for running AI coding agents in production, **built & run by [deemwar](https://deemwar.com)**.

Running coding-agent fleets and hitting these same walls? **[Let's talk → deemwar.com/contact](https://deemwar.com/contact)**

MIT © deemwar
