# Introduction & how to read this guide

*Part 00 of the Tom Core advanced-sample user guide — see the [guide index](README_advanced_sample.md#user-guide).*

This guide teaches how to build a **full-scale, secured, full-stack application
on `tom_core`**, using the *advanced full-stack sample* as the worked example.
The sample is a small but technically complete task manager: three servers —
two serving HTTP, one running scheduled back-office work with no port of its
own — two databases, two Flutter clients, one shared reflected domain, one wire
contract, live four-state field authorization, and cross-user sharing. Every part of this
guide explains one cross-cutting concern of that system — and, just as
importantly, the **implementation rules** the framework imposes — then points at
the exact code that enforces it.

## What the sample is — and is not

The sample optimises for **complete framework coverage with deliberately limited
business logic**. There are only a handful of entities, a couple of forms, one
task board and one item editor — but *every technical concern of real
application creation is present*: reflection, wire contracts, two databases with
migrations, JWT authentication, four-state field authorization, server-delivered
text resources, bound reflected forms, a secured endpoint pipeline, and
cross-tier integration testing. Read it as a **reference skeleton**, not a
feature-rich product: when you build your own app you keep this technical
spine and grow the business logic.

It is the **secured, full-stack successor** to the basic
[`core_server_sample`](core_server_sample/README.md) /
[`core_client_sample`](core_client_sample/README.md) pair. Those teach one server
and one client in isolation, but they stop at a **read-only seam** — the server
is publicly accessible, and login plus writes are faked in-memory on the client.
This sample closes that gap end-to-end: real login, JWT issuance,
bearer-token-secured endpoints, a per-request principal, and per-resource and
per-field authorization.

Two pieces in this sample are its **headline deliverables** — capabilities no
other framework sample demonstrates:

1. **HTTP admin endpoints that *mutate* roles and the grant matrix** — the
   authorization-administration surface (`/admin/*`).
2. **An *authenticated* HTTP client** that presents and refreshes a bearer
   token — the shared `advanced_client_core`.

Two framework rules are made literal throughout, and the guide keeps returning
to them:

- **All UI texts are externalized into server-delivered resources**, keyed by a
  field's `basePath` — the client ships no UI strings. (Part
  [08](README_advanced_08_resources_texts.md), appendix
  [A2](README_advanced_A2_resource_scope_conventions.md).)
- **UI authorization is driven by scope/form/field names**, not hand-wired: the
  screen fetches each field's DB-resolved four-state grade (keyed by `basePath`)
  and stamps it onto the field with a per-field `TomAuthorizer.fixed`; there is
  no *per-field* installed adapter, and an unsent grade is closed-safe
  (`TomAuthState.none`). (Part [07](README_advanced_07_authorization.md),
  appendix [A1](README_advanced_A1_authorization_state_machine.md).)

## Who this guide is for

You are building (or evaluating) an application on the Tom Core stack and want a
complete, end-to-end worked example rather than isolated feature snippets. You
are comfortable with Dart and Flutter. You do **not** need prior Tom Core
experience — the guide introduces each concept where it is first used and
collects the vocabulary in the [glossary](README_advanced_A5_glossary_crossref.md) —
but if you have read the basic `core_*_sample` pair, this is the natural next
step.

## The ten packages at a glance

| # | Package | What it is | Runtime |
| --- | --- | --- | --- |
| 1 | [`advanced_todo_domain`](advanced_todo_domain/README.md) | The shared, reflected domain model — the single source of truth the whole stack agrees on. | library |
| 2 | [`advanced_todo_contracts`](advanced_todo_contracts/README.md) | The over-the-wire surface: DTOs + the typed service interfaces the servers implement and the clients call. | library |
| 3 | [`advanced_client_core`](advanced_client_core/README.md) | The Flutter-free authenticated HTTP layer shared by both clients — presents and refreshes the bearer token, parses JSON↔DTO, headless-testable. | library |
| 4 | [`advanced_auth_server`](advanced_auth_server/README.md) | JWT **authentication** issuer + role-gated **administration** API. The grant-mutating admin endpoints are a primary deliverable. | HTTP `:8081`, `auth_db` `:3307` |
| 5 | [`advanced_app_server`](advanced_app_server/README.md) | The secured task API. Trusts the shared JWT key, validates the bearer on every request, resolves ownership + shares + four-state field grades, persists `app_db`. | HTTP `:8080`, `app_db` `:3308` |
| 6 | [`advanced_app_client`](advanced_app_client/README.md) | The end-user Flutter app: login, a status-column board, a bound item editor with live per-field authorization, and cross-user sharing. | Flutter |
| 7 | [`advanced_authadmin_client`](advanced_authadmin_client/README.md) | The administrator Flutter console: manages users, roles, groups, assignments, and the `projectRole` × field grant matrix. | Flutter |
| 8 | [`advanced_ops_server`](advanced_ops_server/README.md) | Back-office scheduled work over `app_db` — retention purge, digest into the messaging outbox, weekly export, audit anchors. No HTTP surface, no database of its own. | timers, `app_db` `:3308` |
| 9 | [`advanced_openapi_client`](advanced_openapi_client/README.md) | Typed clients for both servers, generated from their OpenAPI documents by `tom_core_openapi` — `package:http` only, no Tom package. | library |
| 10 | [`advanced_audit_client`](advanced_audit_client/README.md) | The auditor's Flutter app over the framework's `/audit-reports` API: questions asked of the audit trail across its writers, saved, and delivered by email as exports. | Flutter |

