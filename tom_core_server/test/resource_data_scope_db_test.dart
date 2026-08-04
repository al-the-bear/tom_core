/// DB-backed tests for the grant-driven row scope (RCC5).
///
/// `resource_data_scope_test.dart` asserts the *predicate* the scope resolves —
/// which keys, at which grade, from which grants. This file asserts the thing
/// the todo actually promises: that a repository, given nothing but an entity
/// with a `resource_key` column and a principal with grants, returns and accepts
/// only that principal's rows. Every claim here is made through the ordinary
/// `TomSqlDatasourceRepository` API against a real table, so nothing can be
/// satisfied by a resolver agreeing with itself.
///
/// Three things are only visible at this level:
///
///  * **the entity carries no `@TomDbScope`.** [FixtureResourceRecord] is
///    annotated with a table and columns and nothing else; if automatic scoping
///    did not work, every query below would return every row;
///  * **read and write diverge.** A `viewer` grant puts the row in `findAll`
///    and takes every mutation of it away — a distinction that only exists once
///    a repository is applying the two resolvers to the two paths;
///  * **grants and delegations reach the repository through the real
///    resolvers**, so a revoked share stops filtering at the next query rather
///    than at some cache boundary.
///
/// The group is `@Tags(['db'])` and skips itself when no MariaDB is reachable,
/// so the default `testkit :test` run stays green everywhere. Bring a server up
/// with `tool/run_db_tests.sh` to run it.
@Tags(['db'])
library;

import 'dart:async';

import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

import 'fixtures/reflection_fixture.dart';
import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

/// A principal whose [TomPrincipal.id] is [userId] — the value the grant rows
/// are keyed by (`principalId: '<id>'`).
TomPrincipal _principalWithId(int userId) => TomPrincipal(
  authenticated: true,
  user: TomUser(id: userId, username: 'user$userId'),
  aci: TomAccessControlInformation(roles: const ['user']),
);

TomPrincipalResourceGrant _grant(int principal, String resource, String role) =>
    TomPrincipalResourceGrant(
      principalId: '$principal',
      resourceKey: resource,
      role: role,
    );

