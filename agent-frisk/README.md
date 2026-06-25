# agent-frisk

Indirect prompt injection is the top security risk for AI coding agents: an attacker hides instructions in a file, dependency, skill/MCP description, or fetched web page that look empty to you but are real tokens to the model. agent-frisk finds the invisible Unicode that carries those payloads, before your agent ingests it.

## Install — there's nothing to install

```bash
git clone https://github.com/deemwar-products/agent-ops
python3 agent-ops/agent-frisk/agent-frisk <file...>        # scan files; exit 1 if anything hidden is found
curl … | python3 agent-ops/agent-frisk/agent-frisk -       # scan stdin (e.g. a fetched page)
python3 agent-ops/agent-frisk/agent-frisk --strip <file>   # remove the hidden characters in place (writes a .bak)
```

## What it does

- Scans content for three classes of concealment: Unicode TAG codepoints (U+E0000–U+E007F — invisible, but read as text by LLMs), zero-width / invisible characters (ZWSP/ZWNJ/ZWJ, word joiner, BOM, soft hyphen, …), and bidirectional overrides (U+202A–U+202E, U+2066–U+2069 — "Trojan Source").
- Reports each hit with line:col, the `U+XXXX` codepoint, its category, and the Unicode name.
- `--strip` removes those characters in place and writes a `.bak` backup first.

Exit `0` = clean, `1` = hidden characters found (`2` = no paths given).

## Why it exists

Agents act on text you can't see — hidden Unicode turns a "blank" line into a model instruction. Full write-up: [Your agent reads text you can't see](https://deemwar.com/insights/your-agent-reads-text-you-cant-see).

## Tests

```bash
./test_agent_frisk.sh        # 11/11 checks
```

---

Part of **[agent-ops](https://github.com/deemwar-products/agent-ops)** — 29 small, dependency-light tools for running AI coding agents in production, **built & run by [deemwar](https://deemwar.com)**.

Running coding-agent fleets and hitting these same walls? **[Let's talk → deemwar.com/contact](https://deemwar.com/contact)**

MIT © deemwar
