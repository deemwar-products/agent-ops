# mcp-budget

Every MCP server you wire up injects its tools' definitions into the model's context on
*every* turn, before you type a prompt — a compounding tax that can quietly eat half your
window. mcp-budget measures exactly how many tokens that costs, so you can see what you're
spending before your first prompt.

## Install — there's nothing to install

```bash
git clone https://github.com/deemwar-products/agent-ops
python3 agent-ops/mcp-budget/mcp-budget --window 200000   # read ./.mcp.json, connect, measure
python3 agent-ops/mcp-budget/mcp-budget --tools tools.json # offline: measure a captured tools/list
python3 agent-ops/mcp-budget/mcp-budget --server "npx -y @scope/server arg"  # one ad-hoc server
```

## What it does

- Connects to your MCP servers (JSON-RPC over stdio: `initialize` → `tools/list`), serializes each tool exactly as a client ships it to the model (name + description + JSON input schema), and counts the tokens.
- Reports per-tool, per-server, and a grand total framed as "spent before your first prompt," with a `--window` percentage readout.
- `--budget N` turns it into a CI gate; `--json` gives machine-readable output.
- Counts the honest number — the serialized definitions you actually ship — rather than Claude Code's `/context`, which over-reports MCP cost (~3x).

Token counts are an **ESTIMATE** (~4 chars/token; Claude's tokenizer isn't public). Treat them as a budgeting signal, not a billing figure.

Exit `0` = within budget/ok, `1` = `--budget` exceeded or a fatal error.

## Why it exists

A Claude Code user measured MCP tool definitions eating 49% of a 200K window — paid every turn, before any work happens. Full write-up: [The hidden context tax of MCP](https://deemwar.com/insights/the-hidden-context-tax-of-mcp).

## Tests

```bash
./test_mcp_budget.sh        # 14/14 checks
```

---

Part of **[agent-ops](https://github.com/deemwar-products/agent-ops)** — 29 small, dependency-light tools for running AI coding agents in production, **built & run by [deemwar](https://deemwar.com)**.

Running coding-agent fleets and hitting these same walls? **[Let's talk → deemwar.com/contact](https://deemwar.com/contact)**

MIT © deemwar
