---
name: firecrawl-local
description: >-
  Scrape, crawl, and map websites on this machine with the `firecrawl-local` CLI, returning clean markdown without a
  hosted API call. Covers one-page scrapes, multi-URL scrapes, site crawls into a folder, and URL discovery from
  sitemaps. Use when the user asks to "scrape this page locally", "get this URL as markdown", "crawl these docs",
  "download the docs site", "map this site", "list all URLs on X", mentions "firecrawl-local" or "local firecrawl", or
  wants page content without using the hosted Firecrawl or Exa services.
license: MIT
metadata:
  author: frytg
  agent: claude
  category: engineering
  inspirations:
    - https://docs.firecrawl.dev/quickstarts/firecrawl-local
---

# firecrawl-local

`firecrawl-local` is a single binary that fetches pages on this machine and prints them as markdown. It renders
JavaScript pages with the local Chrome when one is installed. The output is the page's main content, ready to read
or save, with navigation and footers stripped unless asked for.

## When to use

- Read a known URL as markdown.
- Scrape a short list of URLs in one call.
- Crawl a docs site or section into one markdown file per page.
- List a site's URLs before deciding what to scrape.

## Not for

- Web search. `firecrawl-local search` runs in Firecrawl Cloud. Use Exa or the hosted Firecrawl tools instead.
- Clicks, forms, and logins. Use the `agent-browser` skill.

## Rules

- **Never start the MCP server.** Do not run `firecrawl-local mcp` and do not add it to any MCP config. The user wires
  MCP servers by hand.
- **Never run `init`.** It writes MCP entries into every AI coding tool on the machine.
- **Never run `login`, `search`, `find-tools`, or `data`.** They sign in to or call Firecrawl Cloud.
- **Don't start `serve`** unless the user asks for the HTTP API. The CLI commands below cover agent use.
- **Write crawls outside the repo** (a scratch or temp directory) unless the user names a target folder.

## Workflow

1. Check the binary: `command -v firecrawl-local`. If it's missing, tell the user to install it
   (`cargo install firecrawl-local`) and stop. Don't install it yourself.
2. Pick the command:
   - One or more pages → `scrape`.
   - Unknown page set on one site → `map` first, then `scrape` the URLs that matter.
   - A whole section to keep → `crawl --out <dir>`.
3. Run it. If a page comes back empty or truncated, retry once with `--browser always`. If it still fails, report the
   URL and the error and stop.

## Commands

```sh
# one page, markdown only
firecrawl-local scrape https://example.com --markdown

# several pages at once, keep headers and footers
firecrawl-local scrape https://example.com/a https://example.com/b --markdown --full-page

# JSON envelope with markdown and links (metadata included)
firecrawl-local scrape https://example.com -f markdown,links

# list URLs, filtered by a substring
firecrawl-local map https://example.com --search docs --limit 200

# crawl a section, one markdown file per page
firecrawl-local crawl https://example.com/docs --limit 50 --max-depth 3 --out ./pages

# crawl with path filters (regex, repeatable)
firecrawl-local crawl https://example.com --include '^/docs/' --exclude '/changelog' --out ./pages
```

Useful flags:

- `--browser auto|never|always` controls Chrome rendering. `never` is faster for static pages.
- `--timeout <ms>` sets the per-page timeout on `scrape` (default 30000).
- `--public-only` refuses localhost and private-network targets. Use it when the URL comes from untrusted input.
- `crawl --limit` defaults to 100 pages. Set it lower unless the user wants the whole site.

## Checklist

- Binary present, no install attempted by the agent.
- No `mcp`, `init`, `login`, or cloud commands run.
- Crawl output written to a scratch dir or the folder the user named.
