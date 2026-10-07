/// Pins the error key of the scope-identity refusals that no other test names.
///
/// [TomScopeException] carries a key so a caller can tell an id that cannot be
/// joined into a path from a scope that was used before it had an identity at
/// all. `scope_ids_test.dart` asserts what each refusal says and which value
/// it names, but not the key — and a key no test names is a failure mode
/// nobody checks: it could be renamed or raised from the wrong branch and
/// every run would still pass.
library;

import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// A mixin scope whose identity is assigned after construction, so it can be
/// observed before `initScope` has run.
class _LateScope with TomScopeMixin {}

/// Matches a [TomScopeException] whose key is exactly [key].
Matcher _throwsKey(String key) =>
    throwsA(isA<TomScopeException>().having((e) => e.key, 'key', key));

void main() {
  test('an empty scope id is refused under scope_ids.init_scope.empty_id', () {
    expect(
      () => _LateScope().initScope(scopeId: ''),
      _throwsKey('scope_ids.init_scope.empty_id'),
    );
  });

  test('a scope used before initScope is refused under '
      'scope_ids.use_scope.no_identity', () {
    expect(
      () => _LateScope().runInScope(() {}),
      _throwsKey('scope_ids.use_scope.no_identity'),
    );
  });
}
