---
name: self-improvement
description: Surface setup-level changes worth making from the current conversation and the context files in the working directory. Read-only — suggestions only, never writes. Use when the user asks for a self-improvement check, setup review, "anything to improve?", "recurring patterns", "any setup changes worth making?", or after a long session.
license: MIT
metadata:
  author: frytg
  agent: pi
  category: productivity
---

# Self-improvement check

The setup to improve is whatever gets re-done — by the user, by the agent, or by the routine — when a written skill, instruction, or context file would clarify, speed up, or remove the repetition. This skill surfaces those; it does not fix them. The guarantee: **nothing in this skill writes, edits, or commits a file.** No log, no draft diff, no note. If a suggestion is acted on, the user does it in a separate step.

The skill works in any context the user is in — a project repo, the dotfiles repo, an Obsidian note-taking session, a journaling flow, a normal chat, or a coding task. The suggestions are scoped to whatever setup is relevant for the active context. The skill does not pick a context; it reads the one it is run in.

## When to use

- The user invokes it explicitly: `/self-improvement`, "self-improvement check", "any setup changes worth making?", "anything to improve?", "recurring patterns", "setup review", "what should we change about the setup?"
- After a long session, before a context switch — pause and ask whether the setup still reflects how work is actually being done.
- When the user has corrected the agent multiple times in one session and is willing to convert those corrections into durable rules.

## Not for

- Mid-task problem solving — keep working; the skill is opt-in.
- Generic "improve the code"
- Long-form retros on personal work
- Auto-invocation — the user runs it; the agent does not run it on its own.

## Process

### 1. Inventory inputs

Three sources, no more:

- **The current conversation.** Read every exchange so far. Corrections and redirections count as evidence — every "no, do it like X" is a candidate observation, not just a one-off user comment.
- **Context files in the working directory.** Look for: `AGENTS.md`, `CONTEXT.md` (or `context.md`), `README.md`. If `docs/` or `context/` exists, list its top-level entries and skim the ones that look like context rather than code. Skip source files — that's repo-architecture's domain.
- **The skills in play.** Read the full `SKILL.md` of every skill that was loaded in the conversation before suggesting a change to it. List the names and descriptions of the skills in the dotfiles repo (`~/.dotfiles/skills/`), so a suggestion extends an existing skill instead of duplicating it.

Skip the home-dir vault, sibling repos, and unrelated Obsidian folders unless the working directory is one of those. The skill stays scoped to the active context.

### 2. Detect patterns across six lenses

One pass per lens. If a lens catches nothing, drop it. Do not score or rank — the user filters later.

- **Repeated instructions.** The same rule, preference, or convention was restated more than once in the conversation, or appears in one doc and was restated by the user anyway. _"Use BLUF," `be brief`, `don't X`._
- **Manual repetition.** The same multi-step procedure (e.g., find → read → reformat → write; or grep → summarize → file) was performed more than once in the conversation, or is described twice in different context docs.
- **Repeated context re-statement.** Project facts the user had to re-explain because they aren't in any context file. The fix is a context file, not a behavior change.
- **Missing tooling.** The user said "I'll do this manually" or "I'll handle X myself" more than once where a skill, script, alias, or shortcut would cover it.
- **Stale or contradictory config.** A setting in `settings.json`, `AGENTS.md`, `APPEND_SYSTEM.md`, or another setup file no longer matches how the conversation went, or contradicts another file in the same setup.
- **Workflow gap.** A moment in the conversation where a skill would have helped and none was loaded, or a skill exists and was not triggered when it should have been.

The evidence threshold depends on the size of the change:

- **Updating something that exists** (a skill, a context file, a config entry) needs one grounded occurrence: a specific correction or failure in the conversation that the existing text would have prevented if it had said the right thing.
- **Creating something new** (a skill, a context file, a script) needs two independent occurrences of the same behavior. A single occurrence is not setup-worthy; surface it as a habit observation only when the evidence is unusually clear, and even then with low confidence.

If the evidence does not support a change, abstain. "Nothing worth changing" is a valid result and is better than a padded list.

### 3. Cluster by setup target

Group suggestions into the smallest set of clusters that makes the output scannable. Cluster labels, first match wins:

1. `[context file]` — the fix is a new or updated `CONTEXT.md`, `AGENTS.md`, or `README.md` section in the working directory.
2. `[update skill]` — an existing skill at `~/.dotfiles/skills/<name>/SKILL.md` should change. Prefer this over `[new skill]` whenever an existing skill covers the trigger.
3. `[new skill]` — a new skill at `~/.dotfiles/skills/<name>/SKILL.md` would cover this, and no existing skill does.
4. `[agent config]` — change to a harness config file, such as a settings file, a global `AGENTS.md`, or an appended system prompt. Name the source file in the dotfiles repo, not the path it is symlinked to in the home directory.
5. `[dotfiles]` — change in the dotfiles repo (`Brewfile`, mise, shell, scripts). Only when the CWD is the dotfiles repo.
6. `[project]` — change to a project-local config (project `AGENTS.md`, harness folder, `justfile`). Only when in a project repo.
7. `[note convention]` — change to a journal template, capture flow, or vault convention. Only when in an Obsidian-vault-like context.
8. `[habit]` — observation only; no setup change proposed. Use sparingly. If there is no setup fix, the question is whether the line earns its place at all.

