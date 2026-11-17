---
name: first-principles
description: >-
  Re-evaluate the current task, its trajectory, or the whole project from first principles: restate the real goal,
  strip inherited assumptions, design what would be built from scratch with today's knowledge, and compare that to the
  current path. Picks the scope (task, trajectory, or project) from context and ends with a keep / adjust / restart
  verdict before any change is made. Use when the user says "first principles", "step back", "rethink this", "are we
  on the right track?", "is this still the right approach?", "sanity-check the direction", "would we build it this way
  from scratch?", when a new requirement is being bolted onto an existing design, or when a task keeps accumulating
  workarounds. Not for clarifying an unformed plan (use peer-clarify) or finding shallow modules (use
  repo-architecture).
license: MIT
metadata:
  author: frytg
  agent: claude-code
  category: productivity
  inspirations:
    - cursor/plugins pstack principle-redesign-from-first-principles
---

# First principles

A first-principles check is a verdict on the current path, not a second plan. It answers one question: **knowing what
we know now, would we start down this path today?** The output is a short comparison between the from-scratch design
and the current one, a verdict of `keep`, `adjust`, or `restart`, and the smallest set of moves that gets from here to
there. Nothing changes until the user confirms the verdict.

The core move comes from redesigning instead of bolting on: treat every requirement learned so far as if it had been a
founding assumption, then ask what that design looks like. The gap between that design and the current one is the
finding.

## When to use

- The user asks for it: "first principles", "step back", "rethink this", "are we on the right track?".
- A new requirement arrived and the obvious move is to bolt it onto the existing design.
- The task is accumulating workarounds: a third special case, a second retry of the same fix, a growing list of
  exceptions.
- The original plan was made before a fact that is now known (a constraint, a failed attempt, a changed goal).
- Before a costly or hard-to-reverse step, when the direction has not been questioned since the start.

## Not for

- A plan that does not exist yet. Use peer-clarify to form it first.
- Finding shallow modules or seams in a codebase. Use repo-architecture.
- Reviewing a diff for defects. Use code-review.
- Small, well-scoped tasks that are going fine. A check that costs more than the remaining work is waste.

## Workflow

### 1. Pick the scope from context

Choose one. Say which one and why in a single line, so the user can redirect before the analysis.

- **Task** — a task is active and the question is about its approach. The default when work is in progress.
- **Trajectory** — the session has drifted: several corrections, pivots, or workarounds since the original ask.
  Evaluate the path taken, not only the current step.
- **Project** — no task is active, the user names the project or its design, or the trouble in the task traces back
  to a project-level decision.

Escalate one level only when the evidence points there. If a task-level check finds that the cause sits in the project
design, say so and ask before widening. If the context supports no scope (no task, no project files, no stated goal),
ask the user what to evaluate and stop.

### 2. Read before judging

Read what the chosen scope rests on. Do not evaluate from memory of the conversation alone.

- **Task / trajectory:** the original request, every later correction, the files touched so far, and the files those
  depend on.
- **Project:** `README.md`, `AGENTS.md`, the entry points, the main config, and recent history (`git log` for the
  last weeks) to see where effort actually went.

Look facts up. Do not ask the user for anything the environment can answer.

### 3. Restate the goal without the solution

Write the goal as an outcome, with no reference to the current approach. "Users see fresh prices within a minute" is
a goal. "Fix the cache invalidation job" is a solution wearing a goal's clothes.

Then list what is truly fixed:

- **Hard constraints** — facts that hold no matter the design (a deadline, an external API, a compatibility promise).
- **Requirements learned along the way** — everything discovered since the start. These are the ones the original
  design did not account for.

If the goal cannot be stated without naming the solution, that is the first finding. Ask the user for the outcome
they need and stop.

### 4. Sort the assumptions

List the assumptions the current path depends on. Mark each one:

- `fact` — verified in the environment or stated by the user.
- `choice` — a decision that was made and could be made differently.
- `inherited` — carried over from the existing design, an earlier attempt, or habit, and never checked.

Verify the cheap ones now. The `inherited` ones are where the current path most often diverges from the from-scratch
one. Keep the list to the assumptions that would change the design if false.

### 5. Design from scratch

Answer: **if this started today, with every constraint and learned requirement known from the start, what would be
built?** Describe that design in a few lines. Ignore the existing code and sunk effort for this step.

