---
name: tangled
description: Retrieve content from tangled.org, a federated git platform built on AT Protocol. Use when the user shares a tangled.org URL or asks to fetch/read/inspect content from any Tangled knot. All repos are public — files come over plain HTTP at /raw/{ref}/{path}; issues, PRs, comments, and repo metadata live as AT Protocol records on the owner's PDS (fetch via atproto.md or direct XRPC).
license: MIT
metadata:
  author: frytg
  agent: pi
---

# Tangled

[Tangled](https://tangled.org) is a federated git hosting platform built on AT Protocol. The HTML front-end is a regular web app; the actual git data is served by knots (`tangled.sh` and self-hosted); social artifacts (repos, issues, PRs, comments, labels) live as records in the owner's PDS. **All repos are public** — every read endpoint is unauthenticated.

This skill covers the read paths. Use it whenever the user shares a `tangled.org` URL or asks to fetch something from Tangled.

## URL anatomy

Every URL on tangled.org follows the same shape: `https://tangled.org/{owner}/{repo}/...`. `{owner}` is a handle (e.g. `frytg.digital`) or a DID (`did:plc:...`).

| Page kind          | URL pattern                            | Returns        |
| ------------------ | -------------------------------------- | -------------- |
| Repo landing       | `/{owner}/{repo}`                      | HTML           |
| Directory          | `/{owner}/{repo}/tree/{ref}/{path...}` | HTML           |
| File view          | `/{owner}/{repo}/blob/{ref}/{path...}` | HTML           |
| **Raw file**       | `/{owner}/{repo}/raw/{ref}/{path...}`  | **plain text** |
| Branches list      | `/{owner}/{repo}/branches`             | HTML           |
| Pull requests list | `/{owner}/{repo}/pulls`                | HTML           |
| Issue list         | `/{owner}/{repo}/issues`               | HTML           |
| Single issue       | `/{owner}/{repo}/issues/{n}`           | HTML           |
| Commits            | `/{owner}/{repo}/commits/{ref}`        | HTML           |

`{ref}` is a branch name, tag, or full SHA. `{path...}` can be empty (`/raw/main/`) for the root, or deep (`/raw/main/src/utils/date.ts`). Drop the trailing path for the ref root listing.

The blob page also exposes line anchors: `/{owner}/{repo}/blob/{ref}/{path}#L{line}` (and `L{line}-L{line}` for ranges). Tangled's HTML viewer, not the raw endpoint, is what honours them.

## Reading files

Raw file content is served directly — no auth, no rate-limit surprises:

```bash
# Plain text
curl -sL "https://tangled.org/frytg.digital/dotfiles/raw/main/BACKUPS.md"

# Binary file (e.g. an image)
curl -sL "https://tangled.org/frytg.digital/dotfiles/raw/main/.sshconfig" -o .sshconfig
```

For a directory listing or a file preview, fetch the HTML page and parse it (Tangled's pages emit useful `<meta>` tags — `og:url`, `og:image`, `vcs:clone`, plus a `description` set from the repo's AT Protocol record). The HTML is heavy, though; reach for raw whenever you don't need rendered chrome.

## Git clone (when you want the whole repo)

The clone URL appears on every repo page in two equivalent forms — one based on the handle, one on the DID:

```bash
git clone git@tangled.org:frytg.digital/dotfiles.git
git clone git@tangled.org:did:plc:jttpxcpdum6st5hh6dwf6f72.git
```

Self-hosted knots use a different host (`tangled.sh`, a custom domain, etc.) but the URL shape is the same: `git@<host>:<handle-or-did>/<repo>.git`. The repo page's clone dropdown shows the right host.

## Reading issues, PRs, and metadata

Issues, pull requests, comments, labels, and repo metadata are **not** in git. They're AT Protocol records on the owner's PDS. The `tangled.org/{owner}/{repo}/issues/{n}` page renders them in a browser, but the canonical data lives elsewhere.

The easiest path: `atproto.md` (https://atproto.md) returns any PDS record as clean Markdown. Use it first; fall back to direct XRPC when `atproto.md` isn't reachable.

### Preferred: atproto.md

```bash
# All issues for a user's repo
curl "https://atproto.md/at://frytg.digital/sh.tangled.repo.issue?limit=50"

# Single issue by record key
curl "https://atproto.md/at://frytg.digital/sh.tangled.repo.issue/3mqem7cuyz222"

# Repo metadata (knot, spindle, topics, description, labels)
curl "https://atproto.md/at://frytg.digital/sh.tangled.repo/dotfiles"

# All pull requests
curl "https://atproto.md/at://frytg.digital/sh.tangled.repo.pull?limit=50"

# Comments
curl "https://atproto.md/at://frytg.digital/sh.tangled.feed.comment?limit=50"

# Resolve a handle to its DID and PDS
curl "https://atproto.md/resolve/frytg.digital"
```

Issue records reference the **knot repo**, not the user's PDS, via the `repo` field — that's a DID pointing to the actual git storage. The issue number `n` in the tangled.org URL is **not** the same as the record key; mapping between them requires listing the collection and matching by `createdAt` (the URLs number issues by creation order).

### Fallback: direct XRPC against the PDS

If `atproto.md` is unreachable, do it yourself. Issues live in the `sh.tangled.repo.issue` collection on the **owner's PDS**, filtered client-side by the `repo` field (which points to the knot's repo DID).

```bash
# 1. Resolve handle to DID
DID=$(curl -s "https://tngl.sh/xrpc/com.atproto.identity.resolveHandle?handle=frytg.digital" \
  | jq -r '.did')

# 2. Resolve DID to PDS endpoint
PDS=$(curl -s "https://plc.directory/$DID" \
  | jq -r '.service[] | select(.id == "#atproto_pds") | .serviceEndpoint')

# 3. Find the repo's sh.tangled.repo record to get its rkey + the knot's repoDid
REPO_RKEY=$(curl -s "$PDS/xrpc/com.atproto.repo.listRecords?repo=$DID&collection=sh.tangled.repo" \
  | jq -r '.records[] | select(.value.name == "myrepo") | .uri')
REPO_DID=$(curl -s "$PDS/xrpc/com.atproto.repo.listRecords?repo=$DID&collection=sh.tangled.repo" \
  | jq -r '.records[] | select(.value.name == "myrepo") | .value.repoDid')

# 4. List issues for that repo (filter client-side by repoDid)
curl -s "$PDS/xrpc/com.atproto.repo.listRecords?repo=$DID&collection=sh.tangled.repo.issue&limit=100" \
  | jq --arg repo "$REPO_DID" \
      '.records[] | select(.value.repo == $repo) | {uri: .uri, title: .value.title, body: .value.body, createdAt: .value.createdAt}'

# 5. Fetch a single record
curl -s "$PDS/xrpc/com.atproto.repo.getRecord?repo=$DID&collection=sh.tangled.repo.issue&rkey=3mqem7cuyz222"
```

Pagination uses opaque `cursor` from the previous response. Pass it as `&cursor=<cursor>` and stop when the field is absent or empty.

## Relevant AT Protocol collections

| Collection                     | What it stores                                       |
| ------------------------------ | ---------------------------------------------------- |
| `sh.tangled.repo`              | Repo metadata (knot, spindle, topics, description)   |
| `sh.tangled.repo.issue`        | Issues (title, body, labels, repo reference)         |
| `sh.tangled.repo.pull`         | Pull requests (source/target refs, comments)         |
| `sh.tangled.repo.collaborator` | Repo collaborators                                   |
| `sh.tangled.feed.comment`      | Comments on any Tangled record                       |
| `sh.tangled.label.definition`  | Label definitions (assignee, good-first-issue, etc.) |

Browse the full set of Tangled lexicons: `https://atproto.md/discover/sh.tangled.repo` (replace the collection NSID for any other).

## Common workflows

**Get a file from a tangled URL the user pastes:**

1. Parse `tangled.org/{owner}/{repo}/{kind}/{ref}/{path...}` from the URL.
2. If `kind` is `raw`, fetch it directly. If `blob`, rewrite to `raw` and fetch.

**Get an issue from a tangled URL the user pastes (`/issues/6`):**

1. Parse the owner and repo. Resolve to a DID via `https://tngl.sh/xrpc/com.atproto.identity.resolveHandle?handle={owner}` (or use `atproto.md/resolve/{owner}`).
2. Fetch `https://atproto.md/at://{owner}/sh.tangled.repo.issue?limit=100`.
3. The URL's `6` is the **issue number** (creation order), not the record key. Find the nth record by `createdAt` ascending. Or skip the number and return all issues.

**Clone a repo and inspect a path:**

1. `git clone git@tangled.org:{owner}/{repo}.git` (handle form; use the DID form if the user is on a custom PDS where the handle may not resolve cleanly).
2. Read the file from the working copy — much faster than fetching the raw URL one file at a time.

## Safety

- Tangled is read-public for repos, but **repos may still be deleted or moved** by their owner at any time. Don't cache raw content as if it were permanent; re-fetch when the user needs the latest.
- Issue and PR records live on the owner's personal PDS. If the owner migrates PDS or deletes their account, the tangled.org URL may 404 even though the knot still has the git data. `atproto.md/plc/audit/{owner}` traces migrations.
- Self-hosted knots may serve content from a different origin. Don't hardcode `tangled.org` for clone URLs — read the host from the repo page's clone dropdown.
- The HTML viewer runs JavaScript; `curl` only gets the SSR shell. For rendered views (syntax highlighting, diff rendering), use a real browser or fall back to the raw file.
