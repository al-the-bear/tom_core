# Authorization

*Part 07 of the Tom Core advanced-sample user guide — see the [guide index](README_advanced_sample.md#user-guide).*

> **Status: skeleton.** Content to be written in **RC-10**. This file currently
> provides the section structure and navigation only.

## What this part covers

The **four-state field authorization** model; **scope/form/field → `basePath` →
grade key**; the grant matrix; the `FieldStateAuthorizationAdapter` installed
once at startup; **implicit (adapter) vs override (`TomAuthorizer.fixed`)
paths**; and route-level role gating for admin CRUD. Deep dive in
[A1](README_advanced_A1_authorization_state_machine.md).

## The four-state field authorization model

_TODO(RC-10): none/read/disabled/full ↔ hidden/read-only/disabled/editable._

## scope/form/field → `basePath` → grade key

_TODO(RC-10): cite `tom_form.dart:807`; cross-link A2._

## The grant matrix

_TODO(RC-10)._

## The single installed adapter

_TODO(RC-10): `FieldStateAuthorizationAdapter` installed once from the session._

## Implicit vs override paths

_TODO(RC-10): the adapter path vs per-field `TomAuthorizer.fixed` narrowing override (user/role forms; the group form has none)._

## Route-level role gating for admin CRUD

_TODO(RC-10)._

## Server-side resolvers

_TODO(RC-10): `resource_access_resolver` / `field_grade_resolver`._

## Primary sources

- `advanced_examples_alignment_plan.md` — Why / Key anatomy / D-A1…D-A8
- `advanced_example_specification_plan.md` — A.4 Authorization model, A.12 Security
- `field_state_authorization_adapter.dart`; `app_server/src/access/`; `tom_form.dart:807`
- `advanced_example_completion.md` — After Todos 2, 3, 5; appendix [A1](README_advanced_A1_authorization_state_machine.md)

---

← Prev: [06 · Authentication (JWT)](README_advanced_06_authentication.md) · Next: [08 · Resources & text externalization](README_advanced_08_resources_texts.md) →
