# todo_domain — examples

This is the canonical home for runnable samples of the shared `todo_domain`
model. Each file is self-contained, demonstrates one concept, and ends with its
expected output inline. `todo_domain` is pure Dart, so the whole tree doubles as
a headless smoke test.

| Sample | Demonstrates |
| ------ | ------------ |
| [`build_hierarchy_example.dart`](build_hierarchy_example.dart) | Nesting `Project → TodoList → TodoItem` and walking it back |
| [`enum_round_trip_example.dart`](enum_round_trip_example.dart) | Storing an enum as its name, reading it back typed (with fallback), and resolving its display text from the bundle |
| [`assign_and_complete_example.dart`](assign_and_complete_example.dart) | The `User ↔ TodoItem` link (`assigneeId`, `role`) and completing a task |

Run a single example:

```bash
dart run example/build_hierarchy_example.dart
```

Run the whole set (smoke test, non-zero exit on failure):

```bash
dart run example/run_all_examples.dart
```

Every example calls `initializeReflection()` once before constructing an
entity — see the package [`readme.md`](../readme.md) for why. The form- and
widget-level samples that *render* this model live in the Flutter showcases
under [`tom_core_samples`](../../README.md).
