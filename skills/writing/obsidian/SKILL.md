---
name: obsidian
description: Work with an Obsidian vault using the agent's file tools and the official `obsidian` CLI. Use when the user asks to capture into their vault, find or update a note, set a frontmatter property, or run any Obsidian-side operation.
license: MIT
metadata:
  author: frytg
  agent: pi
---

# Obsidian

Work with an Obsidian vault. The vault is a directory of plain Markdown files, so file tools handle most I/O; the official `obsidian` CLI covers the rest.

## Requirements

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

## The vault

Resolve the active vault's path with the CLI — it's the source of truth for file tools:

```bash
VAULT=$(obsidian vault info=path)
```

Use `$VAULT` for absolute paths to read/edit/write. The CLI requires the app to be running.

- **Check `<vault>/AGENTS.md` first.** Vaults may carry a root-level `AGENTS.md` (or similarly named conventions file) with vault-specific guidance — folder structure, naming conventions, frontmatter rules, what's off-limits. Read it before assuming defaults; treat it as a higher-priority overlay on the rules below.
- **Multiple vaults.** Run `obsidian vaults` to see registered names. The `vault=<name>` flag on any CLI command targets a specific vault by name. For a non-active vault's path: `obsidian vault info=path vault=<name>`. With file tools there is no ambiguity — the path is the path.
- **Vault info fields.** `obsidian vault` prints the full info (name, path, file count, folder count, size). Use `info=<field>` to pull a single one — `path`, `name`, `files`, `folders`, `size`.
- **Vault layout on disk:**
  - Notes: `*.md`.
  - Config: `.obsidian/`. **Don't edit** unless asked — it's plugin state, app settings, workspace layout, and gets silently overwritten.
  - Canvases: `*.canvas` (JSON).
  - Attachments: vault-configured folder (often `_Assets/`).
- **Filenames may include emoji and other non-ASCII characters.** Quote paths in shell and don't split on whitespace; modern tools (`rg`, `find`, the file tools) handle UTF-8 by default.
- **Frontmatter, tags, wikilinks** are just Markdown — a `tags: [foo]` line in YAML, `#tag` inline, `[[Note Name]]` square-bracket links. Treat them as text unless the CLI offers a structured command.

## Tool selection

Three tools can touch the vault. Pick by intent.

**Agent file tools (`read`, `edit`, `write`) — first choice for file I/O.**

The vault is just a directory. Use your file tools directly:

- **Read a note:** open the absolute path under `$VAULT` with the read tool. No `obsidian read` round-trip.
- **Create a new note:** `write` the full file at the target path. Same outcome as `obsidian create`, no app required.
- **Edit an existing note:** `edit` with targeted `oldText`/`newText`. Atomic, diffable, undo-friendly. Replaces `obsidian append` / `prepend` / `property:set` for scalar properties.
- **Create from a template:** `obsidian template:read` to get the body, then `write` the new file. Faster than `obsidian create ... template=`.

Advantage: works whether or not the Obsidian app is running, atomic edits, and the agent's diff/undo semantics apply.

**CLI (`obsidian ...`) — for Obsidian-aware operations.**

Use it when the operation depends on the app's index, plugins, or link graph:

- **Search and discovery:** `search`, `files`, `folders`, `tags`, `tag`, `properties`, `backlinks`, `links`, `orphans`, `deadends`, `unresolved`. These read the index — no equivalent at the file level.
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
VAULT=$(obsidian vault info=path)
rg -l 'TODO' "$VAULT" --glob '*.md'           # discover
rg -c 'TODO' "$VAULT" --glob '*.md' | head    # preview counts
# ... apply edits ...
rg 'TODO' "$VAULT" --glob '*.md' | wc -l      # confirm
```

Avoid the CLI for bulk — every `obsidian` call spawns a Node process and talks to the running app, which is slow at scale.

## Common workflows

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

edit "$VAULT/$DAILY" oldText="...last line" newText="...last line\n\n## Reflection"

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
edit "$VAULT/$DAILY"  oldText="...last line"  newText="...last line\n\n## Reflection"
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
VAULT=$(obsidian vault info=path)
rg -l '#old-tag' "$VAULT" --glob '*.md'       # discover
# for each file: edit "#old-tag" → "#new-tag" with the file tool
rg '#old-tag' "$VAULT" --glob '*.md' | wc -l  # confirm zero
```

## Note syntax

Obsidian extends CommonMark. A handful of patterns come up constantly when writing notes — get these right and the rest behaves like standard Markdown. The agent edits notes as plain text, so knowing the syntax is what separates a clean edit from one that renders as raw backticks.

