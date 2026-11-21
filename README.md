# dotfiles

Personal dotfiles and setup scripts for macOS machines and ephemeral Linux sandboxes.

The primary repository lives on [tangled.org](https://tangled.org/frytg.digital/dotfiles) and mirrors to [github.com](https://github.com/frytg/dotfiles).

**Visibility:** Public repository. Use synthetic placeholders (`acme`, `example.com`, `<host>`) in docs and examples. Exclude internal hostnames, private URLs, IP addresses, account IDs, and credentials.

## Setup

1. Install the prerequisite Mac apps in [`docs/APPS.md`](./docs/APPS.md), starting with 1Password, Xcode, and Tailscale.
2. Bootstrap packages, symlinks, Node, CLI updates, and macOS defaults:

   ```bash
   just install
   ```

3. For repo-root linting and formatting (`just lint`, `just format`), install the pinned tools in [`mise.toml`](./mise.toml):

   ```bash
   mise install
   ```

## Key `just` commands

Run `just` or `just --list` for all recipes under [`justfile`](./justfile) and [`just/`](./just).

- `just link` — symlink configs and copy Herdr mods via [`bin/link.sh`](./bin/link.sh)
- `just brew` — install Homebrew formulas and casks from [`Brewfile`](./Brewfile)
- `just node` — install and pin ambient Node (`26` in [`mise/config.toml`](./mise/config.toml)) via [mise](https://mise.jdx.dev/lang/node.html); removes any leftover `~/.nub/node-shim`
- `just install-omlx` — install or upgrade the latest macOS oMLX app via [`bin/install-omlx.sh`](./bin/install-omlx.sh)
- `just uzu-install` — build [uzu](https://github.com/trymirai/uzu) from source (see [`docs/UZU.md`](./docs/UZU.md))
- `just install-beszel-agent <hub_url> <key> <token>` — opt-in Beszel monitoring agent (see [`docs/BESZEL.md`](./docs/BESZEL.md))
- `just ssh-add-key` — load the SSH key from 1Password into `ssh-agent` (see [`docs/1PASSWORD_SSH.md`](./docs/1PASSWORD_SSH.md))

## Structure and docs

- [`AGENTS.md`](./AGENTS.md) and [`.agents/AGENTS.md`](./.agents/AGENTS.md) — repository rules and cross-project agent defaults
- [`herdr-app/`](./herdr-app/README.md) — Herdr keys, settings, Dark Greeny theme, layout, and sidebar/tab mods (`just link` copies mods because Herdr does not hot-reload symlinks)
- [`factory/`](./factory/README.md) — shared Droid config; move an existing `~/.factory/settings.json` to `~/.factory/settings.local.json` before the first `just link` so shared defaults do not overwrite machine-specific settings, and keep `~/.factory/` itself local
- [`.pi/`](./.pi/README.md) — pi coding agent config, extensions, and sops-encrypted env
- [`skills/`](./skills/README.md) — portable Agent Skills and plugin manifests ([`plugin.json`](./plugin.json), [`.cursor-plugin/`](./.cursor-plugin/), [`.claude-plugin/`](./.claude-plugin/))
- [`sandbox/`](./sandbox/README.md) — ephemeral Linux sandboxes via `just nsc-start`
- [`moshi/`](./moshi/README.md), [`k9s/`](./k9s/README.md), [`keyboard/`](./keyboard/README.md) — Moshi iOS theme, k9s config, and QMK/VIA macro pad
- `fx` — `just link` symlinks only `~/.fx/AGENTS.md`; keep `~/.fx/` local because `fx` refuses durable state in git-tracked paths, and install/upgrade with `just install-fx` ([`just/install.just`](./just/install.just))

Guides in [`docs/`](./docs):

- [`docs/APPS.md`](./docs/APPS.md) — manual Mac and App Store installs outside [`Brewfile`](./Brewfile)
- [`docs/MCP.md`](./docs/MCP.md) — MCP server configs across pi, Claude Code, Cursor, Droid, and Devin
- [`docs/1PASSWORD_SSH.md`](./docs/1PASSWORD_SSH.md) — service-account SSH agent and Git commit signing
- [`docs/SSH.md`](./docs/SSH.md) — YubiKey PIV SSH setup
- [`docs/BACKUPS.md`](./docs/BACKUPS.md) — age key creation and sops secret management
- [`docs/BESZEL.md`](./docs/BESZEL.md) — Beszel agent installation and Homebrew tap gotcha
- [`docs/UZU.md`](./docs/UZU.md) — building, running, and publishing uzu over Tailscale
- [`docs/DESIGN.md`](./docs/DESIGN.md) — Dark Greeny visual design system for web and iOS
- [`docs/NATIVE_APP_DEV.md`](./docs/NATIVE_APP_DEV.md) — SwiftUI/XcodeGen patterns and UI test harness notes

## Author

Created by [frytg.digital](https://www.frytg.digital)

## License

[MIT](./LICENSE)
