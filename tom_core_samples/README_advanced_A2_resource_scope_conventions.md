# Appendix A2 · Scope, `basePath` & resource-key conventions

*Appendix A2 of the Tom Core advanced-sample user guide — see the [guide index](README_advanced_sample.md#user-guide).*

> **Status: skeleton.** Content to be written in **RC-17**. This file currently
> provides the section structure and navigation only. Companion to
> [08 · Resources & text externalization](README_advanced_08_resources_texts.md)
> and [09 · Forms & UI](README_advanced_09_forms_ui.md).

## What this appendix covers

`basePath` = `<scopePath>.<formId>.<tomId>`; the one-path-two-uses fact (auth
keys on `basePath`, resources on `basePath.suffix`); the
`estimate`/`estimateHours` mismatch (D-A2); scoped vs unscoped form construction;
and how the JSON resource tree mirrors scope/form/field.

## `basePath` = `<scopePath>.<formId>.<tomId>`

_TODO(RC-17): cite `tom_form.dart:614-617`._

## One path, two uses

_TODO(RC-17): authorization keys on `basePath` alone; resources on `basePath.suffix` (`.label`/`.hint`/...)._

## The `estimate` / `estimateHours` mismatch (D-A2)

_TODO(RC-17): the `estimateHours` member maps to the `todo.item.estimate` key._

## Scoped vs unscoped form construction

_TODO(RC-17): D-A1 — scope path == resource key._

## How the JSON resource tree mirrors scope/form/field

_TODO(RC-17, ties to RC-24)._

## Primary sources

- `advanced_examples_alignment_plan.md` — Key anatomy, D-A1, D-A2
- `advanced_todo_domain/.../resource_keys.dart`; `tom_form.dart:614-617`
- `tom_construction_helpers.dart:29-32` (`TomCtr`)

---

← Prev: [A1 · Four-state authorization deep dive](README_advanced_A1_authorization_state_machine.md) · Next: [A3 · A secured request, end to end](README_advanced_A3_request_lifecycle.md) →
