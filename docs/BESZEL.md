# Beszel agent

[Beszel](https://beszel.dev) monitors hosts from one hub. The agent is opt-in per Mac, so it isn't in the `Brewfile` or `just run`. The recipe lives in [`just/beszel.just`](../just/beszel.just).

## Setup

1. **Add the system in the hub.** "Add System" shows the public key and the token.
2. **Run the recipe with the hub URL, key, and token.** Quote the key, because it contains a space.

   ```bash
   just install-beszel-agent https://beszel.example.ts.net 'ssh-ed25519 AAAA...' <token>
   ```

3. **Check the hub.** The system turns green within a few seconds.

The recipe overwrites `~/.config/beszel/beszel-agent.env` (mode `600`) on every run. A rerun also restarts the service, so it's the way to change the token or hub.

## Gotchas

- **Use the tap formula, not homebrew-core.** homebrew-core also ships `beszel-agent`, and a bare `brew install beszel-agent` picks it over the tap. Its service only sets `DATA_DIR`, so the agent exits with `no key provided`. The tap formula (`henrygd/beszel/beszel-agent`) runs a launcher that sources the env file. If the core formula is already installed, run `brew services stop beszel-agent && brew uninstall beszel-agent` first. `brew services restart` alone keeps the core formula's launchd plist.
- **The tap needs trust.** Homebrew 7 refuses non-official taps until `brew trust --tap henrygd/beszel` runs. The recipe does this.
- **Logs** go to `~/.cache/beszel/beszel-agent.log`.

See the upstream [agent installation guide](https://beszel.dev/guide/agent-installation) and the [environment variables](https://beszel.dev/guide/environment-variables) list.
