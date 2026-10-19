/// DB-backed tests for the persistent provider-token store.
///
/// The store's *contract* — what `read` / `store` / `delete` mean, when a grant
/// is refreshed, how the cascade from `unlink` behaves — is covered against
/// `TomMemoryOAuthTokenStore` in `oauth_test.dart`, without a database.
///
/// This file exercises the three things only a real server can answer:
///
///  * a [TomOAuthTokenGrant] written through [TomPersistentOAuthTokenStore]
///    survives a round trip through `tom_external_identity_token` with every
///    field intact, and re-storing the same `(issuer, subject)` really is one
///    row rather than two;
///  * **neither token is readable in the raw row.** That is the whole reason
///    the store exists in this shape. A provider refresh token is the most
///    dangerous thing this framework ever writes to a database — a live bearer
///    credential at a *third party*, valid long after the session that produced
///    it and revocable only by the user noticing — so a backup of a table
///    holding them in the clear is a set of keys to other people's mail. The
///    assertion therefore has to be made against the column the database
///    actually holds, not against anything the store hands back, which would
///    only prove the store can read its own writes; and
///  * the retention bound really binds: deleting the identity link through
///    [TomPersistentExternalIdentityStore.unlink] takes the stored grant with
///    it, across two tables and two repositories.
///
/// The whole group is `@Tags(['db'])` and skips itself when no MariaDB is
/// reachable, so the default `testkit :test` run stays green everywhere. Bring a
/// server up with `tool/run_db_tests.sh` to run it.
@Tags(['db'])
library;

import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

/// The stub provider's issuer, matching `oauth_test.dart`.
const String _issuer = 'https://idp.example.test';

/// Token values distinctive enough that an accidental plaintext write would be
/// recognisable in a raw column dump — which is exactly what the secrecy test
/// looks for.
const String _accessToken = 'AT-e0e04b1c-8f2a-4b7d-9c31-provider-access';
const String _refreshToken = 'RT-91f2c7ad-33be-4c08-8a5e-provider-refresh';

/// Whole-second timestamps: MariaDB's `DATETIME` carries no fractional part, so
/// a `DateTime.now()` here would fail the round trip on truncation alone and say
/// nothing about the store.
///
/// Deliberately *not* a round hour apart, and deliberately in March: a whole
/// hour between them would make "the two columns are swapped" indistinguishable
/// from "the value shifted by the machine's UTC offset", and a summer date would
/// make the offset the same one the test process happens to be running under.
final DateTime _obtainedAt = DateTime.utc(2026, 3, 4, 5, 6, 7);
final DateTime _expiresAt = DateTime.utc(2026, 3, 4, 9, 41, 23);

TomOAuthTokenGrant _grant({
  String accessToken = _accessToken,
  String? refreshToken = _refreshToken,
  String scope = 'openid email calendar.read',
}) => TomOAuthTokenGrant(
  accessToken: accessToken,
  refreshToken: refreshToken,
  scope: scope,
  expiresAt: _expiresAt,
  obtainedAt: _obtainedAt,
);

