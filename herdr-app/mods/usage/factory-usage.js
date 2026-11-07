// Billing payload and reset rules follow CodexBar's FactoryStatusProbe:
// https://github.com/steipete/CodexBar/blob/main/Sources/CodexBarCore/Providers/Factory/FactoryStatusProbe.swift
const FACTORY_LIMITS_URL = 'https://api.factory.ai/api/billing/limits';
const FACTORY_KEY_COMMAND = `
set -e
token_file="$HOME/.config/1Password/herdr.token"
[[ -s "$token_file" ]] || exit 1
export OP_SERVICE_ACCOUNT_TOKEN="$(< "$token_file")"
unset OP_CONNECT_HOST OP_CONNECT_TOKEN
op read 'op://Agentic/Factory API Key herdr/password'
`;
const ROLLING_WINDOWS = [
	['fiveHour', '5h'],
	['weekly', '7d'],
	['monthly', '30d'],
];

/**
 * Read the dedicated 1Password API key using the SSH loader's service account.
 * @param {Function} exec Herdr's command runner.
 * @returns {Promise<string|null>} The in-memory key, or null when unavailable.
 */
export const readFactoryKey = async (exec) => {
	try {
		// Read the token inside the child shell, never into command arguments or files.
		const result = await exec('zsh', ['-f', '-c', FACTORY_KEY_COMMAND]);
		return result.code === 0 ? result.stdout.trim() || null : null;
	} catch {
		// Missing commands and inaccessible 1Password items are not credentials.
		return null;
	}
};

/**
 * Normalize Factory's numeric or ISO reset dates to epoch seconds.
 * @param {unknown} value A reset date from the API.
 * @returns {number|null} Epoch seconds, or null for missing or invalid dates.
 */
const resetSeconds = (value) => {
	if (value == null || value === '') return null;
	const numeric = typeof value === 'number' ? value
		: typeof value === 'string' && /^\d+(\.\d+)?$/.test(value) ? Number(value) : null;
	const seconds = numeric == null
		? (typeof value === 'string' ? Date.parse(value) / 1000 : Number.NaN)
		: numeric > 1e12 ? numeric / 1000 : numeric;
	return Number.isFinite(seconds) ? seconds : null;
};

/**
 * Convert one reported rolling window, including Factory's expired-window rule.
 * @param {object} window A billing window.
 * @param {number} now Current epoch seconds.
 * @returns {object|null} A meter value, or null when usage was not reported.
 */
const rollingWindow = (window, now) => {
	if (!window || !Number.isFinite(window.usedPercent)) return null;
	const end = resetSeconds(window.windowEnd);
	const remaining = window.secondsRemaining;
	const reset = Number.isFinite(remaining) && remaining > 0 ? now + remaining
		: end != null && end > now ? end : null;
	// Match Factory's web UI: only an explicitly expired end without a countdown resets usage.
	const expired = end != null && end <= now && remaining == null;
	return {
		used: expired ? 0 : Math.min(100, Math.max(0, window.usedPercent)),
		resets_at: reset,
	};
};

/**
 * Load Standard rolling quotas without exposing response bodies in errors.
 * @param {Function} request Herdr's fetch implementation.
 * @param {string} key The API key, kept in memory.
 * @param {number} now Current epoch seconds.
 * @returns {Promise<object[]>} Named meters for the usage panel.
 */
export const readFactory = async (request, key, now = Date.now() / 1000) => {
	const response = await request(FACTORY_LIMITS_URL, {
		headers: {
			Authorization: `Bearer ${key}`,
			Accept: 'application/json',
			'Content-Type': 'application/json',
			Origin: 'https://app.factory.ai',
			Referer: 'https://app.factory.ai/',
			'x-factory-client': 'web-app',
		},
	});
	if (!response.ok) throw new Error(`Factory HTTP ${response.status}`);
	const limits = await response.json();
	if (limits?.usesTokenRateLimitsBilling !== true) throw new Error('Factory rolling quotas unavailable');
	const meters = ROLLING_WINDOWS.flatMap(([field, label]) => {
		const w = rollingWindow(limits.limits?.standard?.[field], now);
		return w ? [{ id: `factory-${label}`, name: `Factory ${label}`, w }] : [];
	});
	if (!meters.length) throw new Error('Factory quota data missing');
	return meters;
};
