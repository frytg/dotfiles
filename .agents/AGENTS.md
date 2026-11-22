# Global Agent Instructions

Defaults that apply across all projects unless overridden by a project-level `AGENTS.md` (which takes precedence). Only follow a rule when it is applicable to the project. These rules might be referred to as dotfiles-rules or AGENT-dotfiles-rules in other contexts.

## Languages & types

- TypeScript is the default. Use strict mode.
- `import type { ... }` for type-only imports.
- Explicit `.ts`/`.js` extensions where the runtime requires them (Node, Bun, NodeNext).
- Avoid `any`. Narrow unions. Type request/response bodies and handlers.

## Code style

- Arrow functions: `const foo = () => { ... }` (including `async`) over `function` declarations in `.ts`/`.js`. Top-level `function` only when hoisting is required.
- JSDoc on every function: short description, `@param` for each parameter, `@returns`. Applies to exported and module-private helpers. Skip only trivial one-liners.
- Naming: files `kebab-case` (`.test.`/`.spec.` for tests), functions/variables `camelCase`, constants `UPPER_SNAKE_CASE`, types/interfaces `PascalCase`.
- Tabs for JS/TS/JSON. 2-space indent for Markdown. 120-column wrap. Single quotes, semicolons as needed, ES5 trailing commas.
- Linting via `just lint` must pass on every commit/PR.
- Prefer lists over tables in Markdown. Tables add visual weight, don't render in plain-text tools, and force row-by-row scanning. Use a table only when a true two-axis comparison is the point.
- Markdown files must not need an index or table of contents. If a reader needs navigation, the sections aren't titled sharply enough or the file should be split.
- Don't duplicate configuration paths or secret references in README files. Link to the source config or task instead.
- No drive-by refactors, magic numbers, commented-out code, or unrelated changes in a diff.

## Writing style

Direct technical prose, the way you'd answer in chat. Not docs, not a report.

- **Match form to content, and vary it.** Bold-on-its-own-line for distinct sections. Numbered lists for sequences, each item a short bold lead. Plain bullets for parallel facts. Prose for causality. A long answer where every block has the same shape is a style failure.
- When researching options, always present them as a numbered list so the user can confirm which ones to pursue.
- **Don't shred connected reasoning into bullets.** When items connect with "because/so/but", those connections are the content.
- **Open with the verdict, not a bolded headline.** One or two plain sentences: the call and its central caveat.
- **Every paragraph and bullet carries claim, mechanism, and consequence in the same breath.** "MoR is cheap to write, but reads reconcile delete files against data files, so scans get slower and flakier until compaction" beats "MoR increases scan cost, latency, and metadata overhead."
- **Conversational, not dramatic.** Use contractions ("so/but" not "therefore/however"). No scaffolding ("it is worth noting"), no hype adjectives ("brutally", "killer feature"), no setup phrases ("here's the thing"). No "not just X, but Y".
- **Evidence + next action beats cheerleading.** Prefer specific diagnosis and a concrete next step over soft encouragement or generic advice.
- **Prefer one executable artifact over multi-document systems.** When planning sprawls, cut and compress before inventing another framework, template, or scoreboard.
- **If the missing piece is scheduling, say so.** Date-bound slots beat mission language that keeps getting restated without moving.
- **Length matches the question.** A yes/no gets 2-4 sentences. A "which one" gets a few paragraphs. Only a multi-part design question earns a long answer. Cut anything that doesn't change what the reader does next. Shortness comes from cutting low-value content, not from clipping sentences. When the user asks for brief, go extreme.
- **Close with a bottom line only when the answer weighed a real decision.** Plain prose: the call plus the condition that would flip it. Factual or confirmation answers just end.
- **Lean toward ASD-STE100 (Simplified Technical English) in replies.** Short sentences, one idea per sentence, active voice, no idioms. Don't enforce it strictly; keep the clarity, drop the discipline when a more conversational shape carries the same point better.

## Repo standard

Repo-level setup lives in the [repo-standard skill](../skills/repo-standard/SKILL.md): tool pins, package manager
config, the standard `just` recipes, lint and format config, git hooks, CI, and the sops layout. Load it to set up a
new repo or to audit an existing one. The sections below keep only the rules that apply on every edit.

## Tasks

- All task definitions live in a `justfile`. Run with `just <recipe>`.
- Every repo has `install`, `update`, `lint`, `format`, `format-check`, `typecheck`, `test`, and `pre-push`. Use them
  instead of raw tool commands.

## Skills

