# Resources & text externalization

*Part 08 of the Tom Core advanced-sample user guide — see the [guide index](README_advanced_sample.md#user-guide).*

> **Status: skeleton.** Content to be written in **RC-11** (depends on **RC-24**,
> the JSON resource externalization). This file currently provides the section
> structure and navigation only.

## What this part covers

The **no-hard-coded-labels rule**; resources are **server-delivered**, installed
via `TomTextResourceProvider.setAppResourceProvider`; keyed by
`<basePath>.<suffix>` (`.label` / `.hint` / `.error.*` / colors / icons); the
**scope/form/field-structured JSON resource files** (post-RC-24); the login
bundle (pre-login) vs full bundle (post-login) bootstrap; and the sentinel-`[srv]`
proof pattern.

## The no-hard-coded-labels rule

_TODO(RC-11)._

## Server-delivered resources

_TODO(RC-11): `TomTextResourceProvider.setAppResourceProvider`._

## Keying by `<basePath>.<suffix>`

_TODO(RC-11): `.label`/`.hint`/`.error.*`/colors/icons via `TomCtr`; cite `tom_form.dart:855`._

## Scope/form/field-structured JSON resource files

_TODO(RC-11, after RC-24): the nested JSON tree that flattens to the same `<basePath>.<suffix>` keys; cross-link A2._

## Login bundle vs full bundle bootstrap

_TODO(RC-11): login bundle pre-login, full bundle post-login (D-A9)._

## The sentinel-`[srv]` proof pattern

_TODO(RC-11)._

## Primary sources

- `advanced_examples_alignment_plan.md` — gaps 2–3, Key anatomy, D-A1, D-A9
- `*/resources/*_resource_bundles.dart`; `app_session.dart` / `admin_session.dart`
- `advanced_example_completion.md` — After Todos 1, 6, 7, 8, 9, 10
- RC-24 (JSON externalization); appendix [A2](README_advanced_A2_resource_scope_conventions.md)

---

← Prev: [07 · Authorization](README_advanced_07_authorization.md) · Next: [09 · Forms & UI](README_advanced_09_forms_ui.md) →
