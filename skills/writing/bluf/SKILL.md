---
name: bluf
description: Generate decision-ready summaries in BLUF (Bottom Line Up Front) format. Use when the user asks for a summary, brief, status report, executive summary, recap, or "what does X say" where the reader needs the answer first and the supporting context second.
---

# BLUF — Bottom Line Up Front

State the answer in the first sentence, then provide only the context the reader needs to act on it. The reader should be able to stop after the headline and still walk away with the conclusion.

## When to use

- Summarizing notes, meeting notes, weekly reviews, status updates, incident reports, threads, articles.
- Producing a decision brief — "should we do X?"
- Recap emails to a manager or team.
- Anytime the user says *summarize*, *brief me*, *BLUF*, *bottom line*, *status*, *recap*.

## Not for

- TL;DR lists for skimming (use a plain summary or bullet list).
- Inputs where the conclusion isn't yet clear — flag the ambiguity and ask, don't pick a side.

## Output structure

```
# [Title — topic in 3-7 words]

**BLUF:** [The answer in one sentence.] [2-4 sentences of maximum context: critical who/what/when/why, decision or action required, deadline if any. The reader can act on this paragraph alone.]

## [Supporting sections, in order of importance, not chronology:]
- Wins / Outcomes
- Risks / Watchlist
- Open items / Carry-over
- Next steps / Decisions needed
- Key quotes / data points (only if load-bearing)
```

## Rules

1. **The headline is the answer.** Not a topic, not "Summary of X" — the conclusion.
2. **Lead with the dominant risk or decision.** If there's a yes/no question, answer it. If there's a tradeoff, name the dominant side.
3. **No throat-clearing.** No "In this document…", no restating the prompt. Start with the substance.
4. **Cut anything that doesn't change a decision.** If a detail doesn't affect what the reader will do next, omit it.
5. **Be specific.** Names, numbers, dates, links. "Things are going well" is useless.
6. **Use the writer's voice when it's good.** When summarizing someone else's note, preserve their terms and framing — don't re-paraphrase into corporate mush.
7. **Mark uncertainty.** "Appears to", "unclear", or list the interpretations — don't pick one and pretend.
8. **One BLUF per output.** Depth comes from sections, not nested conclusions.

## Length

- BLUF paragraph: 2-4 sentences, ~50-100 words.
- Total output: 150-400 words typical, 600 max.
- If you can't fit it in 400 words, the input probably wants an analysis, not a BLUF — say so.

## What to avoid

- "In summary…", "To summarize…", "Overall…" — anti-BLUF.
- Topic sentences that don't contain the answer.
- Three-item lists in the BLUF paragraph (use sections).
- Hedging that softens the answer ("It might be argued that…").
- Restating the source's structure chronologically instead of by importance.
- Mirroring the source's headers if they aren't decision-relevant.

## Example (good)

Input: a 20-message thread about a Friday service migration with five services to cut over.

```
# Acme migration — on track for Friday, payments test still unproven

**BLUF:** Migration ships Friday with four of five services cut over in staging; payments passes the schema check but rollback failed in this morning's dry run, so we're blocked on one re-test before we go. **Hold the cutover for an extra half-day to re-run the rollback test — the dominant risk is silent data drift in `orders_v2`, where three rows already mismatched the legacy table during staging and we don't yet have a reconciler.**

## Status
- Cutover in staging: auth, catalog, search, billing. Payments pending re-test.
- Rollback dry run at 09:00 failed at step 4 (queue drain) — stuck consumer.

## Decisions needed
- Today EOD: confirm the half-day delay, or override with VP-Eng sign-off.
- Tomorrow 14:00: re-run the rollback dry run; cut over if it passes.

## Watchlist
- `orders_v2` row drift — 3 mismatches found, 0 reconciled.
- On-call coverage thin Saturday; PagerDuty rotation still has the gap.
```

## Example (bad)

```
# Weekly Summary

This week was a productive week with many things happening. Overall, there was a lot of progress in various areas.

## Work
Some work was done on various projects.

## Training
Training was lighter this week due to holidays.
```

Buries the lead, no specifics, mirrors the source's chronology, adds nothing the reader couldn't have guessed.
