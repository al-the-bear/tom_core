# advanced_todo_domain

Shared, reflected domain model for the **advanced Tom Core full-stack sample**
(see [`../README_advanced_sample.md`](../README_advanced_sample.md)).

This is the single source of truth for the whole stack — the app server
persists these entities, both Flutter clients edit them, and the four-state
authorization layer grades their fields.

> **Part of the [Tom Core user guide](../README_advanced_sample.md#user-guide).**
> This package is documented in context by
> **[03 · Domain model & reflection](../README_advanced_03_domain_reflection.md)**.

**Start with the example.**
[`example/advanced_todo_domain_example.dart`](example/advanced_todo_domain_example.dart)
needs no infrastructure and shows, in one run, what every consumer of this
package does: builds `Workspace → Project → TodoList → TodoItem` by foreign
key, reads the typed enum accessors (and their fallback when a stored name is
not a value), forms a resource key, and prints each role's effective field
states — the resource-level ceiling from `registerProjectRoleVocabulary()`
narrowed by the grade from `projectRoleFieldGrades`, the composition the item
screen performs.

```sh
dart run example/advanced_todo_domain_example.dart
```

`test/examples_test.dart` runs it the same way and checks every section of its
output. [The family's index](../README_advanced_sample.md#the-nine-packages)
says which of the nine carry an `example/`, and why.

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

## Authorization model and key formats

Every tier that grades anything agrees on this package's vocabulary, and on two
key formats.

**Two layers, composed by narrowing.** A `ProjectRole` gives a principal one
*resource-level* state on a resource — `owner`/`editor` → `full`,
`commenter`/`viewer` → `read` — registered with the framework by
`registerProjectRoleVocabulary()`. Inside that ceiling, `projectRoleFieldGrades`
grades each item field per role. A field's effective state is the ceiling
narrowed by the grade (`ceiling.narrow(grade)`), which is what the app client's
item screen computes; a principal with no role on the item has a `none` ceiling,
so every field collapses whatever the matrix says. Every grade sits at or below
its role's ceiling, so the narrow reproduces the matrix exactly — the package's
suite asserts that for all 28 field cells and the four attachment grades. The
matrix itself is written out once, in the dartdoc on `projectRoleFieldGrades`
(`lib/src/authz/field_grade_vocabulary.dart`); the server-side enforcement and
the admin console's editing of it are in
[07 · Authorization](../README_advanced_07_authorization.md), and the full
state machine in
[A1](../README_advanced_A1_authorization_state_machine.md).

**Resource keys: `<type>:<id>`.** A resource is addressed as its type token and
id joined by `:` — `workspace:w1`, `project:p1`, `list:l1`, `item:i1` — built by
`ResourceRoleKeys` (the four tokens are its constants, listed under
[API](#api)). These are the keys a principal's `resourceRoles` map and the
framework's resource-role adapter speak; a dotted path is never one.

**Field keys: `todo.item.<field>`.** A gradable field is addressed by scope and
`tomId` — the item form runs under scope `todo`, `formId` `item` — so the key
names the *concept*, not the storage member: `todo.item.estimate` grades the
entity's `estimateHours`. `gradableItemKeys` is the one declaration of the set.
[A2 · Resource & scope conventions](../README_advanced_A2_resource_scope_conventions.md)
covers the addressing rule and the `estimate` / `estimateHours` case in full.

## API

Every public declaration the barrel (`lib/advanced_todo_domain.dart`) exports —
through `lib/src/entities.dart` for the entities and enums — library by
library, as the source declares it. Entity fields are listed with their
initializer, since the observable type *is* the field's type; constants with
their values. Doc comments and bodies are left out.

There is no `doc/` folder and no `doc/api/` summary: no sample carries one, a
decision taken once for all sixteen in [the suite map](../README.md). This
section is the reference instead, and `test/readme_api_reference_test.dart`
holds it to the source in both directions — every line below must occur in its
library, and every public declaration of an exported library must be listed.

### `lib/src/enums.dart`

The closed sets. Each is stored as its `name` in a `TomString` and read through a typed accessor on the owning entity.

```dart
enum TodoStatus { backlog, todo, inProgress, inReview, done, cancelled }
enum TodoPriority { low, medium, high, critical }
enum TodoLabel { feature, bug, chore, docs, research }
enum UserStatus { active, suspended }
enum ProjectRole { owner, editor, commenter, viewer }
```

### `lib/src/user.dart`

An account as the app sees it.

```dart
class User extends TomClass
  late final id = TomString('')
  late final username = TomString('')
  late final displayName = TomString('')
  late final email = TomString('')
  late final avatarRef = TomString('')
  late final status = TomString(UserStatus.active.name)
  UserStatus get statusValue
  set statusValue(UserStatus value)
```

### `lib/src/workspace.dart`

The top of the containment chain; owned by one user.

```dart
class Workspace extends TomClass
  late final id = TomString('')
  late final name = TomString('')
  late final ownerId = TomString('')
  late final createdAt = TomNDateTime(null)
```

### `lib/src/project.dart`

Belongs to a workspace (`workspaceId`).

```dart
class Project extends TomClass
  late final id = TomString('')
  late final workspaceId = TomString('')
  late final name = TomString('')
  late final description = TomString('')
  late final colour = TomString('')
  late final archived = TomBool(false)
```

### `lib/src/todo_list.dart`

Belongs to a project (`projectId`).

```dart
class TodoList extends TomClass
  late final id = TomString('')
  late final projectId = TomString('')
  late final name = TomString('')
  late final position = TomInt(0)
```

### `lib/src/todo_item.dart`

Belongs to a list (`listId`); the graded entity. `estimateHours` is graded under the key `todo.item.estimate`.

```dart
class TodoItem extends TomClass
  late final id = TomString('')
  late final listId = TomString('')
  late final title = TomString('')
  late final description = TomString('')
  late final status = TomString(TodoStatus.backlog.name)
  late final priority = TomString(TodoPriority.medium.name)
  late final label = TomString(TodoLabel.feature.name)
  late final assigneeId = TomString('')
  late final reporterId = TomString('')
  late final dueDate = TomNDateTime(null)
  late final estimateHours = TomNDouble(null)
  late final tags = TomList<TomString>()
  late final attachment = TomString('')
  late final createdAt = TomNDateTime(null)
  late final updatedAt = TomNDateTime(null)
  TodoStatus get statusValue
  set statusValue(TodoStatus value)
  TodoPriority get priorityValue
  set priorityValue(TodoPriority value)
  TodoLabel get labelValue
  set labelValue(TodoLabel value)
```

### `lib/src/todo_comment.dart`

A comment on an item.

```dart
class TodoComment extends TomClass
  late final id = TomString('')
  late final itemId = TomString('')
  late final authorId = TomString('')
  late final body = TomString('')
  late final createdAt = TomNDateTime(null)
```

### `lib/src/subtask.dart`

A checklist row on an item.

```dart
class Subtask extends TomClass
  late final id = TomString('')
  late final itemId = TomString('')
  late final title = TomString('')
  late final done = TomBool(false)
  late final position = TomInt(0)
```

### `lib/src/share.dart`

A grant of a `ProjectRole` on one resource to one user.

```dart
class Share extends TomClass
  late final id = TomString('')
  late final resourceType = TomString('')
  late final resourceId = TomString('')
  late final granteeUserId = TomString('')
  late final projectRole = TomString(ProjectRole.viewer.name)
  late final grantedById = TomString('')
  late final createdAt = TomNDateTime(null)
  ProjectRole get projectRoleValue
  set projectRoleValue(ProjectRole value)
```

### `lib/src/authz/resource_keys.dart`

The `<type>:<id>` resource-key format and its four type tokens.

```dart
class ResourceRoleKeys
  static const String workspaceType = 'workspace'
  static const String projectType = 'project'
  static const String listType = 'list'
  static const String itemType = 'item'
  static String forResource(String type, String id)
  static String workspace(String id)
  static String project(String id)
  static String list(String id)
  static String item(String id)
```

### `lib/src/authz/resource_role_vocabulary.dart`

Registers the resource-level `ProjectRole` → `TomAuthState` ceiling with the framework.

```dart
void registerProjectRoleVocabulary()
```

### `lib/src/authz/field_grade_vocabulary.dart`

The per-field grades inside that ceiling. The matrix itself is written out once, in the dartdoc on `projectRoleFieldGrades`.

```dart
const Map<ProjectRole, Map<String, TomAuthState>> projectRoleFieldGrades
const List<String> gradableItemKeys
const String itemAttachmentGradeKey
const Map<ProjectRole, TomAuthState> projectRoleAttachmentGrades
```
