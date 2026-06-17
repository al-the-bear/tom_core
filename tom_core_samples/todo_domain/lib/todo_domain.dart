/// Shared, reflected todo-management domain model for the Tom Core samples.
///
/// One source of truth for every sample: the server persists these entities,
/// the client edits them, and the showcases render them. Import this barrel
/// and call [initializeReflection] once at startup before constructing any
/// reflected entity.
///
/// ```dart
/// import 'package:todo_domain/todo_domain.dart';
///
/// void main() {
///   initializeReflection();
///   final item = TodoItem()
///     ..title.set('Write the article')
///     ..priorityValue = TodoPriority.high;
/// }
/// ```
library;

export 'src/entities.dart';
export 'src/reflection_entry.reflection.dart' show initializeReflection;
