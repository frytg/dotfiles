---
name: meeting-notes
description: Turn raw transcripts, scattered notes, or a voice memo into a decision log, a task list, and a status log — not a transcript. Use when the user pastes a meeting transcript, says "summarize this meeting", "meeting notes", "what were the action items", "write up from this call", "debrief", "recap", "what did we decide", or hands over notes from a standup, 1:1, client call, planning session, retrospective, or all-hands.
license: MIT
metadata:
  author: frytg
  agent: pi
  inspirations:
    - anthropics/skills (BLUF — headline discipline)
    - SkillMedev/skills (UNASSIGNED / TBD discipline, verb-first actions)
    - mohitagw15856/pm-claude-skills (scoring rubric)
    - andreaswasita/copilot-cowork-dojo (owner verification against attendee list)
    - iankiku/forwward-teams ("every line earns its place" principle)
---

# Meeting notes

A meeting summary is not a transcript. It is a decision log, a task list, and a status log. A line records a decision, assigns work, flags a risk, or states an update that needed no decision. Cut dialogue and repeated facts. Do not cut a reported update because nobody has to act on it.

The notes answer five questions, in order: what is the call, what was reported, who does what by when, what was decided, and what is still open.

Name people when the name carries the work or the update. An owner, an answerer, a decider, the person who holds a result. Never write "Sam said X" when "X was reported" says the same thing.

## When to use

- The user pastes a transcript, bullet notes, or a voice memo and wants structure.
- After a meeting with decisions or assigned actions, within 24 hours.
- Any meeting type: standup, 1:1, client call, planning, retro, all-hands, vendor workshop, kick-off.

## Not for

- A long-form project retrospective. Use a postmortem skill.
- A client-facing narrative. Those want prose, not a recap.
- A board pack with financial detail. Use a deck or memo skill.

## Where the notes go

Two shapes. Pick the one the destination already uses. Do not invent a third.

**Pattern A, default.** One master file per recurring project, named like `<Project> Meetings.md`. Each meeting is one `## YYYY-MM-DD <topic>` section. Newest first. Insert the new section above the previous dated heading. Do not restructure the file's preamble.

**Pattern B.** One file per meeting, for events, conferences, and one-offs. File name `YYYY-MM-DD <topic>.md`. Follow the vault `AGENTS.md` for the folder. No H1; the filename is the title.

If a project master already exists, use it. If unsure, check the project folder, then the events folder. Never create a new master file without asking.

Frontmatter, only on a new file:

```yaml
---
tags:
  - <project>
  - <team>
docs:
  - <url to the external master>
---
```

Tags are a dash-list. Omit `docs:` when there is no external master. Do not invent `date:`, `attendees:`, or `source:`. Do not rename an existing `docs:` key after the host. Do not rewrite frontmatter on an existing master file.

If the file already has a contacts block (`## Key-User`, `## Teilnehmer`, or `## Contacts`), add new named stakeholders there, one line per person, email inline when known. Do not add a contacts block to a file that does not have one. Do not repeat those names inside the meeting body.

## Extract first

Read the source three times, then write once.

1. **Updates.** A status, result, or lead the room reported, including ones that need no decision and no action. A survey that is almost done. An inbox that was empty. A site that is not an official project. These earn a topic, or unlabeled sub-bullets under the topic they belong to.
2. **Decisions.** A choice that was settled. A debate left open is not a decision.
3. **Commitments.** A named promise. "I'll handle X." "Priya will send Y." Becomes an action.
4. **Open threads.** Questions dropped, disagreements without a settlement, parked items.

Collapse duplicates. Keep the most specific phrasing and the latest stated date. An update with no decision still stays. Do not force a `decision:` or an `action for` onto it.

Lead with what that meeting type cares about. Standup: blockers and handoffs. 1:1: decisions and commitments. Client call: what was promised. Planning: the decision and the rejected option. Retro: what changes, and who owns it. Vendor workshop: what each side owes the other. Still include the reported updates. Leading with blockers does not mean dropping a status that needed no decision.

If the source is too thin to extract from, say so. Return what is extractable. Do not pad.

Date defaults to today when unknown. Note that assumption in chat, not as a second block in the file.

## Output

One English block. That block is the whole entry. Do not add a German restatement. Do not add a `### summary` under another list. Do not add a formal hand-out unless the user asks for one.

```markdown
## YYYY-MM-DD <topic>

<Call, one short sentence per line.>
<Second sentence, if it changes what someone does.>

- 📅 **<topic>** — <few words, or omit the dash>
	- <one update or fact; no label required>
	- decision: <what was settled> — <why, if stated>
	- action for <owner>: <verb-first action> (due <YYYY-MM-DD or TBD>)
	- open: <question> — <answerer>, <by when or TBD>
	- ⚠️ <risk, one line>
```

**Lines.** The call is 2–4 short sentences, one per line, no blank lines between them. A topic line is a label, not a paragraph. Each sub-bullet is one fact. Break a long thought into another sub-bullet instead of writing a sentence that wraps.

