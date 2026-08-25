---
name: proofreader
description: Proofread a file or pasted text and return a bullet list of suggestions covering spelling, style, grammar, and punctuation (including commas). Each line starts with the source line number followed by the suggested fix; the changed word(s) or phrase(s) are wrapped in **bold**. Skips capitalization flags — see my-voice. Never edits the source.
metadata:
  author: frytg
  agent: fx
---

# Proofreader

Proofread pass over a file or pasted text. Surfaces suggestions, never mutates
the source.

## Inputs

- A file path, or
- Pasted text inline.

Detect which by the request. If both, proofread the file and mention the
inline text was ignored.

## Output format

A bullet list. One bullet per suggestion. Use a category tag so Dan can
filter:

- `[spell]` — misspelled words.
  - `L<line>: replace **<wrong>** with **<right>**`
  - `L<line>: replace **<wrong>** with **<right>** (suggested: <alt>, <alt>)`
    — when more than one plausible correction exists; list up to 3.
  - `L<line>: suggested split — **<word1>** / **<word2>**` — for
    run-together words the dictionary doesn't know as one (e.g. `alot` →
    `a lot`, `intothe` → `in to`).
  - `L<line>: extra space before/after **<word>**` — for double spaces or
    stray whitespace adjacent to a token.
- `[style]` — word choice, tone, voice, or my-voice mismatches.
  - `L<line>: prefer **<suggested>** over **<current>** (per my-voice)` —
    clipped form, filler word, jargon, etc.
  - `L<line>: rephrase — <short suggestion>` — when a single word swap
    doesn't capture it (e.g. "this is a bit awkward, consider X").
- `[grammar]` — agreement, tense, article, pronoun, modifier placement,
  run-on sentences, etc.
  - `L<line>: rephrase — <short suggestion>`
  - `L<line>: missing article — insert **<a|an|the>** before **<word>**`
- `[comma]` — missing, extra, or misplaced commas. This is the most common
  punctuation flag; treat comma suggestions as a first-class category.
  - `L<line>: add comma after **<word>** — <short reason>` (e.g. before a
    coordinating conjunction joining two independent clauses, after an
    introductory phrase, between items in a series, around a non-restrictive
    clause).
  - `L<line>: remove comma after **<word>** — <short reason>` (e.g.
    unnecessary comma between subject and verb, in a compound predicate
    without a pause, before a restrictive clause).
  - `L<line>: replace comma with **<semicolon|colon|dash>** — <short reason>`
    when a stronger break is needed.
- `[punct]` — other punctuation: apostrophes, hyphens, dashes, semicolons,
  colons, quotation marks.
  - `L<line>: replace **<wrong>** with **<right>** — <short reason>`
    (e.g. `its` vs `it's`, `recieve` vs `receive`, em-dash vs hyphen,
    missing closing quote).

After the bullet list, a single line:

- `No issues found.` — when there is nothing to flag.

## Rules

1. **Proofread, don't rewrite.** Flag suggestions; do not produce a fully
   rewritten paragraph. Bullets stay short — one fix per bullet.
2. **Prioritize over-edits.** It is better to under-flag than to flood Dan
   with style nits. If unsure whether something is a real issue, drop it.
   As a soft cap, try to stay under ~10 bullets per 100 lines; for a
   short file (<30 lines) aim for fewer than 5.
3. **Skip capitalization flags entirely.** Lowercase starts, lowercase "i",
   mid-sentence capitals — all ignored. This matches the my-voice style; do
   not contradict it.
4. **Skip proper-noun guesses.** If a word could be a name, brand, or
   domain-specific term, leave it alone unless the issue is obvious
   (e.g. `teh`, `recieve`, `occured`).
5. **Skip code, URLs, file paths, and inline markdown links.** These are not
   prose; leave them alone. Code fences (```) and inline backticks exempt
   their contents from every category.
6. **Skip frontmatter.** YAML/TOML frontmatter at the top of a markdown
   file is config, not prose — don't flag it.
7. **Reference my-voice for tone.** When a flagged word is also one the
   my-voice skill would render differently (e.g. clipped forms, filler
   words like "just", "really", "very"), prefer the suggestion that matches
   my-voice and tag it `(per my-voice)`.
8. **Comma rules to apply.** Common cases worth flagging:
   - Missing comma before `and`/`but`/`or`/`nor`/`so`/`yet` joining two
     independent clauses.
   - Missing comma after an introductory phrase or clause (>3 words, or
     ambiguous).
   - Missing comma in a series of three or more items (Oxford comma is a
     style choice — only flag its absence or presence if it's inconsistent
     with the rest of the file).
   - Missing comma around a non-restrictive appositive or relative clause.
   - Unnecessary comma between subject and verb.
   - Comma splice joining two independent clauses with no conjunction
     (suggest a period, semicolon, or conjunction).
9. **Grammar rules to apply.** Common cases worth flagging:
   - Subject–verb agreement.
   - Wrong or missing article (`a` vs `an` based on the following sound).
   - Dangling or misplaced modifier that changes meaning.
   - `its` vs `it's`, `your` vs `you're`, `their`/ `there`/`they're`,
     `then` vs `than` — only when the wrong form is clearly intended.
   - Run-on sentences that genuinely hurt clarity (not just long ones).
10. **Style rules to apply.** Flag only when the alternative is
    meaningfully clearer or more concise:
    - Filler words: `just`, `really`, `very`, `quite`, `actually`, `basically`.
    - Weasel words: `somewhat`, `kind of`, `sort of`, `in order to`.
    - Redundant pairs: `end result`, `past history`, `free gift`.
    - Passive voice only when the active form is shorter and clearer.
    - Nominalizations where a verb reads better (`make a decision` →
      `decide`).
11. **Never edit the file.** Print the report and stop. Dan applies fixes
    himself.
12. **Line numbers refer to the source as given**, 1-indexed. If the input
    is pasted text without line numbers, number the visible lines yourself
    and say so in a one-line preamble.
13. **Group by category in the output.** Order categories as
    `[spell]`, `[grammar]`, `[comma]`, `[punct]`, `[style]` so Dan can scan
    in roughly increasing severity. Within a category, keep source line
    order.

## Before returning

1. Re-scan every bullet — is this a real issue, or am I nitpicking? Drop
   nitpicks.
2. Confirm no false positives in code blocks, URLs, paths, or frontmatter.
3. Confirm the capitalization rule held — no `Should capitalize "i" here`
   bullets.
4. Confirm comma flags have a real reason; do not flag every comma.
5. Confirm style flags actually improve the sentence — if the original is
   fine, drop the flag.
6. Confirm each bullet's line number points at the real source line.

## Example

Input (line 3 has the issues):

```
line 1: this is fine
line 2: another clean line
line 3: teh quick brown fox jumps and soem more text
line 4: Just a small thing, that I wanted to flag.
```

Report:

- `L3: [spell] replace **teh** with **the**`
- `L3: [spell] replace **soem** with **some**`
- `L4: [style] prefer **A small thing** over **Just a small thing** (per my-voice)`
- `L4: [comma] add comma after **thing** — closing a non-restrictive clause introduced by "that"`

(Original comma before "that" is also unnecessary — flag whichever is
clearer; one bullet per real issue.)
