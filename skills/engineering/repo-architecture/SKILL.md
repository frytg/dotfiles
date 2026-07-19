---
name: repo-architecture
description: Scan a codebase for module-deepening opportunities, write a visual Markdown architecture report, then peer-clarify the candidate you pick. Use when the user wants to improve architecture, find shallow modules, deepen seams, pressure-test structure for testability/AI-navigability, or asks for an architecture review / deepening pass.
license: MIT
metadata:
  author: frytg
  agent: pi
  inspiration: mattpocock/skills improve-codebase-architecture
---

# Improve codebase architecture

Surface architectural friction and propose **deepening opportunities** — refactors that turn shallow modules into deep ones. Payoff is testability and AI-navigability, not tidy diagrams for their own sake.

Present candidates as a **Markdown report** (Mermaid diagrams, not HTML). Work keeps living in the chat and one temp file until you decide to act.

## Vocabulary

Use these terms exactly in every suggestion. Don't drift into "component," "service," "API," or "boundary" when you mean the terms below.

| Term               | Meaning                                                                                |
| ------------------ | -------------------------------------------------------------------------------------- |
| **module**         | A unit of code with an interface and an implementation                                 |
| **interface**      | What callers see — names, inputs, outputs, guarantees                                  |
| **implementation** | What sits behind the interface                                                         |
| **depth**          | Implementation complexity relative to interface complexity                             |
| **deep**           | Small interface, rich implementation — one place to test and change                    |
| **shallow**        | Interface nearly as complex as the implementation; deletion would just move complexity |
| **seam**           | Where one module meets another; a place you can substitute behavior                    |
| **adapter**        | A concrete implementation behind a seam                                                |
| **leverage**       | One interface serving many call sites                                                  |
| **locality**       | Related behavior and bugs concentrate in one module instead of spreading               |

Principles to apply:

1. **Deletion test** — would deleting this module _concentrate_ complexity, or just hand it to neighbors? "Concentrate" is the signal you want before calling something shallow enough to deepen.
2. **The interface is the test surface** — if tests have to reach past the interface into internals, the interface is wrong or the module is too shallow.
3. **One adapter = hypothetical seam; two = real** — don't invent seams "for testability" with a single production path and no second adapter in sight.

If the project has a domain glossary (`CONTEXT.md` or similar) and ADRs (`docs/adr/`), use their domain names for modules and don't re-litigate settled decisions unless friction clearly warrants it.

## Process

### 1. Explore

**Scope before you scan — YAGNI.** Deepening pays off where change still happens, so weight recent activity.

- If I named a direction — a module, subsystem, or pain point — take it and skip the hot-spot inference.
- Otherwise walk a good stretch of history (`git log --oneline`, optionally `--stat`) and let hot files/paths pull attention first. Scramble with no hot spot → widen the net.

Read domain glossary and nearby ADRs before digging.

Then explore the code organically. Note where _you_ feel friction:

- Understanding one concept means bouncing between many small modules.
- Modules are **shallow** — interface almost as big as the implementation.
- Pure functions were extracted "for tests," but real bugs live in how they're composed (no **locality**).
- Tightly-coupled modules leak across their **seams**.
- Areas that are untested or hard to test through the current interface.

Apply the **deletion test** to anything you suspect is shallow.

Don't invent a second scoring framework. Candidates earn a place by concrete friction + a plausible deepening, not by checklist density.

### 2. Present candidates as a Markdown report

Write one self-contained Markdown file to the OS temp directory so nothing lands in the repo by default.

```bash
# Resolve temp dir: $TMPDIR → /tmp (Unix); %TEMP% on Windows
REPORT="${TMPDIR:-/tmp}/architecture-review-$(date +%Y%m%d-%H%M%S).md"
```

Use the file tool to write `$REPORT`. Tell me the absolute path. Optionally open it (`open` on macOS, `xdg-open` on Linux) only if that helps — print the path either way.

Full card layout, Mermaid patterns, and tone rules: [MARKDOWN-REPORT.md](MARKDOWN-REPORT.md).

For each candidate include:

- **Files** — modules/paths involved
- **Problem** — friction in glossary terms
- **Solution** — plain English deepening (not a full design yet)
- **Wins** — locality / leverage / test-surface gains, short bullets
- **Before / After** — side-by-side Mermaid (or structured ASCII when graph shape doesn't help)
- **Strength** — `Strong` | `Worth exploring` | `Speculative`

End with a **Top recommendation**: which candidate first, and why (one sentence).

Rules:

- Domain nouns from the project's glossary when present; architecture nouns from the table above.
- **ADR conflict** — only surface a forbidden-looking refactor when friction justifies reopening the ADR. Mark it clearly; don't list every theoretical ADR-blocked idea.
- **Do not propose detailed interfaces yet.** Report is the map; design comes after I pick.
- Prefer lists over tables in the report body except for compact metadata. See house writing rules.

After the file is written, ask: **Which of these would you like to explore?**

### 3. Peer-clarify the pick

Once I pick a candidate, run the **`peer-clarify`** skill on it. Walk the decision tree: constraints, dependencies, the shape of the deepened module, what sits behind the seam, which tests survive, migration order.

Until shared understanding is confirmed:

- No bulk rewrite of production code.
- No inventing parallel plan docs when the running understanding already holds state.

### 4. Side effects only when they're load-bearing

As decisions crystallize, keep project language honest — don't create process theater:

- **New domain term that earned its keep?** Offer to add it to `CONTEXT.md` (or the project's existing glossary). Create that file only if the project already uses one, or I asked for it.
- **Sharpened a fuzzy term?** Update the glossary when we're clearly keeping the name.
- **I reject a candidate with a durable reason?** Offer an ADR only when a future explorer would otherwise re-suggest the same deepening — skip "not now" and self-evident "no."
- **Interface design forks?** Design it twice in short form (two alternative interfaces, one paragraph + sketch each), then peer-clarify which one wins. Don't spawn a previous ecosystem of sub-skills that aren't installed.

## Anti-patterns

- HTML / Tailwind / browser-report generation — this skill is Markdown-only.
- Acting on a deepening before peer-clarify finishes and I confirm.
- Suggesting extractions that fail the deletion test (shallow renames as "architecture").
- Seams with one adapter "for purity."
- Generic advice ("improve cohesion") without named files and a before/after.
- Re-litigating every ADR.
- Dropping the report into the repo unless I ask to keep it.

## Triggers

- improve architecture / architecture review / deepen modules
- find shallow modules / bad seams / hard-to-test structure
- "what would make this codebase more AI-navigable"
- the upstream skill name: improve-codebase-architecture
