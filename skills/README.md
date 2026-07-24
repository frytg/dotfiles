# Skills Documentation

This repository houses the specialized skills used by various AI harness systems.

Each AI harness reads its available skills from the following sources:

- **pi** (via the Pi coding agent harness, reads from `~/.agents/skills/`)
- **cursor** (via the Cursor AI harness, reads from `~/.cursor/skills-cursor/`)

For more information on how these skills are managed and linked across the environment, please see [`link.sh`](link.sh).
