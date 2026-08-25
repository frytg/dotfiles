---
name: meeting-notes
description: Turn raw transcripts, scattered notes, or a voice memo into a decision log and task list — not a transcript. Use when the user pastes a meeting transcript, says "summarize this meeting", "meeting notes", "what were the action items", "write up from this call", "debrief", "recap", "what did we decide", or hands over notes from a standup, 1:1, client call, planning session, retrospective, or all-hands.
license: MIT
metadata:
  author: frytg
  agent: pi
  inspirations:
    - anthropics/skills (BLUF — headline discipline)
    - SkillMedev/skills (UNASSIGNED / TBD discipline, verb-first actions)
    - mohitagw15856/pm-claude-skills (scoring rubric, reopen-when)
    - andreaswasita/copilot-cowork-dojo (owner verification against attendee list)
    - iankiku/forwward-teams ("every line earns its place" principle)
---

# Meeting notes

A meeting summary is not a transcript. It is a **decision log and a task list** — documentation for the future reader, not a record of who argued what in the room. Every line either records a decision, assigns work, or flags a risk. Nothing else earns a line.

The notes should answer four questions in order: **what is the call, who does what by when, what was decided, and what is still open.** If a section does not change what someone does next, cut it.

Default to **positions and outcomes over speakers**. Name people only when the name carries the work — an action item owner, an answerer of an open question, a decider whose authority matters. Never write "Sarah said X" when "X was decided" says the same thing.

## When to use

- The user pastes a transcript, bullet notes, or a voice memo dump and wants structure.
- After a meeting with decisions made or actions assigned — within 24 hours.
- Any meeting type — standups, 1:1s, client calls, planning, retros, all-hands.

## Not for

- A long-form project retrospective with root cause analysis — use a postmortem skill.
- A client-facing narrative with relationship context — those want prose, not a recap.
- A board pack with financial detail — use a deck or memo skill.

## Inputs

Ask for what is missing; do not block on it. Defaults in parentheses.

- **Source**: transcript, bullet notes, or voice memo (`ask`).
- **Meeting date** (`today` if unknown — note the assumption).
- **Attendees** (`extract from source`; only mention the names that earn a line — deciders, owners, answerers).
- **Meeting type** (`infer` from agenda, attendees, and language — see the type table below).
- **Language**: **always reply in English**, unless the user specifically asks for another language. The transcription or input language does not change the output language — a German transcript still produces English notes.

If the source is too thin to extract from (no verbs, no names, no decisions), say so and return what is extractable rather than padding.

## The three-pass extraction

Read the source three times, one lens per pass. A single pass reliably misses commitments buried inside discussion.

1. **Decisions.** A choice between options that was settled. _“We’re going with quarterly billing.”_ A debate left open is not a decision — it lands in Open.
2. **Commitments.** Any first-person or assigned promise — _“I’ll handle X,” “Priya will send Y,” “we should do Z by Friday.”_ Becomes an action item.
3. **Unresolved threads.** Questions raised and dropped, disagreements without a settlement, _“let’s discuss offline,”_ deferred topics, parked items.

Then collapse: duplicate mentions of the same commitment become one row, keeping the most specific phrasing and the latest stated date.

## Meeting-type calibration

The shape shifts by what mattered most. Infer from the source; do not ask unless ambiguous.

- **Standup / sync** — lead with blockers and handoffs; compress status updates that did not surface a blocker.
- **1:1** — lead with decisions, commitments, feedback; compress career topics unless either side raised them.
- **Client call** — lead with what was promised and what was asked of us; compress relationship rapport.
- **Planning / strategy** — lead with decisions (rationale + rejected options); compress long debate history.
- **Retrospective** — lead with what to change and who owns the change; compress "what went well" unless load-bearing.
- **All-hands / board** — lead with key messages, decisions, follow-ups; compress anything not announced.

## Action item rules

These rules make the sub-bullets trustworthy. One violation poisons the whole output.

