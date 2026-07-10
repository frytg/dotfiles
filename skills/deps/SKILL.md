---
name: deps
description: Checks for outdated dependencies in a project using its configured package manager (bun, npm, nub, yarn, cargo, go, pip, bundler), and fetches upstream release notes for GitHub Actions and other dependencies to flag breaking changes. Use when the user asks to check for updates, look for outdated packages, audit dependencies, or review upgrade impact.
---

# Check Dependencies

Detect the project's package manager, list outdated dependencies, and surface breaking changes from upstream release notes.

## 1. Detect the package manager

Walk the project root for the first matching lockfile or manifest. Stop at the first hit.

| File                                   | Manager        | Outdated command      |
| -------------------------------------- | -------------- | --------------------- |
| `bun.lock` / `bun.lockb`               | bun            | `bun outdated`        |
| `package-lock.json`                    | npm            | `npm outdated`        |
| `pnpm-lock.yaml`                       | nub            | `nub outdated`        |
| `yarn.lock`                            | yarn (classic) | `yarn outdated`       |
| `Cargo.lock`                           | cargo          | `cargo outdated`      |
| `go.sum`                               | go modules     | `go list -u -m all`   |
| `pyproject.toml` / `requirements*.txt` | pip            | `pip list --outdated` |
| `Gemfile.lock`                         | bundler        | `bundle outdated`     |

If multiple lockfiles are present (e.g. both `bun.lock` and `package-lock.json`), ask the user which manager to use. Don't guess.

`cargo outdated` requires `cargo install cargo-outdated` once.

## 2. List outdated dependencies

Run the matched command from the project root. Capture full output, then parse for: package name, current version, wanted version, latest version.

### bun

```bash
bun outdated
```

### npm

```bash
npm outdated
```

### nub

```bash
nub outdated                  # table of outdated deps
nub outdated --json           # machine-readable
nub outdated --long           # also show specifier and dep type
nub outdated -r               # across all workspace packages
nub outdated '<pattern>'      # e.g. '@babel/*'

# Upgrade (respects semver ranges)
nub update
nub update <package>@latest   # bump a single package to latest
nub add <package>@latest      # add or upgrade to a specific version
nub dedupe                    # dedupe the dep tree
```

### yarn (classic)

```bash
yarn outdated
```

### cargo

```bash
cargo install cargo-outdated   # one-time
cargo outdated
```

### go

```bash
go list -u -m all
```

### pip

```bash
pip list --outdated
```

### bundler

```bash
bundle outdated
```

## 3. Find breaking changes

Group outdated packages into two buckets: **patch/minor** and **major**. Only majors need release-note research.

### GitHub Actions

For every `uses: owner/repo@ref` in `.github/workflows/*.yml` (or `.yaml`):

1. Resolve `ref`. If it's a major-version tag (e.g. `@v4`), the next breaking change is the next major (e.g. `@v5`). If it's a SHA, resolve to the matching tag first:
   ```bash
   gh api repos/{owner}/{repo}/git/refs/tags
   ```
2. Fetch the next major's release notes:
   ```bash
   gh release view v5 --repo actions/checkout
   # or list recent releases
   gh api repos/actions/checkout/releases?per_page=10
   ```
3. For public repos, the raw API works without auth:
   ```bash
   curl -s https://api.github.com/repos/{owner}/{repo}/releases/latest
   ```
4. Read the body for `BREAKING`, `Breaking`, `⚠️`, or migration notes. Note API/signature changes, default-behavior changes, and required Node/runtime bumps.

### Other dependencies

For each package with a major version bump, locate the source repo. Sources in order of reliability:

1. The package's GitHub repo (check `package.json` → `repository`, or `cargo`/`go`/`pip` metadata).
2. The registry page itself (e.g. `https://www.npmjs.com/package/<name>` links to the repo).
3. The changelog file in the repo (`CHANGELOG.md`, `CHANGES.md`, `Releases`).

Fetch the release notes:

```bash
# Recent releases for a GitHub repo
gh release list --repo {owner}/{repo} --limit 20

# A specific tag
gh release view v2.0.0 --repo {owner}/{repo}

# Atom feed (no auth, works for public repos)
curl -sL https://github.com/{owner}/{repo}/releases.atom | head -200

# Changelog file
curl -sL https://raw.githubusercontent.com/{owner}/{repo}/main/CHANGELOG.md
```

Scan for `BREAKING`, `Breaking`, `⚠️`, `Migration`, `Removed`, renamed exports, default flips, and minimum runtime/peer bumps. Skip the raw changelog if it's mostly patch entries — only the majors are interesting.

## 4. Check tool config drift (biome)

If the project uses biome, the version pinned in `biome.json#.$schema` can lag behind the installed `biome` binary. Drift means new rules/options aren't available and deprecated keys may be ignored or warned. Biome ships a built-in `migrate` command for exactly this:

```bash
# Dry-run — prints a diff if the config needs an update, no-op if not
biome migrate

# Apply the migration
biome migrate --write
```

The check is safe to run unconditionally: if `$schema` already matches the installed version, `biome migrate` exits silently. To compare versions explicitly without running the command:

```bash
# Installed version
biome --version

# Schema version (matches the URL in $schema: .../schemas/X.Y.Z/schema.json)
grep -oE '/schemas/[0-9]+\.[0-9]+\.[0-9]+' biome.json | head -1
```

If a migration was applied, re-run the linter to confirm the new schema parses cleanly:

```bash
biome check .
```

Skip this step if the project has no `biome.json` / `biome.jsonc`. For other tooling config (`.eslintrc`, `prettier.config.*`, etc.) there's no equivalent `migrate` command — compare the pinned version against the installed binary and consult the tool's changelog manually.

## 5. Report

Produce a tight summary, not a raw dump:

- **Patch & minor** — one bullet per package, no commentary.
- **Major & breaking** — one bullet per package with: current → next, a one-line breaking-change summary, and a link to the release notes.
- **Action items** — anything needing user decision: Node/runtime bump, peer-dep conflict, deprecated transitive, security advisory.

Keep the report scannable. Don't paste the full `outdated` output.

## Safety

- Never run `update` / `upgrade` / `install` as part of this skill. The user decides what to bump.
- Never edit lockfiles or `package.json` versions. Reporting is the only job.
- For private registries, `npm outdated` may still work, but `gh` release lookups need an authenticated user.
