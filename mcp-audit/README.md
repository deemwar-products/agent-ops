# mcp-audit

Every MCP server you wire up is code you run and a set of tool descriptions that go straight into the model's context — the single largest trust + injection + egress surface in an agent setup, and the one config nobody lints. mcp-audit reads `.mcp.json` and flags the server shapes that actually bite.

## Install — there's nothing to install

```bash
git clone https://github.com/deemwar-products/agent-ops
python3 agent-ops/mcp-audit/mcp-audit              # default: ./.mcp.json
python3 agent-ops/mcp-audit/mcp-audit .mcp.json ...   # audit specific files
```

## What it does

- Flags **remote (url/sse/http) servers** — your prompts and context go to someone else's endpoint, and their tool descriptions enter the model's context.
- Flags **unpinned packages** — `npx`/`bunx`/`pnpm` packages with no version pin (you run whatever the registry serves each session), and unpinned `uvx`/`uv` python tools.
- Flags **inline secrets in `env`** — a value under a token/secret/key/password-shaped key that looks like a real credential rather than a `${VAR}` reference.
- Flags **broad filesystem scope** — a server pointed at `/`, `$HOME`, `~`, `/Users`, or `/home`.
- Always reports the count of configured servers — each one's tool descriptions are an instruction surface you didn't write.

Exit `0` = clean, `1` = at least one finding.

## Why it exists

Your `.mcp.json` is the largest trust and injection surface in an agent setup, and nobody lints it. Full write-up: [blog-post.md](./blog-post.md).

## Tests

```bash
./test_mcp_audit.sh        # 14/14 checks
```

---

Part of **[agent-ops](https://github.com/deemwar-products/agent-ops)** — 29 small, dependency-light tools for running AI coding agents in production, **built & run by [deemwar](https://deemwar.com)**.

Running coding-agent fleets and hitting these same walls? **[Let's talk → deemwar.com/contact](https://deemwar.com/contact)**

MIT © deemwar
