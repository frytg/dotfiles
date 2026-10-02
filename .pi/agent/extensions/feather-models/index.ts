/**
 * Feather `/v1/models` discovery for a native pi provider.
 *
 * Registers `feather` as a native pi provider via
 * `pi.registerProvider(provider)`, where `provider` is built with
 * `createProvider()` from `@earendil-works/pi-ai`. The provider wires
 * built-in chat and classifier implementations, discovers models from
 * feather's live OpenAI-compatible `/v1/models` endpoint, and applies a
 * small per-model override map for offline metadata that the upstream
 * catalog does not always advertise.
 *
 * Why this file (no `models.json` entry)
 * ---------------------------------------
 * Previously feather lived in `models.json` alongside `modelOverrides` for
 * offline metadata. That made the integration depend on two files (the
 * extension and a `models.json` entry) which had to be kept in sync. The
 * native provider form lets us declare the entire feather provider —
 * baseUrl, api key resolution, compat flags, model overrides — inside this
 * extension. Pi composes `models.json` overrides above a registered native
 * provider, but we now own the override layer for feather here.
 *
 * Classifier rows
 * ---------------
 * Feather proxies `type: classifier` rows (RFC 0002) through to providers
 * that speak TypeSafe System One — typically OpenRouter. We route them
 * through a `typesafe-system-one` classifier implementation, which
 * constructs `${baseUrl}/systemone` against `model.baseUrl`. Each
 * classifier model inherits the provider baseUrl, so calls land on
 * `${FEATHER_BASE_URL}/systemone` and reach the System One endpoint through
 * feather's proxy. Chat rows continue to flow through `openai-completions`.
 *
 * Pi's extension loader aliases `@earendil-works/pi-ai` and
 * `@earendil-works/pi-ai/compat` (compat is a deprecated alias surface
 * kept around for old extensions). The per-API subpath imports — like
 * `@earendil-works/pi-ai/api/typesafe-system-one.lazy` — are NOT in the
 * alias map and the package.json only declares an `import` condition for
 * `./api/*`, so a CJS-style require can't resolve them through jiti. We
 * use compat for the chat implementation and re-declare a minimal
 * System One classifier wrapper here. The wrapper speaks the same wire
 * protocol pi-ai uses, so feather (and any compatible proxy) works
 * unchanged.
 *
 * Chat rows
 * ---------
 * Chat rows go through pi's built-in `openai-completions` stream
 * implementation, the same wire protocol the legacy registration used.
 * Provider-level compat flags apply to every chat model; per-model
 * overrides win (see `MODEL_OVERRIDES` below).
 *
 * Auth
 * ----
 * `envApiKeyAuth` resolves in this order:
 *
 *   1. A stored credential from `/login feather` (auth.json).
 *   2. The `LLM_PROXY_API_KEY` environment variable.
 *
 * The runtime drives request-time auth via `auth.resolve()`. The refresh
 * path below reads the same two sources directly because
 * `RefreshModelsContext` exposes the stored credential, not the resolved
 * auth result.
 *
 * Failure modes
 * -------------
 * - transport error or non-2xx → fetchModels throws; pi keeps the
 *   previously cached list visible to `/model`.
 * - empty `data[]` → throws "returned no models"; a stale refresh would be
 *   worse than a visible failure.
 * - row missing id or with a `type` we don't implement (e.g. `image`) →
 *   that row is dropped; the rest of the catalog still loads.
 *
 * Persistence (`models-store.json`)
 * ----------------------------------
 * `createProvider` calls `context.publish({ persist, update })` after a
 * successful refresh, so pi writes the catalog to `models-store.json`
 * itself. We never write the file directly.
 *
 * Startup catalog (why the factory is async)
 * ------------------------------------------
 * Pi only runs a *network* model refresh in interactive mode (after the
 * TUI is up) and in rpc mode (in the background). `pi --list-models`,
 * `pi -p`, and startup model selection read the catalog before any of
 * that happens, and the offline restore pi does on `registerProvider`
 * only replays whatever `models-store.json` already holds. With a cold
 * store a purely dynamic provider therefore shows zero models there
 * ("No models match pattern feather/**").
 *
 * Extension factories may be async and pi awaits them before startup
 * continues, so we seed the provider's baseline `models` ourselves:
 * first from the feather entry in `models-store.json` (instant, works
 * offline), and only when that is empty from one bounded `/v1/models`
 * fetch. `fetchModels` still owns ongoing refresh + persistence, so the
 * store fills on the first interactive run and later launches never hit
 * the network at startup. Startup fetch is skipped under `PI_OFFLINE`
 * (`--offline` sets it) and swallows failures — the provider still
 * registers and the interactive refresh fills it in later.
 */

