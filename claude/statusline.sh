#!/bin/zsh
# claude code status line: model, context, session cost, and plan rate limits.
# also caches the rate limits for the herdr-app status bar.

payload=$(cat)

# Keep previous windows when Claude sends a partial snapshot; Herdr handles expired resets.
usage_cache="$HOME/.cache/claude-usage.json"
if print -r -- "$payload" | jq -e '.rate_limits' >/dev/null 2>&1; then
	mkdir -p "${usage_cache:h}"
	print -r -- "$payload" | jq -c --slurpfile previous <(jq -c 'objects' "$usage_cache" 2>/dev/null) '
		($previous[0] // {}) + (.rate_limits | objects | with_entries(select(.value != null))) + {updated_at: now}
	' >"$usage_cache.$$.tmp" 2>/dev/null &&
		mv -f "$usage_cache.$$.tmp" "$usage_cache"
fi

print -r -- "$payload" | jq -r '
	def pct: if . == null then "–" else "\(. | floor)%" end;
	def reset:
		if . == null then ""
		else ((. - now) / 60 | ceil | if . > 0 then . else 0 end) as $m
			| " ↻" + (if $m >= 60 then "\($m / 60 | floor)h\($m % 60)m" else "\($m)m" end)
		end;
	[
		(.model.display_name // "claude"),
		"ctx " + (.context_window.used_percentage | pct),
		"$" + ((.cost.total_cost_usd // 0) * 100 | round / 100 | tostring),
		(if .rate_limits.five_hour then "5h " + (.rate_limits.five_hour.used_percentage | pct) + (.rate_limits.five_hour.resets_at | reset) else empty end),
		(if .rate_limits.seven_day then "7d " + (.rate_limits.seven_day.used_percentage | pct) else empty end)
	] | join(" · ")
' 2>/dev/null || print "claude"