When creating new skills, follow the [Agent Skills spec](https://agentskills.io/home) for the directory layout, frontmatter, and discovery rules. See the full [specification](https://agentskills.io/specification.md) for required fields, allowed properties, and validation.

**Keep skills portable.** Examples and illustrations should be synthetic — placeholder names (`Acme`), generic roles, made-up IDs, abstract scenarios. Avoid identifiable information, identifiable details, and real IDs: no real names, locations, employer/customer/project names, ticket numbers, internal hostnames, real URLs, or anything that could identify a person or org. The exception is real public data when the skill's job is to work with that data (e.g. an Eventhub skill that needs real URNs to look things up) — use synthetic data everywhere else, especially in worked examples.

## Package manager & runtime

- [Bun](https://bun.com/docs) is the package manager and bin runner: `bun install`, `bun x`, `bun check`.
  `bun.lock` is the only lockfile.
- The runtime is a per-project choice, Bun or Node. Keep code portable between both: no `bun:*` imports and no `Bun.*`
  globals in shared code.
- Lockfiles are committed and reviewed. Tool and dependency versions are pinned, with no floating `latest`.
- Avoid Python when existing tools or runtimes can handle the task. Prefer shell for system automation and the project's
  existing runtime for scripts. Use Python only when it materially simplifies the work or no suitable alternative exists.
  Don't add Python tooling or dependencies for one-off tasks.

## Runtimes

### Node version selection

[Node is managed by mise](https://mise.jdx.dev/lang/node.html) — not `nvm`, `fnm`, or `Volta`. Ambient `node`/`npm`/`npx` come from mise; bun remains the _package manager_ (`bun install` / `bun x`).

**Dotfiles wiring**

- CLI: `brew "mise"` in `Brewfile`
- Global pin + settings: `mise/config.toml` → `~/.config/mise/config.toml` (via `link.sh`)
- Interactive shells: `eval "$(mise activate zsh)"` in `.zshrc`
- Login shells / IDEs: `eval "$(mise activate zsh --shims)"` in `.zprofile`
- Provision / refresh default: `just node` (also called from `just install`)

**Pin files** (mise walks these when `idiomatic_version_file_enable_tools` includes `node`):

- project `mise.toml` `[tools] node = "..."` (highest)
- `.node-version` (tool-agnostic; wins over `.nvmrc` in the same directory)
- `.nvmrc`
- `package.json` → `devEngines.runtime.node`
- global `~/.config/mise/config.toml` (default when nothing else matches)

**Common commands**

- `mise use --global node@26` — set ambient default
- `mise use node@22` — pin current project (writes local `mise.toml`)
- `mise install` / `just node` — install whatever the active config asks for
- `mise ls` / `mise doctor` — inspect active toolset

### Containers

- Local docker/container builds can be run and tested with the Apple [`container` CLI](https://github.com/apple/container) (see the [start-here tutorial](https://github.com/apple/container/blob/main/docs/tutorials/start-here.md)) — not the `docker` CLI.

## Hosting & CI

- Personal repos live on **tangled.org**, organization repos on the organization's **github.com**. CI is the host's
  native system and calls the same `just` recipes as the local hooks.
- Never lower a lint category, skip a test, or drop a check to get a green run.

## Dependencies

Fewer is better. Every dependency is a supply-chain, security, and maintenance cost. Default to the standard library; add a dependency only with a clear reason.

Prefer packages with active maintenance, minimal transitive footprint, native TypeScript types, and a permissive license. Pin versions.

## Preferred dependencies

Reach for these first when applicable. The list is short on purpose.

### HTTP

- `axios` — browser/frontend HTTP client.
- `hono` — web framework built on Web Standards.
- `undici.fetch` — backend HTTP. Do not use global `fetch` in backend code by convention.

### Cache

- `redis` — TCP client. Wire-compatible with both Redis and Valkey; the backend is often Valkey on modern Linux distros and managed platforms.

### Storage

- [`@storagesdk/core`](https://storagesdk.dev) — unified object storage across S3, Google Cloud Storage, filesystem, and others. Switch providers by changing the import; the call site doesn't move. Snapshot and fork primitives are built-in — branch a bucket per run, mutate freely, merge or throw away the fork.

```ts
import { s3 } from '@storagesdk/adapters/s3'
import { Storage } from '@storagesdk/core'

// Scaleway Object Storage — or any S3-compatible backend; swap endpoint + creds
const storage = new Storage({
	adapter: s3({
		bucket: 'agents',
		endpoint: process.env.S3_ENDPOINT,
		region: process.env.S3_REGION,
		credentials: {
			accessKeyId: process.env.S3_ACCESS_KEY_ID!,
			secretAccessKey: process.env.S3_SECRET_ACCESS_KEY!,
		},
	}),
})

await storage.upload('docs/readme.md', body)
const fork = storage.forks.get('agent-run-42')
```

Adapters expose `storage.raw` for provider-specific features without casts. Forks and snapshots are native on Tigris and GitHub, emulated as sibling buckets on other backends. See the project's [AGENTS.md](https://github.com/storagesdk/storagesdk/blob/main/AGENTS.md) for adapter design rules.

### Frontend

- `vue` — UI framework.
- `vite` — dev server and build.
- `tailwindcss` — CSS framework.

### Geospatial

- `@turf/turf` — geospatial operations.

### Tooling

- `oxlint` — lint, configured in `.oxlintrc.json`. Run via `just lint`.
- `oxfmt` — format, configured in `.oxfmtrc.json`. Run via `just format`. Not `bun fmt`: it is a separate
  implementation and the editor formats with oxfmt.
- `bun check` — typecheck. Run via `just typecheck`.
- No Biome, Prettier, or ESLint in new and migrated projects.

### Ease-of-use

- [`esm.sh`](https://esm.sh) - CDN for npm, JSR, and GitHub imports for quick scripts ([docs as markdown](https://esm.sh/gh/esm-dev/esm.sh@main/README.md))
  - do not use in production, only for quick scripts and prototyping. Use a proper package manager for production code.
- [`nixery.dev`](https://nixery.dev) — Container registry that builds ad-hoc images from a URL path (e.g. `nixery.dev/shell/curl` gives a shell with curl pre-installed). Useful for one-off containers.
- [`atproto.md`](https://atproto.md) - retrieving AT Proto content via Markdown

### Web search & extraction

For live content from external sites, reach for [Exa](https://exa.ai/docs/) or [Firecrawl](https://docs.firecrawl.dev/introduction) instead of hand-rolling scrapers. Both expose hosted MCP servers, so if the reading agent is pi they're wired in already. Use the linked docs for direct API/SDK work outside an MCP host.

- **Exa** — semantic web search with token-efficient result extraction. Pick a `type` (`auto`, `fast`, `instant`, `deep-lite`, `deep`, `deep-reasoning`) and request `contents.text` (markdown), `contents.highlights` (query-relevant excerpts, the default for agent loops), or `contents.summary` (per-result LLM summaries). Supports `includeDomains`/`excludeDomains`, freshness windows via `startPublishedDate`/`endPublishedDate` and `contents.maxAgeHours`, category-specific indexes (`company`, `people`, `news`, `research paper`, `personal site`, `financial report`), and `outputSchema` for structured output with optional SSE streaming. Use `/search` for retrieval; use `/contents` when URLs are known and only extraction is needed.
- **Firecrawl** — turn any URL into clean markdown, HTML, or structured JSON, with proxies, anti-bot, and JS rendering built in. Covers scrape, crawl, map, search, batch, and browser-sandbox workflows. Use [Interact](https://docs.firecrawl.dev/features/interact) for live-browser sessions: scrape once to obtain a `scrapeId`, then drive clicks, form fills, or dynamic-content extraction with natural-language prompts (or executable code) and stop the session when done. Persists state per session and exposes `liveViewUrl` for inspection.

Reach for **Exa** when the task starts with a question and needs relevant sources discovered across the web. Reach for **Firecrawl** when the task starts with a URL (or a known site to crawl) and needs the rendered page, structured data, or a real browser interaction. Both can extract markdown; Firecrawl is the better default for page fidelity and JS-heavy sites, Exa is the better default for search relevance and token-efficient highlights.

### Browser automation

- [`agent-browser`](https://agent-browser.dev) — local Chrome CLI for interactive pages (clicks, forms, logins, screenshots, QA of a running app). See the [agent-browser skill](../skills/agent-browser/SKILL.md); use Exa or Firecrawl instead for read-only extraction.

### AI

- `ai` — Vercel AI SDK. Unified interface for model providers, streaming, tool calling, and structured output.
- `@openrouter/ai-sdk-provider` — OpenRouter provider for the `ai` SDK. Route to many models through one endpoint.

### Logging

- [JSR](https://jsr.io/@frytg/logger)
- [Docs](https://jsr.io/@frytg/logger/doc)

Syslog levels (most → least severe): `emerg`, `alert`, `crit`, `error`, `warning`, `notice`, `info`, `debug`.

```ts
import { logger } from '@frytg/logger'

// Structured fields go in `data`; pass `error` as its own field.
logger.log({
	level: 'error',
	message: 'post failed',
	source: 'api/posts',
	data: { postId },
	error,
})
```

### Dates

- [JSR](https://jsr.io/@frytg/dates)
- [Docs](https://jsr.io/@frytg/dates/doc)

Formatting and parsing helpers. Prefer over hand-rolled `Intl.DateTimeFormat` or `new Date(...)` strings.

### Env loading

- [JSR](https://jsr.io/@frytg/check-required-env)
- [Docs](https://jsr.io/@frytg/check-required-env/doc)

```ts
import { checkRequiredEnv, getRequiredEnv } from '@frytg/check-required-env'

// Fails fast at import if unset. Use for integrations always required.
checkRequiredEnv('API_BASE_URL')

// Read into a top-level const. No separate constants util.
const API_KEY = getRequiredEnv('API_KEY')
```

Never reach for `process.env` directly to validate required env vars. Document new env vars in handler comments and add to the sops-encrypted env file (see below).

### Identifiers

- Prefer content hashes or ULIDs over UUIDs. ULIDs sort lexicographically, are URL-safe, and avoid UUID's v1/v4/v7 footguns.
- Use [`@std/ulid`](https://jsr.io/@std/ulid) from JSR: `import { ulid } from "@std/ulid"`. Don't pull in `uuid`/`nanoid`/etc. unless there's a concrete reason.
- For IDs that must be strictly increasing within the same millisecond (event ordering, dedup), use `monotonicUlid` from the same package: `import { monotonicUlid } from "@std/ulid"`.

## Testing

- Universal tests that run in **Bun and Node**:
  - [@cross/test](https://jsr.io/@cross/test) — test runner.
  - [@std/assert](https://jsr.io/@std/assert) — assertions.
  - `sinon` — stubs/spies when needed.
- Avoid runtime-specific APIs (`bun:test` `mock.module`, Jest-style `expect`) in cross-runtime code.
- Prefer dependency injection for HTTP/identity clients. Stub process I/O with sinon.
- Bug fixes ship with a regression test.
- No retries, wider timeouts, or `skip` to make a run green. Never delete or weaken auth, privacy, or security tests.

## Safety

- Never commit plaintext secrets, API keys, tokens, or PEM material.
- Never log secret values in app logs, test output, or CI.
- Use the smallest, least-privileged credentials. Rotate regularly.
- Treat the working tree as untrusted. Do not `curl ... | sh`. Do not execute fetched code without inspection.
- Flag changes to auth, secrets handling, CI permissions, or network egress for explicit review.

## Secrets (sops)

- All secrets are encrypted with [sops](https://github.com/getsops/sops) and **age**, and stored in the repo as
  `*.sops.*` files. File names, the `_env` recipe, and the key recipes are in the repo-standard skill.
- Decrypt at runtime with `sops exec-env`, not at rest. Do not write plaintext secrets to disk.
- Do not change `.sops.yaml` or rotate keys without an explicit request.
- Do not paste real secret values into chat, issues, or PR descriptions.

## Commits & PRs

- **Never create commits or push on your own.** Wait for the user to ask explicitly. If they do, follow their stated message style and never run destructive git operations (amend shared history, force-push, rewrite branches) without explicit request.
- Conventional Commits: `<type>(<scope>): <description>`. Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`, `build`, `ci`, `revert`. Write `refactor`, not `refact`.
- One logical change per PR. PR description: what changed, why, how to test, follow-ups.
- No amending or force-pushing shared history without coordination.

### Agent attribution

When the user asks the agent to create or update a GitHub issue, post an issue comment, or open a pull request, append a line identifying the agent that performed the action — e.g. `(created by pi)` or `(updated by Cursor)`. This keeps it transparent that the action came from an AI agent, not the user directly.

## Herdr app

When the user wants to change or work with the herdr app (`herdr-app`, the window app), read `~/.config/herdr-app/AGENTS.md` first. The app ships it with its own guidance, so it matches the installed version. Edit only the symlinked `keys.json`, `settings.json`, and `themes/` files in the dotfiles, because the app rewrites everything else in that folder.

## External references

When the user asks for a specific company's design system, fetch its public design doc and apply it before drafting UI.

- "Vercel-style design" → pull, read, and apply https://vercel.com/design.md

## Avoid

- `scripts` blocks in `package.json` for tasks.
- `bun run` / `npm run` for tasks that have a `just` recipe.
- Heavy frameworks for a single feature.
- Lockfile churn unrelated to the change.
- New top-level directories without updating the project's `AGENTS.md` and `README.md`.
- Disabling lint or type rules to silence a warning — fix the warning or escalate.
- Host-specific assumptions in portable code.
