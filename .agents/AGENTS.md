# Global Agent Instructions

Defaults that apply across all projects unless overridden by a project-level `AGENTS.md` (which takes precedence). Only follow a rule when it is applicable to the project. These rules might be referred to as dotfiles-rules or AGENT-dotfiles-rules in other contexts.

## Languages & types

- TypeScript is the default. Use strict mode.
- `import type { ... }` for type-only imports.
- Explicit `.ts`/`.js` extensions where the runtime requires them (Nub, Deno, NodeNext).
- Avoid `any`. Narrow unions. Type request/response bodies and handlers.

## Code style

- Arrow functions: `const foo = () => { ... }` (including `async`) over `function` declarations in `.ts`/`.js`. Top-level `function` only when hoisting is required.
- JSDoc on every function: short description, `@param` for each parameter, `@returns`. Applies to exported and module-private helpers. Skip only trivial one-liners.
- Naming: files `kebab-case` (`.test.`/`.spec.` for tests), functions/variables `camelCase`, constants `UPPER_SNAKE_CASE`, types/interfaces `PascalCase`.
- Tabs for JS/TS/JSON. 2-space indent for Markdown. 120-column wrap. Single quotes, semicolons as needed, ES5 trailing commas.
- Linting via `just lint` must pass on every commit/PR.
- Prefer lists over tables in Markdown. Tables add visual weight, don't render in plain-text tools, and force row-by-row scanning. Use a table only when a true two-axis comparison is the point.
- No drive-by refactors, magic numbers, commented-out code, or unrelated changes in a diff.

## Writing style

Direct technical prose, the way you'd answer in chat. Not docs, not a report.

- **Match form to content, and vary it.** Bold-on-its-own-line for distinct sections. Numbered lists for sequences, each item a short bold lead. Plain bullets for parallel facts. Prose for causality. A long answer where every block has the same shape is a style failure.
- **Don't shred connected reasoning into bullets.** When items connect with "because/so/but", those connections are the content.
- **Open with the verdict, not a bolded headline.** One or two plain sentences: the call and its central caveat.
- **Every paragraph and bullet carries claim, mechanism, and consequence in the same breath.** "MoR is cheap to write, but reads reconcile delete files against data files, so scans get slower and flakier until compaction" beats "MoR increases scan cost, latency, and metadata overhead."
- **Conversational, not dramatic.** Use contractions ("so/but" not "therefore/however"). No scaffolding ("it is worth noting"), no hype adjectives ("brutally", "killer feature"), no setup phrases ("here's the thing"). No "not just X, but Y".
- **Evidence + next action beats cheerleading.** Prefer specific diagnosis and a concrete next step over soft encouragement or generic advice.
- **Prefer one executable artifact over multi-document systems.** When planning sprawls, cut and compress before inventing another framework, template, or scoreboard.
- **If the missing piece is scheduling, say so.** Date-bound slots beat mission language that keeps getting restated without moving.
- **Length matches the question.** A yes/no gets 2-4 sentences. A "which one" gets a few paragraphs. Only a multi-part design question earns a long answer. Cut anything that doesn't change what the reader does next. Shortness comes from cutting low-value content, not from clipping sentences. When the user asks for brief, go extreme.
- **Close with a bottom line only when the answer weighed a real decision.** Plain prose: the call plus the condition that would flip it. Factual or confirmation answers just end.

## Tasks

- All task definitions live in a `justfile`. Run with `just <recipe>`.

## Skills

