---
name: k8s-images
description: Finds Kubernetes manifests (Deployment, StatefulSet, DaemonSet, Job, CronJob, Pod) in a project, extracts hardcoded container images, skips templated ones, and uses `crane` to check each image for newer upstream tags. Reports out-of-date images with the latest compatible version. Use when the user asks to check K8s image versions, audit container image freshness, find outdated images, or look for Kubernetes upgrade opportunities.
license: MIT
metadata:
  author: frytg
  agent: pi
---

# K8s Image Versions

Find Kubernetes manifests in the project, extract hardcoded container images, and check each one for newer upstream tags using [`crane`](https://github.com/google/go-containerregistry/tree/main/cmd/crane). Templated images (Helm `{{ }}`, shell `${VAR}`) and digest-pinned images are skipped.

**Prerequisites:** `rg` (ripgrep), `yq` (mikefarah ≥ v4), `crane` (go-containerregistry). Run from the project root.

## 1. Find manifests

A "manifest" is any YAML file in the project (outside `node_modules`, `.git`, `dist`, `vendor`, `target`, `helm-charts/.git`, etc.) whose `kind` is one of: `Deployment`, `StatefulSet`, `DaemonSet`, `Job`, `CronJob`, `Pod`. The file may contain multiple documents (`---`).

Use `rg` for content discovery, then `yq` for the kind check (multi-doc safe):

```bash
# Candidate files: any yaml/yml that contains "kind: <one of>" at line start
rg -l --type yaml -e '^kind: (Deployment|StatefulSet|DaemonSet|Job|CronJob|Pod)\b' .

# Confirm at least one document in the file has a matching kind
for f in $(rg -l --type yaml -e '^kind: (Deployment|StatefulSet|DaemonSet|Job|CronJob|Pod)\b' .); do
  kinds=$(yq -N 'select(.kind == "Deployment" or .kind == "StatefulSet" or .kind == "DaemonSet" or .kind == "Job" or .kind == "CronJob" or .kind == "Pod") | .kind' "$f")
  if [ -n "$kinds" ]; then echo "$f"; fi
done
```

Skip vendored or generated content: drop paths under `node_modules/`, `vendor/`, `dist/`, `target/`, `.git/`, `helm-charts/`. A manifest file downloaded from a third party (e.g. the Tailscale operator bundle) often has no fixed pin, so handle it like any other file — but treat templated images there the same way as everywhere else.

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
# List tags for a repo
crane ls docker.io/persesdev/perses
```

`crane ls` can be slow and verbose. Use timeouts and accept that a flaky registry yields a "registry error" line in the report rather than aborting the run.

### Classify the pinned version

The bump you suggest depends on the **shape** of the pinned tag. Match by prefix:

| Pinned example      | Prefix style                    | Suggest                                                                |
| ------------------- | ------------------------------- | ---------------------------------------------------------------------- |
| `v0.53.1`           | `v` + semver                    | highest `vX.Y.Z` where `X.Y.Z` ≥ pinned (project decides major policy) |
| `0.4.5009`          | semver, no `v`                  | highest `X.Y.Z` ≥ pinned                                               |
| `1.2.3-alpine`      | semver + suffix                 | highest `X.Y.Z-<suffix>` matching the pinned suffix                    |
| `4.2-alpine`        | major.minor + suffix            | highest `X.Y-<suffix>` ≥ pinned (treat as semver)                      |
| `4.2`               | major.minor                     | highest `X.Y` ≥ pinned                                                 |
| `2026.7.1` (calver) | `YYYY.MM.DD` or `YYYY.MM.patch` | highest matching format ≥ pinned                                       |
| `postgres-16`       | name-version                    | highest `<name>-X` ≥ pinned                                            |

Heuristic: if the tag is a dotted numeric string with an optional leading `v` and an optional trailing `-suffix`, parse it as semver; if it's a `YYYY.MM...` string, parse it as calver; otherwise treat it as opaque and look for tags that share the longest common prefix with the pinned one.

For `0.x.y` projects (the dominant pattern in this repo — Perses, Mastodon, PDS, etc.) the **convention is to track the latest `0.x` series**, not jump straight to `1.0.0`. Default to the highest tag within the same `X` (major version). If the highest `X` differs from the pinned one, list it as a **major** entry separately and let the user decide.

### Suggest the latest

Implementation: pipe `crane ls <repo>` through `sort -V` and pick the highest entry that matches the prefix pattern and is `>=` the pinned one. Then optionally confirm with `crane manifest` to make sure the tag still exists and is pullable:

```bash
crane manifest <repo>:<suggested-tag>
```

Skip the `crane manifest` call when you have a long list of images — `crane ls` is enough to know the tag is published, and a missing manifest in a published registry is rare.

## 4. Report

Produce a tight, scannable report. Group entries by category.

### Out of date (hardcoded tag, newer upstream available)

One bullet per image. Include the file path, container name, pinned tag, latest tag, and a one-line note (e.g. "patch only", "new minor in same 0.x series", "major available — see release notes").

```
- leno0/services/perses/deployment.yaml  [perses]  v0.53.1 → v0.55.0  (new minor)
- upc0/services/pds/pds-deployment.yaml  [pds]  0.4.5009 → 0.4.5100  (patch)
```

### Major version available

Call out anything where the latest tag has a different major than the pinned one, and link to the upstream release notes. **Do not silently bump these** — breaking changes need review.

```
- leno0/services/foo/deployment.yaml  [foo]  v1.4.2 → v2.0.0  (major)
  Release notes: https://github.com/<owner>/<foo>/releases/tag/v2.0.0
```

### Floating tags (should be pinned)

```
- common/services/vector/vector.yaml  [vector]  tag: latest  (pin to a version)
- locally0/services/dashy/cronjobs.yaml  [cronjobs]  tag: nixery.dev/shell/curl  (rolling image — pin a digest or specific build)
```

### Templated or digest-pinned (skipped)

One line per file with a templated image, so the user can see what was _not_ checked.

```
- common/services/foo/deployment.yaml  [foo]  image is templated ({{ .Values.image }}) — skipped
- upc0/services/bar/deployment.yaml  [bar]  pinned to sha256:abc123… — skipped
```

### Registry errors

If `crane ls` failed (auth, network, rate limit, missing repo), report the image and the error. Don't silently drop it.

```
- leno0/services/hermes-agent/deployment.yaml  [hermes-agent]  registry error: unauthorized
```

### Summary footer

```
Checked: 28 images across 22 files
Out of date: 11 (10 patch/minor, 1 major)
Floating: 2
Templated / digest-pinned: 15
Registry errors: 0
```

## 5. Safety and boundaries

- **Read-only.** This skill reports; it never edits manifests, runs `kubectl apply`, or calls `crane push`/`crane copy`.
- **Respect auth.** `crane` will reuse the host's Docker config or ambient credentials. Do not bake credentials into the skill. A failed lookup is a registry error, not a bug.
- **Do not recommend a major bump by default.** For `0.x` series and projects that follow semver strictly, surface the major as a separate "Major version available" entry so the user can opt in. For `1.x` and up, still surface majors separately.
- **Do not auto-suggest "latest".** If `latest` exists alongside pinned tags, mention that `latest` is ahead, but never recommend switching to it as a strategy — pinning is the goal.
- **No network calls beyond `crane`.** Don't fetch GitHub release notes in bulk — link them and let the user check.

## Quick reference

```bash
# 1. Find manifests
rg -l --type yaml -e '^kind: (Deployment|StatefulSet|DaemonSet|Job|CronJob|Pod)\b' .

# 2. Extract images for a single file (Deployment)
yq -N eval-all '
  select(.kind == "Deployment" or .kind == "StatefulSet" or .kind == "DaemonSet" or .kind == "Job" or .kind == "Pod")
  | .spec.template.spec.containers[]?.image
' services/foo/deployment.yaml

# 3. List tags for a repo
crane ls docker.io/persesdev/perses

# 4. Highest semver tag matching a prefix, ≥ pinned
crane ls <repo> | grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1

# 5. Confirm a tag exists
crane manifest <repo>:<tag>
```
