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

| Command        | What it does                              |
| -------------- | ----------------------------------------- |
| `just link`    | Symlink dotfiles via `link.sh`            |
| `just brew`    | Install Homebrew packages from `Brewfile` |
| `just install` | Pull, link, and upgrade toolchains        |
| `just moshi-setup <token>` | Pair and start moshi-hook (one-time) |

## Tools

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
