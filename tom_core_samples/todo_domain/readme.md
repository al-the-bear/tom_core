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

## Reflection — initialise once

Reflection metadata is generated, not hand-written. The package ships a
generated `lib/src/entities.reflection.dart` exposing a single
`initializeReflection()` function, re-exported from the public barrel. Call it
**once** at startup, before constructing any entity:

```dart
import 'package:todo_domain/todo_domain.dart';

void main() {
  initializeReflection();               // register the reflected entities
  final list = TodoList()..name.set('Sprint backlog');
  final task = TodoItem()
    ..title.set('Ship todo_domain')
    ..priorityValue = TodoPriority.high;
  list.items.add(task);
}
```

The server and client samples call `initializeReflection()` from their own
entrypoints; you never edit the generated file by hand.

### Regenerating after a model change

If you add a field or an entity, regenerate the reflection:

```bash
cd tom_core_samples/todo_domain
./reflection_generation.sh        # runs: dart run tom_reflection_generator build
```

The generator's entrypoint is `lib/src/entities.dart` (configured in
`build.yaml`); it follows the barrel's exports to discover every `@tomReflector`
class and rewrites `lib/src/entities.reflection.dart`. The generated file is
excluded from analysis by the shared workspace `analysis_options.yaml`.

---

## Package layout

```
todo_domain/
  pubspec.yaml                     pure-Dart package; depends on tom_core_kernel
  build.yaml                       reflection generator config (target: lib/src/entities.dart)
  reflection_generation.sh         one-command reflection rebuild
  analysis_options.yaml            includes the shared workspace options
  lib/
    todo_domain.dart               public barrel: entities + initializeReflection
    src/
      entities.dart                entity barrel (exports the entity files)
      reflection_entry.dart        generator entrypoint (has a main(); build target)
      reflection_entry.reflection.dart  generated — do not edit
      enums.dart                   TodoPriority, TodoLabel (values only; text is a resource)
      user.dart                    User
      project.dart                 Project
      todo_list.dart               TodoList
      todo_item.dart               TodoItem
  example/
    build_hierarchy_example.dart   Project → TodoList → TodoItem nesting
    enum_round_trip_example.dart   enum stored as name, read back typed
    assign_and_complete_example.dart  User ↔ TodoItem link + completion
    run_all_examples.dart          headless smoke test over the examples above
    readme.md                      example index
  readme.md                        this document
```

Run the examples as a smoke test:

```bash
dart run example/run_all_examples.dart
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
