// Store an enum as its name and read it back as a typed value.
//
// Demonstrates the one concept behind TodoItem.priority / .label: the enum is
// persisted as Enum.name in a TomString (so it round-trips to the server and
// JSON without a custom codec), while the typed accessor converts it back —
// falling back to a sensible default for an unknown stored value.
//
// Run with: dart run example/enum_round_trip_example.dart

import 'package:todo_domain/todo_domain.dart';

void main() {
  initializeReflection();

  final item = TodoItem()
    ..priorityValue = TodoPriority.high
    ..labelValue = TodoLabel.bug;

  // Stored as the enum name in the underlying TomString…
  print('stored priority: ${item.priority.get()}'); // stored priority: high
  print('stored label: ${item.label.get()}'); // stored label: bug

  // …and read back as the typed enum, with a human-facing label.
  print('typed priority: ${item.priorityValue.label}'); // typed priority: High
  print('typed label: ${item.labelValue.label}'); // typed label: Bug

  // An unknown stored value falls back to the default enum.
  final legacy = TodoItem()..priority.set('urgent');
  print('fallback: ${legacy.priorityValue}'); // fallback: TodoPriority.medium
}
