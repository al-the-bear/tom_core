# Appendix A1 · Four-state authorization deep dive

*Appendix A1 of the Tom Core advanced-sample user guide — see the [guide index](README_advanced_sample.md#user-guide).*

> **Status: skeleton.** Content to be written in **RC-16**. This file currently
> provides the section structure and navigation only. Companion to
> [07 · Authorization](README_advanced_07_authorization.md).

## What this appendix covers

The four states (hidden / read-only / disabled / editable ↔
none / read / disabled / full); the resolution order layers 1–4
(`resolveEffectiveAuth`); the closed-safe default (D-A4); the grant matrix →
adapter → field path; and a worked role matrix
(owner / editor / viewer / commenter).

## The four states

_TODO(RC-16)._

## Resolution order: layers 1–4

_TODO(RC-16): `resolveEffectiveAuth`; layer 1 `TomAuthorization.resolveAuth(basePath)` (`tom_form.dart:807`); layer 4 per-field `TomAuthorizer.fixed`._

## The closed-safe default (D-A4)

_TODO(RC-16): an ungraded leaf degrades to none/hidden._

## The grant matrix → adapter → field path

_TODO(RC-16)._

## Worked role matrix

_TODO(RC-16): owner / editor / viewer / commenter across the item fields._

## Primary sources

- `advanced_examples_alignment_plan.md` — D-A3, D-A4, D-A6
- `tom_form.dart:807`; `field_grade_resolver.dart`; `field_state_authorization_adapter.dart`
- `advanced_example_completion.md` — After Todos 2, 5, 11

---

← Prev: [12 · Testing & cross-tier integration](README_advanced_12_testing_integration.md) · Next: [A2 · Scope, basePath & resource-key conventions](README_advanced_A2_resource_scope_conventions.md) →