### Wikilinks

The headline feature. No paths — the vault resolves by name, case-insensitive, and rewrites links on rename.

```markdown
[[Recipe]] basic link
[[Recipe|Lasagna]] alias display text
[[Recipe#Ingredients]] link to a heading
[[Recipe#^step-3]] link to a block
[[#Method]] same-note heading link
```

Block IDs are the one bit of new syntax: append `^block-id` to a paragraph to make it linkable. For lists and quotes, put the ID on its own line directly after the block.

### Callouts

Sidebar callouts for asides, warnings, and tips. The type is one of Obsidian's built-in keywords; the title is optional; a trailing `-` or `+` folds the body (`-` = collapsed by default, `+` = expanded by default, no marker = always open).

```markdown
> [!note]
> Inline aside.

> [!warning] Watch out
> Title comes before the body.

> [!tip]-
> Hidden until clicked.
```

Built-in types: `note`, `tip`, `info`, `warning`, `danger`, `example`, `quote`, `question`, `success`, `failure`, `bug`, `abstract`, `todo`. Custom types render as `note` unless a CSS class is registered for them.

### Properties (frontmatter)

YAML block at the top of the file. Three keys Obsidian treats specially: `tags` (searchable labels), `aliases` (alternative names for link suggestions), `cssclasses` (CSS hooks for styling). Everything else is opaque — Obsidian stores it without interpreting.

```markdown
---
title: Lasagna
date: 2026-07-13
tags: [recipe, italian]
aliases: [Lasagne]
---
```

For array values, `property:set` keeps the YAML well-formed whether you prefer inline (`[a, b]`) or block list form. Pick one shape per file to keep diffs small.

### Tags

`#tag` anywhere in body content. Letters, numbers, `_`, `-`, `/` are allowed; numbers can't be the first character. Slashes make nested tags: `#project/active`.

The same tag can live in body or under `tags:` in frontmatter — Obsidian merges them. Frontmatter is better for tags you want indexed cleanly; inline is better for tags that earn their keep in context.

### Highlights

`==text==` marks text for the highlighter pen. Renders as a yellow background by default; themeable via CSS.

### Embeds

Prefix any wikilink with `!` to inline its content.

```markdown
![[Recipe]]                   full note inline
![[Recipe#Ingredients]]       one section
![[photo.jpg]]                image
![[photo.jpg|300]]            image, width 300px
![[manual.pdf#page=3]]        one PDF page
```

The renderer is selected by the target's MIME type, so audio, video, and search embeds all use the same `![[…]]` shape.

### What doesn't need Obsidian-specific syntax

Standard Markdown (headings, lists, quotes, tables, code blocks), LaTeX math (`$inline$` / `$$block$$`), and Mermaid diagrams (` ```mermaid `) all work without any new syntax. Reach for them when the note calls for them — no Obsidian-specific reference needed.

## CLI reference

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

### Vault

```bash
obsidian vaults                              # list registered vault names
obsidian vault                               # full info for active vault (tsv)
obsidian vault info=path                     # absolute path of active vault
obsidian vault info=name                     # name, files, folders, or size also work
obsidian vault info=path vault=Other         # path of a named, non-active vault
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
obsidian daily:append content="## Reflection"
obsidian daily:prepend content="## Morning"
```

For non-trivial edits, use `daily:path` to get the path and edit the file with the file tool.

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

## Safety

- **Never `delete` without explicit ask.** The CLI does not move to trash. Recover via `history:restore` only if file history was on.
- **Prefer `obsidian move` over `mv`.** The CLI rewrites `[[wikilinks]]`; `mv` leaves them broken and `unresolved` will list them forever.
- **Don't edit `.obsidian/`** unless the user asks. Plugin state, workspace layout, and app settings live there — manual edits are silently overwritten.
- **CLI requires the app to be running.** If commands hang or return empty results, check that Obsidian is open with the vault loaded. File tools do not have this constraint.
- **Multiple vaults = silent wrong-target risk for the CLI.** When in doubt, pass `vault=<name>` explicitly, or use file tools with absolute paths.
- **Templating and metadata plugins may rewrite on save.** A direct edit can be touched up by a plugin (Linter, Templater) when the file next opens. If formatting matters, edit via the file tool and let the app do its pass on next save.
- **No third-party `obsidian-cli`** (the Homebrew tap, the npm package). They diverge from the official command set and will not match the patterns in this skill.
