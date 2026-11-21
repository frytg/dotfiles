# `k9s/`

Basic [k9s](https://k9scli.io/) configuration for macOS. [`bin/link.sh`](../bin/link.sh) symlinks [`config.yaml`](./config.yaml) into `~/Library/Application Support/k9s/config.yaml` instead of symlinking the whole directory, so per-host cluster contexts and `k9s.log` stay local.

Edit [`config.yaml`](./config.yaml) here rather than in `~/Library/Application Support/k9s/`, and run `just link` after setting up a new host.
