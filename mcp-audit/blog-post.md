# Learnings — Audit your `.mcp.json` before an MCP server audits you

**Voice:** deemwar, unsigned
**Length:** ~930 words
**Format:** Engineering — linting the highest-trust agent config
**CTA:** /contact

---

# Every MCP Server Is Code You Run and Text in Your Model's Head

MCP made it a one-line change to give your agent new powers: drop a server into `.mcp.json` and it can suddenly touch GitHub, your filesystem, a database, some SaaS API. That convenience is exactly why `.mcp.json` is the most dangerous config file in an agent setup — and the one nobody lints. Wiring up an MCP server does two things at once, and both are trust decisions you probably made without noticing:

1. **You run their code.** An `npx`/`uvx` server is a package that executes on your machine, every session, with your environment.
2. **You load their text into the model's head.** Every server's *tool descriptions* go straight into the model's context — instructions you didn't write, sitting right next to the user's. That's the same hidden-instruction surface we [frisk files](/insights) for, except you opted into it.

We've built linters for the other agent configs — [`settings.json`](/insights) permissions, [`CLAUDE.md`](/insights) hygiene, [`SKILL.md`](/insights) discoverability. `.mcp.json` is the missing, highest-stakes member of that family. So here's `mcp-audit`.

## What it flags

```
$ mcp-audit
mcp-audit — .mcp.json  (3 server(s))

  ● HIGH 'github' has an inline secret in env (GITHUB_TOKEN)
         a token committed in .mcp.json leaks to anyone with the repo. Use ${ENV_VAR}.
  ● WARN 'filesystem' runs an unpinned package (@modelcontextprotocol/server-filesystem)
         no version pin = you execute whatever the registry serves, every session.
  ● WARN 'filesystem' is scoped to a broad path (/Users)
         the server can read everything under it. Point it at the project dir.
  ● WARN 'weather' is a remote server (https://weather.example.com/mcp)
         your prompts + context go to that endpoint. Trust it like a dependency.
  ● INFO 3 MCP server(s) configured
```

**Inline secrets (HIGH).** The most common foot-gun: a real token pasted into the `env` block and committed. `mcp-audit` flags an env value that *looks like a secret* (a token-ish key with a high-entropy literal) — and, crucially, does **not** flag a `${GITHUB_TOKEN}` reference or a `your-key-here` placeholder. The whole point is to catch the committed credential without nagging about the correct pattern.

**Remote servers (WARN).** A `url`-based server means your prompts and context are sent to someone else's endpoint, and its tool descriptions enter your model's context. That's not wrong — but it's a dependency on a third party's code *and* trust, and you should know every one you have.

**Unpinned packages (WARN).** `npx -y @vendor/server` with no version runs whatever the registry serves *that day*. A compromised or updated package is a silent supply-chain change on the next session. The fix is a pin (`@vendor/server@1.2.3`). (Getting this check right took care: the package is the *first* non-flag argument — the paths and flags you pass to the server afterward, like `./project`, are not packages, and a linter that flagged them would be noise. A test pins exactly that.)

**Broad filesystem scope (WARN).** A filesystem server pointed at `/`, `~`, or `/Users` can read everything under it — your whole home directory is now in the agent's reach. Scope it to the project.

And it always prints the **server count** as an INFO, with the reminder that each one is an instruction surface — because the cheapest MCP security control is simply having fewer servers.

## Using it

```bash
mcp-audit                 # ./.mcp.json
mcp-audit path/to/.mcp.json
```

It exits non-zero on any HIGH/WARN, so it drops into the [CI gate](/insights) right alongside the other config checks — the moment someone commits a server with a baked-in token or a wildcard filesystem scope, the build goes red. A clean `.mcp.json` — pinned packages, scoped paths, `${ENV}` references — comes back green.

## The honest limits

It audits the *shape* of the config, not the *behavior* of the servers. It can tell you a server is remote, unpinned, or over-scoped; it can't tell you the remote one is malicious, or that the pinned package is trustworthy, or read the tool descriptions a server will actually inject (those aren't in the file — they come from the server at runtime). And "looks like a secret" is a heuristic — a genuinely weird token format can slip past, and you should still keep credentials out of the file as a rule, not because a linter caught one. Treat `mcp-audit` as the cheap structural floor for the riskiest config you own, not as a verdict on the servers themselves.

## The real lesson

The friction of adding capabilities to an agent has dropped to a single JSON entry — and the trust that entry represents has not dropped at all. Each MCP server is third-party code you execute and third-party text you feed your model, and `.mcp.json` accumulates them quietly, one convenient line at a time. The other config files in an agent setup get linted; this one, the highest-stakes of them, usually doesn't. Point a check at it: catch the committed token, the unpinned package, the wildcard scope, the remote you forgot you added — and keep the most powerful file in your repo honest.

*We build and run autonomous agent fleets on Claude Code in production, MCP servers and all. If you're wiring agents into real systems, [talk to us](/contact).*
