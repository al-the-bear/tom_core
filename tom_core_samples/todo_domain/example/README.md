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

The same set also runs under `dart test` — see
[`test/examples_test.dart`](../test/examples_test.dart) — so a broken example
fails the suite rather than waiting to be noticed by hand. A new example must be
listed in both places. That run also holds the output comments to the output:
every `print(...); // <text>` line must print a line ending in `<text>`, so a
comment that tells the reader the wrong result fails the suite.

Every example calls `initializeReflection()` once before constructing an
entity — see the package [`README.md`](../README.md) for why. The form- and
widget-level samples that *render* this model live in the Flutter showcases
under [`tom_core_samples`](../../README.md).