Drop empty clusters. Do not list clusters with zero suggestions just to demonstrate coverage.

Make at most one suggestion per target file or skill. If several observations point at the same target, merge them into one suggestion and cite all the evidence.

### 4. Write the output

See the format below. Cluster order follows the priority list above; within a cluster, the strongest suggestion comes first. Each suggestion names the file or skill it would change, the lesson behind it, a one-sentence "what would change," and the evidence that triggered it. The lesson is the general rule the evidence points to, not a restatement of the incident.

End with one question: which cluster the user wants to act on, or whether to discard the suggestions. Do not propose edits; do not call any tool that mutates state; do not write the suggestions to a file.

## Output

```markdown
**Setup review — N candidates.**

- `[cluster]` Lesson — concrete proposal naming the target — _evidence: <quote, message number, or doc reference>_.
- `[cluster]` Lesson — ...

**No files written. Nothing was changed.** Which cluster would you like to act on (or discard)?
```

When nothing clears the threshold, the whole output is:

```markdown
**Setup review — nothing worth changing.** <One sentence on what was checked.> No files written.
```

- One BLUF line with the count. No preamble.
- One bullet per suggestion, cluster tag first, then the lesson, then the proposal, evidence italicized at the end.
- Strongest suggestion first inside each cluster.
- Close with the read-only reminder and the single open question.

### Worked example

Suppose the user runs the skill after a session where they corrected "use BLUF" three times, re-ran a four-step `find → read → summarize → file` workflow twice, corrected a status table from a loaded `status-report` skill once because its rows had no titles, and the project has no `CONTEXT.md`.

```markdown
**Setup review — 4 candidates.**

- `[context file]` Summaries here lead with the answer — add a `CONTEXT.md` at the repo root with the BLUF rule and the project's tone defaults — _evidence: correction restated in turns 4, 11, 17_.
- `[update skill]` A status and a next step do not identify the work — add a required title field to the table in `~/.dotfiles/skills/status-report/SKILL.md` — _evidence: "which PR is this row?" in turn 6_.
- `[new skill]` The find → read → summarize → file flow is a repeatable procedure — create `~/.dotfiles/skills/find-summarize/SKILL.md` wrapping it — _evidence: same workflow re-ran in turns 9 and 14_.
- `[habit]` "Be brief" came up four times in this session — consider whether a session-start prompt would carry it.

**No files written. Nothing was changed.** Which cluster would you like to act on (or discard)?
```

## Pitfalls

- **Writing files "to be helpful."** No logs, no notes, no draft diffs. Read-only is the design, not a side effect.
- **Treating one-offs as patterns.** A single correction can justify updating existing text, but never creating a new skill or file. New things need two independent occurrences.
- **Proposing a new skill when an existing one covers it.** Check the skills list first; an update is cheaper to review and does not split the trigger.
- **Suggesting an edit to a skill without reading it.** The fix may already be in the skill and was ignored, which is a different problem from a missing rule.
- **Pointing at symlinked home-directory paths.** Skills and harness config live in the dotfiles repo and are linked into place. Name the source file there.
- **Scanning beyond the active context.** The home-dir vault, sibling repos, and unrelated Obsidian folders are out of scope unless they are the CWD.
- **Proposing changes to secrets, auth, or network egress.** Those need explicit review outside this skill; the setup review surfaces ideas, the user vets them.
- **Generic advice ("be more organized").** Every suggestion names the file or skill it would change and the evidence that triggered it. Unfalsifiable suggestions are cut.
- **Auto-running.** The skill is opt-in. If the user did not invoke it, it does not run.
- **Listing clusters with zero items.** Empty clusters pad the output without informing the user. Drop them.
- **Skipping the evidence.** A suggestion without "you said this N times" or "this was the 3rd re-run" is not useful — the user cannot tell whether the agent is reading the session correctly.
- **Touching any tool that mutates state.** No `write`, no `edit`, no `git commit`, no installs, no `link.sh`. If a tool could change a file, do not call it from this skill.

## Related skills

- **repo-architecture** — for "the code is shallow / find seams." Different domain; the same read-only discipline applies.
- **peer-clarify** — after picking a cluster to act on, run peer-clarify to pressure-test the change before touching files.
- **obsidian** — only relevant when the active context is an Obsidian vault; helps scope the working-directory scan.
