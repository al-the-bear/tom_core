/// How `dtoFromJson` fails, pinned because its dartdoc and the completion
/// document both tell a caller what to catch.
///
/// Kept apart from `todo_domain_test.dart` on purpose: that suite installs the
/// reflection seed in `setUpAll`, and the first case here is only observable in
/// a process where nobody has — which is what a caller who forgot
/// `initializeReflection()` is running. The second case installs the seed, so
/// the order of the two is load-bearing; `dart test` runs a file's tests in
/// declaration order.
library;

import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:todo_domain/todo_domain.dart';

/// A class the reflection seed does not cover.
class _Unreflected {}

void main() {
  test('TDW-DTO-06: before the seed is installed, dtoFromJson throws a '
      'StateError that says so', () {
    expect(
      () => dtoFromJson<TodoItemDto>(const {'id': '1'}),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Reflection has not been initialized'),
        ),
      ),
    );
  });

  test('TDW-DTO-07: for a type the seed does not cover, it throws '
      'NoSuchCapabilityError naming the type', () {
    initializeReflection();
    expect(
      () => dtoFromJson<_Unreflected>(const {}),
      throwsA(
        isA<NoSuchCapabilityError>().having(
          (e) => e.toString(),
          'toString()',
          contains('_Unreflected'),
        ),
      ),
    );
  });
}
