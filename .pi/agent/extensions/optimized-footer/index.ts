/**
 * Optimized footer for pi.
 *
 * Two-line status replacing the default footer:
 *   repo · branch@host · mcp · model · thinking
 *   tokens · cache · reasoning · cost · context bar
 *
 * Token/cost totals come from session usage (OpenRouter-reported when available).
 * MCP status is inferred from mcp.json, mcp-cache.json, and registered tools.
 * Git remote host is derived from `remote.origin.url` (github, tangled, …).
 *
 * Toggle: /opt-footer
 */

import { execFileSync } from 'node:child_process'
import { existsSync, readFileSync } from 'node:fs'
import { basename, join } from 'node:path'
import type { AssistantMessage, Usage } from '@earendil-works/pi-ai'
import { type ExtensionAPI, type ExtensionContext, getAgentDir, type Theme } from '@earendil-works/pi-coding-agent'
import { truncateToWidth, visibleWidth } from '@earendil-works/pi-tui'

type ThinkingLevel = 'off' | 'minimal' | 'low' | 'medium' | 'high' | 'xhigh' | 'max'
type ThemeFg = Parameters<Theme['fg']>[0]

type UsageBucket = {
	input: number
	output: number
	cacheRead: number
	cacheWrite: number
	reasoning: number
	cost: number
	lastCost: number
	lastTotalTokens: number
	lastCacheHitPct: number | undefined
}

type McpSummary = {
	configured: number
	statusLabel: string
	tone: ThemeFg
}

type McpProbe = {
	toolCount: number
	directCount: number
	serverHints: string[]
}

type FooterData = {
	getGitBranch: () => string | null
	getExtensionStatuses: () => ReadonlyMap<string, string>
	onBranchChange: (cb: () => void) => () => void
}

type FooterTui = {
	requestRender: () => void
}

const SEP = ' · '

const EMPTY_USAGE: UsageBucket = {
	input: 0,
	output: 0,
	cacheRead: 0,
	cacheWrite: 0,
	reasoning: 0,
	cost: 0,
	lastCost: 0,
	lastTotalTokens: 0,
	lastCacheHitPct: undefined,
}

/** Latest extension statuses observed during footer render. */
let latestFooterStatuses: ReadonlyMap<string, string> | undefined

/** Cached MCP probe built from pi.getAllTools(). */
let mcpProbe: McpProbe | undefined

/** Cache for git remote host lookups, keyed by cwd. */
const remoteHostCache = new Map<string, { host: string | null; checkedAt: number }>()

/** How long to trust a remote-host cache entry. */
const REMOTE_HOST_TTL_MS = 15_000

/**
 * Known forges mapped to short footer labels.
 */
const REMOTE_HOST_LABELS: Record<string, string> = {
	'github.com': 'github',
	'www.github.com': 'github',
	'gitlab.com': 'gitlab',
	'www.gitlab.com': 'gitlab',
	'bitbucket.org': 'bitbucket',
	'www.bitbucket.org': 'bitbucket',
	'tangled.org': 'tangled',
	'tangled.sh': 'tangled',
	'codeberg.org': 'codeberg',
	'git.sr.ht': 'sourcehut',
	'sr.ht': 'sourcehut',
	'gitlab.gnome.org': 'gnome',
	'gitea.com': 'gitea',
	'code.googlesource.com': 'googlesource',
	'ssh.dev.azure.com': 'azure',
	'dev.azure.com': 'azure',
}

/**
 * Collapse a remote URL hostname into a short forge label.
 * @param hostname Raw hostname from the remote URL.
 * @returns Short label for the footer.
 */
const labelRemoteHost = (hostname: string): string => {
	const host = hostname.trim().toLowerCase().replace(/\.$/, '')
	if (!host) return 'remote'
	if (REMOTE_HOST_LABELS[host]) return REMOTE_HOST_LABELS[host]!
	// strip leading www.
	const bare = host.startsWith('www.') ? host.slice(4) : host
	if (REMOTE_HOST_LABELS[bare]) return REMOTE_HOST_LABELS[bare]!
	// nested gitlab/github enterprise style: gitlab.company.com -> company
	const parts = bare.split('.').filter(Boolean)
	if (parts.length >= 3 && (parts[0] === 'gitlab' || parts[0] === 'github' || parts[0] === 'git')) {
		return parts[1]!
	}
	// common two-level domain
	if (parts.length >= 2) return parts[parts.length - 2]!
	return bare
}

