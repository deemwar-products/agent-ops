# agent-ops

**Small, dependency-light operational tools for AI coding agents.**

A coding agent edits your source, runs your shell, reads whatever files it can reach, and spends money — at machine speed, often unattended. That's a production system, and it needs the same operational layer you'd give anything else with that much reach: recover, prevent, observe, spend, secure, set up, verify.

These are the tools we built filling each gap, one real failure at a time, running autonomous agent fleets on Claude Code in production. Each is a single script (Python 3 or bash), no install, no dependencies beyond a stock interpreter. Each links to a write-up explaining the failure it prevents and the data behind it.

> Read the thesis: **[Your AI coding agent needs an operational layer](https://deemwar.com/insights/coding-agents-need-an-operational-layer)**

## Install

```bash
git clone https://github.com/muthuishere/agent-ops
# each tool is self-contained — run it directly:
python3 agent-ops/mcp-budget/mcp-budget .
bash    agent-ops/preflight/preflight
```

## The tools

### Recover & protect agent work

| Tool | What it does | The story |
|------|--------------|-----------|
| [`recover`](recover/) | get an agent's vanished commit back — reflog + fsck recovery for work you thought was gone | [read →](https://deemwar.com/insights/recover-an-agents-vanished-work) |
| [`unwedge`](unwedge/) | rescue a Claude Code session stuck on the thinking-block 400 ('thinking blocks cannot be modified') | [read →](https://deemwar.com/insights/unwedge-a-stuck-claude-code-session) |
| [`auto-snapshot`](auto-snapshot/) | make an agent's uncommitted work impossible to lose — auto-snapshot the working tree | [read →](https://deemwar.com/insights/the-agent-work-you-cant-recover) |
| [`preflight`](preflight/) | ask git before your agents collide — a worktree/branch collision pre-check | [read →](https://deemwar.com/insights/preflight-check-before-agents-collide) |
| [`worktree-doctor`](worktree-doctor/) | flag agent worktrees that would silently lose work on cleanup | [read →](https://deemwar.com/insights/your-agent-fleets-worktrees-are-a-minefield) |
| [`mergerase`](mergerase/) | find public capabilities that silently disappeared across a parallel-agent merge | [read →](mergerase/blog-post.md) |

### See your fleet (observe)

| Tool | What it does | The story |
|------|--------------|-----------|
| [`fleet-ps`](fleet-ps/) | ps for your Claude Code agent fleet — which sessions are alive, on what branch, healthy or wedged | [read →](https://deemwar.com/insights/a-dozen-agents-which-one-is-stuck) |
| [`session-stats`](session-stats/) | read what a Claude Code session actually did, straight from the transcript | [read →](https://deemwar.com/insights/whats-in-your-claude-code-session-file) |
| [`review-brief`](review-brief/) | a reviewer brief from the transcript — close the AI-code verification gap | [read →](https://deemwar.com/insights/why-reviewing-ai-code-takes-longer) |

### Prevent & guard

| Tool | What it does | The story |
|------|--------------|-----------|
| [`agent-guard`](agent-guard/) | a PreToolUse hook that blocks destructive agent commands (git reset --hard, rm -rf, push --force) | [read →](https://deemwar.com/insights/stop-your-agent-running-git-reset-hard) |
| [`agent-frisk`](agent-frisk/) | find the invisible Unicode instructions that hijack a coding agent | [read →](https://deemwar.com/insights/your-agent-reads-text-you-cant-see) |
| [`forkcap`](forkcap/) | a fork-budget guard that caps Claude Code's runaway nested subagents | [read →](forkcap/blog-post.md) |

### Secure & audit config

| Tool | What it does | The story |
|------|--------------|-----------|
| [`agent-reach`](agent-reach/) | measure a coding agent's secret blast radius — which secret stores are in reach | [read →](https://deemwar.com/insights/your-agent-can-read-everything-your-shell-can) |
| [`perm-audit`](perm-audit/) | flag over-permissive Claude Code settings.json permissions | [read →](https://deemwar.com/insights/the-loosest-line-in-your-claude-settings) |
| [`trifecta-scan`](trifecta-scan/) | cross-config lethal-trifecta scanner — catch read+untrusted+exfil reachable in one grant set | [read →](https://deemwar.com/insights/no-single-line-is-wrong-the-combination-is) |
| [`mcp-audit`](mcp-audit/) | lint your `.mcp.json` — the highest-trust, never-linted agent config — for egress/security surface | [read →](mcp-audit/blog-post.md) |

### Context & cost

| Tool | What it does | The story |
|------|--------------|-----------|
| [`mcp-budget`](mcp-budget/) | measure the context tax of your MCP servers — tokens spent before your first prompt | [read →](https://deemwar.com/insights/the-hidden-context-tax-of-mcp) |
| [`agent-waste`](agent-waste/) | audit a session transcript for wasted tokens — re-reads, redundant tool results | [read →](https://deemwar.com/insights/the-tokens-your-agent-wastes-in-the-transcript) |
| [`context-carry`](context-carry/) | the cost of a read is its residence time — weight every result by tokens x turns re-sent | [read →](https://deemwar.com/insights/the-cost-of-a-read-is-how-long-it-stays) |
| [`cachecost`](cachecost/) | prompt-caching economics — what caching is actually saving you | [read →](https://deemwar.com/insights/the-prompt-caching-10x-most-teams-miss) |
| [`context-lint`](context-lint/) | audit your CLAUDE.md — it loads every session | [read →](https://deemwar.com/insights/the-most-expensive-file-runs-every-turn) |

### Config quality

| Tool | What it does | The story |
|------|--------------|-----------|
| [`claude-md-gen`](claude-md-gen/) | generate a correct starter CLAUDE.md from your repo | [read →](https://deemwar.com/insights/your-repo-already-knows-how-to-build-itself) |
| [`skill-lint`](skill-lint/) | will your Claude Code skill ever get used? lint its description | [read →](https://deemwar.com/insights/your-skills-description-is-the-whole-ballgame) |
| [`agentdrift`](agentdrift/) | detect drift across a repo's agent-instruction files (CLAUDE.md / AGENTS.md / .cursorrules) | [read →](https://deemwar.com/insights/claude-md-and-agents-md-have-drifted) |
| [`tooldoc`](tooldoc/) | MCP tool-description quality audit — find the undocumented parameters your agent guesses | [read →](https://deemwar.com/insights/your-agent-is-guessing-your-tool-parameters) |

### Supply chain & ecosystem measurement

| Tool | What it does | The story |
|------|--------------|-----------|
| [`slopcheck`](slopcheck/) | audit dependencies for AI-hallucination / slopsquat risk | [read →](https://deemwar.com/insights/your-agent-imports-a-package-nobody-trusts) |
| [`mcpfunnel`](mcpfunnel/) | measure how much of the official MCP registry actually runs | [read →](https://deemwar.com/insights/in-the-registry-is-not-runs) |
| [`agentpr`](agentpr/) | do AI PRs dodge review? run the measurement on your own repo | [read →](https://deemwar.com/insights/the-ai-skips-code-review-panic) |

### Author agent demos

| Tool | What it does | The story |
|------|--------------|-----------|
| [`storyboard-doctor`](storyboard-doctor/) | pre-render linter for auto-demo storyboard JSON — catch dead-air/duration mismatches before you render | [read →](storyboard-doctor/README.md) |

### Lint every channel (output gates)

A human developer is gated everywhere — review reads the code, a teammate notices you're stuck, someone catches the key in the diff. An unattended agent has none of that. These are the cheap, loud, deterministic gates that put it back — one per **channel** the agent touches. Each exits non-zero on a problem, so it drops into a Stop hook or CI unchanged. [`agent-frisk`](agent-frisk/) guards the **input** channel; these four guard the **output** channels.

| Tool | What it does | The story |
|------|--------------|-----------|
| [`langcheck`](langcheck/) | lint agent **output prose** for foreign-script intrusion, mojibake, and runaway repetition | [read →](langcheck/README.md) |
| [`leaklint`](leaklint/) | flag **leaked secrets** in agent output — redact-by-design, never reprints the value | [read →](leaklint/README.md) |
| [`spinlint`](spinlint/) | flag **wasted-loop / stuck** sessions burning tokens with no progress | [read →](spinlint/README.md) |
| [`claimlint`](claimlint/) | flag false **completion claims** ("tests pass", "created X") the transcript and filesystem contradict | [read →](claimlint/README.md) |

---

33 tools. Everything here is heuristic and honestly labelled — estimates, not bills; where a finding is uncertain or our own hypothesis lost, the write-up says so. Built and run by [deemwar](https://deemwar.com). Putting agents to work on code that matters? **[Talk to us](https://deemwar.com/contact).**