Keep it honest in both directions:

- Do not copy the current design and call it fresh. If the from-scratch design matches the current one, say so. That
  is a valid result.
- Do not invent a rewrite to justify the exercise. Novelty is not a finding.

### 6. Compare and price the gap

Set the from-scratch design next to the current path. For each difference, state what it costs to keep and what it
costs to close.

- Sunk effort is not an argument for keeping. Remaining cost and risk are.
- Migration cost is an argument. A better design that takes longer to reach than the problem is worth is the wrong
  call.
- Note what the current path does right. Those parts carry over.

### 7. Give the verdict

Pick one:

- `keep` — the current path matches the from-scratch design closely enough. Name the one thing to watch, then
  continue the work.
- `adjust` — the direction holds but specific parts must change. List them.
- `restart` — the foundation differs. Continuing adds cost that the new design discards.

For `adjust` and `restart`, give the path as increments: think through the whole redesign, then deliver it in steps
that each leave things working. Propagate the change through every reference (types, docs, examples, tests, rationale
sections), so no part still describes the old design.

Then stop. Do not edit, delete, or restructure anything until the user confirms. A `keep` verdict needs no
confirmation; report it and resume.

## Output

```markdown
**Verdict: keep | adjust | restart** — one sentence with the reason and its main caveat.

**Scope:** task | trajectory | project — why this scope.

**Goal:** the outcome, solution-free.

**Fixed:** hard constraints and requirements learned since the start.

**Assumptions:**

- `inherited` … — checked: holds / does not hold / unverified
- `choice` … — still the right call / would choose differently

**From scratch:** the design that would be built today, in a few lines.

**Gap:**

- Difference — cost to keep / cost to close.

**Moves:**

1. First increment — what it changes, what stays working.
2. …

Go ahead with these moves, or keep the current path?
```

- Verdict first. Everything after it is evidence.
- Drop sections that are empty. A `keep` verdict usually needs only the verdict, goal, and the one thing to watch.
- Length follows stakes: a task check fits in a short block, a project check earns the full form.

### Worked example

Scope: trajectory. The session began as "add CSV export to the Acme reports page" and has since added a second
format, a size limit, and two workarounds for timeouts.

```markdown
**Verdict: adjust** — the export logic is sound, but it runs inside the request, and every problem since turn 3 comes
from that.

**Scope:** trajectory — three of the last four changes were workarounds for the same timeout.

**Goal:** a user gets a complete export of any report, in the format they pick, without waiting on a page.

**Fixed:** reports can exceed 500k rows (learned in turn 5). Two formats are required (turn 3).

**Assumptions:**

- `inherited` Exports are small enough to build in one request — checked: does not hold.
- `choice` One function per format — would choose differently: the formats share everything but the row writer.

**From scratch:** a background job streams rows through a format-specific writer to storage, and the page polls for a
download link.

**Gap:**

- In-request vs background job — keeping it means more timeout workarounds; closing it is one job and one endpoint.
- Duplicated format functions — cheap to merge once the writer interface exists.

**Moves:**

1. Extract the row writer interface. Both formats keep working in-request.
2. Move generation into a background job behind the same endpoint.
3. Remove the chunking and retry workarounds, and update the export docs.

Go ahead with these moves, or keep the current path?
```

## Pitfalls

- **Rewrite bias.** The exercise does not owe anyone a redesign. `keep` is a normal result.
- **Sunk-cost bias.** "We already built it" prices the past. Price the remaining work.
- **Solution-shaped goals.** If the goal names a component, it is not a goal yet.
- **Judging without reading.** A verdict from conversation memory alone repeats the assumptions it should test.
- **Widening scope without asking.** A task check that turns into a project critique was not requested.
- **Bolting on the fix.** An `adjust` that adds a layer on top of the old design, instead of changing it, repeats the
  original problem.
- **Partial propagation.** A redesign that leaves docs, types, or examples describing the old shape is half done.
- **Acting on the verdict unasked.** `adjust` and `restart` change direction. The user confirms first.
- **A second planning document.** The output lives in the chat. Do not write a plan file unless asked.

## Related skills

- **peer-clarify** — after a `restart` verdict, use it to settle the open decisions of the new design.
- **repo-architecture** — when a project-scope check points at module structure, it finds the specific seams.
- **self-improvement** — when the finding is about the setup, not the work.
