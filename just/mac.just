# setup macos defaults
[group('MAC')]
macos:
	zsh ./bin/macos.sh
	just macos-reload

# reload macos defaults
[confirm('This will reload macOS defaults, are you sure? (type `yes` to continue)')]
[group('MAC')]
macos-reload:
	killall Finder
	killall Dock
	killall SystemUIServer
	herdr server stop

# keep the mac awake but lockable: never system-sleep, display may sleep,
# ssh sessions stay reachable. persists across reboots (pmset writes to nvram-backed prefs).
# lock with ctrl+cmd+q — locking does not sleep the machine.
[group('MAC')]
mac-nosleep:
	#!/usr/bin/env zsh
	set -e
	sudo pmset -a sleep 0          # never system-sleep
	sudo pmset -a displaysleep 10  # display off after 10 min (ssh unaffected)
	sudo pmset -a tcpkeepalive 1   # keep network connections alive
	sudo pmset -a ttyskeepawake 1  # active ssh sessions prevent idle sleep
	sudo pmset -a womp 1           # wake on network access
	echo 'ok: pmset configured'
	pmset -g | grep -E 'sleep|displaysleep|tcpkeepalive|ttyskeepawake|womp'
