// Claude Code, Cursor and Factory plan usage, between the agents list and the footer.

import { Buffer } from 'buffer'
import { v_flex, h_flex } from 'gpui-base'
import { View, div, image, svg } from 'gpui-kit'
import { theme, layout, run, exec, home, readTextFile } from 'herdr'
import { readFactoryKey, readFactory } from './factory-usage.js'

// Written by claude/statusline.sh on every Claude Code status line refresh.
const CLAUDE_CACHE = '.cache/claude-usage.json'
const CURSOR_DB = 'Library/Application Support/Cursor/User/globalStorage/state.vscdb'
const CURSOR_CLI_AUTH = '.cursor/auth.json'
const CURSOR_ORIGIN = 'https://cursor.com'
const CLAUDE_POLL_MS = 60 * 1000
const CURSOR_POLL_MS = 12 * 60 * 1000
const FACTORY_POLL_MS = 5 * 60 * 1000
// From here the bar turns the blocked color.
const WARN_PCT = 80
// The layout block this box sizes to fit, and the top border it draws outside its content.
const BLOCK_ID = 'usage'
const BORDER = 1
const FOLDED_KEY = 'usage.folded'
// Room under the last meter, so it clears the window edge like the footer beside it.
const LIST_BOTTOM = 20

function find(node, id) {
	if (node?.id === id) return node
	for (const child of node?.children ?? []) {
		const found = find(child, id)
		if (found) return found
	}
	return null
}

// The sidebar's rail goes by its width, as in the shipped agents mod.
const narrow = () => (find(layout(), 'sidebar')?.size?.px ?? Infinity) < 160

const pct = (n) => (n == null ? '–' : `${Math.floor(n)}%`)

// "2h13m" or "4d" until an epoch-seconds reset, "" without one.
function until(resetsAt) {
	if (resetsAt == null) return ''
	const m = Math.max(0, Math.ceil((resetsAt - Date.now() / 1000) / 60))
	if (m >= 48 * 60) return `${Math.floor(m / 1440)}d`
	return m >= 60 ? `${Math.floor(m / 60)}h${m % 60}m` : `${m}m`
}

// Claude drops expired windows from status-line snapshots. Keep both meters after a reset.
function claudeWindow(w) {
	if (!w || (w.resets_at != null && w.resets_at * 1000 <= Date.now())) return { used: 0, resets_at: null }
	return { used: w.used_percentage, resets_at: w.resets_at }
}

async function readClaude() {
	const text = await readTextFile(`${home()}/${CLAUDE_CACHE}`)
	if (!text) return null
	const r = JSON.parse(text)
	if (!r.five_hour && !r.seven_day) return null
	return { five: claudeWindow(r.five_hour), week: claudeWindow(r.seven_day) }
}

// The JWT's subject and expiry, or null for a token that isn't one.
function claims(token) {
	try {
		const part = token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/')
		const c = JSON.parse(Buffer.from(part + '='.repeat((4 - (part.length % 4)) % 4), 'base64').toString('utf8'))
		return typeof c.sub === 'string' && c.sub ? { sub: c.sub, exp: c.exp } : null
	} catch {
		return null
	}
}

// Cursor's access tokens, in the order Orca tries them: cursor-agent's Keychain login,
// the CLI auth file, then the desktop app's state database.
const CURSOR_TOKENS = [
	async () =>
		(await exec('security', ['find-generic-password', '-s', 'cursor-access-token', '-a', 'cursor-user', '-w'])).stdout,
	async () => JSON.parse((await readTextFile(`${home()}/${CURSOR_CLI_AUTH}`)) ?? '{}').accessToken,
	async () =>
		(
			await exec('sqlite3', [
				'-readonly',
				`${home()}/${CURSOR_DB}`,
				"select value from ItemTable where key = 'cursorAuth/accessToken'",
			])
		).stdout,
]

// The first unexpired token with a subject.
async function cursorSession() {
	for (const read of CURSOR_TOKENS) {
		const token = String((await read().catch(() => '')) ?? '').trim()
		const c = token && claims(token)
		if (c && !(c.exp && c.exp * 1000 <= Date.now())) return { token, sub: c.sub }
	}
	return null
}

// Cursor's web session cookie is "<JWT subject>::<access token>".
async function cursorGet(session, url, method = 'GET') {
	const res = await fetch(url, {
		method,
		headers: {
			Cookie: `WorkosCursorSessionToken=${encodeURIComponent(session.sub)}%3A%3A${session.token}`,
			Accept: 'application/json',
			Origin: CURSOR_ORIGIN,
			Referer: `${CURSOR_ORIGIN}/dashboard`,
			...(method === 'POST' ? { 'Content-Type': 'application/json' } : {}),
		},
		...(method === 'POST' ? { body: '{}' } : {}),
	})
	if (!res.ok) throw new Error(`${url}: HTTP ${res.status}`)
	return res.json()
}