- **Owner**: exactly one name per action, preserved as written. If no owner was named, write **`UNASSIGNED`** in caps — the gap gets fixed in review rather than discovered at the deadline. Never assign the note-taker, the meeting organizer, or the most plausible person by inference.
- **Action**: verb-first instruction (`Send the pricing draft to sales`), never a topic (`Pricing draft`). A topic cannot be done; a verb can.
- **Due**: only when explicitly stated. Resolve relative dates (`by Friday`) to a calendar date **only** when the meeting date is known. Otherwise write **`TBD`**. Do not infer urgency into a date.
- **Verify owners against the attendee list** before output. Hallucinated owners are the most common defect — cross-check every name.

## Decision rules

- One decision per sub-bullet, past tense, specific.
- Include rationale if one was stated — a decision without _why_ is useless six months later when someone asks _why did we do that_.
- Note dissent as a position, not a person: _"Rejected mobile-only checkout — desktop coverage gaps raised as the risk."_ Smoothing over disagreement erases the option to revisit. The dissenting argument enters the record; who raised it usually does not.
- Add a `reopen-when` condition when the meeting implied one: _“Reopen when Q3 forecast lands.”_
- If a topic was debated but not settled, it is **not** a decision — it goes to `open:` under the topic that owns it.

## What stays in vs. out

**In:**

- Explicit decisions and the reasoning given.
- Commitments extracted as action items with their owners.
- Risks, blockers, escalations raised.
- Explicitly unresolved questions.
- Numbers, dates, and names that load-bear — preserve them exactly.

**Out:**

