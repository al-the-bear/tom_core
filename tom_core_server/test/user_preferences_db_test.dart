/// DB-backed tests for the server-stored user preference store (TCCA10).
///
/// The codec's *contract* — which type name a value is written under, that a
/// mismatched read is refused rather than coerced — is covered without a
/// database in `tom_core_kernel`. This file exercises the three things only a
/// real server can answer:
///
///  * a preference written in one session is read back in another, so the value
///    genuinely lives in `tom_user_preference` and not in a service instance;
///  * **one principal cannot read another's.** That is the whole reason the
///    entity carries `@TomDbScope(field: 'principal_id', scope: 'owner')` rather
///    than an ownership `if` in a handler, so the assertion has to be made
///    across two real principals against the real scoped query — a service
///    agreeing with itself would prove nothing; and
///  * a reflected value survives the round trip as an *object*, which is what
///    separates a typed preference from a stringly-typed blob.
///
/// The whole group is `@Tags(['db'])` and skips itself when no MariaDB is
/// reachable, so the default `testkit :test` run stays green everywhere. Bring a
/// server up with `tool/run_db_tests.sh` to run it.
@Tags(['db'])
library;

import 'dart:async';

import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

import 'fixtures/reflection_fixture.dart';
import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

/// A principal whose [TomPrincipal.id] is [userId] — the value the `'owner'`
/// scope resolver binds into `principal_id`.
TomPrincipal _principalWithId(int userId) => TomPrincipal(
  authenticated: true,
  context: {},
  clientId: 0,
  organization: 'acme',
  organizationId: 0,
  application: 'console',
  applicationId: 0,
  process: 'login',
  processId: 0,
  language: 'en',
  country: 'US',
  clientCountry: 'US',
  clientLanguage: 'en',
  clientTimezone: 'UTC',
  user: TomUser(
    id: userId,
    username: 'user$userId',
    firstname: 'Test',
    lastname: 'User',
    attributes: {},
    timeZone: 'utc',
  ),
  aci: TomAccessControlInformation(roles: const ['user']),
);

/// A whole-second UTC timestamp: a `DateTime` preference is written in UTC by
/// contract, and a `DateTime.now()` here would carry a local offset and
/// sub-second digits, failing the round trip for reasons that are not the
/// store's.
final DateTime _instant = DateTime.utc(2026, 3, 4, 5, 6, 7);

