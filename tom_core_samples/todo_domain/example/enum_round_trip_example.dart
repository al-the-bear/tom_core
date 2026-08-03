// Store an enum as its name, read it back as a typed value, and render it
// through the resource bundle.
//
// Demonstrates the two concepts behind TodoItem.priority / .label:
//   * the enum is persisted as Enum.name in a TomString (so it round-trips to
//     the server and JSON without a custom codec), while the typed accessor
//     converts it back — falling back to a sensible default for an unknown
//     stored value;
//   * the display text is never in Dart (G-RES-5). TomObservableEnum derives the
//     `global.<enumtype>.<value>` key and resolves it against the installed
//     bundle, so a different bundle relabels the same stored value with no code
//     change.
//
// Run with: dart run example/enum_round_trip_example.dart

import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:todo_domain/todo_domain.dart';

/// Installs [texts] as the application bundle. The keys are exactly the ones
/// the framework asks for: `global.<enumtype>.<value>`, both segments lowercase.
void installBundle(Map<String, dynamic> texts) =>
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(texts),
    );

void main() {
  initializeReflection();
  installBundle({
    'global.todopriority.high': 'High',
    'global.todolabel.bug': 'Bug',
  });

  final item = TodoItem()
    ..priorityValue = TodoPriority.high
    ..labelValue = TodoLabel.bug;

  // Stored as the enum name in the underlying TomString…
  print('stored priority: ${item.priority.get()}'); // stored priority: high
  print('stored label: ${item.label.get()}'); // stored label: bug

  // …read back as the typed enum…
  print('typed priority: ${item.priorityValue}'); // TodoPriority.high

  // …and rendered from the bundle, never from a Dart-side label table.
  final priorityText = TomObservableEnum.resolveText(item.priorityValue);
  final labelText = TomObservableEnum.resolveText(item.labelValue);
  print('display priority: $priorityText'); // display priority: High
  print('display label: $labelText'); // display label: Bug

  // A different bundle relabels the same stored value.
  installBundle({'global.todopriority.high': 'Hoch'});
  final germanText = TomObservableEnum.resolveText(item.priorityValue);
  print('display priority (de): $germanText'); // display priority (de): Hoch

  // An unknown stored value falls back to the default enum.
  final legacy = TodoItem()..priority.set('urgent');
  print('fallback: ${legacy.priorityValue}'); // fallback: TodoPriority.medium
}
