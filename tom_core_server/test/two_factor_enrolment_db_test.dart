/// DB-backed tests for the persistent 2FA enrolment store (TCCA2).
///
/// The store's *contract* — what `enrolmentsFor` / `store` / `remove` mean, how
/// re-storing an enrolment id replaces rather than duplicates, how the TOTP
/// adaptor prefers the store over the legacy resolver hook — is covered against
/// `TomMemory2FAEnrolmentStore` in `two_factor_test.dart`, without a database.
///
/// This file exercises the two things only a real server can answer:
///
///  * a [Tom2FAEnrolment] written through [TomPersistent2FAEnrolmentStore]
///    survives a round trip through `tom_user_two_factor_enrolment` with every
///    field intact, and the `(principal_id, enrolment_id)` upsert really is one
///    row rather than two; and
///  * **the secret is unreadable in the raw row.** That is the whole reason the
///    store exists in this shape: a TOTP shared secret readable in a table (or
///    in a backup of one) is a complete 2FA bypass, so the assertion has to be
///    made against the column the database actually holds — not against
///    anything the store hands back, which would only prove the store can read
///    its own writes.
///
/// The whole group is `@Tags(['db'])` and skips itself when no MariaDB is
/// reachable, so the default `testkit :test` run stays green everywhere. Bring a
/// server up with `tool/run_db_tests.sh` to run it.
@Tags(['db'])
library;

import 'dart:convert';

import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

/// A principal whose [TomPrincipal.id] is [userId] — the value the store
/// stringifies into `principal_id`.
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

Tom2FAContext _context(int userId) =>
    Tom2FAContext(principal: _principalWithId(userId));

/// A real RFC 6238 test secret, so an accidental plaintext write would be
/// recognisable in a raw column dump — which is exactly what the secrecy test
/// looks for.
const String _secret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';

/// A whole-second timestamp: MariaDB's `DATETIME` carries no fractional part,
/// so a `DateTime.now()` here would fail the round trip on truncation alone and
/// say nothing about the store.
final DateTime _enrolledAt = DateTime.utc(2026, 3, 4, 5, 6, 7);

