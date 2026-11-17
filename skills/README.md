# Skills Documentation

This repository houses the specialized skills used by various AI harness systems.

Each AI harness reads its available skills from the following sources:

- **pi** (via the Pi coding agent harness, reads from `~/.agents/skills/`)
- **cursor** (via the Cursor AI harness, reads from `~/.agents/skills/` and `~/.cursor/skills-cursor/`)
- **fx** (via the `fx` CLI, reads from `~/.agents/skills/` and `~/.fx/skills/`)
- **claude code** (reads from `~/.claude/skills/`, symlinked to `skills/`)

## Full discovery paths per harness

The list above only shows what `bin/link.sh` wires on this host. Each harness also reads from additional roots per its docs.

- **pi** ([docs/skills.md](https://github.com/earendil-works/pi-coding-agent/blob/main/docs/skills.md))
  - global: `~/.pi/agent/skills/`, `~/.agents/skills/`
  - project (trusted only): `.pi/skills/`, `.agents/skills/`
    - walked from `cwd` up to the git repo root (or filesystem root outside a repo)
  - extras:
    - `skills/` dirs or `pi.skills` entries in `package.json`
    - `skills` array in `settings.json` (files or dirs)
    - `--skill <path>` on the CLI (repeatable, additive even with `--no-skills`)
- **cursor** ([cursor.com/docs/skills](https://cursor.com/docs/skills))
  - global: `~/.agents/skills/`, `~/.cursor/skills/`
  - project: `.agents/skills/`, `.cursor/skills/`
    - recurses into nested subdirs; nested skills are auto-scoped to files inside that subdir
  - compat: `.claude/skills/`, `.codex/skills/`, `~/.claude/skills/`, `~/.codex/skills/`
  - note: `~/.cursor/skills-cursor/` is built-in, not for user content
- **fx** ([fx.sh/docs/capabilities/skills](https://fx.sh/docs/capabilities/skills))
  - workspace (cwd → home, in precedence order):
    - `skills/`, `.opencode/skills/`, `.codex/skills/`, `.claude/skills/`, `.agents/skills/`, `.claw/skills/`
  - global (home):
    - `~/.fx/skills/` — the only path `fx install` writes
    - `~/.config/opencode/skills/`, `~/.codex/skills/`, `~/.claude/skills/`, `~/.agents/skills/`, `~/.claw/skills/`
  - note: additional workspace directories don't contribute skills

For more information on how these skills are managed and linked across the environment, please see [`link.sh`](../bin/link.sh).

## Install as an Agent Plugin (Perplexity Computer, etc.)

The repository root includes [`plugin.json`](../plugin.json) conforming to the [Agent Plugins 1.0 specification](https://agent-plugins.org), and every skill lives directly under `skills/<name>/SKILL.md` (with `metadata.category` in YAML frontmatter).

- **Perplexity Computer**: open **Plugins** → **Add custom** → **Import plugin from GitHub**, and paste `https://github.com/frytg/dotfiles` (the public [Tangled → GitHub mirror](../.tangled/workflows/github-mirror.yml)). All skills under `skills/` are discovered automatically (Perplexity's per-plugin limits are 32 skills, 1,000 files, and 20 MB uncompressed).

## Install as a Cursor plugin

All skills also ship as one Cursor Plugin, `frytg-dotfiles`. The manifest [`.cursor-plugin/plugin.json`](../.cursor-plugin/plugin.json) points to `"skills": ["skills"]`, so skills load straight from `skills/<name>/SKILL.md`. [`.cursor-plugin/marketplace.json`](../.cursor-plugin/marketplace.json) registers the plugin so the repository imports as a Cursor marketplace.

- Install: open **Customize** in Cursor, choose **From GitHub Repository**, and paste `https://github.com/frytg/dotfiles` (the [Tangled → GitHub mirror](../.tangled/workflows/github-mirror.yml); Cursor's repo import officially supports GitHub, GitLab, Bitbucket, and Azure DevOps, not tangled.org). Then install **frytg-dotfiles**.
- Teams/Enterprise: import the same URL as a team marketplace under Dashboard → Plugins & MCPs → Add Marketplace.
- Local test: `mkdir -p ~/.cursor/plugins/local/frytg-dotfiles` and copy `.cursor-plugin/` plus `skills/` into it (copies, not symlinks — Cursor skips symlinks pointing outside that folder), reload the window (Developer: Reload Window), and check Customize. Delete the copy afterwards; it goes stale as skills change.
- Validate with the [Cursor plugin template](https://github.com/cursor/plugin-template)'s `scripts/validate-template.mjs` run from the repo root.

On hosts wired by `link.sh` this is optional — Cursor already reads the same skills through `~/.agents/skills/` (symlinked to this folder). The plugin route matters for other machines and teammates installing straight from the repo URL.

## Install as a Claude Code plugin

All skills also ship as one Claude Code plugin, `frytg-dotfiles`. The manifest [`.claude-plugin/plugin.json`](../.claude-plugin/plugin.json) points to `skills/`, and [`.claude-plugin/marketplace.json`](../.claude-plugin/marketplace.json) registers the repository as a marketplace with the plugin at its root. Plugin skills are namespaced, so they show up as `frytg-dotfiles:<name>`.

- Install: in Claude Code run `/plugin marketplace add https://github.com/frytg/dotfiles` (the [Tangled → GitHub mirror](../.tangled/workflows/github-mirror.yml)), then `/plugin install frytg-dotfiles@frytg-dotfiles`.
- Local test: `claude --plugin-dir .` from the repo root loads the plugin for one session without installing it.
- Validate with `claude plugin validate .` from the repo root.

On hosts wired by `link.sh`, skip the install. `~/.claude/skills/` already links to this folder, so installing the plugin as well loads every skill twice (once bare, once namespaced).
