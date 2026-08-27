#!/usr/bin/env bun
/**
 * sync agent skills from ./skills to an open webui instance via its REST API.
 *
 * usage:
 *   bun run bin/sync-skills.ts [--prune] [--dry-run]
 *   ./bin/sync-skills.ts [--prune] [--dry-run]
 *
 * required env (provided by `just _env` which wraps `sops exec-env`):
 *   OPEN_WEBUI_URL     base url of the instance, no trailing slash
 *   OPEN_WEBUI_API_KEY bearer token with admin role or workspace.skills perm
 *
 * skill discovery:
 *   walks <repo>/skills for files matching <category>/<id>/SKILL.md. the
 *   folder name is the skill id; the category becomes a meta tag alongside
 *   any frontmatter metadata.tags. yaml frontmatter provides `name` and
 *   `description`; the markdown body becomes the skill content.
 */

import { readdir, readFile, stat } from 'node:fs/promises'
import { basename, dirname, join, relative } from 'node:path'
import { fileURLToPath } from 'node:url'

// ─── config & arg parsing ───────────────────────────────────────────────────

const PRUNE = process.argv.includes('--prune')
const DRY_RUN = process.argv.includes('--dry-run')

if (process.argv.slice(2).some((a) => a === '-h' || a === '--help')) {
	console.log('usage: bun run bin/sync-skills.ts [--prune] [--dry-run]')
	process.exit(0)
}

const OPEN_WEBUI_URL = process.env['OPEN_WEBUI_URL']
const OPEN_WEBUI_API_KEY = process.env['OPEN_WEBUI_API_KEY']

if (!OPEN_WEBUI_URL || !OPEN_WEBUI_API_KEY) {
	console.error('OPEN_WEBUI_URL and OPEN_WEBUI_API_KEY must be set (use sops exec-env)')
	process.exit(1)
}

const API_BASE = `${OPEN_WEBUI_URL.replace(/\/$/, '')}/api/v1/skills`
const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url))
const SKILLS_DIR = process.env['SKILLS_DIR'] ?? join(SCRIPT_DIR, '..', 'skills')

// ─── helpers ────────────────────────────────────────────────────────────────

/** Print an info line to stdout. */
const log = (msg: string): void => console.log(msg)

/** Print an error line to stderr. */
const err = (msg: string): void => console.error(msg)

type ApiSuccess<T> = { ok: true; data: T }
type ApiFailure = { ok: false; status: number; body: string }
type ApiResult<T> = ApiSuccess<T> | ApiFailure

/**
 * Make an authenticated request against the open webui skills api.
 * @param method - http verb (GET, POST, DELETE, ...)
 * @param path - path appended to the api base, must start with `/`
 * @param body - optional json body; auto-stringified
 * @param expected - status code to treat as success (default 200)
 * @returns tagged union with parsed json data on success, status+body on failure
 */
async function api<T = unknown>(
	method: string,
	path: string,
	body?: unknown,
	expected: number = 200
): Promise<ApiResult<T>> {
	const headers: Record<string, string> = {
		Authorization: `Bearer ${OPEN_WEBUI_API_KEY}`,
		Accept: 'application/json',
	}
	if (body !== undefined) headers['Content-Type'] = 'application/json'

	const res = await fetch(`${API_BASE}${path}`, {
		method,
		headers,
		body: body !== undefined ? JSON.stringify(body) : undefined,
	})
	const text = await res.text()
	if (res.status !== expected) {
		return { ok: false, status: res.status, body: text }
	}
	return { ok: true, data: text ? (JSON.parse(text) as T) : (null as T) }
}

type ParsedSkill = { frontmatter: string; body: string }

/**
 * Split a SKILL.md into frontmatter and body. Only the first two `---` fences
 * count, so horizontal rules in the body pass through verbatim. Tolerates CRLF.
 * @param raw - full file contents
 * @returns frontmatter and body strings (trailing newline trimmed from body)
 */
function splitSkill(raw: string): ParsedSkill {
	const lines = raw.split('\n')
	let stage = 0
	const fm: string[] = []
	const body: string[] = []
	for (const line of lines) {
		const cleaned = line.replace(/\r$/, '')
		if (stage === 0 && /^---\s*$/.test(cleaned)) {
			stage = 1
			continue
		}
		if (stage === 1 && /^---\s*$/.test(cleaned)) {
			stage = 2
			continue
		}
		if (stage === 1) fm.push(cleaned)
		else if (stage === 2) body.push(cleaned)
	}
	// trim a single trailing blank line if present
	while (body.length > 0 && body[body.length - 1] === '') body.pop()
	return { frontmatter: fm.join('\n'), body: body.join('\n') }
}

type Frontmatter = { name: string; description: string; tags: string[] }

/**
 * Minimal yaml parser for the frontmatter subset used by these skills: top-level
 * string keys plus an optional `metadata.tags` array. Avoids pulling in a yaml
 * dependency for a tiny surface area.
 * @param raw - the frontmatter block (without the surrounding `---` fences)
 * @returns extracted name, description, and tags
 */