Part [02](README_advanced_02_project_layout_build.md) shows how they depend on
one another and how to build and run them; part
[01](README_advanced_01_architecture.md) draws the architecture.

## The worked scenario in one sentence

An **administrator** edits the grant matrix in the admin console; that edit
reaches an **end-user's** field grades on their next request to the app server;
and when an owner **shares** a project, a second user sees it on theirs — the
exact cross-tier loop the [integration test](README_advanced_12_testing_integration.md)
asserts live. The sample seeds four accounts to exercise it: `admin` (manages
roles + grants), `alice` (owns the starter project, can share), and `bob` /
`carol` (an editor and a viewer on alice's project via seeded shares).

## How to read this guide

The guide is one long document split across navigable parts. Read the **spine**
top to bottom — each part ends with a **← Prev / Next →** footer, so you can walk
the whole thing in order:

> 00 Introduction → 01 Architecture → 02 Project layout & build →
> 03 Domain & reflection → 04 Wire contracts → 05 Persistence & databases →
> 06 Authentication → 07 Authorization → 08 Resources & texts → 09 Forms & UI →
> 10 Servers & endpoints → 11 Clients → 12 Testing & integration →
> 13 File transfer under the authorization matrix →
> 14 Operations: scheduled work over live data.

The last part is a **capstone**: rather than introducing a new layer, it follows
one feature — a task's file attachment — down through every layer the preceding
twelve introduced, from the three annotations on the field to the live cross-tier
assertion that an admin's grant edit takes the upload away from the row's owner.

The **appendices** are deep dives linked from the parts that need them (and from
the [index](README_advanced_sample.md#user-guide)). Branch into them when a part
points you there:

- [A1 · Four-state authorization](README_advanced_A1_authorization_state_machine.md) — the state machine behind part 07.
- [A2 · Scope, `basePath` & resource keys](README_advanced_A2_resource_scope_conventions.md) — the conventions behind parts 08 and 09.
- [A3 · A secured request, end to end](README_advanced_A3_request_lifecycle.md) — the full trace summarized in part 10.
- [A4 · Implementation-rules cheat-sheet](README_advanced_A4_implementation_rules_checklist.md) — every rule on one page, for when you build your own app.
- [A5 · Glossary & cross-reference](README_advanced_A5_glossary_crossref.md) — terms, and a map from each package README into the guide.

If you only want the rules (not the narrative), jump straight to
[A4](README_advanced_A4_implementation_rules_checklist.md) and follow its anchors
back into the relevant parts.

## Conventions used in this guide

- **Cite, don't duplicate.** Each package ships its own article-grade
  `README.md` with the depth. This guide explains the *cross-cutting concern and
  the rule*, then links the package README or the enforcing source file. It does
  not re-document a package's internals.
- **Every rule is grounded in code, by name.** Implementation rules name the
  live enforcement point (kernel / `tom_flutter_ui` / server) and a sample usage
  site, always as a **declaration you can search for** — a type, a member, a
  top-level function — with the file that holds it (e.g.
  `TomField.resolveEffectiveAuth` in `tom_form.dart`), so you can verify them.
  Deliberately **never a line number**: a line moves on the next edit to a file
  nobody reading this guide has open, and the citation then points at unrelated
  code while still reading plausibly. A name survives that edit, and
  `tool/check_source_citations.py` keeps line anchors out of these guides the
  same way it keeps them out of the source.
- **`basePath` notation.** A field's `basePath` is written
  `<scopePath>.<formId>.<tomId>` (e.g. `todo.item.title`). The same path is used
  two ways — as the authorization key, and (with a suffix) as the resource key
  `basePath.suffix` (e.g. `todo.item.title.label`). That one-path-two-uses fact
  is central; appendix [A2](README_advanced_A2_resource_scope_conventions.md)
  unpacks it.
- **Terminology.** Unfamiliar terms (grade, scope, adapter, draft, bundle, seed,
  graded DTO, grant matrix) are defined in the
  [glossary](README_advanced_A5_glossary_crossref.md).
- **Running the code.** Part [02](README_advanced_02_project_layout_build.md)
  has the full build/run steps and the seeded accounts; the
  [index](README_advanced_sample.md#run-the-whole-thing) has the one-command
  end-to-end check. Flutter suites take a plain `flutter test` — part 12
  explains why no concurrency flag is needed.

## Primary sources

- [`README_advanced_sample.md`](README_advanced_sample.md) — suite map, architecture diagram, quickstart, seeded accounts.

---

← Prev: [Guide index](README_advanced_sample.md#user-guide) · Next: [01 · Full-stack architecture](README_advanced_01_architecture.md) →
