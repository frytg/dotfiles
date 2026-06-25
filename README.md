# dotfiles

A personal collection of dotfiles and scripts for syncing settings across machines.

## Setup

Symlink dotfiles into place:

```bash
just install
```

## Just commands

This repo uses [just](https://github.com/casey/just) as a task runner. Run `just` or `just --list` to see all recipes.

| Command        | What it does                                                |
| -------------- | ----------------------------------------------------------- |
| `just install` | Symlink dotfiles via `install.sh`                           |
| `just brew`    | Install Homebrew packages from `brew.sh`                    |
| `just up`      | Pull latest dotfiles and upgrade toolchains (`just update`) |
| `just all`     | Run `just brew` then `just up`                              |

Other groups include backup/encryption (`wrap`, `backup-item`), Docker (`fix-colima`), and SSH helpers — see `just --list`.

## Tools

### Crane

Useful tool for managing containers.

- [Docs](https://github.com/google/go-containerregistry/blob/main/cmd/crane/doc/crane.md)
- [Common Commands](https://github.com/google/go-containerregistry/blob/main/cmd/crane/recipes.md)

## Author

Created by [frytg.digital](https://www.frytg.digital)

## License

[Unlicense](./LICENSE) - also see [unlicense.org](https://unlicense.org)
