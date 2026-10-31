# Herdr app

Window config for herdr-app. `just link` symlinks these files into `~/.config/herdr-app`.

## Keys

Migrated from the TUI `[keys]` block. The window has no prefix mode, so `ctrl+a` is a two-key sequence.

- `ctrl-1` through `ctrl-9` selects tabs (`switch_tab`).
- `ctrl-a` then `1` through `9` selects spaces (`prefix+1..9`).
- `ctrl-a` then an arrow, and shift+arrow, moves between spaces (up/down) and tabs (left/right).
- `ctrl-a ctrl-a` in a terminal sends `^A`. A lone `ctrl-a` is the leader and does not.

`prefix+ctrl+1..9` (focus an agent by index) has no command here. `cmd-[` and `cmd-]` move between agents.

`cmd-1` through `cmd-9` still selects tabs.

## Theme

`themes/dark-greeny.json`. Terminal ANSI is gruvbox dark (`theme.name`). Panel colors are the `theme.custom` tokens. `panel_bg = transparent` and `surface0 = reset` become the same background as the terminal. `settings.json` locks `appearance` to `dark` (`auto_switch = false`).

## Git panel

`layouts/dan.json` is a clone of the shipped `main` layout. Its Changes panel runs `mods/git-changes`, a clone of the shipped `changes` mod with a sync row: upstream ahead/behind, Fetch (`--prune`), Pull (`--ff-only`) and Push (sets the upstream on the first push). Clones never get Herdr's updates, so compare against the shipped `changes` mod after an app update. The app writes `gpui-kit.d.ts` and `jsconfig.json` next to the mod for editor types, so they stay out of the repo.

## Usage box

`mods/usage` is a sidebar box between the agents list and the footer. It shows Claude Code (5h and 7d) and Cursor plan usage as meters with their reset times. On the compact rail it shows only the icons and percentages. The box resizes its `usage` layout block to fit its content, so the block's `px` in `layouts/dan.json` is only the starting height. Click the header to fold it down to one line with the percentages.

The mod files are symlinks, and the app doesn't reload a mod when a symlink target changes. After editing, recreate the links with `just link` to reload.

- Claude Code: `claude/statusline.sh` writes the 5h and 7d rate limits to `~/.cache/claude-usage.json` on every refresh. The mod reads it every minute, so the numbers only move while a Claude session runs. A window whose reset has passed shows 0%.
- Cursor: every 12 minutes the mod takes the first unexpired access token from the `cursor-agent` Keychain login, `~/.cursor/auth.json`, or the desktop `state.vscdb`, the same order Orca uses. It calls the undocumented `cursor.com/api/usage-summary`, and for `unified_` plans `api/dashboard/get-current-period-usage`. The token stays in memory. If no token works or the API changes, the Cursor row stays hidden.

## Not a setting anymore

- Sidebar collapse is already a compact rail.
- The agent list defaults to priority order.
- Pane headers already show the agent name.
- Toasts are in-app. Sounds stay on. There is no outer-terminal notification delivery.
- Sidebar row layouts are the shipped mods, not a config table.
