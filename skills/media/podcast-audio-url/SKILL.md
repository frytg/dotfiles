---
name: podcast-audio-url
description: Resolve a podcast URL (Apple Podcasts episode/show page, or an already-direct audio link) to the direct audio file URL plus its normalized content type. Use when the user pastes a podcasts.apple.com link and the audio file is needed — e.g. before downloading, transcribing, or summarizing an episode (pairs with the podcast-bluf-summary skill).
license: MIT
metadata:
  author: frytg
  agent: pi
---

# Podcast audio URL extraction

Turn a human-facing podcast page URL into the direct audio file URL. Apple Podcasts pages are the main case — the audio URL is buried in embedded JSON, not in an obvious tag.

## Input

A podcast URL. Handle these cases:

1. `https://podcasts.apple.com/...` — extract from embedded schema data (below).
2. Anything already ending in an audio extension (`.mp3`, `.m4a`, `.mp4`, `.aac`, `.wav`, `.ogg`, `.flac`) — use as-is.
3. Anything else — treat as a direct audio URL candidate and verify with the HEAD request below. If the HEAD returns HTML, stop and ask the user for an RSS feed or episode link instead of guessing.

## Apple Podcasts extraction

Episode URLs are preferred (they contain `?i=<episodeId>`). Show URLs work but resolve to whatever episode the page promotes first.

Fetch the page HTML with a browser user agent:

```bash
curl -sL -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36" "<URL>"
```

The page embeds JSON in a `<script id="serialized-server-data">` tag (top level is an array on some pages, an object on others — don't assume). Extract it, then deep-search for the first `streamUrl`:

```bash
# extract the serialized-server-data JSON, then deep-search any streamUrl
... | sed -n 's/.*<script[^>]*id="serialized-server-data"[^>]*>\(.*\)<\/script>.*/\1/p' \
    | jq -r '[.. | objects | .streamUrl? // empty] | first // empty'
```

The documented episode shape is `.[0].data.shelves[0].items[0].contextAction.episodeOffer.streamUrl`, but Apple reshuffles shelves and the top-level container — the deep search survives both.

Last-resort fallback — grep the raw HTML for the first stream URL without parsing:

```bash
... | grep -oE '"streamUrl":"https:[^"]+"' | head -1 | cut -d'"' -f4
```

If none of these produce a URL, stop and report that — don't invent one. Common causes: the link is a show page with no promoted episode, or Apple changed the page structure.

## Verify and normalize the content type

Always HEAD the resolved audio URL (cheap, catches dead links and mislabeled servers):

```bash
curl -sIL -X HEAD "<audioUrl>" | grep -iE '^(HTTP|content-type|content-length)'
```

Normalize the `content-type` header — podcast CDNs are sloppy:

- `binary/octet-stream` or `application/octet-stream` → infer from the URL extension: `.mp3` → `audio/mpeg`, `.mp4` → `audio/mp4`, `.m4a` → `audio/m4a`, `.aac` → `audio/aac`
- `text/plain` → `audio/mpeg` (podcast CDNs frequently serve MP3s as text)
- missing header → default `audio/mpeg`

## Output contract

Report back exactly:

- `pageUrl` — the original URL the user gave
- `audioUrl` — the direct audio file URL
- `contentType` — normalized content type
- `contentLength` — bytes, if the HEAD returned it (useful for cost/size estimates downstream)

Do not download the audio file in this skill — resolution and HEAD only. Downloading is the consumer's job (e.g. the podcast-bluf-summary skill).
