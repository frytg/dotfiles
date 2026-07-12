# `k9s/`

Basic [k9s](https://k9scli.io/) configuration. `link.sh` symlinks `config.yaml` into `~/Library/Application Support/k9s/` so k9s picks it up on launch.

## Edit

Edit `config.yaml` in this directory, not in `~/Library/Application Support/k9s/` — the symlink points back here, and only commits persist.

From the repo root:

```sh
just link
```
