---
description: Write the branch's changes into CHANGELOG.md under Unreleased
argument-hint: '[extra instructions]'
---

Write changelog notes for the changes on this branch into the `## Unreleased` section. Do not change any version number, because `/cmd-bump-version` does that. Treat any text after the command as extra instructions.

1. **Collect the changes.** Find the base branch: `main`, then `master`, then `git symbolic-ref refs/remotes/origin/HEAD` with `origin/` removed. Read `git log <base>..HEAD --pretty=format:'%s%n%b'` and `git diff --stat <base>...HEAD`. If there are no commits ahead of the base, stop. Include uncommitted changes only if the user asks.
2. **Find the changelog.** Use `CHANGELOG.md` at the repo root. In a monorepo, use the changelog of each package that the branch touches (`git diff --name-only <base>...HEAD`). If no changelog exists, ask before you create one in [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/) format.
3. **Write user-facing bullets.** Group them under the Keep a Changelog headings `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`, `Security`. Describe the effect for the user, not the commit subject word for word. Skip `chore`, `ci`, `test`, `style`, and `docs` commits unless users can see the change. Start breaking changes with `**BREAKING:**`.
4. **Merge, don't duplicate.** If `## Unreleased` exists, add to it and skip changes that are already listed. If it doesn't exist, create it above the newest version section. Keep the file's existing style.
5. **Stop before committing.** Show the changelog diff. Do not commit.
