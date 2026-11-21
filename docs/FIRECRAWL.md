# Firecrawl Local

[firecrawl-local](https://docs.firecrawl.dev/quickstarts/firecrawl-local) is a single Rust binary that scrapes, crawls, and maps sites on this machine, and serves the Firecrawl v2 HTTP API. Recipes live in [`just/firecrawl.just`](../just/firecrawl.just).

## Install

Run `just firecrawl-install` (aliases: `install-firecrawl`, `firecrawl-update`). It runs `cargo install` from crates.io into `../_cli/firecrawl-local` next to the dotfiles repo (override with `FIRECRAWL_LOCAL_ROOT`), so the binary lands in `bin/` there. The recipe then links it into `~/.local/bin`, which is on `PATH`, so `firecrawl-local` works from any directory. A rerun installs a newer release if one exists.

- **No source checkout.** The crate builds the same binary as `apps/local` in the Firecrawl monorepo, so cloning the whole repo isn't worth it.
- **Chrome renders JavaScript pages.** With `--browser auto` (the default), it uses the installed Google Chrome when a page needs it. Static pages work without Chrome. Set `FIRECRAWL_CHROME_PATH` if Chrome lives somewhere unusual.

## Use

- `just firecrawl-scrape <url>` prints one page as markdown.
- `just firecrawl-crawl <url> [limit] [out]` writes up to 50 pages into `./pages` by default.
- `just firecrawl-map <url>` lists a site's URLs from its sitemaps and start page.
- `just firecrawl-serve [port]` serves the API on `127.0.0.1:3002`. Point clients at `http://localhost:3002` as the Firecrawl API URL. A non-loopback `--host` requires `--token`.
- `just firecrawl <args>` passes anything else straight to the CLI.

## Cloud hand-off

`FIRECRAWL_CLOUD` defaults to `auto`, so the binary can hand some requests to Firecrawl Cloud when you're logged in or have `FIRECRAWL_API_KEY` set. `search`, `find-tools`, and `data` always run in the cloud. Set `FIRECRAWL_CLOUD=off` to keep everything local.

## Agents and MCP

Agents use the CLI through the [`firecrawl-local` skill](../skills/firecrawl-local/SKILL.md). The skill forbids them from starting `firecrawl-local mcp` or running `init`, `login`, or the cloud commands.

Don't run `firecrawl-local init` yourself either, because it writes MCP entries into every AI coding tool it finds. MCP config in this repo goes through [`docs/MCP.md`](./MCP.md), and agents already use the hosted Firecrawl MCP.
