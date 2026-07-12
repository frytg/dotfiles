# Global Agent Instructions

Defaults that apply across all projects unless overridden by a project-level `AGENTS.md` (which takes precedence). Only follow a rule when it is applicable to the project.

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

## Tasks

- All task definitions live in a `justfile`. Run with `just <recipe>`.
- Do not add `scripts` to `package.json` for tasks.
- Do not invoke `nub run` / `npm run` / `bun run` for tasks that have a `just` recipe.

## Package manager & runtime

- [Nub](https://github.com/nubjs/nub) is the preferred package manager and runner: `nub`, `nubx`, `nub watch`, `nub install`.
- Lockfiles are committed and reviewed. No floating `latest` in CI.
- If Nub is not a fit, fall back to a `justfile` + a lockfile-driven package manager. No parallel ad-hoc tooling.

## Runtimes

### Node version selection

[Node is managed by nub](https://nubjs.com/docs/node) — not `nvm`, `fnm`, `mise`, or `Volta`. Do not install or wire up any of those in `.zshrc`, the `justfile`, or `Brewfile`. Nub provisions the right Node itself when you run a file with `nub` / `nubx` / `nub watch`.

**Pin files** (highest precedence first, walked up from CWD; `node_modules/` is skipped so a dependency's own pin never drives your project):

- `package.json` → `devEngines.runtime.node` (exact or range; non-Node runtime refuses by default)
- `.node-version` (tool-agnostic standard; wins over `.nvmrc` in the same directory)
- `.nvmrc`
- `package.json` → `engines.node` (resolved as a range, not an exact pin; uses the newest available matching version)

**Binary resolution** (once a version is pinned): `node` already on `PATH` whose version satisfies the pin → nub's own cache at `~/.cache/nub/node/<version>/` → nvm scan (read-only, never invokes nvm) → download the matching stock build from nodejs.org (SHA-256 verified, then cached).

**With no pin anywhere up the tree**, nub uses whatever `node` is already on `PATH`. For ambient shell commands outside `nub`, keep `node` on `PATH` (e.g. via `brew install node` or a one-time `nub node install <version>` to warm the cache).

**Hard override**: `NODE_EXECUTABLE=/abs/path/to/node` bypasses pin-file reading, the cache, and nvm — useful in CI or when debugging a specific build.

**Pre-warming a cache** (CI setup step, working offline): `nub node install` reads the project's pin and provisions it; aliases like `lts`, `latest`, `lts/*`, a bare major (`26`), or `major.minor` (`22.13`) all work.

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

### Frontend

- `vue` — UI framework.
- `vite` — dev server and build.
- `tailwindcss` — CSS framework.

### Geospatial

- `@turf/turf` — geospatial operations.

### Tooling

- `@biomejs/biome` — lint and format (JS/TS/JSON/JSONC).

### AI

- `ai` — Vercel AI SDK. Unified interface for model providers, streaming, tool calling, and structured output.
- `@openrouter/ai-sdk-provider` — OpenRouter provider for the `ai` SDK. Route to many models through one endpoint.

### Logging — `@frytg/logger`

- JSR: <https://jsr.io/@frytg/logger>
- Docs: <https://jsr.io/@frytg/logger/doc>

```ts
import { logger } from "@frytg/logger";

const log = logger({ source: "api/posts" });

log.info("starting post");
log.warn("rate limited", { retryAfter });
log.error("post failed", { err });

// Data object is always the second argument. Use it for structured fields,
// never concatenate into the message string.
log.info("user signed in", {
  userId: user.id,
  method: "oauth",
  scopes: ["read", "write"],
  durationMs: 142,
});
```

### Dates — `@frytg/dates`

- JSR: <https://jsr.io/@frytg/dates>
- Docs: <https://jsr.io/@frytg/dates/doc>

Formatting and parsing helpers. Prefer over hand-rolled `Intl.DateTimeFormat` or `new Date(...)` strings.

### Env loading — `@frytg/check-required-env`

- JSR: <https://jsr.io/@frytg/check-required-env>
- Docs: <https://jsr.io/@frytg/check-required-env/doc>

```ts
import { checkRequiredEnv, getRequiredEnv } from "@frytg/check-required-env";

// Fails fast at import if unset. Use for integrations always required.
checkRequiredEnv("API_BASE_URL");

// Read into a top-level const. No separate constants util.
const API_KEY = getRequiredEnv("API_KEY");
```

The SDK throws and the process exits when a required var is missing — never reach for `process.env` directly to validate required env vars.

Document new env vars in handler comments and add to the sops-encrypted env file (see below). Never log secret values.

## Testing

- Universal tests that run in **Bun, Node, and Deno**:
  - `https://jsr.io/@cross/test` — test runner.
  - `https://jsr.io/@cross/assert` — assertions.
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
- If a real secret is ever pasted into chat, issues, or PR descriptions, treat it as compromised and rotate.

## Secrets (sops)

- All secrets are encrypted with [sops](https://github.com/getsops/sops). Default key backend: **age**.
- Store encrypted files in the repo (e.g. `.env.sops.yaml`, `secrets.<env>.enc.yaml`) so they are reviewed in the same PR as the code that consumes them.
- Decrypt at runtime, not at rest. CI loads the age key from a secret store (GitHub Actions secret, Spindles secret), never from the repo.
- Local dev: decrypt into memory with `sops exec-env` or an equivalent wrapper. Do not write plaintext secrets to disk.
- Do not paste real secret values into chat, issues, or PR descriptions.

## Commits & PRs

- Conventional Commits: `<type>(<scope>): <description>`. Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `build`, `ci`.
- One logical change per PR. PR description: what changed, why, how to test, follow-ups.
- No amending or force-pushing shared history without coordination.

## Avoid

- `scripts` blocks in `package.json` for tasks.
- `nub run` / `npm run` for tasks that have a `just` recipe.
- Heavy frameworks for a single feature.
- Lockfile churn unrelated to the change.
- New top-level directories without updating the project's `AGENTS.md` and `README.md`.
- Disabling lint or type rules to silence a warning — fix the warning or escalate.
- Host-specific assumptions in portable code.
