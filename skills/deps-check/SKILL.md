---
name: deps-check
description: Checks for outdated dependencies in a project using its configured package manager (bun, npm, cargo, go, pip, bundler), plus GitHub Actions refs, Terraform provider pins, and container images in Kubernetes manifests; respects the repo's configured release cooldown (minimumReleaseAge and equivalents) and fetches upstream release notes to flag breaking changes. Read-only. Use when the user asks to "check for updates", "look for outdated packages", "audit dependencies", "deps check", or review upgrade impact. Not for applying updates (use deps-auto).
license: MIT
metadata:
  author: frytg
  agent: pi
  category: engineering
---

# Check Dependencies

Detect the project's package manager, list outdated dependencies, and surface breaking changes from upstream release notes. Infra-style repos with no lockfile still have dependencies: GitHub Actions refs, Terraform provider pins, and container images pinned in Kubernetes manifests — all covered below.

This skill only reports. The `deps-auto` skill runs it, then applies the safe part of the report.

## 1. Detect the package manager

Walk the project root for the first matching lockfile or manifest. Stop at the first hit.

| File                                   | Manager    | Outdated command      |
| -------------------------------------- | ---------- | --------------------- |
| `bun.lock` / `bun.lockb`               | bun        | `bun outdated`        |
| `package-lock.json`                    | npm        | `npm outdated`        |
| `Cargo.lock`                           | cargo      | `cargo outdated`      |
| `go.sum`                               | go modules | `go list -u -m all`   |
| `pyproject.toml` / `requirements*.txt` | pip        | `pip list --outdated` |
| `Gemfile.lock`                         | bundler    | `bundle outdated`     |

When both `bun.lock*` and `package-lock.json` are present, prefer bun. Only ask the user when the signal is truly ambiguous.

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

### Terraform providers (no lockfile manager — pin comparison)

If the repo has `*.tf` files with `required_providers` version pins (common in infra/homelab repos with no package manager at all), compare each pin against the registry:

```bash
curl -s "https://registry.terraform.io/v1/providers/{namespace}/{name}/versions" \
  | tr '{' '\n' | grep -oE '"version":"[0-9]+\.[0-9]+\.[0-9]+"' | cut -d'"' -f4 | sort -V | tail -1
```

