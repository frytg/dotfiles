---
name: better-uptime-incident-triage
description: Triage a Better Stack (Better Uptime) incident webhook delivered by the skill harness. Parse the payload, enrich with monitor/availability/timeline data, classify severity + blast radius + suspected cause + confidence + summary, draft a comment for the incident, and persist the event plus open questions to `MEMORIES.md` and a per-incident record in `INCIDENTS.md`. Posting the comment is delegated to the host MCP; if the host's Betterstack MCP is read-only (current state), the skill stops at the draft. Use when the harness surfaces an incident webhook, when the user says "triage this Better Uptime alert" with an incident id, or when a Betterstack MCP read tool returns an active incident that should be assessed.
license: MIT
metadata:
  author: frytg
  agent: pi
  category: observability
  source:
    - https://betterstack.com/docs/uptime/webhooks
    - https://betterstack.com/docs/uptime/api/list-all-incidents/
    - https://betterstack.com/docs/uptime/api/list-all-comments/
---

# Better Uptime incident triage

A Better Stack outgoing incident webhook lands in the skill harness as raw JSON. The skill turns that into a structured assessment (severity, blast radius, suspected cause, confidence, summary), drafts a comment for the incident, and persists both the event and any open questions to `MEMORIES.md` and `INCIDENTS.md` so future runs (or a future you) can iterate the rubric from accumulated context and user feedback.

**Posting the comment is delegated to the host's Betterstack MCP.** No env tokens are used; no REST API calls. The currently exposed `betterstack` MCP is read-only — it has tools for reading incidents, comments, timeline, monitor, availability, response times, heartbeats, on-call, status pages, dashboards, charts, metrics, errors, and ClickHouse SQL analytics, but no write tool for creating comments or changing incident state. The skill produces the comment draft either way; whether it actually lands on the incident depends on whether the host MCP grows a write tool. Don't fake the post.

**Acknowledge, resolve, reopen, and escalate are out of scope regardless.** Even when a write tool exists, those change state on the incident and require explicit per-turn user instruction.

## Source of truth

- **Outgoing webhooks:** <https://betterstack.com/docs/uptime/webhooks> — confirms the event types and that the body is JSON:API.
- **Incident attributes:** <https://betterstack.com/docs/uptime/api/list-all-incidents/> — canonical field list (`name`, `cause`, `status`, `started_at`, `acknowledged_at`, `resolved_at`, `team_name`, `regions`, `response_content`, `http_method`, `url`, `metadata`, `relationships.monitor.data.id`).
- **Comments API:** <https://betterstack.com/docs/uptime/api/list-all-comments/> — endpoint shape, response envelope.
- The **triage rubric** (severity, blast radius, cause categories, confidence) is defined in this skill, not in Better Stack. Update it here when the assessment quality needs to change.

## Input contract

The harness delivers the raw HTTP request body of a Better Stack outgoing webhook. The body is JSON:API. Five `incident.*` event types exist — `created`, `acknowledged`, `resolved`, `reopened`, `commented`. The skill acts on **two** of them and drops the rest:

| Event                   | Action                                                                                             |
| ----------------------- | -------------------------------------------------------------------------------------------------- |
| `incident.created`      | Run the full triage workflow.                                                                      |
| `incident.reopened`     | Run the full triage workflow — the previous resolution didn't hold.                                |
| `incident.acknowledged` | **Drop as a no-op.** Someone acked; no triage needed.                                              |
| `incident.resolved`     | **Drop as a no-op.** Fixed; no triage needed.                                                      |
| `incident.commented`    | Drop unless the user asks for a follow-up. A new human comment doesn't need an automated response. |

If the payload's `event` field is missing or none of the above, stop and ask the user — don't guess.

The `data` block for the acted-on events looks like:

```json
{
  "data": {
    "id": "23",
    "type": "incident",
    "attributes": {
      "name": "uptime homepage",
      "url": "https://example.com/",
      "http_method": "get",
      "cause": "Status 404",
      "started_at": "2025-03-09T17:37:56.662Z",
      "acknowledged_at": null,
      "resolved_at": null,
      "status": "Started",
      "team_name": "Testing team",
      "response_content": "404 Not Found\n...",
      "regions": ["us", "eu", "as", "au"],
      "escalation_policy_id": null,
      "call": true,
      "sms": true,
      "email": true,
      "push": true,
      "metadata": {
        "Request duration": [{ "type": "String", "value": "0.04" }],
        "Response code": [{ "type": "String", "value": "404" }]
      }
    },
    "relationships": {
      "monitor": { "data": { "id": "2", "type": "monitor" } }
    }
  }
}
```

