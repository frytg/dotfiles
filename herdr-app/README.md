# Herdr app

Window config for herdr-app. Run `just link` to sync it.

## Keys

Migrated from the TUI `[keys]` block. The window has no prefix mode, so `ctrl+a` is a two-key sequence.

- `ctrl-1` through `ctrl-9` selects tabs (`switch_tab`).
- `ctrl-a` then `1` through `9` selects spaces (`prefix+1..9`).
- `ctrl-a` then an arrow, and shift+arrow, moves between spaces (up/down) and tabs (left/right).
- `ctrl-a ctrl-a` in a terminal sends `^A`. A lone `ctrl-a` is the leader and does not.

`prefix+ctrl+1..9` (focus an agent by index) has no command here. `cmd-[` and `cmd-]` move between agents.

`cmd-1` through `cmd-9` still selects tabs.

## Theme

The [theme](themes/dark-greeny.json) uses gruvbox dark for terminal ANSI (`theme.name`). Panel colors are the
`theme.custom` tokens. `panel_bg = transparent` and `surface0 = reset` become the same background as the terminal.
The [settings](settings.json) lock `appearance` to `dark` (`auto_switch = false`).

## Git panel

The [layout](layouts/dan.json) is a clone of the shipped `main` layout. Its Changes panel runs the
[git-changes mod](mods/git-changes/main.js), a clone of the shipped `changes` mod with a sync row: upstream
ahead/behind, Fetch (`--prune`), Pull (`--ff-only`) and Push (sets the upstream on the first push).
Clones never get Herdr's updates, so compare against the shipped `changes` mod after an app update.
The app writes `gpui-kit.d.ts` and `jsconfig.json` next to the mod for editor types, so they stay out of the repo.

## Usage box

The [usage mod](mods/usage/main.js) is a sidebar box between the agents list and the footer.
It shows Claude Code (5h and 7d), Cursor, and Factory (5h, 7d and 30d) plan usage as meters with their reset times.
On the compact rail it shows only icons and percentages. The box resizes its `usage` layout block to fit its content,
so the layout's `px` is only the starting height. Click the header to fold it down to one line with the percentages.

The usage mod's files are copied together, so imports and reloads use files inside Herdr's home.
After editing, run `just link` to refresh the mod.

- Claude Code: the [status line](../claude/statusline.sh) caches the 5h and 7d rate limits on every refresh.
  The mod reads the cache every minute, so the numbers only move while a Claude session runs.
  Partial snapshots keep previously reported windows. Claude drops expired windows from its payload;
  a missing or expired window shows 0% once either subscription window has been reported.
- Cursor: every 12 minutes the mod takes the first unexpired access token from the `cursor-agent` Keychain login,
  CLI auth, or desktop state database, the same order Orca uses. It calls the undocumented
  `cursor.com/api/usage-summary`, and for `unified_` plans `api/dashboard/get-current-period-usage`.
  The token stays in memory. If no token works or the API changes, the Cursor row stays hidden.
- Factory: every five minutes the mod calls the undocumented `api.factory.ai/api/billing/limits` with an existing
  API key. Standard rolling quotas show as 5h, 7d and 30d; legacy Standard/Premium billing isn't supported.
  Parsing follows
  [CodexBar's Factory provider](https://github.com/steipete/CodexBar/blob/main/docs/factory.md).
  Failed refreshes keep the last reading, marked `stale` (or `*` when folded or compact). No key shows
  `Factory: key needed`; a failed first request shows `Factory: unavailable`. The generic agent icon represents Factory.

### Factory API key

The mod reads its dedicated API key from 1Password with `op`, using the same service account as `just ssh-add-key`.
See the [credential loader](mods/usage/factory-usage.js) for the configured item and token source.
The account must have read access to the item.

Keep `op` on Herdr's command `PATH` and the token file readable only by your user. The API key stays in memory;
the mod doesn't copy it to Keychain or disk, inspect Droid's login or browser cookies, or log Factory API errors
or bodies. `FACTORY_API_KEY` and the old Keychain item are no longer used. The next five-minute refresh picks up
changes to the 1Password item.

Run `just test-herdr-usage` for Claude status-line cache and usage-window regression checks.
Use `herdr-app check herdr-app/mods/usage` from the repo root for the native mod check.

## Not a setting anymore

- Sidebar collapse is already a compact rail.
- The agent list defaults to priority order.
- Pane headers already show the agent name.
- Toasts are in-app. Sounds stay on. There is no outer-terminal notification delivery.
- Sidebar row layouts are the shipped mods, not a config table.
