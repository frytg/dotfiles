# Herdr app

Window config for herdr-app. The older TUI still reads `herdr/config.toml`. `just link` symlinks these files into `~/.config/herdr-app`.

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

## Not a setting anymore

- Sidebar collapse is already a compact rail.
- The agent list defaults to priority order.
- Pane headers already show the agent name.
- Toasts are in-app. Sounds stay on. There is no outer-terminal notification delivery.
- Sidebar row layouts are the shipped mods, not a config table.
