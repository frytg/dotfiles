/**
 * Live `/v1/models` discovery for custom providers in models.json.
 *
 * Stock pi never fetches the models endpoint. A provider with no (or empty)
 * `models` array is registered here with `refreshModels`, so `/model` and
 * startup pull whatever the proxy currently serves.
 *
 * Feather's `/v1/models` may include `context_length` and `max_tokens`. Those
 * map to pi's `contextWindow` / `maxTokens`. Missing live fields fall back to
 * models-store.json, then 128000 / 16384.
 */

import { existsSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import type { ExtensionAPI, ProviderModelConfig } from '@earendil-works/pi-coding-agent'
import { getAgentDir } from '@earendil-works/pi-coding-agent'

type JsonRecord = Record<string, unknown>

type ModelsJsonProvider = {
	baseUrl?: string
	api?: string
	apiKey?: string
	compat?: JsonRecord
	models?: unknown[]
}

type ModelsJson = {
	providers?: Record<string, ModelsJsonProvider>
}

type StoredModel = {
	id?: string
	name?: string
	reasoning?: boolean
	input?: ProviderModelConfig['input']
	cost?: ProviderModelConfig['cost']
	contextWindow?: number
	maxTokens?: number
	thinkingLevelMap?: ProviderModelConfig['thinkingLevelMap']
	compat?: JsonRecord
}

/** One `/v1/models` row. Feather emits `context_length` / `max_tokens` (RFC 0002). */
type LiveModel = {
	id?: unknown
	name?: unknown
	context_length?: unknown
	context_window?: unknown
	max_model_len?: unknown
	max_context_length?: unknown
	max_tokens?: unknown
	max_completion_tokens?: unknown
	max_output_tokens?: unknown
}

const ZERO_COST = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }
const FALLBACK_CONTEXT_WINDOW = 128000
const FALLBACK_MAX_TOKENS = 16384

/**
 * Accept a positive finite number from a JSON field; skip strings and junk.
 *
 * @param value Raw JSON value
 * @returns Integer, or undefined
 */
const positiveInt = (value: unknown): number | undefined => {
	if (typeof value !== 'number' || !Number.isFinite(value) || value <= 0) return undefined
	if (!Number.isInteger(value)) return undefined
	return value
}

/**
 * Map a live models-list row onto pi's contextWindow / maxTokens.
 *
 * @param live Upstream list item
 * @returns Token limits when the row advertised them
 */
const liveTokenLimits = (live: LiveModel): { contextWindow?: number; maxTokens?: number } => {
	const contextWindow =
		positiveInt(live.context_length) ??
		positiveInt(live.context_window) ??
		positiveInt(live.max_model_len) ??
		positiveInt(live.max_context_length)
	const maxTokens =
		positiveInt(live.max_tokens) ??
		positiveInt(live.max_completion_tokens) ??
		positiveInt(live.max_output_tokens)
	return { contextWindow, maxTokens }
}

/**
 * Read a JSON file from the agent dir, or `undefined` if missing/invalid.
 *
 * @param name File name under the agent dir
 * @returns Parsed JSON, or undefined
 */
const readAgentJson = (name: string): unknown => {
	const path = join(getAgentDir(), name)
	if (!existsSync(path)) return undefined
	try {
		return JSON.parse(readFileSync(path, 'utf8')) as unknown
	} catch {
		return undefined
	}
}

/**
 * Resolve a models.json `apiKey` spec for a discovery request.
 *
 * @param spec Literal, `$ENV`, or `${ENV}`. `!command` is skipped.
 * @returns Resolved key, or undefined
 */
const resolveApiKey = (spec: string | undefined, credentialKey: string | undefined): string | undefined => {
	if (credentialKey) return credentialKey
	if (!spec) return undefined
	if (spec.startsWith('!')) return undefined
	const envMatch = spec.match(/^\$\{([^}]+)\}$/) ?? spec.match(/^\$([A-Za-z_][A-Za-z0-9_]*)$/)
	if (envMatch) {
		const value = process.env[envMatch[1]]
		return value && value.length > 0 ? value : undefined
	}
	return spec
}

/**
 * Pull catalog metadata from models-store.json when the live id matches.
 *
 * @param id Live model id from `/v1/models`
 * @param store Parsed models-store.json
 * @returns Matching store entry, if any
 */
