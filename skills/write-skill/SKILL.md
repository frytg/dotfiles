---
name: write-skill
description: >-
  Create or revise a SKILL.md in this repo's skills/ tree, following the Agent Skills spec
  and the repo's own conventions (frontmatter fields, description-as-trigger, body
  structure, portability). Analyzes neighboring skills for the category first, then writes
  the file and reminds to run `just link`. Use when the user asks to add, write, create, or
  improve a skill, says "make this a skill", "turn this into a skill", or wants an existing
  SKILL.md reviewed against the spec.
license: MIT
metadata:
  author: frytg
  agent: pi
  category: engineering
---

# Write a skill

A skill is a single `SKILL.md` with YAML frontmatter that activates when the user's request matches its description. The description decides whether the skill fires; the body decides whether the result is good. Spend most of the effort on the description.

## Before writing

1. Read 2-3 existing skills in the same category (`skills/<category-neighbor>/SKILL.md`) to match their structure and tone.
2. Read the [Agent Skills spec](https://agentskills.io/specification.md) for required fields when in doubt about a constraint.
3. Check no existing skill already covers the trigger — extend that one instead of adding a near-duplicate.

## Frontmatter

```yaml
---
name: kebab-case-id # matches the directory name, ≤64 chars, [a-z0-9-]
description: >- # ≤1024 chars, see formula below
license: MIT
metadata:
  author: frytg
  agent: pi # pi | fx — the harness the skill was created in
  category: engineering # engineering | productivity | writing | media | social | ard
  inspirations: [] # optional, list sources borrowed from
---
```

Rules:

- `name` and `description` are required by the spec; everything else is optional.
- Directory, `name`, and the skill's self-reference must all match: `skills/<name>/SKILL.md`.
- Create a new `category` value only when none of the six fit.

## Description formula

Every skill in this repo follows the same pattern — copy it:

1. Open with a verb-first capability sentence: what it does, in one sentence ("Fetch any public AT Protocol data as clean Markdown", "Turn raw transcripts into a decision log").
2. Follow with the mechanism or scope if it matters for matching ("Detects the active frontmatter style by inspecting the last few entries").
3. Close with "Use when the user…" listing concrete trigger phrasings, in quotes, including shorthand and alternate wordings ("says 'make this a skill', 'turn this into a skill'").

Write in third person, present tense. Include what the skill is _not_ for only if the trigger overlaps a sibling skill.

## Body structure

Follow the house shape, in this order:

1. One H1, then a lead paragraph that defines the **output**, not the process. "A meeting summary is not a transcript. It is a decision log…" — not "This skill helps you summarize meetings."
2. "## When to use" — bullets of concrete trigger situations.
3. "## Not for" — only when a sibling skill or obvious misuse would otherwise win the trigger.
4. Workflow as numbered steps, each with its stop conditions inline ("If `X` is not set, warn the user and stop"). State failure behavior explicitly; never let the agent guess a fallback.
5. Output format in a fenced code block when structure matters (reports, briefs, comments).
6. End with a short checklist or reply-format line, not a summary paragraph.

Style: terse, imperative, one idea per sentence. Numbered lists for sequences, plain bullets for parallel facts. No scaffolding phrases, no praise. Target 50–400 lines; if it grows past that, split reference detail into a `references/` subfolder instead of bloating the body.

## Portability

Examples must be synthetic — placeholder names (`Acme`), generic roles, made-up IDs, abstract scenarios. No real names, employers, ticket numbers, internal hostnames, or real URLs, except public data the skill's job requires (lookup skills may cite real public URNs).
