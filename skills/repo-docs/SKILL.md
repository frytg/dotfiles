---
name: repo-docs
description: >-
  Write and update technical repository documentation (`README.md`, co-located module or service `README.md`s,
  `TESTING.md`, and `docs/` guides, reference pages, migration notes, and runbooks) with concrete behavioral detail and
  single-source-of-truth links to code and tasks. Enforces a public/private visibility and identifier-disclosure note in
  root `README.md` and defaults to English unless specified otherwise. Use when the user asks to "write docs", "update
  the docs", "document this", "update the README", "add a migration guide", "write a runbook", or when user-facing,
  configuration, or operational behavior changes. Not for pre-implementation design proposals (use rfc) or CHANGELOG
  bumps (use changelog).
license: MIT
metadata:
  author: frytg
  agent: factory
  category: writing
---

# Repository Documentation

Repository documentation is a contract for users, maintainers, and agents, not a tour of the codebase. Every file owns
one scope, states exact behavior and failure consequences, links to canonical code or task commands instead of copying
them, and defaults to English unless the repository's `AGENTS.md` or the user specifies another language.

## When to use

- Creating or updating root `README.md`, co-located package/module `README.md`s, or `TESTING.md`.
- Writing or revising `docs/` pages: usage guides, API or CLI references, configuration docs, migration guides, and
  operational procedures.
- Updating docs alongside code, configuration, CLI flag, schema, or task-runner changes.

## Not for

- Pre-implementation architectural proposals or decision records — use `rfc`.
- Version bumps and `CHANGELOG.md` entries — use `changelog`.
- Pure CommonMark/GFM formatting fixes without content changes — use `markdown`.

## Document topology

Match the documentation footprint to the size of the repository, co-locate module details with the code they govern, and
split broader docs by reader goal:

- **Root `README.md`** — Entry point only: one-sentence purpose, **repository visibility & disclosure note** (public vs
  private, plus what identifiers may appear or must be excluded), minimal usage or quickstart, high-level directory or
  package map with links, local setup and task commands (`mise install`, install, test, build), and license/changelog
  links. Keep deep internals and operational procedures out of root `README.md`.

  Every root `README.md` must state explicitly whether the repository is **public** or **private** and define its
  identifier boundary (real hostnames, domains, IPs, account/project IDs vs synthetic placeholders). Plaintext secrets,
  tokens, and private keys are always excluded:

  ```markdown
  <!-- Public repository -->
  **Visibility:** Public repository. Use synthetic placeholders (`acme`, `example.com`, `<host>`) in docs and examples.
  Exclude internal hostnames, private URLs, IP addresses, account IDs, and credentials.

  <!-- Private repository -->
  **Visibility:** Private repository. Real hostnames (`node-01`), service URLs, and namespaces belong in docs so
  `Verify` commands stay runnable; use `<tailnet>` where parameterized and exclude plaintext secrets, tokens, and PII.
  ```

- **Co-located `README.md` (`src/<module>/README.md`, `packages/<pkg>/README.md`, `services/<svc>/README.md`)** — Placed
  inside the folder a contributor edits. Covers how that unit works, its inputs/config, local commands, and invariants
  specific to that directory. Link top-level `README.md`s from `AGENTS.md`, or state the folder convention
  (`packages/*/README.md`, `<host>/services/*/README.md`) when many units share one layout.
- **`TESTING.md`** (when test setup is non-trivial) — Test runner, required fixtures or environment variables, local vs
  CI execution, external service prerequisites, and links to integration or end-to-end suites.
- **`docs/` tree** (only when the repo outgrows READMEs):
  - `docs/index.md` — One-sentence summary plus a short routing paragraph pointing to usage, reference, operations, and
    migration pages.
  - Usage & integration guides — End-to-end setup, authentication, configuration, runnable examples, and migrations.
  - Reference pages — Per-command, per-endpoint, or per-schema contracts, including generated spec workflows.
  - Operations & contributor guides — Secrets handling, deployment/release steps, environment matrices, and runbooks.

## Level of detail

1. **Write concrete values, never vague qualifiers.** State exact defaults, units, limits, status codes, paths, and file
   modes (`timeout defaults to 30s`, `body capped at 64 KiB`, `returns HTTP 409 on duplicate key`, `writes mode 600 to
   ~/.config/acme/credentials`) instead of "reasonable timeout", "large payloads", or "proper permissions".
2. **Pair every rule with its mechanism and consequence.** When stating a constraint, explain in the same sentence what
   breaks mechanically if the reader ignores it:
   - "Pass an `AbortSignal` to `watch()`: without one, the polling loop stays open for the lifetime of the process."
   - "Edit `config.toml` rather than the UI settings panel, which is overwritten from disk on startup."
   - "The server reads TLS certificates only on boot, so restart the process after rotating files."
3. **State negative constraints and non-behaviors explicitly.** Call out plausible wrong assumptions directly:
   - Fields that are ignored or overwritten: "`createdAt` is stamped by the server on receipt; any client value is
     discarded."
   - Commands or channels that do less than their name implies: "`--dry-run` validates config syntax locally and does
     not test remote credentials."
   - Module boundaries: "Keep `DATABASE_URL` out of the shared client package; only `src/server/env.ts` reads it."
