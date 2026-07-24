#!/usr/bin/env bun
/**
 * summarize-audio.ts — download an audio file and summarize it via OpenRouter (Gemini Pro by default).
 *
 * OpenRouter does not accept audio URLs — the file must be downloaded and sent base64-encoded
 * as an `input_audio` content part on /api/v1/chat/completions.
 *
 * Usage:
 *   bun summarize-audio.ts --url <audioUrl> [--content-type audio/mpeg] [--model google/gemini-2.5-pro] \
 *     [--prompt-file <path>] [--max-bytes <n>]
 *
 * Env:
 *   OPENROUTER_API_KEY — required, get one at https://openrouter.ai/keys
 *
 * Output: summary markdown on stdout; progress and usage stats on stderr.
 */

import { readFile } from 'node:fs/promises'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

/** Minimal shape of the OpenRouter chat completions response we consume. */
interface ChatCompletion {
	choices?: { message?: { content?: string } }[]
	usage?: { prompt_tokens?: number; completion_tokens?: number; total_tokens?: number }
	error?: { message?: string }
}

const DEFAULT_MODEL = 'google/gemini-2.5-pro'
const DEFAULT_MAX_BYTES = 300 * 1024 * 1024 // 300 MB — generous, Gemini Pro takes hours of audio
const OPENROUTER_URL = 'https://openrouter.ai/api/v1/chat/completions'

/**
 * Fail with a message on stderr and a non-zero exit code.
 * @param message - human-readable error
 * @returns never — always exits
 */
const fail = (message: string): never => {
	console.error(`error: ${message}`)
	process.exit(1)
}

/**
 * Parse `--flag value` style CLI args.
 * @param argv - process.argv slice (without node/script)
 * @returns map of flag name to value
 */
const parseArgs = (argv: string[]): Record<string, string> => {
	const args: Record<string, string> = {}
	for (let i = 0; i < argv.length; i++) {
		const arg = argv[i]
		if (arg.startsWith('--')) {
			const key = arg.slice(2)
			const value = argv[i + 1]
			if (value === undefined || value.startsWith('--')) fail(`missing value for --${key}`)
			args[key] = value
			i++
		}
	}
	return args
}

/**
 * Map a content type (or URL extension fallback) to an OpenRouter input_audio format.
 * @param contentType - normalized content type, e.g. from the podcast-audio-url skill
 * @param url - audio URL, used for extension fallback
 * @returns OpenRouter audio format string (mp3, m4a, aac, wav, ogg, flac, aiff)
 */
const toAudioFormat = (contentType: string, url: string): string => {
	const type = contentType.toLowerCase()
	if (type.includes('mpeg') || type.includes('mp3')) return 'mp3'
	if (type.includes('mp4') || type.includes('m4a') || type.includes('x-m4a')) return 'm4a'
	if (type.includes('aac')) return 'aac'
	if (type.includes('wav')) return 'wav'
	if (type.includes('ogg')) return 'ogg'
	if (type.includes('flac')) return 'flac'
	if (type.includes('aiff')) return 'aiff'
	const ext = url.split('?')[0].split('.').pop()?.toLowerCase() ?? ''
	if (['mp3', 'm4a', 'aac', 'wav', 'ogg', 'flac', 'aiff'].includes(ext)) return ext === 'mp4' ? 'm4a' : ext
	return 'mp3' // podcast default
}

/**
 * HEAD the audio URL to learn its content type and size without downloading.
 * @param url - audio file URL
 * @returns content type and byte length (null if the server omits them)
 */
const headAudio = async (url: string): Promise<{ contentType: string | null; contentLength: number | null }> => {
	const res = await fetch(url, { method: 'HEAD', redirect: 'follow' })
	if (!res.ok) fail(`HEAD ${url} failed: ${res.status} ${res.statusText}`)
	const length = res.headers.get('content-length')
	return {
		contentType: res.headers.get('content-type'),
		contentLength: length === null ? null : Number.parseInt(length, 10),
	}
}

