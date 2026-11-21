---
name: test-cleanup
description: >-
  Prune tests that guard no behavior: delete or rewrite every test that depends on the past (asserts removed code stays
  gone), on nothing (cannot fail), on the implementation (breaks on refactors that keep behavior), or on a behavior
  another test already guards. Classifies each test by what it depends on, removes production code that existed only
  for the pruned tests, runs the suite, and reports what was deleted, rewritten, and kept as uncertain. Edits the
  working tree only and never commits. Use when the user asks to "prune tests", "clean up the tests", "remove useless
  tests", "delete redundant tests", "trim the test suite", "which tests are worth keeping?", or says the tests break on
  every refactor. Not for finding defects in a diff (use code-review) or for adding missing coverage.
license: MIT
metadata:
  author: frytg
  agent: claude-code
  category: engineering
  inspirations:
    - caldoai/skills prune-tests
---

# Test cleanup

The output is a smaller test suite in which **every remaining test is anchored to intended behavior**: it changes only
when that behavior changes, and it fails only when that behavior regresses. Each pruned test comes with a one-line
reason. A run that prunes nothing is a valid result.

The test for a test is one question: **what would have to change for this test to fail?** If the answer is "a
regression in something a caller relies on", keep it. Any other answer is a reason to prune.

## When to use

- The user asks to prune, trim, or clean up tests, for the whole suite or a given path.
- Tests break on refactors that did not change behavior.
- A feature was removed or moved and its tests were inverted instead of deleted.
- A suite grew through generated or copy-pasted tests and nobody trusts a green run.

## Not for

- Reviewing a diff for defects. Use code-review.
- Adding coverage for untested behavior. Note the gap in the report and leave it.
- Fixing flaky tests. A flaky test that guards real behavior stays; report it.
- Speeding up a slow suite. Runtime is not a reason to prune.

## Workflow

### 1. Set the scope

Use the path the user gave. With no path, use the test files touched on the current branch. If the branch touches no
test files, ask whether to cover the whole suite and stop.

Find the command that runs the tests (`justfile`, then the project's runner config). Run it once before any edit and
record the result. If the suite already fails, say which tests fail and ask whether to continue; do not prune on top of
an unknown baseline.

### 2. Classify each test by what it depends on

Read each test together with the code it exercises. Do not classify from the test name. Give every test exactly one
label.

- `behavior` — it depends on something a caller or user relies on. Keep.
- `duplicate` — another test already guards the same behavior through the same path. Keep the clearer one, prune the
  copy. Two tests that reach the same behavior through different inputs or boundaries are not duplicates.
- `past` — it asserts that removed code stays gone. Bringing that code back would be a decision, not a regression.
  - A feature was removed and a test asserts it is absent.
  - A module moved and a test asserts the old path does not exist.
- `nothing` — no change to the project's code can make it fail.
  - It tests the platform: an element renders, an event fires, a standard-library call returns.
  - It mocks the unit under test and asserts what the mock returns.
  - It asserts what the type system already guarantees.
- `implementation` — it changes whenever the code does, even when behavior did not.
  - The expected value is computed with the same logic as the code, so a wrong result still passes.
  - It asserts private state, internal call order, or which helper was invoked.
- `uncertain` — the intended behavior cannot be determined from the code, docs, or history. Keep, and list it in the
  report.

When a label is not obvious, check it: break the behavior in a scratch edit and see whether the test fails, then revert
the edit. A test that still passes is `nothing`. Do not ask the user for anything the environment can answer.

### 3. Prune

1. Delete every `past`, `nothing`, and `duplicate` test.
2. For each `implementation` test, check whether it also covers behavior something relies on. If it does, rewrite it
   against that behavior: literal expected values, public interface only. If it does not, delete it.
3. Delete what the removed tests leave behind: unused fixtures, helpers, mocks, snapshots, and imports.
4. Delete production code that existed only for the removed tests, such as test-only exports, reset hooks, and
   accessors for private state. Confirm with a search that nothing else references it first.
5. Remove a test file that is now empty.

Leave `behavior` tests alone, including their style and naming. This is not a refactor.

### 4. Verify

Run the suite and the linter again. Every remaining test must pass. If a rewritten test fails, the rewrite found either
a wrong expectation or a real defect: report it with the failing output and do not adjust the assertion until it is
green without knowing which.

Do not commit. Leave the changes in the working tree for review.

## Output

```markdown
**Pruned N of M tests in <scope>.** Suite: passing | failing (details below).

**Deleted**

- `path/to/file.test.ts` "test name" — past | nothing | duplicate of "other test" — one-line reason.

**Rewritten**

- `path/to/file.test.ts` "test name" — what it asserted before, what it asserts now.

**Production code removed**

- `path/to/file.ts` `symbolName` — only referenced by the deleted test.

**Kept as uncertain**

- `path/to/file.test.ts` "test name" — what is unclear about the intended behavior.

**Coverage gaps noticed**

- Behavior with no test left guarding it.
```

Drop sections that are empty.

## Done when

- Every remaining test is anchored to intended behavior.
- Each one would fail on a regression, and only on a regression.
- No test asserts the absence of code that no longer exists.
- No two tests guard the same behavior through the same path.
- No production code exists only for tests.
- The suite and the linter pass, or the report says exactly what fails.

## Pitfalls

- **Pruning by name or size.** A short test with a dull name can be the only guard on a behavior. Read the code it
  exercises.
- **Calling boundary cases duplicates.** Empty input, limits, and error paths are separate behaviors.
- **Deleting a regression test for a fixed bug.** It guards behavior, even when it looks oddly specific. Check the
  history before labelling it `implementation`.
- **Rewriting toward a guess.** If the correct expected value is not known, the test is `uncertain`, not rewritable.
- **Leaving orphans.** A deleted test whose fixture, snapshot, or test-only export survives is half pruned.
- **Chasing a coverage number.** Coverage will drop when `nothing` tests go. That drop is the honest figure.

## Related skills

- **code-review** — run it after pruning to check the diff, or when the goal is defects and not test value.
- **repo-architecture** — when tests can only reach behavior through private state, the module seam is the finding.