`status` is one of `Started`, `Acknowledged`, `Resolved`. The webhook fires on every state change; treat re-deliveries of the same `data.id` + `attributes.status` as duplicates and skip the comment unless the user says otherwise.

**`incident.commented` events** — same body plus a top-level `comment` block with `content` and author. Useful to read but you typically won't post a triage comment in response to someone else's comment; treat it as a no-op unless the user asks.

**`monitor.*` events** are out of scope for this skill. If the harness surfaces one, hand off to a monitor-management skill or ask the user — do not classify.

## Tools

### Better Stack MCP (read AND write, when available)

The skill's only path to Better Stack is the host's Betterstack MCP. **No env tokens. No REST calls.** The skill never asks for or stores an API token.

**Read tools (always present):**

- `betterstack_incident` — full incident detail.
- `betterstack_incident_comments` — prior comments; prevents duplicate triage comments.
- `betterstack_incident_timeline` — start/ack/resolve events and who acted.
- `betterstack_incidents` — recent incidents for the same monitor.
- `betterstack_monitor` — the failing monitor (kind, URL, regions, interval, team).
- `betterstack_monitor_availability` — SLA; quantifies streaks.
- `betterstack_monitor_response_times` — p95/p99; separates slow-down from hard-down.
- `betterstack_heartbeat*` — the heartbeat family, in case the monitor is a heartbeat.
- `betterstack_on_call*` — only used if the assessment names who's paged.
- `betterstack_severities` / `betterstack_severity` — only if the team has configured severity levels.

**Write tools (host-dependent, may not exist):**

- The current `betterstack` MCP exposes no write tools. If a future MCP server adds a comment-create or incident-state-change tool, the skill will use it — but only for `create comment`, never for ack/resolve/reopen/escalate (those are out of scope).
- Discovery: list the betterstack server's tools at the start of a session; record the result in `MEMORIES.md` if a write tool exists, so the next run knows.

### Memory

Two Markdown files, both resolved by the harness (typically the working directory). The skill maintains both, appending as new incidents arrive and updating `INCIDENTS.md` in place when an existing incident is re-triage'd.

- **`MEMORIES.md`** — append-only log of short triage notes, one entry per triage, separated by `---`. Newest at the bottom. Read at session start to recover context: prior assessments, open questions, and a fast index of recent incidents.
- **`INCIDENTS.md`** — per-incident record file. One Markdown section per incident, keyed by incident id, with the full assessment, enrichment evidence, timeline, postmortem, and any user feedback. The deep context for "what happened with incident X".

If `MEMORIES.md` doesn't exist yet, create it with a top-level heading `# Memories` before appending the first entry. If `INCIDENTS.md` doesn't exist yet, create it with a top-level heading `# Incidents` and an empty file body; the first triage adds the first section.

The **Training loop** section at the end of this skill describes how the two files accumulate over time and how user feedback sharpens the rubric.

## Workflow

Run these in order. Skip a step only with a one-line reason in the chat.

### 1. Parse and validate

- Confirm the body parses and `data.type == "incident"`. If it's a different type, stop and ask the user.
- Extract `incident_id = data.id`, `monitor_id = data.relationships.monitor.data.id`, and the full `attributes`.
- Note `attributes.status` and `attributes.started_at` — they drive the comment header.
- Compute `age_seconds = (now - attributes.started_at)` in ISO durations. The comment header needs this.

### 2. Enrich

In parallel where the tools allow:

- `betterstack_incident` (re-fetch — the webhook body may be minutes old).
- `betterstack_incident_comments` — if a prior triage comment exists, do not duplicate; either append "Update:" or hand off.
- `betterstack_incident_timeline` — who already acted? Has it been acked or resolved and reopened?
- `betterstack_monitor` — kind (HTTP/TCP/ping/heartbeat/keyword), regions, check interval, expected status, team.
- `betterstack_monitor_response_times` — has latency been climbing, or is this a binary up/down?
- `betterstack_monitor_availability` — 24h/7d/30d uptime. If this monitor is already at 99.5% for the month, an isolated incident is not the story; a streak is.
- `betterstack_incidents` filtered to the same `monitor_id`, last 7d — has this been noisy?

If `attributes.cause` is null and `attributes.response_content` is non-null, treat the first ~200 chars of `response_content` as the cause hint. If both are null, write the cause as `(no cause reported by monitor)`.

### 3. Classify

Use the rubric below. Every field is required; pick the lowest severity that the evidence supports, not the highest. Confidence is honest: "low" is fine and useful.

### 4. Draft the comment (and post it if a write tool exists)

