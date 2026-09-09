/// The `TomUserPreferences` behaviour that needs no database — how the service
/// is found, and what it does when the caller cannot be.
///
/// The service takes no principal parameter: it reads the caller from the
/// request zone, which is what keeps the value a handler stores and the row
/// `@TomDbScope(field: 'principal_id', scope: 'owner')` permits it to store from
/// ever disagreeing. The consequence is this file's larger subject — outside a
/// zone carrying one, there is nothing to read and nothing to own, so every
/// operation has to refuse, and refuse before it reaches the table.
///
/// *Which* method performs the lookup is an implementation detail and moves; the
/// suite is written against the public surface so that it can.
///
/// [TomUserPreferences.resolve] is here for the same reason: it is a static bean
/// lookup that touches no repository, and its answer for an unwired deployment
/// is a deliberate `null` rather than a throw — a choice the module is designed
/// around and which would otherwise be pinned nowhere.
///
/// The round trip, the scope, and one principal's inability to read another's
/// are only answerable against a real server — see `preferences_db_test.dart`.
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

// A repository resolves its entity through reflection at construction, so the
// bootstrap is needed even though no statement is ever issued here.
import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/unreachable_repository.dart';

void main() {
  setUpAll(initializeReflection);

  group('resolve answers the installed store, or nothing', () {
    // The bean context is process-global, so each test leaves it as it found it
    // rather than letting the next one inherit a registration. Without this the
    // "no bean" case would pass or fail on test order, which is the one way a
    // test of an absence can be worthless.
    tearDown(TomBean.resetBeanContext);

    test('null when no bean is installed', () {
      // The behaviour the module is designed around: a preference is optional by
      // nature, so a deployment that never created `tom_user_preference` falls
      // back to whatever its callers used before rather than failing. A throw
      // here would make installing the table mandatory for every deployment.
      expect(TomUserPreferences.resolve(), isNull);
    });

    test('the installed instance when one is', () {
      // The complement. Without it an implementation that answered `null`
      // unconditionally would satisfy the test above, and every consumer would
      // quietly take its fallback path against a store that was wired
      // correctly.
      final store = preferenceStore();
      TomBean.withType(TomUserPreferences, store);

      expect(TomUserPreferences.resolve(), same(store));
    });

    test('null when the type is bound to something that is not a store', () {
      // `resolve` type-tests what it finds instead of casting it. A deployment
      // that bound the key to the wrong object is mis-wired either way, but the
      // type test keeps the failure shaped like the absence it is — the caller
      // takes its fallback — rather than a cast error raised at whichever
      // consumer happened to ask first.
      TomBean.overrideWithType(TomUserPreferences, 'not a store');

      expect(TomUserPreferences.resolve(), isNull);
    });
  });

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