import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { createProvider, envApiKeyAuth } from "@earendil-works/pi-ai";
import type {
	AnyModel,
	ApiKeyCredential,
	ClassifierAnswer,
	ClassifierContext,
	ClassifierModel,
	ClassifierQuestion,
	ClassifierResult,
	Credential,
	JsonObject,
	Model as ChatModel,
	ModelsStoreEntry,
	OpenAICompletionsCompat,
} from "@earendil-works/pi-ai";
import { openAICompletionsApi } from "@earendil-works/pi-ai/compat";
import { getAgentDir } from "@earendil-works/pi-coding-agent";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// Provider config — replaces the `feather` entry in `models.json`.
const FEATHER_ID = "feather";
const FEATHER_NAME = "Feather";
const FEATHER_BASE_URL = "https://llm.moose-mulley.ts.net/v1";
const FEATHER_API_KEY_ENV = "LLM_PROXY_API_KEY";

// Cold-store startup fetch budget. Keeps `pi` launch snappy when the proxy
// is unreachable (off the tailnet); the interactive refresh retries later.
const STARTUP_FETCH_TIMEOUT_MS = 4000;
// Pi's persisted dynamic catalogs, keyed by provider id.
const MODELS_STORE_FILE = "models-store.json";

// Provider-wide OpenAI completions compat — applied to every chat model.
// Per-model overrides (see MODEL_OVERRIDES) win.
const FEATHER_COMPAT: OpenAICompletionsCompat = {
	supportsDeveloperRole: false,
	supportsReasoningEffort: false,
	thinkingFormat: "qwen",
};

// Per-model overrides — replaces `models.json#providers.feather.modelOverrides`.
// Lives here so the integration is self-contained.
type ChatOverride = Partial<ChatModel<"openai-completions">>;
type ClassifierOverride = Partial<ClassifierModel<"typesafe-system-one">>;

const MODEL_OVERRIDES: {
	chat: Record<string, ChatOverride>;
	classifier: Record<string, ClassifierOverride>;
} = {
	chat: {
		"minimax/MiniMax-M3": {
			name: "MiniMax M3",
			input: ["text", "image"],
			reasoning: true,
			contextWindow: 1000000,
			maxTokens: 32000,
			compat: {
				supportsDeveloperRole: false,
				forceAdaptiveThinking: true,
			} as ChatOverride["compat"],
			samplingParams: { reasoning_split: true },
		},
	},
	classifier: {},
};

// Sensible defaults — pi does not infer any of these.
const ZERO_COST = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 };
const FALLBACK_CONTEXT_WINDOW = 128000;
const FALLBACK_MAX_TOKENS = 16384;

// One row from feather's `/v1/models` response (RFC 0002).
type LiveRow = {
	id?: unknown;
	name?: unknown;
	type?: unknown;
	context_length?: unknown;
	context_window?: unknown;
	max_model_len?: unknown;
	max_context_length?: unknown;
	max_tokens?: unknown;
	max_completion_tokens?: unknown;
	max_output_tokens?: unknown;
};

/**
 * Accept a positive finite integer from a JSON field.
 *
 * @param value Raw JSON value
 * @returns Integer, or undefined
 */
const positiveInt = (value: unknown): number | undefined => {
	if (typeof value !== "number" || !Number.isFinite(value) || value <= 0) return undefined;
	if (!Number.isInteger(value)) return undefined;
	return value;
};

/**
 * Map an upstream row's token-limit fields onto pi's
 * `contextWindow` / `maxTokens`.
 *
 * Probes several common spellings because upstream proxies vary — feather
 * uses `context_length` / `max_tokens` (RFC 0002), llama.cpp's server
 * uses `max_model_len`, vLLM/OpenRouter proxies use other names. First
 * hit wins; undefined means "let the next layer try".
 *
 * @param row Upstream list item
 * @returns Token limits when the row advertised them
 */
