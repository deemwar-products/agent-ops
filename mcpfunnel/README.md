# mcpfunnel

The official MCP registry is the canonical catalog everyone points their agents at — but "listed in the registry" is not "installs and runs." mcpfunnel pulls the registry and measures the drop-off from every listed server down to the ones that actually boot and complete a handshake.

## Install — there's nothing to install

```bash
git clone https://github.com/deemwar-products/agent-ops
python3 agent-ops/mcpfunnel/mcpfunnel                       # fetch the live registry, report composition
python3 agent-ops/mcpfunnel/mcpfunnel --boot --sample 50    # also launch installable servers, test the handshake
python3 agent-ops/mcpfunnel/mcpfunnel --registry servers.json  # analyze a saved registry dump (offline)
```

## What it does

- Pulls the registry and measures the funnel: ALL listed → INSTALLABLE (ships a runnable npm/PyPI package, not remote-only) → RESOLVES (the package actually exists, not a dead pointer) → HANDSHAKE (boots and completes an MCP initialize + tools/list with no config).
- Each stage is deterministic: registry JSON, a registry 404 check, and a fixed JSON-RPC handshake over stdio. No model anywhere.
- `--boot` actually launches servers (may be slow); `--sample N`, `--timeout S`, `--json` available.
- Honest caveat: a server that fails the handshake may just need credentials, not be broken — so HANDSHAKE measures "runs out of the box," and the report splits no-start from no-handshake so you can tell the difference.

Exit `0` always — it's a report.

## Why it exists

The registry catalogs servers that often don't actually run; "in the registry" is not "runs." Full write-up: ["In the registry" is not "runs"](https://deemwar.com/insights/in-the-registry-is-not-runs).

## Tests

```bash
./test_mcpfunnel.sh        # 12/12 checks
```

---

Part of **[agent-ops](https://github.com/deemwar-products/agent-ops)** — 29 small, dependency-light tools for running AI coding agents in production, **built & run by [deemwar](https://deemwar.com)**.

Running coding-agent fleets and hitting these same walls? **[Let's talk → deemwar.com/contact](https://deemwar.com/contact)**

MIT © deemwar
