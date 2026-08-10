# skill-doctor

Which of your Claude Code skills are **silently broken**?

A skill registers only if the harness finds a real directory with a valid `SKILL.md` that carries a `name`. Break any link in that chain — a symlinked skill whose target was deleted, a folder with no `SKILL.md`, a `SKILL.md` with no frontmatter — and the skill just **doesn't appear**. No error, no warning. You think the skill is installed; the model never sees it. `skill-doctor` scans the skills *directory* for exactly these structural / registration faults across the whole tree.

It is the **structural-health complement to skill-lint** and stays in its lane: skill-lint judges one skill's *description quality* (vague / too short / SKILL.md size tax); skill-doctor never looks at description quality — only at whether each skill can register at all, plus name collisions and misplaced entries.

## Install — there's nothing to install

One file, `python3` stdlib only, no network, no model call.

```bash
git clone https://github.com/deemwar-products/agent-ops
python3 agent-ops/skill-doctor/skill-doctor              # checks ~/.claude/skills, then ./.claude/skills
python3 agent-ops/skill-doctor/skill-doctor ~/.claude/skills
python3 agent-ops/skill-doctor/skill-doctor --json
```

Exit `0` = clean, `1` = findings, `2` = bad input (dir missing / not a directory / empty).

## What it does

Scans every immediate child of the skills dir that is (or symlinks to) a directory expected to hold `SKILL.md`:

| code | severity | meaning |
|------|----------|---------|
| `BROKEN_SYMLINK` | HIGH | a skill entry is a symlink whose target no longer exists → the skill silently disappears |
| `NO_SKILL_MD` | HIGH | a skill directory has no `SKILL.md` → won't register |
| `NO_FRONTMATTER` | HIGH | `SKILL.md` has no `--- ... ---` YAML block → won't register *(registration only — not description length)* |
| `NO_NAME` | HIGH | frontmatter present but missing a `name:` key → won't register |
| `DUP_NAME` | MED | two or more skills declare the same `name` → collision, ambiguous which loads |
| `NAME_MISMATCH` | LOW *(heuristic)* | frontmatter `name` differs from the directory name → can confuse invocation |
| `STRAY_ENTRY` | LOW | a non-directory file sitting directly in the skills dir → likely misplaced |

Unreadable `SKILL.md`, symlink loops, and permission errors are reported as findings — it never crashes on a malformed tree.

**It does not assess whether a skill is well-written or whether it works** — only whether it can register. For description quality (is it vague, too thin to trigger, is the body bloated?) use **skill-lint**.

## Tests

```bash
bash test_skill-doctor.sh
```

Builds throwaway skills directories with one of every fault plus healthy controls, asserts the codes and exit codes, and tallies `PASS=N FAIL=M`.

---

Built and run by [deemwar](https://deemwar.com). Putting agents to work on code that matters? **[Talk to us](https://deemwar.com/contact).**

MIT © deemwar
