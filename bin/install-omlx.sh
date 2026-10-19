#!/usr/bin/env zsh
# install/upgrade the latest oMLX macOS app from GitHub releases, including beta
# https://github.com/jundot/omlx/releases
set -euo pipefail

[[ "$(uname)" == 'Darwin' ]] || { echo 'error: oMLX is macOS-only' >&2; exit 1; }
[[ "$(uname -m)" == 'arm64' ]] || { echo 'error: oMLX requires Apple Silicon' >&2; exit 1; }
command -v jq >/dev/null || { echo 'error: jq not on PATH' >&2; exit 1; }

# DMG suffix by macOS major version
os_major=$(sw_vers -productVersion); os_major=${os_major%%.*}
case "$os_major" in
	15) suffix='-macos15-sequoia.dmg' ;;
	26|27) suffix='-macos26-27.dmg' ;;
	*) echo "error: no oMLX DMG for macOS ${os_major}" >&2; exit 1 ;;
esac

workdir=$(mktemp -d "${TMPDIR:-/tmp}/omlx-install.XXXXXX")
trap 'hdiutil detach "$workdir/mnt" -quiet 2>/dev/null; rm -rf "$workdir"' EXIT
mkdir -p "$workdir/mnt"

# Find newest release with matching DMG (prereleases included)
api='https://api.github.com/repos/jundot/omlx/releases?per_page=20'
releases=$(curl -fsSL -H 'Accept: application/vnd.github+json' -A 'dotfiles-install-omlx' "$api")

line=$(jq -r --arg suffix "$suffix" '
	sort_by(.published_at) | reverse
	| map(. as $r | $r.assets[] | select(.name | endswith($suffix)) | [$r.tag_name, .browser_download_url, .name, (.digest // "")] | @tsv)
	| first // empty
' <<< "$releases")

[[ -n "$line" ]] || { echo "error: no oMLX release asset matching *${suffix}" >&2; exit 1; }

IFS=$'\t' read -r tag url asset digest <<< "$line"
version=${tag#v}

# Skip if already installed at this version
plist='/Applications/oMLX.app/Contents/Info.plist'
installed=$(defaults read "$plist" CFBundleShortVersionString 2>/dev/null || true)
if [[ "$installed" == "$version" ]]; then
	echo "ok: oMLX ${installed} already installed"
	exit 0
fi

if [[ -n "$installed" ]]; then
	echo "upgrading oMLX ${installed} -> ${version}"
else
	echo "installing oMLX ${version}"
fi
echo "release: https://github.com/jundot/omlx/releases/tag/${tag}"
echo "asset: ${asset}"

# Download
dmg="$workdir/$asset"
curl -fL --retry 3 --retry-delay 2 --progress-bar -o "$dmg" "$url"

# Verify checksum if available
if [[ "$digest" == sha256:* ]]; then
	expected=${digest#sha256:}
	actual=$(shasum -a 256 "$dmg" | awk '{print $1}')
	[[ "$actual" == "$expected" ]] || { echo "error: checksum mismatch for ${asset}" >&2; exit 1; }
	echo 'ok: checksum'
fi

# Stop running oMLX (brew service + app + server)
brew services stop omlx 2>/dev/null || true
if pgrep -xq oMLX || pgrep -xq omlx-server; then
	echo 'stopping oMLX'
	killall oMLX omlx-server 2>/dev/null || true
	sleep 1
	killall -9 oMLX omlx-server 2>/dev/null || true
fi

# Mount and install
hdiutil attach -nobrowse -readonly -quiet -mountpoint "$workdir/mnt" "$dmg"
# Prefer oMLX.app by name; fall back to any .app if the DMG layout changes
app=''
for candidate in "$workdir/mnt"/oMLX.app(N) "$workdir/mnt"/*/oMLX.app(N) "$workdir/mnt"/*.app(N) "$workdir/mnt"/*/*.app(N); do
	[[ -e "$candidate" ]] || continue
	app=$candidate
	break
done
[[ -n "$app" ]] || { echo 'error: DMG contains no .app' >&2; exit 1; }

dest="/Applications/${app:t}"
staged="/Applications/.${dest:t}.installing"
backup="${dest}.previous"

rm -rf "$staged" "$backup"
ditto "$app" "$staged"
xattr -dr com.apple.quarantine "$staged" 2>/dev/null || true
[[ -d "$dest" ]] && mv "$dest" "$backup"
if ! mv "$staged" "$dest"; then
	echo 'error: failed to install; restoring previous app' >&2
	[[ -d "$backup" ]] && mv "$backup" "$dest"
	exit 1
fi
rm -rf "$backup"

echo "ok: installed oMLX $(defaults read "$dest/Contents/Info.plist" CFBundleShortVersionString) to ${dest}"
echo 'reopen oMLX to run this version'
