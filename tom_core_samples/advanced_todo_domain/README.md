# advanced_todo_domain

Shared, reflected domain model for the **advanced Tom Core full-stack sample**
(see [`../README_advanced_sample.md`](../README_advanced_sample.md)).

This is the single source of truth for the whole stack — the app server
persists these entities, both Flutter clients edit them, and the four-state
authorization layer grades their fields.

> **Part of the [Tom Core user guide](../README_advanced_sample.md#user-guide).**
> This package is documented in context by
> **[03 · Domain model & reflection](../README_advanced_03_domain_reflection.md)**.

## Contents

- Observable `TomClass` entities (`lib/src/`): `User`, `Workspace`, `Project`,
  `TodoList`, `TodoItem` (with the `status` workflow enum), `TodoComment`,
  `Subtask`, `Share`. Relations are flat foreign keys, so each entity maps to
  its own SQL table in the app server's persistence layer.
- Closed-set enums (`lib/src/enums.dart`): `TodoStatus`, `TodoPriority`,
  `TodoLabel`, `UserStatus`, and `ProjectRole`
  (`owner`/`editor`/`commenter`/`viewer`) — each stored as its `name` in a
  `TomString` with a typed accessor on the owning entity.
- The gradable `TodoItem` fields are addressed by scope + `tomId` (G-RES-6): a
  form run under scope `'todo'` with `formId: 'item'` self-addresses each field
  as a `todo.item.<field>` key, which the four-state field authorization model
  grades. There is no key-catalogue class on the form side — a field's key is
  derived at use from scope + `formId` + `tomId`.
- The shared authorization vocabulary (`lib/src/authz/`), which every tier must
  agree on:
  - `resource_keys.dart` — `ResourceRoleKeys`, the `<type>:<id>` format for
    per-principal-per-resource grants, with the four type tokens
    (`workspace`/`project`/`list`/`item`) and a builder each.
  - `resource_role_vocabulary.dart` — `registerProjectRoleVocabulary()`, which
    installs the `ProjectRole` → `TomAuthState` mapping (owner/editor → `full`,
    commenter/viewer → `read`) into the framework's `TomResourceRoleRegistry`.
    Called once at each runtime's boot.
  - `field_grade_vocabulary.dart` — the finer per-field matrix
    (`projectRoleFieldGrades` over `gradableItemKeys`) that the resource-level
    registry deliberately does not model, plus the item's graded file column
    (`itemAttachmentGradeKey`, `projectRoleAttachmentGrades`), which is
    enforced on the file endpoint rather than in the item payload.
- A **test-only** reflection seed (`test/run_all_tests.dart` →
  `test/run_all_tests.reflection.dart`); regenerate with
  `./reflection_generation.sh`. The domain is a library and ships no runtime seed
  (G-REFL-1/2): its own tests call `initializeReflection()` from this seed, while
  runtime consumers (servers/clients) build and call their own combined seed
  before constructing any entity.
