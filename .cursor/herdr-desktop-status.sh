#!/bin/zsh
set -e

# Cursor does not report OSC 7501 itself: https://github.com/herdrdev/herdr-app/issues/98
[[ -n "${HC_TERMINAL_ID:-}" ]] || exit 0
case "${1:-}" in
	idle|working|clear) ;;
	*) exit 0 ;;
esac

# Keep stdout free for Cursor's hook protocol; a missing tty must not block it.
{ printf '\033]7501;state=%s:app=cursor-agent\033\\' "$1" > /dev/tty; } 2>/dev/null || true
