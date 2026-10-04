# install Ollama CLI/ app
[group('INSTALL')]
install-ollama:
	@if ! command -v ollama >/dev/null 2>&1; then \
		curl -fsSL https://ollama.com/install.sh | sh; \
	else \
		echo "ollama already installed, skipping"; \
	fi
	ollama pull clef
	ollama pull tev1:4b