void main() async {
  final reachable = await TestDatabase.isReachable();
  final String? skipReason = reachable
      ? null
      : 'MariaDB not reachable on ${TestDatabase.host}:${TestDatabase.port} — '
            'start one with tool/run_db_tests.sh';

  group('grant-driven row scope (DB-backed)', () {
    late TomDataSourceInfo dsi;

    setUpAll(() async {
      initializeReflection();
      dsi = await TestDatabase.register();
      await TestDatabase.ensureFixtureResourceTable(dsi);
    });

    setUp(() async {
      await TestDatabase.truncateFixtureResource(dsi);
      TomResourceRoleRegistry.reset();
      TomResourceRoleRegistry.registerAll({
        'owner': TomAuthState.full,
        'viewer': TomAuthState.read,
      });
    });

    tearDown(() {
      TomResourceDataScope.uninstall();
      TomResourceRoleRegistry.reset();
    });

    tearDownAll(TestDatabase.reset);

    /// Installs the scope over [grants] and [delegations], evaluated at [now].
    void install(
      List<TomPrincipalResourceGrant> grants, {
      List<TomPrincipalDelegation> delegations = const [],
      DateTime? now,
    }) {
      TomResourceDataScope.install(
        TomDelegationResolver(
          InMemoryPrincipalDelegationStore(delegations),
          TomPrincipalResourceRoleResolver(
            InMemoryPrincipalResourceGrantStore(grants),
          ),
        ),
        now: now == null ? null : () => now,
      );
    }

    /// Runs [body] as [userId] would — a request zone carrying that principal,
    /// over a freshly constructed repository (the scope must come from the zone,
    /// not from an instance field).
    Future<T> asPrincipal<T>(
      int userId,
      Future<T> Function(FixtureResourceRepository repo) body,
    ) => runZoned(
      () => body(FixtureResourceRepository()),
      zoneValues: <Object, Object?>{TomPrincipal: _principalWithId(userId)},
    );

    /// Inserts a row bypassing the scope, so a test can prove a principal
    /// cannot see a row that demonstrably exists.
    Future<void> seed(String resourceKey, String title) =>
        dsi.datasource.executeCommand(
          'INSERT INTO fixture_resource_document (resource_key, title) '
          "VALUES ('$resourceKey', '$title')",
        );

    /// Reads every row without a repository, so "the row is still there" is not
    /// an assertion the scope itself can satisfy.
    Future<int> rawCount() async => (await rawRows(dsi)).length;

    // ------------------------------------------------------------------
    // Reads
    // ------------------------------------------------------------------

    test('two principals read disjoint row sets from their own grants',
        () async {
      await seed('project:alpha', 'Alpha plan');
      await seed('project:beta', 'Beta plan');
      install([
        _grant(1, 'project:alpha', 'owner'),
        _grant(2, 'project:beta', 'owner'),
      ]);

      final one = await asPrincipal(1, (r) => r.findAll());
      final two = await asPrincipal(2, (r) => r.findAll());
      expect(one.map((e) => e.title), ['Alpha plan']);
      expect(two.map((e) => e.title), ['Beta plan']);
      // Both rows are really there — the filtering is the scope's, not the
      // fixture's.
      expect(await rawCount(), 2);
    });

    test('an ungranted row is invisible by id as well as in a listing',
        () async {
      await seed('project:alpha', 'Alpha plan');
      final ids = await rawIds(dsi);
      install([_grant(2, 'project:beta', 'owner')]);

      expect(await asPrincipal(2, (r) => r.findAll()), isEmpty);
      expect(await asPrincipal(2, (r) => r.findById(ids.first)), isNull);
    });

    test('a principal with no grants at all reads nothing', () async {
      await seed('project:alpha', 'Alpha plan');
      install(const []);
      expect(await asPrincipal(1, (r) => r.findAll()), isEmpty);
    });

    test('a viewer grant admits the row to a read (decision 1)', () async {
      await seed('project:alpha', 'Alpha plan');
      install([_grant(1, 'project:alpha', 'viewer')]);
      expect(
        (await asPrincipal(1, (r) => r.findAll())).map((e) => e.title),
        ['Alpha plan'],
      );
    });

    // ------------------------------------------------------------------
    // Writes
    // ------------------------------------------------------------------

    test('an owner grant admits an update; the change reaches the table',
        () async {
      await seed('project:alpha', 'Alpha plan');
      install([_grant(1, 'project:alpha', 'owner')]);

      await asPrincipal(1, (r) async {
        final row = (await r.findAll()).single;
        row.title = 'Alpha plan v2';
        await r.save(row);
      });

      final reread = await asPrincipal(1, (r) => r.findAll());
      expect(reread.single.title, 'Alpha plan v2');
    });

    test('a viewer grant rejects an update of the row it admits to reads '
        '(decision 2)', () async {
      await seed('project:alpha', 'Alpha plan');
      install([_grant(1, 'project:alpha', 'viewer')]);

      await asPrincipal(1, (r) async {
        final row = (await r.findAll()).single;
        row.title = 'Alpha plan v2';
        await expectLater(
          r.save(row),
          throwsA(isA<TomDataScopeAuthorizationException>()),
        );
      });
      // The row is untouched, not merely un-returned.
      expect((await rawRows(dsi)).single.title, 'Alpha plan');
    });

    test('a viewer grant rejects a delete of the row it admits to reads',
        () async {
      await seed('project:alpha', 'Alpha plan');
      final ids = await rawIds(dsi);
      install([_grant(1, 'project:alpha', 'viewer')]);

      await asPrincipal(1, (r) async {
        await expectLater(
          r.deleteById(ids.first),
          throwsA(isA<TomDataScopeAuthorizationException>()),
        );
      });
      expect(await rawCount(), 1);
    });

    test('an owner grant admits a delete', () async {
      await seed('project:alpha', 'Alpha plan');
      final ids = await rawIds(dsi);
      install([_grant(1, 'project:alpha', 'owner')]);

      await asPrincipal(1, (r) => r.deleteById(ids.first));
      expect(await rawCount(), 0);
    });

    test('a write to another principal\'s row is rejected, not silently ignored',
        () async {
      await seed('project:alpha', 'Alpha plan');
      install([
        _grant(1, 'project:alpha', 'owner'),
        _grant(2, 'project:beta', 'owner'),
      ]);

      // Principal 1 reads the row it owns; principal 2 tries to write it.
      final row = (await asPrincipal(1, (r) => r.findAll())).single;
      row.title = 'Hijacked';
      await asPrincipal(2, (r) async {
        await expectLater(
          r.save(row),
          throwsA(isA<TomDataScopeAuthorizationException>()),
        );
      });
    });

    test('an insert under an ungranted resource key is rejected', () async {
      install([_grant(1, 'project:alpha', 'owner')]);

      await asPrincipal(1, (r) async {
        final fresh = FixtureResourceRecord()
          ..resourceKey = 'project:beta'
          ..title = 'Not mine';
        await expectLater(
          r.save(fresh),
          throwsA(isA<TomDataScopeAuthorizationException>()),
        );
      });
      expect(await rawCount(), 0);
    });

    test('an insert under a viewer-graded key is rejected too (decision 2)',
        () async {
      install([_grant(1, 'project:alpha', 'viewer')]);

      await asPrincipal(1, (r) async {
        final fresh = FixtureResourceRecord()
          ..resourceKey = 'project:alpha'
          ..title = 'Read-only key';
        await expectLater(
          r.save(fresh),
          throwsA(isA<TomDataScopeAuthorizationException>()),
        );
      });
      expect(await rawCount(), 0);
    });

    test('an insert under an owner-graded key is accepted', () async {
      install([_grant(1, 'project:alpha', 'owner')]);

      await asPrincipal(1, (r) async {
        final fresh = FixtureResourceRecord()
          ..resourceKey = 'project:alpha'
          ..title = 'Mine';
        await r.save(fresh);
      });
      expect(await rawCount(), 1);
      expect(
        (await asPrincipal(1, (r) => r.findAll())).single.title,
        'Mine',
      );
    });

    // ------------------------------------------------------------------
    // Delegation
    // ------------------------------------------------------------------

    test('an active share delegation lets the delegate read the shared row',
        () async {
      await seed('project:alpha', 'Alpha plan');
      install(
        [_grant(1, 'project:alpha', 'owner')],
        delegations: [
          TomPrincipalDelegation(
            delegatorId: '1',
            delegateId: '2',
            mode: 'share',
            resourceKey: 'project:alpha',
            role: 'viewer',
          ),
        ],
      );

      expect(
        (await asPrincipal(2, (r) => r.findAll())).map((e) => e.title),
        ['Alpha plan'],
      );
    });

    test('a revoked delegation stops the delegate reading the row', () async {
      await seed('project:alpha', 'Alpha plan');
      install(
        [_grant(1, 'project:alpha', 'owner')],
        delegations: [
          TomPrincipalDelegation(
            delegatorId: '1',
            delegateId: '2',
            mode: 'share',
            resourceKey: 'project:alpha',
            role: 'viewer',
            revoked: true,
          ),
        ],
      );

      expect(await asPrincipal(2, (r) => r.findAll()), isEmpty);
    });

    test('a viewer share admits the read and rejects the write', () async {
      await seed('project:alpha', 'Alpha plan');
      install(
        [_grant(1, 'project:alpha', 'owner')],
        delegations: [
          TomPrincipalDelegation(
            delegatorId: '1',
            delegateId: '2',
            mode: 'share',
            resourceKey: 'project:alpha',
            role: 'viewer',
          ),
        ],
      );

      await asPrincipal(2, (r) async {
        final row = (await r.findAll()).single;
        row.title = 'Changed by the delegate';
        await expectLater(
          r.save(row),
          throwsA(isA<TomDataScopeAuthorizationException>()),
        );
      });
    });

    test('an owner share admits the delegate\'s write', () async {
      await seed('project:alpha', 'Alpha plan');
      install(
        [_grant(1, 'project:alpha', 'owner')],
        delegations: [
          TomPrincipalDelegation(
            delegatorId: '1',
            delegateId: '2',
            mode: 'share',
            resourceKey: 'project:alpha',
            role: 'owner',
          ),
        ],
      );

      await asPrincipal(2, (r) async {
        final row = (await r.findAll()).single;
        row.title = 'Changed by the delegate';
        await r.save(row);
      });
      expect(
        (await asPrincipal(1, (r) => r.findAll())).single.title,
        'Changed by the delegate',
      );
    });

    test('a delegation outside its validity window grants nothing', () async {
      await seed('project:alpha', 'Alpha plan');
      install(
        [_grant(1, 'project:alpha', 'owner')],
        delegations: [
          TomPrincipalDelegation(
            delegatorId: '1',
            delegateId: '2',
            mode: 'absence',
            validFrom: DateTime.utc(2026, 8, 1),
            validTo: DateTime.utc(2026, 8, 10),
          ),
        ],
        now: DateTime.utc(2026, 8, 20),
      );

      expect(await asPrincipal(2, (r) => r.findAll()), isEmpty);
    });

    // ------------------------------------------------------------------
    // Deny by default
    // ------------------------------------------------------------------

    test('with no scope source installed the entity is invisible', () async {
      await seed('project:alpha', 'Alpha plan');
      TomResourceDataScope.uninstall();
      expect(await asPrincipal(1, (r) => r.findAll()), isEmpty);
      expect(await rawCount(), 1);
    });

    test('an unauthenticated request (no principal in the zone) reads nothing',
        () async {
      await seed('project:alpha', 'Alpha plan');
      install([_grant(1, 'project:alpha', 'owner')]);
      expect(await FixtureResourceRepository().findAll(), isEmpty);
    });
  }, skip: skipReason);
}

/// Every row in `fixture_resource_document`, read as raw SQL rather than through
/// a repository — unscoped by construction, so a test can name (or count) a row
/// no principal is allowed to see.
Future<List<FixtureResourceRecord>> rawRows(TomDataSourceInfo dsi) =>
    dsi.datasource.executeQuery<FixtureResourceRecord>(
      'SELECT id, resource_key, title FROM fixture_resource_document '
      'ORDER BY id',
    );

/// The primary keys currently in `fixture_resource_document`.
Future<List<int>> rawIds(TomDataSourceInfo dsi) async =>
    [for (final row in await rawRows(dsi)) row.id!];