/**
 * Parse host label from a git remote URL.
 * Supports ssh, https, scp-like, and file URLs.
 * @param url Remote URL string.
 * @returns Short host label, or null if local/unparseable.
 */
const hostFromRemoteUrl = (url: string): string | null => {
	const raw = url.trim()
	if (!raw) return null

	// file:// or absolute/relative local path — no remote forge
	if (
		raw.startsWith('file://') ||
		raw.startsWith('/') ||
		raw.startsWith('./') ||
		raw.startsWith('../') ||
		raw.startsWith('~')
	) {
		return 'local'
	}

	// git@host:path or ssh://git@host/path or https://host/path
	// scp-like: git@tangled.org:user/repo
	const scp = /^(?:(?<user>[^@/]+)@)?(?<host>[^:/]+)(?::|\/)(?!\/)/.exec(raw)
	if (scp && !raw.includes('://') && scp.groups?.host && !raw.startsWith(scp.groups.host + '://')) {
		// only treat as scp if it looks like user@host:path (has user@ or host:path without scheme)
		if (raw.includes('@') || /^[A-Za-z0-9._-]+:[^/]/.test(raw)) {
			return labelRemoteHost(scp.groups.host)
		}
	}

	try {
		// Normalize git+ssh and ssh schemes for URL parser
		const normalized = raw
			.replace(/^git\+ssh:\/\//i, 'ssh://')
			.replace(/^git:\/\//i, 'http://')
			.replace(/^ssh:\/\/([^@/]+@)?/i, 'https://')
			.replace(/^git@/i, 'https://') // git@host:path already handled; this is rare
		// scp after git@ rewrite fails; handle pure https/http/ssh
		if (raw.includes('://')) {
			const u = new URL(raw.replace(/^git\+ssh:/i, 'ssh:').replace(/^ssh:/i, 'https:'))
			if (u.hostname) return labelRemoteHost(u.hostname)
		}
		// fallback: try https:// on scp remaining
		if (raw.includes('@') && raw.includes(':')) {
			const host = raw.split('@')[1]?.split(':')[0]
			if (host) return labelRemoteHost(host)
		}
		void normalized
	} catch {
		// fall through
	}

	// last-ditch: host from user@host:path
	const at = raw.indexOf('@')
	if (at >= 0) {
		const rest = raw.slice(at + 1)
		const host = rest.split(/[:/]/)[0]
		if (host) return labelRemoteHost(host)
	}

	return null
}

/**
 * Read origin (or first) remote URL for a working tree.
 * @param cwd Working directory.
 * @returns Remote URL string, or null.
 */
const readGitRemoteUrl = (cwd: string): string | null => {
	try {
		const origin = execFileSync('git', ['-C', cwd, 'config', '--get', 'remote.origin.url'], {
			encoding: 'utf8',
			timeout: 400,
			stdio: ['ignore', 'pipe', 'ignore'],
		}).trim()
		if (origin) return origin
	} catch {
		// no origin
	}
	try {
		const fallback = execFileSync('git', ['-C', cwd, 'remote', 'get-url', '--all', 'origin'], {
			encoding: 'utf8',
			timeout: 400,
			stdio: ['ignore', 'pipe', 'ignore'],
		})
			.split(/\r?\n/)
			.map((l) => l.trim())
			.find(Boolean)
		if (fallback) return fallback
	} catch {
		// ignore
	}
	try {
		// first configured remote if origin missing
		const names = execFileSync('git', ['-C', cwd, 'remote'], {
			encoding: 'utf8',
			timeout: 400,
			stdio: ['ignore', 'pipe', 'ignore'],
		})
			.split(/\r?\n/)
			.map((l) => l.trim())
			.filter(Boolean)
		const first = names[0]
		if (!first) return null
		const url = execFileSync('git', ['-C', cwd, 'remote', 'get-url', first], {
			encoding: 'utf8',
			timeout: 400,
			stdio: ['ignore', 'pipe', 'ignore'],
		}).trim()
		return url || null
	} catch {
		return null
	}
}

/**
 * Resolve a short git remote host label for the footer.
 * Cached briefly per cwd; forceRefresh bypasses TTL (e.g. on branch change).
 * @param cwd Working directory.
 * @param forceRefresh Bypass cache TTL.
 * @returns Host label or null when not a git remote checkout.
 */
const getGitRemoteHost = (cwd: string, forceRefresh = false): string | null => {
	const now = Date.now()
	const cached = remoteHostCache.get(cwd)
	if (!forceRefresh && cached && now - cached.checkedAt < REMOTE_HOST_TTL_MS) {
		return cached.host
	}
	const url = readGitRemoteUrl(cwd)
	const host = url ? hostFromRemoteUrl(url) : null
	remoteHostCache.set(cwd, { host, checkedAt: now })
	return host
}

/**
 * Expand a path that may start with `~`.
 * @param path Candidate path.
 * @returns Absolute path with home expanded.
 */
const expandHome = (path: string): string => {
	if (path === '~') return process.env.HOME || process.env.USERPROFILE || path
	if (path.startsWith('~/') || path.startsWith('~\\')) {
		const home = process.env.HOME || process.env.USERPROFILE || ''
		return join(home, path.slice(2))
	}
	return path
}

/**
 * Resolve the active pi agent directory, honoring PI_CODING_AGENT_DIR.
 * @returns Absolute agent dir path.
 */
const resolveAgentDir = (): string => {
	try {
		return expandHome(getAgentDir())
	} catch {
		const fromEnv = process.env.PI_CODING_AGENT_DIR
		if (fromEnv) return expandHome(fromEnv)
		const home = process.env.HOME || process.env.USERPROFILE || ''
		return join(home, '.pi', 'agent')
	}
}

/**
 * Safely parse a JSON file.
 * @param path File path.
 * @returns Parsed object or undefined.
 */
const readJson = (path: string): unknown => {
	try {
		if (!existsSync(path)) return undefined
		return JSON.parse(readFileSync(path, 'utf8')) as unknown
	} catch {
		return undefined
	}
}

/**
 * Format a compact token/count value.
 * @param count Numeric count.
 * @returns Compact display string.
 */
const formatCount = (count: number): string => {
	const n = Math.max(0, Math.round(count))
	if (n < 1000) return `${n}`
	if (n < 10_000) return `${(n / 1000).toFixed(1)}k`
	if (n < 1_000_000) return `${Math.round(n / 1000)}k`
	if (n < 10_000_000) return `${(n / 1_000_000).toFixed(1)}M`
	return `${Math.round(n / 1_000_000)}M`
}

/**
 * Format OpenRouter/session USD cost with useful precision.
 * @param cost Cost in dollars.
 * @returns Display string including `$`.
 */
const formatCost = (cost: number): string => {
	if (!Number.isFinite(cost) || cost <= 0) return '$0'
	if (cost < 0.0001) return `$${cost.toExponential(1)}`
	if (cost < 0.01) return `$${cost.toFixed(4)}`
	if (cost < 1) return `$${cost.toFixed(3)}`
	if (cost < 100) return `$${cost.toFixed(2)}`
	return `$${cost.toFixed(1)}`
}

/**
 * Shorten a model id for footer display.
 * @param modelId Full model id.
 * @returns Compact model label.
 */
const formatModelId = (modelId: string): string => {
	let id = modelId
	if (id.startsWith('~')) id = id.slice(1)
	const slash = id.lastIndexOf('/')
	if (slash >= 0) {
		const leaf = id.slice(slash + 1)
		if (leaf.length >= 4) id = leaf
	}
	return id
		.replace(/-latest$/i, '')
		.replace(/-it-6bit$/i, '')
		.replace(/-8bit$/i, '')
}

/**
 * Map thinking level to theme color token.
 * @param level Active thinking level.
 * @returns Theme foreground key.
 */
const thinkingColor = (level: ThinkingLevel): ThemeFg => {
	switch (level) {
		case 'off':
			return 'thinkingOff'
		case 'minimal':
			return 'thinkingMinimal'
		case 'low':
			return 'thinkingLow'
		case 'medium':
			return 'thinkingMedium'
		case 'high':
			return 'thinkingHigh'
		case 'xhigh':
			return 'thinkingXhigh'
		case 'max':
			return 'thinkingMax'
		default:
			return 'muted'
	}
}

/**
 * Short thinking badge text.
 * @param level Active thinking level.
 * @param supportsReasoning Whether model supports reasoning.
 * @returns Display label.
 */
const formatThinking = (level: ThinkingLevel, supportsReasoning: boolean): string => {
	if (!supportsReasoning) return 'no-think'
	if (level === 'off') return 'think off'
	if (level === 'xhigh') return 'xhigh'
	return level
}

/**
 * Build a single-line unicode context bar.
 * @param percent Context fill percent 0-100, or null if unknown.
 * @param width Bar width in cells.
 * @returns Bar string.
 */
const contextBar = (percent: number | null, width = 10): string => {
	const w = Math.max(4, width)
	if (percent === null || !Number.isFinite(percent)) return '░'.repeat(w)
	const clamped = Math.max(0, Math.min(100, percent))
	const filled = Math.round((clamped / 100) * w)
	return `${'█'.repeat(filled)}${'░'.repeat(w - filled)}`
}

/**
 * Extract MCP server names from a config-like object.
 * @param value Parsed JSON.
 * @returns Server name list.
 */
const serverNamesFromConfig = (value: unknown): string[] => {
	if (!value || typeof value !== 'object') return []
	const servers = (value as { mcpServers?: unknown }).mcpServers
	if (!servers || typeof servers !== 'object') return []
	return Object.keys(servers as Record<string, unknown>)
}

/**
 * Collect configured MCP server names from common config locations.
 * @param cwd Current working directory.
 * @returns Unique server names in discovery order.
 */
const collectConfiguredMcpServers = (cwd: string): string[] => {
	const agentDir = resolveAgentDir()
	const home = process.env.HOME || process.env.USERPROFILE || ''
	const paths = [
		join(home, '.config', 'mcp', 'mcp.json'),
		join(agentDir, 'mcp.json'),
		join(cwd, '.mcp.json'),
		join(cwd, '.pi', 'mcp.json'),
	]
	const names: string[] = []
	const seen = new Set<string>()
	for (const path of paths) {
		for (const name of serverNamesFromConfig(readJson(path))) {
			if (seen.has(name)) continue
			seen.add(name)
			names.push(name)
		}
	}
	return names
}

/**
 * Count servers present in the metadata cache.
 * @returns Number of cached servers.
 */
const countCachedMcpServers = (): number => {
	const cache = readJson(join(resolveAgentDir(), 'mcp-cache.json'))
	if (!cache || typeof cache !== 'object') return 0
	const servers = (cache as { servers?: unknown }).servers
	if (!servers || typeof servers !== 'object') return 0
	return Object.keys(servers as Record<string, unknown>).length
}

/**
 * Refresh MCP probe from ExtensionAPI tool metadata.
 * @param pi Extension API.
 * @param configured Configured server names.
 */
const refreshMcpProbe = (pi: ExtensionAPI, configured: string[]): void => {
	try {
		const tools = pi.getAllTools()
		const lowerConfigured = configured.map((n) => n.toLowerCase())
		const prefixes = configured.map((n) => n.replace(/-/g, '_').toLowerCase())
		let toolCount = 0
		let directCount = 0
		const hints = new Set<string>()

		for (const tool of tools) {
			const name = tool.name.toLowerCase()
			const src = `${tool.sourceInfo.path} ${tool.sourceInfo.source}`.toLowerCase()
			const fromMcpAdapter =
				src.includes('pi-mcp-adapter') || src.includes('mcp-adapter') || name === 'mcp' || name.startsWith('mcp_')

			const matchedIdx = prefixes.findIndex((p) => p && (name === p || name.startsWith(`${p}_`)))

			if (!fromMcpAdapter) {
				if (matchedIdx < 0) continue
				toolCount += 1
				directCount += 1
				hints.add(configured[matchedIdx]!)
				continue
			}

			toolCount += 1
			if (name !== 'mcp') {
				directCount += 1
				if (matchedIdx >= 0) {
					hints.add(configured[matchedIdx]!)
				} else {
					const head = name.split('_')[0] ?? ''
					const idx = lowerConfigured.findIndex((n) => n.replace(/-/g, '') === head.replace(/-/g, ''))
					if (idx >= 0) hints.add(configured[idx]!)
				}
			}
		}

		mcpProbe = {
			toolCount,
			directCount,
			serverHints: [...hints],
		}
	} catch {
		mcpProbe = undefined
	}
}

/**
 * Summarize MCP availability from config, cache, and registered tools.
 *
 * Important: this does not measure live socket connections. pi-mcp-adapter keeps
 * servers lazy by default, so stock UI often showed 0/2 connected while both
 * servers still had cached metadata/directTools. We report readiness, not sockets.
 *
 * @param _ctx Extension context (reserved for future live probes).
 * @returns MCP summary for footer display.
 */
const summarizeMcp = (_ctx: ExtensionContext): McpSummary => {
	const configuredNames = collectConfiguredMcpServers(_ctx.cwd)
	const configured = configuredNames.length
	const cached = countCachedMcpServers()
	const probe = mcpProbe

	const registeredMcpTools = probe?.toolCount ?? 0
	const directTools = probe?.directCount ?? 0
	// Servers with registered direct tools (from cache) — not live connections.
	const readyServers = probe?.serverHints.length ?? 0

	let authNeeded = false
	let authLabel = ''
	if (latestFooterStatuses) {
		for (const [key, text] of latestFooterStatuses.entries()) {
			if (/auth/i.test(key) || /auth/i.test(text)) {
				authNeeded = true
				authLabel = text.replace(/[\r\n\t]+/g, ' ').trim()
			}
		}
	}

	if (configured === 0 && cached === 0 && registeredMcpTools === 0) {
		return { configured, statusLabel: 'mcp off', tone: 'dim' }
	}
	if (authNeeded) {
		const shortAuth = authLabel && authLabel.length <= 28 ? authLabel : `auth ${configured || cached || '?'}`
		return {
			configured,
			statusLabel: `mcp ${shortAuth}`,
			tone: 'warning',
		}
	}

	// Prefer “ready N” over ambiguous N/M so lazy-but-configured isn’t read as live.
	if (directTools > 0 || readyServers > 0) {
		const ready = readyServers || configured || cached
		const total = configured || ready
		const tools = directTools > 0 ? ` · ${formatCount(directTools)}t` : ''
		return {
			configured,
			statusLabel: `mcp ready ${ready}/${total}${tools}`,
			tone: 'success',
		}
	}
	if (registeredMcpTools > 0 || cached > 0 || configured > 0) {
		return {
			configured,
			statusLabel: `mcp ${configured || cached} lazy`,
			tone: 'muted',
		}
	}
	return {
		configured,
		statusLabel: 'mcp off',
		tone: 'dim',
	}
}

/**
 * Sum session usage across all attributable entries.
 * @param ctx Extension context.
 * @returns Aggregated usage bucket.
 */
const collectUsage = (ctx: ExtensionContext): UsageBucket => {
	const out: UsageBucket = { ...EMPTY_USAGE }
	let last: Usage | undefined

	for (const entry of ctx.sessionManager.getEntries()) {
		let usage: Usage | undefined
		if (entry.type === 'message' && entry.message.role === 'assistant') {
			usage = (entry.message as AssistantMessage).usage
		} else if (entry.type === 'message' && entry.message.role === 'toolResult' && entry.message.usage) {
			usage = entry.message.usage
		} else if ((entry.type === 'branch_summary' || entry.type === 'compaction') && entry.usage) {
			usage = entry.usage
		}
		if (!usage) continue

		out.input += usage.input || 0
		out.output += usage.output || 0
		out.cacheRead += usage.cacheRead || 0
		out.cacheWrite += usage.cacheWrite || 0
		if (typeof usage.reasoning === 'number') out.reasoning += usage.reasoning
		out.cost += usage.cost?.total || 0
		last = usage
	}

	if (last) {
		out.lastCost = last.cost?.total || 0
		out.lastTotalTokens = last.totalTokens || last.input + last.output + last.cacheRead + last.cacheWrite
		const prompt = (last.input || 0) + (last.cacheRead || 0) + (last.cacheWrite || 0)
		out.lastCacheHitPct = prompt > 0 ? (last.cacheRead / prompt) * 100 : undefined
	}

	return out
}

/**
 * Join themed segments with a dim separator, dropping empties.
 * @param theme Active theme.
 * @param parts Segment strings (already colored).
 * @returns Joined line.
 */
const joinSegments = (theme: Theme, parts: Array<string | undefined | false>): string => {
	const sep = theme.fg('dim', SEP)
	return parts.filter((p): p is string => typeof p === 'string' && p.length > 0).join(sep)
}

/**
 * Pad left and right segments into a full-width line.
 * @param left Left content.
 * @param right Right content.
 * @param width Terminal width.
 * @returns Single display line.
 */
const splitLine = (left: string, right: string, width: number): string => {
	const lw = visibleWidth(left)
	const rw = visibleWidth(right)
	if (lw + rw + 1 > width) {
		const rightBudget = Math.max(0, width - lw - 1)
		if (rightBudget >= 4) {
			const trimmedRight = truncateToWidth(right, rightBudget, '…')
			const pad = ' '.repeat(Math.max(1, width - lw - visibleWidth(trimmedRight)))
			return left + pad + trimmedRight
		}
		return truncateToWidth(left, width, '…')
	}
	const pad = ' '.repeat(Math.max(1, width - lw - rw))
	return left + pad + right
}

/**
 * Build the footer factory bound to the open ExtensionAPI.
 * @param pi Extension API.
 * @param getCtx Latest extension context getter.
 * @returns Footer factory for setFooter.
 */
const createFooterFactory = (pi: ExtensionAPI, getCtx: () => ExtensionContext | undefined) => {
	return (tui: FooterTui, theme: Theme, footerData: FooterData) => {
		const unsubBranch = footerData.onBranchChange(() => {
			// Branch changes often track checkout/remote switches; drop host cache.
			remoteHostCache.clear()
			tui.requestRender()
		})
		// Soft refresh so MCP direct-tool registration changes show up without a turn.
		const timer = setInterval(() => tui.requestRender(), 4000)

		return {
			/**
			 * Release timers/subscriptions.
			 */
			dispose: () => {
				unsubBranch()
				clearInterval(timer)
			},
			/**
			 * No-op cache invalidation (render is always fresh).
			 */
			invalidate() {},
			/**
			 * Render the two-line optimized footer.
			 * @param width Terminal width in cells.
			 * @returns Footer lines.
			 */
			render(width: number): string[] {
				const ctx = getCtx()
				if (!ctx) return [theme.fg('dim', 'footer loading…')]

				latestFooterStatuses = footerData.getExtensionStatuses()
				const configured = collectConfiguredMcpServers(ctx.cwd)
				refreshMcpProbe(pi, configured)

				const repo = basename(ctx.cwd) || ctx.cwd
				const branch = footerData.getGitBranch()
				const remoteHost = branch ? getGitRemoteHost(ctx.cwd) : null
				const usage = collectUsage(ctx)
				const mcp = summarizeMcp(ctx)
				const model = ctx.model
				const thinking = (pi.getThinkingLevel?.() ?? 'off') as ThinkingLevel
				const supportsReasoning = Boolean(model?.reasoning)
				const context = ctx.getContextUsage()
				const contextWindow = context?.contextWindow ?? model?.contextWindow ?? 0
				const contextPct = context?.percent ?? null
				const contextTokens = context?.tokens ?? null

				const extraStatuses = [...(latestFooterStatuses?.entries() ?? [])]
					.filter(([key]) => !/^mcp/i.test(key))
					.sort(([a], [b]) => a.localeCompare(b))
					.map(([, text]) =>
						text
							.replace(/[\r\n\t]+/g, ' ')
							.replace(/ +/g, ' ')
							.trim(),
					)
					.filter(Boolean)

				// line 1: identity
				const repoSeg = theme.bold(theme.fg('accent', repo))
				const branchLabel = branch ? (remoteHost ? `git ${branch}@${remoteHost}` : `git ${branch}`) : 'no-git'
				const branchSeg = branch
					? theme.fg(branch === 'detached' ? 'warning' : 'success', branchLabel)
					: theme.fg('dim', branchLabel)
				const mcpSeg = theme.fg(mcp.tone, mcp.statusLabel)

				const modelLeaf = model ? formatModelId(model.id) : 'no-model'
				const provider = model?.provider
				const showProvider = Boolean(provider) && provider !== 'openrouter' && !modelLeaf.includes(provider!)
				const modelLabel = showProvider ? `${provider}/${modelLeaf}` : modelLeaf
				const modelSeg = theme.fg('text', modelLabel)
				const thinkSeg = theme.fg(thinkingColor(thinking), formatThinking(thinking, supportsReasoning))

				const left1 = joinSegments(theme, [repoSeg, branchSeg, mcpSeg])
				const right1 = joinSegments(theme, [modelSeg, thinkSeg])
				const line1 = splitLine(left1, right1, width)

				// line 2: economy
				const tokenBits: string[] = []
				if (usage.input) tokenBits.push(`↑${formatCount(usage.input)}`)
				if (usage.output) tokenBits.push(`↓${formatCount(usage.output)}`)
				if (usage.cacheRead) tokenBits.push(`R${formatCount(usage.cacheRead)}`)
				if (usage.cacheWrite) tokenBits.push(`W${formatCount(usage.cacheWrite)}`)
				if (usage.reasoning) tokenBits.push(`τ${formatCount(usage.reasoning)}`)
				const tokensSeg = tokenBits.length ? theme.fg('muted', tokenBits.join(' ')) : theme.fg('dim', 'no usage')

				const costMain = theme.fg('accent', formatCost(usage.cost))
				const costLast =
					usage.lastCost > 0 && usage.cost !== usage.lastCost
						? theme.fg('dim', ` last ${formatCost(usage.lastCost)}`)
						: ''
				const cacheHit =
					usage.lastCacheHitPct !== undefined ? theme.fg('dim', ` ch${usage.lastCacheHitPct.toFixed(0)}%`) : ''
				const costSeg = costMain + costLast + cacheHit

				const barWidth = width >= 100 ? 12 : width >= 80 ? 10 : 8
				const pctLabel =
					contextPct === null
						? `?/${formatCount(contextWindow)}`
						: `${contextPct.toFixed(1)}%/${formatCount(contextWindow)}`
				const tokensHint =
					contextTokens !== null && contextWindow > 0 ? theme.fg('dim', ` ${formatCount(contextTokens)}`) : ''
				let ctxColor: ThemeFg = 'muted'
				if (contextPct !== null) {
					if (contextPct > 90) ctxColor = 'error'
					else if (contextPct > 70) ctxColor = 'warning'
					else ctxColor = 'success'
				}
				const bar = theme.fg(ctxColor, contextBar(contextPct, barWidth))
				const ctxSeg = theme.fg(ctxColor, pctLabel) + theme.fg('dim', ' ') + bar + tokensHint

				const left2 = joinSegments(theme, [tokensSeg, costSeg])
				const line2 = splitLine(left2, ctxSeg, width)

				const lines = [line1, line2]
				if (extraStatuses.length > 0) {
					const statusLine = extraStatuses.join(theme.fg('dim', '  '))
					lines.push(truncateToWidth(statusLine, width, theme.fg('dim', '…')))
				}
				return lines
			},
		}
	}
}

export default function (pi: ExtensionAPI) {
	let enabled = true
	let latestCtx: ExtensionContext | undefined
	let installed = false

	/**
	 * Install or refresh the custom footer against the latest context.
	 * @param ctx Extension context.
	 */
	const installFooter = (ctx: ExtensionContext) => {
		latestCtx = ctx
		if (!enabled || !ctx.hasUI || ctx.mode !== 'tui') return
		ctx.ui.setFooter(createFooterFactory(pi, () => latestCtx))
		installed = true
	}

	/**
	 * Drop custom footer and restore pi default.
	 * @param ctx Extension context.
	 */
	const uninstallFooter = (ctx: ExtensionContext) => {
		if (!ctx.hasUI) return
		ctx.ui.setFooter(undefined)
		installed = false
	}

	pi.on('session_start', async (_event, ctx) => {
		installFooter(ctx)
	})

	pi.on('session_shutdown', async (_event, ctx) => {
		if (latestCtx === ctx) latestCtx = undefined
		installed = false
	})

	pi.on('model_select', async (_event, ctx) => {
		latestCtx = ctx
		if (enabled) installFooter(ctx)
	})

	pi.on('thinking_level_select', async (_event, ctx) => {
		latestCtx = ctx
	})

	pi.on('message_end', async (_event, ctx) => {
		latestCtx = ctx
	})

	pi.on('agent_end', async (_event, ctx) => {
		latestCtx = ctx
	})

	pi.on('agent_settled', async (_event, ctx) => {
		latestCtx = ctx
	})

	pi.registerCommand('opt-footer', {
		description: 'Toggle optimized footer (repo/branch/mcp/tokens/cost/context/model)',
		handler: async (_args, ctx) => {
			enabled = !enabled
			if (enabled) {
				installFooter(ctx)
				ctx.ui.notify('optimized footer on', 'info')
			} else {
				uninstallFooter(ctx)
				ctx.ui.notify('default footer restored', 'info')
			}
		},
	})

	// silence unused in non-tui / edge cases
	void installed
}
