---
name: obsidian
description: Work with an Obsidian vault using the agent's file tools (read/edit/write) and the official `obsidian` CLI. Use when the user asks to capture into their vault, find or update a note, toggle a task, set a frontmatter property, or run any Obsidian-side operation. Vault files are plain Markdown under `$OBISDIAN_VAULT_DIR` — prefer the file tools for I/O; fall back to the CLI for Obsidian-aware operations (search, tags, backlinks, tasks, move-with-link-rewriting, plugin/theme control).
license: MIT
metadata:
  author: frytg
  agent: pi
---

# Obsidian

Work with an Obsidian vault. The vault is a directory of plain Markdown files, so file tools handle most I/O; the official `obsidian` CLI covers the rest.

## 1. Requirements

- Obsidian 1.12.7+ installed (older releases don't have the CLI).
- **Settings → General → Command line interface** enabled.
- `obsidian` on `PATH`. macOS: `/usr/local/bin/obsidian` → the binary inside the app bundle. Linux: copied to `~/.local/bin/obsidian`.
- The **Obsidian app must be running** for CLI use — it talks to the app over a local socket. File tools do not require the app.

Quick check:

```bash
obsidian version
obsidian help
obsidian vaults
```

> The first two lines of stderr from every command are a banner (`Loading updated app package ...` and `Your Obsidian installer is out of date ...` on 1.12.7). Noise, not errors — parse the real output below.

## 2. The vault

`$OBISDIAN_VAULT_DIR` is the source of truth. The skill treats it as the active vault.

- **Expand tilde for non-shell tools.** The env var is typically a `~`-prefixed path. Shell expands it; programmatic consumers (Node, Python, `find -path`) do not. Resolve explicitly:
  ```bash
  VAULT="${OBISDIAN_VAULT_DIR/#\~/$HOME}"
  cd "$VAULT"
  ```
- **Path → vault name.** The `vault=<name>` argument is the **basename of the path**, not the path itself. Run `obsidian vaults` to see the registered names; use the basename of the path you want to target.
- **Multiple vaults are common.** Obsidian lets one host hold many vaults side by side, and the CLI defaults to whichever was opened last. When a CLI call could hit the wrong one, pass `vault=<name>` explicitly. With file tools there is no ambiguity — the path is the path.
- **Vault layout on disk:**
  - Notes: `*.md`.
  - Config: `.obsidian/`. **Don't edit** unless asked — it's plugin state, app settings, workspace layout, and gets silently overwritten.
  - Canvases: `*.canvas` (JSON).
  - Attachments: vault-configured folder (often `_Assets/`).
- **Frontmatter, tags, wikilinks** are just Markdown — a `tags: [foo]` line in YAML, `#tag` inline, `[[Note Name]]` square-bracket links. Treat them as text unless the CLI offers a structured command.

## 3. Tool selection

Three tools can touch the vault. Pick by intent.

**Agent file tools (`read`, `edit`, `write`) — first choice for file I/O.**

The vault is just a directory. Use your file tools directly:

- **Read a note:** open the absolute path under `$VAULT` with the read tool. No `obsidian read` round-trip.
- **Create a new note:** `write` the full file at the target path. Same outcome as `obsidian create`, no app required.
- **Edit an existing note:** `edit` with targeted `oldText`/`newText`. Atomic, diffable, undo-friendly. Replaces `obsidian append` / `prepend` / `property:set` for scalar properties.
- **Toggle a known task:** `edit` to flip `- [ ]` → `- [x]`. One targeted change, no line-number arithmetic (which `obsidian task` requires).
- **Create from a template:** `obsidian template:read` to get the body, then `write` the new file. Faster than `obsidian create ... template=`.

Advantage: works whether or not the Obsidian app is running, atomic edits, and the agent's diff/undo semantics apply.

**CLI (`obsidian ...`) — for Obsidian-aware operations.**

Use it when the operation depends on the app's index, plugins, or link graph:

- **Search and discovery:** `search`, `files`, `folders`, `tags`, `tag`, `properties`, `backlinks`, `links`, `orphans`, `deadends`, `unresolved`. These read the index — no equivalent at the file level.
- **Tasks listing:** `tasks all todo`. The only way to query tasks across the vault.
- **Daily note path:** `daily:path` to get today's path, then read/write it with file tools.
- **Structured properties** (arrays, dates, objects): `property:set` keeps YAML well-formed. Editing frontmatter directly with `edit` is fine for scalars but error-prone for arrays — `tags: [a, b]` vs `tags:\n  - a\n  - b` — and the CLI normalises.
- **Move / rename:** `move` rewrites `[[wikilinks]]` pointing at the file. A plain `mv` leaves them broken and `unresolved` lists them forever.
- **App-side state:** `eval` (JS in the app context), `command` (any Obsidian command by ID), `plugin:*`, `theme:*`, `dev:*`.

**Bash + `rg`/`sed`/`jq` — for bulk operations across many files.**

When the work is regular and the per-file edit is scripted:

- Renaming a tag across hundreds of notes.
- Migrating frontmatter schema (e.g. `status` → `Status`).
- Sweeps where you'd otherwise loop the same edit.

Pattern: discover with `rg`, preview, script the edit, re-`rg` to confirm:

```bash
VAULT="${OBISDIAN_VAULT_DIR/#\~/$HOME}"
rg -l 'TODO' "$VAULT" --glob '*.md'           # discover
rg -c 'TODO' "$VAULT" --glob '*.md' | head    # preview counts
# ... apply edits ...
rg 'TODO' "$VAULT" --glob '*.md' | wc -l      # confirm
```

Avoid the CLI for bulk — every `obsidian` call spawns a Node process and talks to the running app, which is slow at scale.

## 4. Common workflows

End-to-end recipes showing the right tool per step.

**Find a note and read it.** The CLI knows about wikilinks, aliases, and case; the file tool knows about bytes. Combine them.

```bash
# Locate the file the index knows about
obsidian search query="Recipe" format=tsv

# Then read it with the file tool at the resolved path
# (e.g. "$VAULT/Recipes/Recipe.md")
```

**Create a new note from a template.**

```bash
TEMPLATE_BODY=$(obsidian template:read name="Daily Standup")
# write the body into "$VAULT/Meetings/2026-07-13.md" with the file tool
```

**Edit a known task to done.** Don't hunt for a line number — match the text.

```
edit "$VAULT/Projects/Foo.md"  oldText="- [ ] review PR"  newText="- [x] review PR"
```

**Set a frontmatter property (scalar).** Edit the YAML in place.

```
edit "$VAULT/Projects/Foo.md"  oldText="status: active"  newText="status: done"
```

**Set a structured property (array).** Use the CLI — it normalises YAML.

```bash
obsidian property:set file=Foo name=tags value="[work, urgent]"
```

**Append to the daily note.**

```bash
DAILY=$(obsidian daily:path)                  # → "2026-07-13.md"
edit "$VAULT/$DAILY"  oldText="...last line"  newText="...last line\n\n- [ ] Review inbox"
```

**Search for tasks across the vault.** Only the CLI can do this.

```bash
obsidian tasks all todo format=tsv
```

**Find broken wikilinks.**

```bash
obsidian unresolved verbose counts
```

**Move a file and rewrite its wikilinks.** CLI required — file ops don't know about the link graph.

```bash
obsidian move path="Inbox/Old.md" to="Projects/New.md"
```

**Bulk-rename a tag across the vault.** Bash + `rg` for the discovery and confirmation loop, file tool for the edits.

```bash
VAULT="${OBISDIAN_VAULT_DIR/#\~/$HOME}"
rg -l '#old-tag' "$VAULT" --glob '*.md'       # discover
# for each file: edit "#old-tag" → "#new-tag" with the file tool
rg '#old-tag' "$VAULT" --glob '*.md' | wc -l  # confirm zero
```

## 5. CLI reference

`obsidian <command> [name=value] [flag]`. `key=value` pairs; quote values with spaces. `--copy` copies output to the clipboard. `format=json|tsv|csv|text` is offered by list-style commands.

`file=<name>` resolves like a wikilink (case-insensitive, basename). `path=<vault-relative.md>` is exact. Both are relative to the active vault unless `vault=` is set.

### Discovery

```bash
obsidian search query="TODO" matches
obsidian search query="status::active" format=json
obsidian search query="meeting" path="Projects" limit=20 format=tsv
obsidian search:open query="project notes"     # open results in the app
obsidian files path="Inbox"
obsidian folders
obsidian tags all counts
obsidian tag name=project
obsidian orphans                                # no incoming links
obsidian deadends                               # no outgoing links
obsidian unresolved verbose counts              # broken wikilinks
obsidian properties                             # all property keys
obsidian backlinks file=Recipe                  # what links here
obsidian links file=Recipe                      # what this links to
```

### Read

Prefer the agent's file tool for reading — the CLI works but adds a round-trip.

```bash
obsidian read                                  # active file
obsidian read file=Recipe
obsidian read path="Daily/2026-07-13.md"
obsidian file=Recipe                            # metadata (size, mtime, links)
obsidian outline file=Recipe                    # headings
obsidian wordcount file=Recipe
obsidian open file=Recipe                       # open in app
obsidian open path="Inbox/Idea.md" newtab
```

### Write

Prefer the agent's file tool — `write` to create, `edit` to modify. The CLI is a fallback.

```bash
obsidian create name="New Note"
obsidian create path="Inbox/Idea.md" content="# Idea"
obsidian create name="Meeting" template="Daily Standup"
obsidian append file=Note content="New line"
obsidian prepend file=Note content="After frontmatter"
obsidian template:read name="Daily Standup"
obsidian template:insert name="Daily Standup"
```

### Move and delete

CLI only — `move` rewrites wikilinks; `delete` confirms.

```bash
obsidian move file=Note to=Archive/
obsidian move path="Inbox/Old.md" to="Projects/New.md"
obsidian delete file=Note
```

`delete` does not move to trash; the file is gone. Confirm the path first (`obsidian file=Note`).

### Daily notes

```bash
obsidian daily                                   # open today's
obsidian daily:path                              # print path
obsidian daily:read                              # print contents
obsidian daily:append content="- [ ] Review inbox"
obsidian daily:prepend content="## Morning"
```

For non-trivial edits, use `daily:path` to get the path and edit the file with the file tool.

### Tasks

The CLI is the only way to **list** tasks across the vault. For a **known** task, the file tool is faster (match the text, toggle the checkbox).

```bash
obsidian tasks all todo
obsidian tasks all done
obsidian tasks file=Note todo
obsidian task file=Note line=8 done
obsidian task file=Note line=8 todo
```

### Properties

Use `edit` for scalar values. Use the CLI for arrays/objects/dates — it normalises YAML.

```bash
obsidian property:read name=status file=Note
obsidian property:set file=Note name=status value=done
obsidian property:set file=Note name=tags value="[work, urgent]"
obsidian property:remove file=Note name=status
```

### Tags, links, history

```bash
obsidian tag name=project
obsidian aliases file=Note
obsidian history:list
obsidian history file=Note
obsidian history:read file=Note version=2
obsidian history:restore file=Note version=2
```

### Bases (structured data)

```bash
obsidian bases
obsidian base:views file="Projects.base"
obsidian base:query file="Projects.base" view="Active" format=json
obsidian base:create file="Projects.base" view="Active" ...
```

### Plugins, themes, app-side

```bash
obsidian plugins
obsidian plugins:enabled
obsidian plugin:enable id=dataview
obsidian plugin:disable id=dataview
obsidian plugin:reload id=my-plugin
obsidian themes
obsidian theme:set name="Things"
obsidian eval code="app.vault.getFiles().length"
obsidian command id="workspace:toggle-folders"
obsidian dev:errors
obsidian dev:console
obsidian dev:screenshot file=shot.png
```

## 6. Safety

- **Never `delete` without explicit ask.** The CLI does not move to trash. Recover via `history:restore` only if file history was on.
- **Prefer `obsidian move` over `mv`.** The CLI rewrites `[[wikilinks]]`; `mv` leaves them broken and `unresolved` will list them forever.
- **Don't edit `.obsidian/`** unless the user asks. Plugin state, workspace layout, and app settings live there — manual edits are silently overwritten.
- **CLI requires the app to be running.** If commands hang or return empty results, check that Obsidian is open with the vault loaded. File tools do not have this constraint.
- **Multiple vaults = silent wrong-target risk for the CLI.** When in doubt, pass `vault=<name>` explicitly, or use file tools with absolute paths.
- **Templating and metadata plugins may rewrite on save.** A direct edit can be touched up by a plugin (Linter, Templater) when the file next opens. If formatting matters, edit via the file tool and let the app do its pass on next save.
- **No third-party `obsidian-cli`** (the Homebrew tap, the npm package). They diverge from the official command set and will not match the patterns in this skill.
