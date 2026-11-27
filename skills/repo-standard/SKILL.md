---
name: repo-standard
description: >-
  Set up a new repository or audit an existing one against the house repo standard: bun as package manager with a text
  lockfile, a mirror registry, and a 3-day release cooldown; exact tool pins in mise; a `justfile` with the standard
  `install`, `update`, `lint`, `format`, `format-check`, `typecheck`, `test`, `hooks-install`, and `pre-push` recipes;
  oxlint, oxfmt, and `bun check`; hk pre-commit and pre-push hooks; one CI workflow on the repo's host that calls
  the same recipes; sops secrets; and the required root files. Scaffold mode writes the files. Audit mode is read-only
  and returns a severity-ranked findings list. Use when the user asks to "set up a new repo", "scaffold a project",
  "bootstrap this repo", "apply the repo standard", "audit this repo", "check this repo against my standards", "is
  this repo up to standard?", or "add hooks / lint / CI the usual way". Not for recipe syntax (use just-commands),
  Tangled workflow fields (use tangled-ci), or README content (use repo-docs).
license: MIT
metadata:
  author: frytg
  agent: claude
  category: engineering
---

# Repo standard

A repo that meets the standard gives the same answer in three places: a local shell, a git hook, and CI all run the
same `just` recipes against the same pinned tools. Scaffold mode produces that repo. Audit mode produces one findings
list that says where a repo differs and what to change first.