const lookupStoreModel = (id: string, store: Record<string, { models?: StoredModel[] }>): StoredModel | undefined => {
	for (const entry of Object.values(store)) {
		const exact = entry.models?.find((model) => model.id === id)
		if (exact) return exact
	}
	const slash = id.indexOf('/')
	if (slash <= 0) return undefined
	const prefix = id.slice(0, slash)
	const rest = id.slice(slash + 1)
	return store[prefix]?.models?.find((model) => model.id === rest)
}

/**
 * Map a live `/v1/models` row onto a pi provider model.
 *
 * Token limits: live row (proxy overlay / upstream extract) > models-store.json >
 * pi defaults. `modelOverrides` in models.json still win on top of this — pi
 * applies those after refreshModels returns.
 *
 * @param live Upstream list item
 * @param providerCompat Provider-level compat from models.json
 * @param stored Optional models-store metadata
 * @returns Pi model config
 */
const toProviderModel = (
	live: LiveModel,
	providerCompat: JsonRecord | undefined,
	stored: StoredModel | undefined,
): ProviderModelConfig | undefined => {
	if (typeof live.id !== 'string' || live.id.length === 0) return undefined
	const storedCompat = stored?.compat ?? {}
	const compat = { ...providerCompat, ...storedCompat }
	const liveLimits = liveTokenLimits(live)
	return {
		id: live.id,
		name: (typeof live.name === 'string' && live.name) || stored?.name || live.id,
		reasoning: stored?.reasoning ?? true,
		input: stored?.input ?? ['text', 'image'],
		cost: stored?.cost ?? ZERO_COST,
		contextWindow: liveLimits.contextWindow ?? stored?.contextWindow ?? FALLBACK_CONTEXT_WINDOW,
		maxTokens: liveLimits.maxTokens ?? stored?.maxTokens ?? FALLBACK_MAX_TOKENS,
		thinkingLevelMap: stored?.thinkingLevelMap,
		compat: Object.keys(compat).length > 0 ? (compat as ProviderModelConfig['compat']) : undefined,
	}
}

/**
 * Fetch `{baseUrl}/models` and map the list into pi model configs.
 *
 * @param baseUrl OpenAI-compatible root (…/v1)
 * @param apiKey Optional bearer token
 * @param signal Abort signal from pi's refresh
 * @param providerCompat Provider-level compat
 * @param store models-store.json contents
 * @returns Discovered models
 */
const fetchModels = async (
	baseUrl: string,
	apiKey: string | undefined,
	signal: AbortSignal,
	providerCompat: JsonRecord | undefined,
	store: Record<string, { models?: StoredModel[] }>,
): Promise<ProviderModelConfig[]> => {
	const url = `${baseUrl.replace(/\/$/, '')}/models`
	const headers: Record<string, string> = { Accept: 'application/json' }
	if (apiKey) headers.Authorization = `Bearer ${apiKey}`
	const response = await fetch(url, { signal, headers })
	if (!response.ok) {
		throw new Error(`GET ${url} → ${response.status}`)
	}
	const payload = (await response.json()) as { data?: LiveModel[] }
	const rows = Array.isArray(payload.data) ? payload.data : []
	const models = rows
		.map((row) => toProviderModel(row, providerCompat, lookupStoreModel(String(row.id ?? ''), store)))
		.filter((model): model is ProviderModelConfig => model !== undefined)
	if (models.length === 0) {
		throw new Error(`GET ${url} returned no models`)
	}
	return models
}

export default (pi: ExtensionAPI): void => {
	const modelsJson = readAgentJson('models.json') as ModelsJson | undefined
	const providers = modelsJson?.providers ?? {}
	const store = (readAgentJson('models-store.json') as Record<string, { models?: StoredModel[] }> | undefined) ?? {}

	for (const [id, provider] of Object.entries(providers)) {
		if (!provider.baseUrl || !provider.api) continue
		if (Array.isArray(provider.models) && provider.models.length > 0) continue

		const baseUrl = provider.baseUrl
		const apiKeySpec = provider.apiKey
		const compat = provider.compat

		pi.registerProvider(id, {
			name: id,
			baseUrl,
			apiKey: apiKeySpec,
			api: provider.api as 'openai-completions',
			refreshModels: async ({ signal, credential }) => {
				const key = resolveApiKey(
					apiKeySpec,
					credential?.type === 'api_key' ? credential.key : undefined,
				)
				return fetchModels(baseUrl, key, signal, compat, store)
			},
		})
	}
}