void main() async {
  // Probe once, before declaring the group, so the group can skip when nothing
  // is listening — keeping the default run green with no database.
  final reachable = await TestDatabase.isReachable();
  final String? skipReason = reachable
      ? null
      : 'MariaDB not reachable on ${TestDatabase.host}:${TestDatabase.port} — '
          'start one with tool/run_db_tests.sh';

  group('TomPersistent2FAEnrolmentStore (DB-backed)', () {
    late TomDataSourceInfo dsi;
    late TomPersistent2FAEnrolmentStore store;

    setUpAll(() async {
      initializeReflection();
      dsi = await TestDatabase.register();
      // TomUserTwoFactorEnrolment declares `datasource: 'main'`, the name a
      // deployment configures. Aliasing rather than renaming keeps the entity
      // under test identical to the one that ships.
      await TestDatabase.registerMainAlias();
      await TestDatabase.ensureTwoFactorEnrolmentTable(dsi);
    });

    setUp(() async {
      await TestDatabase.truncateTwoFactorEnrolment(dsi);
      // A fresh repository per test, matching the rest of the DB suite: no
      // prepared-statement cache carries the previous test's table state.
      store = TomPersistent2FAEnrolmentStore(
        TomUserTwoFactorEnrolmentRepository(),
      );
    });

    tearDownAll(TestDatabase.reset);

    /// Reads the table without going through the store, so an assertion about
    /// storage cannot be satisfied by the store agreeing with itself.
    Future<List<TomUserTwoFactorEnrolment>> rawRows() =>
        dsi.datasource.executeQuery<TomUserTwoFactorEnrolment>(
          'SELECT id, principal_id, enrolment_id, mechanism, hint, '
          'enrolled_at, is_primary, secret_data '
          'FROM tom_user_two_factor_enrolment ORDER BY id',
        );

    // ------------------------------------------------------------------
    // Round trip
    // ------------------------------------------------------------------

    test('a stored enrolment round-trips with every field intact', () async {
      await store.store(
        _context(7),
        Tom2FAEnrolment(
          type: 'totp',
          enrolmentId: 'phone-1',
          hint: 'iPhone 14',
          enrolledAt: _enrolledAt,
          isPrimary: true,
          secretData: {TomTotp2FAService.secretDataKey: _secret},
        ),
      );

      final loaded = await store.enrolmentsFor(_context(7));
      expect(loaded, hasLength(1));
      final enrolment = loaded.single;
      expect(enrolment.type, 'totp');
      expect(enrolment.enrolmentId, 'phone-1');
      expect(enrolment.hint, 'iPhone 14');
      expect(enrolment.isPrimary, isTrue);
      expect(enrolment.enrolledAt.isUtc, isTrue);
      expect(enrolment.enrolledAt, _enrolledAt);
      expect(enrolment.secretData[TomTotp2FAService.secretDataKey], _secret);
    });

    test('an enrolment with no secret round-trips as an empty map', () async {
      await store.store(
        _context(7),
        Tom2FAEnrolment(type: 'push', enrolmentId: 'watch', hint: 'Watch'),
      );

      final enrolment = (await store.enrolmentsFor(_context(7))).single;
      expect(enrolment.type, 'push');
      expect(enrolment.secretData, isEmpty);
      // Nothing to decrypt means nothing was encrypted: no key operation is
      // spent on a mechanism that keeps no secret.
      expect((await rawRows()).single.secretDataCipher, isEmpty);
    });

    test('enrolments are scoped to the principal that stored them', () async {
      await store.store(
        _context(7),
        Tom2FAEnrolment(type: 'totp', enrolmentId: 'phone-1'),
      );
      await store.store(
        _context(8),
        Tom2FAEnrolment(type: 'totp', enrolmentId: 'phone-1'),
      );

      expect(await store.enrolmentsFor(_context(7)), hasLength(1));
      expect(await store.enrolmentsFor(_context(8)), hasLength(1));
      // The same enrolment id under two principals is two rows, not a
      // collision: the unique key is the *pair*.
      expect(await rawRows(), hasLength(2));
    });

    test('a principal with nothing stored reads back empty', () async {
      expect(await store.enrolmentsFor(_context(99)), isEmpty);
    });

    test('several enrolments per principal are all returned', () async {
      await store.store(
        _context(7),
        Tom2FAEnrolment(type: 'totp', enrolmentId: 'phone-1'),
      );
      await store.store(
        _context(7),
        Tom2FAEnrolment(type: 'push', enrolmentId: 'watch-1'),
      );

      final loaded = await store.enrolmentsFor(_context(7));
      expect(loaded.map((e) => e.enrolmentId), containsAll(<String>[
        'phone-1',
        'watch-1',
      ]));
    });

    // ------------------------------------------------------------------
    // Upsert and removal
    // ------------------------------------------------------------------

    test('re-storing the same enrolment id updates the row rather than '
        'inserting a second', () async {
      await store.store(
        _context(7),
        Tom2FAEnrolment(
          type: 'totp',
          enrolmentId: 'phone-1',
          hint: 'old device',
          secretData: {TomTotp2FAService.secretDataKey: _secret},
        ),
      );
      final firstId = (await rawRows()).single.id;

      await store.store(
        _context(7),
        Tom2FAEnrolment(
          type: 'totp',
          enrolmentId: 'phone-1',
          hint: 'new device',
          secretData: {TomTotp2FAService.secretDataKey: 'AAAAAAAAAAAAAAAA'},
        ),
      );

      final rows = await rawRows();
      expect(rows, hasLength(1));
      // The same row, not a replacement: re-enrolling after losing an
      // authenticator must not orphan the old secret in a second row that a
      // login could still match.
      expect(rows.single.id, firstId);
      final enrolment = (await store.enrolmentsFor(_context(7))).single;
      expect(enrolment.hint, 'new device');
      expect(
        enrolment.secretData[TomTotp2FAService.secretDataKey],
        'AAAAAAAAAAAAAAAA',
      );
    });

    test('remove deletes only the named enrolment', () async {
      await store.store(
        _context(7),
        Tom2FAEnrolment(type: 'totp', enrolmentId: 'phone-1'),
      );
      await store.store(
        _context(7),
        Tom2FAEnrolment(type: 'push', enrolmentId: 'watch-1'),
      );

      await store.remove(_context(7), 'phone-1');

      final loaded = await store.enrolmentsFor(_context(7));
      expect(loaded.map((e) => e.enrolmentId), <String>['watch-1']);
    });

    test('remove leaves another principal\'s identically named enrolment '
        'alone', () async {
      await store.store(
        _context(7),
        Tom2FAEnrolment(type: 'totp', enrolmentId: 'phone-1'),
      );
      await store.store(
        _context(8),
        Tom2FAEnrolment(type: 'totp', enrolmentId: 'phone-1'),
      );

      await store.remove(_context(7), 'phone-1');

      expect(await store.enrolmentsFor(_context(7)), isEmpty);
      expect(await store.enrolmentsFor(_context(8)), hasLength(1));
    });

    test('removing an enrolment that is not there is a no-op', () async {
      await store.store(
        _context(7),
        Tom2FAEnrolment(type: 'totp', enrolmentId: 'phone-1'),
      );

      await expectLater(store.remove(_context(7), 'ghost'), completes);
      expect(await store.enrolmentsFor(_context(7)), hasLength(1));
    });

    // ------------------------------------------------------------------
    // The secret is unreadable at rest
    // ------------------------------------------------------------------

    test('the raw secret_data column holds neither the secret nor its '
        'plaintext JSON', () async {
      await store.store(
        _context(7),
        Tom2FAEnrolment(
          type: 'totp',
          enrolmentId: 'phone-1',
          secretData: {TomTotp2FAService.secretDataKey: _secret},
        ),
      );

      final cipher = (await rawRows()).single.secretDataCipher;
      expect(cipher, isNotEmpty);
      // Not the secret, and not merely encoded around it: `contains` is the
      // assertion that matters, because a scheme that only wrapped the value
      // (base64 of the JSON, say) would pass an equality check and still hand
      // a database reader the user's authenticator.
      expect(cipher, isNot(_secret));
      expect(cipher, isNot(contains(_secret)));
      // Nor is the key name legible — the map is encrypted whole, so a reader
      // cannot even tell which mechanism state a row carries.
      expect(cipher, isNot(contains(TomTotp2FAService.secretDataKey)));
      // And it is not JSON at all: a `jsonDecode` of the stored column fails,
      // which is what distinguishes ciphertext from a value that was merely
      // moved to another column.
      expect(() => jsonDecode(cipher), throwsA(isA<FormatException>()));
    });

    test('an undecryptable row yields an unusable factor, not a failed read',
        () async {
      await store.store(
        _context(7),
        Tom2FAEnrolment(
          type: 'totp',
          enrolmentId: 'phone-1',
          hint: 'iPhone 14',
          secretData: {TomTotp2FAService.secretDataKey: _secret},
        ),
      );
      // Ciphertext this store's key cannot open — what a row written before a
      // key rotation looks like afterwards.
      await dsi.datasource.executeCommand(
        "UPDATE tom_user_two_factor_enrolment SET secret_data = 'not-cipher'",
      );

      // The enrolment still comes back, with everything that was never secret
      // intact: an unreadable secret means *this factor cannot answer a
      // challenge*, and throwing would instead fail the whole login — including
      // the user's other, perfectly good factors.
      final enrolment = (await store.enrolmentsFor(_context(7))).single;
      expect(enrolment.enrolmentId, 'phone-1');
      expect(enrolment.hint, 'iPhone 14');
      expect(enrolment.secretData, isEmpty);
    });
  }, skip: skipReason);
}
