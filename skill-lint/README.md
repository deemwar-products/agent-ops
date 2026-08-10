# skill-lint

A Claude Code skill is loaded on demand: the model reads only its name and description, then decides whether to pull in the full SKILL.md. A vague or too-short description means the skill silently never triggers — dead weight you wrote and forgot. And once it does trigger, the whole body loads into context, so a bloated SKILL.md taxes every run that uses it. skill-lint checks both, plus the basics.

## Install — there's nothing to install

```bash
git clone https://github.com/deemwar-products/agent-ops
python3 agent-ops/skill-lint/skill-lint            # audit ./SKILL.md
python3 agent-ops/skill-lint/skill-lint my-skill/  # audit one or more skills by dir
```

## What it does

- Flags a missing YAML frontmatter block, a missing `name`, or a `name` that doesn't match its folder.
- Flags a missing description, or one too thin to trigger reliably (under 10 words = HIGH, under 20 = WARN).
- Flags a description that says what the skill does but not WHEN to use it (no trigger cues).
- Reports the body's token weight, since the whole SKILL.md loads into context on every use.

Exit `0` = healthy, `1` = at least one finding.

## Why it exists

A skill the model never chooses is invisible work — the description is the whole ballgame. Full write-up: [Your skill's description is the whole ballgame](https://deemwar.com/insights/your-skills-description-is-the-whole-ballgame).

## Tests

```bash
./test_skill_lint.sh        # 12/12 checks
```

---

Part of **[agent-ops](https://github.com/deemwar-products/agent-ops)** — 29 small, dependency-light tools for running AI coding agents in production, **built & run by [deemwar](https://deemwar.com)**.

Running coding-agent fleets and hitting these same walls? **[Let's talk → deemwar.com/contact](https://deemwar.com/contact)**

MIT © deemwar
