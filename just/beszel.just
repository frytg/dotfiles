# beszel agent: opt-in per machine, so it stays out of the Brewfile. See docs/BESZEL.md.

BESZEL_ENV_FILE := home_directory() / '.config' / 'beszel' / 'beszel-agent.env'

# write the beszel agent env file, install the tap formula, and (re)start the service (see docs/BESZEL.md)
[group('INSTALL')]
install-beszel-agent hub_url key token:
	mkdir -p ~/.config/beszel ~/.cache/beszel
	@umask 077 && printf 'KEY="%s"\nTOKEN="%s"\nHUB_URL="%s"\n' {{ quote(key) }} {{ quote(token) }} {{ quote(hub_url) }} > "{{ BESZEL_ENV_FILE }}"
	brew tap henrygd/beszel
	brew trust --tap henrygd/beszel
	brew install henrygd/beszel/beszel-agent
	brew services restart henrygd/beszel/beszel-agent
