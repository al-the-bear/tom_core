# advanced_todo_domain

Shared, reflected domain model for the **advanced Tom Core full-stack sample**
(see `../../../../../_ai/quests/tom_core/advanced_example_specification_plan.md`).

This is the single source of truth for the whole stack — the app server
persists these entities, both Flutter clients edit them, and the four-state
authorization layer grades their fields.

## Status

Entities defined (step 2). The eight observable `TomClass` entities and their
enums are implemented, the reflection seed is generated, and a round-trip
test per entity passes. The resource-key/role constants are added in step 3.

## Contents

- Observable `TomClass` entities (`lib/src/`): `User`, `Workspace`, `Project`,
  `TodoList`, `TodoItem` (with the `status` workflow enum), `TodoComment`,
  `Subtask`, `Share`. Relations are flat foreign keys, so each entity maps to
  its own SQL table in the app server's persistence layer.
- Closed-set enums (`lib/src/enums.dart`): `TodoStatus`, `TodoPriority`,
  `TodoLabel`, `UserStatus` — each stored as its `name` in a `TomString` with a
  typed accessor on the owning entity.
- A reflection seed (`lib/src/reflection_entry.dart` →
  `reflection_entry.reflection.dart`); regenerate with
  `./reflection_generation.sh`. Call `initializeReflection()` once before
  constructing any entity.

## Planned (later steps)

- Resource-key constants (`TodoItemResourceKeys`) for the gradable fields and
  the typed `projectRole` enum + accessor on `Share` (step 3).
