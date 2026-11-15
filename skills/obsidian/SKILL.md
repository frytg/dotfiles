---
name: obsidian
description: Work with an Obsidian vault using the agent's file tools and the official `obsidian` CLI. Use when the user asks to capture into their vault, find or update a note, set a frontmatter property, or run any Obsidian-side operation.
license: MIT
metadata:
  author: frytg
  agent: pi
  category: writing
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
- **Multiple vaults.** Run `obsidian vaults` to see registered names. `vault=<name>` targets a specific vault, but only as the first parameter (`obsidian vault=Other search query=x`); anywhere else it is ignored. For a non-active vault's path: `obsidian vault=<name> vault info=path`. With file tools there is no ambiguity — the path is the path.
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

**Update a scalar property.** Use the file tool.

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

## Related skills

- **obsidian-markdown** — note syntax: wikilinks, embeds, callouts, properties, tags, comments, highlights.
- **obsidian-cli** — CLI syntax, file and vault targeting, output flags, plugin and theme dev loop. Run `obsidian help` for the full command list.
- **json-canvas** — reading and writing `.canvas` files.

## Safety

- **Never `delete` without explicit ask.** `delete` moves to the Obsidian trash; `permanent` skips it, so never pass `permanent` unless asked.
- **Prefer `obsidian move` over `mv`.** The CLI rewrites `[[wikilinks]]`; `mv` leaves them broken and `unresolved` will list them forever.
- **Don't edit `.obsidian/`** unless the user asks. Plugin state, workspace layout, and app settings live there — manual edits are silently overwritten.
- **CLI requires the app to be running.** If commands hang or return empty results, check that Obsidian is open with the vault loaded. File tools do not have this constraint.
- **Multiple vaults = silent wrong-target risk for the CLI.** When in doubt, pass `vault=<name>` explicitly, or use file tools with absolute paths.
- **Templating and metadata plugins may rewrite on save.** A direct edit can be touched up by a plugin (Linter, Templater) when the file next opens. If formatting matters, edit via the file tool and let the app do its pass on next save.
- **No third-party `obsidian-cli`** (the Homebrew tap, the npm package). They diverge from the official command set and will not match the patterns in this skill.