const seconds = (v) => {
	const n = typeof v === 'string' && /^\d+$/.test(v) ? Number(v) : v
	const ms = typeof n === 'number' ? (n > 1e12 ? n : n * 1000) : Date.parse(n)
	return Number.isFinite(ms) ? ms / 1000 : null
}

// The plan's used percentage, or null when it reports none.
function planUsed(plan) {
	if (!plan || plan.enabled === false) return null
	if (plan.totalPercentUsed != null) return Number(plan.totalPercentUsed)
	return plan.limit > 0 ? (plan.used / plan.limit) * 100 : null
}

async function readCursor() {
	const session = await cursorSession()
	if (!session) return null
	const r = await cursorGet(session, `${CURSOR_ORIGIN}/api/usage-summary`)
	if (r.isUnlimited === true) return null
	const plan = r.individualUsage?.plan
	let used = planUsed(plan),
		end = seconds(r.billingCycleEnd)
	// Unified plans, and summaries that read all zero, carry the real numbers in the dashboard's period usage.
	const buckets = [plan?.autoPercentUsed, plan?.apiPercentUsed].filter((p) => p != null)
	const zero = buckets.length > 0 && buckets.every((p) => Number(p) === 0)
	if (String(r.membershipType ?? '').startsWith('unified_') || zero) {
		const p = await cursorGet(session, `${CURSOR_ORIGIN}/api/dashboard/get-current-period-usage`, 'POST').catch(
			() => null
		)
		const periodUsed = planUsed(p?.planUsage)
		if (periodUsed != null) {
			used = periodUsed
			end = seconds(p.billingCycleEnd) ?? end
		}
	}
	return used == null ? null : { used: Math.min(100, Math.max(0, used)), resets_at: end }
}

export default class Usage extends View {
	init(_props, cx) {
		this.claude = null
		this.cursor = null
		this.factory = null
		this.factoryPending = false
		this.factoryUpdatedAt = null
		this.factoryStatus = 'loading'
		try {
			this.folded = Boolean(localStorage.getItem(FOLDED_KEY))
		} catch {
			this.folded = false
		}
		this.poll(cx, 'claude', readClaude)
		this.poll(cx, 'cursor', readCursor)
		this.pollFactory(cx)
		cx.timer.every(CLAUDE_POLL_MS, (tickCx) => this.poll(tickCx, 'claude', readClaude))
		cx.timer.every(CURSOR_POLL_MS, (tickCx) => this.poll(tickCx, 'cursor', readCursor))
		cx.timer.every(FACTORY_POLL_MS, (tickCx) => this.pollFactory(tickCx))
	}

	/**
	 * Refresh Factory without overlapping requests or logging credentials and API bodies.
	 * @param {object} context This callback's Herdr view context.
	 * @returns {void}
	 */
	pollFactory(context) {
		if (this.factoryPending) {
			context.notify()
			return
		}
		this.factoryPending = true
		context.spawn(async (cx) => {
			try {
				const key = await readFactoryKey(exec)
				if (!key) {
					this.factory = null
					this.factoryUpdatedAt = null
					this.factoryStatus = 'key needed'
					return
				}
				this.factory = await readFactory(fetch, key)
				this.factoryUpdatedAt = Date.now()
				this.factoryStatus = null
			} catch {
				this.factoryStatus = this.factory ? 'stale' : 'unavailable'
			} finally {
				this.factoryPending = false
				cx.notify()
			}
		})
	}

	// Keeps the last good reading when a read fails (offline, Cursor signed out).
	poll(context, field, read) {
		context.spawn(async (cx) => {
			try {
				const value = await read()
				if (value) this[field] = value
			} catch (e) {
				console.log(`usage: ${field}: ${e}`)
			}
			cx.notify()
		})
	}

