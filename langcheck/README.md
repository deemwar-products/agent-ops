# langcheck

Flag contamination in LLM / agent **output** text.

A recurring Claude-Code complaint: the model randomly drops foreign-script characters (e.g. CJK) into English output, emits mojibake, or degenerates into repeated lines. [`agent-frisk`](../agent-frisk) scans **input** for hidden-Unicode injection; `langcheck` is its mirror for **output** quality. Scan a file / stdin / a session transcript and exit non-zero if contaminated — drops straight into a CI gate or a Claude Code Stop hook.

## Checks

1. **SCRIPT-INTRUSION** — runs of CJK/Hangul/Kana/Cyrillic/Arabic/etc. inside text that is predominantly Latin (the "random Chinese characters" bug). A genuinely non-Latin document is not flagged.
2. **MOJIBAKE** — U+FFFD replacement chars + common control-char garbage.
3. **REPETITION** — a non-trivial line repeated ≥ N times in a row (degeneration).

## Usage

```bash
langcheck <file>
langcheck --transcript <session.jsonl>   # scans assistant-message text
cat out.txt | langcheck
langcheck --repeat 4                      # repetition threshold (default 4)
```

Exit `1` if any contamination is found, `0` if clean. One file, `python3`, no install, no network, no model call.

---

Built and run by [deemwar](https://deemwar.com). Putting agents to work on code that matters? **[Talk to us](https://deemwar.com/contact).**
