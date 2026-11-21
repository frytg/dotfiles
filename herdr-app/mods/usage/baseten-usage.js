// Month-to-date spend from Baseten's billing API: https://docs.baseten.co/organization/billing
const BASETEN_USAGE_URL = 'https://api.baseten.co/v1/billing/usage_summary'
const BASETEN_KEY_COMMAND = `
set -e
token_file="$HOME/.config/1Password/herdr.token"
[[ -s "$token_file" ]] || exit 1
export OP_SERVICE_ACCOUNT_TOKEN="$(< "$token_file")"
unset OP_CONNECT_HOST OP_CONNECT_TOKEN
op read 'op://Agentic/Baseten API/credential'
`

/**
 * Read the Baseten API key from 1Password using the SSH loader's service account.
 * @param {Function} exec Herdr's command runner.
 * @returns {Promise<string|null>} The in-memory key, or null when unavailable.
 */
export const readBasetenKey = async (exec) => {
	try {
		// Read the token inside the child shell, never into command arguments or files.
		const result = await exec('zsh', ['-f', '-c', BASETEN_KEY_COMMAND])
		return result.code === 0 ? result.stdout.trim() || null : null
	} catch {
		// Missing commands and inaccessible 1Password items are not credentials.
		return null
	}
}

/**
 * Parse a dollar amount that the API sends as a number or a decimal string.
 * @param {unknown} value A money field from the API.
 * @returns {number} Dollars, or 0 for missing or invalid values.
 */
const dollars = (value) => {
	const n = typeof value === 'string' ? Number(value) : value
	return typeof n === 'number' && Number.isFinite(n) ? n : 0
}

/**
 * Format epoch milliseconds as an ISO 8601 timestamp without milliseconds, as the API docs show.
 * @param {number} ms Epoch milliseconds.
 * @returns {string} A timestamp like `2026-07-29T00:00:00Z`.
 */
const isoSeconds = (ms) => new Date(ms).toISOString().replace(/\.\d{3}Z$/, 'Z')

/**
 * Load this UTC month's usage charges without exposing response bodies in errors.
 * A 401 or 403 sets `status` on the error, because billing needs an admin's personal key.
 * @param {Function} request Herdr's fetch implementation.
 * @param {string} key The API key, kept in memory.
 * @param {number} now Current epoch milliseconds.
 * @returns {Promise<{spend: number, resets_at: number}>} Dollars before credits, and the month's end in epoch seconds.
 */
export const readBaseten = async (request, key, now = Date.now()) => {
	const today = new Date(now)
	const year = today.getUTCFullYear()
	const month = today.getUTCMonth()
	const start = Date.UTC(year, month, 1)
	const monthEnd = Date.UTC(year, month + 1, 1)
	// End at the next UTC midnight so today's hourly updates count, but never past the month.
	const end = Math.min(Date.UTC(year, month, today.getUTCDate() + 1), monthEnd)
	const query = `start_date=${isoSeconds(start)}&end_date=${isoSeconds(end)}`
	const response = await request(`${BASETEN_USAGE_URL}?${query}`, {
		headers: { Authorization: `Bearer ${key}`, Accept: 'application/json' },
	})
	if (!response.ok) throw Object.assign(new Error(`Baseten HTTP ${response.status}`), { status: response.status })
	const summary = await response.json()
	// Each product (dedicated, Model APIs, training, loops, ...) is a top-level object with a pre-credit `subtotal`.
	// Sum them all, because the API returns products the docs don't list yet.
	const sections = Object.values(summary ?? {}).filter((s) => s && typeof s === 'object' && 'subtotal' in s)
	return {
		spend: sections.reduce((sum, s) => sum + dollars(s.subtotal), 0),
		resets_at: monthEnd / 1000,
	}
}
