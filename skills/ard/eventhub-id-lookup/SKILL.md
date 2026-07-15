---
name: eventhub-id-lookup
description: Look up ARD Eventhub identifiers (publisher URNs, topic URNs, contribution CRIDs) for radio stations and individual contributions in Datadog logs of the SWR radiohub-ingest service. Maps human-readable inputs (station name, publisher Core ID, crid:// external id) to the hashed URNs the service actually logs, then queries structured Eventhub payloads. Use when the user asks about ingest activity for a specific station, contributor, or contribution in dev/stage/prod.
license: MIT
metadata:
  author: frytg
  agent: pi
---

# ARD Eventhub ID Lookup

The `swr-radiohub-ingest` service is a subscriber of the [ARD Eventhub](https://eventhub-ingest.ard.de/openapi/openapi.yaml) (v2.3.4 at time of writing, EUPL 1.2, contact `lab@swr.de`). The Eventhub uses **opaque hashed URNs** for everything it generates — topics, institutions — while the radio business side uses human-readable IDs (numeric Core IDs, `crid://<host>/Beitrag-…` external ids). The mapping between the two is **only stored in Datadog**, in the structured payload of each log line. There is no public endpoint to resolve a CRID or Core ID to a URN — you have to find it by querying a log that already contains both.

This skill covers the workflow: find the right URN, then query.

## Source of truth

The Eventhub OpenAPI spec is the canonical schema for what publishers post. Whenever a field, enum, or pattern in this skill disagrees with the spec, the spec wins.

- URL: `https://eventhub-ingest.ard.de/openapi/openapi.yaml`
- Key schemas: `eventV1PostBody` (radio track), `eventV1PostRadioTextBody` (encoder text), `services`, `reference`, `topicResponse`
- All event types are namespaced: `de.ard.eventhub.v1.radio.track.playing`, `de.ard.eventhub.v1.radio.track.next`, `de.ard.eventhub.v1.radio.text`

The `swr-radiohub-ingest` service may add or restructure fields on top of the Eventhub payload when it writes the log. The fields we observe in `data.data.message` are a wrapped form of `eventV1PostBody`; the spec describes the *input* shape, not the *logged* shape.

## Identifier forms

| Concept                    | Human-readable form                                  | Hash form in logs                                          |
| -------------------------- | ---------------------------------------------------- | ---------------------------------------------------------- |
| Station/publisher (Core ID) | numeric `publisherId` string (e.g. `'248000'`)       | `urn:ard:publisher:<16-hex>` (radiohub wraps the Core ID into a URN) |
| Topic / livestream channel | `crid://<host>/Beitrag-<uuid>` (the contribution `externalId`) | `urn:ard:permanent-livestream:<16-hex>`                    |
| Institution (sender)       | institution name                                     | `urn:ard:institution:<32-hex>-<26-char base32>`            |
| Individual track           | 8-hex `externalId`                                   | only present as `externalId` on the message                |

CRID hostnames are per-publisher and follow the `crid://<host>/<id>` pattern, where `<host>` is the publisher's domain (e.g. one of the public broadcasters' `.de` domains). The full set of valid hosts isn't published in the spec — they're whatever the publisher chose when registering the contribution.

Mapping rules (all observed, not derivable from inputs):

- The `publisherId` in the Eventhub spec is the **numeric Core ID** the publisher posts. The radiohub-ingest service wraps it as `urn:ard:publisher:<16-hex>` in the log; the same numeric ID is recoverable from a hash only by finding a log that already contains both.
- The `topic.id` (`urn:ard:permanent-livestream:<16-hex>`) is Eventhub-assigned and stable per channel.
- The `institution` URN is per-event — it contains a timestamp + short random suffix from the originating system, so it changes for the same institution across events.

You cannot compute any URN from the human-readable form. The only way to find a URN is to find a log line that already contains both.

## Datadog query template

```
service:swr-radiohub-ingest @data.stage:{stage} @data.source:{source} @data.data.message.services.topic.id:"{topic_urn}"
```

- `service` is always `swr-radiohub-ingest` (the ingest service).
- `stage` lives in **`@data.stage`**, not the `env` tag. Values seen: `dev`, `stage`, `prod`. The pod name (e.g. `swr-radiohub-ingest-prod-…`) is **not** authoritative.
- `source` lives in **`@data.source`**, not the `source` tag. The only value seen so far is `eventhub`.
- URN values contain colons; **always quote them** in the query: `field:"urn:ard:…"` — unquoted colons break the parser.

### What **doesn't** work

- `env:dev`, `env:stage` — the `env` tag is empty for this service.
- `source:eventhub` — the `source` tag is empty.
- Full-text search for the human-readable id (`crid://<host>/Beitrag-…` or a numeric Core ID or a station name) — the string is only present in the structured `data.data.message.services[].externalId` / `services[].publisherId` / `playlistItemId`, never in the rendered log line.
- `status:error OR warn OR notice` on a healthy topic — most successful topics are pure `info`.

## Tooling gotchas

These are real bugs in the Datadog MCP wrapper used in pi:

- **`search_datadog_logs` `extra_fields`** — must be passed as a **single string**, not an array. Passing `["data.data.message"]` fails with "expected an array of strings but received an object". Use `"data.data.message"` (one string).
- **`analyze_datadog_logs` `extra_columns`** — currently **broken** end-to-end (the array is received with an empty `name`). Don't rely on it. Use `search_datadog_logs` with `extra_fields` for structured access.
- The default SQL columns are only `timestamp, host, service, env, version, status, message`. To access custom JSON attributes, the search tool with `extra_fields` is the only working path right now.

## Output file location

When this skill produces a deliverable file (a JSON dump of ingested tracks, an Eventhub payload export, a CRID → URN lookup table, etc.), write it to **`~/Downloads/`** with a descriptive name. This is the only agreed-on output path for ad-hoc datadog exports — do not litter the working directory.

Naming pattern:

```
~/Downloads/<service>-<stage>-<source>-<topic-or-descriptor>-<YYYYMMDD>.json
```

Examples:

- `~/Downloads/radiohub-ingest-dev-eventhub-topic-A-20260715.json`
- `~/Downloads/radiohub-ingest-prod-eventhub-12h-window-20260715.json`

Strip the log envelope (`timestamp`, `message`, `service`, `status`, the `attributes.` nesting) before writing — keep only the `data.data.message` payloads. The `data.data.message.services[0]` block is the canonical "this is what station X contributed" record and is what downstream code usually wants.

## Looking up a station: three strategies

Strategy choice depends on what the user has in hand.

### A. You already have a known URN (from a previous lookup)

Use the canonical query above. Fastest, most precise.

### B. You have a human-readable id (publisher Core ID, CRID, station name)

You need to find a log that contains both the human-readable and the hashed form. Pick the angle that matches the hint:

1. **Station name in `playlistItemId`** — radio playlists are prefixed by station slug (look for `<station-slug>-<digits>-<8hex>` patterns in the rendered `message` field). Use the service log's own `message` text (which **does** contain the playlist id) to find a recent station activity log, then read the structured `data.data.message` to get the URNs.

   ```
   service:swr-radiohub-ingest @data.stage:dev message:"<station-slug>-"
   ```

   This returns the rendered log lines (`track-playlist done (7ms) > full > <station-slug>-…`). Pick one, then requery with the topic id from its `data.data.message` to get the full structured activity.

2. **`creator` address** — Eventhub messages from a given station have a per-station `creator` value (typically a per-station email; the OpenAPI doesn't define this field, it's added by the radiohub ingest). Query for recent logs and look for the desired creator in the structured `data.data.message`, then read out the topic URN from `services[0].topic.id`.

   ```
   service:swr-radiohub-ingest @data.stage:dev @data.source:eventhub
   ```

   Then page through recent logs with `extra_fields: "data.data.message"` and grep the result.

3. **Counting, not finding a specific line** — if `extra_columns` were working you'd `GROUP BY @data.data.message.services.topic.id` to enumerate all topics. With it broken, page through results and de-duplicate client-side.

### C. You have nothing — exploring what's in a stage

Two useful aggregations when `extra_columns` is fixed:

- Distinct publishers per stage: `GROUP BY services[].publisherId` (counts of `1x urn:ard:publisher:…` in the rendered log line is a workable proxy even without the structured field).
- Distinct topics per publisher: same approach, but on `services[].topic.id`.

Until the bug is fixed, the practical workaround is to page through the search results for a short window and de-duplicate the URNs from the `data.data.message.services` arrays.

## Reading the structured payload

`@data.data.message` is the radiohub-ingest's wrapped form of the Eventhub `eventV1PostBody`. Only the fields we actually query or read are listed below; for the full schema (contributors, references, media, plugins, hfdbIds, isrc, upc, mpn, …) see the [OpenAPI spec](https://eventhub-ingest.ard.de/openapi/openapi.yaml) (`eventV1PostBody`).

### Core fields (read these)

| Field             | Type                | Notes                                                                            |
| ----------------- | ------------------- | -------------------------------------------------------------------------------- |
| `event`           | enum                | `de.ard.eventhub.v1.radio.track.playing` \| `.track.next` \| `.text`. |
| `type`            | enum                | `audio` \| `commercial` \| `jingle` \| `live` \| `music` \| `news` \| `traffic` \| `weather`. |
| `start`           | ISO 8601 string     | When the track starts.                                                            |
| `length`          | float (seconds)     | Scheduled length. Nullable.                                                       |
| `title`           | string              | Representative title.                                                            |
| `artist`          | string              | Pre-formatted artist info. Nullable.                                              |
| `playlistItemId`  | string              | `<station-slug>-<digits>-<8hex>` — connects `next` and `playing` items within a publisher. |
| `id`              | string              | Eventhub-assigned numeric/string id for the event.                                |
| `creator`         | string              | **Added by the radiohub ingest** (not in the spec). Per-station value, often an email-shaped string. |
| `created`         | ISO 8601 string     | **Added by the radiohub ingest** (not in the spec). When the Eventhub message was sent. |

### `services[]` (query target — read this carefully)

Each `data.data.message` carries a `services[]` array. This is what we filter on and what holds the ID mapping.

| Field         | Required? | Type   | Notes |
| ------------- | --------- | ------ | ----- |
| `type`        | yes       | enum   | `EventLivestream` \| `PermanentLivestream`. |
| `externalId`  | yes       | string | `crid://<host>/<id>` or `brid://…` (spec regex: `^(c\|b)rid://.+$`). The contribution this delivery is for. |
| `publisherId` | yes       | string | Numeric Core ID in the spec (e.g. `'248000'`); the radiohub wraps it into `urn:ard:publisher:<hex>` in the log. |
| `id`          | no        | string | Eventhub-assigned URN. In the radiohub log this is the **topic** URN and is nested under `services[].topic.id` instead of being on `services[].id` directly. |
| `topic.id`    | (log only) | string | `urn:ard:permanent-livestream:<16-hex>` — the value we filter on with the canonical query. |

`@data.data.message.services[0]` is usually the only entry, but in principle there can be several (one per delivery target). The first one is the canonical "this is what station X contributed" record.

In `search_datadog_logs` output the full payload appears as `attributes.custom.data.data.message`; that nesting is the "log envelope" the user usually wants stripped off.

## Common workflows

**"Is station X (Core ID N) publishing right now in dev?"**

1. Confirm you have the publisher URN. If not, find one recent log with the station's `playlistItemId` prefix (e.g. `message:"<station-slug>-"`) and read `services[0].publisherId` from `data.data.message`.
2. Run the canonical query with that URN's topic id (or just the publisher, by dropping the topic clause if you want all topics from that publisher).
3. Count: `analyze_datadog_logs` with `filter: <query>` and `sql_query: "SELECT count(*) FROM logs"`.
4. Check for gaps: `sql_query: "SELECT DATE_TRUNC('hour', timestamp) AS h, count(*) FROM logs GROUP BY h ORDER BY h DESC LIMIT 48"`.

**"Look up a specific contribution by its CRID"**

1. Find one log that has the CRID in `services[].externalId`. Plain-text search of the CRID returns 0 — you have to look at structured `data.data.message` of recent logs. Filter by stage + source and page through `extra_fields: "data.data.message"` results, or by station prefix in the rendered `message` first.
2. Once you have a single matching log, note the `services[0].topic.id` (topic URN) and use that for the canonical query.
3. Or, if you only have the CRID and want to find any log mentioning it, broaden the time window and read raw `data.data.message` from a few candidates — the CRID appears in `services[].externalId` only.

**"Enumerate all publishers active in dev"**

1. `search_datadog_logs` with `service:swr-radiohub-ingest @data.stage:dev @data.source:eventhub`, sort `-timestamp`, and `extra_fields: "data.data.message"`.
2. Page through with `start_at` (response is paginated; max_tokens limits single-page size).
3. De-duplicate `data.data.message.services[].publisherId` per page.

**"Write the last 10 ingested tracks to a file"**

Use the canonical query, page size 10, `sort: -timestamp`, `extra_fields: "data.data.message"`. Then extract just the `data.data.message` array (strip the log envelope: `timestamp`, `message`, `service`, `status`, the `attributes` wrapper) and write to `~/Downloads/<service>-<stage>-<source>-<topic-or-descriptor>-<YYYYMMDD>.json`. Each entry is the Eventhub payload verbatim. The structured `data.data.message.services[0]` is the canonical "this is what station X contributed" record.

**"Find a topic by its `stage` label"**

The `topics` endpoint in the OpenAPI returns topic objects with a `labels` object that includes `stage`. For ingested topics, this label is set when the topic is created. If you know the `stage` value (`dev`/`stage`/`prod`) but not the URN, the workflow is the same as B: find any recent log from the right `@data.stage` and read the topic URN out of `data.data.message.services[0].topic.id`. The radiohub does not log the `labels` object directly.

## Worked example (synthetic)

Two stations are active in dev:

- Station A: Core ID `29001`, topic URN `urn:ard:permanent-livestream:0000ffff5678abcd`, contribution CRID `crid://<host-a>/Beitrag-aaaa1111-bbbb-2222-cccc-3333dddd4444`.
- Station B: Core ID `29002`, topic URN `urn:ard:permanent-livestream:1111eeee2222ffff`, contribution CRID `crid://<host-b>/Beitrag-11112222-3333-4444-5555-6666aaaa7777`.

Query for station A:

```
service:swr-radiohub-ingest @data.stage:dev @data.source:eventhub @data.data.message.services.topic.id:"urn:ard:permanent-livestream:0000ffff5678abcd"
```

A typical entry in the response:

- `event: de.ard.eventhub.v1.radio.track.playing`
- `type: music` (one of the spec's allowed values)
- `services[0].type: PermanentLivestream`
- `services[0].externalId: crid://<host-a>/Beitrag-aaaa1111-bbbb-2222-cccc-3333dddd4444`
- `services[0].publisherId: urn:ard:publisher:0000abcd1234ef56` (radiohub-wrapped form of Core ID `29001`)
- `services[0].topic.id: urn:ard:permanent-livestream:0000ffff5678abcd`
- `playlistItemId: <station-slug>-1784125783186-AABBCC01` (matches the spec's `<publisher-id>-<digits>-<id>` shape)

## Safety

- **Read-only.** This skill only queries Datadog; it never edits Eventhub messages, services, or topics.
- **Don't compute URNs.** If the user asks "what's the URN for Core ID 248000?", the only honest answer is "I have to find it in a log". There is no deterministic mapping you can run.
- **The OpenAPI spec is the source of truth** for field names, types, and enums. If a log disagrees, suspect the radiohub wrapper, not the spec.
- **Quote URNs in queries.** Bare colons in field values break the Datadog query parser; always `"urn:ard:…"` with double quotes.
- **Use `@data.stage` and `@data.source`, not the tags.** The `env`/`source` tags are empty for this service — searching on them returns 0 by design.
- **Don't trust the pod name for stage.** Pods may be named `prod` while logging `data.stage: dev`. Always filter on `@data.stage` if stage matters.
- **Output to `~/Downloads` only.** Don't write exported payloads to `/tmp` or the working directory; the agreed-on location is `~/Downloads/`.
- **The Datadog MCP wrapper has a known bug** with array parameters (`extra_fields`, `extra_columns`). Pass `extra_fields` as a single string; avoid `extra_columns` until it's fixed.
