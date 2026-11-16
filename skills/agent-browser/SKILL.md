---
name: agent-browser
description: >-
  Drive a real Chrome browser from the shell with the `agent-browser` CLI, using accessibility-tree snapshots and
  compact `@eN` element refs. Loads the version-matched usage guide from the CLI itself before running any command.
  Use when the user asks to "open a website", "click a button", "fill out a form", "log in to a site", "take a
  screenshot", "test this web app", "dogfood", "QA this page", "automate the browser", or wants to drive an Electron
  app (VS Code, Slack, Notion, ...) through the browser.
license: MIT
metadata:
  author: frytg
  agent: claude
  category: engineering
  inspirations:
    - https://github.com/vercel-labs/agent-browser/blob/main/skills/agent-browser/SKILL.md
---

# agent-browser

`agent-browser` is a native Rust CLI that drives Chrome over CDP. It returns accessibility-tree snapshots with `@eN`
refs, so the agent clicks and types by ref instead of by CSS selector. This file is a stub. The real usage guide ships
inside the CLI, so it always matches the installed version.

## When to use

- Interactive pages: clicks, forms, logins, multi-step flows.
- Screenshots or visual checks of a running web app.
- Exploratory testing, QA, bug hunts on a local or deployed app.
- Electron desktop apps that expose a debugging port.

## Not for

- Read-only extraction of a public page or a web search. Use Firecrawl or Exa, because they skip the browser and
  return clean Markdown.

## Workflow

1. Check `command -v agent-browser`. If it is missing, tell the user it comes from the dotfiles `Brewfile`
   (`brew bundle`) and stop.
2. If a command fails because Chrome is missing, run `agent-browser install` once to fetch Chrome for Testing, then
   retry.
3. Load the core guide before the first command: `agent-browser skills get core`. Follow its loop, waits, and
   troubleshooting. Use `--full` only when you need every reference at once, because it is several times larger.
4. For work outside plain web pages, load the matching specialized guide with `agent-browser skills get <name>`.
   Run `agent-browser skills list` to see the names on the installed version. Common ones:
   - `electron`: Electron desktop apps.
   - `dogfood`: exploratory testing and QA.
   - `derive-client`: record a HAR and derive an API client for a site.
5. Ask before you submit forms, send messages, or make purchases on a real account. Browsing and reading need no
   confirmation.

## Checklist

- Core guide loaded from the CLI, not from memory.
- Outward-facing actions confirmed with the user first.
- Reply with what was done, plus screenshot paths or extracted data.
