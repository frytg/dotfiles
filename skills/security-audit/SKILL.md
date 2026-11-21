---
name: security-audit
description: >-
  Audit codebases, APIs, services, CLI tools, libraries, and daemons for trust-boundary vulnerabilities and produce
  evidence-backed remediation guidance. Defaults to focused Q&A and targeted review; runs a multi-phase audit workflow
  only when asked for a full audit. Use when the user asks for a "security audit", "security review", "pen test",
  "vulnerability research", "threat model", or wants focused security triage on a codebase or component.
license: MIT
metadata:
  author: cloudflare
  category: engineering
  inspiration: https://github.com/cloudflare/security-audit-skill/tree/main/skills/security-audit
---

# Security audit

A security audit produces source-grounded findings tied to real trust boundaries, with minimal local reproduction steps, calibrated severity, and the smallest effective source fix. A candidate without a concrete affected principal, resource, or security outcome is not a confirmed finding.

## Operating modes

This skill defaults to guidance mode. Loading it does not authorize a full multi-phase audit or report file creation.

- **Guidance mode (default):** For security questions, targeted reviews, triage, or investigating specific findings, apply only the relevant principles and checklists from `references/`. Do not write report files.
- **Full audit mode:** Run the full four-phase workflow only when the user explicitly asks to audit or pen-test a codebase, requests a full/comprehensive/end-to-end security review, or asks for report artifacts.

If the request is ambiguous between modes, ask one short clarifying question before creating files or starting a full audit.

## Core principles

### Require a trust boundary and result

For every candidate, name:

1. The lower-trust principal and starting capability.
2. The accepted input, action, state transition, or selector.
3. The intended control and crossed trust boundary.
4. The affected principal or resource and the observed or owner-observable result.

Never elevate a missing best practice, guessed deployment behavior, generic parser crash, or same-principal self-impact into a finding.

### Stay within source and bounded local evidence

Source inspection is read-only. Never edit target source during an audit, and never probe deployed endpoints, live accounts, production data, paid APIs, or shared services.

Run target-controlled builds, tests, fixtures, or local processes only when isolated (no external network, empty/minimal environment with dummy data and secrets, scratch-only writes, and tight time/resource limits). Stop as soon as the minimum boundary failure is established. If isolation is not available or the decisive fact lives outside source, record `needs_validation` with a safe local or owner-observed check instead of guessing.

### Separate certainty from severity

- **`confirmed`:** Complete source path plus bounded local proof (or source-deterministic proof with no missing runtime/deployment dependency) and concrete boundary impact.
- **`needs_validation`:** Source-grounded boundary hypothesis blocked on an unobserved deployment, proxy, IAM, identity, browser, or runtime fact. State the exact blocker and safe resolution plan. Never assign severity to `needs_validation`.
- **`rejected`:** Disproved by source, an existing control, missing impact, or an impossible prerequisite.

Calibrate `confirmed` severity by demonstrated impact (overall severity cannot exceed impact):

- **critical:** Unauthenticated code execution, full data-store access, or arbitrary account takeover.
- **high:** Full defeat of an explicit security control with real consequences (auth bypass, cross-tenant read/write, stored XSS affecting other users, authenticated RCE, unauthenticated remote stop of a shared service).
- **medium:** Real boundary violation with limited blast radius, uncommon preconditions, or narrow resource scope.
- **low:** Disclosure of non-secret internals or minimal gain requiring sustained effort.
- **informational:** Minimal-impact observation useful mainly as a prerequisite inside a larger finding.

### Recommend the smallest effective fix

Identify the invariant the code must enforce and the narrowest repo-relative change that enforces it at the last trusted decision point, paired with a regression test.

## Full audit workflow

Write audit outputs outside the target repo (default `~/security-audit/<repo-name>/run-<N>/`), or inside the target only when the user selects a git-ignored directory. Track scope (full vs. scoped paths/diff) and reviewed commit ref explicitly, and state when coverage is partial.

1. **Reconnaissance**
   - Map product purpose, principals, normal authority, and protected resources.
   - Inventory entry surfaces (HTTP, RPC/messaging, files/archives, CLI/env/config, plugins/CI, cloud/IAM, AI/MCP tools, local IPC), major data copies, and sinks.
   - Note offline build/test capabilities and which controls depend on unobserved deployment facts.
   - Select applicable checklists from [references/ATTACK-CLASSES.md](references/ATTACK-CLASSES.md) and the domain files below based on observed boundaries, not merely language or dependency names.
   - Summarize this map in `architecture.md` (aim for under 1,000 words) and build a coverage checklist of `surface × boundary × attack_class` units.