/**
 * Download the audio file and return it base64-encoded.
 * @param url - audio file URL
 * @param maxBytes - refuse files larger than this
 * @returns base64 string of the raw audio bytes
 */
const downloadBase64 = async (url: string, maxBytes: number): Promise<string> => {
	const res = await fetch(url, { redirect: 'follow' })
	if (!res.ok) fail(`download failed: ${res.status} ${res.statusText}`)
	const buf = Buffer.from(await res.arrayBuffer())
	if (buf.byteLength > maxBytes) fail(`audio is ${buf.byteLength} bytes, over the --max-bytes limit of ${maxBytes}`)
	console.error(`downloaded ${(buf.byteLength / 1024 / 1024).toFixed(1)} MB`)
	return buf.toString('base64')
}

/**
 * Send the audio to OpenRouter chat completions and return the assistant text.
 * @param apiKey - OpenRouter API key
 * @param model - OpenRouter model id
 * @param systemPrompt - system prompt steering the summary format
 * @param base64 - base64-encoded audio
 * @param format - input_audio format (mp3, m4a, ...)
 * @returns assistant message content
 */
const summarize = async (
	apiKey: string,
	model: string,
	systemPrompt: string,
	base64: string,
	format: string,
): Promise<ChatCompletion> => {
	const res = await fetch(OPENROUTER_URL, {
		method: 'POST',
		headers: {
			authorization: `Bearer ${apiKey}`,
			'content-type': 'application/json',
			'http-referer': 'https://github.com/frytg/skills',
			'x-title': 'podcast-bluf-summary skill',
		},
		body: JSON.stringify({
			model,
			messages: [
				{ role: 'system', content: systemPrompt },
				{
					role: 'user',
					content: [
						{ type: 'text', text: 'Summarize this podcast episode.' },
						{ type: 'input_audio', input_audio: { data: base64, format } },
					],
				},
			],
		}),
	})
	const body = (await res.json()) as ChatCompletion
	if (!res.ok) fail(`openrouter ${res.status}: ${body.error?.message ?? JSON.stringify(body)}`)
	return body
}

const main = async (): Promise<void> => {
	const args = parseArgs(process.argv.slice(2))
	const url = args.url ?? fail('missing --url <audioUrl>')

	// standalone script: no package context, so validate env inline instead of @frytg/check-required-env
	const apiKey = process.env.OPENROUTER_API_KEY ?? fail('OPENROUTER_API_KEY is not set')

	const model = args.model ?? DEFAULT_MODEL
	const maxBytes = args['max-bytes'] === undefined ? DEFAULT_MAX_BYTES : Number.parseInt(args['max-bytes'], 10)
	const scriptDir = dirname(fileURLToPath(import.meta.url))
	const promptFile = resolve(scriptDir, args['prompt-file'] ?? '../prompt.md')
	const systemPrompt = await readFile(promptFile, 'utf8').catch(() => fail(`could not read prompt file: ${promptFile}`))

	const head = await headAudio(url)
	if (head.contentType?.includes('text/html')) {
		fail(`URL serves HTML, not audio — resolve it with the podcast-audio-url skill first: ${url}`)
	}
	if (head.contentLength !== null && head.contentLength > maxBytes) {
		fail(`audio is ${head.contentLength} bytes, over the --max-bytes limit of ${maxBytes}`)
	}

	const contentType = args['content-type'] ?? head.contentType ?? 'audio/mpeg'
	const format = toAudioFormat(contentType, url)
	console.error(`model: ${model} | format: ${format} | content-type: ${contentType}`)

	const base64 = await downloadBase64(url, maxBytes)
	console.error('sending to openrouter…')
	const result = await summarize(apiKey, model, systemPrompt, base64, format)

	const text = result.choices?.[0]?.message?.content
	if (!text) fail(`empty response: ${JSON.stringify(result)}`)
	if (result.usage) console.error(`usage: ${JSON.stringify(result.usage)}`)
	console.log(text)
}

await main()
