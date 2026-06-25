# agent-doctor

Will your Claude Code **custom subagent** actually register and get routed to?

A custom subagent is just a markdown file — `.claude/agents/<name>.md` (project) or `~/.claude/agents/<name>.md` (user) — with YAML frontmatter and a body that becomes the agent's system prompt. The frontmatter is load-bearing in a way that **fails silently**: get it wrong and there's no error, no warning — the agent just isn't there. A missing `name`, a missing `description` (the model routes to subagents by their description), a stray non-frontmatter file — each one quietly drops the agent off the roster. You wrote it, you forgot it, it never fires.

`agent-doctor` scans an agents directory (or a single `.md`) and flags only the things it's confident break **registration or routing** — never your prompt's wording, never which tools you picked.

## Install — there's nothing to install

One file, `python3`, stdlib only, no network, no model call.

```bash
git clone https://github.com/deemwar-products/agent-ops
python3 agent-ops/agent-doctor/agent-doctor                 # default: ~/.claude/agents, then ./.claude/agents
python3 agent-ops/agent-doctor/agent-doctor .claude/agents  # a specific dir
python3 agent-ops/agent-doctor/agent-doctor reviewer.md     # a single agent file
python3 agent-ops/agent-doctor/agent-doctor --json .claude/agents
```

Exit `0` clean · `1` findings · `2` bad input (path missing / not a dir-or-`.md` / empty dir).

## What it does

Each agent file becomes one or more findings with a stable code and a severity:

| Code | Severity | What it catches |
|------|----------|-----------------|
| `NO_FRONTMATTER` | HIGH | no `--- ... ---` YAML block — the file never registers as an agent. |
| `NO_NAME` | HIGH | frontmatter missing `name` — nothing to reference it by. |
| `NO_DESCRIPTION` | HIGH | frontmatter missing `description` — the model routes to subagents by description; without one the agent is effectively unreachable by auto-selection. |
| `NAME_MISMATCH` | MED *(heuristic)* | frontmatter `name` differs from the filename — invocation confusion. |
| `DUP_NAME` | MED | two agent files declare the same `name` — ambiguous which one loads (both files flagged). |
| `EMPTY_BODY` | LOW | no system-prompt body after the frontmatter — the agent has no instructions. |
| `TOOLS_MALFORMED` | LOW *(heuristic)* | `tools` is present but is neither a string nor a list (e.g. a number or a dict) — may not parse. |

It is **conservative by design**. It does **not** validate individual tool *names* — the tool registry varies per setup, so flagging a tool name would mean guessing, and a checker that guesses isn't honest. Absent `tools` is fine (the agent inherits all tools). Unreadable files and odd paths are reported as findings or a clean exit `2`, never a traceback.

Human output is grouped per agent; `--json` emits `{"agents_dir", "agents_scanned", "findings":[{agent,file,code,severity,message}], "summary":{total,high,med,low}}`.

This is the **agents** member of the "agent config that fails silently" family — alongside `skill-doctor` (skills), `hooklint` (hooks), and `mcp-doctor` (MCP servers). Same shape, different config surface.

> **Honest disclaimer:** agent-doctor checks structure/registration health, not whether the agent's prompt is well-written or its tool list is right.

## Tests

```bash
./test_agent-doctor.sh        # synthetic fixtures, asserts exit codes + check codes
```

---

Built and run by [deemwar](https://deemwar.com). Putting agents to work on code that matters? **[Talk to us](https://deemwar.com/contact).**

MIT © deemwar
