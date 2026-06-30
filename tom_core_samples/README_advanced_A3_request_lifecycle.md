# Appendix A3 · A secured request, end to end

*Appendix A3 of the Tom Core advanced-sample user guide — see the [guide index](README_advanced_sample.md#user-guide).*

> **Status: skeleton.** Content to be written in **RC-18**. This file currently
> provides the section structure and navigation only. Companion to
> [10 · Servers & the secured endpoint pipeline](README_advanced_10_servers_endpoints.md).
> This appendix is *synthesized* from the endpoint, access, and client-http
> sources — it traces a single request rather than transcribing one document.

## What this appendix covers

One end-user request traced across both tiers: login at the auth server → token
→ app-server bearer validation → ownership/share resolution → field-grade
computation → graded DTO → client field rendering.

## 1. Login at the auth server → token

_TODO(RC-18)._

## 2. App-server bearer validation

_TODO(RC-18)._

## 3. Ownership / share resolution

_TODO(RC-18)._

## 4. Field-grade computation

_TODO(RC-18)._

## 5. Graded DTO over the wire

_TODO(RC-18)._

## 6. Client field rendering

_TODO(RC-18)._

## Primary sources

- `*/endpoints/*`; `app_server/src/access/*`; the client http layer
- `advanced_example_specification_plan.md` — A.5, A.6, Phase 7
- `run_cross_tier_integration.sh` (the same loop, executed live)

---

← Prev: [A2 · Scope, basePath & resource-key conventions](README_advanced_A2_resource_scope_conventions.md) · Next: [A4 · Implementation-rules cheat-sheet](README_advanced_A4_implementation_rules_checklist.md) →
