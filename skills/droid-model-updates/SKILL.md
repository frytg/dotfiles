---
name: droid-model-updates
description: >-
  Configure, test, and rotate custom LLM models in the Droid (Factory) agent.
  Validates customModels entries against the current settings schema, sets
  credential strategy (apiKeyHelper vs static apiKey), configures context
  and token limits, and stages the change in `factory/settings.json` for
  commit. Use when the user asks to add, update, remove, or test a
  model in Droid, to change the default model, to rotate credentials,
  or says "update model", "add new model", "change LLM config", or
  "model rotation".
license: MIT
metadata:
  author: frytg
  agent: pi
  category: engineering
---

# Droid Model Updates

A custom model entry in `~/.factory/settings.json` is a JSON object in the
`customModels` array. Each entry defines something Droid can call: identity,
endpoint, credentials, and capacity limits. The settings file is tracked in
the dotfiles repo under `factory/settings.json` and linked into `~/.factory/`
by `bin/link.sh`.

Editing this file changes which models appear in the `/model` selector. A
bad entry does not crash Droid — it surfaces on first use when the user
selects that model.

## When to use

- Adding a new model to Droid's custom model list.
- Updating an existing model's endpoint, credentials, or limits.
- Removing a deprecated model.
- Rotating model credentials.
- Verifying that a model entry fits the current schema and compaction
  limits.
- The user says "add a model", "update model config", "change default
  model", or "model rotation".

## Not for

- Changing Droid's global settings unrelated to models (theme, sounds,
  interaction mode). Those are separate top-level keys.
- General provider API documentation or model selection advice without
  the intent to wire a model into Droid.

## Config field reference

Every entry in `customModels` uses these keys. Omitted fields keep their
defaults; unsupported fields are silently ignored.

| Field              | Required | Type    | Purpose                                                      |
| ------------------ | -------- | ------- | ------------------------------------------------------------ |
| `model`            | yes      | string  | Internal ID used as the selection key in `/model`. Must be   |
|                    |          |         | unique across all entries.                                   |
| `displayName`      | yes      | string  | Human-readable label shown in the model picker.              |
| `baseUrl`          | yes      | string  | OpenAI-compatible chat completions endpoint (with `/v1` or   |
|                    |          |         | equivalent path).                                            |
| `provider`         | yes      | string  | Provider identifier. Use `generic-chat-completion-api` for   |
|                    |          |         | OpenAI-compatible endpoints.                                 |
| `apiKey`           | no       | string  | Static API key. Prefer `apiKeyHelper` instead.               |
| `apiKeyHelper`     | no       | string  | Shell command that returns the API key at call time.         |
| `maxOutputTokens`  | no       | number  | Hard cap on response tokens.                                 |
| `maxContextLimit`  | no       | number  | Upper bound for context window. Must be >= compaction limit. |
| `reasoningEffort`  | no       | string  | Override reasoning depth: `none`, `low`, `medium`, `high`.   |
| `extendedThinking` | no       | object  | Enable extended thinking mode settings.                      |
| `baseModelId`      | no       | string  | Underlying base model for routing hints.                     |
| `autoModel`        | no       | boolean | Whether auto-selection may route to this model.              |
| `noImageSupport`   | no       | boolean | Set `true` if the model cannot process images.               |
| `extraArgs`        | no       | object  | Additional request parameters forwarded to the provider.     |
| `extraHeaders`     | no       | object  | Headers injected on every request.                           |

## Workflow

### 1. Assess the provider

Identify the provider, endpoint format, and auth method. Confirm the
endpoint serves an OpenAI-compatible `chat/completions` API. If it does
not, stop — Droid requires a compatible endpoint.

Read provider docs for known limits: max context window, max output tokens,
image support, and reasoning capabilities. These determine
`maxContextLimit`, `maxOutputTokens`, and optional flags.

### 2. Choose credential strategy

Prefer `apiKeyHelper` over `apiKey` for every entry.

