#!/usr/bin/env bash
# Build a numbered review diff with a file TOC for the code-review skill.
# Bash (not zsh) on purpose: the skill ships to harnesses on hosts without zsh.
#
# Usage: prepare-diff.sh [--staged | --worktree | --base <ref> | --from <sha> | --pr <n>] [--name <file-stem>]
#   no mode flag  auto: dirty tree → --worktree; feature branch → --base <default branch>; else last commit
#   --staged      index vs HEAD
#   --worktree    working tree (incl. untracked, not ignored) vs HEAD
#   --base <ref>  committed changes since merge-base(<ref>, HEAD)
#   --from <sha>  committed changes since exactly <sha> (incremental re-review)
#   --pr <n>      `gh pr diff <n>` (needs an authenticated gh)
#   --name <stem> output file stem inside the state dir (default: diff)
#
# State lives in <repo>/.local/code-review/<branch>/. If .local is not ignored yet, `.local/` is appended to
# the repo .gitignore and the output reports gitignore=added.
# Prints key=value lines on stdout. Exit 2 = usage/git error, 3 = empty diff.
set -euo pipefail

MODE=''
ARG=''
NAME='diff'

die() {
	echo "prepare-diff: $1" >&2
	exit "${2:-2}"
}

while [ $# -gt 0 ]; do
	case "$1" in
	--staged | --worktree) MODE="${1#--}" ;;
	--base | --from | --pr)
		[ $# -ge 2 ] || die "$1 needs a value"
		MODE="${1#--}"
		ARG="$2"
		shift
		;;
	--name)
		[ $# -ge 2 ] || die '--name needs a value'
		NAME="$2"
		shift
		;;
	-h | --help)
		sed -n '2,17p' "$0"
		exit 0
		;;
	*) die "unknown argument: $1" ;;
	esac
	shift
done

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die 'not inside a git work tree'
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

HEAD_SHA="$(git rev-parse --verify -q HEAD || true)"
EMPTY_TREE='4b825dc642cb6eb9a060e54bf8d69288fbee4904'
BRANCH="$(git branch --show-current)"
if [ -n "$BRANCH" ]; then
	SLUG="$(printf '%s' "$BRANCH" | tr '/ ' '__')"
elif [ -n "$HEAD_SHA" ]; then
	SLUG="detached-${HEAD_SHA:0:12}"
else
	SLUG='unborn'
fi

# Append .local/ to the repo .gitignore unless something already ignores it. Called only after
# a non-empty diff succeeds, so empty or failing runs never dirty tracked files.
ensure_ignored() {
	if git check-ignore -q .local/code-review/state.json; then
		echo 'gitignore=ok'
		return
	fi
	{
		if [ -s .gitignore ] && [ -n "$(tail -c1 .gitignore)" ]; then echo; fi
		echo '.local/'
	} >>.gitignore
	echo 'gitignore=added'
}

# Working-tree scans skip .local so state files never review themselves, even before .gitignore covers them.
LOCAL_SPEC=(-- . ':(exclude).local')

# Resolve the default branch: origin/HEAD, then main, then master.
default_branch() {
	local ref
	ref="$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || true)"
	if [ -n "$ref" ]; then
		echo "$ref"
		return
	fi
	for ref in main master origin/main origin/master; do
		if git rev-parse --verify -q "$ref" >/dev/null; then
			echo "$ref"
			return
		fi
	done
}

if [ -z "$MODE" ]; then
	if [ -n "$(git status --porcelain --untracked-files=normal "${LOCAL_SPEC[@]}")" ]; then
		MODE='worktree'
	elif [ -z "$HEAD_SHA" ]; then
		die 'empty repo with no commits or changes' 3
	else
		DEFAULT="$(default_branch)"
		if [ -n "$DEFAULT" ] && [ "$(git rev-parse "$DEFAULT")" != "$HEAD_SHA" ] &&
			[ "${DEFAULT#origin/}" != "$BRANCH" ]; then
			MODE='base'
			ARG="$DEFAULT"
		else
			git rev-parse --verify -q HEAD~1 >/dev/null || die 'clean single-commit repo; pass a mode' 3
			MODE='from'
			ARG='HEAD~1'
		fi
	fi
fi

if [ "$MODE" = 'pr' ]; then
	SLUG="pr-$ARG"
fi
STATE_DIR="$ROOT/.local/code-review/$SLUG"
mkdir -p "$STATE_DIR"

PATCH="$STATE_DIR/$NAME.patch"
OUT="$STATE_DIR/$NAME.md"
DIFF_OPTS=(--no-color --no-ext-diff -M)
export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.quotePath GIT_CONFIG_VALUE_0=false
HEAD_LABEL="$HEAD_SHA"
HEAD_MATCH='yes'

case "$MODE" in
staged)
	BASE_SHA="${HEAD_SHA:-$EMPTY_TREE}"
	LABEL='staged changes vs HEAD'
	git diff "${DIFF_OPTS[@]}" --cached "${LOCAL_SPEC[@]}" >"$PATCH"
	HEAD_LABEL='INDEX'
	;;
worktree)
	BASE_SHA="${HEAD_SHA:-$EMPTY_TREE}"
	LABEL='working tree vs HEAD (incl. untracked)'
	git diff "${DIFF_OPTS[@]}" "$BASE_SHA" "${LOCAL_SPEC[@]}" >"$PATCH"
	# Untracked files without touching the index (no `git add -N`).
	while IFS= read -r -d '' f; do
		git diff "${DIFF_OPTS[@]}" --no-index -- /dev/null "$f" >>"$PATCH" || true
	done < <(git ls-files -z --others --exclude-standard "${LOCAL_SPEC[@]}")
	HEAD_LABEL='WORKTREE'
	;;
