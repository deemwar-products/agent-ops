# leaklint

Flag **leaked secrets** in LLM / agent output — without ever printing the secret.

An unattended agent writes to places humans used to gate — commits, docs, logs, chat replies, the shell. Sometimes it writes a live secret there: pastes back an API key it saw, echoes a token into a commit message, drops a private key into a file, bakes a credential into a `Bash` command. `leaklint` scans a file / stdin / a session transcript for secret-shaped strings and exits non-zero on a hit.

**The load-bearing rule:** `leaklint` *never* prints the matched secret value. A finding shows only the detector name, location, the value length, a non-reversible fingerprint (`sha256[:8]`), and at most the value's public scheme prefix (e.g. `ghp_`, `AKIA` — the vendor brand, not the secret). That is what makes it safe to wire into the agent's own Stop hook, whose stdout flows back into the model's context. A scanner that echoed the secret to "show" you the finding would re-inject the very thing you're trying to contain.

## Checks (high-precision, prefix/format-anchored)

1. **PROVIDER-KEY** — known vendor key formats (OpenAI/Anthropic, GitHub, AWS, Google, Slack, Stripe, GitLab, npm, JWT, …).
2. **PRIVATE-KEY** — PEM private-key headers (`-----BEGIN … PRIVATE KEY-----`).
3. **ASSIGNED-SECRET** — a NAME containing `KEY`/`TOKEN`/`SECRET`/`PASSWORD` `= "<high-entropy literal>"`, only when the RHS is a real literal (not `$VAR` / `os.environ` / a placeholder).

## Usage

```bash
leaklint <file>
leaklint --transcript <session.jsonl>
cat out.txt | leaklint
```

Exit `1` if any secret is found, `0` if clean. One file, `python3`, no install, no network, no model call.

---

Built and run by [deemwar](https://deemwar.com). Putting agents to work on code that matters? **[Talk to us](https://deemwar.com/contact).**
