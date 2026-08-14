# create a new nostr nsec/npub keypair into files named after <name>.
[group('ENCRYPTION')]
create-nostr-key name="key":
	#!/usr/bin/env zsh
	set -euo pipefail
	if ! command -v go >/dev/null 2>&1; then
		echo 'error: go is not on PATH — install via mise or `brew install go`' >&2
		exit 1
	fi
	mkdir -p tmp
	if [[ -f "tmp/{{ name }}.nsec.txt" || -f "tmp/{{ name }}.npub.txt" || -f "tmp/{{ name }}.hex.txt" ]]; then
		echo "error: tmp/{{ name }}.{nsec,npub,hex}.txt already exists — refusing to clobber a key" >&2
		exit 1
	fi

	# fresh secp256k1 secret → bech32 nsec, derive hex npub → bech32 + hex
	local nsec_hex nsec npub_hex npub
	nsec_hex=$(go run github.com/fiatjaf/nak@latest key generate)
	nsec=$(echo "$nsec_hex" | go run github.com/fiatjaf/nak@latest encode nsec)
	npub_hex=$(go run github.com/fiatjaf/nak@latest key public "$nsec_hex")
	npub=$(echo "$npub_hex" | go run github.com/fiatjaf/nak@latest encode npub)

	echo "$nsec" > "tmp/{{ name }}.nsec.txt"
	echo "$npub" > "tmp/{{ name }}.npub.txt"
	echo "$npub_hex" > "tmp/{{ name }}.hex.txt"
	chmod 600 "tmp/{{ name }}.nsec.txt" "tmp/{{ name }}.npub.txt" "tmp/{{ name }}.hex.txt"

	echo "ok: created tmp/{{ name }}.{nsec,npub,hex}.txt"
	echo "    npub:     $npub"
	echo "    npub hex: $npub_hex"
	just nostr-key-to-1password "{{ name }}"
alias cnk := create-nostr-key

# create a Crypto Wallet item in 1password from a created nostr key
[confirm]
[group('ENCRYPTION')]
nostr-key-to-1password name:
	#!/usr/bin/env zsh
	set -euo pipefail
	if ! command -v op >/dev/null 2>&1; then
		echo 'error: 1password-cli (op) not on PATH — install via `brew install --cask 1password-cli` or skip' >&2
		exit 1
	fi
	if [[ ! -f "tmp/{{ name }}.nsec.txt" || ! -f "tmp/{{ name }}.npub.txt" || ! -f "tmp/{{ name }}.hex.txt" ]]; then
		echo "error: tmp/{{ name }}.{nsec,npub,hex}.txt required" >&2
		exit 1
	fi

	local nsec npub npub_hex template
	nsec=$(cat "tmp/{{ name }}.nsec.txt")
	npub=$(cat "tmp/{{ name }}.npub.txt")
	npub_hex=$(cat "tmp/{{ name }}.hex.txt")
	template=$(op item template get "Crypto Wallet")

	if ! echo "$template" | jq -e '.fields[] | select(.label | test("^recovery[_ ]?phrase$"; "i"))' >/dev/null 2>&1; then
		echo 'error: Crypto Wallet template has no `recovery phrase` field. labels available:' >&2
		echo "$template" | jq -r '.fields[].label' | sort -u | sed 's/^/  - /' >&2
		exit 1
	fi
	if ! echo "$template" | jq -e '.fields[] | select(.label | test("wallet address"; "i"))' >/dev/null 2>&1; then
		echo 'error: Crypto Wallet template has no `wallet address` field. labels available:' >&2
		echo "$template" | jq -r '.fields[].label' | sort -u | sed 's/^/  - /' >&2
		exit 1
	fi

	echo "$template" | jq \
		--arg title "Nostr > {{ name }}" \
		--arg priv "$nsec" \
		--arg addr "$npub" \
		--arg hex  "$npub_hex" \
		'.title = $title
		 | .sections = ((.sections // []) + [{id: "nostr", label: "Nostr"}])
		 | (.fields[] | select(.label | test("^recovery[_ ]?phrase$"; "i")) | .value) = $priv
		 | (.fields[] | select(.label | test("wallet address"; "i")) | .value) = $addr
		 | .fields += [{section: {id: "nostr"}, type: "STRING", label: "npub_hex", value: $hex}]' \
		| op item create --tags "nostr" -

# list nostr keys saved in 1password (Crypto Wallet items tagged `nostr`)
[group('ENCRYPTION')]
list-nostr-keys:
	op item list --categories "Crypto Wallet" --tags "nostr"
alias lnk := list-nostr-keys
