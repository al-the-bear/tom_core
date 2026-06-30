# advanced_todo_domain

Shared, reflected domain model for the **advanced Tom Core full-stack sample**
(see `../../../../../_ai/quests/tom_core/advanced_example_specification_plan.md`).

This is the single source of truth for the whole stack — the app server
persists these entities, both Flutter clients edit them, and the four-state
authorization layer grades their fields.

> **Part of the [Tom Core user guide](../README_advanced_sample.md#user-guide).**
> This package is documented in context by
> **[03 · Domain model & reflection](../README_advanced_03_domain_reflection.md)**.

## Status

Entities + constants defined (steps 2–3). The eight observable `TomClass`
entities, their enums, the gradable resource-key constants, and the `ProjectRole`
enum are implemented; the reflection seed is generated; and the test suite (a
round-trip test per entity plus the gradable-key assertions) passes.

## Contents

- Observable `TomClass` entities (`lib/src/`): `User`, `Workspace`, `Project`,
  `TodoList`, `TodoItem` (with the `status` workflow enum), `TodoComment`,
  `Subtask`, `Share`. Relations are flat foreign keys, so each entity maps to
  its own SQL table in the app server's persistence layer.
- Closed-set enums (`lib/src/enums.dart`): `TodoStatus`, `TodoPriority`,
  `TodoLabel`, `UserStatus`, and `ProjectRole`
  (`owner`/`editor`/`commenter`/`viewer`) — each stored as its `name` in a
  `TomString` with a typed accessor on the owning entity.
- Gradable resource-key constants (`lib/src/resource_keys.dart`):
  `TodoItemResourceKeys` — the named, stable set of `todo.item.*` keys the
  four-state field authorization model grades.
- A reflection seed (`lib/src/reflection_entry.dart` →
  `reflection_entry.reflection.dart`); regenerate with
  `./reflection_generation.sh`. Call `initializeReflection()` once before
  constructing any entity.
