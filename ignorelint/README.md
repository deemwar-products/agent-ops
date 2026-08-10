# ignorelint

Catch the **secret file git is already committing** — before it ships.

Committing a `.env`, or an `.mcp.json` / `.claude/settings.local.json` with a live API token, is the classic one-keystroke disaster. And here's the trap people miss: **`.gitignore` does NOT save a file git is ALREADY tracking.** Add `.env` to `.gitignore` *after* it's been committed and git keeps tracking it — the secret is still in the repo, still in history. `ignorelint` checks every commonly-secret file in your work tree against git's ignore + tracking state and tells you which ones are exposed.

It is **agent-aware**: it knows the files that hold agent/dev secrets, not just `.env`.

## Install — there's nothing to install

One file, `python3`, stdlib only, no network. Clone and run:

```bash
git clone https://github.com/deemwar-products/agent-ops
python3 agent-ops/ignorelint/ignorelint            # scan the current git repo
python3 agent-ops/ignorelint/ignorelint <path>     # scan a specific repo / subdir
python3 agent-ops/ignorelint/ignorelint --json     # machine-readable (for hooks/CI)
python3 agent-ops/ignorelint/ignorelint --add '*.secret'   # extend the list (repeatable)
```

Exit `0` clean, `1` findings, `2` bad input (not a git repo / git unavailable).

## What it does

In a git repo it walks the work tree for files on a **curated, agent/dev-aware** secret-file list and reports two things:

- **TRACKED_SECRET** (HIGH) — the file is tracked/committed. `.gitignore` won't untrack it and the secret is in history. Rotate it, then `git rm --cached`.
- **UNIGNORED_SECRET** (MED) — the file is present, not tracked, and not gitignored: one `git add .` from a leak. Add it to `.gitignore`.

A file that's ignored **and** untracked is clean. A file that's both ignored *and* tracked is still HIGH — tracking wins.

The curated list (kept conservative, to avoid false positives): `.env`, `.env.*`, `.mcp.json`, `.claude.json`, `.claude/settings.local.json`, `secrets.json`, `*.pem`, `*.p12`, `*.pfx`, `id_rsa` / `id_dsa` / `id_ecdsa` / `id_ed25519`, `.npmrc`, `.netrc`, `.pypirc`. It **never** flags the committed-on-purpose variants — `.env.example`, `.env.sample`, `.env.template`, `.env.dist`, or any `.pub` public key.

**It checks git STATE, not file CONTENTS.** ignorelint never opens a secret file — it only asks git whether the file is ignored and whether it's tracked. So a custom-named or inline secret won't be caught; for that, run a content scanner like **leaklint**. The two complement each other: `ignorelint` watches which secret *files* git is exposing, `leaklint` watches for secret *values* in output.

## Tests

```bash
cd ignorelint && bash test_ignorelint.sh
```

---

Built and run by [deemwar](https://deemwar.com). Putting agents to work on code that matters? **[Talk to us](https://deemwar.com/contact).**

MIT © deemwar
