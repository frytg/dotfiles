---
name: deps-auto
description: >-
  Apply dependency updates end to end without supervision: run the deps-check skill, drop every release that is
  younger than the repo's configured cooldown (minimumReleaseAge and equivalents), apply all patch and minor updates
  that keep the repo's `justfile` checks (typecheck, lint, format, test) green, inspect each major or breaking
  update against the repo's actual usage before applying it, and hold back anything that needs a human decision. By default it creates a branch, commits,
  pushes, and opens a pull request whose body is the update report. Safe to run from CI or a scheduled agent because
  it never prompts. Use when the user or an automation asks to "update dependencies", "apply dependency updates",
  "bump deps and open a PR", "auto-update deps", "deps auto", "run the weekly dependency update", or "do what
  Renovate would do". Not for a read-only report (use deps-check).
license: MIT
metadata:
  author: frytg
  agent: claude-code
  category: engineering
---

# Automated dependency updates

The output is **one pull request** that applies every eligible update that keeps the repo green, plus a body that says what was applied, what was held back, and why. An update is eligible when it is past the release cooldown. It is applied when the checks pass. A breaking update is applied only after its impact on this repo is inspected and the checks pass. Everything else goes in the report with a reason, not into the diff.

The run never prompts. When a decision belongs to a human, the update is held back and the decision goes in the pull request body. That keeps the skill usable from CI, scheduled agents, and cloud agents.

## When to use

- A scheduled or CI agent runs the weekly dependency update.
- The user asks to update dependencies and open a pull request.
- The user wants the safe part of a `deps-check` report applied.

## Not for

- A report without edits. Use `deps-check`.
- Deploying the result. Image and provider bumps change files only. Nothing is applied to a cluster, a host, or Terraform state.

## Invocation overrides

Defaults apply unless the request or the automation prompt says otherwise. Read the overrides once, at the start:

- **Delivery** — default `pr`: branch, commit, push, pull request. `push`: no pull request. `local`: branch and commits, no push. `apply`: edit the working tree, no commits. `dry-run`: run steps 1–4 and print the report, no edits.
- **Base branch** — default: the remote's default branch.
- **Cooldown** — default: the repo's configuration, resolved as in `deps-check` step 3.
- **Scope** — default: every ecosystem `deps-check` finds. An override can limit it (for example "only GitHub Actions" or "only npm").
- **Breaking updates** — default `inspect`: apply after inspection when safe. `skip`: report majors, apply none.

Invoking this skill with delivery `pr`, `push`, or `local` is the explicit request to create a branch and commits. With `pr` or `push` it is also the request to push. No further confirmation is needed.

## 1. Preflight

Stop and report on the first failure. Do not work around it.

1. The working tree is clean (`git status --porcelain` is empty). A dirty tree means someone else's work is in it.
2. Fetch the base branch and branch from its tip: `git fetch origin <base>`.
3. For delivery `pr` or `push`: git has an author identity (`git config user.name` and `user.email` are set). Never change git config. In CI the automation must provide the identity.
4. For delivery `pr`: the host CLI is authenticated. GitHub uses `gh auth status` (CI provides `GH_TOKEN`). GitLab uses `glab auth status`. For other hosts, see step 8.
5. For delivery `pr`: no open pull request from an earlier run exists:

   ```bash
   gh pr list --state open --json headRefName,url \
     --jq '.[] | select(.headRefName | startswith("deps-auto/")) | .url'
   ```

   If one exists, stop and report its URL. Do not stack a second one. Replace it only when the request says so: open the new pull request first, then close the old one with a comment that links the new one.

## 2. Baseline

Find the repo's checks as described in `deps-check` step 6: `just pre-push` if it exists, else `just typecheck`, `just lint`, `just format-check`, and `just test`, each one only if the recipe exists. Without a `justfile`, use the CI workflow's commands. Do not invent a command.

Run those checks on the untouched base, before any change. They are the checks for every later step.

If the baseline fails, stop and report the failing check. A failure that exists before the update cannot be told apart from one the update causes.

If the repo has no tests, continue, but apply only patch updates and treat every minor update like a major one (step 6). State that in the report.

## 3. Collect candidates

Load the `deps-check` skill and run its steps 1–6 with the scope from the overrides. Do not repeat its logic here. Its output gives, per dependency: current version, newest version past the cooldown, bucket (patch/minor or major), release notes for majors, and the cooldown in effect.

`deps-check` delegates container images to `k8s-images`, which asks for confirmation per bump. In this skill the rules below replace that confirmation. Use `k8s-images` for lookups only.

Drop:

- Releases still in cooldown. They go in the report with their eligible date.
- Versions with an unknown publish time.
- Floating, templated, and digest-pinned image tags. They go in the report as "pin manually".

## 4. Classify

Every remaining candidate gets exactly one class:

- **safe** — patch or minor of a `>=1.0` package, Actions and images within the pinned major, Terraform providers within the pinned major whose changelog lists no breaking change.
- **breaking** — a new major, a minor of a `0.x` package, or any release whose notes list a breaking change, a removed API, a default flip, or a raised runtime or peer minimum.
- **blocked** — needs a runtime bump the repo does not pin, conflicts with a peer range, or has a security advisory against the target version.

With delivery `dry-run`, print the report (step 9) now and stop.

## 5. Apply the safe updates

Create the branch: `deps-auto/<YYYY-MM-DD>`. If that name exists on the remote, add a suffix (`-2`).

