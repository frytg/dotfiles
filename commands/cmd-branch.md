---
description: Create a new git branch and switch to it
argument-hint: '<what the branch is for, or an exact name>'
---

Create a new git branch and switch to it. Treat any text after the command as the purpose of the branch, or as the exact name if it already looks like a branch name.

1. **Pick the name.** Use `<type>/<slug>`: the type is a Conventional Commits type (`feat`, `fix`, `docs`, `refactor`, `chore`, ...), and the slug is 2 to 5 lowercase ASCII words joined with `-`. Keep a ticket ID only if the user gave one. If no text was given, derive the purpose from `git status` and `git diff`. If those are empty too, ask.
2. **Pick the base.** Branch from the current `HEAD` unless the user names a base. Uncommitted changes carry over to the new branch, which is usually what the user wants.
3. **Avoid collisions.** Check `git branch --all --list '*<name>'`. If the name exists, propose a different one instead of overwriting.
4. **Create it.** Run `git switch -c <name> [<base>]`. Do not stash, reset, push, or set an upstream.
5. **Report** the branch name, the base commit, and whether uncommitted changes came along.
