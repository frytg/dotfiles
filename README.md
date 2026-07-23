# dotfiles

A personal collection of dotfiles and scripts for syncing settings across machines.

The primary repository lives on [tangled.org](https://tangled.org/frytg.digital/dotfiles), which gets synced to [github.com](https://github.com/frytg/dotfiles).

## Setup

Install and symlink dotfiles into place:

```bash
just install
```

## Just commands

This repo uses [just](https://github.com/casey/just) as a task runner. Run `just` or `just --list` to see all recipes.

- `just link` — symlink dotfiles via `link.sh`
- `just brew` — install Homebrew packages from `Brewfile`
- `just node` — install/pin ambient Node via [mise](https://mise.jdx.dev/)
- `just install` — brew, link, mise node, and upgrade toolchains
- `just moshi-setup <token>` — pair and start moshi-hook (one-time)

## Tools

### Node (mise)

Ambient `node` is provisioned by [mise](https://mise.jdx.dev/lang/node.html), not nvm/fnm or nub's shim. Global pin and settings live in [`mise/config.toml`](./mise/config.toml) (linked to `~/.config/mise/config.toml`). Interactive shells activate mise from `.zshrc`; login shells / IDEs get shims from `.zprofile`.

```bash
just node                 # install + pin global node@26
mise use node@22          # pin a project (writes mise.toml)
mise doctor               # verify activate/shims
```

Project pins also come from `.node-version`, `.nvmrc`, or `package.json#devEngines` when those are present. Nub stays the package manager (`nub` / `nubx` / `nub install`) and uses the mise-provided `node` on `PATH`.

### Moshi

[moshi-hook](https://getmoshi.app/docs/hooks) bridges local coding agents to the Moshi iOS app (inbox events, approvals, Live Activity). It's installed via the `Brewfile`; finish the one-time setup per machine with:

```bash
just moshi-setup <pairing-token> # token from Moshi app → Settings → Hooks
```

No tmux here — sessions run in [herdr](https://herdr.dev), which moshi-hook detects automatically via `$HERDR_ENV`. (Don't call `moshi <dir>`; that alias launches a tmux session.)

The [moshi/](./moshi) directory holds the Dark Greeny custom app theme and its import docs.

### Crane

Useful tool for managing containers.

- [Docs](https://github.com/google/go-containerregistry/blob/main/cmd/crane/doc/crane.md)
- [Common Commands](https://github.com/google/go-containerregistry/blob/main/cmd/crane/recipes.md)

## Author

Created by [frytg.digital](https://www.frytg.digital)

## License

[MIT](./LICENSE)
