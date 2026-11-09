---
name: home-assistant
description: >-
  Read Home Assistant entity states and perform user-requested device actions through its REST API. Resolves the base
  URL and bearer token from the specified 1Password fields with `op read`. Use when the user asks to check Home
  Assistant, inspect a device or entity, control a device, or run a scene.
license: MIT
metadata:
  author: frytg
  agent: factory
  category: engineering
  tags:
    - home automation
---

# Home Assistant

Home Assistant requests use its REST API. Read only the state needed to answer the user, and perform only actions the
user requested. Keep the base URL and API token private.

## When to use

- The user asks for the current state of a Home Assistant entity or device.
- The user asks to control a device or activate a scene through Home Assistant.
- The user asks whether a requested Home Assistant action succeeded.

## Workflow

1. **Resolve credentials securely.** The 1Password references are:

   - Base URL: `op://Agentic/Home Assistant API Key/hostname`
   - API token: `op://Agentic/Home Assistant API Key/credential`

   Use `op read` to capture each value inside the same non-interactive process that makes the request. Pass them as
   environment variables to a standard-library HTTP client, not as command-line arguments. Never print the values,
   enable shell tracing, save them to a file, or include them in logs or the final response. If `op` is unavailable,
   access is denied, or either value is empty, stop and tell the user which reference could not be read.

2. **Check the base URL.** Use the hostname value as configured. It must be an absolute `http://` or `https://` URL;
   don't guess a scheme, port, or alternate host. If it is incomplete, ask the user. Keep TLS certificate validation
   enabled. If the request fails, report the status without showing request headers or credentials.

3. **Check the API.** Send `GET /api/` with `Authorization: Bearer <token>` and confirm the response is
   `{"message":"API running."}`. Use a short timeout. Do not retry a failed action automatically.

4. **Find the requested entity or service.**

   - Use `GET /api/states` to find entities or `GET /api/states/<entity_id>` to read one known entity.
   - Use `GET /api/services` to check available services.
   - Match the user's requested device against the entity's `entity_id` and `friendly_name`. If there is no match or
     more than one plausible match, ask which one they mean.
   - Filter broad results locally and return only the requested state. Do not dump all entity states.
   - Don't request `/api/config` unless the user specifically asks for configuration details; it includes location and
     other potentially sensitive values.

5. **Perform a requested action.** Call
   `POST /api/services/<domain>/<service>` with a JSON body for the selected entity, for example
   `{"entity_id":"light.example"}` for a light service. Confirm the entity, service, and payload match the user's
   request. Ask before an action with physical-access or safety impact if the user did not explicitly request that
   exact action. Never use `POST /api/states/<entity_id>` to control a device; it changes Home Assistant's displayed
   state only, not the device.

6. **Verify and report.** After a successful service call, check the returned changed states or read the entity again
   when needed. If a POST times out, inspect the entity state before considering another call because the first action
   may have succeeded. Report the observed result; don't claim success based only on sending the request.

## API request handling

Use an HTTP client in the same process that reads the 1Password values. Build requests only for the configured base
URL and the documented `/api/` paths. Send JSON for service calls, set a timeout, and keep the token in the
`Authorization` header. Do not print headers, the token, or full unfiltered responses.

Home Assistant REST API reference: <https://developers.home-assistant.io/docs/api/rest/>

## Failure handling

- `401`: stop; report that authentication failed without exposing the token.
- `403`: stop; report that the account lacks permission. Don't attempt privilege escalation.
- `404`: verify the entity or service using the API, then ask if it remains ambiguous.
- Network, TLS, or server errors: report the status and stop. Never disable TLS verification or retry an action blindly.

## Reply

State the entity or device, the observed state or action result, and any error that blocked the request. Never include
the API token or its 1Password contents.
