---
name: podcast-bluf-summary
description: Summarize a podcast episode as a BLUF brief by downloading the audio and sending it to Gemini Pro via OpenRouter. Use when the user pastes a podcast link (especially podcasts.apple.com) and asks for a summary, brief, or recap. Resolves the audio URL with the podcast-audio-url skill and formats output per the bluf skill.
license: MIT
metadata:
  author: frytg
  agent: pi
---

# Podcast BLUF summary

Produce a BLUF summary of a podcast episode from its URL. The heavy lifting is done by a bundled script that downloads the audio and sends it base64-encoded to OpenRouter (OpenRouter does not accept audio URLs — base64 `input_audio` only), with the BLUF format instructions (`prompt.md`) given directly to the model. No pi extension needed; the script is the tool.

## Prerequisites

- `OPENROUTER_API_KEY` set in the environment (get one at https://openrouter.ai/keys). If unset, stop and tell the user — don't improvise another provider.
- `bun` on PATH (falls back to `node` ≥ 20, it's plain TypeScript with no dependencies).
- The `podcast-audio-url` skill for Apple Podcasts links.

## Workflow

1. **Resolve the audio URL.** If the user gave a `podcasts.apple.com` link (or any non-audio page), use the `podcast-audio-url` skill first to get `audioUrl` and `contentType`. If they pasted a direct audio link, skip to the next step.

2. **Run the summarizer.** Resolve `scripts/summarize-audio.ts` relative to this SKILL.md's directory:

   ```bash
   bun <skill-dir>/scripts/summarize-audio.ts \
     --url "<audioUrl>" \
     --content-type "<contentType>" \
     --model google/gemini-2.5-pro
   ```

   The script HEADs the file, downloads it, base64-encodes it, posts it to OpenRouter, and prints the summary markdown on stdout (progress and token usage on stderr). Default model is `google/gemini-2.5-pro`; pass `--model` to override (check openrouter.ai/models for current Gemini Pro IDs — the audio input modality is required).

3. **Present the output as-is.** The BLUF rules go straight to the model via `prompt.md` — do not re-summarize, reformat, or "improve" the model's output with a second pass. If it's genuinely broken (empty, wrong language, truncated), re-run the script rather than patching the text yourself.

4. **Append sources.** End the output with both links on their own lines (page URL first, then audio URL if different), so the summary is traceable:

   ```
   <pageUrl>
   <audioUrl>
   ```

5. **Present, don't publish.** Show the summary in chat. If the user wants it saved, offer the `obsidian` skill or a file — don't write it anywhere unprompted.

## Cost and size notes

- Long episodes are large payloads: a 60-minute MP3 is ~60 MB → ~80 MB base64. Gemini Pro handles hours of audio, but token usage scales with duration — mention the reported `usage` line if it looks expensive.
- The script refuses files over 300 MB (`--max-bytes` to override) and bails early if the URL serves HTML (a sign step 1 was skipped).

## Troubleshooting

- `openrouter 4xx: ... audio` — the chosen model lacks the audio input modality; switch `--model`.
- `URL serves HTML` — the input was a page link, not audio; run `podcast-audio-url` first.
- `Could not find audio URL in schema` from the extractor — Apple changed their page; report it, ask the user for the RSS feed or direct MP3 link.

## Optional: pi extension

Not required. If this becomes a daily driver, wrapping the script as a native pi custom tool (see pi's docs/extensions.md) would give first-class tool-call ergonomics and streaming progress — but the bundled script keeps the skill portable across harnesses, so prefer it until the friction is real.
