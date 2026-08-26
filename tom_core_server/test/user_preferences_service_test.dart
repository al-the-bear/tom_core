/// The `TomUserPreferences` behaviour that needs no database.
///
/// The service takes no principal parameter: it reads the caller from the
/// request zone, which is what keeps the value a handler stores and the row
/// `@TomDbScope(field: 'principal_id', scope: 'owner')` permits it to store from
/// ever disagreeing. The consequence is this file's subject — outside a zone
/// carrying one, there is nothing to read and nothing to own, so every operation
/// has to refuse, and refuse before it reaches the table.
///
/// *Which* method performs the lookup is an implementation detail and moves; the
/// suite is written against the public surface so that it can.
///
/// The round trip, the scope, and one principal's inability to read another's
/// are only answerable against a real server — see `user_preferences_db_test.dart`.
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

// A repository resolves its entity through reflection at construction, so the
// bootstrap is needed even though no statement is ever issued here.
import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/unreachable_repository.dart';

void main() {
  setUpAll(initializeReflection);

  group('every operation identifies the caller before it queries', () {
    // These run outside any zone, over a repository that fails the test if it is
    // reached, so each asserts both halves at once: the refusal is
    // `preferences.no_principal`, and nothing was asked of the database first.
    //
    // All seven entry points are here rather than a representative few. The
    // lookup is shared through private helpers, so any one of them can stop
    // performing it as a side effect of a change to a helper it delegates to —
    // and that is a failure no test of a *sibling* method would notice.

    test('all refuses when no principal is in the zone', () {
      expect(preferenceStore().all, throwsNoPrincipal);
    });

    test('read refuses when no principal is in the zone', () {
      expect(
        () => preferenceStore().read(TomUserPreferenceKeys.theme),
        throwsNoPrincipal,
      );
    });

    test('get refuses when no principal is in the zone', () {
      expect(
        () => preferenceStore().get<String>(TomUserPreferenceKeys.theme),
        throwsNoPrincipal,
      );
    });

    test('getOr refuses when no principal is in the zone', () {
      // Notably *not* answered with the fallback: the fallback stands in for a
      // preference that was never written, which is a state this call never got
      // close enough to the table to establish.
      expect(
        () => preferenceStore().getOr<String>(
          TomUserPreferenceKeys.theme,
          'light',
        ),
        throwsNoPrincipal,
      );
    });

    test('set refuses when no principal is in the zone', () {
      expect(
        () => preferenceStore().set(TomUserPreferenceKeys.theme, 'dark'),
        throwsNoPrincipal,
      );
    });

    test('setEncoded refuses when no principal is in the zone', () {
      expect(
        () => preferenceStore().setEncoded(
          TomUserPreferenceKeys.theme,
          valueType: 'String',
          valueJson: '"dark"',
        ),
        throwsNoPrincipal,
      );
    });

    test('remove refuses when no principal is in the zone', () {
      expect(
        () => preferenceStore().remove(TomUserPreferenceKeys.theme),
        throwsNoPrincipal,
      );
    });
  });
}