function parseFrontmatter(raw: string): Frontmatter {
	const result: Frontmatter = { name: '', description: '', tags: [] }
	let inMetadata = false
	for (const rawLine of raw.split('\n')) {
		const line = rawLine.replace(/\r$/, '')
		if (!line.trim()) continue
		if (line.startsWith(' ') || line.startsWith('-')) {
			if (inMetadata) {
				const m = line.match(/^\s+-\s+(.+)$/)
				if (m) result.tags.push(m[1].trim().replace(/^["']|["']$/g, ''))
			}
			continue
		}
		inMetadata = false
		const m = line.match(/^([a-zA-Z_][a-zA-Z0-9_-]*):\s*(.*)$/)
		if (!m) continue
		const [, key, value] = m
		const v = value.trim().replace(/^["']|["']$/g, '')
		if (key === 'name') result.name = v
		else if (key === 'description') result.description = v
		else if (key === 'metadata') inMetadata = true
	}
	return result
}

/**
 * Humanize a kebab-case id: `eventhub-id-lookup` → `Eventhub Id Lookup`.
 * @param id - kebab-case identifier
 */
function humanize(id: string): string {
	return id
		.split('-')
		.map((w) => (w ? w.charAt(0).toUpperCase() + w.slice(1) : w))
		.join(' ')
}

type SkillPayload = {
	id: string
	name: string
	description: string
	content: string
	meta: { tags: string[] }
}

/**
 * Recursively find every SKILL.md under a directory, skipping dotfiles.
 * @param dir - absolute path to the skills root
 * @returns absolute paths to every SKILL.md found
 */
async function findSkillFiles(dir: string): Promise<string[]> {
	try {
		const s = await stat(dir)
		if (!s.isDirectory()) throw new Error('not a directory')
	} catch {
		err(`skills dir not found: ${dir}`)
		process.exit(1)
	}
	const out: string[] = []
	async function walk(d: string): Promise<void> {
		const entries = await readdir(d, { withFileTypes: true })
		for (const entry of entries) {
			if (entry.name.startsWith('.')) continue
			const p = join(d, entry.name)
			if (entry.isDirectory()) {
				await walk(p)
			} else if (entry.isFile() && entry.name === 'SKILL.md') {
				out.push(p)
			}
		}
	}
	await walk(dir)
	return out
}

// ─── main ───────────────────────────────────────────────────────────────────

async function main(): Promise<void> {
	log(`scanning ${SKILLS_DIR} ...`)
	const skillFiles = await findSkillFiles(SKILLS_DIR)
	if (skillFiles.length === 0) {
		log('no SKILL.md files found; nothing to sync')
		process.exit(0)
	}

	const localIds = new Set<string>()
	const localPayloads = new Map<string, SkillPayload>()

	for (const file of skillFiles) {
		const rel = relative(SKILLS_DIR, file)
		// rel looks like <category>/<id>/SKILL.md (or <id>/SKILL.md at the root)
		const skillDir = dirname(rel)
		const id = basename(skillDir)
		const categoryRaw = dirname(skillDir)
		const category = categoryRaw === '.' ? 'uncategorized' : categoryRaw

		const raw = await readFile(file, 'utf8')
		const { frontmatter, body } = splitSkill(raw)
		const fm = parseFrontmatter(frontmatter)
		const name = fm.name || humanize(id)
		const tags = [category, ...fm.tags]

		const payload: SkillPayload = {
			id,
			name,
			description: fm.description,
			content: body,
			meta: { tags },
		}
		localIds.add(id)
		localPayloads.set(id, payload)
		log(`  + ${category}/${id}`)
	}

	log('')
	log(`fetching remote skills from ${API_BASE} ...`)
	type ListResponse = { items?: Array<{ id: string }> }
	const listRes = await api<ListResponse>('GET', '/list?page=1&per_page=500')
	if (!listRes.ok) {
		err(`list failed: ${listRes.status} ${listRes.body}`)
		process.exit(1)
	}
	const remoteIds = new Set<string>((listRes.data.items ?? []).map((s) => s.id))
	log(`remote: ${remoteIds.size}  local: ${localPayloads.size}`)

	let created = 0
	let updated = 0
	let skipped = 0
	let pruned = 0

	for (const [id, payload] of localPayloads) {
		const op: 'create' | 'update' = remoteIds.has(id) ? 'update' : 'create'
		const path = op === 'create' ? '/create' : `/id/${id}/update`

		if (DRY_RUN) {
			log(`  [dry-run] ${op} ${id}`)
			continue
		}

		const res = await api('POST', path, payload)
		if (res.ok) {
			if (op === 'create') created++
			else updated++
			log(`  ✓ ${op} ${id}`)
		} else {
			skipped++
			err(`  ✗ ${op} ${id}: ${res.status} ${res.body}`)
		}
	}

	if (PRUNE) {
		log('')
		log('pruning skills not present locally ...')
		for (const rid of remoteIds) {
			if (localIds.has(rid)) continue
			if (DRY_RUN) {
				log(`  [dry-run] delete ${rid}`)
				continue
			}
			const res = await api('DELETE', `/id/${rid}/delete`)
			if (res.ok) {
				pruned++
				log(`  ✓ delete ${rid}`)
			} else {
				err(`  ✗ delete ${rid}: ${res.status} ${res.body}`)
			}
		}
	}

	log('')
	log(`done: created=${created} updated=${updated} skipped=${skipped} pruned=${pruned}`)
	if (skipped > 0) process.exit(1)
}

main().catch((e) => {
	err(e instanceof Error ? (e.stack ?? e.message) : String(e))
	process.exit(1)
})
