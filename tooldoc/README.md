# tooldoc

An MCP tool is only as usable as its description. The model never sees your code — it sees the tool's name, its description, and the JSON schema of its parameters, and picks the tool and fills the arguments from that text alone. When a parameter has no description, the model guesses. Guessing is where agents go wrong. tooldoc grades the *documentation* of your tools.

## Install — there's nothing to install

```bash
git clone https://github.com/deemwar-products/agent-ops
python3 agent-ops/tooldoc/tooldoc                              # read ./.mcp.json, connect to each server, audit
python3 agent-ops/tooldoc/tooldoc --server "npx -y @scope/srv" # audit one ad-hoc stdio server
python3 agent-ops/tooldoc/tooldoc --tools tools.json           # offline: audit a captured tools/list array
```

## What it does

- Flags tools with no description or a one-word description.
- Flags PARAMETERS with no description — the big one, since the model can't infer what `path` means.
- Flags free-form string params with no description AND no enum (maximally guess-prone), and the same tool name exposed by two servers (name shadowing).
- Reports a per-server grade plus a corpus-wide "what %% of parameters are undocumented" number. `--top N`, `--min-grade A..F`, `--json` available.

The grade is heuristic, weighted on parameter-description coverage (what most agents actually trip on). Exit `0` normally, `1` if `--min-grade` isn't met or on a fatal error.

## Why it exists

Agents fill tool arguments from documentation alone, so undocumented params turn into guesses. Full write-up: [Your agent is guessing your tool parameters](https://deemwar.com/insights/your-agent-is-guessing-your-tool-parameters).

## Tests

```bash
./test_tooldoc.sh        # 15/15 checks
```

---

Part of **[agent-ops](https://github.com/deemwar-products/agent-ops)** — 29 small, dependency-light tools for running AI coding agents in production, **built & run by [deemwar](https://deemwar.com)**.

Running coding-agent fleets and hitting these same walls? **[Let's talk → deemwar.com/contact](https://deemwar.com/contact)**

MIT © deemwar
