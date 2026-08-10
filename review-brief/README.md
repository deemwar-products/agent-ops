# review-brief

Reviewing an agent's PR means reconstructing intent from a finished diff with no
record of how it got there — so most developers don't fully trust AI code and only
about half verify it. For a Claude Code agent that record exists: the session
transcript. review-brief turns it into a short brief to read alongside the diff.

## Install — there's nothing to install

```bash
git clone https://github.com/deemwar-products/agent-ops
python3 agent-ops/review-brief/review-brief find        # newest transcript for cwd
python3 agent-ops/review-brief/review-brief <transcript.jsonl>   # print the review brief (markdown)
```

## What it does

- `find [project_dir]` prints the path to the newest transcript for a project (defaults to the current directory).
- Extracts what the agent was asked (the first real user turn) from the transcript.
- Lists the files it changed and flags each: read before editing, created/rewritten, or edited without reading first (a review risk).
- Counts commands run and surfaces the test/build/lint ones, then judges verification: whether a test-like command ran after the last edit, with a reviewer-focus note when something edited blind or went unverified.

## Why it exists

Reviewing AI-generated code takes longer because the diff hides the journey; the transcript has it, so review-brief hands the reviewer intent, blind edits, and verification up front. Full write-up: [Why reviewing AI code takes longer](https://deemwar.com/insights/why-reviewing-ai-code-takes-longer).

## Tests

```bash
./test_review_brief.sh        # 11/11 checks
```

---

Part of **[agent-ops](https://github.com/deemwar-products/agent-ops)** — 29 small, dependency-light tools for running AI coding agents in production, **built & run by [deemwar](https://deemwar.com)**.

Running coding-agent fleets and hitting these same walls? **[Let's talk → deemwar.com/contact](https://deemwar.com/contact)**

MIT © deemwar
