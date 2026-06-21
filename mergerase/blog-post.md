# Learnings — Your agents passed CI and still deleted the feature

**Voice:** deemwar, unsigned
**Length:** ~950 words
**Format:** Engineering — catching silent feature-erasure when parallel agents merge
**CTA:** /contact

---

# The sprint looked clean. The PRs all passed CI. The checkout flow no longer worked.

Run three to five agents on the same repo and something quietly breaks that none of your existing checks will catch. Each agent branches from a frozen snapshot of `main` with **zero awareness of its siblings**. They all finish, all pass their tests, all merge green. And somewhere in the merge, a feature one agent built simply *stops existing*.

This isn't hypothetical. A [detailed April 2026 writeup](https://getautonoma.com/blog/ai-subagent-merge-conflicts) catalogues the exact shape:

> *"The export button doesn't filter by date range anymore."* The date filtering was implemented by one subagent and **silently overwritten** by another that also touched the export service.

> Agent A adds role-based access to the settings page; Agent B refactors the permissions service. The merge **silently reverts parts of Agent B's refactor.**

No error. No failing test. No stack trace. No human who recognizes what's missing, because the person reviewing the merge didn't write either branch. CI is green and the feature is gone. ([getautonoma.com](https://getautonoma.com/blog/ai-subagent-merge-conflicts), [getunblocked.com](https://getunblocked.com/blog/scale-parallel-ai-agents/) — the latter ties it to a QCon London team that "doubled throughput, then spent weeks debugging integration failures.")

Conflict-aware tooling doesn't help here, because **there's often no conflict**. When two branches edit the same region, git stops you. When a bad resolution — by a human in a hurry or an agent told to "just make it merge" — picks one side, git is satisfied; the dropped capability leaves no marker. The loss is invisible at exactly the layer everyone trusts.

So we built the cheapest possible detector for it: `mergerase`.

## The idea: diff the public surface, not the diff

A silently-erased feature has one reliable fingerprint: a **public symbol that existed in a branch and isn't in the merged result.** The export button's date filter was a function. Agent B's refactor exposed names. When the merge loses them, the *exported surface* shrinks even though the merge "succeeded."

`mergerase` extracts the set of public symbols — exported functions, consts, classes, named re-exports (JS/TS); top-level `def`/`class` (Python); capitalized `func`/`type` (Go) — at two git states, and reports the names present **before** and gone **after**.

```
$ mergerase
mergerase — HEAD is a merge; checking each parent for lost public symbols
  ✓ parent 1 (a1b2c3d) -> merge — no public symbols disappeared
  ✗ parent 2 (e4f5a6b) -> merge — public symbol(s) gone:
      LOST  getExportDateFilter        (was in src/export.ts)
      -> 1 symbol(s) — confirm intentional, not silent merge erasure.
```

With no arguments it checks a merge commit against each of its parents — the silent-erasure case directly. Point it at any two refs to compare them:

```bash
mergerase                       # HEAD (a merge) vs each parent
mergerase main feature/checkout # did this branch drop anything main had?
mergerase HEAD~1 HEAD           # any two refs
```

It exits non-zero when something disappeared, so it drops into CI right next to your tests — and it catches the failure your tests can't, because a deleted feature has no test that fails; it has a test that quietly stops running.

## Why symbols, and why by name

Comparing the **public surface** instead of the line diff is what makes this robust. A merge that touches 40 files produces an unreadable diff; the set of exported names is a handful of tokens, and a *missing* one is unambiguous. `mergerase` keys on the symbol **name**, not its location, so a symbol that merely **moved files** during a refactor isn't flagged — only one that truly vanished from the whole tree. It looks at exported/public names only; an internal helper coming and going is noise, and noise gets a linter switched off.

It's one file of bash with no exotic dependencies — just `git` and bash itself, runs on the stock bash 3.2 that ships with macOS. The test suite doesn't mock anything: each test builds a **real git repo, makes a real branch add a real export, merges with a bad resolution, and asserts `mergerase` flags it** — the actual failure mode reproduced in git, not a hand-fed fixture.

## The honest limits

`mergerase` catches *disappearance*, not *gutting*. The third example in that writeup — an audit hook that "compiles but calls a no-op… records nothing" because a method was renamed under it — keeps its symbol; the name is still exported, so a surface diff won't see it. Behavioral erasure where the signature survives is out of scope, and pretending otherwise would be the dishonest kind of green.

It also flags **intentional** removals — if a merge was *supposed* to delete a deprecated export, `mergerase` will still call it out. That's deliberate: at merge time you want every disappearing capability surfaced for a one-second human "yes, on purpose," rather than guessing which deletions were meant. And it reads four languages' surface syntactically; a symbol exposed by metaprogramming or a build step isn't in the source for it to see. Treat it as a smoke alarm for the specific, common, expensive case — a feature deleted by a merge nobody noticed — not as proof a merge is semantically intact.

## The real lesson

Parallelism across agents buys throughput and sells you a new failure class: work that integrates cleanly and is wrong, with every signal you normally trust showing green. The defenses you already have — tests, types, CI — all check whether the code that's *present* is correct. None of them check whether code that *should be present* still is. When you fan work out across agents that can't see each other, you need a check on the **negative space**: what used to be here and isn't. That check is cheap. The demo that reveals the missing checkout flow, the week of debugging, the customer who found it first — those aren't.

*We build and run autonomous agent fleets on Claude Code in production — many agents, one repo. If you're scaling parallel agents against a real codebase, [talk to us](/contact).*
