# Moshi theme — Dark Greeny

Custom theme for the [Moshi](https://getmoshi.app) iOS app (SSH & MOSH terminal). One palette drives both the terminal and the app chrome, so the phone matches Zed, Ghostty, and herdr.

Not symlinked by `link.sh` — the theme is imported into the app, not read from disk.

## Palette source

- ANSI colors lifted from `.zed/themes/dark-greeny.json` (`terminal.ansi.*`), including bright variants; magenta stays mapped to orange as in the editor theme.
- Cursor `#FFFF11` from `.ghostty`.
- Selection `#3E4939` (the `greeny` border/hover tone).

## Import

Settings → Theme → Import theme in the app, then one of:

- **File** — pick `moshi-theme-dark-greeny.json`.
- **Clipboard** — paste the `moshi-theme:` string (regenerate below):

  ```
  moshi-theme:ewoJInYiOiAxLAoJIm5hbWUiOiAiRGFyayBHcmVlbnkiLAoJIm1vZGUiOiAiZGFyayIsCgkiY29sb3JzIjogewoJCSJiYWNrZ3JvdW5kIjogIiMxODFEMTYiLAoJCSJmb3JlZ3JvdW5kIjogIiNFQ0VCRTMiLAoJCSJjdXJzb3IiOiAiI0ZGRkYxMSIsCgkJImJsYWNrIjogIiMxODFEMTYiLAoJCSJyZWQiOiAiI0ZGMDAzQyIsCgkJImdyZWVuIjogIiM4MEQwODAiLAoJCSJ5ZWxsb3ciOiAiI0ZGRTk0QSIsCgkJImJsdWUiOiAiIzJBQzJGMSIsCgkJIm1hZ2VudGEiOiAiI0YwOTEzOSIsCgkJImN5YW4iOiAiIzgwRDA4MCIsCgkJIndoaXRlIjogIiNFQ0VCRTMiLAoJCSJicmlnaHRCbGFjayI6ICIjM0U0OTM5IiwKCQkiYnJpZ2h0UmVkIjogIiNGRjZCODUiLAoJCSJicmlnaHRHcmVlbiI6ICIjQjBFMEIwIiwKCQkiYnJpZ2h0WWVsbG93IjogIiNGRkZGN0YiLAoJCSJicmlnaHRCbHVlIjogIiM3QkQ4RjEiLAoJCSJicmlnaHRNYWdlbnRhIjogIiNGRkIwNzAiLAoJCSJicmlnaHRDeWFuIjogIiNCMEUwQjAiLAoJCSJicmlnaHRXaGl0ZSI6ICIjRkZGRkZGIiwKCQkic2VsZWN0aW9uQmFja2dyb3VuZCI6ICIjM0U0OTM5IgoJfQp9Cg==
  ```

- **QR code** — scan a gallery QR with the import screen's camera.

Imported themes behave like built-ins, including Auto Theme pairing.

## Regenerate the clipboard string

The clipboard format is `moshi-theme:` + base64 of the JSON:

```bash
printf 'moshi-theme:%s' "$(base64 -i moshi/moshi-theme-dark-greeny.json | tr -d '\n')" | pbcopy
```

## Docs and links

- [Moshi setup / hooks docs](https://getmoshi.app/docs/hooks) — pairing `moshi-hook` (repo shortcut: `just moshi-setup <token>`).
- [Moshi personalization docs](https://getmoshi.app/docs/personalization) — theme format (v1), import flow, fonts.
- [Moshi theme gallery](https://getmoshi.app/themes) — 570+ palettes; raw JSON at `getmoshi.app/themes/<slug>.json`.
- [iTerm2-Color-Schemes](https://iterm2colorschemes.com) — upstream source of the gallery palettes.
