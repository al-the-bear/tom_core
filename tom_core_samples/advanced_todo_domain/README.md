# advanced_todo_domain

Shared, reflected domain model for the **advanced Tom Core full-stack sample**
(see `../../../../../_ai/quests/tom_core/advanced_example_specification_plan.md`).

This is the single source of truth for the whole stack — the app server
persists these entities, both Flutter clients edit them, and the four-state
authorization layer grades their fields.

## Status

Scaffold (step 1). The package compiles and analyzes clean; the entities,
resource-key/role constants, and reflection seed are added in steps 2–3.

## Planned contents

- Observable `TomClass` entities: `User`, `Workspace`, `Project`, `TodoList`,
  `TodoItem` (with the `status` workflow enum), `TodoComment`, `Subtask`,
  `Share`.
- Resource-key constants (`TodoItemResourceKeys`) for the gradable fields and
  the `projectRole` / `status` enums.
- A reflection seed (`lib/src/reflection_entry.dart` →
  `reflection_entry.reflection.dart`); regenerate with
  `./reflection_generation.sh`.
