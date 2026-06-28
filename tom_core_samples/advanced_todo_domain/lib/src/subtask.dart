import 'package:tom_core_kernel/tom_core_kernel.dart';

/// A checklist row on a [TodoItem].
///
/// Lightweight sub-step of an item; [done] toggles the checkbox and [position]
/// orders the rows.
@tomReflector
class Subtask extends TomClass {
  /// Stable identifier (the server's primary key).
  late final id = TomString('');

  /// `TodoItem.id` this subtask belongs to.
  late final itemId = TomString('');

  /// Short label for the checklist row.
  late final title = TomString('');

  /// Whether the subtask is completed.
  late final done = TomBool(false);

  /// Zero-based ordering position within the item.
  late final position = TomInt(0);
}
