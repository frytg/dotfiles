---
name: tangled-ci
description: >-
  Write and edit Tangled CI workflows (`.tangled/workflows/*.yml`, run by a spindle) in house style: `microvm` engine,
  thin steps that call the repo's `just` recipes, a comment header that names required secrets, `push` paired with
  `manual`, and secrets referenced by name only. Covers triggers, engines and images, nix `dependencies`, clone depth,
  caching, built-in `TANGLED_*` variables, secrets and trusted runs, and the failure signatures a push or a run prints.
  Use when the user asks to "add CI", "update CI", "fix the pipeline", "add a lint/test/build/deploy workflow", "run
  this on every push", "add a nightly job", or "add a CI secret" in a repository hosted on tangled.org, mentions
  "spindle" or "Tangled pipelines", or edits any file under `.tangled/workflows/`. Not for migrating a repo or
  first-time GitHub mirror setup (use migrate-to-tangled), reading Tangled content (use tangled), or GitHub Actions.
license: MIT
metadata:
  author: frytg
  agent: claude
  category: engineering
---

# Tangled CI

A Tangled CI change is one small YAML file in `.tangled/workflows/` that the spindle accepts on the next push. The
workflow holds triggers, an engine, and tools. The actual lint, test, and build logic stays in the repo's `just`
recipes, so CI and a local shell run the same commands.

