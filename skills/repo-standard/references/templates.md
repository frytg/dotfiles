# Repo standard templates

Starting points for the files the [baseline](../SKILL.md#baseline) requires. Version numbers are placeholders. Pin
the current release of each tool, and keep the `hk` version in `mise.toml` and in the `hk.pkl` `amends` line equal.

## mise.toml

List only the tools the recipes and hooks call. Drop `sops` in a repo without secrets, and `node` in a Bun-only repo.
With `lockfile = true`, `mise install` writes `mise.lock` for every platform, the CI runner included.

```toml
[settings]
minimum_release_age = "3d"
lockfile = true

[tools]
node = "26.13.0"
bun = "1.4.4"
just = "1.59.0"
sops = "3.13.3"
# git hooks: https://hk.jdx.dev
hk = "2.13.0"
pkl = "0.33.0"
# secret scan in the pre-commit hook
gitleaks = "8.30.1"
```

## bunfig.toml

```toml
telemetry = false

[install]
saveTextLockfile = true
registry = "https://registry.vlt.io/upstream/npm/"
# 3 days in seconds, the same cooldown as mise minimum_release_age
minimumReleaseAge = 259200

[install.scopes]
jsr = "https://npm.jsr.io"
```

## justfile

The standard recipes for a single-package JS/TS repo. Layout and comment rules follow the `just-commands` skill.
`oxlint` and `oxfmt` are exact-version dev dependencies. `--no-install` makes a recipe fail when one is missing, where
plain `bun x` would download the latest release.

```just
# list all recipes
_default:
	@just --list

# install pinned tools and dependencies
[group('DEV-SETUP')]
install:
	mise install
	bun install

# bump tool pins and dependencies, then format
[group('DEV-SETUP')]
update:
	mise upgrade --bump -y --local
	bun update
	just format
	-bun outdated

# install the git hooks (pre-commit, pre-push)
[group('DEV-SETUP')]
hooks-install:
	hk install

# lint the code base
[group('LOCAL')]
lint:
	bun x --no-install oxlint

# lint specific files (called by the pre-commit hook)
[group('LOCAL')]
lint-files *files:
	bun x --no-install oxlint {{ files }}

# write formatting fixes
[group('LOCAL')]
format:
	bun x --no-install oxfmt

# format specific files (called by the pre-commit hook)
[group('LOCAL')]
format-files *files:
	bun x --no-install oxfmt {{ files }}

# fail when a file needs formatting
[group('LOCAL')]
format-check:
	bun x --no-install oxfmt --check

# check formatting of specific files (called by the hook check)
[group('LOCAL')]
format-check-files *files:
	bun x --no-install oxfmt --check {{ files }}

# type-check the project
[group('LOCAL')]
typecheck:
	bun check

# run the tests in random order
[group('LOCAL')]
test *args:
	bun test --randomize {{ args }}

# run the checks CI runs for a pull request
[group('LOCAL')]
pre-push: lint format-check typecheck test
```

A project that runs on Node in production adds a `test-node` recipe (`node --test`) and lists it in `pre-push` next
to `test`.

## hk.pkl

The top-level `steps` are shared by `hk check`, `hk fix`, and the `pre-commit` hook. `pre-commit` fixes only the
staged files, stashes unstaged changes first, and scans the staged content for secrets. `commit-msg` rejects a commit
type outside the Conventional Commits list. `pre-push` runs the CI checks.

```pkl
amends "package://github.com/jdx/hk/releases/download/v2.13.0/hk@2.13.0#/Config.pkl"
import "package://github.com/jdx/hk/releases/download/v2.13.0/hk@2.13.0#/Builtins.pkl"

local ignored = List("**/*.sops.*", "keys/**", "**/bun.lock", "**/mise.lock", "**/dist/**", "**/node_modules/**")

steps {
	["format"] {
		glob = List("**/*.{js,mjs,cjs,ts,mts,cts,vue,json,css,md}")
		exclude = ignored
		batch = true
		check = "just format-check-files {{ files }}"
		fix = "just format-files {{ files }}"
	}
	["lint"] {
		glob = List("**/*.{js,mjs,cjs,ts,mts,cts,vue}")
		exclude = ignored
		batch = true
		check = "just lint-files {{ files }}"
	}
}

hooks {
	["pre-commit"] {
		fix = true
		stash = "git"
		steps {
			["secrets"] {
				check = "gitleaks git --pre-commit --staged --redact --no-banner"
			}
		}
	}
	["commit-msg"] {
		steps {
			["conventional"] = Builtins.check_conventional_commit
		}
	}
	["pre-push"] {
		steps {
			["checks"] {
				check = "just pre-push"
			}
		}
	}
}
```

Run `hk validate` after every edit. A step defined only inside `hooks` does not reach `hk check` and `hk fix`.

## GitHub Actions workflow

`.github/workflows/ci.yml`. The two jobs run in parallel and neither waits on the other. For a repo on Tangled, write
the workflow with the `tangled-ci` skill, call the same four recipes, and set `MISE_LOCKED=1`.

The SHAs below are examples. Resolve the current one with `git ls-remote <repo-url> refs/tags/<tag>`, and pick a
release that is older than the 3-day cooldown. `jdx/mise-action` installs in locked mode when `mise.lock` exists.

```yaml
name: CI

on:
  pull_request:
  push:
    branches: [main]
  workflow_dispatch:

concurrency:
  group: ci-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: ${{ github.ref != 'refs/heads/main' }}

permissions:
  contents: read

env:
  MISE_DISABLE_TOOLS: sops,hk,pkl,gitleaks

jobs:
  lint:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          filter: blob:none
          persist-credentials: false
          show-progress: false
      - uses: jdx/mise-action@90f833d396d0cc3674b631d2d225e306476c303a # v5.2.10
      - run: bun install --frozen-lockfile
      - run: just lint
      - run: just format-check

  test:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          filter: blob:none
          persist-credentials: false
          show-progress: false
      - uses: jdx/mise-action@90f833d396d0cc3674b631d2d225e306476c303a # v5.2.10
      - run: bun install --frozen-lockfile
      - run: just typecheck
      - run: just test
```

The checkout filter is `blob:none` without a space. `blob: none` is an invalid filter and fails the job.

## sops recipes

Add to the root `justfile` in a repo with secrets. Call it as `just _env "node src/main.ts"`. Set `SOPS_ENV_FILE` to
select another file, for example `.env.ci.sops.yaml`.

```just
DEFAULT_SOPS_FILE := '.env.sops.yaml'
SELECTED_SOPS_FILE := env('SOPS_ENV_FILE', DEFAULT_SOPS_FILE)

# run a command with the selected sops file injected as environment variables
_env *args:
	@sops exec-env --same-process {{ SELECTED_SOPS_FILE }} "{{ args }}"
```

`just/encryption.just`, imported from the root `justfile`:

```just
# open an encrypted file in the editor
[group('ENCRYPTION')]
edit-key file:
	sops edit {{ file }}

# decrypt one file next to its encrypted source
[confirm('This overwrites the decrypted file. Continue?')]
[group('ENCRYPTION')]
decrypt-key file:
	sops --output $(echo {{ file }} | sed 's/\.sops//g') --decrypt {{ file }}

# list every encrypted file in the repo
_sops-files:
	@find . -name '*.sops.*' -not -name '.sops.yaml' -not -path '*/node_modules/*' -not -path '*/.git/*' | sort

# re-encrypt all files for the recipients in .sops.yaml
[group('ENCRYPTION')]
update-keys:
	#!/usr/bin/env bash
	set -euo pipefail
	while IFS= read -r file; do
		sops updatekeys -y "$file"
	done < <(just _sops-files)

# rotate the data key of all files
[group('ENCRYPTION')]
rotate-keys:
	#!/usr/bin/env bash
	set -euo pipefail
	while IFS= read -r file; do
		sops rotate --in-place "$file"
	done < <(just _sops-files)
```
