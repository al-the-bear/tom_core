/// Shared, reflected todo-management domain model for the Tom Core samples.
///
/// One source of truth for every sample: the server persists these entities,
/// the client edits them, and the showcases render them.
///
/// **This package ships no reflection seed.** The entities are
/// `@tomReflector` classes, so a program must install reflection before
/// constructing one — and it installs *its own* seed, generated from its own
/// entry point, which reaches these entities through its imports alongside
/// everything else the program reflects:
///
/// ```dart
/// import 'package:todo_domain/todo_domain.dart';
///
/// import 'main.reflection.dart'; // this program's seed, from its own root
///
/// void main() {
///   initializeReflection();
///   final item = TodoItem()
///     ..title.set('Write the article')
///     ..priorityValue = TodoPriority.high;
/// }
/// ```
///
/// A library that exported a seed of its own would collide with its consumer's
/// on `initializeReflection`, and which one the consumer got would be decided
/// by import order. The package's own tests and examples use the seed rooted
/// at `test/run_all_tests.dart`.
library;

export 'src/entities.dart';
export 'src/wire/wire.dart';
