# slopcheck

LLMs hallucinate package names — a USENIX Security 2025 study found 19.7% of AI-generated code referenced a package that doesn't exist, and 43% of those reappear on *every* re-run. That predictability is the attack: someone registers the commonly-hallucinated name ("slopsquatting"), and the next agent that confidently installs it pulls their code. slopcheck reads your manifest and flags the deps that smell invented.

## Install — there's nothing to install

```bash
git clone https://github.com/deemwar-products/agent-ops
python3 agent-ops/slopcheck/slopcheck requirements.txt              # audit a manifest
python3 agent-ops/slopcheck/slopcheck --ecosystem pypi reqests       # audit names directly
```

## What it does

- Reads `package.json` / `requirements.txt` and checks each package against the live registry (registry.npmjs.org / pypi.org).
- **HIGH** — not in the registry at all (hallucinated, a typo, or a name waiting to be squatted).
- **WARN** — one edit away from a hugely-popular package (likely typo: `reqests` → `requests`), or exists but barely downloaded.
- **INFO** — no source repo / homepage (thin provenance). `--min-downloads N`, `--json`, and `--meta <file.json>` for offline scoring.

This is a heuristic supply-chain smell test, not proof of malice — it tells you which deps to look at twice. Exit `0` = clean, `1` = a HIGH risk found.

## Why it exists

Agents confidently import packages that were never real, and squatters are waiting on the predictable names. Full write-up: [Your agent imports a package nobody trusts](https://deemwar.com/insights/your-agent-imports-a-package-nobody-trusts).

## Tests

```bash
./test_slopcheck.sh        # 11/11 checks
```

---

Part of **[agent-ops](https://github.com/deemwar-products/agent-ops)** — 29 small, dependency-light tools for running AI coding agents in production, **built & run by [deemwar](https://deemwar.com)**.

Running coding-agent fleets and hitting these same walls? **[Let's talk → deemwar.com/contact](https://deemwar.com/contact)**

MIT © deemwar