Build the comment from the **Comment template** below. Always render it in the chat for the user to see.

- If the host MCP exposes a `betterstack_*_comment_create` (or similarly named write) tool, call it with the rendered content. Show the user the tool name and the response.
- If the host MCP has no comment write tool, **stop at the draft**. Tell the user the assessment is in chat and the comment text is ready to paste. Do not silently drop the comment; do not pretend to have posted it; do not fall back to REST or env tokens.

The MCP also exposes `betterstack_incident_comments` for **reading** — don't confuse read with write. Reading is always safe; writing is conditional on the tool existing.

### 5. Persist to `MEMORIES.md` and `INCIDENTS.md`

Two writes, both required:

- **`MEMORIES.md`** — append the **Memory entry** below to the end of the file, prefixed with a `---` separator (except for the very first entry, which is preceded only by a blank line). The short triage note.
- **`INCIDENTS.md`** — add or update a section for the current incident id. If a section already exists, append a new sub-entry with the latest timestamp and any change in assessment; never delete the prior content. The full per-incident record. See **INCIDENTS.md section** below for the format.

The two files together are the agent's working memory across sessions.

## Classification rubric

Pick one value per field. The values are stable — when you change one, change it here and flag the change in memory as a learning.

### Severity

| Grade  | Meaning                                                   | Default trigger                                                                                                                              |
| ------ | --------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| **P1** | Customer-facing outage or data loss. Pages leadership.    | Production monitor down in ≥ 2 regions OR error rate / latency breach with active user impact described in metadata.                         |
| **P2** | Degraded service or single-region failure. Pages on-call. | Production monitor down in 1 region OR a heartbeat missing for > 2× interval OR a single monitor on a non-critical service down for > 5 min. |
| **P3** | Internal / non-customer-facing / informational.           | Heartbeat-only monitor, staging monitor, or an incident on a monitor whose `kind` is not user-facing.                                        |

Promote P3→P2 if the monitor's URL appears in any recent customer-facing incident group (`incident_group_id` set or recent related incidents). Demote P2→P1 if the same monitor triggered ≥ 3 incidents in the last hour (likely cascading).

### Blast radius

A free-form field, but always answer all three sub-questions:

- **Regions affected:** comma-separated list from `attributes.regions`; "all configured regions" if the list is empty.
- **User impact:** one sentence — "Customers in the EU hitting example.com see a 404" not "service is down".
- **Scope:** "isolated" (single monitor), "related" (multiple monitors on the same dependency), or "widespread" (multiple unrelated monitors).

### Suspected cause category

Pick exactly one:

- `infra` — cloud / network / DNS / load balancer.
- `app` — code, deployment, configuration change.
- `dependency` — downstream service or third-party API.
- `data` — database, cache, queue.
- `capacity` — saturation (CPU, memory, connections, rate limit).
- `external` — vendor / partner / certificate expiry.
- `unknown` — nothing in the payload or enrichment suggests a direction.

Cite the evidence in the summary, not just the category. "Suspected `app` — `response_content` is a 500 from the app, not the LB" beats "Suspected `app`".

### Confidence

- `high` — multiple signals agree (monitor kind + response content + recent incidents all point the same way).
- `medium` — one strong signal, no contradicting evidence.
- `low` — payload is thin (no `response_content`, no recent history) and the cause is a guess.

### Summary

Two to four sentences. Lead with the **observable fact** ("`GET /` returns 404 from `us-east-1` for the last 4 minutes"), then the **suspected cause with evidence**, then the **suggested next step** ("check the most recent deploy to the homepage service"). Do not invent action items the user didn't ask for.

## Comment template

Markdown rendered by Better Stack's comment view. Plain text is also fine; use markdown when structure helps.

```markdown
## Triage — {severity} ({confidence} confidence)

**Started:** {started_at_iso} ({age_minutes}m ago)
**Monitor:** {monitor_name} ({monitor_kind}, regions: {regions})
**Cause (reported):** {cause_or_response_excerpt}
**Suspected cause:** {category} — {one-line evidence}
**Blast radius:** {regions} · {user_impact} · {scope}

{summary_paragraph}

---

_Suggested next step: {next_step} • Triage by pi skill `better-uptime-incident-triage` at {iso_timestamp}_
```

The footer line is the audit trail. Keep it. When the rubric changes, the footer is what makes old comments traceable.

## Memory entry

Append a plain-text record to `MEMORIES.md`, one per incident. Lead with a timestamp in ISO 8601, then short labelled lines. Add a second plain-text record per open question (see the **Open questions** section). No JSON, no structured envelope — a future you (or a future agent) should be able to read these without a parser.

