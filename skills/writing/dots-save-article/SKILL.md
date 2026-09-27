---
name: dots-save-article
description: Save an article (markdown body) into the Obsidian vault under `Dots/`. Detects the active frontmatter style by inspecting the last few entries in `Dots/<year>/qN/`. Use when the user asks to save, archive, capture, or store an article, essay, post, or long-form read into their Obsidian Dots folder.
license: MIT
metadata:
  author: frytg
  agent: pi
---

# Save article to Obsidian Dots

Save a markdown article into the user's Obsidian vault under `Dots/`, mirroring the conventions of existing entries.

## Requirements

- `OBSIDIAN_VAULT_PATH` set, pointing to the vault root.
- A `Dots/` subfolder inside the vault.

## Target path

`$OBSIDIAN_VAULT_PATH/Dots/<year>/q<n>/<YYYY-MM-DD> <title>.md`

- Year and quarter: from the article's publication date if known, else today.
- Filename: `<ISO date> <title>.md` — title preserves spaces and casing, no slug.
- Parents are created automatically by the file tool; no `mkdir` needed.

## Frontmatter

The active style drifts. Always read the last 3-5 entries in `Dots/<year>/q<n>/` first, then mirror what you see. Observed fields, in approximate frequency order:

- `author: <Name>` — when known.
- `source: <URL>` — canonical URL the article was retrieved from.
- `tags:` — block list (`- tag`) or inline array; only when tags add value.

Common omissions — keep them out unless an entry uses them:

- `title:` — the filename is the title.
- `date:` — the filename's date prefix is the date.
- An H1 heading that just restates the title.

Emit only the fields the observed entries include. Don't add `id`, `aliases`, `cssclasses`, or other Obsidian extras without an explicit ask.

## Workflow

1. Confirm `OBSIDIAN_VAULT_PATH` is set and `$OBSIDIAN_VAULT_PATH/Dots/` exists. If not, stop and report.
2. Read the last 3-5 files in the current quarter folder to confirm the active frontmatter style.
3. Pick `year`/`q<n>` and compose the filename.
4. Compose frontmatter with only the fields that match the observed style.
5. Write the file with the `write` tool.
6. Reply with one line: path written + which frontmatter fields were emitted.
