---
name: changelog
description: Bumps the project version based on conventional commits on the current branch, writes a new entry to CHANGELOG.md following Keep a Changelog 1.1.0, and updates package.json#version. Use when the user asks to cut a release, prepare a version bump, or refresh the changelog.
license: MIT
metadata:
  author: frytg
  agent: pi
---

# Changelog

Bump the project version based on the conventional commits on the current branch and write a corresponding entry to `CHANGELOG.md`. Updates `package.json#version` to match.

## 1. Establish context

- **Working tree must be clean.** If `git status --porcelain` is non-empty, stop and report. The only changes this skill makes are the version bump and changelog entry — anything else should be committed first.
- **Identify the base branch.** Try in order: `main`, `master`, then `git symbolic-ref refs/remotes/origin/HEAD`. Strip `origin/` from the result. The base branch is the comparison point, not the merge target.
- **Confirm there are commits ahead of base.** `git log <base>..HEAD --oneline | wc -l` must be `> 0`. If zero, stop with "no commits ahead of `<base>` — nothing to release."
- **Read `package.json#version`.** If the file is missing, stop. If the field is missing, treat the current version as `0.0.0` and warn the user that this is a fresh project.
- **Skip if already up-to-date.** If a tag matching `v<version>` (e.g. `v1.4.2`) already exists at HEAD, stop with "version `<version>` already tagged at HEAD — nothing to do."

## 2. Gather commits

Collect commit subjects and bodies for everything on the branch since base:

```bash
git log <base>..HEAD --pretty=format:'%H%x1f%s%x1f%b%x1e'
```

Use a non-printable delimiter (`%x1f` = US, `%x1e` = RS) so commit subjects and bodies can be parsed reliably even when they contain colons, parens, or newlines.

## 3. Classify commits

For each commit, extract the conventional-commit **type** and **breaking flag**:

- **Type** — the first token of the subject before the first `(`, `!`, or `:`. Examples: `feat`, `fix`, `chore`, `docs`, `refactor`, `perf`, `style`, `test`, `build`, `ci`, `revert`.
- **Breaking flag** — `true` if either:
  - The subject ends in `!` before the colon (e.g. `feat(api)!: ...`), or
  - The body (or footer lines) contains `BREAKING CHANGE:` / `BREAKING-CHANGE:`.

Map to a semver bump level. Take the **highest** level across all commits:

- **major** — breaking flag set.
- **minor** — type is `feat`.
- **patch** — type is `fix`, `perf`, `refactor`, `revert`, `style`, `docs`, `test`, `chore`, `build`, or `ci`.
- **patch (warn in the report)** — no recognised type.

`major > minor > patch`. A single `BREAKING CHANGE` always wins over a `feat:`.

## 4. Compute the new version

Apply semver rules to the current version:

- **major** — bump major, reset minor and patch to 0 (e.g. `1.4.2` → `2.0.0`).
- **minor** — bump minor, reset patch to 0 (e.g. `1.4.2` → `1.5.0`).
- **patch** — bump patch (e.g. `1.4.2` → `1.4.3`).

For pre-`1.0.0` versions, standard semver still applies. Note in the report that some teams choose to treat breaking changes as minor on `0.x.y`; default to the strict rule and let the user override.

## 5. Categorise commits for the changelog

Group the commits into Keep a Changelog sections. Drop non-user-facing types unless they are breaking.

- **Added** — `feat`.
- **Changed** — `refactor`, `style`, `perf`, `revert`.
- **Fixed** — `fix`.
- **Removed** — only when a commit body explicitly contains `Removed:` (case-sensitive) followed by a one-line description. A `feat!:` or `fix!:` is breaking but is not necessarily a removal — leave the breaking flag in the relevant section.
- **Security** — `fix` commits whose body mentions `CVE-` or `security`.
- _(omit)_ — `docs`, `test`, `chore`, `build`, `ci`.

If a commit is breaking, add a `**BREAKING:**` line in the relevant section summarising the change. If nothing maps to a given section, omit the heading entirely.

Format each entry as: `- <description> ([<short-sha>](<commit-url>))`. Strip the conventional-commit prefix from the description — the section heading already conveys the type. Build the commit URL from `git remote get-url origin` (strip `.git`, prepend `https://`, prefix the path with `/commit/`).

## 6. Write `CHANGELOG.md`

Follow [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/):

- If `CHANGELOG.md` does not exist, create it with the standard header and an `## [Unreleased]` section above the new entry.
- If it exists, leave the existing `## [Unreleased]` section in place and prepend the new version section above it. New entries go at the top of the version list.

Template for the new section:

```markdown
## [<new-version>] - <YYYY-MM-DD>

### Added

- <description> ([<short-sha>](commit-url))

### Changed

- **BREAKING:** <description> ([<short-sha>](commit-url))

### Fixed

- <description> ([<short-sha>](commit-url))
```

Use today's date in `YYYY-MM-DD` (local time). The date is the release date, not the commit date.

## 7. Update `package.json`

- Read `package.json` and update the top-level `version` field to the new version.
- Preserve all other fields, formatting, key order, and existing indentation (tabs vs spaces, 2 vs 4). Use a targeted edit, not a rewrite.
- If the file is missing, stop — this skill does not create `package.json`.

## 8. Report and stop

Print a summary, then stop. Do not stage, commit, tag, or push.

```
Current branch: <branch>
Base branch:    <base>
Commits ahead:  <n>

Bump:   <major|minor|patch>
Reason: <one-line summary, e.g. "1 feat, 2 fix, 1 BREAKING CHANGE">
Old:    <old-version>
New:    <new-version>

Files changed:
  M package.json
  M CHANGELOG.md
```

End with: "Run `git diff` to review. Stage and commit when you're ready."

## Safety

- **Never commit, tag, push, or merge.** This skill edits files only.
- **Never edit a working tree with uncommitted changes** — stop and tell the user to commit or stash first.
- **Never invent commit descriptions.** If a commit body is empty, fall back to the subject (with the conventional-commit prefix stripped). Never paraphrase beyond that.
- **Never rewrite history.** The skill reads `git log`; it does not run `git rebase`, `reset`, or `commit --amend`.
- **Single-package only.** Monorepos with multiple `package.json` files are out of scope — stop and tell the user to run the skill per package.
- **No `npm`/`bun`/`nub` version commands.** Edit `package.json` directly so the bump works the same regardless of package manager.