**List spacing.** No blank lines between bullet lines. Not between topics, not between a topic and its sub-bullets. One blank line after the heading. One blank line between the call and the list. One blank line before the next heading. Nothing else.

**Indent.** Sub-bullets use one tab. Do not use spaces. This wins over the markdown skill's blank-line and indent rules.

**Labels.** `decision:`, `action for <owner>:`, `open:`. A risk line may start with ⚠️. An update has no label. A topic may be only updates. Do not use checkboxes or tables.

**Emoji.** One per topic, on the topic line only, except ⚠️ on a risk sub-bullet. The set:

- 🚀 launch or headline decision
- 📍 place, hosting, where people will be
- 👤 people, ownership, a named inbox or rota
- 📅 date, deadline, a cancelled or moved meeting
- 🤝 partnership or agreement
- 🎯 scope, a slot that was secured, a target
- 🔄 ongoing work, a retro, a migration
- 🔧 technical status, a blocked deploy, infra
- ✨ a reported update, result, or lead that needs no decision
- ⚠️ do not repeat, watchlist, blocker

A topic that fits two still gets one. Pick the most load-bearing.

**Language.** The entry is English. Source quotes stay verbatim, in the original language, as a blockquote after the list. Do not translate them. Do not invent them.

## Action, decision, open

- **Owner.** Exactly one name, as written in the source. If nobody was named, write `UNASSIGNED`. Never assign the note-taker, the organizer, or the most plausible person by inference.
- **Action.** Verb first. `Cancel the appointment`, not `Appointment`.
- **Due.** Only when stated. Resolve `by Friday` or `next week` to a calendar date only when the meeting date is known. Otherwise `TBD`. Do not invent urgency.
- **Decision.** One per sub-bullet. Include the why if one was stated. Record dissent as a position, not a person. A debate that did not settle is `open:`, not `decision:`.
- **Open.** Question, answerer, by-when. `UNASSIGNED` and `TBD` when the room did not name them.
- **Verify names** against people actually in the source before writing. A guessed owner is the usual defect.

## Anti-patterns

- A German list and an English summary of the same meeting. One block.
- A `### summary` under notes that already say the same thing.
- A topic line that is 1–3 sentences. The label is short. Facts go underneath.
- Blank lines between bullet lines.
- Who-said-what, in order. Extract the outcome.
- Actions owned by "the team". One name, or `UNASSIGNED`.
- A date that was not stated. `TBD`.
- A debated item promoted to `decision:`.
- A recommendation the room did not make.
- A new master file, or a new contacts block, the file did not already have.
- Dropping a reported update because it has no decision and no action.
- Padding the recap with dialogue so it matches the transcript.

## Before sending

- [ ] One English block. No second summary. No German copy.
- [ ] Call is short sentences, one per line, and it carries the call.
- [ ] Topic lines are labels. Sub-bullets are one fact each.
- [ ] No blank lines between bullet lines. Sub-bullets are tab-indented.
- [ ] Reported updates are in the notes, even when nobody has to decide or act.
- [ ] Every action has one owner, or `UNASSIGNED`, and a date, or `TBD`.
- [ ] Every decision has a why, if one was stated.
- [ ] Every open has an answerer and a by-when, or `UNASSIGNED` / `TBD`.
- [ ] Names were in the source. No guessed owners.
- [ ] Heading is `## YYYY-MM-DD <topic>`, in the existing master file, newest first.
- [ ] Within 24 hours of the meeting.

## Example

Synthetic. Do not copy real people, orgs, or paths into a note.

```markdown
## 2026-09-25 weekly

Next week's sync is off.
The pilot stays blocked until the partner answers.
The retro waits until the week of 10 Nov.

- 📅 **Next sync** — cancelled
	- venue clash
	- moderation would have been Alex
	- action for Sam: cancel the appointment (due 2026-09-26)
- 🔧 **Pilot**
	- mapping is in
	- no release, so no deploy this week
	- partner silent for ~10 days
	- decision: let it run 2–3 weeks, then stop if still silent
	- action for Alex: write the partner lead (due TBD)
	- open: does the partner take the mapping — partner lead, week of 2026-10-06
- 🔄 **Retro**
	- needs 2–3 hours; this month does not fit
	- earliest: week of 10 Nov
	- decision: hold it that week
	- action for Rio: ask an outside facilitator (due TBD)
	- open: facilitator capacity — Rio, before the week of 2026-11-10
- ⚠️ **Offsite**
	- do not staff again
	- morning slot empty; about 10 people
	- decision: empty rooms were the event, not the talk
- ✨ **Survey**
	- results are nearly ready
	- more user detail than other accounts so far
	- the circle can join, or take the results
	- open: presentation date — presenters, TBD
```

## Related skills

- **bluf** — if the call reads like a topic list, rewrite the opening sentences.
- **obsidian** — when the destination is the vault. This skill writes the content. Obsidian writes the file.
- **dots-save-article** — a long-form article, not a meeting recap. Do not use it here.
