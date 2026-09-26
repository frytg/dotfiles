---
name: linkedin-feed-briefing
description: Pull recent posts from the user's LinkedIn feed and write a one-page BLUF briefing in their voice. Tool-agnostic — works with any persistent browser automation (Osaurus, Playwright MCP, Browserbase, etc.) with a Firecrawl/Exa fallback for public-only summaries. Use when the user asks for a LinkedIn briefing, feed summary, "what's on my feed."
metadata:
  category: social
  auth-required: true (LinkedIn session)
---

# LinkedIn Feed Briefing

Pull the recent posts from the user's LinkedIn feed and turn them into a one-page BLUF briefing in their voice. The flow is the same regardless of browser tool — the post-extraction logic is the point, not the driver.

## When to use

- User asks for a LinkedIn briefing, feed summary, or "what's on my feed."
- Optional: name a scroll depth ("top 10") or time window ("since Tuesday").

## Reality check

- LinkedIn fights automation aggressively. A **persistent, logged-in browser session** is the only reliable path. Anonymous scraping via Firecrawl/Exa returns shallow, stale, and often blocked results — use it only as a smoke test or when the user has explicitly opted out of signing in.
- Login is a one-time gate. Plan for it; don't try to brute it.
- WebKit fingerprints (used by Osaurus today) trip LinkedIn's bot checks more often than Chromium. If sign-in fails repeatedly, surface it to the user instead of retrying.

## Flow

### 1. Pick a tool

Reach for whichever persistent browser tool is available. Examples:

| Tool                                          | Notes                                                                                                                                                                             |
| --------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Osaurus Browser** (`osaurus-browser` skill) | Native to this dotfiles repo; persistent per-agent session; helper window for login.                                                                                              |
| **Playwright MCP** (`@playwright/mcp`)        | Chromium; persistent context via `browser_install`/`browser_profile`; same `browser_navigate` / `browser_click` shape.                                                            |
| **Browserbase / Steel / Anchor**              | Hosted Chromium with profile cookies; usually exposed via `browser_session_create` + `browser_navigate`.                                                                          |
| **Firecrawl `scrape`**                        | No login. Returns a markdown snapshot of the public feed view — useful for one-off check-ins, not the full session-authenticated feed. Falls back here when login is unavailable. |
| **Exa `search`**                              | Last resort: query for `site:linkedin.com "<author>" "<keyword>"` to surface individual posts. Loses ordering, dedup, and recency guarantees.                                     |

Pick the first row that is loaded. Prefer anything that exposes a real browser with a logged-in session; fall back to Firecrawl/Exa only when nothing else works.

### 2. Navigate

Open the feed:

```
url: https://www.linkedin.com/feed/
```

If the response says login is required (auth wall, `LOGIN_REQUIRED` style error, or a redirect to `/login` or `/checkpoint`):

1. Tell the user: "I need to sign in to LinkedIn. Opening a window for you."
2. Open a browser window the user can interact with (Osaurus: `browser_open_login`; Playwright MCP: open the page and pause; hosted browsers usually have a "take over" mode).
3. Wait for the user to confirm in chat that they're done signing in.
4. Retry the navigate.

Never type credentials, 2FA codes, or OAuth approvals yourself. If sign-in fails repeatedly, surface the error and stop — don't hammer it.

### 3. Scroll and capture

The shape is the same in every browser tool:

1. Scroll the feed N times (default 3; more if the user asked for depth).
2. After each pass, snapshot the visible posts.
3. Stop when you hit the requested count or the posts stop being "recent" (>3 days or older).

Use the tool's batch / action primitive (Osaurus: `browser_do` with `scroll` action; Playwright MCP: `browser_evaluate` of `window.scrollBy`; hosted browsers: usually a `scroll` or `act` action). Wait for `networkidle` or `domstable` between passes so lazy-loaded posts render.

Capture per post:

- **Author name** + headline / title.
- **Post body** — first 1–3 lines or the headline takeaway. Don't paste whole posts.
- **Post URL** — the canonical `linkedin.com/posts/<activity-id>` permalink, not the internal feed item link. Required for hyperlinks.
- **Company / link card** (if present).
- **Relative time** (`1h`, `2d`).

Dedupe by author + headline. Keep the canonical permalink for every post; render plain text and flag it if a permalink is missing — never invent a URL.

### 4. Write the briefing (BLUF, your voice)

Deliver in the body of the reply:

```markdown
**Bottom line:** the 1–2 posts that matter, in one sentence. Hyperlink the posts that matter.

## Top posts

1. **Author** — [headline / takeaway](post-url) (time).
2. ...

## Threads to watch

The 1–3 recurring topics across the window.

## Worth a look

Anything relevant to: SWR/ARD, Eventhub, K8s, GitOps, AI, open-weight models, hybrid training.

If you only read one: <author> on <topic>.
```

Rules — these are tool-independent:

- One line per post. No padding.
- Pull takeaways, don't paste posts.
- Skip algorithm fluff, engagement bait, reposts of reposts, and "I'm humbled to announce" posts.
- Hyperlink the post that matters most in the "Bottom line" too.
- If a permalink is missing, render as plain text and say so.
- End with a single "If you only read one: …" line.

## Settings / tweaks

- **Depth**: more scroll passes = more posts. Default 3. Cap at ~10 unless the user asks for more.
- **Window**: filter captured posts by stated time. Default "recent" = up to ~3 days.
- **No-login mode**: when falling back to Firecrawl/Exa, drop the "Threads to watch" section if there's not enough signal, and say "public-only view" up top so the user knows what they're getting.

## What can go wrong

- **Login wall won't budge.** WebKit fingerprint trips the bot check. Tell the user; don't loop.
- **Posts are duplicated across scrolls.** The same promoted or pinned post shows up on every scroll pass. Dedupe by `activity-id` (extract from the permalink).
- **Captured time is wrong.** LinkedIn shows "1h" for anything in the last hour regardless of actual time. Trust the permalink's timestamp over the rendered relative time when they disagree.
- **Snapshot is empty after scroll.** The feed uses infinite-scroll virtualization; sometimes the snapshot grabs a partially-rendered view. Wait `networkidle` and retry once before falling back.
- **Rate-limited.** LinkedIn starts serving an interstitial after aggressive scrolling. Back off, wait a beat, and retry with fewer passes.
