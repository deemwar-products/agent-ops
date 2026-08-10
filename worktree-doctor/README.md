# worktree-doctor

When you run parallel coding agents in git worktrees, each worktree is a place work can quietly die: an agent edits but never commits, or commits to a branch that was never pushed — then a cleanup or `git worktree remove` takes the directory and the work with it. `worktree-doctor` makes that risk visible *before* cleanup runs.

## Install — there's nothing to install

```bash
git clone https://github.com/deemwar-products/agent-ops
python3 agent-ops/worktree-doctor/worktree-doctor           # report all worktrees for this repo
python3 agent-ops/worktree-doctor/worktree-doctor --quiet   # only print the at-risk ones
```

## What it does

- Lists every worktree for the current repo and flags each as at-risk or safe.
- A worktree is AT RISK if it has uncommitted changes (unrecoverable once the dir is gone) or commits that are on no remote (lost if the branch/worktree is deleted).
- Also surfaces missing-dir (prunable), locked, and stale (HEAD ≥ 7 days old) status as context.
- `--quiet` prints only the at-risk worktrees — handy in a pre-cleanup check.

Exit `0` = all safe, `1` = at least one at-risk worktree.

## Why it exists

A worktree auto-cleanup deleted days of uncommitted agent work that was invisible until it was gone. Full write-up: [Your agent fleet's worktrees are a minefield](https://deemwar.com/insights/your-agent-fleets-worktrees-are-a-minefield).

## Tests

```bash
./test_worktree_doctor.sh        # 8/8 checks
```

---

Part of **[agent-ops](https://github.com/deemwar-products/agent-ops)** — 29 small, dependency-light tools for running AI coding agents in production, **built & run by [deemwar](https://deemwar.com)**.

Running coding-agent fleets and hitting these same walls? **[Let's talk → deemwar.com/contact](https://deemwar.com/contact)**

MIT © deemwar
