---
description: Bump the version and turn the Unreleased changelog notes into a release section
argument-hint: '[major|minor|patch|x.y.z]'
---

Bump the project version. Treat any text after the command as the bump level (`major`, `minor`, `patch`) or as an exact version.

1. **Check the working tree.** Uncommitted changes to changelog files are fine, because `/cmd-changelog` leaves them. If anything else is uncommitted, stop and ask.
2. **Find the version sources.** Start with `package.json`, then check other manifests that carry the same version and must stay in sync (`jsr.json`, `deno.json`, `Cargo.toml`, `pyproject.toml`, plugin manifests). In a monorepo, bump only the packages that the branch touches. Leave lockfiles alone.
3. **Pick the level.** An explicit level or version after the command wins. Otherwise, read the commits since the last `v*` tag (or since the base branch if there is no tag): a breaking change (`!` or `BREAKING CHANGE:`) means major, any `feat` means minor, and everything else means patch. Apply strict semver on `0.x` too. Say which commits decided the level.
4. **Update the manifests.** Write the new version into every source from step 2.
5. **Promote the changelog.** If a changelog exists, rename `## Unreleased` to `## [x.y.z] - YYYY-MM-DD` with today's date and add a new, empty `## Unreleased` above it if the file uses one. Update compare links at the bottom of the file if it has them. If `## Unreleased` is missing or empty, stop and suggest running `/cmd-changelog` first.
6. **Stop before committing.** Do not commit, tag, or push. Report the old and new version and the list of changed files.
