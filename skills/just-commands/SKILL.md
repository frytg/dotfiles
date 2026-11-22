---
name: just-commands
description: >-
  Write and edit `justfile` task recipes for the `just` command runner, following house conventions: a private
  `_default` listing recipe first, exactly one doc-comment line above every recipe, every public recipe in a
  `[group()]`, and larger task sets split into `just/*.just` files imported from the root `justfile`. Covers recipe
  syntax, parameters, dependencies, variables, settings, shebang recipes, imports, and modules, with links to the full
  manual. Use when the user asks to "add a just recipe", "add a just command", "create a justfile", "split the
  justfile", "move tasks to just", or edits any `justfile` / `*.just` file. Not for which recipes a repo must have
  (`install`, `update`, `lint`, `test`, hooks); use repo-standard.
license: MIT
metadata:
  author: frytg
  agent: claude
  category: engineering
---

# just

A good justfile is a self-documenting task menu. Running bare `just` prints every public recipe, sorted into groups,
each with a one-line description. Nobody has to open the file to find the right command.

Full docs: [manual](https://just.systems/man/en/) and [GitHub README](https://github.com/casey/just).

## When to use

- Adding, renaming, or editing a recipe in a `justfile` or `just/*.just` file.
- Creating a `justfile` for a new repo.
- Moving ad-hoc scripts or `package.json` `scripts` into just recipes.
- Splitting a long `justfile` into imported sub-files.

## Not for

- Deciding which recipes a repo must have. The standard names (`install`, `update`, `lint`, `format`, `format-check`,
  `typecheck`, `test`, `hooks-install`, `pre-push`) and their bodies live in `repo-standard`. This skill covers how to
  write them.

## House rules

1. **`_default` comes first.** `just` runs the first recipe when called without arguments. Make it a listing job so
   bare `just` prints the menu. The `_` prefix hides it from the list. `@` stops just from echoing the command.

   ```just
   _default:
   	@just --list
   ```

2. **One comment line directly above every recipe.** `just --list` shows only the comment line right above the recipe
   (attributes may sit between). Keep it a brief, lowercase one-liner that says what the recipe does. A blank line
   between comment and recipe drops the description. Put longer explanations in `docs/` and link them from that line.
3. **Every public recipe has a group.** Use `[group('NAME')]` with upper-case names, for example `LOCAL`, `DEV`,
   `K8S`, `LINT`, `TEST`, `BUILD`, `DB`. Ungrouped recipes float to the top of `--list`, which breaks the menu.
   Private helpers (`_name` or `[private]`) are hidden from the list and need no group.
4. **Split by topic into `just/*.just`.** Keep the root `justfile` short: imports, shared settings and variables, then
   `_default`. Add a trailing comment on each `import` line so the root file doubles as a table of contents.
5. **Indent with tabs**, consistently within a recipe. just rejects mixed indentation.

## Layout

```text
justfile          # imports, settings, shared variables, _default
just/
  local.just      # [group('LOCAL')] recipes
  k8s.just        # [group('K8S')] recipes
  lint.just       # [group('LINT')] recipes
```

Root `justfile`:

```just
import 'just/local.just' # run the app and its services on this machine
import 'just/k8s.just' # deploy and inspect the cluster
import 'just/lint.just' # lint and format checks

set dotenv-load

_default:
	@just --list
```

Sub-file `just/k8s.just`:

```just
# apply the manifests to a kube context (default: staging)
[group('K8S')]
k8s-apply context='staging' *flags:
	kubectl --context {{ context }} apply -k k8s/ {{ flags }}

# tail logs of the api deployment
[group('K8S')]
k8s-logs context='staging':
	kubectl --context {{ context }} logs -f deploy/acme-api
```

Output of bare `just`:

```text
Available recipes:
    [K8S]
    k8s-apply context='staging' *flags # apply the manifests to a kube context (default: staging)
    k8s-logs context='staging'         # tail logs of the api deployment

    [LINT]
    ...
```

Recipes from an `import` share one namespace with the root file, so prefix names with the topic (`k8s-apply`, not
`apply`) to avoid collisions. Use `import? 'just/local.just'` for an optional file that may not exist on every
machine.

## Imports vs modules

- `import 'just/k8s.just'` merges recipes into the root namespace. Call them as `just k8s-apply`. Default choice.
- `mod k8s 'just/k8s.just'` creates a submodule with its own namespace. Call it as `just k8s apply` or
  `just k8s::apply`. Bare `just` shows it as `k8s ...`; list its recipes with `just --list k8s`. Use a module only
  when a topic has many recipes or needs its own settings, because the recipes no longer appear in the main menu.

Docs: [imports](https://just.systems/man/en/imports.html), [modules](https://just.systems/man/en/modules.html).

## Syntax quick reference

```just
# variables: plain, from env with fallback, from a command
version := '1.2.0'
env_file := env('ENV_FILE', '.env')
git_sha := `git rev-parse --short HEAD`

# load .env into recipe environments
set dotenv-load

# build the container image tagged with the git sha
[group('BUILD')]
build tag=git_sha:
	container build -t acme/api:{{ tag }} .

# run tests, then lint (dependencies run first, once each)
[group('TEST')]
check: test lint

# pass any extra args through (* = zero or more, + = one or more)
[group('DEV')]
run *args:
	node src/main.ts {{ args }}

# multi-line script in one shell (shebang recipe)
[group('DEV')]
setup:
	#!/usr/bin/env zsh
	set -e
	if ! command -v mise >/dev/null; then
		echo 'error: mise missing' >&2
		exit 1
	fi
	mise install

# helper: hidden from --list, no group needed
_ensure-env:
	@test -f {{ env_file }} || (echo 'missing {{ env_file }}' >&2; exit 1)

# ask before running, macOS only
[group('LOCAL')]
[confirm('Wipe local data?')]
[macos]
reset-local:
	-rm -rf .data   # leading - ignores a failing line
	@echo done      # leading @ hides the echoed command
```

Each line in a normal recipe runs in a fresh shell, so `cd` and variables do not carry over. Use a shebang recipe
when lines depend on each other.

Top-level backtick variables run on every `just` call, `just --list` included. A failing backtick breaks the whole
menu, so keep them cheap and safe, or move the command into the recipe body.

## Useful commands

- `just` — run `_default`, prints the menu.
- `just --list` / `just -l` — list recipes with descriptions.
- `just --groups` — list group names.
- `just --list k8s` — list recipes of module `k8s`.
- `just --show <recipe>` — print a recipe's source.
- `just --dry-run <recipe>` / `just -n` — print commands without running them.
- `just --evaluate` — print all variable values.
- `just --summary` — names only, for scripting.

## Docs

- [Quick start](https://just.systems/man/en/quick-start.html)
- [Listing recipes](https://just.systems/man/en/listing-available-recipes.html)
- [Documentation comments](https://just.systems/man/en/documentation-comments.html)
- [Groups](https://just.systems/man/en/groups.html)
- [Attributes](https://just.systems/man/en/attributes.html)
- [Recipe parameters](https://just.systems/man/en/recipe-parameters.html)
- [Dependencies](https://just.systems/man/en/dependencies.html)
- [Settings](https://just.systems/man/en/settings.html)
- [Shebang recipes](https://just.systems/man/en/shebang-recipes.html)
- [Private recipes](https://just.systems/man/en/private-recipes.html)

## Checklist

- `_default` with `@just --list` is the first recipe in the root `justfile`.
- Every recipe has exactly one comment line directly above it (attributes in between are fine).
- Every public recipe has a `[group('NAME')]`; private helpers start with `_`.
- Topic files live in `just/*.just`, imported from the root with a trailing comment.
- Imported recipe names carry a topic prefix.
- Run bare `just` and check the menu reads cleanly before finishing.