	// One meter: icon, name, percentage and reset, with a thin bar below.
	row(t, id, icon, name, w, stale = false) {
		const used = Math.min(100, Math.max(0, w.used ?? 0))
		const reset = until(w.resets_at)
		return v_flex()
			.id(id)
			.gap(4)
			.px(8)
			.py(3)
			.child(
				h_flex()
					.gap(8)
					.items_center()
					.child(image(`icons/${icon}.svg`).size(14).flex_none())
					.child(
						div()
							.flex_1()
							.truncate()
							.text_color(t.muted)
							.child(`${name}${stale ? ' · stale' : ''}`)
					)
					.when(Boolean(reset), (el) => el.child(div().flex_none().text_size(11).text_color(t.dim).child(`↻ ${reset}`)))
					.child(div().flex_none().text_color(t.foreground).child(pct(w.used)))
			)
			.child(
				div()
					.w_full()
					.h(3)
					.rounded(2)
					.bg(t.border)
					.child(
						div()
							.h(3)
							.rounded(2)
							.w(`${used}%`)
							.bg(used >= WARN_PCT ? t.blocked : t.accent)
					)
			)
	}

	// The block follows the content's height: header and meters, or the header alone when folded.
	fit(height) {
		const px = Math.ceil(height) + BORDER
		const block = find(layout(), BLOCK_ID)
		if (block && block.size?.px !== px) run('layout.resize', { id: BLOCK_ID, px })
	}

	toggle() {
		this.folded = !this.folded
		try {
			localStorage.setItem(FOLDED_KEY, this.folded ? '1' : '')
		} catch {}
	}

	render() {
		const t = theme()
		const factoryStale =
			this.factoryStatus === 'stale' ||
			(this.factoryUpdatedAt != null && Date.now() - this.factoryUpdatedAt >= FACTORY_POLL_MS * 2)
		const factoryNote = !this.factory && this.factoryStatus ? `Factory: ${this.factoryStatus}` : null
		const meters = [
			this.claude?.five && { id: 'claude-5h', icon: 'claude', name: 'Claude 5h', w: this.claude.five },
			this.claude?.week && { id: 'claude-7d', icon: 'claude', name: 'Claude 7d', w: this.claude.week },
			this.cursor && { id: 'cursor', icon: 'cursor', name: 'Cursor', w: this.cursor },
			...(this.factory ?? []).map((m) => ({ ...m, icon: 'agent', stale: factoryStale })),
		].filter(Boolean)
		const root = v_flex().size_full().min_h(0).bg(t.chrome).border_t(1).border_color(t.border).text_size(12.5)
		// Natural height, never stretched by the block, so its size is what the block should be.
		const content = v_flex()
			.id('usage-content')
			.flex_none()
			.w_full()
			.on_size_change((size) => this.fit(size.height))
		if (narrow()) {
			const rail = content
				.items_center()
				.py(8)
				.gap(6)
				.children(
					meters.map((m) =>
						v_flex()
							.id(m.id)
							.items_center()
							.gap(2)
							.child(image(`icons/${m.icon}.svg`).size(14))
							.child(
								div()
									.text_size(10)
									.text_color(t.dim)
									.child(`${pct(m.w.used)}${m.stale ? '*' : ''}`)
							)
					)
				)
			return root.child(
				rail.when(Boolean(factoryNote), (el) =>
					el.child(
						div()
							.text_size(10)
							.text_color(t.dim)
							.child(
								this.factoryStatus === 'key needed' ? 'F: key' : this.factoryStatus === 'loading' ? 'F: …' : 'F: !'
							)
					)
				)
			)
		}
		const header = h_flex()
			.id('usage-header')
			.px(16)
			.h(41)
			.pt(14)
			.pb(5)
			.flex_none()
			.items_center()
			.gap(6)
			.text_color(t.dim)
			.hover((s) => s.text_color(t.foreground))
			.on_click((_e, cx) => {
				this.toggle()
				cx.notify()
			})
			.child(svg(`mods/workspace-chrome/${this.folded ? 'chevron-right' : 'chevron-down'}.svg`).size(12))
			.child(div().flex_1().text_size(11.5).font_medium().child('Usage'))
			.when(this.folded && meters.length > 0, (el) =>
				el.child(
					div()
						.truncate()
						.text_size(11)
						.child(meters.map((m) => `${pct(m.w.used)}${m.stale ? '*' : ''}`).join(' · '))
				)
			)
		return root.child(
			content
				.child(header)
				.when(!this.folded && meters.length === 0, (el) =>
					el.child(div().px(16).pb(10).text_size(12).text_color(t.dim).child('No usage yet.'))
				)
				.when(!this.folded && meters.length > 0, (el) =>
					el.child(
						v_flex()
							.px(8)
							.pb(LIST_BOTTOM)
							.gap(2)
							.children(meters.map((m) => this.row(t, m.id, m.icon, m.name, m.w, m.stale)))
					)
				)
				.when(Boolean(factoryNote), (el) =>
					el.child(div().px(16).pb(8).text_size(11).text_color(t.dim).child(factoryNote))
				)
		)
	}
}
