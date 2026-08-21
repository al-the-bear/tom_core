/// The server half of the preference-key rule.
///
/// The rule itself lives in `tom_core_kernel` and is tested there. Two things
/// about it are only answerable here:
///
///  * **the store refuses an illegal key**, and refuses it *first* — before the
///    caller is identified and before a statement is issued. The server reads
///    the key off the request URL, so on this side it is untrusted input, and a
///    check that ran after the query would be a check the column had already
///    seen past;
///  * **the length cap and the column agree.** `maxLength` is not a taste: it
///    is `preference_key`'s own width. If the DDL widened and the constant did
///    not, keys the store accepts would be silently truncated; if the constant
///    grew and the DDL did not, two keys differing past the cut would collide
///    on the unique key. Neither is visible by reading one file.
///
/// No database is needed for either: the refusal happens before the repository
/// is reached, and the DDL is a constant.
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

// A repository resolves its entity through reflection at construction, so the
// bootstrap is needed even though no statement is ever issued here.
import 'fixtures/reflection_fixture.reflection.dart';

/// A repository that fails the test if anything reaches it.
///
/// Not a stub standing in for a database, but the assertion itself: every call
/// below is expected to be refused *before* a statement is built, and a
/// repository that answered plausibly would let a check that ran too late pass
/// unnoticed.
class _UnreachableRepository
    implements TomSqlDatasourceRepository<TomUserPreference, int> {
  @override
  dynamic noSuchMethod(Invocation invocation) => fail(
    'the repository was reached via '
    '${invocation.memberName}: an illegal key must be refused before any '
    'statement is built',
  );
}

/// The store over a repository nothing may reach.
TomUserPreferences _store() => TomUserPreferences(_UnreachableRepository());

/// The `preference_key` width [TomUserPreference.createTableSql] declares.
int _declaredKeyColumnWidth() {
  final match = RegExp(
    r'preference_key\s+VARCHAR\((\d+)\)',
    caseSensitive: false,
  ).firstMatch(TomUserPreference.createTableSql);
  if (match == null) {
    fail('createTableSql no longer declares a preference_key VARCHAR column');
  }
  return int.parse(match.group(1)!);
}

/// Matches the refusal a key violating `TomUserPreferenceKeys` raises.
final Matcher throwsKeyRefusal = throwsA(
  isA<TomException>().having(
    (error) => error.key,
    'key',
    'preferences.key.invalid',
  ),
);

void main() {
  setUpAll(initializeReflection);

  group('the length cap is the column', () {
    test('maxLength equals the declared preference_key width', () {
      expect(
        TomUserPreferenceKeys.maxLength,
        _declaredKeyColumnWidth(),
        reason:
            'a cap wider than the column stores keys truncated; a cap '
            'narrower than it refuses keys the column would hold',
      );
    });

    test('a key of exactly maxLength is accepted', () {
      // The boundary belongs to the legal side: the column holds 191, so 191
      // has to be storable, not one short of it.
      expect(
        TomUserPreferenceKeys.isValid('a' * TomUserPreferenceKeys.maxLength),
        isTrue,
      );
    });
  });

  group('TomUserPreferences refuses an illegal key before anything else', () {
    // No principal is installed in the zone, so any of these calls that got
    // past the key check would fail with `preferences.no_principal` instead —
    // which is precisely what makes these assertions about *ordering* and not
    // merely about the key being rejected somewhere along the way.

    test('read refuses a key carrying a separator', () {
      expect(() => _store().read('a/b'), throwsKeyRefusal);
    });

    test('read refuses the empty key', () {
      expect(() => _store().read(''), throwsKeyRefusal);
    });

    test('set refuses an illegal key even with an encodable value', () {
      expect(() => _store().set('a/b', 'dark'), throwsKeyRefusal);
    });

    test('setEncoded refuses an illegal key even with a valid pair', () {
      expect(
        () => _store().setEncoded(
          'has space',
          valueType: 'String',
          valueJson: '"dark"',
        ),
        throwsKeyRefusal,
      );
    });

    test('remove refuses an illegal key', () {
      expect(() => _store().remove('..'), throwsKeyRefusal);
    });

    test('a legal key gets past the check and fails for the real reason', () {
      // The complement of the group: without it, a check that refused every
      // key would satisfy every test above.
      expect(
        () => _store().read(TomUserPreferenceKeys.theme),
        throwsA(
          isA<TomException>().having(
            (error) => error.key,
            'key',
            'preferences.no_principal',
          ),
        ),
      );
    });
  });
}
