/// A preference store whose repository nothing may reach.
///
/// `TomUserPreferences` refuses a call for two reasons before it issues a
/// statement — an illegal key, and no principal in the zone — and in both cases
/// the *ordering* is the point: the key arrives off a request URL, so a check
/// that ran after the query would be a check the column had already seen past,
/// and a caller that got as far as the table without being identified would be
/// writing an unowned row.
///
/// Ordering is not observable from the value a refused call throws, so
/// [UnreachableRepository] makes it observable: it fails the test the moment it
/// is touched. A stub that answered plausibly instead would let a check that ran
/// too late pass unnoticed, which is the one failure these suites exist to
/// catch. It is the assertion, not a stand-in for a database.
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

/// A repository that fails the test if anything reaches it.
class UnreachableRepository
    implements TomSqlDatasourceRepository<TomUserPreference, int> {
  @override
  dynamic noSuchMethod(Invocation invocation) => fail(
    'the repository was reached via ${invocation.memberName}: this call had to '
    'be refused before any statement was built',
  );
}

/// A [TomUserPreferences] over a repository nothing may reach.
TomUserPreferences preferenceStore() =>
    TomUserPreferences(UnreachableRepository());

/// Matches the refusal every operation raises outside a principal-carrying zone.
final Matcher throwsNoPrincipal = throwsA(
  isA<TomException>().having(
    (error) => error.key,
    'key',
    'preferences.no_principal',
  ),
);
