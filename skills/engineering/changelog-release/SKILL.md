---
name: changelog-release
description: >-
  Promotes curated ## Unreleased changelog bullets into dated version sections
  and bumps package.json versions for every package a branch actually ships.
  Use in monorepos when the user asks to prepare all required changelogs for
  release, bump version numbers, or cut a multi-package release. For a
  single-package repo, use the changelog skill instead.
license: MIT
metadata:
  author: frytg
  agent: cursor
---

# Changelog release (monorepo)

Cut a release from **already-written Unreleased notes**, not from a fresh git-log rewrite. Only packages the branch ships. Edit files; do not commit, tag, or push.

## 1. Context

- **Working tree should be clean.** If it is dirty, stop and ask to commit or stash first — this skill only writes version + changelog (+ a public changelog UI if the package asks for one).
- **Base branch:** `main`, then `master`, then `git symbolic-ref refs/remotes/origin/HEAD` (strip `origin/`).
- **Commits ahead:** `git log <base>..HEAD --oneline`. If zero, stop: nothing to release.
- **Files on the branch:** `git diff --name-only <base>...HEAD`.

## 2. Which packages to release

A package is in scope when **both** are true:

1. The branch touches it (`packages/<name>/…`, or `infra/` for the infra changelog).
2. Its **first** `## Unreleased` section has at least one bullet.

Skip:

- Packages the branch did not touch, even if they have leftover Unreleased notes.
- Empty Unreleased sections.
- A **second** `## Unreleased` later in the same file (stale leftover — leave it).
- Deploy/image tag files (`kubernetes/_env/*.json` and similar). CI rewrites those on build.

`infra/CHANGELOG.md` has no `package.json` and **does not use version numbers**. Headings are ISO dates only (`## YYYY-MM-DD`). If `infra/` is in the diff and Unreleased has bullets, promote to `## YYYY-MM-DD` (today). Never invent a `vX.Y.Z` for infra.

## 3. Bump level (per package)

Read `packages/<name>/package.json` `#version`. Infer the bump from that package’s Unreleased bullets **and** commits that touch it (`feat` / `fix` / `refactor` / `BREAKING CHANGE` / `type!:`). Highest wins:

- **major** — breaking (`!` before `:` or `BREAKING CHANGE:` in a commit body).
- **minor** — `feat`.
- **patch** — `fix`, `refactor` / `refact`, `perf`, `revert`, and other conventional types.

Apply semver to that package’s current version (major resets minor+patch; minor resets patch). Pre-1.0.0 still uses strict semver; mention that in the report.

Do **not** run `npm version` / `bun pm pkg` / `nub` version commands. Edit `version` in place; keep indentation and key order.

## 4. Write the changelog

Promote the first Unreleased block **as written**. Do not replace curated bullets with raw commit subjects. Do not invent bullets. Do not append SHAs or compare URLs.

Match **that file’s** heading and list style:

- App packages: `## YYYY-MM-DD - v<new-version>`.
- Keep-a-Changelog subsections (`### Added` / `### Changed` / `### Fixed`) when the Unreleased block already uses them.
- Flat `- feat:` / `- fix:` / `- refact:` lists when the file already uses those.
- **`infra/CHANGELOG.md`:** `## YYYY-MM-DD` only — no `vX.Y.Z`, no package bump. Same date as the rest of the release. If that date heading already exists, append the new bullets under it rather than duplicating the heading.

Date is **today** (local), the release date.

Leave an empty Unreleased section on top:

```markdown
## Unreleased

## YYYY-MM-DD - vX.Y.Z

- existing bullet
```

If the changelog header points at a **public** changelog UI (e.g. a Vue module), add one short user-facing line for the new version at the top of that list. Tone and language must match the existing entries (do not paste engineering bullets into the public list).

## 5. Report and stop

```
Current branch: <branch>
Base branch:    <base>
Commits ahead:  <n>

| Package | Bump | Old | New |
|---|---|---|---|
| <name> | minor | x.y.z | x.y+1.0 |
| infra | — | — | ## YYYY-MM-DD |

Skipped: <names and why>
```

End with: "Run `git diff` to review. Stage and commit when you're ready."

## Safety

- Never commit, tag, push, merge, or rewrite history.
- Never edit deploy/image tags by hand.
- Never bump a package the branch did not ship.
- Never invent a version number for `infra/CHANGELOG.md` — date headings only.
- Never fold a stale second Unreleased section into the new version.
- Never paraphrase Unreleased bullets into new wording; move them.
