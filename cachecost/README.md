# cachecost

Prompt caching can make repeated input ~10x cheaper — but only if you can see what a cache
write cost versus what each read saved. cachecost reads a Claude API `usage` object and shows
what caching actually cost or saved on that request, in model-agnostic base-input-token units
(no dollar tables to wire up).

## Install — there's nothing to install

```bash
git clone https://github.com/deemwar-products/agent-ops
python3 agent-ops/cachecost/cachecost explain usage.json                 # cost/savings on one request
python3 agent-ops/cachecost/cachecost amortize write_usage.json read_usage.json --reads 10  # write paid off over N reads
```

## What it does

- Reads a Claude API `usage` object (raw or a full message with `.usage`) and computes input-equivalent cost using fixed multipliers of base input price: uncached `1.00x`, cache **write** `1.25x` (5-min TTL), cache **read** `0.10x`.
- `explain` shows what caching cost or saved on a single request versus the same prompt with caching off.
- `amortize` takes a write-usage and a read-usage object and shows when the `1.25x` write cost pays for itself across `--reads N` cache hits.
- `--write-mult M` / `--read-mult M` override the multipliers (e.g. `2.00x` write for the 1-hour TTL).

Totals follow Anthropic's accounting: full prompt size = `input_tokens + cache_creation_input_tokens + cache_read_input_tokens`, where `input_tokens` is only the uncached remainder.

## Why it exists

Most teams enable prompt caching and never check whether the write cost is actually being amortized — leaving a 10x saving on the table. Full write-up: [The prompt-caching 10x most teams miss](https://deemwar.com/insights/the-prompt-caching-10x-most-teams-miss).

## Tests

```bash
./test_cachecost.sh        # 11/11 checks
```

---

Part of **[agent-ops](https://github.com/deemwar-products/agent-ops)** — 29 small, dependency-light tools for running AI coding agents in production, **built & run by [deemwar](https://deemwar.com)**.

Running coding-agent fleets and hitting these same walls? **[Let's talk → deemwar.com/contact](https://deemwar.com/contact)**

MIT © deemwar