const liveTokenLimits = (row: LiveRow): { contextWindow?: number; maxTokens?: number } => {
	const contextWindow =
		positiveInt(row.context_length) ??
		positiveInt(row.context_window) ??
		positiveInt(row.max_model_len) ??
		positiveInt(row.max_context_length);
	const maxTokens =
		positiveInt(row.max_tokens) ??
		positiveInt(row.max_completion_tokens) ??
		positiveInt(row.max_output_tokens);
	return { contextWindow, maxTokens };
};

/**
 * Map a live `/v1/models` row onto a pi provider model.
 *
 * Dispatches on the upstream `type` field:
 *
 * - `"classifier"` → `ClassifierModel<"typesafe-system-one">` so the
 *   inline classifier api can route through feather's proxy.
 * - `"image"` → dropped; no image api is registered for feather.
 * - missing or unknown → treated as `"chat"` for proxies that pre-date
 *   the field (same fallback the legacy registration used).
 *
 * Per-model overrides apply on top of the live row. The `compat` cast
 * widens to accept `AnthropicMessagesCompat` fields (e.g.
 * `forceAdaptiveThinking`); the runtime ignores them on the
 * `openai-completions` api, but the override layer keeps the same
 * shape it had in `models.json`.
 *
 * @param row Upstream list item
 * @returns Provider model config, or undefined when the row is unusable
 */
const toProviderModel = (row: LiveRow): AnyModel | undefined => {
	if (typeof row.id !== "string" || row.id.length === 0) return undefined;
	const limits = liveTokenLimits(row);
	const upstreamType = typeof row.type === "string" ? row.type : "chat";

	if (upstreamType === "classifier") {
		const override = MODEL_OVERRIDES.classifier[row.id];
		const model: ClassifierModel<"typesafe-system-one"> = {
			id: row.id,
			type: "classifier",
			api: "typesafe-system-one",
			provider: FEATHER_ID,
			baseUrl: FEATHER_BASE_URL,
			name: (typeof row.name === "string" && row.name) || override?.name || row.id,
			input: override?.input ?? ["text"],
			cost: override?.cost ?? ZERO_COST,
			contextWindow: limits.contextWindow ?? override?.contextWindow ?? FALLBACK_CONTEXT_WINDOW,
		};
		return model;
	}

	if (upstreamType === "image") {
		return undefined;
	}

	const override = MODEL_OVERRIDES.chat[row.id];
	const compat = { ...FEATHER_COMPAT, ...override?.compat };
	const compatField = Object.keys(compat).length > 0 ? compat : undefined;
	const model: ChatModel<"openai-completions"> = {
		id: row.id,
		api: "openai-completions",
		provider: FEATHER_ID,
		baseUrl: FEATHER_BASE_URL,
		name: (typeof row.name === "string" && row.name) || override?.name || row.id,
		reasoning: override?.reasoning ?? true,
		input: override?.input ?? ["text", "image"],
		cost: override?.cost ?? ZERO_COST,
		contextWindow: limits.contextWindow ?? override?.contextWindow ?? FALLBACK_CONTEXT_WINDOW,
		maxTokens: limits.maxTokens ?? override?.maxTokens ?? FALLBACK_MAX_TOKENS,
		samplingParams: override?.samplingParams,
		compat: compatField as ChatModel<"openai-completions">["compat"],
	};
	return model;
};

/**
 * Fetch `{baseUrl}/models` and map the list into pi provider model
 * configs.
 *
 * Throws on transport error, non-2xx status, or empty `data[]` — pi then
 * keeps the previously-cached model list visible to `/model` rather than
 * silently dropping the provider.
 *
 * @param signal Abort signal from pi's refresh
 * @param apiKey Optional bearer token
 * @returns Discovered models
 */
