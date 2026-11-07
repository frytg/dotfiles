---
name: code-review
description: >-
  Review local code changes (working tree, staged, branch vs base, or a PR diff) for defects that change behavior and
  write one severity-ranked report. Builds a numbered diff file whose TOC is the coverage checklist, sends open questions
  to parallel read-only reviewer subagents when the calling harness documents a subagent tool, verifies every finding
  against the code before keeping it, and stores per-branch state in the repo's git-ignored `.local/code-review/` so
  later runs re-review only new commits. Closes with a merge-risk assessment from the `merge-risk` skill. Runs inside
  whatever harness invokes it, so it never posts to GitHub and never edits code. Use when the user asks to "review my
  changes", "code review this", "review this branch/diff/PR", "check before I push", "re-review",
  "/code-review", or wants a PR-style review done locally.
license: MIT
metadata:
  author: frytg
  agent: claude-code
  category: engineering
  inspirations:
    - pullfrog/pullfrog review and incremental-review modes
---

# Code review

The output is **one review report**. It has a verdict and a short list of verified defects. Each defect has a `path:line` anchor, a severity, and a concrete failure path. The report is not a summary of the diff and not a style pass. An empty findings list with a `clean` verdict is a valid result.

The review is read-only. It never edits, commits, or posts. It runs in the harness that invoked it and uses only that harness's tools.

## When to use

- The user asks for a review of uncommitted work, staged changes, a feature branch, or a PR diff.
- The user wants a check before pushing or opening a PR.
- The user asks for a re-review after new commits on a branch that was reviewed before.

## Not for

- Lint, formatting, or naming passes. Linters do that work.
- Whole-repo audits or architecture critique. Use `repo-architecture` for that.
- Applying fixes. Offer that after the report and do it only if the user says yes.

## Inputs

Parse the invocation text into these values. Anything left over is focus text, for example "focus on the migration".

- Target. Nothing means auto. Other values: `staged`, `worktree`, `<ref>` (review the branch against this base), `since <sha>`, or `#<n>` / `pr <n>` (a PR diff through `gh`).
- `--full` ignores stored state and reviews everything again.
- `--no-risk` skips the merge-risk step.

## Harness check

Run this check once, before step 1.

- **Shell and file read are required.** Without a shell tool, tell the user that the skill needs git and stop.
- **Subagents are optional.** Use them only when the current harness exposes a subagent or task tool and its usage is documented in context: a tool schema, system-prompt guidance, or a loaded skill that explains how to spawn one. Stay inside the same harness. Never launch a different agent CLI from the shell. If you are unsure, don't use subagents.
- **Pick the most restricted read-only subagent type** the harness offers (a read-only agent type, or a tool allowlist without edit or write).
- **Model choice.** If the harness lets you pick a subagent model and nothing forbids it, use one tier smaller from the same provider. Otherwise inherit the model. Don't change reasoning effort unless the user asked for it.
- **Task list.** If the harness has a todo or task-list tool, use it for coverage in step 4. Otherwise track coverage in your working notes.

## Workflow

### 1. Collect instructions

Read these sources. The first one wins when they conflict.

1. The user's invocation text.
2. Repo review instructions: `REVIEW.md` or `.github/REVIEW.md` at the repo root, or a section titled "Review" or "Code review" in `AGENTS.md` / `CLAUDE.md`.
3. The defaults in this skill.

General conventions in `AGENTS.md` (style, naming, tooling) tell you what the code should look like. They are not a request to flag style. Only explicit review instructions widen or narrow the review scope.

### 2. Prepare the diff

Run the bundled script. Its path is relative to this `SKILL.md`:

```bash
bash <skill-dir>/scripts/prepare-diff.sh [--staged | --worktree | --base <ref> | --from <sha> | --pr <n>]
```

Map the target: auto → no flag. `staged` → `--staged`. `worktree` → `--worktree`. `<ref>` → `--base <ref>`. `since <sha>` → `--from <sha>`. PR → `--pr <n>`.

With no flag, the script reviews a dirty tree against `HEAD`. On a clean feature branch it reviews against the merge-base with the default branch. On a clean default branch it reviews the last commit.

The script prints `key=value` lines. Keep `root`, `state_dir`, `diff`, `mode`, `label`, `base`, `head`, `files`, and `gitignore`.