- **`apiKeyHelper`** — shell command executed at call time. The command runs
  in a sandboxed subprocess. Typical patterns:
  - 1Password: `op read 'op://A-Team/ServiceName/credential'`
  - Dotonial vault: `sops exec-env <file> 'printenv SECRET_KEY'`
- CLI secrets: `secret-tool lookup ...`
- Test with the command directly: `eval "<command>"` and verify it
  outputs exactly the key, no extra text or newlines.
- **`apiKey`** — static string stored in the settings file. Only use
  when no helper is available and the user confirms the trade-off.
  Never paste a real key into chat; the user types it into the file.

If neither `apiKey` nor `apiKeyHelper` is set, Droid uses its own auth.
This works for Auto routing and local models but not for third-party
endpoints.

### 3. Draft the entry

Create the JSON object under `customModels`. Pick a unique `model` ID
(kebab-case, readable) and a `displayName` that identifies provider and
model size.

Set `maxContextLimit` to the provider's documented context window or a
conservative estimate if undocumented. **The compaction limit defaults to
250,000 tokens in Droid.** `maxContextLimit` must be at least 250,000 or
compaction will truncate context early. Exceptional models with smaller
windows can use a lower value; note that long sessions will be more
expensive or shorter as a result.

Set `maxOutputTokens` to a realistic cap (4096–8192 for most models).
Higher values consume tokens; lower values cut short long answers.

Mark `noImageSupport: true` if the model lacks vision input.

Example:

```json
{
	"model": "provider/acme-model-xl",
	"displayName": "Acme XL (Falcon)",
	"baseUrl": "https://api.example.com/v1",
	"provider": "generic-chat-completion-api",
	"apiKeyHelper": "op read 'op://A-Team/Falcon Proxy/credential'",
	"maxOutputTokens": 8192,
	"maxContextLimit": 24000,
	"noImageSupport": true
}
```

Edit only `factory/settings.json` in the repo. The file is linked into
`~/.factory/settings.json` by `bin/link.sh`. Never edit the target file
directly.

### 4. Validate the entry

Reload Droid's settings. In the desktop chat, type `/model` and confirm
the new entry appears with the correct display name.

If available, run `just lint` to check JSON syntax and trailing commas.
A malformed file will not load on the next Droid startup.

### 5. Test the model

Select the new model with `/model` and send a short prompt. Verify:

- Response is returned without error.
- Token usage roughly matches expectations.
- `noImageSupport` is correct (try an image prompt if applicable).

If the call fails, check:

- The `apiKeyHelper` command outputs a valid key (run it in a shell).
- The `baseUrl` is reachable and returns valid JSON.
- The provider is spelled correctly.

Fix the entry, then retest. Stop if the endpoint returns permament errors
or the provider changes its contract; ask the user for an alternative or
updated docs.

### 6. Stage and commit

Once tested, stage `factory/settings.json` with the repository's normal
git workflow. Use `factory/settings.json` and sync it to the session.
Commit with a conventional message:

```
feat(settings): add provider/acme-model-xl to customModels
feat(settings): add provider/acme-model-xl to customModels
```

Run `just link` after any skill additions so the harness picks them up.

## When to keep Auto vs. set a custom default

- **Auto** — Droid picks a context length, reasoning depth, cost, and
  capability. Use for general work.
- **Custom default** — Use when the user explicitly wants a specific
  model for the session. Change `sessionDefaultSettings.model` from
  `"auto"` to the model ID. This overrides picker for new sessions;
  the user can still switch per-session with `/model`.

If the user asks which model to default to, recommend Auto unless the
task benefits from a particular model's strengths.

## Check list

1. Endpoint is OpenAI-compatible?
2. Credential strategy is `apiKeyHelper`, not `apiKey`?
3. `maxContextLimit` >= 250000 (compaction default)?
4. `maxOutputTokens` set to a reasonable cap?
5. `noImageSupport` marked if applicable?
6. Entry appears in `/model` picker?
7. Short test prompt succeeds?
8. `factory/settings.json` edited, not `~/.factory/settings.json`?
