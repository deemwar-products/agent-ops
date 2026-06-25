# mcp-doctor

Will your MCP servers actually **start**? A static health check for `.mcp.json`.

A configured MCP server whose command isn't installed fails *silently* — Claude Code reads the entry, tries to spawn it, the binary isn't on PATH (or the url is malformed), the launch fails, and you just see **no tools from that server**, with no error in your face. `mcp-doctor` statically inspects each server entry and tells you which ones can't possibly launch — before you waste a session wondering where your tools went.

It's the **health complement to [`mcp-audit`](../mcp-audit)**: `mcp-audit` asks whether a server is *safe* (secrets / egress / supply-chain); `mcp-doctor` asks whether it's *runnable*. They don't overlap — `mcp-doctor` runs **no** security checks.

## Install — there's nothing to install

```bash
git clone https://github.com/deemwar-products/agent-ops
python3 agent-ops/mcp-doctor/mcp-doctor                 # checks ./.mcp.json
python3 agent-ops/mcp-doctor/mcp-doctor ~/.claude.json  # or an explicit path
cat .mcp.json | python3 agent-ops/mcp-doctor/mcp-doctor - --json
```

One file, `python3`, no third-party deps. Default search order: `./.mcp.json`, then `~/.claude.json` (Claude Code stores `mcpServers` there too), then `~/.mcp.json`. Use `-` to read from stdin. Exit `0` clean / `1` findings / `2` bad input (missing file, invalid JSON, or no `mcpServers` block).

## What it does

It is a **static** check — it verifies the command resolves and the config is well-formed. It **never** starts a server, opens a socket, makes a network call, or checks auth/runtime. Some checks are heuristics, labelled below.

- **CMD_NOT_FOUND** (HIGH) — a stdio server whose `command` doesn't resolve on PATH (`shutil.which`) and isn't an executable file. This is the headline silent failure.
- **NO_COMMAND_OR_URL** (HIGH) — an entry with neither a usable `command` nor a `url`/remote `type`. Malformed, nothing to launch.
- **BAD_URL** (HIGH) — a remote server with a missing/malformed `url` (no scheme, or a scheme that isn't `http`/`https`).
- **ENV_UNSET** (MED, *heuristic*) — the server's `env` values or `${VAR}` references point at an environment variable that isn't set in the current process. The server may fail to authenticate. Reported by **name only** — the value is never read or printed.
- **LAZY_FETCH** (LOW, *heuristic*) — `command` is `npx`/`uvx`/`bunx`: the package is fetched on first run, so it needs network + a correct package name to ever launch. Quiet info-level note.
- **SHAPE** issues (HIGH/MED) — `mcpServers`, a server entry, `args`, or `command` of the wrong JSON type are reported as findings, never as a traceback.

`--json` emits `{"findings":[...], "summary":{"total","high","med","low"}}`.

## Tests

```bash
cd mcp-doctor && bash test_mcp-doctor.sh   # ≥10 inline-fixture cases, exits non-zero on any failure
```

---

Built and run by [deemwar](https://deemwar.com). Putting agents to work on code that matters? **[Talk to us](https://deemwar.com/contact).**

MIT © deemwar