```
2025-03-09T17:38:00Z — incident 23, monitor 2
Severity: P2
Cause: app (medium confidence)
Blast radius: US and EU customers hitting / see 404; isolated
Summary: GET / returns 404 from us-east-1 for the last 4 minutes.
  Stock 404 from the app, not the LB, so likely a recent deploy.
  Suggested next step: check the homepage deploy in the last 30 minutes.
Evidence: 1 prior incident in 7 days; 24h availability 99.98%;
  p95 response time 412 ms
Comment: drafted (no write tool available)
Open questions: none
```

Lines to keep on every entry:

- **Timestamp** (ISO 8601, UTC) — the time the triage finished, not when the incident started.
- **Incident id and monitor id** — the join key for cross-referencing later.
- **Severity, cause, confidence** — the rubric's call.
- **Blast radius** — regions, who is affected, scope.
- **Summary** — the same two-to-four-sentence summary that goes into the comment.
- **Evidence** — the raw numbers (availability, p95, recent incident count, response content excerpt) that drove the call. Future rubric tuning is impossible without the inputs.
- **Comment** — one of `drafted` (rendered in chat, no write tool available), `posted` (host MCP write tool succeeded; add the comment id), or `skipped` (user asked for triage without a comment).
- **Open questions** — `none` if zero; otherwise point to the separate question records by their first line.

## Open questions

Anything you couldn't decide without the user, append a separate plain-text record to `MEMORIES.md` so it surfaces in future runs:

```
2025-03-09T17:38:00Z — open question for incident 23
Question: Monitor foo-prod-heartbeat is a heartbeat but the team
  treats it as P1 — should the rubric promote heartbeats to P2 by
  default?
Context: Incident 23 was a 12-minute heartbeat gap and I graded it
  P3. The user manually acked it as P1 in the timeline.
```

When the user answers, update the rubric **here** in this skill, append a record to `MEMORIES.md` noting the change, and add a `## Feedback` subsection to the relevant section in `INCIDENTS.md`. The skill is the durable rule; the memories are the audit log.

## Worked example (synthetic)

Payload arrives in the harness. The agent parses:

- `data.id = 451`, `data.attributes.status = "Started"`, `started_at = 2026-05-12T08:14:22Z`.
- `data.relationships.monitor.data.id = 88`.
- `data.attributes.cause = "Status 500"`, `data.attributes.regions = ["eu"]`, `data.attributes.response_content = "Internal Server Error\n..."`.

Enrichment:

- `betterstack_monitor` → `name = "api.orders.write"`, `kind = "http"`, `url = "https://api.example.com/orders"`, `team = "Orders"`, `regions = ["us", "eu"]`.
- `betterstack_monitor_availability` → 30d: 99.97%, 7d: 99.81%, 24h: 98.4% (degrading).
- `betterstack_monitor_response_times` → p95 jumped from 220ms to 1.4s over the last 90 minutes.
- `betterstack_incidents` (monitor 88, last 7d) → 4 prior incidents, all `infra` category, all resolved by LB rule change.
- `betterstack_incident_comments` → none yet.

Classification:

- Severity: **P1** (degradation turning into errors in 1 of 2 regions, but p95 climb suggests the other region is on the way; promote because of the trend).
- Blast radius: EU customers hitting `POST /orders`; orders placement degraded; "isolated" on this monitor but trending toward "widespread".
- Cause: `capacity` — p95 climbing over 90 min and then 5xx is the classic saturation shape. Cite the 1.4s p95.
- Confidence: `medium` — strong trend signal, no `response_content` hint about a specific component.
- Summary: "`POST /orders` returns 500 from `eu-west-1` after a 90-minute latency climb (p95 220ms → 1.4s). Likely capacity saturation, not a deploy — no recent ship to `orders`. Suggested next step: check `orders` pool saturation and connection counts to the upstream auth service before the EU region also tips over."

Comment drafted and rendered in chat. With the current read-only `betterstack` MCP, the draft is the deliverable — the user posts it. `MEMORIES.md` entry appended with `Comment: drafted (no write tool available)`. New section added to `INCIDENTS.md` for incident 451 with the assessment, evidence, and timeline. Two open questions logged in `MEMORIES.md`: "is `orders` on a shared pool with `auth` — should the rubric treat shared pools as `dependency` not `capacity`?" and "is the 24h availability drop expected given a known migration?".

## Safety

