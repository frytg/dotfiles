---
name: atproto-md
description: Fetch any public AT Protocol data as clean Markdown — resolve handles/DIDs, browse repos, read records from any collection on any PDS (Bluesky or third-party lexicons), resolve lexicon schemas by NSID, discover every repo using a lexicon, explore backlinks, and trace a did:plc identity's history via its PLC audit log. Use whenever the user shares an at:// URI, a handle/DID, or a lexicon NSID (e.g. app.bsky.feed.post, site.standard.document), or asks to inspect AT Protocol / atproto / Bluesky / Standard.site data, or wants to know when an account migrated PDS or changed its handle.
metadata:
  source: https://atproto.md/skill.md
  repository: https://tangled.org/socialde.pt/atproto.md/
---

# atproto-md — AT Protocol Markdown API

Fetch any public AT Protocol data as clean Markdown. No auth, no API key required.
Works with **any collection on any PDS** — not just Bluesky.
Base URL: https://atproto.md

## When to use this skill

Use this API whenever the user asks to:

- Browse an AT Protocol repo or list someone's collections
- Read records from any AT Protocol collection (posts, profiles, follows, publications, etc.)
- Resolve a handle to a DID, or inspect someone's DID document and PDS
- Explore third-party lexicons that get rich Markdown formatting: Standard (`site.standard`), Leaflet (`pub.leaflet`), Offprint (`app.offprint`), Pocket (`blog.pckt`), Linkat (`blue.linkat`), Woosh (`link.woosh`), Smoke Signal (`events.smokesignal.calendar`), Wisp (`place.wisp`), Lexicon schemas (`com.atproto.lexicon.schema`), and Bluesky (`app.bsky.*`) — any other collection still renders as generic markdown
- Fetch content from any PDS on the AT Protocol network
- Dereference an `at://` URI
- Resolve a Lexicon schema definition by its NSID (e.g. inspect the `app.bsky.feed.post` schema)
- Discover every repo on the network using a given collection/lexicon (e.g. all repos with `site.standard.document`)
- Find who liked, reposted, replied to, follows, or otherwise links to a record, account, or URL (backlinks)
- Date a PDS migration or trace an account's handle/key history via its PLC audit log
- Inspect the rotation keys that control a did:plc identity (PLC data)

## How to call it

All endpoints return `Content-Type: text/markdown`. Just fetch the URL.
Open CORS — works from browser, server, or CLI.

```bash
# Resolve a handle or DID
curl https://atproto.md/resolve/bsky.app

# Trace a did:plc identity's history (PDS migrations, handle/key changes)
curl https://atproto.md/plc/audit/bsky.app

# Current PLC state — active PDS, handles, and rotation keys
curl https://atproto.md/plc/data/bsky.app

# Browse a repo (list all collections)
curl https://atproto.md/at://bsky.app

# List records in a collection
curl "https://atproto.md/at://bsky.app/app.bsky.feed.post?limit=5"

# Fetch a single record
curl https://atproto.md/at://bsky.app/app.bsky.actor.profile/self

# Resolve a Lexicon schema by NSID
curl https://atproto.md/lexicon/app.bsky.feed.post

# Discover every repo on the network with a given collection
curl https://atproto.md/discover/site.standard.document

# Find backlinks to a record (summary of all link sources)
curl https://atproto.md/backlinks/at://bsky.app/app.bsky.feed.post/3lgwdn7vd722r

# List the actual liking records
curl "https://atproto.md/backlinks/at://bsky.app/app.bsky.feed.post/3lgwdn7vd722r?source=app.bsky.feed.like:subject.uri"
```

## Endpoint reference

### Resolve identity

```
GET https://atproto.md/resolve/{actor}
```

Full identity chain: handle → DID → DID document → PDS endpoint.
Returns the DID, all `alsoKnownAs` handles, services, and verification keys.

### PLC audit log

```
GET https://atproto.md/plc/audit/{actor}
```

Chronological history of a `did:plc` identity from plc.directory, with each operation diffed
against the previous one. Surfaces PDS migrations (from/to endpoint and date), handle changes,
and signing/rotation key rotations — useful for dating a migration or verifying provenance.
`did:web` identities have no PLC log.

### PLC data

```
GET https://atproto.md/plc/data/{actor}
```

The current canonical PLC state — active PDS, all handles (`alsoKnownAs`), atproto signing key,
and rotation keys in priority order. Unlike `/resolve` (the DID document), this exposes the
rotation keys that actually control the identity.

### PLC last operation

```
GET https://atproto.md/plc/last/{actor}
```

