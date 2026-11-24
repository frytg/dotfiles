---
description: Commit the staged changes with a Conventional Commits message
argument-hint: '[extra instructions]'
---

Commit the currently staged changes. The user ran this command, so this is an explicit request to commit. Treat any text after the command as extra instructions (for example a type, a scope, or "also stage X").

1. **Read what is staged.** Run `git diff --staged --stat` and `git diff --staged`. If nothing is staged, show `git status --short` and stop. Do not stage files unless the extra instructions say so.
2. **Match the repo's style.** Read `git log --oneline -15` and follow its conventions for scopes, casing, and language. Default to Conventional Commits: `<type>(<scope>): <description>` with the types `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`, `build`, `ci`, `revert`.
3. **Check scope and safety.** If the staged diff mixes unrelated changes, propose a split instead of one commit. If it contains likely secrets (API keys, tokens, `.env` files, PEM blocks), stop and warn.
4. **Write the message.** Subject in the imperative mood, at most 72 characters, no trailing period. Add a body only when the reason for the change is not clear from the diff, wrapped at 72 characters. Mark breaking changes with `!` after the type and a `BREAKING CHANGE:` footer.
5. **Confirm, then commit.** Show the message and wait for a yes, unless the extra instructions say to skip confirmation. Then commit with `git commit -F -` and a heredoc so multi-line messages survive. Never use `--no-verify` or `--amend`, and never push. If a hook fails, show its output and stop.
6. **Report** the short hash and the subject.