Pins are usually exact (`version = "2.81.0"`), so any newer release is an update. Same-major newer → patch/minor bucket; different major (or a 0.x provider minor flagged as breaking in its changelog — 0.x providers don't guarantee semver) → major bucket with a changelog link. The `.terraform.lock.hcl` mirrors the pins; report against the pin, not the lockfile.

## 3. Apply the release cooldown

A version that is newer than the repo's cooldown is not an update yet. Freshly published releases are the main vector for supply-chain attacks, so the cooldown filters every candidate before any other step.

### Resolve the cooldown

Read each setting that exists in the repo. Each one uses a different unit, so convert all values to a duration before you compare them:

- bun: `bunfig.toml` → `[install] minimumReleaseAge` — **seconds** (`259200` = 3 days).
- npm: `.npmrc` → `min-release-age` — **days**.
- pip: `--uploaded-prior-to` in `pip.conf` or the install recipe — a timestamp or a duration.
- mise: `mise.toml` `[settings]` → `minimum_release_age` — a duration (`3d`). Applies to the tools mise pins.
- Renovate: `renovate.json5` / `renovate.json` → `minimumReleaseAge` — a duration (`3 days`). Package rules can override it per manager.
- Dependabot: `.github/dependabot.yml` → `cooldown.default-days` and the per-semver keys — **days**.

Rules:

1. Each ecosystem uses its own setting.
2. An ecosystem without a setting (GitHub Actions, Terraform providers, container images, cargo, go) uses the strictest value configured anywhere in the repo.
3. A repo with no setting at all uses **3 days**.
4. An explicit cooldown in the user's request or the automation prompt overrides all of the above.

### Check each candidate

Get the publish time of every candidate version:

```bash
# npm registry (bun, npm)
curl -s "https://registry.npmjs.org/<name>" | jq -r '.time["<version>"]'
# PyPI
curl -s "https://pypi.org/pypi/<name>/<version>/json" | jq -r '.urls[0].upload_time_iso_8601'
# crates.io
curl -s -A "deps-check" "https://crates.io/api/v1/crates/<name>/<version>" | jq -r '.version.created_at'
# Go module proxy
curl -s "https://proxy.golang.org/<module>/@v/<version>.info" | jq -r '.Time'
# GitHub release (Actions, Terraform providers, anything released on GitHub)
gh api "repos/{owner}/{repo}/releases/tags/<tag>" --jq '.published_at'
# Container image (the field is often zeroed by reproducible builds)
crane config "<image>:<tag>" | jq -r '.created'
```

- Pick the **newest version that is older than the cooldown**, not the newest version. The result can be a lower version than `latest`.
- A version with an unknown or zeroed publish time counts as too new. Do not guess.
- A newer version that is still in cooldown goes in the report with the date it becomes eligible.

## 4. Find breaking changes

Group the eligible updates into two buckets: **patch/minor** and **major**. Only majors need release-note research. A minor bump of a `0.x` package goes in the major bucket, because semver does not promise compatibility below `1.0`.

### GitHub Actions

For every `uses: owner/repo@ref` in `.github/workflows/*.yml` (or `.yaml`):

1. Resolve `ref`. If it's a major-version tag (e.g. `@v4`), the next breaking change is the next major (e.g. `@v5`). If it's a SHA, resolve to the matching tag first:

   ```bash
   gh api "repos/{owner}/{repo}/git/refs/tags"
   ```

2. Fetch the next major's release notes:

   ```bash
   gh release view v5 --repo actions/checkout
   # or list recent releases
   gh api "repos/actions/checkout/releases?per_page=10"
   ```

3. For public repos, the raw API works without auth, but is rate-limited to 60 requests/hour/IP. Use `gh` with auth (`gh auth status`) for higher limits:

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

## 5. Check container images (Kubernetes manifests)

If the repo contains Kubernetes workload manifests (files with `kind: Deployment`, `StatefulSet`, `DaemonSet`, `Job`, `CronJob`, or `Pod`), every pinned `image:` tag is a dependency. Find them:

```bash
rg -l --type yaml -e '^kind: (Deployment|StatefulSet|DaemonSet|Job|CronJob|Pod)\b' .
```

**If the `k8s-images` skill is available, delegate to it** — it owns the full flow: extracting images (multi-doc safe, `yq`), classifying floating/templated/digest-pinned tags, `crane ls` lookups bounded by the pinned major, the one-at-a-time confirmation, and the YAML edits. Never duplicate that logic inline.

Without the skill, do the read-only minimum yourself:

1. Extract images per manifest (containers + initContainers, CronJob via `.spec.jobTemplate...`), dedupe.
2. Skip templated (`{{`, `${`), digest-pinned (`@sha256:`), and floating tags (`latest`, `main`, `stable`, dated).
3. `crane ls <repo>` per image, pick the highest tag matching the pinned shape within the same major; different-major latest goes in the **major** bucket with a release-notes link.
4. Report — don't edit. Same rule as lockfiles: the user approves every bump.

Registry notes:

- Bare names default to Docker Hub (`nginx` → `docker.io/library/nginx`).
- Private registries need ambient credentials; a failed lookup is a registry error in the report, not a bug.
- `crane ls` is slow; call it once per repo, not per file. Don't wrap it in `timeout` on macOS — the binary doesn't exist there and every call silently fails.

## 6. Find the repo's checks

`deps-auto` verifies every update with the repo's own checks, and a toolchain bump can change what those checks report. Read them from the `justfile`, including files it imports (`just/*.just`):

```bash
just --summary                 # recipe names
just --show <recipe>           # the commands a recipe runs
```

Map the recipes by their usual names. Most repos run the oxc toolchain behind them, but the recipe name is the contract, not the tool:

- `typecheck` — type check, usually `bun check` or `tsc --noEmit`.
- `lint` — linter, usually `oxlint`.
- `format-check` — formatter in check mode, usually `oxfmt --check`. `format` writes the fixes.
- `test` — the test suite.
- `pre-push` — runs what CI runs. Prefer it when it exists.

Without a `justfile`, read the checks from the CI workflow, then `AGENTS.md` or `README.md`. Do not invent a command. Report a repo with no checks at all as an action item.

Then compare the report with the recipe bodies:

- An update to a tool that a check recipe calls (`oxlint`, `oxfmt`, `typescript`, a test runner) goes in the report as a **toolchain** update. It can add new lint findings, reformat files, or tighten types without any code change.
- A config `$schema` that points into `node_modules` follows the installed version. A `$schema` URL with a version in it needs the same bump as the tool; list it next to the tool.

## 7. Report

Produce a tight summary, not a raw dump. Open with the cooldown in effect and where it came from (for example `3 days, bunfig.toml`), and the checks found in step 6 (for example `checks: just pre-push`).

- **Patch & minor** — one bullet per package, no commentary.
- **Toolchain** — updates to tools that a check recipe calls, with the recipe that calls them.
- **Major & breaking** — one bullet per package with: current → next, a one-line breaking-change summary, and a link to the release notes. Includes container images whose upstream major differs from the pinned one.
- **Container images** — out-of-date pinned tags (file, container name, current → latest), plus separate buckets for floating tags that should be pinned and registry errors. Already-latest images get one line, not a list.
- **In cooldown** — one bullet per newer release that is still too young: name, version, and the date it becomes eligible.
- **Action items** — anything needing user decision: Node/runtime bump, peer-dep conflict, deprecated transitive, security advisory, rolling tags to pin.

Keep the report scannable. Don't paste the full `outdated` output.

## Safety

- Never run `update` / `upgrade` / `install` as part of this skill. The user decides what to bump, or runs `deps-auto` to apply the safe updates.
- Never edit lockfiles or `package.json` versions. Reporting is the only job.
- Never deploy or mutate live state: no `terraform apply`/`init -upgrade`, no `kubectl apply`, no cluster or host changes. Infra deps (providers, images) are reported like any other dependency.
- For private registries, `npm outdated` may still work, but `gh` release lookups need an authenticated user.