base)
	[ -n "$HEAD_SHA" ] || die 'repo has no commits yet'
	BASE_SHA="$(git merge-base "$ARG" HEAD)" || die "no merge-base with $ARG"
	LABEL="${BRANCH:-HEAD} vs $ARG (merge-base ${BASE_SHA:0:12})"
	git diff "${DIFF_OPTS[@]}" "$BASE_SHA" HEAD >"$PATCH"
	;;
from)
	[ -n "$HEAD_SHA" ] || die 'repo has no commits yet'
	BASE_SHA="$(git rev-parse --verify "$ARG^{commit}")" || die "unknown commit: $ARG"
	LABEL="${BRANCH:-HEAD} since ${BASE_SHA:0:12}"
	git diff "${DIFF_OPTS[@]}" "$BASE_SHA" HEAD >"$PATCH"
	;;
pr)
	command -v gh >/dev/null || die 'gh not installed'
	BASE_SHA="$(gh pr view "$ARG" --json baseRefOid -q .baseRefOid)" || die "cannot read PR $ARG"
	HEAD_LABEL="$(gh pr view "$ARG" --json headRefOid -q .headRefOid)"
	[ "$HEAD_SHA" = "$HEAD_LABEL" ] || HEAD_MATCH='no'
	LABEL="PR #$ARG"
	gh pr diff "$ARG" --color=never >"$PATCH"
	;;
esac

[ -s "$PATCH" ] || die "empty diff ($LABEL)" 3

awk -v label="$LABEL" -v base="$BASE_SHA" -v head="$HEAD_LABEL" '
function flush_file() {
	if (path == "") return
	nf++
	fpath[nf] = path; fstat[nf] = stat; fadd[nf] = adds; fdel[nf] = dels
	fstart[nf] = start; fend[nf] = nb
}
function emit(s) { body[++nb] = s }
/^diff --git / {
	flush_file()
	line = $0; sub(/^diff --git a\//, "", line)
	n = index(line, " b/"); path = (n ? substr(line, n + 3) : line)
	stat = "M"; adds = 0; dels = 0; inhunk = 0; old_mode = ""
	emit(""); start = nb + 1; emit("## " path)
	next
}
!inhunk && /^new file mode/ { stat = "A"; next }
!inhunk && /^deleted file mode/ { stat = "D"; next }
!inhunk && /^old mode / { old_mode = substr($0, 10); next }
!inhunk && /^new mode / { emit("(mode changed: " old_mode " -> " substr($0, 10) ")"); next }
!inhunk && /^rename from / { stat = "R"; emit("(renamed from " substr($0, 13) ")"); next }
!inhunk && /^rename to / { path = substr($0, 11); next }
!inhunk && /^Binary files / { emit("(binary file changed)"); next }
!inhunk && /^\+\+\+ / { if ($2 != "/dev/null") { path = substr($0, 5); sub(/^b\//, "", path); sub(/\t$/, "", path) } next }
!inhunk && /^--- / { if ($2 != "/dev/null" && stat == "D") { path = substr($0, 5); sub(/^a\//, "", path); sub(/\t$/, "", path) } next }
/^@@ / {
	inhunk = 1
	split($2, o, ","); split($3, w, ",")
	old = substr(o[1], 2) + 0; new = substr(w[1], 2) + 0
	emit($0)
	next
}
inhunk && /^ / { emit(sprintf("%6d %6d   %s", old, new, substr($0, 2))); old++; new++; next }
inhunk && /^-/ { emit(sprintf("%6d %6s - %s", old, "", substr($0, 2))); old++; dels++; next }
inhunk && /^\+/ { emit(sprintf("%6s %6d + %s", "", new, substr($0, 2))); new++; adds++; next }
inhunk && /^\\/ { emit("              " $0); next }
{ next }
END {
	flush_file()
	for (i = 1; i <= nf; i++) body[fstart[i]] = "## " fpath[i] " [" fstat[i] "]"
	header = 7 + nf
	print "# Review diff"
	print "label: " label
	print "base: " base
	print "head: " head
	print "columns: OLD NEW MARK CODE. Anchor findings on NEW, or on OLD for removed lines."
	print ""
	print "## Files (" nf "): use the line ranges as the coverage checklist"
	for (i = 1; i <= nf; i++)
		printf "- %s [%s] +%d -%d: L%d-L%d\n", fpath[i], fstat[i], fadd[i], fdel[i], fstart[i] + header, fend[i] + header
	for (i = 1; i <= nb; i++) print body[i]
	printf "files=%d\n", nf > "/dev/stderr"
}
' "$PATCH" >"$OUT" 2>"$STATE_DIR/.$NAME.count"

FILES="$(sed -n 's/^files=//p' "$STATE_DIR/.$NAME.count")"
rm -f "$STATE_DIR/.$NAME.count"

echo "root=$ROOT"
echo "branch=${BRANCH:-}"
echo "state_dir=$STATE_DIR"
echo "diff=$OUT"
echo "patch=$PATCH"
echo "mode=$MODE"
echo "label=$LABEL"
echo "base=$BASE_SHA"
echo "head=$HEAD_LABEL"
echo "head_match=$HEAD_MATCH"
echo "files=$FILES"
echo "lines=$(wc -l <"$OUT" | tr -d ' ')"
ensure_ignored
