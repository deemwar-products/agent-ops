# trifecta-scan

The attack that actually steals your data doesn't live in one tool — it lives in a *combination*. Simon Willison's "lethal trifecta" says an agent is exposed to data theft the moment its granted capabilities cover all three of **private data**, **untrusted input**, and **exfiltration**. A per-file linter never sees it, because no single line is wrong; the danger is the union.

## Install — there's nothing to install

```bash
git clone https://github.com/deemwar-products/agent-ops
python3 agent-ops/trifecta-scan/trifecta-scan          # default: . — reads ./.mcp.json + ./.claude/settings.json
python3 agent-ops/trifecta-scan/trifecta-scan DIR ...  # scan one or more directories
```

## What it does

- Reads `.mcp.json` and `.claude/settings.json`, classifies every granted capability into the three legs — PRIVATE (read your data), UNTRUSTED (ingest attacker-controllable content), EXFIL (send data outward) — and flags when the union covers all three.
- Notes when a single tool carries multiple legs (an arbitrary-URL web-fetch is both untrusted input AND exfil; Bash is all three).
- Is **deny-aware**: whole-tool / whole-server `permissions.deny` rules are netted out. It does *not* model fine-grained Bash subcommand denies — `Bash(curl:*)` still counts Bash as exfil-capable.
- Detects bypass mode (`skipDangerousModePermissionPrompt` / `defaultMode: bypassPermissions` with no allowlist) and synthesizes the full native toolset rather than reporting a misleading "nothing to scan."
- On a complete trifecta, names which capabilities supply each leg and points at the fix — Meta's "rule of two": break any one leg.

**Heuristic, not a proof:** it reasons over capability *names*, erring toward naming the legs. Treat a clean result as "no obvious trifecta," not proof of safety.

Exit `0` = trifecta NOT complete, `1` = complete (or a config failed to parse).

## Why it exists

No single line in your agent config is wrong — the combination is. Full write-up: [No single line is wrong — the combination is](https://deemwar.com/insights/no-single-line-is-wrong-the-combination-is).

## Tests

```bash
./test_trifecta_scan.sh        # 25/25 checks
```

---

Part of **[agent-ops](https://github.com/deemwar-products/agent-ops)** — 29 small, dependency-light tools for running AI coding agents in production, **built & run by [deemwar](https://deemwar.com)**.

Running coding-agent fleets and hitting these same walls? **[Let's talk → deemwar.com/contact](https://deemwar.com/contact)**

MIT © deemwar