4. **Document options, flags, and environment variables with exact parsing and fallback rules.** Mark each setting
   `REQUIRED` or `OPTIONAL`, give its default and type/unit, note strict parsing (`exact string 'true'` vs truthy), name
   where secrets come from, and state what happens when unset:

   ```markdown
   - REQUIRED `API_BASE_URL` — upstream origin (`https://api.example.com`), no trailing slash.
   - OPTIONAL `CACHE_URL` — Redis/Valkey connection string. Unset disables caching so every read hits upstream.
   - OPTIONAL `ENABLE_WEBHOOKS` — exact string `true` turns on outbound delivery. Unset or any other value (`1`, `TRUE`,
     `false`) leaves delivery off. Requires a restart after changing.
   ```

5. **Show exact transformations across boundaries.** Whenever identifiers, paths, or arguments are rewritten between
   layers (CLI flags to env vars, URL encoding, slug rules, glob or wildcard syntax), show the mapping and a concrete
   resolved example, plus the common mistake that silently fails:

   ```text
   <namespace> / <resource> / <stage>
      acme     /   orders   /   dev   => acme.orders.dev
   ```

6. **Annotate sharp edges inline in runnable examples.** Keep code and CLI snippets minimal, complete, and runnable with
   synthetic placeholders (`acme`, `example.com`) and env vars for credentials. Add short inline comments only on lines
   callers commonly get wrong. When documenting failure modes, include a realistic error output or payload and map each
   error code/message to its fix.

## References and single source of truth

1. **Route early instead of repeating context.** Open each page with 1–3 sentences defining what _this_ file covers,
   followed immediately by a short paragraph linking adjacent concerns (setup, auth, config, testing, migration) to
   their canonical files. Each topic has one home.
2. **Link to code, schemas, and configs instead of copying mutable details.** Use relative links to the authoritative
   source file (``[`src/config.ts`](src/config.ts)``, ``[`.github/workflows/ci.yml`](.github/workflows/ci.yml)``). When a
   file is generated or symlinked (API specs, type bundles, linked dotfiles), name both the source file and the command
   that regenerates or syncs the target.
3. **Lead with the repo's task runner.** Show the project's canonical task commands (`just test`, `just build`, or the
   repo's configured script runner) rather than long raw tool invocations. Show raw commands only when demonstrating
   ad-hoc flags, debugging, or manual inspection.
4. **Reference secrets by mechanism, never by value.** Name the environment variable, secret store, or encrypted file
   and the wrapper that injects it (`sops exec-env`, `op read`, `just env`). If a workflow writes decrypted material
   locally, state the gitignored path and `600` file mode explicitly.
5. **Link rationale to decision records.** Keep usage and operational pages focused on _how_ the system behaves today;
   link architectural trade-offs and historical context to the relevant RFC, ADR, issue, or PR anchor.

## Recurring page shapes

- **Migration guides** — State the target version up front, open with a scannable summary of breaking changes grouped by
  version, then give each change its own section: version introduced, old vs new behavior, before/after snippet or
  mapping table if needed, and a bold **`Action:`** line stating exactly what callers must change.
- **Operational procedures & runbooks** — List prerequisites and blast radius before step 1, give copy-paste commands in
  order, include a non-destructive check (`--dry-run`, `diff`, `check`, `status`) before or after applying changes, and
  note whether changes hot-reload or require a restart.
- **Deprecations** — Keep legacy docs accurate until removal, mark the deprecation at the top of the file, and link
  directly to the replacement path.

## Workflow

1. **Check language and repo conventions.** Default to English across prose, headings, and comments. Inspect `AGENTS.md`
   and existing docs first; use another language only when the repo or user explicitly asks for it. Ignore site-builder
   specifics unless preserving existing frontmatter (`title`, `description`) in a `docs/` tree that already uses it.
2. **Verify every fact against the codebase.** Read option parsers, env loaders, schemas, `justfile`/`package.json`, and
   tests before writing. If existing docs contradict the code, trust the code and update the doc (or flag the mismatch
   if the code looks broken). Never guess flags, defaults, or paths; ask the user or use `<placeholder>` / `.invalid`
   for unknown external values.
3. **Update the canonical file instead of creating sprawl.** Edit the existing `README.md` or `docs/` page that owns the
   subject. Create a new file only for a genuinely new module, guide, migration, or runbook, and link it from
   `AGENTS.md`, root `README.md`, or the parent index.
4. **Write direct, zero-filler prose.** Start immediately with what the component, command, or contract does — no "This
   document describes..." preamble and no table of contents. Use active voice, present tense, short sentences, `-`
   bullets by default, numbered lists for ordered steps, and tables only for true two-axis comparisons.
5. **Verify links, commands, and formatting.** Confirm every relative file path resolves on disk and every task command
   exists in the repo's task file. Run `just format` / `just lint` (or the repo's formatter/linter) before finishing.

## Checklist

- Written in English (unless `AGENTS.md` or the user explicitly specified otherwise), with no SSG-specific boilerplate.
- Placed in the right layer (thin root `README.md`, co-located module `README.md`, `TESTING.md`, or single-topic `docs/`
  page) with no table of contents.
- Opens with what the subject does, followed by routing links to adjacent docs instead of duplicated explanations.
- States concrete defaults/limits, mechanism + failure consequence for constraints, negative non-behaviors, and strict
  `REQUIRED`/`OPTIONAL` config semantics.
- Links to source files, task recipes, and secret wrappers as the single source of truth; contains zero real secrets or
  org-specific hostnames.
- Every relative path and task command was verified against the codebase, and formatting/lint checks pass.