Docs: [how CI works](https://tangled.org/docs/spindles/),
[writing workflows](https://tangled.org/docs/spindles/writing-workflows/),
[workflow reference](https://tangled.org/docs/spindles/workflows/), [engines](https://tangled.org/docs/spindles/engines/),
[secrets](https://tangled.org/docs/spindles/secrets/). Fetch the reference page when a field is not covered below.

## When to use

- The repo has a `tangled.org` remote (`git remote -v`) or a `.tangled/workflows/` directory, and the user asks for any
  CI change.
- Adding, renaming, or editing a file under `.tangled/workflows/`.
- A pipeline fails, never starts, or times out, and the user wants it fixed.
- A workflow needs a new secret, a cache, a schedule, or a different trigger.

## Not for

- Moving a repo to Tangled or setting up the GitHub mirror for the first time. Use `migrate-to-tangled`.
- Reading files, issues, or pull requests from Tangled. Use `tangled`.
- A repo that lives only on GitHub. If the repo has `.github/workflows/` and no Tangled remote, stop and say so.

## How a spindle runs workflows

These facts decide how you split and order work.

- One event makes one pipeline. Every workflow file whose `when` matches runs in parallel. Workflows cannot depend on
  each other, so work that must run in sequence goes into one file as ordered steps.
- Steps run in order. The first step that exits non-zero fails the workflow, and later steps do not run.
- Each step is a new Bash shell. Files and installed packages stay between steps on `microvm`, but `export` and `cd`
  do not, so repeat `export PATH=...` in every step that needs it.
- The whole workflow, queue time included, must finish within the spindle's timeout. The default is 5 minutes. Put slow
  jobs in their own file so they run in parallel with the fast ones.
- The spindle rejects unknown keys. A typo fails the workflow with an error that points at the line.
- Only trusted runs get secrets, caches, and OIDC tokens. Pull requests from forks or patches, and every run a
  collaborator had to approve, get none of them.

## Workflow

1. **Confirm the host.** Check `git remote -v` and `.tangled/workflows/`. If the repo mirrors to GitHub, CI still
   belongs on Tangled; do not add GitHub Actions.
2. **Read what exists.** Read every file in `.tangled/workflows/` and the `justfile`. Match the existing quote style
   and indentation, because the repo's formatter owns them.
3. **Put the logic in `just`.** A step calls `just lint`, `just test`, or `just build`. If the recipe does not exist,
   add it first (see the `just-commands` skill), then call it from the workflow.
4. **Pick the file.** Edit an existing workflow when the concern matches. Otherwise add one file per concern, named in
   kebab-case with `.yml`: `lint.yml`, `test.yml`, `build.yml`, `deploy.yml`.
5. **Write it** from the [template](#template) and the [house style](#house-style).
6. **Check it locally.** No local spindle runner exists. Parse the file with a YAML parser that is already on the
   machine, then check every key against [Fields](#fields). Run the same `just` recipes locally to confirm they pass.
7. **Hand over the browser steps.** Spindle selection and secrets are set in the web UI. List what the user must do
   (see [Secrets](#secrets)). Never ask for a secret value in chat.
8. **Do not commit or push.** Tell the user that `git push` prints workflow compile errors, and that
   `git push -o verbose-ci` also lists skipped workflows.

## House style

- **Header comment.** Line 1 links the spindle docs. Then one line that says what the workflow does, one line per
  required secret, and the setup hint. Add a line for any non-obvious constraint of the image.
- **Top-level order:** `when`, `engine` + `image`, `clone`, `dependencies`, `registry`, `environment`, `cache`,
  `steps`. One blank line between blocks. `engine` and `image` sit together.
- **Engine:** `engine: microvm`. Use another engine only on request.
- **Events and branches are lists**, also for one value: `event: ['push', 'manual']`, `branch: ['main']`.
- **`manual` goes with every `push` condition**, so the user can rerun from the Pipelines tab.
- **Quotes:** single quotes in new files. Quote step names, branch patterns, and `environment` values. Leave package
  names and flake references bare.
- **Indent:** 2 spaces, unless the repo's formatter config says otherwise.
- **Step names:** short, capitalised, the action or the recipe: `'Install dependencies'`, `'Lint'`, `'Build'`.
- **Commands:** a single command stays on one line. Anything longer uses a `|` block that opens with the `set` line.
- **`set` line:** `set -eo pipefail` on `image: nixos`. Steps run in a login shell, and the NixOS `/etc/bash_logout`
  reads an unset variable on exit, so `-u` can fail a step whose commands all passed. On `image: alpine` use
  `set -euo pipefail`.
- **`environment`** holds non-secret config in `UPPER_SNAKE_CASE`. The file is public, so no secret goes there.
- **Pin tools.** Pass an explicit version to every installer. No floating `latest`.
- **Explicit `clone.depth`.** Write the depth even when it is `1`.

## Template

Lint and build on every push and on pull requests to `main`:

```yaml
# Spindle docs: https://tangled.org/docs/spindles/
# Run just lint and just build on every push and on pull requests to main.
# Assign a spindle under repo Settings → Pipelines.

when:
  - event: ['push', 'manual']
    branch: ['**']
  - event: ['pull_request']
    branch: ['main']

engine: microvm
image: nixos

clone:
  depth: 1

dependencies:
  - go
  - just

registry:
  nixpkgs: github:nixos/nixpkgs/nixos-unstable

steps:
  - name: 'Lint'
    command: |
      set -eo pipefail
      just lint
  - name: 'Build'
    command: |
      set -eo pipefail
      just build
```

A branch of the same repo with an open pull request matches both conditions and can run twice. If that costs too much
queue time, narrow the push condition to `['main']`.

## Fields

Common to every engine:

- `when`: list of conditions; any match runs the workflow. Without it, the workflow runs for every event.
- `engine`: **required**. `microvm`, `nixery`, or `namespace`. A missing value fails with `missing engine`.
- `clone`: `skip` (default `false`), `depth` (default `1`), `submodules` (default `true`), `tags` (default `true`).
- `environment`: variables for every step. A step's own `environment` overrides it.
- `cache`: directories kept between runs. See [Cache](#cache).
- `steps`: list of `name`, `command`, and optional `environment`.
- `runs_on`: executor labels. Only has an effect on spindles that the operator split into a mill and executors.
- `audience`: requests an OIDC token, exposed as `TANGLED_ID_TOKEN`. Needs the operator to have enabled OIDC.
- `workflows`: several named workflows in one file. The file then has no other top-level key, and entries share no
  fields. Prefer one file per workflow.

Added by `microvm`:

- `image`: `nixos`, `alpine`, or `almalinux10` on the hosted spindle.
- `dependencies`, `registry`, `substituters`, `services`, `virtualisation`: NixOS images only. They have no effect on
  other images.

## Triggers

- `event`: `push`, `pull_request`, `manual`, `schedule`.
- `branch`: glob over branch names. For `pull_request` it matches the **target** branch. A `push` condition needs
  `branch` or `tag`.
- `tag`: glob over tag names, `push` only.
- `paths`: glob over changed files. The condition matches only if a changed file matches.
- `types`: `pull_request` only. `opened`, `reopened`, `synchronize`, `closed`, `merged`. Defaults to the first three.
- `schedule`: list of `cron` entries with an optional IANA `timezone` (default `UTC`). Required for `schedule` events,
  and that condition takes no `branch`, `tag`, `types`, or `paths`.

`*` stops at `/`, `**` does not. `branch: ['*']` skips `feature/login`, so use `['**']` for "every branch".

The spindle does not evaluate `when` for manual runs. `manual` only marks the workflow as startable by hand.

```yaml
when:
  - event: ['push']
    tag: ['v*']
  - event: ['schedule']
    schedule:
      - cron: 'H 2 * * *'
        timezone: Europe/Berlin
```

Use `H` for the minute, so runs spread across the hour. The minimum interval is 5 minutes on a default spindle.
Scheduled runs use the default branch. `@daily` nicknames and a seconds field are not supported.

To skip CI for one push: `git push -o skip-ci`.

## Images and tools

Pick the image by where the tools come from.

1. **The tools are in nixpkgs** (search [search.nixos.org](https://search.nixos.org/)): `image: nixos` and list them
   under `dependencies`. This is the default. A bare name comes from the image's nixpkgs. `unstable#zig` takes one
   package from nixpkgs-unstable. `github:acme/tool#default` takes a package from any flake.
2. **The repo pins its toolchain in `mise.toml`** and CI must use the same versions: `image: alpine`, install the
   tools in the first steps, then run `mise install` and `mise exec -- just <recipe>`. Prebuilt generic Linux binaries
   often do not start on NixOS, so mise-managed toolchains stay on `alpine`.

The house `registry` block maps `nixpkgs` to `nixos-unstable`, so bare names resolve to current versions. Remove the
block when the image's own nixpkgs revision is new enough.

On `alpine`, `dependencies` is ignored. Install with `apk` and repeat the `PATH` export in each step:

```yaml
engine: microvm
image: alpine

environment:
  MISE_VERSION: 'v2026.1.0'

steps:
  - name: 'Install mise'
    command: |
      set -euo pipefail
      apk add --no-cache bash curl
      curl -fsSL https://mise.run | MISE_INSTALL_PATH="$HOME/.local/bin/mise" sh
  - name: 'Install dependencies'
    command: |
      set -euo pipefail
      export PATH="$HOME/.local/bin:$PATH"
      mise install
  - name: 'Lint'
    command: |
      set -euo pipefail
      export PATH="$HOME/.local/bin:$PATH"
      mise exec -- just lint
```

That first step pipes a remote script into a shell. Keep it in workflows that already use it, with a pinned version.
For a new workflow, prefer option 1, and ask the user before adding an install script.

Databases and Docker come from NixOS options on `image: nixos`. `true` is short for `enable: true`:

```yaml
services:
  postgresql:
    enable: true
    ensureDatabases: ['spindle-workflow']
    ensureUsers:
      - name: spindle-workflow
        ensureDBOwnership: true

virtualisation:
  docker: true
```

Steps run as the user `spindle-workflow` in `/workspace/repo`. The VM has outbound network access only.

## Secrets

Secrets live on the spindle, not in the repo. Every secret reaches every step of every workflow as an environment
variable with the same name.

1. Name the secret in `UPPER_SNAKE_CASE` (1 to 50 characters, a valid shell variable name; value up to 4096
   characters).
2. Add a header line: `# Required secret: DEPLOY_TOKEN (API token with deploy scope).`
3. Read it in the step by name. Never echo it, and never copy it into `environment`.
4. Guard optional integrations, so a run without the secret skips instead of failing:

   ```bash
   if [ -z "${DEPLOY_TOKEN:-}" ]; then
     echo "DEPLOY_TOKEN not set — skipping"
     exit 0
   fi
   ```

5. Tell the user to add it under the repository's **Settings → Pipelines → Secrets → Add secret**. A spindle must be
   selected first. A value cannot be read back; to change it, delete it and add it again.

Flag these to the user when they apply:

- Anyone who can push a matching branch can make a step send the secrets elsewhere. Push access is secret access.
- Log masking replaces values with `***`, but it is a safety net, not a guarantee.
- Secrets are stored per spindle. After a spindle change, add them again.
- A workflow that needs a secret gets none on fork, patch, or approved pull request runs. Keep deploy and mirror
  workflows on `push` only.
- For cloud providers that accept OIDC, `audience` plus `TANGLED_ID_TOKEN` removes the stored key. See
  [OIDC federation](https://tangled.org/docs/spindles/oidc/).

## Cache

```yaml
cache:
  - key: go-mod
    hash: [go.sum]
    fallback: true
    paths: [.gocache]
```

- `key` and `paths` are required. `hash` folds lockfile content into the key, so a lockfile change invalidates the
  entry. `fallback: true` then restores the newest older entry instead of starting empty.
- Relative paths start at the checkout. No spaces, quotes, shell metacharacters, or `..`.
- `when: always` also saves after a failed run. The default is `on-success`.
- A cache miss never fails a workflow. An invalid entry does.
- Entries are ignored when the operator configured no cache storage, and on untrusted runs. Saving needs `zstd` in
  the image.

## Built-in variables

- `CI` is always `true`.
- `TANGLED_REF_NAME` (`main`, `v1.0.0`), `TANGLED_REF` (`refs/heads/main`), `TANGLED_REF_TYPE` (`branch` or `tag`).
- `TANGLED_SHA`: the commit that triggered the pipeline.
- `TANGLED_PIPELINE_KIND`: `push`, `pull_request`, `manual`, or `schedule`.
- `TANGLED_REPO_NAME`, `TANGLED_REPO_DEFAULT_BRANCH`, `TANGLED_REPO_URL`, `TANGLED_REPO_KNOT`, `TANGLED_REPO_DID`
  (owner), `TANGLED_REPO_REPO_DID` (repository).
- Pull requests only: `TANGLED_PR_SOURCE_BRANCH`, `TANGLED_PR_TARGET_BRANCH`, `TANGLED_PR_SOURCE_SHA`,
  `TANGLED_PR_AT_URI`.
- Manual runs: each input as `TANGLED_INPUT_<KEY>`. Ref variables are set only when the caller names a ref, so write
  `${TANGLED_REF_NAME:-main}` in workflows that allow `manual`.
- Schedules: `TANGLED_SCHEDULED_AT`.

## Failure signatures

- **`missing engine`**: add `engine`.
- **Error that points at a line**: unknown key. Check for a typo, or an engine field on the wrong engine.
- **Nothing runs after a push**: no spindle is selected under Settings → Pipelines, the `when` block does not match
  (`*` against a branch with `/`, or a `push` condition without `branch` or `tag`), or the push used `skip-ci`.
- **Tool not found on `alpine`**: `dependencies` has no effect there. Install with `apk` in a step.
- **Tool not found in a later step**: the `PATH` export from an earlier step is gone. Repeat it.
- **Step fails on `nixos` although every command passed**: remove `-u` from the `set` line.
- **Status `timeout`**: the run passed the 5-minute budget. Split the workflow, add a cache, or cut work.
- **Secret is empty**: the run is untrusted, the name differs, or the secret sits on a different spindle.
- **Pull request run stays blocked**: the author has no push access. A collaborator must approve it, and the approved
  run still gets no secrets.
- **Mirror push rejected from a shallow clone**: the push holds more new commits than `clone.depth`. Raise the depth.
- **Cache never restores**: untrusted run, no operator cache storage, or `zstd` is missing in the image.

## Checklist

- [ ] The file is under `.tangled/workflows/`, kebab-case, `.yml`.
- [ ] The header has the docs link, the purpose, every required secret, and the spindle hint.
- [ ] `engine` is set, and every `push` condition has `branch` or `tag` and includes `manual`.
- [ ] Steps call `just` recipes, and those recipes pass locally.
- [ ] No secret value is in the file. Tool versions are pinned.
- [ ] The `set` line matches the image.
- [ ] The reply lists the browser steps (spindle, secrets) and the push hint. Nothing was committed or pushed.