void main() async {
  // Probe once, before declaring the group, so the group can skip when nothing
  // is listening — keeping the default run green with no database.
  final reachable = await TestDatabase.isReachable();
  final String? skipReason = reachable
      ? null
      : 'No ${TestDatabase.engine} server reachable on ${TestDatabase.host}:${TestDatabase.port} — '
            'start one with tool/run_db_tests.sh or tool/run_db_tests_postgres.sh';

  group('TomPersistentOAuthTokenStore (DB-backed)', () {
    late TomDataSourceInfo dsi;
    late TomPersistentOAuthTokenStore store;

    setUpAll(() async {
      initializeReflection();
      dsi = await TestDatabase.register();
      // Both entities declare `datasource: 'main'`, the name a deployment
      // configures. Aliasing rather than renaming keeps the entities under test
      // identical to the ones that ship.
      await TestDatabase.registerMainAlias();
      await TestDatabase.ensureExternalIdentityTable(dsi);
      await TestDatabase.ensureExternalIdentityTokenTable(dsi);
    });

    setUp(() async {
      await TestDatabase.truncateExternalIdentity(dsi);
      await TestDatabase.truncateExternalIdentityToken(dsi);
      // A fresh repository per test, matching the rest of the DB suite: no
      // prepared-statement cache carries the previous test's table state.
      store = TomPersistentOAuthTokenStore(
        TomExternalIdentityTokenRepository(),
      );
    });

    tearDownAll(TestDatabase.reset);

    /// Reads the table without going through the store, so an assertion about
    /// storage cannot be satisfied by the store agreeing with itself.
    Future<List<TomExternalIdentityToken>> rawRows() =>
        dsi.datasource.executeQuery<TomExternalIdentityToken>(
          'SELECT id, issuer, subject, token_data, token_scope, '
          'obtained_at, expires_at '
          'FROM tom_external_identity_token ORDER BY id',
        );

    // ------------------------------------------------------------------
    // Round trip
    // ------------------------------------------------------------------

    test('a stored grant round-trips with every field intact', () async {
      await store.store(_issuer, 'sub-1', _grant());

      final read = await store.read(_issuer, 'sub-1');
      expect(read, isNotNull);
      expect(read!.accessToken, _accessToken);
      expect(read.refreshToken, _refreshToken);
      expect(read.tokenType, 'Bearer');
      expect(read.scope, 'openid email calendar.read');
      expect(read.expiresAt, _expiresAt);
      expect(read.obtainedAt, _obtainedAt);
    });

    test('a grant with no refresh token round-trips as one without', () async {
      await store.store(_issuer, 'sub-1', _grant(refreshToken: null));

      final read = await store.read(_issuer, 'sub-1');
      expect(read!.hasRefreshToken, isFalse);
      expect(read.accessToken, _accessToken);
    });

    test('an identity with no grant reads back as null', () async {
      expect(await store.read(_issuer, 'nobody'), isNull);
    });

    // ------------------------------------------------------------------
    // Secrecy at rest
    // ------------------------------------------------------------------

    // The point of the whole store. Asserted against the raw column, because
    // the store reading its own writes proves only that the cipher is
    // reversible.
    test('neither token is readable in the raw row', () async {
      await store.store(_issuer, 'sub-1', _grant());

      final row = (await rawRows()).single;
      expect(row.tokenData, isNotEmpty);
      expect(row.tokenData, isNot(contains(_accessToken)));
      expect(row.tokenData, isNot(contains(_refreshToken)));
      // Not merely reordered or encoded: the plaintext JSON key names are gone
      // too, so a reader cannot even tell which field is which.
      expect(row.tokenData, isNot(contains('accessToken')));
      expect(row.tokenData, isNot(contains('refreshToken')));
    });

    // The operator projection: "is this grant live, and what does it cover?"
    // must be answerable from the table without the private key, because an
    // operator holding the private key to answer it defeats the encryption.
    test('the scope and the timestamps stay readable beside it', () async {
      await store.store(_issuer, 'sub-1', _grant());

      final row = (await rawRows()).single;
      expect(row.issuer, _issuer);
      expect(row.subject, 'sub-1');
      expect(row.tokenScope, 'openid email calendar.read');
      // Equal with no conversion on the way out. A `DATETIME` column carries no
      // zone, so the datasource supplies the one the text omits: written as UTC
      // and read back UTC-flagged (`datasources/sql_instant.dart`). Dart's `==`
      // compares the flag as well as the moment, which makes this the stronger
      // assertion — it fails if the column is read as the local time of
      // whichever node happened to load the row, and that is precisely the
      // reading that would let one node think a grant had expired and another
      // think it had not.
      expect(row.obtainedAt, _obtainedAt);
      expect(row.expiresAt, _expiresAt);
      expect(row.obtainedAt!.isUtc, isTrue);
    });

    // ------------------------------------------------------------------
    // One row per identity
    // ------------------------------------------------------------------

    // A second row for the same identity would make which credential an
    // application presents depend on row order — and the older of the two is by
    // definition the one whose refresh token the provider may already have
    // rotated away.
    test('re-storing an identity replaces rather than duplicates', () async {
      await store.store(_issuer, 'sub-1', _grant());
      await store.store(
        _issuer,
        'sub-1',
        _grant(accessToken: 'AT-second', refreshToken: 'RT-second'),
      );

      expect(await rawRows(), hasLength(1));
      final read = await store.read(_issuer, 'sub-1');
      expect(read!.accessToken, 'AT-second');
      expect(read.refreshToken, 'RT-second');
    });

    // The subject is unique only within its issuer: the same subject from a
    // different provider is a different person, holding a different credential.
    test('two issuers may hold a grant for the same subject', () async {
      await store.store(_issuer, 'sub-1', _grant(accessToken: 'AT-first'));
      await store.store(
        'https://other.example.test',
        'sub-1',
        _grant(accessToken: 'AT-other'),
      );

      expect(await rawRows(), hasLength(2));
      expect((await store.read(_issuer, 'sub-1'))!.accessToken, 'AT-first');
      expect(
        (await store.read('https://other.example.test', 'sub-1'))!.accessToken,
        'AT-other',
      );
    });

    // ------------------------------------------------------------------
    // Deletion
    // ------------------------------------------------------------------

    test('deleting a grant removes its row', () async {
      await store.store(_issuer, 'sub-1', _grant());
      await store.delete(_issuer, 'sub-1');

      expect(await rawRows(), isEmpty);
      expect(await store.read(_issuer, 'sub-1'), isNull);
    });

    test('deleting a grant that is not there is a no-op', () async {
      await store.delete(_issuer, 'nobody');
      expect(await rawRows(), isEmpty);
    });

    // The retention bound, across both tables: a third-party credential must
    // never outlive the link it was granted through.
    test('unlinking the identity deletes the grant with it', () async {
      final identities = TomPersistentExternalIdentityStore(
        TomExternalIdentityLinkRepository(),
        tokenStore: store,
      );
      const identity = TomExternalIdentity(issuer: _issuer, subject: 'sub-1');

      await identities.link(identity, 'alice');
      await store.store(_issuer, 'sub-1', _grant());
      expect(await rawRows(), hasLength(1));

      await identities.unlink(_issuer, 'sub-1');

      expect(await rawRows(), isEmpty);
      expect(await identities.localUsernameFor(identity), isNull);
    });

    // A grant held for an identity that was never linked here is still deleted:
    // the cascade keys on `(issuer, subject)`, not on the link row existing.
    test('unlinking an unlinked identity still clears its grant', () async {
      final identities = TomPersistentExternalIdentityStore(
        TomExternalIdentityLinkRepository(),
        tokenStore: store,
      );
      await store.store(_issuer, 'sub-1', _grant());

      await identities.unlink(_issuer, 'sub-1');

      expect(await rawRows(), isEmpty);
    });
  }, skip: skipReason);
}
