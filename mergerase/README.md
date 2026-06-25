# mergerase

When several agents work the same repo in parallel, each branches from a frozen snapshot with no awareness of its siblings. At merge, the conflict-resolving step "picks a winner" with no understanding of intent — and a feature one agent built simply stops existing. No error, no failing test, green CI. `mergerase` compares the public symbol surface of two git states and reports the exported names that were present *before* and gone *after* — the silent-erasure signature.

## Install — there's nothing to install

```bash
git clone https://github.com/deemwar-products/agent-ops
bash agent-ops/mergerase/mergerase                    # HEAD must be a merge; check each parent -> HEAD
bash agent-ops/mergerase/mergerase <before> [<after>] # compare two refs (after defaults to the worktree)
```

## What it does

- With no args: HEAD must be a merge commit; compares each parent against HEAD.
- With refs: compares `<before>` against `<after>` (or the worktree if `<after>` is omitted).
- Reports each public symbol present in the before-state but missing after, with the file it lived in — confirm intentional, not silent merge erasure.
- Detects exported names in JS/TS (`export function|const|class`, `exports.x`, `export { … }`), Python (top-level public `def`/`class`), and Go (capitalized `func`/`type`). Needs only git + bash (3.2+).

Exits non-zero if any public symbol disappeared (drops into a CI gate).

## Why it exists

Parallel-agent merges silently dropped a working capability — a feature that lived in a parent branch but wasn't in the merged result, with green CI to mask it. Full write-up: [blog-post.md](./blog-post.md).

## Tests

```bash
./test_mergerase.sh        # 13/13 checks
```

---

Part of **[agent-ops](https://github.com/deemwar-products/agent-ops)** — 29 small, dependency-light tools for running AI coding agents in production, **built & run by [deemwar](https://deemwar.com)**.

Running coding-agent fleets and hitting these same walls? **[Let's talk → deemwar.com/contact](https://deemwar.com/contact)**

MIT © deemwar
