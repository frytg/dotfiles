---
name: eventhub-active-publishers
description: Refresh the Aktive Datenlieferanten table in ARD Eventhub docs/index.md from Datadog logs of swr-radiohub-ingest. Resolves institution URNs from the ARD Core feed (just feed → ard-core-livestreams.json), then counts live metadata for Eventhub TEST vs PROD. Use when updating active publishers, broadcasters, Datenlieferanten, or the TEST/PROD checklist on the Eventhub docs homepage.
license: MIT
metadata:
  author: frytg
  agent: cursor
---

# Eventhub active publishers

Update the **Aktive Datenlieferanten** table in the Eventhub repo’s `docs/index.md` from live radiohub-ingest traffic.

## Target

- File: `docs/index.md` (section `## Aktive Datenlieferanten`)
- Columns: `Broadcaster | TEST | PROD`
- Marks: `✅` = activity in the window, `-` = none

Keep the existing broadcaster row order unless the user asks to change it.

## Stage mapping

`swr-radiohub-ingest` is a subscriber of Eventhub. Stage is **`@data.stage`**, not the `env` tag.

| Docs column | Datadog filter     | Meaning                                  |
| ----------- | ------------------ | ---------------------------------------- |
| TEST        | `@data.stage:dev`  | radiohub-dev receives Eventhub **test**  |
| PROD        | `@data.stage:prod` | radiohub-prod receives Eventhub **prod** |

Base filter (always):

```
service:swr-radiohub-ingest @data.source:eventhub
```

Default lookback: **24h** (`from: now-24h`). Widen to `now-7d` only if a known broadcaster looks missing and you need to confirm intermittency.

## Resolve institution IDs from ARD Core feed

Do **not** hardcode or paste institution URNs into this skill, the docs, or chat. They can change; always load them from the feed dump.

1. From the Eventhub repo root, refresh the feed:

   ```sh
   just feed
   ```

   This runs `src/cli/feed.ts` and writes `src/utils/ard-core-livestreams.json` (gitignored).

2. If `just feed` fails (e.g. 403 / network) and a recent `src/utils/ard-core-livestreams.json` already exists, reuse it and say so. If the file is missing, stop and ask.

3. Build a unique map from feed items:

   ```
   items[].publisher.institution.id        → urn:ard:institution:<hex>
   items[].publisher.institution.acronym   → short label
   items[].publisher.institution.title     → full name
   ```

4. Match docs row names to feed acronyms / titles:

   | Docs `Broadcaster` | Feed `acronym` (typical) |
   | ------------------ | ------------------------ |
   | BR                 | `BR`                     |
   | HR                 | `HR`                     |
   | MDR                | `MDR`                    |
   | NDR                | `NDR`                    |
   | Radio Bremen       | `RadioBremen`            |
   | RBB                | `RBB`                    |
   | SR                 | `SR`                     |
   | SWR                | `SWR`                    |
   | WDR                | `WDR`                    |
   | Deutschlandradio   | `Deutschlandradio`       |

   Skip feed institutions that are not rows in the table (e.g. umbrella `ARD`). If acronym spelling drifts, match on `title` / fuzzy Anstalt name — do not invent IDs.

5. For Datadog filters, take only the `<hex>` from `institution.id` (`urn:ard:institution:<hex>`). Never commit the feed JSON.

## Identity fields in Datadog

Do **not** use creator emails for lookups or aggregation.

Use:

1. **Institution prefix on `message.id`** (preferred)

   Logged as `@data.data.message.id`:

   ```
   urn:ard:institution:<hex>-<ulid-suffix>
   ```

   Filter with a wildcard on the feed-derived hex (escape colons):

   ```
   @data.data.message.id:urn\:ard\:institution\:<hex>*
   ```

2. **Publisher URN** (optional cross-check only)

   In log `message` text / `@data.data.message.services.publisherId` as `urn:ard:publisher:<hex>`. Many publishers per institution — not the primary rollup key.

## Workflow

1. `just feed` → read `src/utils/ard-core-livestreams.json` → Anstalt → institution hex map (in memory only).
2. Load Datadog logs + DDSQL skills; use `analyze_datadog_logs`.
3. For each docs-table Anstalt, run:

   ```text
   filter: service:swr-radiohub-ingest @data.source:eventhub @data.data.message.id:urn\:ard\:institution\:<hex>*
   from: now-24h
   sql: SELECT "@data.stage", count(*) AS cnt FROM logs GROUP BY "@data.stage"
   extra_columns: [{ name: "@data.stage", type: "varchar" }]
   ```

4. Mark TEST (`dev`) / PROD (`prod`) as `✅` if `cnt > 0`, else `-`.
5. Patch only the markdown table in `docs/index.md`.
6. Summarize deltas vs the previous table (who gained/lost TEST or PROD). Do not dump the institution URN list in the summary unless the user asks.

### Tooling notes

- Prefer counting via `analyze_datadog_logs` with the institution-prefix filter. Do not `GROUP BY` full `@data.data.message.id` — the ULID suffix makes every event unique.
- Quote / escape URN colons in filters.
- Never filter on `env:` or bare `source:` tags for this service; they are empty.
- Related: [eventhub-id-lookup](../eventhub-id-lookup/SKILL.md) for topic/CRID station lookups — not needed for this table refresh.

## Table template

```markdown
| Broadcaster      | TEST | PROD |
| ---------------- | ---- | ---- |
| BR               | ✅   | ✅   |
| HR               | ✅   | ✅   |
| MDR              | -    | ✅   |
| NDR              | -    | ✅   |
| Radio Bremen     | -    | ✅   |
| RBB              | ✅   | ✅   |
| SR               | ✅   | ✅   |
| SWR              | ✅   | ✅   |
| WDR              | ✅   | ✅   |
| Deutschlandradio | ✅   | -    |
```

Replace cells from the live counts; keep column alignment. The checkmarks above are illustrative only — always overwrite from Datadog.

## Safety

- Read-only Datadog. Do not post events or change Eventhub config.
- Do not hardcode institution IDs in skills, docs, or commits; always derive from `ard-core-livestreams.json`.
- Do not paste decrypted user emails into skills, docs, chat, or commits.
- Do not commit `src/utils/ard-core-livestreams.json` (gitignored).
