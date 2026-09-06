---
name: k8s-images
description: Walks Kubernetes manifests in a project, uses `crane ls` to find the latest tag for each pinned container image, presents proposed bumps with file path + current/new tag + bump type, asks the user to confirm each one, then updates the YAML on approval. Use when the user asks to check, bump, update, or upgrade container image versions in k8s/ArgoCD/Helm-rendered manifests. Nothing is applied to a cluster — the user reviews the diff and deploys manually.
license: MIT
metadata:
  author: frytg
  agent: pi
---

# K8s Images

Walk every Kubernetes manifest in the project, look up the latest upstream tag for each pinned container image via [`crane`](https://github.com/google/go-containerregistry/tree/main/cmd/crane) `ls`, present proposed bumps, ask the user to confirm each one, then write the approved tags back into the YAML.

**Prerequisites:** `rg` (ripgrep), `yq` (mikefarah ≥ v4), `crane` (go-containerregistry). Run from the project root.

## Hard boundary: never deploy

This skill edits YAML files. **It does not run `kubectl apply`, `argocd app sync`, Helm upgrades, `nixos-rebuild`, `terraform apply`, or any command that mutates live clusters or hosts.** The user deploys manually after reviewing the diff. If the workflow seems to need a deploy, stop and surface the exact command + blast radius for explicit confirmation. Some host repos encode this as a formal deploy policy (e.g. an `AGENTS.md` rule); respect any local wording when running there.

## 1. Find manifests

A "manifest" is any YAML file in the project (outside `node_modules`, `.git`, `dist`, `vendor`, `target`, `helm-charts/.git`, etc.) whose `kind` is one of: `Deployment`, `StatefulSet`, `DaemonSet`, `Job`, `CronJob`, `Pod`. The file may contain multiple documents (`---`).

Use `rg` for content discovery, then `yq` for the kind check (multi-doc safe):

```bash
# Candidate files: any yaml/yml that contains "kind: <one of>" at line start
rg -l --type yaml -e '^kind: (Deployment|StatefulSet|DaemonSet|Job|CronJob|Pod)\b' .

# Confirm at least one document in the file has a matching kind
for f in $(rg -l --type yaml -e '^kind: (Deployment|StatefulSet|DaemonSet|Job|CronJob|Pod)\b' .); do
  kinds=$(yq -N 'select(.kind == "Deployment" or .kind == "StatefulSet" or .kind == "DaemonSet" or .kind == "Job" or .kind == "CronJob" or .kind == "Pod") | .kind' "$f")
  [ -n "$kinds" ] && echo "$f"
done
```

Skip vendored or generated content: drop paths under `node_modules/`, `vendor/`, `dist/`, `target/`, `.git/`, `helm-charts/`. A manifest file downloaded from a third party (e.g. an operator bundle) often has no fixed pin, so handle it like any other file — but treat templated images there the same way as everywhere else.

## 2. Extract images

For each matching file, walk every document and collect the container images. Use the path expression that fits the resource:

| Kind                                               | Path to container images                                                                                                 |
| -------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `Deployment` / `StatefulSet` / `DaemonSet` / `Pod` | `.spec.template.spec.containers[].image`, `.spec.template.spec.initContainers[].image`                                   |
| `Job`                                              | `.spec.template.spec.containers[].image`, `.spec.template.spec.initContainers[].image`                                   |
| `CronJob`                                          | `.spec.jobTemplate.spec.template.spec.containers[].image`, `.spec.jobTemplate.spec.template.spec.initContainers[].image` |

Emit one line per image, prefixed with the source location. The cleanest approach is one `yq` expression per resource shape:

```bash
# Deployment-style (incl. StatefulSet, DaemonSet, Job, Pod)
yq -N eval-all '
  select(.kind == "Deployment" or .kind == "StatefulSet" or .kind == "DaemonSet" or .kind == "Job" or .kind == "Pod")
  | [.kind, .metadata.name, (.spec.template.spec.containers // [] | .[].image)]
  | @tsv
' "$file"

# CronJob — one extra level of nesting
yq -N eval-all '
  select(.kind == "CronJob")
  | [.kind, .metadata.name, (.spec.jobTemplate.spec.template.spec.containers // [] | .[].image)]
  | @tsv
' "$file"

# initContainers — same expression with "initContainers" instead of "containers"
yq -N eval-all '
  select(.kind == "Deployment" or .kind == "StatefulSet" or .kind == "DaemonSet" or .kind == "Job" or .kind == "Pod")
  | [.kind, .metadata.name, (.spec.template.spec.initContainers // [] | .[].image)]
  | @tsv
' "$file"
```

Run all three against every manifest file, then deduplicate. For each image, capture: `file`, `kind`, `name`, `image`.

### Skip templated images

Mark an image as **templated** (skip the check) when its raw value matches any of:

- Helm/Jinja: contains `{{` (e.g. `{{ .Values.image }}`, `{{ .Chart.AppVersion }}`)
- Shell substitution: contains `${` or starts with `$` after the registry (e.g. `${IMAGE}`, `$IMAGE_TAG`)
- Kustomize `images:` directive: the raw `image:` field is left blank and rewritten by a `kustomization.yaml` entry. Detect by looking for an empty image string, or by a `kustomization.yaml` sibling with an `images:` block. Pragmatic check: if `yq '.spec.template.spec.containers[].image'` is empty/blank on a file, the image is likely Kustomize-managed — skip with a note rather than guessing.

To find templated values cheaply, filter the extracted images:

```bash
# Drop templated images
grep -vE '\{\{|\$\{|\$[A-Z_]'

# Drop images pinned to a digest (the check is tag-based)
grep -v '@sha256:'
```

### Skip floating tags

A tag is "floating" if it is `latest`, `main`, `master`, `dev`, `develop`, `edge`, `nightly`, `unstable`, `stable`, or matches `<prefix>-<date>` (e.g. `main-2023-10-23-...`, `sha-abc123...`). Floating tags are reported in a separate bucket ("unpinned, should be pinned") rather than checked for "latest" — there is no version to compare.

A pragmatic classifier:

```bash
is_floating() {
  case "$1" in
    latest|main|master|dev|develop|edge|nightly|unstable|stable|"") return 0 ;;
    sha-*) return 0 ;;
    *-20[0-9][0-9]-*) return 0 ;;   # dated tags
  esac
  return 1
}
```

### Normalise the registry

Bare names without a registry default to Docker Hub:

- `nginx` → `docker.io/library/nginx`
- `library/nginx` → `docker.io/library/nginx`
- `ghcr.io/owner/repo` stays as-is
- `quay.io/owner/repo` stays as-is
- `registry.example.com/foo` stays as-is

Use a small `awk`/shell normaliser, or have `yq` emit the value and resolve before calling `crane`.

## 3. Look up upstream tags

For each hardcoded, non-floating, non-digest image, call `crane ls` on the **repository** (not the full image) and parse out the latest version compatible with the pinned one.

```bash
crane ls docker.io/example-org/api-service
```

`crane ls` can be slow and verbose. Cap each call with a timeout (e.g. `timeout 30s crane ls …`) and treat failures as registry errors — surface them in the report, do not abort the run.

### Classify the pinned version

The bump you suggest depends on the **shape** of the pinned tag. Match by prefix:

| Pinned example                        | Prefix style                    | Default suggestion                                              |
| ------------------------------------- | ------------------------------- | --------------------------------------------------------------- |
| `v0.53.1`                             | `v` + semver                    | highest `vX.Y.Z` **within the same major** (skip `v1.0.0` etc.) |
| `0.4.5009`                            | semver, no `v`                  | highest `X.Y.Z` within the same major                           |
| `1.2.3-alpine`                        | semver + suffix                 | highest `X.Y.Z-<same suffix>` within the same major             |
| `4.2-alpine`                          | major.minor + suffix            | highest `X.Y-<same suffix>` within the same major               |
| `4.2`                                 | major.minor                     | highest `X.Y` within the same major                             |
| `2026.7.4` (calver)                   | `YYYY.MM.DD` or `YYYY.MM.patch` | highest matching format ≥ pinned                                |
| `2026-08-24-11-26-59--v0.1.0` (dated) | `<date>--<semver>`              | look behind the `--` for the inner semver and bump within major |
| `app-16`                              | name-version                    | highest `<name>-X` ≥ pinned                                     |

Heuristic: if the tag is a dotted numeric string with an optional leading `v` and an optional trailing `-suffix`, parse it as semver; if it's a `YYYY.MM...` string, parse it as calver; otherwise treat it as opaque and look for tags that share the longest common prefix with the pinned one.

For `0.x.y` projects the convention is to track the latest `0.x` series, not jump straight to `1.0.0`. If the highest `X` differs from the pinned one, list it as a **major** entry separately and let the user opt in.

### Suggest the latest

Implementation: pipe `crane ls <repo>` through `sort -V` and pick the highest entry that matches the prefix pattern and is `>=` the pinned one, **bounded by the pinned major**. Then optionally confirm with `crane manifest` to make sure the tag still exists and is pullable:

```bash
crane manifest <repo>:<suggested-tag>
```

Skip the `crane manifest` call when you have a long list of images — `crane ls` is enough to know the tag is published, and a missing manifest in a published registry is rare.

## 4. Report

Produce a tight, scannable report. Group entries by category. Don't trigger edits yet — the per-image confirmation in step 5 owns that.

### Out of date (hardcoded tag, newer upstream available)

One bullet per image. Include the file path, container name, pinned tag, latest tag, and a one-line note (e.g. "patch only", "new minor in same 0.x series", "major available — see release notes").

```
- clusters/cluster-a/apps/observability/deployment.yaml  [api-service]  v0.53.1 → v0.55.0  (new minor)
- clusters/cluster-c/apps/indexer/deployment.yaml        [indexer]       0.4.5009 → 0.4.5100  (patch)
```

### Major version available

Call out anything where the latest tag has a different major than the pinned one, and link to the upstream release notes. **Do not silently bump these** — breaking changes need review.

```
- clusters/cluster-a/apps/api-service/deployment.yaml  [api-service]  v1.4.2 → v2.0.0  (major)
  Release notes: https://github.com/<owner>/<api-service>/releases/tag/v2.0.0
```

### Floating tags (should be pinned)

```
- shared/services/collector/deployment.yaml    [collector]   tag: latest            (pin to a version)
- clusters/cluster-b/apps/notify/cronjobs.yaml [notify-cron] tag: nixery.dev/shell/curl  (rolling — pin a digest or specific build)
```

### Templated or digest-pinned (skipped)

One line per file with a templated image, so the user can see what was _not_ checked.

```
- shared/charts/api-service/values.yaml  [api-service]  image is templated ({{ .Values.image }}) — skipped
- clusters/cluster-c/apps/indexer/deployment.yaml  [indexer]  pinned to sha256:abc123… — skipped
```

### Registry errors

If `crane ls` failed (auth, network, rate limit, missing repo), report the image and the error. Don't silently drop it.

```
- clusters/cluster-a/apps/agent/deployment.yaml  [agent]  registry error: unauthorized
```

### Summary footer

```
Checked: 28 images across 22 files
Out of date: 11 (10 patch/minor, 1 major)
Floating: 2
Templated / digest-pinned: 15
Registry errors: 0
```

## 5. Confirm one at a time

For each out-of-date or major-available entry, present one bullet at a time and wait for a direct yes/no. **Never batch-confirm.** The prompt is a plain question that names the file, the line, the pinned tag, the proposed tag, and the bump type — the user should answer with the file path or image name to make the intent unambiguous:

```
Bump clusters/cluster-a/apps/observability/deployment.yaml  api-service: v0.53.1 → v0.55.0  (new minor, same 0.x)
  [y/n] _
```

On **yes**, queue the bump. On **no**, leave the file untouched and move on. On a major, require both `yes` and an acknowledgement that release notes were reviewed before queuing.

Choices per image:

- `y` — apply this bump in step 6
- `n` — leave it untouched
- `m` — show the full `crane ls` output for this repo so the user can inspect other tags before deciding
- `q` — stop the run entirely (apply what's queued so far, then exit)

Anything else is treated as `n`. Each image is its own prompt — when the same image appears in multiple files (e.g. one app pinned across several manifests), confirm each file separately; the user may want different versions per cluster.

## 6. Apply the confirmed bumps

For each queued bump, edit the YAML to replace **only the tag** in the existing `image:` line. Preserve everything else byte-for-byte: leading whitespace, surrounding comments (e.g. a `# Repo:` / `# Registry:` block), the rest of the manifest, document separators. The lines above and below the image line stay put.

Implementation rules:

1. Use the smallest unique `oldText` that includes the line with the old tag plus enough surrounding context (a couple of lines above and below) to be unique. Do not rewrite the file with `write`; do not pipe through `sed -i` if a tool-managed edit is available.
2. After every edit, re-grep the file to confirm the new tag is present and the old tag is gone. If both show up, the line was non-unique — pick more context and re-apply.
3. After each edit, re-parse the file with `yq` (or `ruby -ryaml`) to confirm it still parses. A bad edit that breaks YAML is the worst-case outcome; a parse check after every change catches it before the user sees a broken diff.
4. When the same image appears in multiple files, confirm each file separately (covered in step 5) and edit each one with file-scoped context.

### What the edit looks like

```diff
       - name: api-service
         # Repo: https://github.com/<owner>/api-service
         # Registry: https://ghcr.io/<owner>/api-service
-        image: ghcr.io/<owner>/api-service:v0.53.1
+        image: ghcr.io/<owner>/api-service:v0.55.0
```

That's the only line that should change.

## 7. Summary

After all edits, show:

- Count applied, skipped, declined.
- `git diff --stat` for the changed files (read-only, no commit).
- Any registry errors that surfaced so the user can retry later.
- A reminder that **nothing was applied to any cluster**. The diff is on disk; the user runs `kubectl apply`, `argocd app sync`, or the cluster's reconciler at their discretion.

```
Applied 7 bumps across 6 files:
  clusters/cluster-a/apps/observability/deployment.yaml  api-service v0.53.1 → v0.55.0
  clusters/cluster-b/apps/metrics/deployment.yaml       metrics     12.3.1   → 12.5.4
  …

Skipped (user declined): 2
Registry errors: 1  (clusters/cluster-a/apps/agent/deployment.yaml: timeout)

Diff summary:
  .../observability/deployment.yaml | 2 +-
  .../metrics/deployment.yaml       | 2 +-
  ...                               | 10 files changed, 10 insertions(+), 10 deletions(-)

Nothing was applied to any cluster. You decide when to deploy.
```

## Safety

- **Never deploy.** Edits stay in the working tree. No `kubectl apply`, `argocd app sync`, Helm upgrade, NixOS rebuild, Terraform apply, or sops re-encrypt. The deploy gate is a hard rule, not a default.
- **Confirm before editing.** One image at a time. Never apply a bump the user didn't explicitly approve.
- **Never bump across a major without a separate `yes` and acknowledgement of release notes.** Majors are surfaced, never silently applied.
- **Never propose `latest` as an upgrade target.** If the user is on a pinned tag and `latest` exists, mention that `latest` is ahead, but never recommend switching to it as a strategy — pinning is the goal.
- **Refuse to edit non-unique lines.** If two `image:` lines in a file have the same value, ask the user to disambiguate before editing — silently picking one is a corruption risk.
- **Re-parse after every edit.** A bad edit that breaks YAML is the worst-case outcome; `yq -e '.' "$file"` after each change catches it before the user sees a broken diff.
- **Don't bake credentials.** `crane` reuses the host's Docker config or ambient credentials. A failed lookup is a registry error, not a bug.
- **Don't fetch release notes in bulk.** Link them in the report; let the user check.

## Quick reference

```bash
# 1. Find manifests
rg -l --type yaml -e '^kind: (Deployment|StatefulSet|DaemonSet|Job|CronJob|Pod)\b' .

# 2. Extract images for a single file (Deployment)
yq -N eval-all '
  select(.kind == "Deployment" or .kind == "StatefulSet" or .kind == "DaemonSet" or .kind == "Job" or .kind == "Pod")
  | .spec.template.spec.containers[]?.image
' path/to/deployment.yaml

# 3. List tags for a repo
crane ls docker.io/example-org/api-service

# 4. Highest semver tag matching a prefix, ≥ pinned, within major
crane ls <repo> | grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1

# 5. Confirm a tag exists
crane manifest <repo>:<tag>

# 6. Verify the YAML still parses after edits
yq -e '.' path/to/deployment.yaml >/dev/null && echo OK
```
