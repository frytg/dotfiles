---
name: create-issue
description: Turn a conversation, plan, or sketch into a GitHub issue — optionally sliced into tracer-bullet child issues with blocking edges. Use when the user asks to create an issue, open a ticket, write a PRD/spec to GitHub, break work into tickets, or uses create-issue / to-spec / to-tickets phrasing.
license: MIT
metadata:
  author: frytg
  agent: pi
  inspiration: mattpocock/skills to-spec + to-tickets
---

# Create issue

Synthesize what's already known into a **publishable GitHub issue**. Split into tracer-bullet children only when the work needs ordering or multiple independent slices. GitHub first. Draft → my OK → create.

- **Spec only** (default) — one issue when the work is one grab-able unit or I just want it tracked.
- **Spec + tickets** — parent plus children when I ask to break it down, or the work clearly needs multiple vertical slices.

## Principles

- **Synthesize, don't interview.** Only ask when a gap would produce a wrong issue (repo target, success criterion, seam that changes the body). Look up facts.
- **Domain language over file paths.** Glossary / `AGENTS.md` / `CONTEXT.md` terms when present; respect nearby ADRs. Paths and big code dumps go stale — exception: a trimmed decision-shaped prototype snippet (schema, type, state machine), marked as such.
- **Vertical slices.** End-to-end behaviour per ticket (not schema-then-API-then-UI). Demoable alone. Sized for one fresh agent context.
- **One artifact.** Prefer a single tight issue over a PRD plus tickets plus a side doc. Scale body length to the stakes.
- **Publish needs my OK.** Never open issues unprompted after freeform chat.
- **Don't touch unrelated issues** you weren't asked to close or rewrite.

## Process

### 1. Resolve target

Need `owner/repo`: argument/URL I gave → `git remote get-url origin` if it's github.com → ask once.

If I hand you an issue number/URL as source, fetch body + comments and build from that plus the conversation.

### 2. Explore just enough

If you don't already know the area, skim code, glossary, ADRs. Prefer existing **seams** over new ones — fewer is better; one high seam is ideal. Prefactors only when they truly unblock ("make the change easy, then make the easy change"), as their own early ticket. Skip the tour if the conversation already holds the decision record.

### 3. Seam check (light)

Before drafting, state in a few bullets: primary seam(s), any new seam (justify), prefactors or "none". One confirmation. Don't expand into peer-clarify unless I push back.

### 4. Draft the parent

Use the [default template](#default-issue-body). Depth matches the work: a one-line fix can be title + Done when; a multi-day feature may add Approach / Out of scope. **Drop empty sections** — never pad.

Lead with user-facing pain and a checkable done-state. Don't open with process metadata or a story ladder.

### 5. Tickets (only if splitting)

1. Draft vertical slices with **blocking edges** (none ⇒ can start now). Prefactors first.
2. Show a numbered plan only — title, blocked by, delivers — no API writes yet.
3. Confirm granularity, edges, merge/split. Iterate until I approve.

**Wide refactors** break pure vertical slicing when one mechanical change fans so wide no slice stays green. Sequence **expand → migrate batches → contract**:

1. Expand — new form beside old.
2. Migrate — batches by package/dir, each blocked by expand; old form keeps CI green.
3. Contract — delete old form once callers are gone; blocked by every migrate batch.

If batches still can't stay green alone, share an integration branch and block a final integrate-and-verify ticket — green only promised there.

### 6. Publish after approval

Explicit go only ("create it", "publish", "LGTM", etc.).

- **Parent** — GitHub issue create with draft title/body. Labels only if I named them or the repo already has a clear agent-ready label I didn't forbid — don't invent `ready-for-agent`. Type / milestone / assignees only when set or unambiguous.
- **Children** — create in dependency order (blockers first). Child template below. `Parent: #<n>` in body; sub-issue API when available. `Blocked by: #a, #b`. Return a compact index: number, title, URL, blocked-by.
- **Local fallback** — only when GitHub isn't the target. Write under `${TMPDIR:-/tmp}/issues-<slug>/` (`00-parent.md`, `01-…`) in dependency order. Same bodies. Tell me the path. Don't dump into the repo unasked.

### 7. Stop

Report URLs. Don't implement unless I ask.

## Default issue body

Short by default. Optional sections only when they change what the implementer does.

```markdown
## Problem

<user-perspective pain — one short paragraph>

## Done when

- [ ] <checkable outcome>
- [ ] <edge/failure that matters>

## Approach

- <load-bearing decisions already made — modules/interfaces in domain terms, not file paths>
- <seam under test>
```

Add only if needed:

```markdown
## Out of scope

- …

## Notes

- <deferred questions, prototype snippet>
```

**Title:** short, specific, outcome-shaped — not "misc" / "improvements."

**Don't default to user-story ladders.** If role×capability narration helps a product surface, fold 1–3 real paths into Problem or Done when instead of a separate performative list. Skip empty Implementation/Testing essay sections; Approach holds decisions + test seam when they matter.

## Child issue body

```markdown
## Parent

#<parent-number>

## What to build

<end-to-end behaviour this slice unlocks — user perspective>

## Done when

- [ ] …
- [ ] …

## Blocked by

- #<n> — <title>
- <!-- or: None — can start immediately -->
```

Local drafts may use ticket numbers/titles before GitHub numbers exist.

## Anti-patterns

- Interviewing when the conversation already decided the shape
- Horizontal tickets when a vertical slice would demo value
- Filing without approval
- Long templates with empty sections
- Giant code pastes or brittle file paths in bodies
- Inventing labels/process the repo doesn't use
- Editing/closing my other issues without a clear ask
- Starting implementation right after publish

## Triggers

- create issue / open a ticket / file this
- write a spec/PRD to GitHub
- break this into tickets / slice this / to-tickets / to-spec

## Example shape

Acme webhook worker needs age-capped retries and a dead-letter path.

**Seam:** existing `Delivery` interface; dead-letter as a second adapter on the same port.

**Parent title:** Age-capped webhook retries with dead-letter

**Done when:** events older than the cap stop retrying; exhausted events land in dead-letter; one partner end-to-end test covers both.

**If split:**

1. Expand retry policy + clock seam — blocked by none
2. Deliver → retry → dead-letter for one failing partner — blocked by 1
3. Ops signal (metric or log field) for dead-letter rate — blocked by 2

Publish only after I say go.