State lives in `<root>/.local/code-review/<branch>/`. The script leaves `.local` out of working-tree and staged diffs. If nothing in the repo ignores `.local` yet, the script appends `.local/` to the repo's `.gitignore` and prints `gitignore=added`. In that case, say so in the report's closing line so the user can commit it. Until it is committed, the `.gitignore` change shows up as a dirty tree in auto mode.

- Exit `3`: nothing to review. Tell the user which target was empty and stop.
- Exit `2`: tell the user the error message and stop. Don't guess a different target.

The diff file has a header, a `## Files (N)` TOC with line ranges, and one section per file. Each code line shows `OLD NEW MARK CODE`, so you can read anchors directly without counting hunk offsets.

### 3. Load prior state

Read `<state_dir>/state.json` if it exists (schema below). Then pick a review type:

- **Full.** Use it when there is no state, when `--full` is set, or when `mode` is `worktree`, `staged`, or `pr`. If prior state exists, keep its open findings for re-checking in step 7.
- **Incremental.** Use it when `state.head` is a commit, `git merge-base --is-ancestor <state.head> HEAD` succeeds, and `mode` is `base` or `from`. Run the script again with `--from <state.head> --name incremental`. Read the incremental file first, then the full diff for context.
- **Rewritten history.** If `state.head` is not an ancestor, the branch was rebased or force-pushed. Do a full review. Run `git range-diff <state.base>..<state.head> <base>..HEAD` and read it, so you can tell new work from replayed commits.

### 4. Read the whole diff

Make one coverage item per TOC entry. Read each line range and mark the item done. Read large sections in chunks.

You may skim generated files, lockfiles, vendored code, and snapshots. List them as skimmed in the report. Never skip a range without listing it.

### 5. Triage and gather context

Write down, for yourself:

- What the change does, in one or two sentences.
- The seams it touches: public APIs, schemas, persistence, config, auth, money, concurrency, error and retry paths, user-facing output.
- The contracts that callers depend on.

Then read beyond the diff: callers of changed functions, callees whose assumptions changed, types, related tests, and config. You are the synthesizer. Subagents answer narrow questions, but understanding the change stays with you.

**Fast path.** If the change has no behavioral surface, skip step 6. Examples: prose-only docs, comments, formatting, generated output, or a lockfile bump with no code change. Diff size never decides this. A one-line change to an auth check, a comparison operator, a SQL query, or a retry loop gets the full pass.

### 6. Ask the open questions

List the questions you can't answer with confidence and whose answer would add, remove, or re-rank a finding. Make each one falsifiable:

- Good: "Can `parseLimit` return 0 when the header is missing, and does `paginate` then divide by it?"
- Bad: "Is the pagination code correct?"

Zero questions is fine. There is no fixed cap, but never ask filler questions such as "review this file".

**With subagents.** Send one question per reviewer. Use the brief in [references/reviewer-brief.md](references/reviewer-brief.md). Send all briefs in the same turn so they run in parallel. Each brief has the diff path verbatim, one question, a short lens label, and one starting `path:line`. Don't include your summary, your expected answer, or the other questions.

**Without subagents.** Work each question yourself, one at a time, with the same rules. Write down an answer (yes, no, or unclear) and evidence before you move on.

### 7. Aggregate and verify

Merge the reviewer answers with your own candidates. Group them by root cause, so one cause gives one finding.

For every candidate, open the code at the anchor and trace the failure path yourself. Check that the anchor line exists in the diff: NEW column for added or context lines, OLD for removed lines. Then drop:

- Praise, summaries, "looks good".
- Style, naming, formatting, and taste, unless the instructions ask for them.
- Missing tests, comments, or docs, unless the instructions ask for them.
- Speculation: no concrete input or state that triggers the problem.
- Pre-existing problems. Keep one only when the diff introduces it, makes it worse, or makes it reachable.
- Fixes heavier than the risk: new abstractions, layers of defensive checks, or rewrites for a case that can't happen.
- Reviewer claims that you can't reproduce by reading the code.

**Incremental reviews.** Keep new findings only on lines that changed since `state.head`. Re-check every open prior finding. Match it by `path` and `fingerprint`, not by line number, because lines move. Mark it `resolved` (the code at the anchor now handles the case), `open` (still present), or `obsolete` (the code is gone). If you are not sure, leave it `open`.

### 8. Rank

- `blocker`: merging breaks something real. Examples: data loss or corruption, a security hole, a crash or wrong result on a main path, a broken contract for existing callers, a migration that can't be reversed.
- `fix`: a real defect with narrower reach. Examples: a wrong result on an edge case, a swallowed error, a resource leak, a race under realistic load.
- `minor`: a small correctness problem with low impact. Never a nit.

