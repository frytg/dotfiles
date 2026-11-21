---
name: compare-ai-model
description: >-
  Research one or more named AI models and write a brief BLUF overview in the user's voice: what each model is good
  at, what it costs, how fast it is, and which one to pick for the stated job. Pulls live numbers from Vals AI
  (index and comparison), OpenRouter (pricing, context, modalities), Arena (agent leaderboard), Artificial Analysis
  (intelligence, speed, price), and the vendor's release post, then cites every number with its source and date.
  Use when the user asks to "compare models", "compare X vs Y", "how good is model X?", "is X better than Y?",
  "which model should I use for Z?", "what's the deal with the new X?", "model overview", "model check", or names a
  model and asks about its benchmarks, price, speed, or context window. Not for configuring a model in a harness
  (use droid-model-updates).
license: MIT
metadata:
  author: frytg
  agent: claude-code
  category: engineering
---

# Compare AI models

A model comparison is a pick, not a spec sheet. The output names the model to use for the stated job, the number that
decides it, and the condition that would flip the call. Everything else is supporting evidence with a source link.

Model facts go stale within weeks. Never answer from memory: every number in the output comes from a page fetched in
this run.

## When to use

- The user names one model and wants to know whether it is worth using.
- The user names two or more models and wants a pick.
- The user names a job ("agentic coding", "cheap bulk extraction", "audio input") and wants candidates compared.
- A new model was released and the user wants the short version of the launch.

## Not for

- Adding or rotating a model in a harness config (use `droid-model-updates`).
- Running your own benchmark or eval. This skill reads published results only.

## Workflow

### 1. Pin down the models and the job

1. Resolve each name to an exact model ID, including the variant: version, size tier, and reasoning or thinking
   level. `Acme Large 4` and `Acme Large 4 (high reasoning)` score and cost differently, so they are different rows.
2. If a name matches several current variants, pick the newest generally available one and say which one you picked.
   Ask only when the variants differ enough to change the answer, such as a preview and a stable release.
3. Take the job from the request or the conversation. If none is stated, compare on general capability, price, and
   speed, and say so in the output.
4. If only one model is named, add its direct predecessor and the closest competitor at a similar price as baselines.
   A score without a baseline tells the reader nothing.
5. Cap the comparison at four models. With more, shortlist first and name the ones you dropped.

### 2. Collect from the sources

Fetch the sources in parallel. Each one answers a different question, so use each for its strength and do not
average across them.

- **OpenRouter** for price, context window, max output, modalities, and supported parameters. The JSON API is public
  and needs no key: `https://openrouter.ai/api/v1/models`. Filter by `id`. Prices are USD per token, so multiply by
  1,000,000 before reporting. `https://openrouter.ai/<model-id>` shows providers, uptime, and throughput.
- **Vals AI** for task-level accuracy on domain benchmarks (finance, legal, coding, and others), with cost and latency
  per test. Index: `https://www.vals.ai/benchmarks/vals_index`. Side by side:
  `https://www.vals.ai/comparison`.
- **Artificial Analysis** for the intelligence index, output speed in tokens per second, time to first token, and
  blended price. Start at `https://artificialanalysis.ai/leaderboards/models`, then open the model page.
- **Arena** for human-preference and agent rankings: `https://arena.ai/leaderboard/agent`. The site blocks plain HTTP
  clients, so use a rendering fetcher (Firecrawl) or a real browser (`agent-browser`).
- **Vendor release post and model card** for release date, knowledge cutoff, the intended use, and known limits.
  Vendor benchmark tables are marketing. Use them only when no independent source has the number, and label them
  "vendor-reported".
- **Anything else that fits the job**, such as a benchmark's own leaderboard for a coding or agent task. Use it when
  the job needs it, and cite it the same way.

Rules for collecting:

1. Record the source URL and the date you fetched it with every number.
2. These pages render client-side. If a plain fetch returns a shell without data, use Firecrawl or `agent-browser`
   instead of guessing from the page skeleton.
3. If a source has no entry for a model, write "not listed" for that source. New models often take days to appear.
   Do not substitute a sibling variant's number.
4. If a source is unreachable after one retry with a different fetcher, skip it and name it under "Gaps".
5. If fewer than two independent sources have data for a model, say so in the BLUF. The comparison is then
   provisional.

### 3. Reconcile

1. Compare like with like: same variant, same reasoning level, same benchmark version. If the sources tested
   different settings, say which setting each number belongs to.
2. When two sources disagree on a ranking, report both and name the likely reason (different task mix, different
   reasoning level, different date). Do not pick the one that fits the conclusion.
3. Treat gaps smaller than the benchmark's stated error margin as a tie. If no margin is stated, treat a gap under
   two points as a tie.
4. Compute the cost of the stated job, not just the list price. A model with a low token price and heavy reasoning
   output can cost more per task than a pricier one. Use per-task cost from Vals AI or Artificial Analysis when
   available.
5. Check the hard constraints before the scores: context window, required modality, tool calling, structured output,
   and availability on the provider the user uses. A model that fails a hard constraint is out, whatever it scores.

### 4. Write the overview

Apply the `bluf` skill for structure and the `my-voice` skill for tone. Where they conflict, `bluf` wins on
structure and `my-voice` wins on wording. Keep model IDs, numbers, and links exact.

```markdown
# [The pick, in 3-7 words]

**BLUF:** [Which model for which job, and the number that decides it.] [Price and speed tradeoff in one sentence.]
[What would flip the call.]

## Numbers

- **<model-a>**: <score> on <benchmark> ([source](url)); $<in>/$<out> per 1M tokens; <tps> tokens/s; <context> context
- **<model-b>**: ...

## Where each one wins

- **<model-a>**: <job or trait>, because <mechanism or evidence>
- **<model-b>**: ...

## Watch out

- <hard constraint, known weakness, preview status, or source disagreement>

## Gaps

- <source that had no data or could not be reached>

Sources fetched <YYYY-MM-DD>: [OpenRouter](url) · [Vals AI](url) · [Artificial Analysis](url) · [Arena](url) ·
[release post](url)
```

Format rules:

1. Target 150 to 300 words. Go to 400 only with three or four models.
2. Use the same fields in the same order for every model under "Numbers", so the lines scan as a column.
3. Use a table only when the user asks for one or when four models are compared across four or more metrics.
4. Drop "Watch out" or "Gaps" when it would be empty.
5. With a single model, the title and BLUF answer "worth using or not, and for what" against the baselines.
6. Present the overview in chat. Do not save or publish it unless the user asks.

## Checklist

- Every number has a source link and comes from this run.
- Variant and reasoning level are named for every model.
- The BLUF names a pick, the deciding number, and the flip condition.
- Vendor-reported numbers are labeled as such.
- Missing or unreachable sources are listed, not papered over.
