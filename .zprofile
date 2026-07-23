# login shell only (Terminal.app, automation profiles, some IDEs).
# shims put node/npm/etc on PATH without the full interactive activate hook.
# interactive shells also load .zshrc, which runs `mise activate zsh`.
# https://mise.jdx.dev/ide-integration.html
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh --shims)"
fi
