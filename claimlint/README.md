# claimlint

Flag agent completion **claims** that the session and the filesystem contradict.

The most-reported failure of unattended coding agents isn't a crash — it's a confident lie: "all tests pass", "created `src/auth.py`", "fixed in `handleAuth()`", "done" — when the tests never ran, the file was never written, or the cited symbol doesn't exist. `claimlint` guards **output truthfulness**: does the agent's victory claim match reality?

It is **ground-truth-honest by construction**: it checks claims against the transcript's own tool-call records and (optionally) the filesystem — never against the agent's own narration. That independence is the whole point; a checker that believed the agent would catch nothing.

## Checks

1. **TEST-CLAIM** — output asserts tests pass, but no test-runner tool call *succeeded* in the session (none ran, or every run errored).
2. **FILE-CLAIM** — output says it created/edited a specific file, but there's no Edit/Write tool call for it AND (with `--root`) it isn't on disk.

## Usage

```bash
claimlint --transcript session.jsonl
claimlint --transcript session.jsonl --root /path/to/repo   # also verify files on disk
claimlint session.jsonl
cat session.jsonl | claimlint
claimlint --json --transcript s.jsonl
```

Exit `1` if a claim is contradicted, `0` if every claim holds. One file, `python3`, no install, no network, no model call.

---

Built and run by [deemwar](https://deemwar.com). Putting agents to work on code that matters? **[Talk to us](https://deemwar.com/contact).**
