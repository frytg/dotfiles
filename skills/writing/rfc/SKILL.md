---
name: rfc
description: "Create RFC documents anywhere on disk. Asks clarifying questions one at a time, then writes a YYYY-MM-DD-topic.md file in BLUF + bullet-point style. Resolves the output directory from the user's explicit path, the working directory's rfc/ or docs/rfc/ folder, or asks if neither exists."
license: MIT
metadata:
  author: Dan
  inspirations:
    - skills.sh/rfc-generator
    - anthropics/skills/doc-coauthoring
    - anthropics/skills/technical-writing
    - ralpinhino-rfc-pipeline
---

# RFC Document Authoring

Create an RFC (Request for Comments) for a project, feature, architectural decision, or process change. Output is plain Markdown with YAML frontmatter — readable in any editor, on any platform, no vault required.

## When to Use

Trigger when the user says:

- "Write an RFC for…" / "Create a design doc for…" / "Write up a proposal for…"
- "I need an RFC on…" / "Document the plan for…"
- "PRD", "spec", "decision doc"

Also use when you identify a decision that warrants a written record before execution.

## Output Location

Resolve the target directory before writing. Try in order:

1. **User-provided path** — the user named a directory or file; honour it verbatim.
2. **`rfc/` in cwd** — if `./rfc/` exists relative to the working directory, use it.
3. **`docs/rfc/` in cwd** — if `./docs/rfc/` exists, use it.
4. **Ask** — if none match, ask the user where to save. Suggest `./rfc/` as a default and create it.

Date is **today** in ISO 8601 (`YYYY-MM-DD`), unless the user overrides. The slug is lowercase, hyphenated, derived from the topic.

Final file path: `<resolved-dir>/<YYYY-MM-DD>-<slug>.md`. Create the directory if missing.

## Structure

### Frontmatter

```markdown
---
title: '[RFC] Topic Title'
status: Draft # Draft → In Review → Accepted → Rejected → Implemented
date: YYYY-MM-DD
author: Dan
reviewers: # populated later (optional)
tags: [rfc, topic-tag]
target-date: # optional deadline
---
```

### 1. BLUF (Bottom Line Up Front)

**Bold** one-liner stating the recommendation. Someone should know the point before reading further.

### 2. Context

What prompted this? Current situation, background, problem space. 2-4 bullets.

### 3. Problem Statement

The specific pain point or gap — not the solution.

### 4. Proposal

The recommended approach. Bullets, not paragraphs:

- **What** — what's being proposed
- **How** — high-level approach (include a Mermaid diagram if the flow is non-trivial)
- **Scope** — what's in, what's out (YAGNI)
- **Audience** — who this RFC is for (devs, ops, stakeholders, etc.) — affects depth and tone

### 5. Alternatives Considered

Other approaches evaluated and why rejected. 2-3 bullets max. "N/A — no viable alternatives" if obvious.

### 6. Trade-offs & Risks

Honest assessment. What could go wrong?

- Risk: … → Mitigation: …

### 7. Open Questions

Things undecided, needing input, or deferred. Mark as draft items.

### 8. Actions / Next Steps

Who does what, by when. Concrete, assignable.

## Process

### Phase 1: Understand (interactive)

Ask questions **one at a time**. The user is concise — keep each question tight. If the user provided enough detail upfront, infer what you can and only ask what's genuinely ambiguous.

Work through:

1. **Topic** — What's this RFC about? One short phrase.
2. **Trigger** — Why now? What changed?
3. **Problem** — What specific problem does this solve? (Skip if given.)
4. **Proposal** — Do you have a solution in mind, or exploring?
5. **Audience** — Who needs to read/approve this? (Stakeholders, reviewers)
6. **Timeline** — Deadline or urgency?
7. **Risks** — Obvious risks or dependencies you already know about?
8. **Location** — Where should I save it? (Only if path resolution is ambiguous.)

### Phase 2: Write Draft

1. Resolve target directory using the Output Location rules above.
2. Determine topic slug (lowercase, hyphens, no special characters).
3. Write the RFC with the host agent's file-write tool.
4. Include a Mermaid diagram in the Proposal section if the flow, architecture, or decision tree has ≥3 branching paths — keep it simple.
5. Confirm the write succeeded by re-reading the file or checking its stat.

