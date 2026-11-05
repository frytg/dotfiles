#!/bin/zsh -f
set -e

# Read Droid's payload once, keeping spaces and newlines in paths intact.
{
	IFS= read -r -d '' model
	IFS= read -r -d '' directory
	IFS= read -r -d '' context
} < <(jq -j '[
	.model.display_name // "Droid",
	.cwd // .workspace.current_dir // ".",
	.context.display // ""
] | .[] | ., "\u0000"')

if ! branch=$(git --no-optional-locks -C "$directory" symbolic-ref --quiet --short HEAD 2>/dev/null); then
	branch=$(git --no-optional-locks -C "$directory" rev-parse --short HEAD 2>/dev/null) || branch=''
fi

directory_name=${directory:t}
directory_name=${directory_name:-/}

# Keep terminal control characters out of the single rendered row.
printf '%s · %s' "${model//[[:cntrl:]]/}" "${directory_name//[[:cntrl:]]/}"
[[ -z "$branch" ]] || printf ' · %s' "${branch//[[:cntrl:]]/}"
[[ -z "$context" ]] || printf ' · ctx %s' "${context//[[:cntrl:]]/}"
printf '\n'