When creating new skills, follow the [Agent Skills spec](https://agentskills.io/home) for the directory layout, frontmatter, and discovery rules. See the full [specification](https://agentskills.io/specification.md) for required fields, allowed properties, and validation.

**Keep skills portable.** Examples and illustrations should be synthetic — placeholder names (`Acme`), generic roles, made-up IDs, abstract scenarios. Avoid identifiable information, identifiable details, and real IDs: no real names, locations, employer/customer/project names, ticket numbers, internal hostnames, real URLs, or anything that could identify a person or org. The exception is real public data when the skill's job is to work with that data (e.g. an Eventhub skill that needs real URNs to look things up) — use synthetic data everywhere else, especially in worked examples.

## Package manager & runtime

- [Nub](https://github.com/nubjs/nub) is the preferred package manager and runner: `nub`, `nubx`, `nub watch`, `nub install`.
- Lockfiles are committed and reviewed. No floating `latest` in CI.
- If Nub is not a fit, fall back to a `justfile` + a lockfile-driven package manager. No parallel ad-hoc tooling.

## Runtimes

### Node version selection

[Node is managed by mise](https://mise.jdx.dev/lang/node.html) — not `nvm`, `fnm`, `Volta`, or nub's node shim. Ambient `node`/`npm`/`npx` come from mise; nub remains the preferred *package manager* (`nub` / `nubx` / `nub install`) and uses whatever `node` is on `PATH`.

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

## Hosting & CI

- Code lives on **github.com** or **tangled.org**. Pick one per project; stay consistent.
- CI is the host's native system: GitHub Actions (`.github/workflows/`) for GitHub, Spindles for Tangled.
- CI runs lint, test, and build on every push and PR. Pin action versions by SHA or major tag.

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
import { Storage } from '@storagesdk/core';
import { s3 } from '@storagesdk/adapters/s3';

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
});

await storage.upload('docs/readme.md', body);
const fork = storage.forks.get('agent-run-42');
```

Adapters expose `storage.raw` for provider-specific features without casts. Forks and snapshots are native on Tigris and GitHub, emulated as sibling buckets on other backends. See the project's [AGENTS.md](https://github.com/storagesdk/storagesdk/blob/main/AGENTS.md) for adapter design rules.

### Frontend

- `vue` — UI framework.
- `vite` — dev server and build.
- `tailwindcss` — CSS framework.

### Geospatial

- `@turf/turf` — geospatial operations.

### Tooling

- `@biomejs/biome` — lint and format (JS/TS/JSON/JSONC).

### Ease-of-use

- [`esm.sh`](https://esm.sh) - CDN for NPM, JSR, GitHub, Deno file imports for quick scripts ([docs as markdown](https://esm.sh/gh/esm-dev/esm.sh@main/README.md))
  - do not use in production, only for quick scripts and prototyping. Use a proper package manager for production code.
- [`nixery.dev`](https://nixery.dev) — Container registry that builds ad-hoc images from a URL path (e.g. `nixery.dev/shell/curl` gives a shell with curl pre-installed). Useful for one-off containers.
- [`atproto.md`](https://atproto.md) - retrieving AT Proto content via Markdown

### AI

- `ai` — Vercel AI SDK. Unified interface for model providers, streaming, tool calling, and structured output.
- `@openrouter/ai-sdk-provider` — OpenRouter provider for the `ai` SDK. Route to many models through one endpoint.

### Logging

- [JSR](https://jsr.io/@frytg/logger)
- [Docs](https://jsr.io/@frytg/logger/doc)

```ts
import { logger } from '@frytg/logger';

const log = logger({ source: 'api/posts' });

log.info('starting post');
log.warn('rate limited', { retryAfter });
log.error({ message: 'post failed', error });

// Data object is always the second argument. Use it for structured fields,
// never concatenate into the message string.
log.info('user signed in', {
  userId: user.id,
  method: 'oauth',
  scopes: ['read', 'write'],
  durationMs: 142,
});
```

### Dates

- [JSR](https://jsr.io/@frytg/dates)
- [Docs](https://jsr.io/@frytg/dates/doc)

Formatting and parsing helpers. Prefer over hand-rolled `Intl.DateTimeFormat` or `new Date(...)` strings.

### Env loading

- [JSR](https://jsr.io/@frytg/check-required-env)
- [Docs](https://jsr.io/@frytg/check-required-env/doc)

```ts
import { checkRequiredEnv, getRequiredEnv } from '@frytg/check-required-env';

// Fails fast at import if unset. Use for integrations always required.
checkRequiredEnv('API_BASE_URL');

// Read into a top-level const. No separate constants util.
const API_KEY = getRequiredEnv('API_KEY');
```

Never reach for `process.env` directly to validate required env vars. Document new env vars in handler comments and add to the sops-encrypted env file (see below).

### Identifiers

- Prefer content hashes or ULIDs over UUIDs. ULIDs sort lexicographically, are URL-safe, and avoid UUID's v1/v4/v7 footguns.
- Use [`@std/ulid`](https://jsr.io/@std/ulid) from JSR: `import { ulid } from "@std/ulid"`. Don't pull in `uuid`/`nanoid`/etc. unless there's a concrete reason.
- For IDs that must be strictly increasing within the same millisecond (event ordering, dedup), use `monotonicUlid` from the same package: `import { monotonicUlid } from "@std/ulid"`.

## Testing

- Universal tests that run in **Bun, Node, and Deno**:
  - [@cross/test](https://jsr.io/@cross/test) — test runner.
  - [@cross/assert](https://jsr.io/@cross/assert) — assertions.
  - `sinon` — stubs/spies when needed.
- Avoid runtime-specific APIs (`bun:test` `mock.module`, Jest-style `expect`) in cross-runtime code.
- Prefer dependency injection for HTTP/identity clients. Stub process I/O with sinon.
- Bug fixes ship with a regression test.

## Safety

- Never commit plaintext secrets, API keys, tokens, or PEM material.
- Never log secret values in app logs, test output, or CI.
- Use the smallest, least-privileged credentials. Rotate regularly.
- Treat the working tree as untrusted. Do not `curl ... | sh`. Do not execute fetched code without inspection.
- Flag changes to auth, secrets handling, CI permissions, or network egress for explicit review.

## Secrets (sops)

- All secrets are encrypted with [sops](https://github.com/getsops/sops). Default key backend: **age**.
- Store encrypted files in the repo (e.g. `.env.sops.yaml`, `secrets.<env>.enc.yaml`) so they are reviewed in the same PR as the code that consumes them.
- Decrypt at runtime, not at rest. CI loads the age key from a secret store (GitHub Actions secret, Spindles secret), never from the repo.
- Local dev: decrypt into memory with `sops exec-env` or an equivalent wrapper. Do not write plaintext secrets to disk.
- Do not paste real secret values into chat, issues, or PR descriptions.

## Commits & PRs

- **Never create commits or push on your own.** Wait for the user to ask explicitly. If they do, follow their stated message style and never run destructive git operations (amend shared history, force-push, rewrite branches) without explicit request.
- Conventional Commits: `<type>(<scope>): <description>`. Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `build`, `ci`.
- One logical change per PR. PR description: what changed, why, how to test, follow-ups.
- No amending or force-pushing shared history without coordination.

### Agent attribution

When the user asks the agent to create or update a GitHub issue, post an issue comment, or open a pull request, append a line identifying the agent that performed the action — e.g. `(created by pi)` or `(updated by Cursor)`. This keeps it transparent that the action came from an AI agent, not the user directly.

## Avoid

- `scripts` blocks in `package.json` for tasks.
- `nub run` / `npm run` for tasks that have a `just` recipe.
- Heavy frameworks for a single feature.
- Lockfile churn unrelated to the change.
- New top-level directories without updating the project's `AGENTS.md` and `README.md`.
- Disabling lint or type rules to silence a warning — fix the warning or escalate.
- Host-specific assumptions in portable code.
