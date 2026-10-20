# auth: service account token at ~/.config/1Password/herdr.token.
# private key is piped to ssh-add and is not written to disk.
# uses SSH_AUTH_SOCK when an agent is already listening (herdr / launchd),
# otherwise starts ~/.ssh/agent-herdr.sock.
# load Agentic vault "Agent SSH Key" into ssh-agent. lifetime defaults to 8h.
[group('SSH')]
ssh-add-key lifetime='8h':
	#!/usr/bin/env zsh
	set -euo pipefail

	token_file="$HOME/.config/1Password/herdr.token"
	fallback_sock="$HOME/.ssh/agent-herdr.sock"
	pub="$HOME/.ssh/agent.pub"

	if [[ ! -s "$token_file" ]]; then
		echo "error: missing service account token at $token_file" >&2
		exit 1
	fi
	if ! command -v op >/dev/null 2>&1; then
		echo 'error: op CLI not on PATH' >&2
		exit 1
	fi

	# fail instead of blocking on a passphrase prompt (op returns an unencrypted key)
	export DISPLAY=
	export SSH_ASKPASS=
	export SSH_ASKPASS_REQUIRE=never

	agent_up=0
	if [[ -n "${SSH_AUTH_SOCK:-}" && -S "$SSH_AUTH_SOCK" ]]; then
		rc=0
		ssh-add -l >/dev/null 2>&1 || rc=$?
		# 0 = has keys, 1 = empty but reachable, 2 = no agent
		if [[ "$rc" -eq 0 || "$rc" -eq 1 ]]; then
			agent_up=1
		fi
	fi

	if [[ "$agent_up" -eq 0 ]]; then
		mkdir -p "$HOME/.ssh"
		chmod 700 "$HOME/.ssh"
		export SSH_AUTH_SOCK="$fallback_sock"
		rm -f "$fallback_sock"
		ssh-agent -a "$fallback_sock" >/dev/null
		echo "ok: started ssh-agent at $fallback_sock"
		echo "export SSH_AUTH_SOCK=$fallback_sock"
	else
		echo "ok: using $SSH_AUTH_SOCK"
	fi

	export OP_SERVICE_ACCOUNT_TOKEN="$(cat "$token_file")"
	unset OP_CONNECT_HOST OP_CONNECT_TOKEN

	umask 077
	mkdir -p "$HOME/.ssh"
	op read 'op://Agentic/Agent SSH Key/public key' > "$pub"
	chmod 644 "$pub"

	op read 'op://Agentic/Agent SSH Key/private key?ssh-format=openssh' \
		| ssh-add -t '{{ lifetime }}' -
	echo "ok: loaded Agent SSH Key (lifetime {{ lifetime }})"
	ssh-add -l

# list keys registered in the ssh-agent (fingerprints).
[group('SSH')]
ssh-keys:
	#!/usr/bin/env zsh
	set -euo pipefail

	if [[ -z "${SSH_AUTH_SOCK:-}" || ! -S "$SSH_AUTH_SOCK" ]]; then
		if [[ -S "$HOME/.ssh/agent-herdr.sock" ]]; then
			export SSH_AUTH_SOCK="$HOME/.ssh/agent-herdr.sock"
		else
			echo 'error: no ssh-agent socket — run `just ssh-add-key`' >&2
			exit 1
		fi
	fi

	echo "agent: $SSH_AUTH_SOCK"
	rc=0
	ssh-add -l || rc=$?
	# 1 = agent is up and empty. ssh-add already printed that.
	if [[ "$rc" -eq 1 ]]; then
		exit 0
	fi
	exit "$rc"
