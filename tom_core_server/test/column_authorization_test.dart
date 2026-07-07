import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

/// C-4 (G-AUTHZ-4) column-level access-rights tests, verified reflection-free.
///
/// The done-bar is "a read masks unauthorized columns; a write to a read-only
/// column is rejected server-side; both tested". The repository's read-mask and
/// write-enforcement both delegate to the *pure* decision core in
/// [TomColumnAuthorization] ([maskedColumns], [decideWrites], [stateForKey]),
/// which takes value/key accessors as callbacks so it runs without a database
/// or the reflection runtime. These tests exercise that core directly over
/// plain string column tokens with a stub [TomColumnAuthResolver], asserting the
/// same masking and write outcomes the repository's reflection path relies on.

/// A stub resolver mapping resource keys to grades; any unmapped key denies
/// (state [TomAuthState.none]) so a test must opt a column into a grade.
TomColumnAuthResolver _resolver(Map<String, TomAuthState> grades) =>
    (key) => grades[key] ?? TomAuthState.none;

/// A partition sentinel: rejection means [onForbidden] fired.
Never _reject(String column, String authKey, TomAuthState grade) =>
    throw StateError('forbidden:$column:$authKey:${grade.name}');

void main() {
  group('stateForKey', () {
    test('a null authKey is an unrestricted column (full)', () {
      expect(TomColumnAuthorization.stateForKey(null), TomAuthState.full);
    });

    test('a non-null key resolves through the provided resolver', () {
      final resolver = _resolver({'secret': TomAuthState.none});
      expect(
        TomColumnAuthorization.stateForKey('secret', resolver: resolver),
        TomAuthState.none,
      );
      // An unmapped key falls to the stub's deny default.
      expect(
        TomColumnAuthorization.stateForKey('other', resolver: resolver),
        TomAuthState.none,
      );
    });
  });

  group('maskedColumns (read projection)', () {
    // salary is masked (none), ssn is masked (disabled), name is read, age full.
    final resolver = _resolver({
      'k.salary': TomAuthState.none,
      'k.ssn': TomAuthState.disabled,
      'k.name': TomAuthState.read,
      'k.age': TomAuthState.full,
    });
    final keys = {
      'salary': 'k.salary',
      'ssn': 'k.ssn',
      'name': 'k.name',
      'age': 'k.age',
      'note': null, // unrestricted column
    };

    test('masks exactly the columns whose grade lacks showsContent', () {
      final masked = TomColumnAuthorization.maskedColumns<String>(
        columns: keys.keys,
        keyOf: (c) => keys[c],
        resolver: resolver,
      );
      // none + disabled are masked; read + full + unrestricted are not.
      expect(masked, unorderedEquals(['salary', 'ssn']));
    });

    test('an all-unrestricted column set masks nothing', () {
      final masked = TomColumnAuthorization.maskedColumns<String>(
        columns: const ['a', 'b'],
        keyOf: (_) => null,
        resolver: resolver,
      );
      expect(masked, isEmpty);
    });
  });

  group('decideWrites (write enforcement)', () {
    // grade: full=writable, read=visible-not-editable, disabled/none=masked.
    final resolver = _resolver({
      'k.title': TomAuthState.full,
      'k.status': TomAuthState.read,
      'k.salary': TomAuthState.none,
      'k.ssn': TomAuthState.disabled,
    });
    final keys = {
      'title': 'k.title',
      'status': 'k.status',
      'salary': 'k.salary',
      'ssn': 'k.ssn',
      'note': null,
    };

    TomColumnWriteDecision<String> decide(Set<String> changed) {
      return TomColumnAuthorization.decideWrites<String>(
        columns: keys.keys,
        gradeOf: (c) => keys[c],
        changed: changed.contains,
        onForbidden: _reject,
        resolver: resolver,
      );
    }

    test('full and unrestricted columns are writable; the rest preserved', () {
      // Nothing changed → no rejection possible; partition is by grade only.
      final decision = decide(const {});
      expect(decision.writable, unorderedEquals(['title', 'note']));
      expect(
        decision.preserved,
        unorderedEquals(['status', 'salary', 'ssn']),
      );
    });

    test('a changed visible (read) column is a rejectable violation', () {
      expect(
        () => decide({'status'}),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'forbidden:status:k.status:read',
          ),
        ),
      );
    });

    test('an unchanged read column is preserved, not rejected', () {
      final decision = decide(const {});
      expect(decision.preserved, contains('status'));
    });

    test('a changed masked (none/disabled) column is preserved silently', () {
      // Round-tripped masked-null differs from the stored value, so it is
      // "changed" — but a masked column must never reject; it is overlaid.
      final decision = decide({'salary', 'ssn'});
      expect(decision.preserved, containsAll(['salary', 'ssn']));
      expect(decision.writable, unorderedEquals(['title', 'note']));
    });

    test('a changed full column is written without objection', () {
      final decision = decide({'title'});
      expect(decision.writable, contains('title'));
    });
  });
}