- Who said what (attribution, unless the speaker's identity carries the decision).
- Tangents that did not produce a decision or task.
- Pleasantries, filler, _“does that make sense?”_ moments.
- Speculation that was not agreed on.
- Editorialising, recommendations, or advice the room did not endorse.

## Output format

There is exactly one output format. The same source always renders into this structure.

```markdown
# YYYY-MM-DD <max five-word summary>

<One BLUF sentence: staccato, carries the call.>

- 🚀 **<topic>**: <1–3 sentences on what the room concluded about it>
  - decision: <what was decided> — <rationale, if stated> — <counter-position, if any> — <reopen-when, if implied>
  - action item for <owner>: <verb-first action> (due <date or TBD>)
  - open: <question> — <answerer, by when>
- ✨ **<topic>**: <next topic summary>
  - action item for UNASSIGNED: <action> (due TBD)
```

**Title.** `# YYYY-MM-DD <max five-word summary>`. The summary is the meeting in five words, not the topic area.

**BLUF.** One sentence, staccato, easy to understand — the call. Not a paragraph.

**Topic bullets.** One bullet per topic that earned a line. Pick the emoji by content (🎯 decision, ⚠️ risk, 👤 ownership, 🚀 launch, ✨ opportunity, 🔄 status) — never decoration. Skip emoji in formal reports. If a topic didn't move a decision or surface a blocker, cut it.

**Sub-bullets.** Decisions, actions, and open questions nest under the topic that owns them. Use natural-language labels: `decision:`, `action item for <owner>:`, `open:`. **A decision or action may appear under more than one topic if it fits** — duplication is fine, omission is not. A topic with only a summary and no sub-bullets is fine when the discussion was the load-bearing part.

### Frontmatter (when the destination supports it)

```yaml
---
date: <YYYY-MM-DD>
attendees: [<names>]
source: <transcript | notes | voice memo>
tags: [meeting, <project>, <team>]
---
```

For tone and phrasing that read like Dan, run the output through the **my-voice** skill — it can tighten the BLUF and bullet prose without breaking the structure above.

---

## Anti-patterns

- **Transcribing who said what in order** — extract decisions and tasks, ignore dialogue.
- **Replaying the conversation in summary form** — summarize each topic in 1–3 sentences; do not turn every source sentence into an output bullet.
- **Assigning actions to “the team” or “everyone”** — one named owner per row; `UNASSIGNED` if missing.
- **Fabricating a deadline to look concrete** — `TBD` if not stated; never infer urgency into a date.
- **Phrasing actions as topics** (`Pricing draft`) — verb-first (`Send the pricing draft to design`).
- **Promoting debated-but-unsettled items to `decision:`** — they belong in `open:` under the same topic.
- **Burying decisions in narrative prose** — decisions belong in their own sub-bullets, not folded into the topic sentence.
- **Adding recommendations the room did not endorse** — neutral recorder, not participant.
- **Skipping the rationale on a decision** — _why_ earns its line; future-you will need it.
- **Sending the recap three days later** — within 24 hours, while owners can still act.
- **Padding the recap to match the transcript length** — cut anything that does not change what someone does next.
- **Dropping ownerless actions to tidy the list** — `UNASSIGNED` in caps is the feature, not a formatting failure.

## Quality gate (scoring rubric, 0–40)

Score before sending. 32+ is ship quality.

- **Action accountability (0–10)**
  - **0** — actions owned by “the team” or nobody, with no dates.
  - **5** — named owners but vague deadlines (`next week`, `soon`) or co-owned blobs.
  - **10** — every action has exactly one named owner and a concrete date; shared work split into separately-owned items.
- **Decision traceability (0–10)**
  - **0** — decisions buried in discussion or recorded without any why.
  - **5** — decisions listed with owners but rationale thin; disagreement invisible.
  - **10** — each decision carries context, owner, and deadline; dissent recorded inside the decision with a reopen condition.
- **Synthesis over transcript (0–10)**
  - **0** — verbatim capture of who said what, in order.
  - **5** — trimmed transcript grouped by topic, still dialogue rather than distillation.
  - **10** — discussion summarized per topic in 1–3 sentences each; quotes appear only where they carry decision weight.
- **Loop closure (0–10)**
  - **0** — open questions, deferred topics, escalations silently dropped.
  - **5** — open items listed but ownerless or dateless; deferrals vanish from next steps.
  - **10** — every open question has an owner and by-when; deferred items reappear in next steps with dates; notes sent within 24h.

### Pre-send checklist

- [ ] BLUF sentence carries the call, not the topic.
- [ ] Every action item has exactly one named owner (or `UNASSIGNED`).
- [ ] Every action item has a concrete date (or `TBD`).
- [ ] Every decision carries context (why), and dissent if any.
- [ ] Every open question has an answerer and a by-when.
- [ ] Owners verified against the attendee list — no hallucinated names.
- [ ] No verbatim transcript content — synthesis only.
- [ ] Within 24 hours of the meeting.

---

## Example

The italic notes between sections are the rule, not the output. Strip them when filling the template in.

```markdown
# YYYY-MM-DD <max five-word summary>

<!-- Date + ≤5-word title. The summary is the meeting in five words, not the topic area. -->

<One BLUF sentence: staccato, carries the call.>

<!-- One sentence, not a paragraph. The verdict. -->

- 🚀 **<topic>**: <1–3 sentences on what the room concluded about it>
  - decision: <what was decided> — <rationale, if stated> — <counter-position, if any> — <reopen-when, if implied>
  - action item for <owner>: <verb-first action> (due <date or TBD>)
  - open: <question> — <answerer, by when>

<!-- One bullet per topic. Emoji marks content, not decoration. Cut topics that did not move a decision or surface a blocker. -->

- ✨ **<topic>**: <next topic summary>
  - action item for UNASSIGNED: <action> (due TBD)

<!-- Sub-bullets nest under the topic that owns them. Same content may appear under multiple topics — duplication is fine, omission is not. UNASSIGNED in caps is the feature, not a formatting failure. -->
```

---

## Related skills

- **bluf** — the headline-writing discipline this skill inherits. Read once if the BLUF in your recap reads like a topic.
- **my-voice** — for tweaking the BLUF and bullet phrasing to match Dan's writing style. Run the output through my-voice if the prose doesn't read like him; the structure stays intact.
- **obsidian** — when the destination is the user’s vault; this skill writes the content, obsidian writes the file.