The [baseline](#baseline) is both the scaffold spec and the audit checklist. It covers single-package repos.
Monorepo-only CI (affected-package selection, per-package jobs, sparse checkout) is out of scope.

## When to use

- Starting a new repository, or adding the standard tooling to a repo that has none.
- Checking an existing repo against the standard before or after a change.
- Adding one baseline part "the usual way": hooks, lint and format checks, CI, tool pins, or secrets layout.
- Migrating a repo from another package manager, formatter, or hook tool.

## Not for

- Recipe syntax, groups, imports, and justfile layout. Use `just-commands`.
- Fields, engines, and secrets of a Tangled workflow. Use `tangled-ci`.
- Moving a repo to Tangled or the first GitHub mirror setup. Use `migrate-to-tangled`.
- What goes into `README.md` and `docs/`. Use `repo-docs`. For `CHANGELOG.md` use `changelog`, for design docs `rfc`.
- Outdated dependency reports. Use `deps-check`, or `deps-auto` to apply the safe updates.

## Pick the mode

- The user asks to check, audit, validate, or compare: run [Audit](#audit). Do not edit files.
- The user asks to set up, scaffold, bootstrap, add, or fix: run [Scaffold](#scaffold).
- If the request is unclear, run the audit first and offer the fixes.

## Baseline

Each item carries a severity for the audit. `must` contradicts the standard. `should` is drift. `info` is context.
Items marked _JS/TS_ apply only when the repo has a `package.json`. In other languages, keep the recipe names and swap
in that language's tools (for example `go vet` behind `just lint`).

Each section links its file template in [references/templates.md](references/templates.md). Version numbers there are
placeholders. Pin the current release of each tool.

### Hosting

- `must` CI lives on the host of the `origin` remote: `.tangled/workflows/` for tangled.org, `.github/workflows/` for
  github.com. A repo that mirrors to GitHub keeps its CI on Tangled.
- `info` New personal repos go to Tangled. Organization repos go to the organization's GitHub. Do not flag an existing
  repo for its host. Moving it is a separate decision.
- `info` A public personal repo on Tangled mirrors to GitHub with a `github-mirror.yml` workflow.
- `must` The default branch is `main`.
- `info` On GitHub, `main` requires the CI checks and blocks force pushes. Report it only when the API lets you read
  the ruleset.

### Tool pins (mise)

- `must` A root `mise.toml` pins every tool the recipes call, with exact versions. No `latest`, no bare majors for
  tools CI installs.
- `must` `mise.lock` is committed.
- `should` `[settings]` sets `lockfile = true` and `minimum_release_age = "3d"`.
- `should` `mise.lock` has entries for every platform that installs the tools, the CI runner included. `mise install`
  writes them when `lockfile = true`. Add a missing one with `mise lock --platform <os-arch>`.
- `info` The cooldown filters version resolution only. An exact pin or a lockfile entry installs as written, so the
  cooldown acts during `just update`, not during `just install`.
- `should` The file holds `[tools]` and `[settings]` only. No `[env]`, `[hooks]`, or `[tasks]`, so it loads without
  `mise trust`. Tasks stay in `just`, secrets stay in sops.

Template: [mise.toml](references/templates.md#misetoml).

### Package manager (bun) _JS/TS_

- `must` `bun.lock` (text format) is the only lockfile. `aube-lock.yaml`, `package-lock.json`, `pnpm-lock.yaml`,
  `yarn.lock`, `deno.lock`, and binary `bun.lockb` are findings.
- `must` CI and container builds install with `bun install --frozen-lockfile`.
- `should` `bunfig.toml` sets the mirror registry (`https://registry.vlt.io/upstream/npm/`),
  `minimumReleaseAge = 259200` (3 days, in seconds), and the JSR scope. Template:
  [bunfig.toml](references/templates.md#bunfigtoml). The template also sets `saveTextLockfile = true` and
  `telemetry = false`. Do not flag a repo that omits them: the text lockfile is the default since Bun 1.2, and
  telemetry covers crash reports only.
- `info` The mirror is a shared, free service with usage limits and no documented malware filter. The cooldown is the
  supply-chain control. A repo whose installs hit the limit moves to an account mirror and keeps the cooldown.
- `should` `package.json` has `"type": "module"`, no `scripts` block, and `"private": true` unless the package is
  published. Private repos set `"license": "UNLICENSED"`.
- `should` Dependencies use the cooldown everywhere it exists: mise, bun, and the update bot.

### Runtime and code _JS/TS_

- `info` The runtime is a per-project choice: Bun or Node. Record it in `AGENTS.md`.
- `should` Code stays portable between both. Findings: imports from `bun:*`, the `Bun.*` and `Deno.*` globals, and any
  `deno.json`, `deno.jsonc`, or Deno recipe. `node:*` built-ins are fine because both runtimes ship them.
- `should` Projects that run TypeScript directly set `strict`, `module: "nodenext"`, `noEmit`,
  `allowImportingTsExtensions`, `erasableSyntaxOnly`, and `verbatimModuleSyntax` in `tsconfig.json`. Framework repos
  extend the framework's strict preset.

### Tasks (just)

- `must` A root `justfile` exists and bare `just` prints the menu. Layout and style follow `just-commands`.
- `must` These recipe names exist with these meanings. Hooks and CI call them, so the names are fixed.
  - `install` installs pinned tools and dependencies.
  - `update` bumps tool pins and dependencies, then formats.
  - `lint` runs the linter, check-only.
  - `format` writes formatting fixes. `format-check` fails when a file needs formatting.
  - `typecheck` type-checks every `tsconfig.json`.
  - `test` runs the tests in random order.
  - `hooks-install` installs the git hooks.
  - `pre-push` runs what CI runs for a pull request.
  - `lint-files`, `format-files`, `format-check-files` take a file list. The pre-commit hook calls them.
- `should` `just update` is the only place that rewrites pins and lockfiles. Do not edit a lockfile by hand.

Template: [justfile](references/templates.md#justfile). A project that runs on Node in production adds `test-node`
(`node --test`) and calls it from `pre-push` and CI next to `test`. The fast runner does not replace the production
runtime's runner.

### Lint, format, typecheck _JS/TS_

- `must` oxlint is the linter, configured in `.oxlintrc.json`. Biome, ESLint, and Prettier configs are findings.
- `should` The `correctness` and `suspicious` categories are set to `error`. Turn on `perf` and `pedantic` only after
  reading the violations, then fix them.
- `must` Lint rules and required checks only stay or grow. Do not lower a category, disable a rule, or drop a check to
  get a green run.
- `must` oxfmt is the formatter, configured in `.oxfmtrc.json`. The editor's oxfmt language server reads the same
  file, so the editor, the hook, and CI give the same output.
- `should` `bun fmt` in a recipe, hook, or workflow is a finding. It is a separate implementation that reads the oxfmt
  config and differs in places, for example it keeps double quotes in CSS.
- `should` `oxlint` and `oxfmt` are exact-version dev dependencies, and recipes call them with `bun x --no-install`.
  Then a missing dependency fails the recipe and nothing is downloaded unpinned.
- `should` `.oxfmtrc.json` sets tabs, `printWidth: 120`, `singleQuote: true`, `semi: false`, `trailingComma: "es5"`,
  sorted imports, and ignores `**/*.sops.*`.
- `should` `bun check` is the typecheck for every `tsconfig.json`, frontend configs included.
- `should` `.editorconfig` at the root: tabs, `max_line_length = 120`, LF, final newline; 2 spaces for Markdown, YAML,
  and TOML.

### Tests _JS/TS_

- `should` Tests import the runner from `@cross/test` and assertions from `@std/assert`, with `sinon` for stubs. They
  pass on Bun and on Node.
- `should` Tests run in random order. Fix an ordering leak (shared stubs, process-wide mocks). Do not pin a seed.
- `must` No retries, wider timeouts, or `skip` to make a run green. A test that needs a retry has a bug.
- `must` Tests for authorization, privacy, and security are never deleted or weakened to make a change easier.
- `should` Tests assert observable behavior, not mock call counts or copied config constants. Use `test-cleanup` to
  prune the rest.

### Git hooks (hk)

- `must` `hk.pkl` exists at the root, and `hk` and `pkl` are pinned in `mise.toml`. The version in the `amends` and
  `import` lines matches the `hk` pin.
- `must` `pre-commit` formats and lints only the staged files through `just`, with `fix = true` and `stash = "git"`.
  Budget: under 2 seconds.
- `should` The format and lint steps are top-level `steps`, not steps inside one hook. Then `hk check` and `hk fix` run
  them by hand, and `pre-commit` shares them.
- `should` `pre-commit` scans the staged content for secrets with `gitleaks`, pinned in `mise.toml`. This is the
  mechanical check behind "no plaintext secret is tracked".
- `should` A `commit-msg` hook runs hk's `check_conventional_commit` builtin. It accepts `build`, `chore`, `ci`,
  `docs`, `feat`, `fix`, `perf`, `refactor`, `revert`, `style`, and `test`. Other spellings, such as `refact`, are
  findings in the recent history.
- `must` `pre-push` runs `just pre-push`. Budget: under 9 seconds on a warm tree.
- `info` Hooks are local, and hk registers them in the git config. If `git config --get-regexp '^hook\.hk'` prints
  nothing, tell the user to run `just hooks-install`.

Template: [hk.pkl](references/templates.md#hkpkl).

### CI

- `must` One workflow runs `just lint`, `just format-check`, `just typecheck`, and `just test` on every pull request
  and on every push to `main`. Steps stay thin. The logic lives in the recipes.
- `must` Checks do not wait on each other. A lint job never blocks a test job.
- `must` CI installs tools from `mise.toml` and dependencies with `bun install --frozen-lockfile`. It does not call
  `just install`.
- `should` CI installs tools in locked mode, so a version that is not in `mise.lock` fails the job.
  `jdx/mise-action` does this when `mise.lock` exists. Other runners and container builds set `MISE_LOCKED=1`.
- `should` CI skips tools it does not use (`MISE_DISABLE_TOOLS: sops,hk,pkl,gitleaks`).
- `should` Every job has a timeout. A new push cancels the branch's run in progress, except on `main`.
- `should` Actions are pinned to a full commit SHA, with the version in a trailing comment. A tag can be moved to
  other code; a SHA cannot.
- `should` `permissions` defaults to `contents: read`, and the checkout sets `persist-credentials: false`.

Template: [GitHub Actions workflow](references/templates.md#github-actions-workflow). On Tangled, write the workflow
with `tangled-ci` and call the same four recipes.

- `should` GitHub repos run Renovate from a committed `renovate.json5`: dashboard approval before pull requests,
  `chore` semantic commits, `minimumReleaseAge: '3 days'`, a weekly schedule, an explicit `enabledManagers` list, and
  `helpers:pinGitHubActionDigests` so the SHA pins get updates. A repo without an update bot runs `just update` by
  hand.
- `info` `zizmor` audits workflow files for unpinned actions, leaked credentials, and script injection. hk ships it as
  a builtin step for repos that want the check in `pre-commit`.

### Secrets (sops)

Applies when the repo needs secrets. A repo without secrets has no `.sops.yaml`.

- `must` No plaintext secret is tracked. `.gitignore` ignores `.env*` and `keys/*`, and re-includes the encrypted
  files (`!.env.sops.*`, `!.env.*.sops.*`).
- `must` Secrets are sops-encrypted files in the repo, named `.env.sops.yaml` (default), `.env.<stage>.sops.yaml`, or
  `<name>.sops.<ext>`. `.sops.yaml` lists the age recipients.
- `should` Recipes read secrets through a private `_env` recipe that wraps `sops exec-env`, and `SOPS_ENV_FILE`
  selects another file.
- `should` `just/encryption.just` holds the key recipes in group `ENCRYPTION`: `edit-key`, `decrypt-key`,
  `update-keys`, `rotate-keys`. Template: [sops recipes](references/templates.md#sops-recipes).
- `must` CI gets its age key from the host's secret store. CI-only values live in `.env.ci.sops.yaml`.
- Never change `.sops.yaml`, rotate keys, or write decrypted output without an explicit request. Report the finding
  and stop.

### Root files

- `must` `AGENTS.md`: layout, the common `just` commands, the runtime, and project rules. Keep it short. Global rules
  are not repeated.
- `must` `README.md` with the visibility note. See `repo-docs`.
- `should` `.gitignore` covers `.DS_Store`, `node_modules/`, `dist/`, `*.log`, `.env*`, `keys/*`, and `.local/`
  (scratch space for agents and local output).
- `should` Public repos have an MIT `LICENSE` and a `SECURITY.md` that says how to report a vulnerability.
- `info` Versioned projects keep a `CHANGELOG.md` (see `changelog`). Design decisions live in `docs/rfc/` (see `rfc`).

## Audit

Read-only. Do not edit, install, or run a recipe that writes.

1. **Find the repo root and the state.** Run `git rev-parse --show-toplevel`, `git status -sb`, and
   `git remote -v`. Audit the default branch. If the checkout is on another branch or behind its remote, check
   `origin/main` with `git show origin/main:<file>` and say so in the report. A stale branch gives wrong findings.
   If the folder is not a git repository or has no remote, report that as a `must` finding and audit the files on
   disk.
2. **Classify.** Record the host, personal or organization, public or private, whether `package.json` exists, whether
   secrets exist, and the runtime. These decide which baseline items apply.
3. **Read the inputs.** `mise.toml`, `mise.lock`, `bunfig.toml`, `package.json`, the lockfiles, `justfile` and
   `just/*.just`, `.oxlintrc.json`, `.oxfmtrc.json`, `.editorconfig`, `tsconfig.json`, `hk.pkl`, the CI directory,
   `.sops.yaml`, `.gitignore`, `AGENTS.md`, and `README.md`. Run `just --summary` for the recipe names and
   `git log -20 --format=%s` for the commit types.
4. **Search for the code findings.** Search the sources, excluding `node_modules` and `dist`, for `bun:` imports,
   `Bun.` and `Deno.` globals, and `.skip(` or retry options in tests.
5. **Walk the baseline in order.** Mark every item pass, finding, or not applicable. Quote the file and line for each
   finding. Do not report an item you did not check.
6. **Write the report** in the format below. Then stop. Offer to fix the findings in the suggested order; do not start.

```markdown
# Repo standard audit: <repo>

Branch `<branch>` at `<short sha>`, host <host>, <personal | organization>, <public | private>, runtime <Bun | Node>.
<n> must, <n> should, <n> info.

## Must

1. **<baseline item>:** <what is there, with `file:line`>. Fix: <one line>.

## Should

1. **<baseline item>:** <what is there>. Fix: <one line>.

## Info

- <context that needs no fix>

## Passing

<one line that lists the baseline sections with no finding>

## Suggested order

1. <fix that unblocks the others, usually package manager, then recipes, then hooks, then CI>
```

Leave out an empty section. If nothing is found, say so in one sentence and list what was checked.

## Scaffold

1. **Settle the inputs.** You need: personal or organization, public or private, the runtime (Bun or Node), and
   whether the repo needs secrets. Read them from the request or the existing files. Ask once for what is missing.
2. **Check what exists.** In a repo that already has files, run the [audit](#audit) first and scaffold only the
   findings. Never overwrite a config file without reading it.
3. **Write in dependency order.** Start each file from [references/templates.md](references/templates.md). Resolve
   each action's SHA with `git ls-remote <repo-url> refs/tags/<tag>`. Do not copy a SHA from the template.
   `mise.toml`, then `bunfig.toml` and `package.json`, then the `justfile`, then `.oxlintrc.json`, `.oxfmtrc.json`,
   `.editorconfig`, `.gitignore`, and `tsconfig.json`, then `hk.pkl`, then the CI workflow, then the sops files if
   needed, then `AGENTS.md`, `README.md`, and `LICENSE`.
4. **Migrate, do not stack.** When replacing a package manager, formatter, or hook tool, remove the old lockfile,
   config, and recipes in the same change. Let `bun install` write the new lockfile and review its diff.
5. **Prove it.** Run `just install`, `just hooks-install`, `hk validate`, then `just lint`, `just format-check`,
   `just typecheck`, and `just test`. All must pass. Time `just pre-push` and report the number. If a check fails on
   existing code, fix the code or report it. Do not relax the check.
6. **Hand over the manual steps.** List what only the user can do: create the remote, pick a spindle or enable
   Actions, add CI secrets, and mark the checks as required. Never ask for a secret value in chat.
7. **Do not commit or push.**

## Checklist

- The mode matches the request: audit edits nothing, scaffold ends with passing checks.
- The audit read the default branch, and the report names the branch and commit.
- Every finding quotes a file and has a one-line fix.
- No check was lowered, skipped, or removed to get a green run.
- Hooks, `just pre-push`, and CI call the same recipes.
- `bun.lock` is the only lockfile and tool pins are exact.
- No secret value appears in a file, the report, or the chat.
