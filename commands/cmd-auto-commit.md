---
description: Group all uncommitted changes into logical commits and commit them without asking
argument-hint: '[extra instructions]'
---

Commit every uncommitted change in the repo as one or more logical commits. The user ran this command, so this is an explicit request to commit without asking for confirmation. Never push. Treat any text after the command as extra instructions (for example "one commit only", a scope, or paths to leave out).

1. **Check the repo state.** If a merge, rebase, cherry-pick, or revert is in progress, stop. Read `git status --short --untracked-files=all`, `git diff`, `git diff --staged`, and the content of untracked files. If there is nothing to commit, say so and stop.
2. **Check for secrets.** Leave out any file that looks like it holds a secret (`.env*`, keys, tokens, PEM blocks, unencrypted credentials), and anything that should be in `.gitignore` (build output, logs, caches). List what you left out and why.
3. **Match the repo's style.** Read `git log --oneline -15` and follow its conventions for scopes, casing, and language. Default to Conventional Commits: `<type>(<scope>): <description>` with the types `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`, `build`, `ci`, `revert`.
4. **Group the changes.** Put each file in exactly one group, one group per logical change. Docs and config that belong to a feature go with that feature. Unrelated edits get their own group. If one file mixes unrelated changes, put it in the group it fits best and mention that in the report. Order the groups so each commit makes sense on its own, for example a dependency or helper before the feature that uses it.
5. **Commit each group.** Run `git add -A -- <paths>`, then `git commit -F - -- <paths>` with the message in a heredoc. The pathspec on `git commit` keeps other staged files out of that commit. Write the subject in the imperative mood, at most 72 characters, with no trailing period. Add a body only when the reason for the change is not clear from the diff. Never use `--no-verify` or `--amend`.
6. **Stop on failure.** If a hook or commit fails, show its output and stop. Don't retry and don't bypass the hook.
7. **Report** each commit as short hash and subject, then anything you left uncommitted.
