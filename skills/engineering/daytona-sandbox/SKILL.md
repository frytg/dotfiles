---
name: daytona-sandbox
description: Run shell commands in an ephemeral Daytona cloud sandbox via the `daytona` CLI. Use when a task needs an isolated Linux runtime — untrusted commands, package experiments, /tmp-style probes, network reachability checks, anything that shouldn't touch the host. Skip when the task needs the local repo (sandboxes don't auto-sync the working tree) or long-lived state across many turns. Requires `daytona` CLI installed and authenticated; if not, warn the user and stop.
license: MIT
metadata:
  author: frytg
  agent: pi
---

# Daytona sandbox

Daytona sandboxes are short-lived Linux containers you drive from the `daytona` CLI. You create one, `exec` commands against its name, and `delete` it when you're done. They're the place to run anything you wouldn't type directly on the host — `curl | sh`, exotic installs, destructive probes, fresh-Linux checks.

The CLI is assumed installed and authenticated. If it isn't, stop with a warning instead of installing it for the user.

## Before you start

Confirm both:

1. `command -v daytona` — the CLI is on `PATH`. If not, point the user at the [installation docs](https://www.daytona.io/docs/en/tools/cli#installation) and stop.
2. `daytona login` was completed, or `DAYTONA_API_KEY` is set in the environment. The CLI will fail with an auth error otherwise.

## When to use it

Reach for a sandbox when the command would otherwise touch the host and you don't fully trust the side effects:

- `curl ... | sh`, third-party installers, package experiments you might revert
- filesystem probes that might delete or rewrite things (`rm -rf`, `find -delete`)
- cross-distro Linux checks, weird-glibc binaries, network reachability
- anything you'd otherwise test in `/tmp`

Skip it when the task needs the local repo: sandboxes start from a snapshot, they don't see your working tree. Clone the repo inside the sandbox, copy files via `daytona ssh` + `scp`, or use a [volume](https://www.daytona.io/docs/en/volumes) if you need persistent state across runs. For long-lived workflows that span many turns, prefer the host or the Python/TypeScript SDK over repeated `daytona exec` round-trips.

## The standard recipe

Create with auto-stop and auto-delete so a forgotten sandbox can't run forever:

```bash
daytona create \
  --auto-stop 30 \
  --auto-delete 60 \
  --name "dotfiles project 123" \
  --target eu \
  --snapshot daytona-medium
```

- `--auto-stop 30` — sandbox auto-stops after 30 min of inactivity (frees CPU/RAM, keeps disk).
- `--auto-delete 60` — sandbox auto-deletes 60 min after stopping (wipes disk).
- `--target eu` — pin region. Use `us` if that's closer. Without it, Daytona picks the org default.
- `--snapshot daytona-medium` — 2 vCPU, 4 GiB RAM, 8 GiB disk, container class.

Run commands inside by name:

```bash
daytona exec "dotfiles project 123" -- "ls -al /"
daytona exec "dotfiles project 123" -- "sudo apt-get update && sudo apt-get install -y ripgrep"
daytona exec "dotfiles project 123" -- "rg --version"
```

The `--` separates the sandbox selector from the command. Quote the command if it contains shell metacharacters (`&&`, `|`, redirections), or your local shell will evaluate them first.

Clean up:

```bash
daytona delete "dotfiles project 123"
# confirm with --all if you want to nuke every sandbox
daytona delete --all
```

## Naming and quoting

Names with spaces must be quoted everywhere they're passed: create, exec, delete, info, stop, start, ssh, preview-url. The user's convention is `"<project> <short-id>"`, e.g. `"dotfiles project 123"`. Slug names (`dotfiles-123`) avoid the quoting dance entirely and parse cleanly through nested shells.

Names are unique within your org. If you re-run a create with a name that already exists, Daytona errors out — pick a new slug or delete the old sandbox first.

## Default snapshots

These are the snapshots Daytona ships with. Pick by resource need; the medium is the workhorse.

| Snapshot            | vCPU | Memory | Disk   | Class     |
| ------------------- | ---- | ------ | ------ | --------- |
| `daytona-small`     | 1    | 1 GiB  | 3 GiB  | Container |
| `daytona-medium`    | 2    | 4 GiB  | 8 GiB  | Container |
| `daytona-large`     | 4    | 8 GiB  | 10 GiB | Container |
| `daytona-vm-medium` | 2    | 4 GiB  | 8 GiB  | Linux VM  |
| `windows-medium`    | 2    | 8 GiB  | 50 GiB | Windows   |

Default snapshots include pre-installed Python (anthropic, openai, pandas, pydantic, transformers, etc.) and Node (bun, typescript, opencode-ai). Useful if you're testing an LLM-driven workflow — the sandbox already has the SDKs.

## Command reference

Only the subset worth remembering. Run `daytona <cmd> --help` for the full flag list.

### Sandbox lifecycle

```bash
daytona create [flags]                              # --snapshot, --name, --target, --auto-stop, --auto-delete, --cpu, --memory, --disk, --env KEY=VAL, --label KEY=VAL
daytona list [-f yaml|json] [-l N]                  # all sandboxes in the org
daytona info <name|id> [-f yaml|json]               # one sandbox, full details
daytona exec <name|id> [--cwd <path>] [--timeout N] -- "<cmd> [args...]"
daytona ssh <name|id> [--expires N]                 # interactive shell
daytona stop <name|id> [-f]                         # -f = SIGKILL
daytona start <name|id>
daytona archive <name|id>                           # cold storage, no quota impact
daytona delete <name|id> | --all                    # permanent
```

### Snapshots

```bash
daytona snapshot list [-f yaml|json] [-l N] [-p N]
daytona snapshot create <name> --image <img> [--cpu N --memory N --disk N]   # img must have a tag (no :latest)
daytona snapshot push <local-image:tag> --name <snapshot-name>              # upload a local Docker image
daytona snapshot delete <name|id> | --all
```

A snapshot becomes **inactive** after 2 weeks of disuse; reactivate it from the dashboard or via `daytona snapshot activate <name>` (where supported).

### Preview URLs

Expose an HTTP service running inside the sandbox:

```bash
daytona preview-url <name|id> --port 8080 [--expires N]
```

Returns a signed URL good for `--expires` seconds. Use this when the sandbox is running a server you want to hit from your laptop.

### Resource overrides

If the default snapshot's resources are wrong for the run, override per-sandbox on `create`:

```bash
daytona create --snapshot daytona-small --cpu 2 --memory 4 --disk 8 --name "build-test-456"
```

Values match the snapshot's class; bigger numbers than the snapshot's defaults may not be honored by smaller classes.

## Common workflows

**Test a sketchy install script:**

```bash
daytona create --auto-stop 30 --auto-delete 60 --name "install-probe-789" --target eu --snapshot daytona-medium
daytona exec "install-probe-789" -- "curl -fsSL https://example.com/install.sh | bash -s -- --some-flag"
daytona exec "install-probe-789" -- "which thing-i-just-installed && thing-i-just-installed --version"
daytona delete "install-probe-789"
```

**Reproduce a Linux-only bug:**

```bash
daytona create --auto-stop 30 --auto-delete 60 --name "repro-bug-101" --target eu --snapshot daytona-small
daytona exec "repro-bug-101" -- "uname -a && cat /etc/os-release"
daytona exec "repro-bug-101" -- "git clone https://github.com/some/repo.git /tmp/repro && cd /tmp/repro && ./build.sh"
daytona delete "repro-bug-101"
```

**Drive a server, then hit it:**

```bash
daytona create --auto-stop 30 --auto-delete 60 --name "web-probe-202" --target eu --snapshot daytona-medium --public
daytona exec "web-probe-202" -- "python3 -m http.server 8080 >/tmp/srv.log 2>&1 &"
URL=$(daytona preview-url "web-probe-202" --port 8080 | awk '/https?:\/\// {print $NF}')
curl -s "$URL"
daytona delete "web-probe-202"
```

The `--public` flag exposes the sandbox without token auth; omit it to require the preview token header.

## Pitfalls

- **Network access is restricted on Tier 1/2 orgs.** Sandboxes can only reach an essential-services whitelist (npm, PyPI, apt, GitHub, major AI APIs, common CDNs). Arbitrary URLs fail with no override. Need arbitrary egress? Upgrade to Tier 3+ or work around it.
- **No automatic repo sync.** The sandbox is a fresh container. Clone or upload what you need.
- **`--` is mandatory for exec** when the command has flags of its own; without it, `daytona` tries to parse them.
- **`daytona create` doesn't accept a `--name` that already exists** — names are org-unique. Delete first or pick a new slug.
- **Auto-stop ≠ auto-delete.** Stopped sandboxes still hold disk against your quota until `--auto-delete` fires. If you stop one manually, delete it explicitly.
- **`--target eu` / `--target us`** sets the sandbox region. Snapshots also have a region — if your snapshot was built in `us`, creating a sandbox with `--target eu` from it can fail. Match them.
- **No `:latest` in snapshot images.** Build/pin a tag or digest, or `daytona snapshot create` errors out.