const fetchFeatherModels = async (
	signal: AbortSignal,
	apiKey: string | undefined,
): Promise<readonly AnyModel[]> => {
	const url = `${FEATHER_BASE_URL.replace(/\/$/, "")}/models`;
	const headers: Record<string, string> = { Accept: "application/json" };
	if (apiKey) headers.Authorization = `Bearer ${apiKey}`;
	const response = await fetch(url, { signal, headers });
	if (!response.ok) {
		throw new Error(`GET ${url} → ${response.status}`);
	}
	const payload = (await response.json()) as { data?: LiveRow[] };
	const rows = Array.isArray(payload.data) ? payload.data : [];
	const models = rows
		.map((row) => toProviderModel(row))
		.filter((model): model is AnyModel => model !== undefined);
	if (models.length === 0) {
		throw new Error(`GET ${url} returned no models`);
	}
	return models;
};

/**
 * Pick the best API key for the refresh request.
 *
 * `context.credential` is the stored `auth.json` entry, populated by
 * `/login`. When absent (env-only setup), fall back to the configured
 * environment variable. `!command` interpolation is intentionally
 * skipped at refresh — invoking a subprocess from a network fetch path is
 * an unnecessary side effect.
 *
 * @param credential Stored credential from auth.json, if any
 * @param envVar Environment variable name to read when no stored key
 * @returns Resolved key, or undefined
 */
const resolveRefreshApiKey = (
	credential: Credential | undefined,
	envVar: string,
): string | undefined => {
	const stored = credential as ApiKeyCredential | undefined;
	if (stored?.type === "api_key" && typeof stored.key === "string" && stored.key.length > 0) {
		return stored.key;
	}
	const value = process.env[envVar];
	return value && value.length > 0 ? value : undefined;
};

/**
 * Read feather's persisted catalog from pi's `models-store.json`.
 *
 * Read-only: pi owns the file and writes it via `context.publish`. Any
 * parse or shape problem yields an empty list so startup falls through
 * to the network fetch instead of failing.
 *
 * @returns Cached feather models, or an empty list when none are stored
 */
const readStoredFeatherModels = (): readonly AnyModel[] => {
	const path = join(getAgentDir(), MODELS_STORE_FILE);
	if (!existsSync(path)) return [];
	try {
		const store = JSON.parse(readFileSync(path, "utf8")) as Record<string, ModelsStoreEntry | undefined>;
		const models = store[FEATHER_ID]?.models;
		if (!Array.isArray(models)) return [];
		return models.filter((model) => model.provider === FEATHER_ID);
	} catch {
		return [];
	}
};

/**
 * `PI_OFFLINE` as pi reads it (`--offline` sets it to `"1"`).
 *
 * @returns True when pi runs offline and startup must not touch the network
 */
const isOffline = (): boolean => {
	const value = process.env.PI_OFFLINE?.toLowerCase();
	return value === "1" || value === "true" || value === "yes";
};

/**
 * Resolve the baseline model list for `createProvider({ models })`.
 *
 * Stored catalog first; on a cold store, one bounded network fetch using
 * the env API key (the factory has no access to `auth.json` credentials,
 * so a `/login`-only setup gets its models on the first interactive
 * refresh instead). Never throws.
 *
 * @returns Models to register immediately, possibly empty
 */
const loadStartupModels = async (): Promise<readonly AnyModel[]> => {
	const stored = readStoredFeatherModels();
	if (stored.length > 0) return stored;
	if (isOffline()) return [];
	try {
		const apiKey = resolveRefreshApiKey(undefined, FEATHER_API_KEY_ENV);
		return await fetchFeatherModels(AbortSignal.timeout(STARTUP_FETCH_TIMEOUT_MS), apiKey);
	} catch {
		return [];
	}
};

// ---------------------------------------------------------------------------
// TypeSafe System One classifier api (inline)
// ---------------------------------------------------------------------------
// Pi's extension loader aliases `@earendil-works/pi-ai` and the compat
// subpath, but not the per-api lazy subpaths. The `./api/*` exports in
// pi-ai's package.json only declare an `import` condition, so a CJS-style
// `require` (which is how jiti resolves imports in transpiled .ts files)
// cannot find them. We re-declare a minimal `typesafe-system-one` wrapper
// here. The wire protocol is documented at https://docs.typesafe.sh and is
// the same one pi-ai's built-in implementation speaks, so feather and any
// compatible proxy works the same way.