void main() async {
  // Probe once, before declaring the group, so the group can skip when nothing
  // is listening — keeping the default run green with no database.
  final reachable = await TestDatabase.isReachable();
  final String? skipReason = reachable
      ? null
      : 'MariaDB not reachable on ${TestDatabase.host}:${TestDatabase.port} — '
            'start one with tool/run_db_tests.sh';

  group('TomUserPreferences (DB-backed)', () {
    late TomDataSourceInfo dsi;

    setUpAll(() async {
      initializeReflection();
      dsi = await TestDatabase.register();
      // TomUserPreference declares `datasource: 'main'`, the name a deployment
      // configures. Aliasing rather than renaming keeps the entity under test
      // identical to the one that ships.
      await TestDatabase.registerMainAlias();
      await TestDatabase.ensureUserPreferenceTable(dsi);
    });

    setUp(() async {
      await TestDatabase.truncateUserPreference(dsi);
    });

    tearDownAll(TestDatabase.reset);

    /// Runs [body] as [userId] would — a request zone carrying that principal,
    /// over a **freshly constructed** service and repository.
    ///
    /// Both halves matter. The zone is where the service and the row scope both
    /// find the caller, so this is the only way to exercise either as a request
    /// does. The fresh instances are what make a "session" mean something: a
    /// value read back through the same object could have come from a field
    /// rather than from the table.
    Future<T> asSession<T>(
      int userId,
      Future<T> Function(TomUserPreferences preferences) body,
    ) {
      final preferences = TomUserPreferences(TomUserPreferenceRepository());
      return runZoned(
        () => body(preferences),
        zoneValues: <Object, Object?>{TomPrincipal: _principalWithId(userId)},
      );
    }

    /// Reads the table without going through the service, so an assertion about
    /// storage cannot be satisfied by the service agreeing with itself.
    ///
    /// Unscoped by construction: it is raw SQL rather than a repository call, so
    /// it sees every principal's rows and can prove that a row another principal
    /// cannot *read* is nevertheless there.
    Future<List<TomUserPreference>> rawRows() =>
        dsi.datasource.executeQuery<TomUserPreference>(
          'SELECT id, principal_id, preference_key, value_type, value_json, '
          'updated_at FROM tom_user_preference ORDER BY id',
        );

    // ------------------------------------------------------------------
    // A preference set in one session is read in another
    // ------------------------------------------------------------------

    test('a preference written in one session is read in another', () async {
      await asSession(7, (p) => p.set(TomUserPreferenceKeys.timezone, 'CET'));

      final read = await asSession(
        7,
        (p) => p.get<String>(TomUserPreferenceKeys.timezone),
      );
      expect(read, 'CET');
    });

    test('a preference that was never written reads as null', () async {
      expect(await asSession(7, (p) => p.get<String>('ghost')), isNull);
    });

    test('getOr answers the fallback only for an unwritten key', () async {
      await asSession(7, (p) => p.set('theme', 'dark'));

      expect(await asSession(7, (p) => p.getOr<String>('theme', 'light')),
          'dark');
      expect(await asSession(7, (p) => p.getOr<String>('other', 'light')),
          'light');
    });

    test('writing the same key twice replaces the value in the same row',
        () async {
      await asSession(7, (p) => p.set('theme', 'dark'));
      final firstId = (await rawRows()).single.id;

      await asSession(7, (p) => p.set('theme', 'light'));

      final rows = await rawRows();
      // One row, not two: `(principal_id, preference_key)` *is* the
      // preference's identity, so a second row would make the value a user
      // gets depend on row order.
      expect(rows, hasLength(1));
      expect(rows.single.id, firstId);
      expect(await asSession(7, (p) => p.get<String>('theme')), 'light');
    });

    test('all() lists the calling principal\'s preferences', () async {
      await asSession(7, (p) => p.set('theme', 'dark'));
      await asSession(7, (p) => p.set('fontSize', 14));

      final all = await asSession(7, (p) => p.all());
      expect(all.map((dto) => dto.key), containsAll(<String>[
        'theme',
        'fontSize',
      ]));
    });

    test('remove deletes the preference and reports whether it existed',
        () async {
      await asSession(7, (p) => p.set('theme', 'dark'));

      expect(await asSession(7, (p) => p.remove('theme')), isTrue);
      expect(await asSession(7, (p) => p.get<String>('theme')), isNull);
      // A second removal reports false rather than throwing: "was never there"
      // is an ordinary answer, not a failure.
      expect(await asSession(7, (p) => p.remove('theme')), isFalse);
    });

    test('a write records the server\'s UTC timestamp', () async {
      final before = DateTime.now().toUtc().subtract(
        const Duration(seconds: 2),
      );

      final dto = await asSession(7, (p) => p.set('theme', 'dark'));

      expect(dto.updatedAt, isNotNull);
      expect(dto.updatedAt!.isUtc, isTrue);
      expect(dto.updatedAt!.isBefore(before), isFalse);
    });

    // ------------------------------------------------------------------
    // One principal cannot read another's
    // ------------------------------------------------------------------

    test('one principal cannot read another\'s preference', () async {
      await asSession(7, (p) => p.set('theme', 'dark'));

      // Not "reads a different value" — reads *nothing*. The row is never
      // selected, because the scope ANDs `principal_id IN (…)` into the query
      // from the zone's principal.
      expect(await asSession(8, (p) => p.get<String>('theme')), isNull);
      expect(await asSession(8, (p) => p.all()), isEmpty);
      // And the row is genuinely still there — the read was denied, not the
      // write lost.
      expect(await rawRows(), hasLength(1));
    });

    test('the same key under two principals is two rows, not a collision',
        () async {
      await asSession(7, (p) => p.set('theme', 'dark'));
      await asSession(8, (p) => p.set('theme', 'light'));

      expect(await rawRows(), hasLength(2));
      expect(await asSession(7, (p) => p.get<String>('theme')), 'dark');
      expect(await asSession(8, (p) => p.get<String>('theme')), 'light');
    });

    test('one principal\'s write does not overwrite another\'s same-named '
        'preference', () async {
      await asSession(7, (p) => p.set('theme', 'dark'));
      await asSession(8, (p) => p.set('theme', 'light'));
      await asSession(8, (p) => p.set('theme', 'sepia'));

      expect(await asSession(7, (p) => p.get<String>('theme')), 'dark');
      expect(await rawRows(), hasLength(2));
    });

    test('one principal cannot remove another\'s preference', () async {
      await asSession(7, (p) => p.set('theme', 'dark'));

      expect(await asSession(8, (p) => p.remove('theme')), isFalse);
      expect(await asSession(7, (p) => p.get<String>('theme')), 'dark');
    });

    test('a read without a principal is refused rather than unscoped',
        () async {
      final preferences = TomUserPreferences(TomUserPreferenceRepository());
      // No zone, so no caller. Answering *something* here would mean answering
      // from an unscoped query — every principal's rows — which is the one
      // outcome that must not be reachable.
      await expectLater(
        preferences.get<String>('theme'),
        throwsA(isA<TomUserPreferenceException>()),
      );
    });

    test('getFor reads a named principal\'s preference outside a request',
        () async {
      await asSession(7, (p) => p.set(TomUserPreferenceKeys.timezone, 'CET'));

      // The authentication path's entry point: no request zone exists yet, so
      // the principal is supplied and installed by the call itself.
      final preferences = TomUserPreferences(TomUserPreferenceRepository());
      expect(
        await preferences.getFor<String>(
          _principalWithId(7),
          TomUserPreferenceKeys.timezone,
        ),
        'CET',
      );
      // Still scoped: naming a principal is not a bypass.
      expect(
        await preferences.getFor<String>(
          _principalWithId(8),
          TomUserPreferenceKeys.timezone,
        ),
        isNull,
      );
    });

    // ------------------------------------------------------------------
    // Typed values round-trip
    // ------------------------------------------------------------------

    test('scalar preferences round-trip as their own types', () async {
      await asSession(7, (p) async {
        await p.set('text', 'hello');
        await p.set('count', 42);
        await p.set('ratio', 1.5);
        await p.set('enabled', true);
        await p.set('since', _instant);
      });

      await asSession(7, (p) async {
        expect(await p.get<String>('text'), 'hello');
        expect(await p.get<int>('count'), 42);
        expect(await p.get<double>('ratio'), 1.5);
        expect(await p.get<bool>('enabled'), isTrue);
        final since = await p.get<DateTime>('since');
        expect(since, _instant);
        expect(since!.isUtc, isTrue);
      });
    });

    test('a reflected value round-trips as an object', () async {
      final stored = FixtureDisplayPreference()
        ..theme = 'solarized'
        ..fontSize = 13
        ..compact = true;

      await asSession(7, (p) => p.set('display', stored));

      final loaded = await asSession(
        7,
        (p) => p.get<FixtureDisplayPreference>('display'),
      );
      // Reconstructed, not merely returned: a different session over a fresh
      // service, so this instance came out of the table through reflection.
      expect(loaded, isNotNull);
      expect(loaded, isNot(same(stored)));
      expect(loaded!.theme, 'solarized');
      expect(loaded.fontSize, 13);
      expect(loaded.compact, isTrue);
      // The stored type name is the class's own, which is what a later read
      // matches against.
      expect(
        (await asSession(7, (p) => p.read('display')))!.valueType,
        'FixtureDisplayPreference',
      );
    });

    test('reading a preference as the wrong type is refused, not coerced',
        () async {
      await asSession(7, (p) => p.set('count', 42));

      await expectLater(
        asSession(7, (p) => p.get<String>('count')),
        throwsA(isA<TomUserPreferenceCodecException>()),
      );
    });

    test('setEncoded stores a pre-encoded value and rejects a mismatched one',
        () async {
      await asSession(
        7,
        (p) => p.setEncoded('theme', valueType: 'String', valueJson: '"dark"'),
      );
      expect(await asSession(7, (p) => p.get<String>('theme')), 'dark');

      // The endpoint's write path validates before it stores: a pair that
      // disagrees fails every later read of the key, on every device.
      await expectLater(
        asSession(
          7,
          (p) => p.setEncoded('bad', valueType: 'int', valueJson: '"dark"'),
        ),
        throwsA(isA<TomUserPreferenceCodecException>()),
      );
      expect(await asSession(7, (p) => p.read('bad')), isNull);
    });
  }, skip: skipReason);
}
