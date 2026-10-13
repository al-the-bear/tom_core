# `todo_domain` — the shared model every sample reuses

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> This sample is BSD-3-Clause licensed and internal (`publish_to: none`).

`todo_domain` is the **single source of truth** for the Tom Core samples. It is a
tiny, pure-Dart package — no Flutter, no server, no UI — that defines the
reflected entities of a todo-management application: **`User`**, **`Project`**,
**`TodoList`**, **`TodoItem`**, and the **`TodoPriority`** / **`TodoLabel`**
enums. Every other sample depends on it: the
[`core_server_sample`](../README.md#client--server) persists these entities,
the [`core_client_sample`](../README.md#client--server) edits them, and the
[showcases](../README.md#tom_flutter_ui-showcases) render them. Because the model
lives in exactly one place, the articles build on one another instead of
re-introducing a model each time.

This README is the article companion for the shared domain. Read it first, then
follow the [learning path](../README.md#learning-path) up through the server and
the client.

---

## Why a shared domain package at all

When a model is copied into each app, the copies drift: the server's `TodoItem`
grows a field the client never learns about; an enum gains a case on one side
only. The whole point of these samples is to show **one** application taught
across the whole Tom Core layer, so the model has to be shared, not duplicated.

A standalone package gives us that for free:

- **One definition, many consumers.** The server and the client both
  `dependency: todo_domain` and import the same classes. A change lands once.
- **Pure Dart.** `todo_domain` depends only on
  [`tom_core_kernel`](../../tom_core_kernel/README.md) — never on Flutter or on
  `tom_core_server`. That keeps it usable from a headless server, a Flutter
  client, a CLI, or a test, with no platform baggage.
- **Reflected.** Every entity carries `@tomReflector`, so the kernel's reflection
  machinery can construct, inspect, copy, and (de)serialize it. That same
  reflection is what lets the server's persistence layer map entities to MySQL
  and the client's forms bind fields by name.

---

## The model

The entities form a three-level hierarchy, owned by a `User`:

```
User  ──owns──▶  Project  ──has──▶  TodoList  ──has──▶  TodoItem
                                                          │
                              assigneeId ─────────────────┘  (points back to a User.id)
```

| Entity | Key fields | Role |
| --- | --- | --- |
| `User` | `id`, `displayName`, `email`, `role` | Identity; `role` drives four-state authorization. |
| `Project` | `id`, `name`, `description`, `ownerId`, `lists` | Groups lists under an owning user. |
| `TodoList` | `id`, `name`, `projectId`, `items` | A named list of items inside a project. |
| `TodoItem` | `id`, `title`, `description`, `done`, `priority`, `label`, `assigneeId`, `dueDate` | The leaf task the CRUD forms edit. |

Every field is a kernel **observable** — `TomString`, `TomBool`, `TomNDateTime`,
or a `TomList<T>` of child entities — so any field can be observed, bound to a
form, and round-tripped through reflection.

### Observable fields, not plain values

Entities extend `TomClass` and declare their fields as `late final` observables:

```dart
@tomReflector
class TodoItem extends TomClass {
  late final id = TomString('');
  late final title = TomString('');
  late final done = TomBool(false);
  late final dueDate = TomNDateTime(null);
  // …
}
```

Reading and writing goes through the observable, so changes are notifiable and
form-bindable:

```dart
final item = TodoItem();
item.title.set('Write the article');   // or: item.title | 'Write the article'
final isDone = item.done.get();         // or: ~item.done
```

`TomList<T>` holds child entities — `Project.lists`, `TodoList.items` — and is
itself observable, so adding or removing a child notifies list-bound UI.

### Enums stored as names

`TodoItem.priority` and `TodoItem.label` are closed sets, but they are **stored**
as a `TomString` holding the enum's `name`:

```dart
late final priority = TomString(TodoPriority.medium.name);
```

Storing the `name` means the value persists to a MySQL `VARCHAR`/`ENUM` column
and serializes to JSON with **no custom codec** — the server's persistence layer
treats it as an ordinary string. For typed access, `TodoItem` exposes
convenience accessors that convert back to the enum (falling back to a sane
default for an unknown stored value):

```dart
item.priorityValue = TodoPriority.high;      // writes 'high' to priority
final p = item.priorityValue;                // reads 'high' → TodoPriority.high
```

The human-facing text is **not** in this package (G-RES-5). A value's display
string is addressed by a `global.<enumtype>.<value>` key that the framework
derives and resolves against the installed bundle —
`TomObservableEnum.resolveText(TodoPriority.high)` yields whatever
`global.todopriority.high` holds — so a different bundle relabels the same
stored value with no change here.

---

## The wire contract

The entities above are what the *application* holds. What crosses the network is
a second, flatter set of shapes under `lib/src/wire/`, exported from the same
barrel:

| DTO | Endpoint | Shape |
| --- | --- | --- |
| `TodoItemDto` | `GET /todos` (a bare array) | flat projection: keys as strings, `priority`/`label` as their enum `.name` token, `dueDate` as an ISO-8601 string (empty when unset) |
| `TodoFieldMatrixDto` | `GET /todos/field-states` | `{states: {role: {resourceKey: token}}}` — the full `role → field → TomAuthState` grade matrix |

Both are **reflection-first** (G-DTO): a `@tomReflector` class with plain
non-`final` fields and **no** hand-written `toJson`/`fromJson`. The framework
round-trips them through the same kernel reflection path as the entities — the
server's endpoint pipeline drives it directly, while off-server consumers (the
Flutter client's live read path, the round-trip tests) go through the three
one-liners in `dto_reflection.dart`:

```dart
final map = dtoToMap(dto);                       // DTO  → JSON-ready map
final json = dtoToJsonString(dto);               // DTO  → JSON string
final back = dtoFromJson<TodoItemDto>(map);      // map  → DTO
```

The string form is a separate kernel path from the map form, so
`todo_domain_test.dart` round-trips both DTOs through it too: the decoded string
must equal the map, and read back to the same DTO. `dtoFromJson` throws a
`StateError` whose message names `initializeReflection()` when the reflection
seed has not been installed, and a `NoSuchCapabilityError` for a type it does
not cover; `dto_reflection_failure_test.dart` pins both.

Values that cannot cross the wire as their native type travel as a stable token
with a typed accessor on the near side, and the readers are **closed-safe**:
every degenerate `TodoFieldMatrixDto` input a payload can carry — an absent
role, a row that is not a map, an unset cell, an unrecognised token, or a cell
holding something that is not a string at all — resolves to `TomAuthState.none`
rather than throwing, so an unknown grade denies rather than escalates.

That last case is why `parseState` takes `Object?` rather than `String?`:
`states` is typed `Map<String, Object?>`, so a cell may hold any JSON value, and
keeping the decision in one place is what stops a reader from reintroducing a
throwing path by narrowing the type itself. The guarantee matters more here than
ordinary leniency would suggest — the matrix *is* an authorization decision
arriving over the network, so a reader that threw on a malformed cell would
break the client's read path instead of denying. `todo_domain_test.dart` asserts
each of those inputs against both readers.

The DTOs live beside the entities rather than in a separate contracts package
because this deliberately-minimal pair already shares one reflected package
across both tiers; the `wire/` folder keeps the domain-versus-transport
separation without a second package to build and reflect.

---

## Reflection — the program installs its own seed

The entities are `@tomReflector` classes, so reflection must be installed before
one is constructed or a wire DTO is parsed. **This package ships no seed.** A
program generates one from its own entry point — the generator follows that
program's imports and reaches these entities along with everything else it
reflects — and calls that seed's `initializeReflection()` once at startup:

```dart
import 'package:todo_domain/todo_domain.dart';

import 'main.reflection.dart'; // this program's seed, from its own root

void main() {
  initializeReflection();               // register the reflected entities
  final list = TodoList()..name.set('Sprint backlog');
  final task = TodoItem()
    ..title.set('Ship todo_domain')
    ..priorityValue = TodoPriority.high;
  list.items.add(task);
}
```

`core_server_sample` installs `bin/server_start.reflection.dart`, rooted at its
live-boot entry point, and `core_client_sample` its `lib/reflection_seed.dart`,
which covers the entities and its forms together. A seed exported from this
package would collide with theirs on `initializeReflection`, and which one a
consumer got would be decided by import order — so a library carries none
(G-REFL-1/2 in the suite's guidelines).

This package's own tests and examples need reflection too, so it has **one
seed, in `test/`**: `test/run_all_tests.dart` is the generator's root and
`test/run_all_tests.reflection.dart` the generated seed. Tests import it
directly, and the examples import it as `../test/run_all_tests.reflection.dart`.

### Regenerating after a model change

If you add a field or an entity, regenerate the reflection:

```bash
cd tom_core_samples/todo_domain
./reflection_generation.sh        # runs: dart run tom_reflection_generator
```

The seed is committed and must stay what the generator emits today — a rule the
whole suite shares, stated once in
[the samples map](../README.md#reflection-seeds). It can go stale without a
model change here, because it also mirrors the kernel types the entities reach;
`./reflection_generation.sh --check` reports that, and a stale seed still
analyzes and still passes the suite.

The script runs the generator **flag-free** — it scans the current project only
(the framework default is scan `.`, non-recursive) and reads `build.yaml`'s
`generate_for`. Do not add a `build` positional argument: the generator reads it
as a target filter, matches nothing, and exits with `Target not found: build`
having written no output.

The generator's entrypoint is `test/run_all_tests.dart` (configured in
`build.yaml`); the generator only processes files that expose a `main()`, so
that file exists solely to give it one — its `main()` touches each reflected
type, and the generator follows the import graph from there to discover every
`@tomReflector` class, rewriting `test/run_all_tests.reflection.dart`. It is
never called at runtime. The generated file is excluded from analysis by the
shared workspace `analysis_options.yaml`.

---

## Package layout

```
todo_domain/
  pubspec.yaml                     pure-Dart package; depends on tom_core_kernel
  build.yaml                       reflection generator config (target: test/run_all_tests.dart)
  reflection_generation.sh         one-command reflection rebuild
  analysis_options.yaml            includes the shared workspace options
  lib/
    todo_domain.dart               public barrel: entities + wire DTOs (no reflection seed)
    src/
      entities.dart                entity barrel (exports the entity files)
      enums.dart                   TodoPriority, TodoLabel (values only; text is a resource)
      user.dart                    User
      project.dart                 Project
      todo_list.dart               TodoList
      todo_item.dart               TodoItem
      wire/
        wire.dart                  wire barrel (exported from todo_domain.dart)
        todo_item_dto.dart         TodoItemDto — GET /todos
        todo_field_matrix_dto.dart TodoFieldMatrixDto — GET /todos/field-states
        dto_reflection.dart        dtoFromJson / dtoToMap / dtoToJsonString
  example/
    build_hierarchy_example.dart   Project → TodoList → TodoItem nesting
    enum_round_trip_example.dart   enum stored as name, read back typed
    assign_and_complete_example.dart  User ↔ TodoItem link + completion
    run_all_examples.dart          headless smoke test over the examples above
    README.md                      example index
  test/
    run_all_tests.dart             reflection generator root (has a main(); build target)
    run_all_tests.reflection.dart  generated — the seed tests and examples install
  README.md                        this document
```

Run the examples as a smoke test:

```bash
dart run example/run_all_examples.dart
```

---

## API

Every public declaration the barrel (`lib/todo_domain.dart`) exports, library by
library, with its signature as the source declares it. The sections above are
the narrative; this is the index the other samples are read against. Doc
comments, annotations and bodies are left out.

There is no `doc/` folder and no `doc/api/` summary: no sample carries one, a
decision taken once for all sixteen in [the samples map](../README.md). This
section is the reference instead, and `test/readme_api_reference_test.dart`
holds it to the source in both directions — every line below must occur in its
library, and every public declaration of an exported library must be listed.

### `lib/src/enums.dart`

Stored by name; the display text is a resource, never a string in Dart.

```dart
enum TodoPriority { low, medium, high, critical }
enum TodoLabel { feature, bug, chore, docs, research }
```

### `lib/src/project.dart`

```dart
class Project extends TomClass
  late final id = TomString('')
  late final name = TomString('')
  late final description = TomString('')
  late final ownerId = TomString('')
  late final lists = TomList<TodoList>()
```

### `lib/src/todo_item.dart`

```dart
class TodoItem extends TomClass
  late final id = TomString('')
  late final title = TomString('')
  late final description = TomString('')
  late final done = TomBool(false)
  late final priority = TomString(TodoPriority.medium.name)
  late final label = TomString(TodoLabel.feature.name)
  late final assigneeId = TomString('')
  late final dueDate = TomNDateTime(null)
  TodoPriority get priorityValue
  set priorityValue(TodoPriority value)
  TodoLabel get labelValue
  set labelValue(TodoLabel value)
```

### `lib/src/todo_list.dart`

```dart
class TodoList extends TomClass
  late final id = TomString('')
  late final name = TomString('')
  late final projectId = TomString('')
  late final items = TomList<TodoItem>()
```

### `lib/src/user.dart`

```dart
class User extends TomClass
  late final id = TomString('')
  late final displayName = TomString('')
  late final email = TomString('')
  late final role = TomString('member')
```

### `lib/src/wire/dto_reflection.dart`

```dart
T dtoFromJson<T extends Object>(Map<String, Object?> json)
Map<String, Object?> dtoToMap(Object dto)
String dtoToJsonString(Object dto)
```

### `lib/src/wire/todo_field_matrix_dto.dart`

```dart
class TodoFieldMatrixDto
  Map<String, Object?> states
  TodoFieldMatrixDto([Map<String, Map<String, TomAuthState>>? matrix])
  Iterable<String> get roles
  Map<String, TomAuthState> statesFor(String role)
  TomAuthState accessFor(String role, String resourceKey)
  static TomAuthState parseState(Object? token, {TomAuthState orElse = TomAuthState.none})
  String toString()
```

### `lib/src/wire/todo_item_dto.dart`

```dart
class TodoItemDto
  String id
  String title
  String description
  bool done
  String priority
  String label
  String assigneeId
  String dueDate
  String listId
  TodoItemDto({this.id = '', this.title = '', this.description = '', this.done = false, this.priority = '', this.label = '', this.assigneeId = '', this.dueDate = '', this.listId = ''})
  String toString()
```

---

## Where it goes next

| Consumer | Uses `todo_domain` to… |
| --- | --- |
| [`core_server_sample`](../README.md#client--server) | persist the entities to MySQL and serve them over the API |
| [`core_client_sample`](../README.md#client--server) | bind the entities to login + CRUD forms with ACL-driven field states |
| [showcases](../README.md#tom_flutter_ui-showcases) | render the entities through the widget, forms, and ACL surfaces |

Continue with the [samples map](../README.md) and the
[Tom Core repository map](../../README.md).

## License

BSD 3-Clause licensed. This sample carries the same
[`LICENSE`](../../tom_core_kernel/LICENSE) as the rest of Tom Core.
