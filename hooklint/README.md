# hooklint

Lint your Claude Code `hooks` config before it fails silently.

Hooks run real shell on your agent's tool events — `PreToolUse`, `PostToolUse`, `Stop`, and friends. The failure mode is quiet: a typo'd event name, a `matcher` on an event that ignores it, or a hook entry missing `"type":"command"` just never fires, with no error to tell you. [`perm-audit`](../perm-audit) checks what your agent may *do*; [`mcp-audit`](../mcp-audit) checks the servers it loads; `hooklint` checks the other config that runs shell — the `"hooks"` block in `.claude/settings.json`.

## Install — there's nothing to install

```bash
git clone https://github.com/deemwar-products/agent-ops
python3 agent-ops/hooklint/hooklint ~/.claude/settings.json
```

One file, `python3`, no third-party deps, no network, no model call. With no path it searches `./.claude/settings.json`, then `./.claude/settings.local.json`, then `~/.claude/settings.json`. Pass `-` to read from stdin, `--json` for machine-readable findings.

## What it does

Validates the structure of the `hooks` block (event-name → list of matcher-groups → `{type, command}` entries) and flags known pitfalls:

1. **UNKNOWN_EVENT** (HIGH) — event name not in the valid set (`PreToolUse`, `PostToolUse`, `UserPromptSubmit`, `Notification`, `Stop`, `SubagentStop`, `PreCompact`, `SessionStart`, `SessionEnd`). The hook silently never fires.
2. **HOOK_BAD_COMMAND** (HIGH) — a hook entry missing `"type":"command"` or with a missing/empty `command`. It never runs.
3. **MATCHER_IGNORED** (MED) — a `matcher` on an event that ignores it (only `PreToolUse` / `PostToolUse` use `matcher`). The matcher does nothing — likely a mistake.
4. **BAD_MATCHER_REGEX** (HIGH) — a `matcher` that fails `re.compile` on `PreToolUse` / `PostToolUse`. The matcher-group never matches.
5. **CMD_RELATIVE** (LOW, *heuristic*) — a command that looks relative (`./x.sh` or a bare `foo.sh`/`foo.py`). May not resolve depending on the hook's working directory.
6. **CMD_RISKY** (MED, *heuristic*) — a command containing `rm -rf`, `curl … | sh/bash`, or `eval`. Hooks run with your shell's privileges — review it.
7. **EMPTY_EVENT / EMPTY_GROUP** (LOW) — an event with no matcher-groups, or a matcher-group with no `hooks` entries. It does nothing.

Wrong types (a dict where a list is expected, a non-object hook entry) are reported as findings, never a traceback.

Heuristics are labelled as heuristic and never overclaimed. hooklint checks **structure and known pitfalls — not whether a hook's logic is correct.** A hook that runs and does the wrong thing looks clean here.

Exit `0` = clean, `1` = problems found, `2` = bad input (missing file / invalid JSON / no hooks block).

## Tests

```bash
bash test_hooklint.sh
```

---

Built and run by [deemwar](https://deemwar.com). Putting agents to work on code that matters? **[Talk to us](https://deemwar.com/contact).**

MIT © deemwar