### Phase 3: Self-Review

The doc-coauthoring pattern calls for a fresh-reader pass. Without a subagent, do it yourself:

1. Re-read the file as if you've never seen the topic. Verify the BLUF actually states the recommendation — not the topic.
2. Scan for structural gaps: every decision has rationale; every action has a date or `TBD`; every open question has an answerer; sections match the structure above.
3. Run the anti-AI pass: search for em dashes, "underscores," "tapestry," "let's break this down," "serves as a testament," "it is worth noting," "exciting," "game-changing," "unlock potential."
4. Apply the verification checklist before delivery.

For substantive RFCs that will be circulated widely, recommend the user opens a fresh chat/session to cold-read it. Capture their feedback and apply targeted edits.

> Skip this phase for trivial RFCs (1-2 sections, single decision).

### Phase 4: Deliver

Reply with:

- **Path** to the RFC
- **Status line** — "RFC: [BLUF] → saved to `<path>`"
- **1 sentence** offering to iterate

## Style Rules (non-negotiable)

- **BLUF first** — bottom line before anything
- **Bullet points** over paragraphs — dense noun phrases, not flowing prose
- **No AI-isms** — no "underscores," "serves as a testament," "it is worth noting," "let's dive in"
- **No hedging** — "This is" not "It could be argued that this is"
- **No cheerleading** — no "exciting," "game-changing," "unlock potential"
- **Bold key terms**, not full sentences
- **Copula direct** — "We migrate" not "We are proposing to migrate"
- **Specific over vague** — name the tool, config, command. Not "automate deployments" but "GitHub Actions deploys to ECS on merge to main"
- **Mermaid where useful** — flowcharts for branching logic, not for linear sequences
- **Audience-aware depth** — for devs: architecture/API detail; for stakeholders: timeline/risk; for both: BLUF → detail
- **Dry humor tolerated** — only if it lands. Default: straight.

## Common Pitfalls

1. **Writing before understanding.** Don't draft until you've asked clarifying questions for what's ambiguous.
2. **Overwriting context.** If the user gave detail in chat, don't re-ask those questions.
3. **Date format.** ISO 8601: `YYYY-MM-DD`. Not `MM/DD/YYYY`, not `DD.MM.YYYY`.
4. **Slug hygiene.** Lowercase, hyphens only. No spaces, no capitals, no emojis.
5. **Too verbose.** An RFC is 30-50 lines, not 200. Split into wikilinked sections if it needs more.
6. **Skipping self-review.** For any RFC someone else will read, the anti-AI pass catches blind spots.
7. **AI-isms sneaking in.** Do a final anti-AI pass before delivery — scan for em dashes, "tapestry," "underscores," "let's break this down."
8. **Wrong target directory.** When the user is in a project repo, prefer `./rfc/` or `./docs/rfc/`. Don't drop files at cwd root unless asked.

## One-Shot Recipes

### Quick RFC (single decision, single stakeholder)

Ask 1-2 clarifying questions → write directly → skip self-review → deliver.

### Full RFC (multi-stakeholder, architectural)

Full interactive phase → draft with Mermaid → self-review → deliver with offer to circulate for review.

### RFC Pipeline (ralphinho-style, for large features)

If the RFC describes work too large for one pass, add a **Decomposition** section after the Proposal that splits work into independently verifiable units (DAG of tasks). Each unit gets its own sub-RFC.

## Verification Checklist

- [ ] Target directory resolved (user-given, cwd `rfc/`, cwd `docs/rfc/`, or confirmed with user)
- [ ] File saved with correct date and slug
- [ ] Frontmatter complete: title, status, date, author, tags
- [ ] BLUF is the first content section and states the recommendation
- [ ] No AI-isms, no hedging, no cheerleading
- [ ] Bullet points, not dense paragraphs
- [ ] Mermaid diagram included if flow is non-trivial
- [ ] Self-review done (substantive RFCs only)
- [ ] Open questions section present if anything undecided
- [ ] Actions / next steps included with owners and dates (or `TBD`)
- [ ] File content verified by reread — especially important after applying multiple edits
