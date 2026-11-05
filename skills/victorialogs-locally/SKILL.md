---
name: victorialogs-locally
description: Query the VictoriaLogs instance of the locally0 k3s cluster through the victorialogs MCP server. Covers the vector → victoria-logs pipeline, the log field structure (k8s_* fields, @frytg/logger conventions, JSON parse depth), and tested LogsQL patterns including known gotchas with wildcards and stats tools. Use when the user asks about logs, errors, events, or log history of services running on locally0.
license: MIT
metadata:
  author: frytg
  agent: pi
  category: engineering
  tags:
    - observability
    - homelab
    - logs
---

# VictoriaLogs on locally0

The `locally0` k3s cluster ships all container logs to a single-node VictoriaLogs instance (namespace `monitoring`). This skill is the map of that log store: how logs get their shape, what fields exist, and which queries are verified to work. All examples below were run against the live instance.

- Human UI: `https://victoria-logs.<tailnet>.ts.net/select/vmui/`
- MCP server: `mcp__victorialogs*` tools via codemode, backed by `ghcr.io/victoriametrics/mcp-victorialogs` (read-only query APIs + docs search) at `https://victoria-logs-mcp.<tailnet>.ts.net/mcp`
- Everything is read-only: query first, `kubectl` only when a fix is needed.

## Pipeline: how logs get their shape

A vector DaemonSet collects `kubernetes_logs` and pushes to VictoriaLogs. Two transforms matter:

1. **Tag remap** — kubernetes metadata is flattened to `k8s_namespace`, `k8s_pod_name`, `k8s_container_name`, `k8s_container_image`, `k8s_node_name`; the original `.kubernetes` and `.file` fields are deleted.
2. **JSON parse, `max_depth: 3`** — if the container's `message` is JSON, it is parsed up to depth 3 and merged into the log entry; `is_json` records whether parsing happened. Deeper objects stay as **escaped JSON strings** (a nested object at depth 4+ becomes a string field containing JSON, not a nested field).

The sink declares `_stream_fields=k8s_container,k8s_pod_name`, but the remap writes `k8s_container_name` (not `k8s_container`), so **the only stream field is `k8s_pod_name`**. Consequences: queries filter fast by pod name, and streams group by pod — a redeployed pod is a new stream.

`k8s_node_name` is always `locally0` (single-node cluster). leno0 logs are NOT in this instance.

## Field structure

Every log entry has these fields:

- `_msg` — the log message (or raw line for non-JSON logs)
- `_time` / `time` — ingestion timestamp (RFC3339, nanosecond precision)
- `_stream_id` / `_stream` — stream identity, effectively `{k8s_pod_name="…"}`
- `k8s_namespace`, `k8s_pod_name`, `k8s_container_name`, `k8s_container_image`, `k8s_node_name`
- `is_json` — `"true"` if the raw message was parsed as JSON

On top of that, services fall into three log shapes:

- **`@frytg/logger` services** — the platform convention. Fields: `serviceName`, `source` (subsystem, slash- or dot-separated), `level` (lowercase syslog: `info`, `error`, `warning`, `notice`, `debug`), `stage`, `runtime`, `host` (pod name), plus free-form `data.*` and `error.*` payloads. Errors carry `error.message` and `error.stack`, sometimes full `error.requestBodyValues` / `error.responseHeaders` from upstream API failures.
- **Other JSON-logging services** — fields follow whatever the app emits (e.g. request logs with `method`, `path`, `status`, `duration_ms`). `is_json:"true"` + the merged fields are queryable; watch for differing level conventions (some log uppercase `"INFO"`).
- **Plain-text services** — `is_json:"false"`, everything lives in `_msg`. Query them with word filters, not structured fields.

When the shape of a service is unknown, discover it first (see below) instead of assuming fields exist.

## MCP tools and gotchas (all verified live)

Available tools: `query` (raw NDJSON entries), `hits` (count per time bucket), `stats_query` / `stats_query_range` (LogsQL `| stats` pipes, Prometheus-style output), `streams`, `stream_field_names`, `stream_field_values`, `stream_ids`, `field_names`, `field_values`, `flags`, `documentation`.

Gotchas that cost real debugging time:

- **Quoted wildcard filters return empty**: `k8s_pod_name:"<app>*"` matches nothing because pod names tokenize on hyphens. Use a regex instead: `k8s_pod_name:~"<app>-.*"`. Plain word filters work when the value has no hyphens.
- **`hits` without an explicit `step` fails** with `cannot parse duration from the arg 'step='` — always pass `step` (e.g. `1h`).
- **`stats_query` requires a `time` point** and errors with `time param is required`; prefer `stats_query_range` with `start` + `end` + `step`.
- **`stream_field_values` only works on stream fields** — `k8s_pod_name` is the only one. For `k8s_namespace`, `level`, `source` etc. use `field_values` (takes any `field` + `query`).
- An empty result comes back as an empty string in `content[0].text`, not an error.
- `hits` is a counting tool; to read actual log lines use `query`.

## Query cookbook

```sh
# errors from a @frytg/logger service in the last 24h
serviceName:<service> level:error

# warnings from the same
serviceName:<service> level:warning

# errors scoped to one subsystem
source:<subsystem> level:error

# all logs of a deployment (regex, not quoted wildcard)
k8s_pod_name:~"<app>-.*"

# request logs by endpoint / status code (JSON-logging services)
path:"<endpoint>" status:<code>

# plain-text services: filter on exact words in _msg
k8s_pod_name:~"<app>-.*" "<failure-word>"
```

Counting and aggregation (run via `stats_query_range`, not `stats_query`):

```sh
# errors per subsystem over the last 24h, 1h buckets
serviceName:<service> level:error | stats by (source) count() as c

# log volume per namespace over the last 24h
* | stats by (k8s_namespace) count() as logs
```

Discovery patterns when the shape is unknown:

1. `field_values` with `query: '*'` on `k8s_namespace` or `k8s_pod_name` → what's running.
2. `field_names` with a scoped query, e.g. `query: 'k8s_pod_name:~"<app>-.*"'` → which structured fields that service actually logs.
3. `query` with `limit: 2` on the same filter → sample the real entries before writing a bigger query.