Apply one ecosystem at a time, then verify, then commit:

1. Install each update at its **exact eligible version** with the package manager, so it cannot resolve a newer, younger release. Examples: `bun add <name>@<version>`, `npm install <name>@<version>`, `cargo update -p <name> --precise <version>`, `go get <module>@<version>`, `pip install <name>==<version>` plus the pin in the requirements file. Keep the dependency type (dev, peer, optional) and the specifier style already in the manifest (exact pin vs `^`).
2. Let the package manager write the lockfile. Never edit a lockfile by hand.
3. GitHub Actions: keep the pin style. A SHA pin gets the new tag's SHA (`git ls-remote https://github.com/<owner>/<repo> refs/tags/<tag>`) and the version in the trailing comment. A tag pin gets the new tag.
4. Terraform: change the `required_providers` pin, then `terraform init -backend=false -upgrade` and `terraform validate`. The flag keeps state and backends untouched. Never `plan` or `apply`.
5. Container images: change the tag in the manifest only.
6. Toolchain updates (tools the check recipes call, flagged by `deps-check`) go in their own commit after the other safe updates. A formatter bump that only reformats files is fine: run `just format` and commit the result with the bump. A linter or type checker bump that reports new findings is held back with the findings. Do not fix code or silence rules for it.
7. Run `just format` if the recipe exists, so the commit carries no format drift.
8. Run the baseline checks again.
   - Green: commit with `chore(deps): bump <ecosystem> patch and minor updates`. List each `name old → new` in the commit body.
   - Red: find the culprit. Revert the batch, then apply the updates one at a time with a check run after each. Commit the green ones, drop the red ones, and record each dropped update with the failing check and the first relevant error lines.

Never change a test, a lint rule, a type rule, or a CI check to make an update pass. A failure is a reason to drop the update.

## 6. Inspect and apply the breaking updates

Skip this step when the breaking-updates override is `skip`. Handle each breaking candidate on its own, in its own commit, so one can be reverted without touching the others:

1. **Read** the release notes and migration guide that `deps-check` linked. List every breaking item: removed or renamed exports, changed signatures, changed defaults, removed config keys or CLI flags, and raised runtime or peer minimums.
2. **Search the repo** for each item: imports and call sites, config files, CLI calls in recipes and CI, and type references. Compare raised runtime minimums with the pinned runtime (`mise.toml`, `.node-version`, `engines`).
3. **Decide**:
   - No item matches the repo: apply the bump.
   - Matches exist, and the migration guide gives a mechanical replacement that changes no behavior: apply the bump and the migration together.
   - The migration changes behavior, needs a product or design decision, touches code with no test coverage, or needs a runtime bump: hold it back as **blocked**.
4. **Verify** with the baseline checks. Green: commit with `chore(deps): bump <name> from <old> to <new>`, and put the breaking items and the files changed for them in the commit body. Red: revert completely and hold back with the failing check.

Record for every breaking candidate, applied or not: the breaking items, what the search found (file paths), what was changed, and the check result. This record is the evidence a reviewer needs. Without it, the pull request is not reviewable.

## 7. Push

Skip for delivery `local` and `apply`. If no commit was made, delete the local branch, print the report, and stop. An empty pull request is noise.

```bash
git push -u origin deps-auto/<YYYY-MM-DD>
```

Never push to the base branch. Never force-push.

## 8. Open the pull request

Skip for delivery `push`. Write the report (step 9) to a file in the scratchpad or `$RUNNER_TEMP`, then:

- GitHub: `gh pr create --base <base> --head deps-auto/<YYYY-MM-DD> --title "chore(deps): dependency updates <YYYY-MM-DD>" --body-file <file>`. Add the `dependencies` label only if it already exists in the repo.
- GitLab: `glab mr create` with the same title, description, and branches.
- tangled.org and other hosts: if no tool for creating pull requests is available, the pushed branch is the result. Report the branch name and the URL where a human opens the pull request.

Open as a draft when the repo has no tests or when any breaking update was applied. Otherwise open it ready for review. Never merge and never enable auto-merge unless the request says so.

## 9. Report

The report is the pull request body, and the final message of the run. Use this shape and leave out empty sections:

```markdown
Cooldown: <duration> (<source>). Base: <base> @ <short-sha>.

## Applied

- `<name>` <old> → <new> (<ecosystem>)

## Breaking, applied after inspection

### `<name>` <old> → <new>

- Breaking items: <short list> — [release notes](url)
- Repo usage: <files found, or "none">
- Changes made: <files and what changed, or "bump only">
- Checks: <recipes run> passed

## Held back

- `<name>` <old> → <new>: <reason: failing check + first error line, blocked decision, runtime bump, peer conflict>

## In cooldown

- `<name>` <new>: eligible <YYYY-MM-DD>

## Needs manual action

- <floating image tags to pin, registry errors, advisories, untested areas>

(created by <agent name>)
```

The last line names the agent that ran, for example `(created by Claude Code)`.

## Checklist

- [ ] Clean tree, fresh base, green baseline before any edit.
- [ ] Every applied version is past the cooldown and was installed at its exact version.
- [ ] Each ecosystem batch and each breaking update has its own commit, and each commit passed the checks.
- [ ] No test, lint rule, or CI check was changed to get green.
- [ ] Every held-back update has a reason in the report.
- [ ] Pushed to a `deps-auto/` branch, never to the base branch. No force-push, no merge.