The verdict is the highest tier present, or `clean` when nothing survived.

### 9. Assess merge risk

Skip this step when `--no-risk` is set.

Load the `merge-risk` skill in this order:

1. If the harness lists a `merge-risk` skill, invoke it through the harness's skill mechanism.
2. Otherwise, if `../merge-risk/SKILL.md` exists next to this skill's directory, read it and follow it.
3. Otherwise, skip the section and add "merge-risk skill not available" to the scope line.

Give it the context you already have. Don't re-read the diff for it.

- **Alignment:** the PR title, body, and linked issue (`gh pr view <n>` in `pr` mode). Otherwise use the commit messages (`git log --format=%s%n%b <base>..HEAD`) and the branch name. For `worktree` and `staged`, use the user's focus text if there is any.
- **Impact:** the seams from step 5 and the sensitive areas the diff touches.
- **Verification:** tests added or changed in the diff, and screenshots or profiling the PR body mentions.
- **Rollback cost:** migrations, data rewrites, deletions, renamed public contracts, and dependency bumps.
- **Error detection:** findings about swallowed errors or silent fallbacks, plus logging and alerting changes in the diff.

Merge risk is a separate judgment. It doesn't change the defect verdict, and its gaps are not findings. A gap that is a real defect must already be a verified finding from step 7. Never add one here.

### 10. Write the report and state

Print the report in chat and save the same text to `<state_dir>/review.md`. Then write `<state_dir>/state.json`. Never write state outside `<root>/.local/code-review/`.

### 11. Stop

Don't edit code. The only write outside the state dir is the script's one-time `.gitignore` line. End with one line that offers the next step: fix the findings, or post them to the PR with `gh`. Post only when the user explicitly asks.

## Report format

Each finding is 2-3 sentences: what breaks, which input or state triggers it, and the consequence. Add one `Fix:` line with the direction, not a patch. Order findings by severity, then by path.

```markdown
## Review: <label>

**Verdict:** <blocker | fix | minor | clean>. <One sentence on why.>
**Scope:** <N> files, <base short sha>..<head short sha or WORKTREE>, <full | incremental since <sha>>. Skimmed: <paths | none>.

### Findings

1. **[blocker]** `src/billing/charge.ts:88` <title, 10 words or fewer>
   <What breaks, under which input or state, and the consequence.>
   Fix: <direction in one line>.

### Merge risk

<merge-risk skill output, verbatim in its own format.>

### Prior findings

- F2 `src/api/limit.ts:40` resolved: <what changed>.
- F3 `src/api/limit.ts:71` still open.

### Open questions

- <A question you couldn't settle that the author should answer, with its `path:line`.>
```

Leave out sections with no content. A `clean` review is the verdict line, the scope line, and the merge-risk section. "Prior findings" appears only when state existed.

## State file

`<state_dir>/state.json` holds one object per branch. Rewrite the whole file after each review.

```json
{
	"branch": "feature/acme-limits",
	"mode": "base",
	"base": "<full sha>",
	"head": "<full sha, or WORKTREE / INDEX>",
	"reviewedAt": "2030-01-01T12:00:00Z",
	"verdict": "fix",
	"mergeRisk": "medium",
	"nextId": 4,
	"findings": [
		{
			"id": "F3",
			"severity": "fix",
			"path": "src/api/limit.ts",
			"line": 71,
			"title": "Zero limit divides by zero in paginate",
			"fingerprint": "const pages = Math.ceil(total / limit)",
			"status": "open"
		}
	]
}
```

- `mergeRisk` is `low`, `medium`, `high`, or `null` when step 9 was skipped.
- `id` comes from `nextId` and never gets reused across runs.
- `fingerprint` is the trimmed source text of the anchor line.
- Keep `resolved` and `obsolete` findings for one more run, then drop them.

## Checklist

- Every TOC range is read or listed as skimmed.
- Every finding was traced by you, sits on a diff line, and has one root cause.
- No style, test-coverage, or pre-existing items unless the instructions asked for them.
- Merge risk came from the `merge-risk` skill, or the report says why it is missing. It added no unverified findings.
- One report in chat, `review.md` and `state.json` in `.local/code-review/<branch>/`, no code edits.
- If the script printed `gitignore=added`, the user was told.
