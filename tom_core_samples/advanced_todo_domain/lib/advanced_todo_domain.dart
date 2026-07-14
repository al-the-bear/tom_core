/// Shared, reflected domain model for the advanced Tom Core full-stack sample.
///
/// One source of truth for the whole stack: the app server persists these
/// entities, the clients edit them, and the authorization layer grades their
/// fields.
///
/// This is a **library**: it ships no reflection seed of its own (G-REFL-1/2).
/// The runtime entry-points that need these entities reflected — the `*_server`
/// and `*_client` packages — build their own combined `initializeReflection()`
/// seed (domain entities + their local DTOs/forms) and call it once at startup.
/// The domain's *own* tests bootstrap through the test-only seed at
/// `test/run_all_tests.dart`.
///
/// ```dart
/// import 'package:advanced_todo_domain/advanced_todo_domain.dart';
///
/// // A consumer installs its own combined seed first, then:
/// final item = TodoItem()
///   ..title.set('Ship the advanced sample')
///   ..statusValue = TodoStatus.inProgress
///   ..priorityValue = TodoPriority.high;
/// ```
library;

export 'src/authz/resource_role_vocabulary.dart';
export 'src/entities.dart';
