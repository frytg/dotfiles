---
name: eventhub-deploy
description: Bumps the Eventhub ingest Docker tag (optional dev, test, prod). Use when deploying or updating that image. Confirms before the staging merge request, then again before staging into main.
license: MIT
metadata:
  author: frytg
  agent: pi
  category: ard
---

# Eventhub deploy

Bump `eventhub-ingest` image tags in this repo, then open GitLab merge requests only after the user confirms each one. The user may say "pull request"; on this host the artifact is a merge request. Do not write the Git remote host, project path, or image registry into this skill, commit messages, or merge request text.

The invoking message is not a yes. "Deploy tag X" authorizes the branch and the YAML edit. It does not authorize the commit, the push, or either merge request.

## Repo and files

Run only in a checkout that contains the three tag files below. If it does not, stop.

Read `image.repository` from `releases/eventhub-ingest/values.yaml.gotmpl`. Do not change it, and do not copy it into commit messages or merge request text.

Tag files, one `image.tag` each:

- `dev` → `releases/eventhub-ingest/values.dev.yaml.gotmpl`
- `test` → `releases/eventhub-ingest/values.test.yaml.gotmpl`
- `prod` → `releases/eventhub-ingest/values.prod.yaml.gotmpl`

Edit only the `tag:` line. Leave quotes, indent, and every other line alone.

## Inputs

- **Tag** (required). A Docker tag such as `3.0.0-beta.2-g938`. Accept a full image reference only when the repository portion matches `image.repository` in the values file; then use the substring after the last `:`. Reject whitespace, digests (`@sha256:`), and any other registry path.
- **Environments** (optional). A subset of `dev`, `test`, `prod`. Default is all three. `staging` is a branch, not an environment. If the user says stage or staging as an environment, stop and ask which of dev, test, and prod they mean.

## What merging does

Opening a merge request does not deploy. Merging does, via GitLab CI (`helmfile sync`):

- Merge into `staging` deploys **dev**.
- Merge of `staging` into `main` deploys **test** and **prod**.

`main` only accepts merge requests whose source branch is `staging`, `HOTFIX-*`, or `cherry-pick-*`. Promote through `staging`. Do not push to `staging` or `main`, and do not merge either request, unless the user explicitly asks in a later message.

Do not run `helmfile apply`, `helmfile sync`, or `kubectl`.

## 1. Prepare the branch

Stop if `git status --porcelain` is non-empty. Do not stash.

```bash
git fetch origin staging main
```

Read the selected tag files on `origin/staging` (not the previously checked-out branch). If every selected file already has the requested tag, stop and say so. Do not create a branch.

Otherwise:

```bash
git checkout -b "eventhub-ingest/<tag>" origin/staging
```

If that ref already exists locally or on `origin`, stop and report it. Do not reuse it.

## 2. Update the tag

On the new branch, set `tag: "<tag>"` in each selected file whose current tag differs. Skip files that already match, and say which ones.

Then show `git diff`. The diff must contain only `tag:` lines in the selected values files. If anything else changed, stop.

## 3. Ask before the staging merge request

Ask one question, then wait:

> Commit these tag changes and open a merge request into `staging`?

- **Yes** — commit and open the merge request.
- **No** — leave the branch with the uncommitted edit.

Do not also ask about `main` in this step. If the answer is no, stop. Do not push.

## 4. Commit and open the staging merge request

Stage only the values files that changed.

Commit subject, matching earlier eventhub bumps:

- All three environments: `update eventhub-ingest to <tag>`
- A subset: `update eventhub-ingest to <tag> (dev, test)` — list only the environments whose files changed, in the order dev, test, prod.

If an open merge request from this branch into `staging` already exists, push any missing commits without `merge_request.create` and report that URL.

Otherwise push the new branch and open the merge request with target `staging`:

```bash
git push -u origin HEAD \
  -o merge_request.create \
  -o merge_request.target=staging \
  -o merge_request.title="<commit subject>" \
  -o merge_request.description="$(cat <<EOF
Set eventhub-ingest image tag to \`<tag>\` for <envs>.

<file>: \`<old>\` → \`<tag>\`

Merging into staging deploys dev. This merge request does not deploy by itself.

(created by <agent>)
EOF
)"
```

Use the agent name for this session (`Cursor`, `pi`, …). Read the merge request URL from the push output. If the push succeeds and no URL appears, look it up with `glab mr list` when `glab` is on PATH. If `glab` is not available, tell the user and stop. Do not call the API.

## 5. Ask before promoting staging to main

Fetch again, then list what a `staging` → `main` merge request would contain:

```bash
git fetch origin staging main
git log --oneline origin/main..origin/staging
```

When `glab` is on PATH, list open merge requests from `staging` to `main`. If one exists, give its URL and stop. Do not ask, and do not open another. If `glab` is not available, skip this check.

Otherwise ask one question, then wait:

> Open a merge request from `staging` into `main`?

State these facts in the same message:

- The request promotes every commit on `origin/staging` that is missing from `origin/main`. Paste the `git log` above.
- This tag bump stays on the feature branch until the merge request into `staging` is merged. After that merge, an open `staging` → `main` request includes the bump.
- Merging `staging` into `main` deploys **test** and **prod**. Opening the request does not.

- **Yes** — open the merge request.
- **No** — stop. Leave the staging merge request as it is.

## 6. Open the main merge request

Do not push `staging`. Do not call the API.

If `glab` is not on PATH, or it is not authenticated for the host in `origin`, stop and tell the user the merge request was not opened.

Otherwise:

```bash
glab mr create \
  --source-branch staging \
  --target-branch main \
  --title "Merge staging into main" \
  --description "$(cat <<EOF
Promote staging to main.

Merging deploys test and prod. Opening this merge request does not deploy.

(created by <agent>)
EOF
)" \
  --yes
```

Return both merge request URLs when they exist. Do not merge them.