const isRecord = (value: unknown): value is Record<string, unknown> =>
	typeof value === "object" && value !== null && !Array.isArray(value);

/**
 * Require a finite numeric field on the wire payload. Throws when the
 * service returns a value pi cannot trust.
 *
 * @param label Service name used in error messages
 * @param value Raw field value
 * @param field Human-friendly field name
 * @returns The value as a number
 */
const requiredNumber = (label: string, value: unknown, field: string): number => {
	if (typeof value !== "number" || !Number.isFinite(value)) {
		throw new Error(`${label} returned an invalid ${field}`);
	}
	return value;
};

/**
 * TypeSafe's documented choice confidence,
 * `(n * peak - 1) / (n - 1)`, clamped to [0, 1].
 *
 * @param probabilities Per-label probability mass
 * @returns Confidence score
 */
const peakConfidence = (probabilities: Record<string, number>): number => {
	const values = Object.values(probabilities);
	if (values.length === 0) return 0;
	const peak = Math.max(...values);
	if (values.length === 1) return peak;
	return Math.max(0, Math.min(1, (values.length * peak - 1) / (values.length - 1)));
};

/**
 * Parse the per-question `{ answers: { ... } }` payload into the public
 * `ClassifierAnswer` shape. Each question type maps to a different wire
 * format — `bool` arrives as `noul` with a single probability, while
 * `choice` and `score` carry a confidence value.
 *
 * @param label Service name for error messages
 * @param value Raw answers payload
 * @param context Classifier request context
 * @returns Parsed answers keyed by question id
 */
const parseAnswers = (
	label: string,
	value: unknown,
	context: ClassifierContext,
): Record<string, ClassifierAnswer> => {
	if (!isRecord(value)) {
		throw new Error(`${label} returned an unexpected response`);
	}
	const parsed: Record<string, ClassifierAnswer> = {};
	for (const [id, question] of Object.entries(context.questions)) {
		const answer = value[id];
		if (!isRecord(answer)) {
			throw new Error(`${label} did not return an answer for ${id}`);
		}
		if (question.type === "choice") {
			if (answer.type !== "choice" || typeof answer.choice !== "string") {
				throw new Error(`${label} did not return a choice answer for ${id}`);
			}
			if (!isRecord(answer.probabilities)) {
				throw new Error(`${label} returned invalid probabilities for ${id}`);
			}
			const probabilities: Record<string, number> = {};
			for (const [key, probability] of Object.entries(answer.probabilities)) {
				probabilities[key] = requiredNumber(label, probability, `probability for ${id}.${key}`);
			}
			parsed[id] = {
				type: "choice",
				choice: answer.choice,
				probabilities,
				confidence: requiredNumber(label, answer.confidence, `confidence for ${id}`),
			};
		} else if (question.type === "score") {
			if (answer.type !== "score") {
				throw new Error(`${label} did not return a score answer for ${id}`);
			}
			parsed[id] = {
				type: "score",
				score: requiredNumber(label, answer.score, `score for ${id}`),
				confidence: requiredNumber(label, answer.confidence, `confidence for ${id}`),
			};
		} else {
			if (answer.type !== "noul") {
				throw new Error(`${label} did not return a bool answer for ${id}`);
			}
			parsed[id] = {
				type: "bool",
				probability: requiredNumber(label, answer.noul, `probability for ${id}`),
			};
		}
	}
	return parsed;
};

/**
 * Map public `bool` questions to TypeSafe's wire-level `noul` type.
 *
 * @param context Classifier request context
 * @returns Wire-level request body
 */
const wireRequest = (
	context: ClassifierContext,
): { state: JsonObject; questions: Record<string, unknown> } => ({
	state: context.state,
	questions: Object.fromEntries(
		Object.entries(context.questions).map(([id, question]) => [
			id,
			question.type === "bool"
				? ({ ...question, type: "noul" } as unknown as ClassifierQuestion)
				: question,
		]),
	),
});

/**
 * Build the System One request URL against the model baseUrl.
 *
 * The transport prepends the model baseUrl to `systemone`, matching
 * pi-ai's built-in implementation and OpenRouter's documented endpoint.
 */
