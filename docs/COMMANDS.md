# Commands

Short slash-command prompts shared by Claude Code, Cursor (IDE and CLI), and Droid. `just link` ([`bin/link.sh`](../bin/link.sh)) symlinks [`commands/`](../commands/) into each harness, so every `<name>.md` there runs as `/<name>`. Keep only command files in that folder, because each harness turns every `.md` file in it into a command.

Use a command for a short prompt that you start by hand. Use a [skill](../skills/README.md) when the agent should pick the task up on its own, or when the task needs reference material or more than one file.

## Writing a command

- The file name is the command name. Start it with `cmd-` so it doesn't collide with skills or built-in commands.
- Use only `description` and `argument-hint` in the frontmatter. Cursor reads the file as plain text, so other keys do nothing there.
- Don't use `$ARGUMENTS`, `$1`, `` !`shell` ``, or `@file`, because Cursor doesn't expand them. Write "treat any text after the command as ..." instead, and name the shell commands the agent should run.
- Don't restate the global rules from [`.agents/AGENTS.md`](../.agents/AGENTS.md); every harness already loads them.
