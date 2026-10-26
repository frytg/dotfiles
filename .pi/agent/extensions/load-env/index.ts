/**
 * Auto-load sops-decrypted env vars for pi.
 *
 * Reads `<agentDir>/../.env.personal` (produced from `.env.personal.sops.yaml`
 * by `just decrypt-env` or `just run`) into the pi process env at extension-load
 * time. Extension modules load before MCP servers connect, so mcp.json
 * interpolations like `${EXA_API_KEY}` and `${GITHUB_PAT}` resolve without any
 * manual sourcing; bash tools and spawned commands inherit the values too.
 *
 * Precedence: values already present in the environment win — the dotenv only
 * fills gaps. A missing file (first launch before decrypt) is a silent no-op.
 */

import { existsSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { getAgentDir } from '@earendil-works/pi-coding-agent'

/**
 * Parses dotenv content: `KEY=value` lines with optional `export` and quotes.
 * @param content raw dotenv file content
 * @returns map of parsed key/value pairs
 */
const parseDotenv = (content: string): Record<string, string> => {
	const out: Record<string, string> = {}
	for (const rawLine of content.split('\n')) {
		const line = rawLine.trim()
		if (line === '' || line.startsWith('#')) continue
		const match = /^(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$/.exec(line)
		if (!match) continue
		out[match[1]!] = match[2]!.trim().replace(/^(['"])(.*)\1$/, '$2')
	}
	return out
}

/**
 * Expands a leading `~` to the home directory; other paths pass through.
 * @param path raw path, possibly `~`-prefixed
 * @returns absolute or unchanged path
 */
const expandHome = (path: string): string => {
	if (path === '~') return process.env.HOME || process.env.USERPROFILE || path
	if (path.startsWith('~/') || path.startsWith('~\\')) {
		const home = process.env.HOME || process.env.USERPROFILE || ''
		return join(home, path.slice(2))
	}
	return path
}

const envPath = join(expandHome(getAgentDir()), '..', '.env.personal')

// keys this extension set in a previous load (same process, e.g. after `/reload`).
// those may be overwritten with fresh values from a re-decrypted file; keys set
// by the shell or launcher always win.
type OwnedKeys = { keys: string[] }
const g = globalThis as Record<string, unknown>
const owned: OwnedKeys = (g.piLoadEnvOwned as OwnedKeys | undefined) ?? { keys: [] }
g.piLoadEnvOwned = owned

if (existsSync(envPath)) {
	for (const [key, value] of Object.entries(parseDotenv(readFileSync(envPath, 'utf8')))) {
		if (process.env[key] === undefined || owned.keys.includes(key)) {
			process.env[key] = value
			if (!owned.keys.includes(key)) owned.keys.push(key)
		}
	}
}

/**
 * No-op factory: all work happens at module load, before the session starts.
 * @param _pi unused extension API handle
 * @returns void
 */
export default function (_pi: unknown): void {}