The most recent PLC operation and the state it established (PDS, handles, keys, op type).
Lightweight "what changed last" check; use `/plc/audit` for the full dated history.

### Repo overview

```
GET https://atproto.md/at://{actor}
```

Lists all collections present in the actor's repo with links to browse each one.

### List records

```
GET https://atproto.md/at://{actor}/{collection}[?limit=&cursor=&reverse=]
```

Paginated list of records in any collection. Unknown collections are rendered as generic key-value markdown.

### Single record

```
GET https://atproto.md/at://{actor}/{collection}/{rkey}
```

Fetch a single record by its record key.

### Get lexicon

```
GET https://atproto.md/lexicon/{nsid}
```

Resolve a Lexicon schema by its NSID using AT Protocol DNS-based lexicon resolution: the
`_lexicon.{authority}` TXT record points at a DID, whose repo holds the schema at
`com.atproto.lexicon.schema/{nsid}`. Returns the schema's definitions and full JSON.
Works for any published lexicon — e.g. `/lexicon/app.bsky.feed.post`.

### Discover repos by collection

```
GET https://atproto.md/discover/{collection}[?limit=&cursor=]
```

Every repo (DID) on the network with records in the given collection NSID. Network-wide,
via the relay's `com.atproto.sync.listReposByCollection`. Use it to find all users of a
lexicon — e.g. `/discover/site.standard.document`. Cursor-paginated (limit default 100, max 2000).
Each result links straight into that repo's records for the collection.

### Backlinks

```
GET https://atproto.md/backlinks/{at-uri-or-did-or-url}[?source=&limit=&cursor=]
```

Records across the network that link to a target — likes, reposts, replies, follows, quotes,
or any custom lexicon. Without `source`, returns a summary table of every link source with
record + distinct-DID counts. With `source={collection:path}` (e.g. `app.bsky.feed.like:subject.uri`),
lists the actual linking records, cursor-paginated. Indexed by Constellation (microcosm.blue).

URLs accept `at://` URIs directly in the path:

```
https://atproto.md/at://{actor}                          → repo overview
https://atproto.md/at://{actor}/{collection}              → list records
https://atproto.md/at://{actor}/{collection}/{rkey}       → single record
```

## Parameter notes

- **{actor}** — a handle (`alice.bsky.social`, `bsky.app`, `aka.dad`) or DID (`did:plc:...`, `did:web:...`)
- **{collection}** — any AT Protocol collection NSID (e.g. `app.bsky.feed.post`, `site.standard.document`, `link.woosh.linkPage`)
- **{rkey}** — the record key (e.g. `self`, `3jui7kd54zh2y`)
- **limit** — integer 1–100, default 25
- **cursor** — opaque pagination token from a previous response
- **reverse** — `true` for oldest-first ordering

## Response format

All responses are plain Markdown text:

- Records include collection type, AT URI, and formatted content
- Known collections get rich formatting (posts with embeds, profiles with bios, publications with URLs, etc.)
- Unknown collections are rendered as generic key-value markdown — nothing is unreadable
- Paginated responses include a cursor for the next page
- Errors return markdown with status code and message

## Rich formatting for known collections

| Collection                                  | Notes                              |
| ------------------------------------------- | ---------------------------------- |
| `app.bsky.feed.post`                        | Text, embeds, reply context        |
| `app.bsky.actor.profile`                    | Bio, display name                  |
| `app.bsky.graph.follow/block/list/listitem` | Subjects, timestamps               |
| `app.bsky.feed.like/repost/generator`       | Subjects, timestamps               |
| `app.bsky.labeler.service`                  | Label policies                     |
| `site.standard.publication`                 | Name, URL, description             |
| `site.standard.document`                    | Title, content, published date     |
| `pub.leaflet.publication/document`          | Name, URL, content from pages      |
| `app.offprint.publication/document.article` | References to standard records     |
| `blog.pckt.publication`                     | Reference to standard record       |
| `link.woosh.linkPage`                       | Description, labeled link sections |
| `blue.linkat.entry`                         | Title, URL, description            |
| `events.smokesignal.calendar.event`         | Name, dates, location              |
| _Any other collection_                      | Generic key-value markdown         |

## Install as a Claude Code command

Save this skill sheet as a slash command (then invoke it with `/atproto`):

```bash
curl -s https://atproto.md/skill.md > ~/.claude/commands/atproto.md
```

## Full reference

https://atproto.md/llms.txt — structured API summary for LLM discovery
https://atproto.md/mcp — MCP server endpoint (install in Claude Code: `claude mcp add --transport http atproto-md https://atproto.md/mcp`)
https://atproto.md/ — interactive homepage