const systemOneUrl = (baseUrl: string): string =>
	new URL("systemone", `${baseUrl.replace(/\/+$/u, "")}/`).toString();

/**
 * Build the System One request payload — wraps the wire body with the
 * model id so the upstream can route the call.
 */
const systemOnePayload = (
	model: ClassifierModel<"typesafe-system-one">,
	wire: { state: JsonObject; questions: Record<string, unknown> },
): Record<string, unknown> => ({ model: model.id, ...wire });

/**
 * Run one System One classification against feather's proxy.
 *
 * @param model The classifier model entry (carries the upstream id and baseUrl)
 * @param context Question state and definitions
 * @param options Classifier options — api key, abort signal, hooks
 * @returns Classifier result, populated on success or with an error
 */
const classifySystemOne = async (
	model: ClassifierModel<"typesafe-system-one">,
	context: ClassifierContext,
	options: {
		apiKey?: string;
		signal?: AbortSignal;
		timeoutMs?: number;
		fetch?: typeof fetch;
		maxRetries?: number;
		maxRetryDelayMs?: number;
		headers?: Record<string, string | null>;
	} = {},
): Promise<ClassifierResult> => {
	const output: ClassifierResult = {
		api: model.api,
		provider: model.provider,
		model: model.id,
		answers: {},
		stopReason: "stop",
		timestamp: Date.now(),
	};
	try {
		if (!options.apiKey) {
			throw new Error(`No API key for provider: ${model.provider}`);
		}
		const headers: Record<string, string> = {
			Authorization: `Bearer ${options.apiKey}`,
			"Content-Type": "application/json",
			...(model.headers ?? {}),
			...(options.headers ?? {}),
		};
		const payload = systemOnePayload(model, wireRequest(context));
		const url = systemOneUrl(model.baseUrl);
		const requestFetch = options.fetch ?? globalThis.fetch;
		const timeoutSignal =
			options.timeoutMs !== undefined ? AbortSignal.timeout(options.timeoutMs) : undefined;
		const signal =
			options.signal && timeoutSignal
				? AbortSignal.any([options.signal, timeoutSignal])
				: (options.signal ?? timeoutSignal);
		const response = await requestFetch(url, {
			method: "POST",
			headers,
			body: JSON.stringify(payload),
			signal,
		});
		if (!response.ok) {
			throw new Error(`GET ${url} → ${response.status}`);
		}
		const body = (await response.json()) as Record<string, unknown>;
		if (!isRecord(body.answers)) {
			throw new Error(`System One returned an unexpected response`);
		}
		output.answers = parseAnswers("System One API", body.answers, context);
		return output;
	} catch (error) {
		output.stopReason = options.signal?.aborted ? "aborted" : "error";
		output.errorMessage = error instanceof Error ? error.message : String(error);
		return output;
	}
};

/**
 * Classifier api factory compatible with `ProviderClassifier`.
 *
 * The api is registered under the `"typesafe-system-one"` key on the
 * feather provider, matching pi-ai's classifier api id for System One.
 */
const featherClassifierApi = {
	classify: (
		model: ClassifierModel<"typesafe-system-one">,
		context: ClassifierContext,
		options?: {
			apiKey?: string;
			signal?: AbortSignal;
			timeoutMs?: number;
			fetch?: typeof fetch;
			maxRetries?: number;
			maxRetryDelayMs?: number;
			headers?: Record<string, string | null>;
		},
	): Promise<ClassifierResult> => classifySystemOne(model, context, options ?? {}),
};

export default async (pi: ExtensionAPI): Promise<void> => {
	const provider = createProvider({
		id: FEATHER_ID,
		name: FEATHER_NAME,
		baseUrl: FEATHER_BASE_URL,
		auth: { apiKey: envApiKeyAuth("Feather API key", [FEATHER_API_KEY_ENV]) },
		models: await loadStartupModels(),
		api: openAICompletionsApi(),
		classifiers: { "typesafe-system-one": featherClassifierApi },
		fetchModels: async (context) => {
			const apiKey = resolveRefreshApiKey(context.credential, FEATHER_API_KEY_ENV);
			return fetchFeatherModels(context.signal, apiKey);
		},
	});
	pi.registerProvider(provider);
};