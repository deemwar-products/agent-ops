# agent-reach

A coding agent with shell/file access can read anything your shell can. Before you point one at a repo — especially with `--dangerously-skip-permissions` — the real question isn't "will it misbehave?" but "if it's hijacked by injected instructions, what secrets are in reach?" agent-reach answers that by listing the secret-bearing files reachable from here.

## Install — there's nothing to install

```bash
git clone https://github.com/deemwar-products/agent-ops
python3 agent-ops/agent-reach/agent-reach              # audit current repo tree + well-known home credential stores
python3 agent-ops/agent-reach/agent-reach --repo-only  # only the repo tree (skip $HOME)
python3 agent-ops/agent-reach/agent-reach <dir>        # audit a specific directory tree
```

## What it does

- Walks the repo tree (pruning `.git`, `node_modules`, `.venv`, etc.) and flags secret-bearing files by name — `.env*`, `*.pem`/`*.key`, SSH keys, `.npmrc`, `.netrc`, `.git-credentials`, GCP service-account JSON, key stores, password databases, and more.
- Checks well-known `$HOME` credential stores by existence only — AWS creds, SSH keys, GitHub CLI token, Docker/Kube auth, npm token, gcloud creds (skipped with `--repo-only`).
- For repo hits inside a git tree, marks any file that is **COMMITTED (not gitignored)** — in-tree secrets are worse than ignored ones.
- Reports a final blast-radius count of secret stores in reach.

**Safety:** reports file PATHS and existence only. It never opens or prints secret contents.

Exit `0` = nothing sensitive in reach, `1` = blast radius is non-empty.

## Why it exists

A hijacked agent's blast radius is everything your shell can read, not just the repo. Full write-up: [Your agent can read everything your shell can](https://deemwar.com/insights/your-agent-can-read-everything-your-shell-can).

## Tests

```bash
./test_agent_reach.sh        # 12/12 checks
```

---

Part of **[agent-ops](https://github.com/deemwar-products/agent-ops)** — 29 small, dependency-light tools for running AI coding agents in production, **built & run by [deemwar](https://deemwar.com)**.

Running coding-agent fleets and hitting these same walls? **[Let's talk → deemwar.com/contact](https://deemwar.com/contact)**

MIT © deemwar
