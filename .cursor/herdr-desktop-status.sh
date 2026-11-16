#!/bin/zsh
set -e

# Cursor does not report OSC 7501 itself: https://github.com/herdrdev/herdr-app/issues/98
[[ -n "${HC_TERMINAL_ID:-}" ]] || exit 0
case "${1:-}" in
	idle|working|clear) ;;
	*) exit 0 ;;
esac

# Cursor runs hooks detached (no controlling tty), so /dev/tty fails. Walk up to the first ancestor
# that owns a tty (the `agent` process) and write to that device instead.
tty_dev=''
pid=$PPID
while [[ "$pid" -gt 1 ]]; do
	t=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' ') || break
	if [[ -n "$t" && "$t" != '??' && "$t" != '?' ]]; then
		tty_dev="/dev/${t#/dev/}"
		break
	fi
	pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ') || break
	[[ -n "$pid" ]] || break
done
[[ -n "$tty_dev" ]] || exit 0

# Keep stdout free for Cursor's hook protocol; a missing tty must not block it.
{ printf '\033]7501;state=%s:app=cursor-agent\033\\' "$1" > "$tty_dev"; } 2>/dev/null || true
