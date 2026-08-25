---
name: markdown
description: Lint and write Markdown that renders correctly across CommonMark, GFM, GitHub, Hugo, MkDocs, and most static-site generators. Use when editing any .md file or auditing documentation. Covers spacing around block elements, list and emphasis conventions, and final-newline requirements.
---

# Markdown — concise lint rules

Brief rules for Markdown that renders consistently across CommonMark, GFM, GitHub, Hugo, MkDocs, and the like.

## Spacing (the #1 source of "fine in my editor" bugs)

1. **Blank line before AND after every heading, list, and fenced code block.** Without it, parsers commonly join the previous paragraph into the heading, swallow the first list item, or refuse to close the fence.
2. **At most one consecutive blank line.** Two blanks adds nothing and breaks some lints.
3. **No trailing whitespace on prose lines.** Two trailing spaces is a hard line break in Markdown — fragile and invisible in most editors. Prefer blank line + new paragraph instead. (Projects with `trim_trailing_whitespace = false` for `*.md` in `.editorconfig` are opting into allowing it — leave those alone.)
4. **File ends with a single newline.** No trailing blank lines.

## Headings

1. **ATX style only** (`# Heading`), never Setext (`Heading\n=====`). ATX is unambiguous, supports nesting cleanly, and matches anchor generation.
2. **One H1 per file.** The H1 is the document title; everything else nests beneath it.
3. **Don't skip levels.** After H2, use H3 — don't jump to H4.
4. **No trailing punctuation in heading text** (except `?` / `!` / `:`). Keeps slugs clean and saves some renderers.

## Lists

1. **Consistent marker** — pick `-` and use it everywhere; don't mix `-` / `*` / `+`.
2. **Consistent indent — 2 spaces per level** (or whatever the project's `.editorconfig` says).
3. **Numbered lists: increment the digit** (`1.` `2.` `3.`) even though Markdown only requires all `1.`. Easier to insert items and to read in source.
4. **Blank line between consecutive lists, and between a list and its parent or child list.** Sub-items need both the indent and the blank line above.

## Code

1. **Always set the language on fenced code blocks** (` ```ts `, not ` ``` `). Untyped fences skip syntax highlighting, lose copy-button semantics on docs sites, and break some extractors.
2. **Pick one fence style** (` ``` `) and stay with it. Don't mix ` ``` ` and `~~~`.
3. **Indent inside lists: 2 extra spaces** beyond the list marker. The fence must align with the first character after the marker.

## Inline

1. **Pick an emphasis style and stay with it.** Either `*italic*` / `**bold**` or `_italic_` / `__bold__`, not both — within a file.
2. **Inline links over reference links** for one-offs. Reserve reference links for repeated URLs or long anchor text.
3. **Use backticks for code** — `` `variable` ``, not `*variable*` (asterisks render as emphasis).
4. **No raw HTML unless required.** Markdown breaks cleaner in RSS, copy-paste, and most static-site renderers.

## Indentation

- **Use spaces for indentation.** Tabs break list parsing in CommonMark and most renderers.