- **Read by default; comment only when a write tool exists.** If the host MCP has no comment-create tool, the comment stays a draft. Never invent a write path.
- **No env tokens, ever.** The skill never reads `BETTERSTACK_API_TOKEN` or any similar env var. There is no fallback to REST, no header smuggling. The host MCP is the only path to Better Stack.
- **Never change incident state.** Acknowledge, resolve, reopen, escalate are out of scope regardless of which write tools exist. State changes are loud and one-way; require explicit per-turn user instruction.
- **No retry storms.** If the comment write tool fails, surface the error and stop. Duplicates are visible in the incident timeline and look like automation gone wrong.
- **No secrets in the comment body.** The comment is a Better Stack audience; never include credentials, internal URLs behind auth, or PII.
- **Response content may contain user data.** `attributes.response_content` is a snapshot of the failing response; it can include form data, query strings, or stack traces with emails. Summarise, don't quote verbatim, when the content is over 200 chars or looks like it could contain PII.
- **Read before drafting.** Always re-fetch with `betterstack_incident` before rendering the comment; the webhook body can be minutes stale and a triage comment on a now-resolved incident is a small embarrassment.
- **The memory files are not logs.** Entries in `MEMORIES.md` and sections in `INCIDENTS.md` are durable assessment records. Don't dump raw webhook bodies into either; the rubric-shaped summary is the artifact, the raw body is throwaway.
- **Skill portability.** This skill is host-agnostic. The Betterstack MCP, `MEMORIES.md`, and `INCIDENTS.md` are the only external dependencies; everything else is in the rubric, which travels with the skill.

## Training loop

Over time, `MEMORIES.md` and `INCIDENTS.md` accumulate enough entries that the agent has working context for any future triage: what kinds of incidents this team sees, which monitors are noisy, which assessments the user has corrected, which open questions never got answered. User feedback is the input that makes the rubric drift toward the user's actual taste rather than the agent's first guess.

**At the start of every triage, read both files.** Search `MEMORIES.md` for recent entries on the same monitor or the same cause category; check the matching section in `INCIDENTS.md` for the full prior assessment and any feedback. A re-triage of an incident that was already triaged must respect the prior feedback.

**After every triage, write to both.** `MEMORIES.md` gets the short note (see **Memory entry**); `INCIDENTS.md` gets a section for the incident (see **INCIDENTS.md section**).

**When the user gives feedback** — "this should have been P2, not P3", "we treat heartbeats as P1 here", "the cause category is `dependency`, not `capacity`" — do three things in this order:

1. Update the rubric **in this skill file** so the next run starts from the corrected rule. The rubric is the durable definition of how the agent triages; feedback that doesn't reach the rubric is lost.
2. Append a short note to `MEMORIES.md` with the timestamp, the change, and the user's words.
3. Add a `## Feedback` subsection to the matching `INCIDENTS.md` section with the same change, in the user's words.

**What "good training" looks like.** After roughly thirty incidents, both files carry enough signal that the agent can answer "what kinds of incidents have we seen on this monitor, what did we get right, what did the user correct, which open questions keep recurring?" without re-fetching from Better Stack. The open-questions list should thin out as feedback resolves them; if it doesn't, the rubric itself is the problem — promote the recurring question into a rubric change.

**INCIDENTS.md section**

One Markdown section per incident, keyed by id. On a fresh incident, create the section at the end of the file. On a re-triage, find the existing section and append; never overwrite the prior content.

```
## Incident 451 — api.orders.write (2026-05-12)

Started: 2026-05-12T08:14:22Z
Status at triage: Started
Monitor: 88 (api.orders.write, http, regions us/eu)
Severity: P1
Cause: capacity (medium confidence)
Blast radius: EU customers hitting POST /orders; orders placement
  degraded; isolated on this monitor, trending toward widespread
Summary: POST /orders returns 500 from eu-west-1 after a 90-minute
  latency climb (p95 220ms -> 1.4s). Likely capacity saturation, not
  a deploy - no recent ship to orders. Suggested next step: check
  orders pool saturation and connection counts to the upstream auth
  service before the EU region also tips over.
Evidence: 30d 99.97%, 7d 99.81%, 24h 98.4% (degrading);
  p95 220ms -> 1.4s over 90 minutes;
  4 prior incidents on monitor 88 in 7 days, all infra, all resolved
  by LB rule change.
Comment: drafted (no write tool available)
Open questions: see MEMORIES.md

## Timeline
- 2026-05-12T08:14:22Z incident created
- 2026-05-12T08:38:00Z triage completed by pi

## Feedback
(none yet)
```

The `## Feedback` subsection is the part that grows over time. When the user comes back and corrects the assessment, append a dated bullet here. When a postmortem is added, add a `## Postmortem` subsection with the user's notes. The section is meant to be a long-lived record of one incident; `MEMORIES.md` is the index that points at it.
