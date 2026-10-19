/// DB-backed tests for the server-stored user preference store.
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
import 'dart:convert';

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
    id: '$userId',
    username: 'user$userId',
    firstname: 'Test',
    lastname: 'User',
    attributes: {},
    timezone: 'utc',
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
      : 'No ${TestDatabase.engine} server reachable on ${TestDatabase.host}:${TestDatabase.port} — '
            'start one with tool/run_db_tests.sh or tool/run_db_tests_postgres.sh';

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

      expect(
        await asSession(7, (p) => p.getOr<String>('theme', 'light')),
        'dark',
      );
      expect(
        await asSession(7, (p) => p.getOr<String>('other', 'light')),
        'light',
      );
    });

    test(
      'writing the same key twice replaces the value in the same row',
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
      },
    );

    test('all() lists the calling principal\'s preferences', () async {
      await asSession(7, (p) => p.set('theme', 'dark'));
      await asSession(7, (p) => p.set('fontSize', 14));

      final all = await asSession(7, (p) => p.all());
      expect(
        all.map((dto) => dto.key),
        containsAll(<String>['theme', 'fontSize']),
      );
    });

    test('all() lists preferences by key, not by insertion order', () async {
      // Written in an order that is neither alphabetical nor its reverse, so a
      // list that merely echoes the write sequence — or the row ids, which
      // follow it — fails rather than passing by coincidence.
      await asSession(7, (p) async {
        await p.set('theme', 'dark');
        await p.set('account.language', 'de');
        await p.set('zoom', 1.25);
        await p.set('account.pageSize', 25);
      });

      final all = await asSession(7, (p) => p.all());
      // An exact sequence, not a set: the order is the contract the three
      // documents state, so an unordered matcher would leave it unasserted.
      expect(all.map((dto) => dto.key).toList(), <String>[
        'account.language',
        'account.pageSize',
        'theme',
        'zoom',
      ]);
    });

    test('keys differing only in case are two preferences', () async {
      // The unique key is the preference's identity. Under a case-insensitive
      // collation the second write would overwrite the first and still
      // succeed, so a preference moving in from the device store - which
      // keeps both - would lose its sibling with nothing reported.
      await asSession(7, (p) async {
        await p.set('device.Theme', 'upper');
        await p.set('device.theme', 'lower');
      });

      expect(await asSession(7, (p) => p.get<String>('device.Theme')), 'upper');
      expect(await asSession(7, (p) => p.get<String>('device.theme')), 'lower');
      expect(await asSession(7, (p) => p.all()), hasLength(2));
    });

    test('keys differing only in case list by code unit', () async {
      // The contract is code-unit order, which puts every uppercase letter
      // before every lowercase one; the device store answers the same.
      await asSession(7, (p) async {
        await p.set('theme', 'b');
        await p.set('Theme', 'a');
      });

      final all = await asSession(7, (p) => p.all());
      expect(all.map((dto) => dto.key).toList(), <String>['Theme', 'theme']);
    });

    test('all() lists in the same order across sessions', () async {
      await asSession(7, (p) async {
        await p.set('theme', 'dark');
        await p.set('account.language', 'de');
        await p.set('zoom', 1.25);
      });
      final first = await asSession(7, (p) => p.all());

      // Rewriting a value touches the row without changing the key, so a list
      // that followed storage rather than the key would reorder here — which is
      // exactly the drift the documented order exists to rule out.
      await asSession(7, (p) => p.set('theme', 'light'));
      final second = await asSession(7, (p) => p.all());

      expect(
        second.map((dto) => dto.key).toList(),
        first.map((dto) => dto.key).toList(),
      );
    });

    test(
      'remove deletes the preference and reports whether it existed',
      () async {
        await asSession(7, (p) => p.set('theme', 'dark'));

        expect(await asSession(7, (p) => p.remove('theme')), isTrue);
        expect(await asSession(7, (p) => p.get<String>('theme')), isNull);
        // A second removal reports false rather than throwing: "was never there"
        // is an ordinary answer, not a failure.
        expect(await asSession(7, (p) => p.remove('theme')), isFalse);
      },
    );

    test('a write records the server\'s UTC timestamp', () async {
      final before = DateTime.now().toUtc().subtract(
        const Duration(seconds: 2),
      );

      final dto = await asSession(7, (p) => p.set('theme', 'dark'));

      expect(dto.updatedAt, isNotNull);
      expect(dto.updatedAt!.isUtc, isTrue);
      expect(dto.updatedAt!.isBefore(before), isFalse);
    });

    test('a replace moves the timestamp forward', () async {
      // "When was this written" has to mean the *last* write, or the field
      // answers a different question than its name — and the upsert reuses the
      // found row, so a stamp assigned only on insert would keep answering
      // when the preference was first created while the value changed under
      // it. That is the shape this asserts against, not merely that a stamp
      // exists.
      final first = await asSession(7, (p) => p.set('theme', 'dark'));
      // The column is DATETIME(6) and the write is fast, so two stamps can
      // land in the same microsecond; a pause makes "moved forward" a question
      // about the code rather than about the clock's resolution.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final second = await asSession(7, (p) => p.set('theme', 'light'));

      expect(
        second.updatedAt!.isAfter(first.updatedAt!),
        isTrue,
        reason:
            'first ${first.updatedAt} (${first.value}), '
            'second ${second.updatedAt} (${second.value})',
      );
      expect(await asSession(7, (p) => p.get<String>('theme')), 'light');
    });

    test('the endpoint\'s encoded write path stamps it too', () async {
      // `setEncoded` is the path a request takes, and it reaches the same
      // writer — so a stamp added to `set` alone would leave every preference
      // written over HTTP without one.
      final dto = await asSession(
        7,
        (p) => p.setEncoded(
          'ui.rows',
          valueType: TomUserPreferenceCodec.intType,
          valueJson: '20',
        ),
      );

      expect(dto.updatedAt, isNotNull);
      expect(dto.updatedAt!.isUtc, isTrue);
    });

    test('the stamp survives the round trip through the column', () async {
      // The DTO the writer returns is built in memory; the one a later session
      // reads comes back through DATETIME(6) and the instant convention. Both
      // have to answer the same moment, or "when was this written" depends on
      // who is asking.
      final written = await asSession(7, (p) => p.set('theme', 'dark'));

      final readBack = await asSession(7, (p) => p.read('theme'));

      expect(readBack!.updatedAt!.isUtc, isTrue);
      expect(
        readBack.updatedAt!.isAtSameMomentAs(written.updatedAt!),
        isTrue,
        reason:
            'the stored instant and the one the write returned are the same '
            'moment, so a client that re-reads sees the stamp it was given',
      );
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

    test(
      'the same key under two principals is two rows, not a collision',
      () async {
        await asSession(7, (p) => p.set('theme', 'dark'));
        await asSession(8, (p) => p.set('theme', 'light'));

        expect(await rawRows(), hasLength(2));
        expect(await asSession(7, (p) => p.get<String>('theme')), 'dark');
        expect(await asSession(8, (p) => p.get<String>('theme')), 'light');
      },
    );

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

    test(
      'clear removes every preference of the caller and no other\'s',
      () async {
        await asSession(7, (p) async {
          await p.set('theme', 'dark');
          await p.set('zoom', 1.25);
          await p.set('account.language', 'de');
        });
        await asSession(8, (p) => p.set('theme', 'light'));

        expect(await asSession(7, (p) => p.clear()), 3);

        expect(await asSession(7, (p) => p.all()), isEmpty);
        // The other principal's row is untouched. A bulk delete is the statement
        // where forgetting the scope costs the most — one predicate away from
        // every account on the server — so this is asserted against a second
        // real principal rather than against the caller's own view.
        expect(await asSession(8, (p) => p.get<String>('theme')), 'light');
        expect(await rawRows(), hasLength(1));
      },
    );

    test('clear is idempotent and answers how many rows went', () async {
      await asSession(7, (p) => p.set('theme', 'dark'));

      expect(await asSession(7, (p) => p.clear()), 1);
      // A second clear is not a failure: an account already holding nothing has
      // already reached the state a reset asks for.
      expect(await asSession(7, (p) => p.clear()), 0);
    });

    test('clear inside an unscoped bypass is still only the caller\'s', () async {
      await asSession(7, (p) async {
        await p.set('theme', 'dark');
        await p.set('zoom', 1.25);
      });
      await asSession(8, (p) => p.set('theme', 'light'));

      // `TomDataScope.runUnscoped` is an administrative bypass: inside it the
      // row scope adds no predicate at all. Every read in this service still
      // names the principal for that reason, and this is the statement where
      // relying on the scope instead would delete every account's preferences
      // on the server. Asserted rather than left to the dartdoc that claims it.
      expect(
        await TomDataScope.runUnscoped(() => asSession(7, (p) => p.clear())),
        2,
      );

      expect(await rawRows(), hasLength(1));
      expect(await asSession(8, (p) => p.get<String>('theme')), 'light');
    });

    test('clear without a principal is refused rather than unscoped', () async {
      final preferences = TomUserPreferences(TomUserPreferenceRepository());
      await asSession(7, (p) => p.set('theme', 'dark'));

      // The one operation where an unscoped run would delete every principal's
      // preferences, so "no caller" has to be a refusal and not a wide
      // predicate.
      await expectLater(
        preferences.clear(),
        throwsA(isA<TomUserPreferenceException>()),
      );
      expect(await rawRows(), hasLength(1));
    });

    test('a read without a principal is refused rather than unscoped', () async {
      final preferences = TomUserPreferences(TomUserPreferenceRepository());
      // No zone, so no caller. Answering *something* here would mean answering
      // from an unscoped query — every principal's rows — which is the one
      // outcome that must not be reachable.
      await expectLater(
        preferences.get<String>('theme'),
        throwsA(isA<TomUserPreferenceException>()),
      );
    });

    test(
      'getFor reads a named principal\'s preference outside a request',
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
      },
    );

    // ------------------------------------------------------------------
    // The store is bounded
    // ------------------------------------------------------------------

    /// Fills [userId]'s preferences to the ceiling with raw rows `k000`,
    /// `k001`, … — one statement rather than 256 service writes, and outside
    /// the service so the ceiling under test is not what placed them.
    Future<void> fillToCeiling(int userId) async {
      final rows = [
        for (var i = 0; i < tomUserPreferencesMaxPerPrincipal; i++)
          "($userId, 'k${i.toString().padLeft(3, '0')}', 'String', '\"x\"', "
              "'2026-01-01 00:00:00')",
      ];
      await dsi.datasource.executeCommand(
        'INSERT INTO tom_user_preference '
        '(principal_id, preference_key, value_type, value_json, updated_at) '
        'VALUES ${rows.join(', ')}',
      );
    }

    test('a principal at the ceiling cannot add another key', () async {
      await fillToCeiling(7);

      await expectLater(
        asSession(7, (p) => p.set('one.too.many', 'x')),
        throwsA(
          isA<TomUserPreferenceException>()
              .having(
                (error) => error.key,
                'key',
                tomUserPreferencesLimitExceededErrorKey,
              )
              .having(
                (error) => error.parameters?['limit'],
                'limit',
                tomUserPreferencesMaxPerPrincipal,
              ),
        ),
      );
      expect(await rawRows(), hasLength(tomUserPreferencesMaxPerPrincipal));
    });

    test('the ceiling admits exactly its own number of keys', () async {
      // One short of the ceiling, the next new key is still accepted: the
      // bound is "at most", not "fewer than".
      await fillToCeiling(7);
      await asSession(7, (p) => p.remove('k000'));

      await asSession(7, (p) => p.set('the.last.place', 'x'));

      expect(await rawRows(), hasLength(tomUserPreferencesMaxPerPrincipal));
    });

    test('at the ceiling a held key can still be replaced', () async {
      // The ceiling bounds how many preferences exist, not how often they
      // change: a full account must still be able to change every setting
      // it has.
      await fillToCeiling(7);

      await asSession(7, (p) => p.set('k000', 'changed'));

      expect(await asSession(7, (p) => p.get<String>('k000')), 'changed');
      expect(await rawRows(), hasLength(tomUserPreferencesMaxPerPrincipal));
    });

    test('a window over all() narrows in the contract order', () async {
      // The other half of `all([page])`: `preferences_service_test.dart`
      // asserts the window is *forwarded*, and whether it narrows is the
      // repository's answer, which needs a table.
      //
      // The rows are `k000` … `k255`, so the expected page is arithmetic
      // rather than a copy of what the store happened to return — a page
      // asserted against itself would pass whatever the window did.
      await fillToCeiling(7);

      final unpaged = await asSession(7, (p) => p.all());
      final firstPage = await asSession(
        7,
        (p) => p.all(TomPageRequest(limit: 10)),
      );
      final thirdPage = await asSession(
        7,
        (p) => p.all(TomPageRequest(limit: 10, offset: 20)),
      );

      expect(unpaged, hasLength(tomUserPreferencesMaxPerPrincipal));
      expect(firstPage.map((dto) => dto.key), [
        for (var i = 0; i < 10; i++) 'k${i.toString().padLeft(3, '0')}',
      ]);
      expect(thirdPage.map((dto) => dto.key), [
        for (var i = 20; i < 30; i++) 'k${i.toString().padLeft(3, '0')}',
      ]);
    });

    test('a window stays inside the caller\'s own rows', () async {
      // The window narrows the answer; it does not widen who it is about. A
      // page that reached past the principal would be the scope failing under
      // a LIMIT, which is exactly where a filter applied in the wrong order
      // stops being visible.
      await fillToCeiling(7);
      await asSession(8, (p) => p.set('k000', 'theirs'));

      final page = await asSession(8, (p) => p.all(TomPageRequest(limit: 10)));

      expect(page.map((dto) => dto.key), ['k000']);
      expect(await asSession(8, (p) => p.get<String>('k000')), 'theirs');
    });

    test('the ceiling is counted per principal', () async {
      await fillToCeiling(7);

      await asSession(8, (p) => p.set('theme', 'dark'));

      expect(await asSession(8, (p) => p.get<String>('theme')), 'dark');
    });

    test('an oversized value is refused before it reaches the table', () async {
      // The column holds 64 KiB; the codec's ceiling is well inside it, so a
      // value is refused as the caller's mistake rather than failing in the
      // database as a fault of the server's.
      await expectLater(
        asSession(
          7,
          (p) => p.setEncoded(
            'ui.notes',
            valueType: TomUserPreferenceCodec.stringType,
            valueJson: jsonEncode('a' * TomUserPreferenceCodec.maxValueBytes),
          ),
        ),
        throwsA(
          isA<TomUserPreferenceCodecException>().having(
            (error) => error.key,
            'key',
            'preferences.encoded.too_large',
          ),
        ),
      );
      expect(await rawRows(), isEmpty);
    });

    // ------------------------------------------------------------------
    // Typed values round-trip
    // ------------------------------------------------------------------

    test(
      'a rewrite may change a key\'s type, and a typed reader then fails',
      () async {
        // `setEncoded` checks the pair it is handed against itself, not against
        // the row it replaces — so the second write succeeds and the first
        // writer's typed read throws from then on. Pinned for the limitation in
        // doc/preferences.md; when the write starts refusing a type change, the
        // bullet goes.
        await asSession(7, (p) => p.set('theme', 'dark'));
        await asSession(7, (p) => p.set('theme', 3));
        await asSession(7, (p) async {
          await expectLater(
            () => p.get<String>('theme'),
            throwsA(isA<TomUserPreferenceCodecException>()),
          );
        });
      },
    );

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

    test(
      'reading a preference as the wrong type is refused, not coerced',
      () async {
        await asSession(7, (p) => p.set('count', 42));

        await expectLater(
          asSession(7, (p) => p.get<String>('count')),
          throwsA(isA<TomUserPreferenceCodecException>()),
        );
      },
    );

    test(
      'setEncoded stores a pre-encoded value and rejects a mismatched one',
      () async {
        await asSession(
          7,
          (p) =>
              p.setEncoded('theme', valueType: 'String', valueJson: '"dark"'),
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
      },
    );
  }, skip: skipReason);
}