2. **Coverage-led hunting**
   - Work through each coverage unit systematically (using parallel read-only or isolated subagents when the harness supports them, keeping scopes disjoint).
   - Trace each input through parsing, identity, authorization, normalization, derived copies, and sinks. Check sibling, batch, retry, migration, rollback, cancellation, and error paths.
   - Test sad paths and disagreements (empty, zero, negative, overflow, duplicate, mixed encoding, stale/revoked state, concurrency, canonicalization mismatches).
   - Consolidate findings by root cause and record non-finding hardening observations separately.

3. **Independent verification**
   - Have a fresh pass or fresh subagent challenge every `confirmed` and `needs_validation` candidate against the actual source and minimum local checks.
   - Re-verify every cited `file:line`, trace order (`entrypoint` -> `propagation` -> `sink`), strongest existing control on the path, preconditions, severity vs. impact, and whether the proposed fix actually closes the invariant.
   - Demote any claim relying on an unobserved runtime/deployment assumption to `needs_validation`, and drop disproved claims.

4. **Target-neutral reporting**
   - Derive reports strictly from verified results; prose must never upgrade a verdict, severity, or impact.
   - **`REPORT.md`:** Scope, commit ref, partial-coverage disclaimers, posture summary, confirmed findings table and write-ups (trace, principal, native bounded repro, conditions, fix), separate `needs_validation` table (no severity), hardening notes, and coverage gaps.
   - **`FINDINGS-DETAIL.md`:** Complete trace, dummy principal/resource, target-native invocation or fixture, observed output, conditions, and fix/regression case for `medium`, `high`, and `critical` confirmed findings.
   - **`NEEDS-VALIDATION.md`:** Source trace, exact blocker, affected boundary, and bounded local or owner-observed verification plan for each unresolved lead.
   - A clean run with zero confirmed findings is valid; report coverage and remaining validation gaps honestly without inventing `low` filler.

## Reference checklists

Load `references/ATTACK-CLASSES.md` for general classes (injection, access control, file/resource handling, crypto/secrets, business logic, feature abuse, chained boundaries, wildcard, obvious exposures), plus only the domain files matching observed boundaries:

- [references/WEB-PROTOCOL-AND-AUTH.md](references/WEB-PROTOCOL-AND-AUTH.md) — HTTP parsing, proxies/CDNs, caching, sessions, CSRF, JWT, OAuth/OIDC, SAML, MFA, passkeys, recovery, API keys, mTLS.
- [references/CLIENT-SIDE.md](references/CLIENT-SIDE.md) — SPAs, DOM XSS, prototype pollution, `postMessage`, browser storage, CORS, WebSockets, extensions, webviews.
- [references/AI-AND-LLM.md](references/AI-AND-LLM.md) — prompt assembly, RAG/memory poisoning, tool-calling, action binding, MCP identity, model output sinks.
- [references/CLOUD-AND-DEPLOYMENT.md](references/CLOUD-AND-DEPLOYMENT.md) — IAM, IaC, containers/Kubernetes, service mesh, serverless/edge, ingress, workload identity.
- [references/DATA-ISOLATION-AND-LIFECYCLE.md](references/DATA-ISOLATION-AND-LIFECYCLE.md) — multi-tenant isolation, derived search/cache/analytics copies, exports, migrations, deletion/retention.
- [references/PROTOCOLS-RPC-AND-MESSAGING.md](references/PROTOCOLS-RPC-AND-MESSAGING.md) — gRPC, GraphQL, Protobuf/Thrift, custom protocols, queues, brokers, webhooks, streaming.
- [references/DESKTOP-MOBILE-AND-LOCAL-IPC.md](references/DESKTOP-MOBILE-AND-LOCAL-IPC.md) — native apps, deep links, webview bridges, privileged helpers, Unix sockets/XPC/Binder/D-Bus.
- [references/MEMORY-SAFETY-AND-BINARY.md](references/MEMORY-SAFETY-AND-BINARY.md) — C/C++/unsafe Rust, parsers, FFI, integer/ABI, concurrency, binary loaders, firmware.
- [references/RESOURCE-EXHAUSTION-AND-AVAILABILITY.md](references/RESOURCE-EXHAUSTION-AND-AVAILABILITY.md) — asymmetric CPU/memory/disk/connection/queue/quota exhaustion and operator-spend amplification.
- [references/SUPPLY-CHAIN-AND-RELEASE.md](references/SUPPLY-CHAIN-AND-RELEASE.md) — dependency resolution, build/CI pipelines, signing/promotion, updates, plugins, extensions.

## Anti-patterns

- Presenting checklist deviations or defense-in-depth suggestions as findings without a reachable boundary violation.
- Probing live or shared infrastructure, or running target code without isolation.
- Guessing proxy, provider, browser, IAM, or deployment behavior absent from source.
- Treating same-principal authority or self-impact as a cross-boundary defect.
- Assigning severity to `needs_validation` items, or reporting `low` filler on a clean target.
- Skipping independent verification before writing reports, or letting prose contradict verified evidence.
