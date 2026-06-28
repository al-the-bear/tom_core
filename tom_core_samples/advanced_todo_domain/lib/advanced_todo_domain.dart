/// Shared, reflected domain model for the advanced Tom Core full-stack sample.
///
/// One source of truth for the whole stack: the app server persists these
/// entities, the clients edit them, and the authorization layer grades their
/// fields. Import this barrel and call [initializeReflection] once at startup
/// before constructing any reflected entity.
///
/// ```dart
/// import 'package:advanced_todo_domain/advanced_todo_domain.dart';
///
/// void main() {
///   initializeReflection();
///   final item = TodoItem()
///     ..title.set('Ship the advanced sample')
///     ..statusValue = TodoStatus.inProgress
///     ..priorityValue = TodoPriority.high;
/// }
/// ```
///
/// The resource-key and role constants are added in step 3 of the plan.
library;

export 'src/entities.dart';
export 'src/reflection_entry.reflection.dart' show initializeReflection;
