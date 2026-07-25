# optimized-footer

Local pi extension that replaces the default footer with a denser, session-aware status bar.

## Goals

- put the high-signal session state on screen without leaving the prompt
- prefer **actionable** numbers over vanity chrome (real costs, cache hit, context pressure)
- stay honest about MCP: show **readiness**, not fake live socket counts
- keep the layout readable at ~80 columns and useful at wider widths
- zero config for day-to-day use; one toggle when you want stock pi back

## Idea

Pi’s built-in footer is useful, but mixes full path noise with weak MCP semantics and bland model/thinking presentation. This extension owns `ctx.ui.setFooter()` and paints two fixed lines:

```
repo · git branch@host · mcp readiness          model · thinking
↑in ↓out Rcache Wcache τreason  $cost …         context% bar
```

Data sources stay local to the session:

- repo = `basename(cwd)`
- branch = pi `footerData.getGitBranch()`
- host = short label from `git remote.origin.url` (github, tangled, …)
- tokens/cost = summed `usage` from session entries (OpenRouter-reported when present)
- context = `ctx.getContextUsage()`
- model/thinking = `ctx.model` + `pi.getThinkingLevel()`
- mcp = config + `mcp-cache.json` + registered tools (not live sockets)

## Layout

### Line 1 — identity / runtime

- **repo** — folder name of the working tree
- **git branch@host** — current branch plus forge (`main@tangled`, `feat@github`)
- **mcp** — readiness summary (see below)
- **model** — short model id (OpenRouter org noise stripped)
- **thinking** — current effort, color-coded; `no-think` if model lacks reasoning

### Line 2 — economy / pressure

- **↑ ↓ R W τ** — session cumulative input, output, cache read/write, reasoning tokens
- **$cost** — cumulative USD; optional `last $…`for the previous turn;`chNN%` last-turn cache hit
- **context** — `used%/window` + bar + optional absolute tokens; colors at 70% / 90%

### Optional line 3

Other extensions’ `setStatus()` text (non-mcp keys), if any.

## MCP semantics

pi-mcp-adapter is lazy by default. Stock “0/2 connected” is often true for sockets while both servers already have cached tools/directTools ready.

This footer reports readiness:

- `mcp off` — nothing configured/cached
- `mcp ready 2/2 · 58t` — N of M servers ready, direct tool count
- `mcp 2 lazy` — configured/cached but not promoted to direct tools yet
- `mcp auth …` — auth warning bubbled from the adapter status line

It does **not** claim live TCP/HTTP connections.

## Setup

Pi auto-discovers `extensions/*/index.ts` under the agent dir.

This repo already points PI at:

```text
PI_CODING_AGENT_DIR=~/.dotfiles/.pi/agent
```

So the extension path is:

```text
.pi/agent/extensions/optimized-footer/index.ts
```

After editing:

1. `/reload` in an open pi session, or start a new `pi`
2. footer should replace the default automatically
3. toggle with `/opt-footer` if you want stock back

No install step, no package.json, no secrets.

## Commands

| Command       | Effect                           |
| ------------- | -------------------------------- |
| `/opt-footer` | Toggle this footer vs pi default |

## Non-goals

- powerline / nerd-font theming frameworks
- live MCP health probes into adapter internals
- OpenRouter account-wide spend dashboards (session totals only; use `/atlas` for deeper views)
- hosting this as a public npm package (local extension on purpose)

## Files

- `index.ts` — extension entrypoint
- `README.md` — this file

## Follow-ups worth considering

- optional third line for session name / compaction threshold
- git dirty/ahead-behind once cheap enough to poll
- host-specific accents (tangled vs github) without turning the bar into a theme kit
